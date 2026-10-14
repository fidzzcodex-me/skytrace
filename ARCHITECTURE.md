# Arsitektur SkyTrace

## Prinsip

1. Semua traffic dihentikan di dalam proses. Tidak ada port lokal yang dibuka.
2. Room di Kotlin adalah satu-satunya sumber data traffic. Flutter membaca lewat channel dan menerima pembaruan lewat event.
3. Mesin tidak pernah memodifikasi traffic yang tidak cocok dengan rule atau breakpoint, selain normalisasi Accept-Encoding yang bisa dimatikan.

## Alur data

```
Aplikasi lain
   | paket IP
   v
TUN (VpnService, 10.8.0.2/32, route 0.0.0.0/0)
   |
PacketReader  (thread blocking, buffer dipakai ulang)
   |
TrafficRouter
   |-- TCP --> TcpSession (state machine user-space)
   |             |  stream byte
   |             v
   |          LocalProxyEngine
   |             |-- deteksi ClientHello TLS --> TlsInterceptor --> HTTP loop
   |             |-- awalan method HTTP     --> HTTP loop
   |             |-- lainnya                --> tunnel mentah
   |
   |-- UDP 53 --> UdpRelay.handleDns (AAAA dijawab kosong, A dipelajari DnsCache)
   |-- UDP 443 --> ICMP port unreachable bila blockQuic aktif
   |-- UDP lain --> UdpRelay flow per soket (protect)
   v
TunWriter --> TUN --> aplikasi asal
```

## State machine TCP

`TcpSession` berperan sebagai server TCP bagi aplikasi.

```
SYN diterima
   |
   v
SYN_RCVD --(ACK dari klien)--> ESTABLISHED
                                   |
        FIN dari klien             |           close() dari engine
   +-------------------------------+--------------------------+
   v                                                          v
(input ditutup, engine melihat EOF)                      FIN_WAIT / LAST_ACK
                                                              |
                                     FIN diakui dan FIN klien diterima
                                                              v
                                                           CLOSED
```

- Segmen keluar dibatasi jendela klien dan MSS 1360 (MTU 1400).
- Segmen yang belum di-ACK disimpan dan dikirim ulang oleh sweeper setiap 900 ms, maksimal 8 kali.
- Data masuk yang tidak berurutan dibuang dan di-ACK ulang agar klien mengirim ulang.
- `write()` ditangguhkan bila buffer lebih dari 512 KB sehingga ada backpressure ke upstream.
- Arah klien ke proxy memakai channel tak terbatas. Upload yang sangat besar bisa memakai memori.

## TLS

1. Byte pertama dari klien diperiksa: `0x16 0x03` berarti TLS.
2. `TlsInterceptor` mengumpulkan ClientHello lengkap dan membaca SNI.
3. `CertManager.contextFor(host)` membuat sertifikat leaf (EC P-256, berlaku 365 hari, SAN sesuai host) yang ditandatangani CA lokal. `SSLContext` disimpan di cache LRU 256 entri.
4. `SslEngineTransport` menjalankan handshake dengan `SSLEngine` di atas transport byte.
5. ALPN tidak dinegosiasikan sehingga klien jatuh ke HTTP/1.1.
6. Bila handshake gagal, host masuk daftar bypass dan koneksi berikutnya diteruskan sebagai tunnel.
7. Koneksi upstream memakai `SSLSocket` dengan SNI, verifikasi hostname bawaan, atau trust-all bila opsi diaktifkan.

## Mode remote proxy

```
Klien (HP ini atau perangkat lain)
   | proxy Wi-Fi ke ip:8888
   v
ProxyService (ServerSocket)
   |
LocalProxyEngine.serveProxyConnection
   |-- CONNECT host:port --> 200 Connection Established --> byte pertama
   |        TLS  --> TlsInterceptor --> HTTP loop
   |        HTTP --> HTTP loop
   |        lain --> tunnel
   |-- GET http://host/path --> normalisasi ke origin-form --> HTTP loop
   v
socket upstream biasa (tidak lewat VPN)
```

Mesin HTTP sama persis dengan mode VPN. Perbedaannya hanya sumber koneksi: tidak ada `TcpSession`, dan aplikasi asal tidak diketahui sehingga dicatat sebagai `Proxy <ip klien>`. Password proxy memakai Basic `Proxy-Authorization` dan diperiksa pada request pertama setiap koneksi.

## Live Monitor

```
Browser PC --HTTP--> MonitorServer (ServerSocket, MonitorService foreground)
   |  GET /            halaman dashboard (asset monitor/index.html)
   |  POST /api/login  PIN -> cookie sesi (HttpOnly, SameSite=Strict)
   |  GET /api/...     data dari TrafficRepository (Room), memerlukan sesi
   |  GET /ws          WebSocket, mendorong event dari EventBus
   v
EventBus (traffic_new, traffic_update, traffic_deleted, stats, vpn_state)
```

Server ditulis sendiri di atas `ServerSocket` memakai parser HTTP yang sama dengan proxy. Tidak ada dependensi tambahan. Event `breakpoint_*` tidak pernah dikirim ke dashboard. Penghapusan dari aplikasi, dashboard, atau filter memancarkan `traffic_deleted` sehingga semua tampilan tersinkron.

## Alur satu request HTTP

```
readHead -> parse -> readRequestBody
   -> insert TrafficEntity (event traffic_new)
   -> RewriteEngine.applyRequest  (header, body, redirect, delay, mock)
   -> BreakpointManager (request)
   -> normalisasi Accept-Encoding
   -> upstream (reuse koneksi per host:port, retry sekali bila koneksi basi)
   -> baca head response
   -> rule header response
   -> bila ada rule ganti body atau breakpoint response: buffer penuh, edit, kirim
      bila tidak: stream ke klien sambil menangkap body sampai batas
   -> update TrafficEntity (event traffic_update)
```

Request yang tersimpan adalah request setelah rewrite dan breakpoint, bertanda `modified`.

## Urutan rule

Rule dievaluasi sesuai urutan id. Mock menghentikan evaluasi dan langsung menjawab klien. Delay dari beberapa rule dijumlahkan.

## Breakpoint

`BreakpointManager.intercept` menangguhkan coroutine di `CompletableDeferred`. Event `breakpoint_hit` dikirim ke Flutter. Keputusan datang lewat `bpResume` (dengan edit opsional) atau `bpAbort`. Bila tidak ada keputusan dalam batas waktu (default 120 detik), request dilanjutkan tanpa perubahan.

## Penyimpanan

| Tabel | Isi |
| --- | --- |
| traffic | satu baris per request, tunnel, atau kegagalan TLS, body disimpan sebagai blob dengan batas ukuran |
| rules | rewrite rule dalam JSON |
| breakpoints | definisi breakpoint dalam JSON |

Riwayat dipangkas ke `maxEntries` setiap 100 insert. Pengaturan ada di SharedPreferences (`SettingsStore`).

## API channel

MethodChannel `skytrace/api`:

| Metode | Keterangan |
| --- | --- |
| vpnPrepare, vpnStart, vpnStop, vpnStatus | siklus hidup VPN |
| requestNotifications | izin notifikasi Android 13 ke atas |
| trafficList, trafficDetail, trafficClear, trafficDelete, trafficCount | data traffic |
| facets, stats | filter dan statistik |
| replay, curlFor, export, shareFile | kirim ulang dan ekspor |
| certStatus, certEnsure, certRegenerate, certPem, certExport, certShare, certInstall | sertifikat |
| ruleList, ruleSave, ruleDelete, ruleToggle | rewrite rule |
| bpList, bpSave, bpDelete, bpToggle, bpPending, bpResume, bpAbort | breakpoint |
| settingsGet, settingsSet | pengaturan |
| appIcon, logs | ikon aplikasi dan log |

EventChannel `skytrace/events` mengirim JSON `{type, data}` dengan tipe `vpn_state`, `stats`, `traffic_new`, `traffic_update`, `breakpoint_hit`, `breakpoint_resolved`.

## Threading

| Komponen | Thread atau dispatcher |
| --- | --- |
| PacketReader | thread khusus, blocking |
| Sesi TCP dan engine | coroutine pada Dispatchers.IO, satu per koneksi |
| Socket upstream | `withContext(Dispatchers.IO)` untuk setiap read dan write |
| Room | suspend, Dispatchers.IO |
| Channel Flutter | hasil dikembalikan di main thread |

## Keamanan

- Kunci privat CA tersimpan di `filesDir/ca/ca.p12` yang privat bagi aplikasi.
- Paket SkyTrace sendiri dikecualikan dari VPN dan semua soket upstream memakai `protect()` agar tidak terjadi loop.
- Semua data traffic hanya ada di penyimpanan lokal perangkat.
- Ekspor dibagikan lewat FileProvider dengan izin baca sementara.

## Identitas visual

Lihat `docs/IDENTITY.md`.
