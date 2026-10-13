# SkyTrace

SkyTrace adalah inspector traffic HTTP dan HTTPS open-source untuk debugging API milik sendiri di Android. Aplikasi membuat VPN lokal tanpa root, menangkap traffic perangkat, lalu menampilkannya secara real-time: lihat, jeda, ubah, dan kirim ulang request.

Tagline: Intercept, Inspect, Modify, Replay.

Stack: Kotlin (mesin VPN, proxy, TLS, database) dan Flutter (antarmuka). Target Android 8.0 sampai 15. Build lewat GitHub Actions.

## Fitur

1. Start dan stop VPN lokal dari satu tombol
2. Daftar request real-time (method, URL, status, ukuran, waktu, aplikasi)
3. Detail lengkap (header, body, response, timing, raw) dengan JSON tree view
4. Filter berdasarkan aplikasi, method, status, domain, content-type
5. Pencarian di URL, header, dan body
6. Breakpoint untuk menjeda request atau response lalu mengeditnya
7. Rewrite rule: redirect, ubah header, ganti body, mock response, delay
8. Replay request, langsung atau setelah diedit
9. Ekspor HAR, cURL, dan raw
10. Generate dan pasang sertifikat CA
11. Statistik per aplikasi, domain teratas, distribusi status dan waktu
12. Setelan: DNS, timeout, batas body, tema, bahasa
13. Notifikasi foreground dengan statistik langsung
14. Panduan pemasangan sertifikat saat onboarding

## Arsitektur singkat

```
+---------------------------------------------------------------+
| Flutter UI (Riverpod)                                         |
|  Home | Traffic | Rules | Stats | Settings | Detail           |
+----------------------+----------------------------------------+
                       | MethodChannel skytrace/api
                       | EventChannel  skytrace/events
+----------------------v----------------------------------------+
| Kotlin plugin: VpnPlugin                                      |
|  VpnServiceManager | TrafficRepository (Room) | CertManager   |
+----------------------+----------------------------------------+
                       |
+----------------------v----------------------------------------+
| SkyVpnService (TUN)                                           |
|  PacketReader -> TrafficRouter -> TcpSession / UdpRelay       |
+----------------------+----------------------------------------+
                       | byte stream per koneksi TCP
+----------------------v----------------------------------------+
| LocalProxyEngine                                              |
|  TlsInterceptor (SSLEngine + BouncyCastle) | HttpParser       |
|  RewriteEngine | BreakpointManager | WebSocketHandler         |
+----------------------+----------------------------------------+
                       | socket yang di-protect() ke upstream
                       v
                    Internet
```

Detail lengkap ada di `ARCHITECTURE.md`.

## Prasyarat

- Flutter stable (3.22 atau lebih baru)
- JDK 17
- Android SDK dengan platform 35
- Python 3 (hanya untuk skrip lint)

## Memulai secara lokal

1. Clone repository lalu masuk ke folder proyek.
2. Pasang Gradle wrapper. Folder `android/` di repo ini sengaja tidak menyertakan `gradle-wrapper.jar` karena file biner:

```
bash scripts/bootstrap.sh
```

3. Ambil dependensi dan jalankan:

```
flutter pub get
flutter run
```

4. Build APK:

```
flutter build apk --release
```

## Dua metode capture

| Metode | Kapan dipakai | Cara kerja |
| --- | --- | --- |
| VPN | Default. Menangkap traffic aplikasi yang dipilih atau semua aplikasi | VPN lokal tanpa root, semua TCP dan DNS lewat SkyTrace |
| Remote proxy | Aplikasi yang menolak berjalan saat VPN aktif | SkyTrace membuka proxy HTTP di port 8888. Atur proxy Wi-Fi perangkat ke alamat yang tampil di Beranda |

Pilih metode di Beranda (hanya bisa diganti saat capture mati). Pada mode proxy, perangkat lain di jaringan yang sama juga bisa memakai alamat itu. Kamu bisa mengunci proxy dengan password (`user:pass`) di Setelan. Aplikasi yang mengabaikan proxy sistem tidak akan tertangkap pada mode ini.

## Popup update

SkyTrace memeriksa rilis terbaru di GitHub setiap 12 jam. Yang dibaca adalah release resmi bertag (misalnya `v1.1.0`), bukan release "latest build" otomatis. Bila versi di GitHub lebih tinggi dari versi terpasang, muncul popup berisi catatan rilis dengan tombol Unduh, Nanti, dan Lewati versi ini. Alamat repo diatur di `lib/utils/app_config.dart`.

## Cara pakai

1. Buka SkyTrace dan ikuti onboarding.
2. Buat sertifikat CA dan pasang di perangkat (lihat bagian sertifikat).
3. Tekan tombol power di Beranda. Android akan meminta izin VPN satu kali.
4. Buka aplikasi yang ingin kamu debug. Request muncul di tab Traffic.
5. Ketuk satu request untuk melihat detail, kirim ulang, atau ekspor.

## Sertifikat CA dan aplikasi yang kamu debug

Sejak Android 7, aplikasi hanya mempercayai CA sistem. CA pengguna dipercaya hanya jika aplikasi memintanya. Untuk aplikasi milikmu, tambahkan konfigurasi berikut pada build debug (`res/xml/network_security_config.xml`):

```
<network-security-config>
  <debug-overrides>
    <trust-anchors>
      <certificates src="user" />
    </trust-anchors>
  </debug-overrides>
</network-security-config>
```

Lalu rujuk dari manifest dengan `android:networkSecurityConfig="@xml/network_security_config"`.

Memasang CA:

- Android 8 sampai 10: ketuk Pasang sertifikat di SkyTrace, beri nama, konfirmasi dengan PIN atau pola layar.
- Android 11 sampai 15: sistem tidak mengizinkan aplikasi memasang CA langsung. SkyTrace menyimpan `skytrace-ca.crt` ke folder Download lalu membuka pengaturan keamanan. Buka Keamanan lanjutan, Enkripsi dan kredensial, Pasang sertifikat, Sertifikat CA, lalu pilih `skytrace-ca.crt`.

Kunci privat CA hanya tersimpan di penyimpanan privat aplikasi.

## Build di GitHub Actions

### Build biasa

`build.yml` berjalan pada push ke `main`, pull request, dan manual dari tab Actions. Workflow menjalankan lint komentar, `flutter analyze`, `flutter test`, unit test Kotlin, lalu membangun APK debug, APK release, dan AAB. Hasilnya ada di bagian Artifacts pada halaman run.

### Kunci tanda tangan tetap (wajib agar update tidak konflik)

Android hanya mau menimpa aplikasi bila tanda tangannya sama. Kunci debug bawaan CI dibuat acak di setiap build, jadi tiap APK berbeda tanda tangan dan harus uninstall dulu. Solusinya satu kunci tetap yang dipakai semua build, dibuat sekali lewat GitHub dan tanpa komputer:

1. Buka Settings, Secrets and variables, Actions, New repository secret. Buat secret bernama `KEYSTORE_PASSWORD` berisi password acak minimal 12 karakter (disarankan 24 karakter). Simpan password itu di tempat aman.
2. Buka tab Actions, pilih workflow **Create signing key**, tekan Run workflow. Workflow membuat keystore, mengenkripsinya dengan password tadi (AES-256), lalu menyimpannya ke `android/signing/skytrace.keystore.enc`.
3. Mulai build berikutnya, semua APK (debug, release, dan latest) ditandatangani dengan kunci yang sama. Nomor build naik otomatis dari waktu, jadi APK baru selalu bisa menimpa yang lama.
4. Lakukan satu kali uninstall pada versi yang masih memakai kunci acak lama. Setelah itu update berjalan mulus.

Keamanan: file `.enc` aman di repo publik selama password kuat dan rahasia. Jangan pernah mengganti kunci (opsi force) kecuali terpaksa, karena semua perangkat harus uninstall lagi.

Cadangan: mekanisme lama dengan empat secret (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`) tetap didukung. Skrip `scripts/generate_keystore.sh` membuat keystore di komputer.

### Release bertanda tangan

Buat tag untuk membuat release resmi:

```
git tag v1.1.0
git push origin v1.1.0
```

`release.yml` menolak berjalan bila kunci belum dibuat. Hasilnya (APK, AAB, `SHA256SUMS.txt`) muncul di tab Releases dan menjadi sumber popup update di aplikasi.

## Contoh data

Request yang ditangkap (ringkas, format ekspor HAR):

```
{
  "request": {
    "method": "POST",
    "url": "https://api.example.com/v1/login",
    "headers": [{"name": "Content-Type", "value": "application/json"}],
    "postData": {"mimeType": "application/json", "text": "{\"user\":\"demo\"}"}
  },
  "response": {
    "status": 200,
    "statusText": "OK",
    "content": {"mimeType": "application/json", "text": "{\"token\":\"abc\"}"}
  },
  "timings": {"connect": 38, "ssl": 61, "send": 1, "wait": 112, "receive": 4}
}
```

Rewrite rule yang mengembalikan response palsu:

```
{
  "name": "mock users",
  "urlPattern": "*/v1/users*",
  "method": "GET",
  "action": "MOCK",
  "mockStatus": 200,
  "mockContentType": "application/json",
  "mockBody": "{\"users\":[]}"
}
```

Redirect ke server lokal (map remote):

```
{
  "name": "to dev server",
  "urlPattern": "*api.example.com*",
  "action": "REDIRECT",
  "redirectUrl": "http://10.0.2.2:8080"
}
```

Hasil ekspor cURL:

```
curl -X POST 'https://api.example.com/v1/login' \
  -H 'Content-Type: application/json' \
  --data-raw '{"user":"demo"}' \
  --compressed
```

## Troubleshooting

| Gejala | Penyebab umum | Solusi |
| --- | --- | --- |
| Request HTTPS muncul sebagai TUNNEL | Aplikasi menolak sertifikat SkyTrace atau memakai certificate pinning | Pasang CA, tambahkan konfigurasi debug-overrides pada aplikasimu, nonaktifkan pinning di build debug |
| Entri bermetode TLS dengan error handshake | Klien menolak CA | Sama seperti di atas. Koneksi berikutnya ke host itu otomatis diteruskan tanpa dekripsi |
| Tidak ada traffic sama sekali | Private DNS atau VPN lain aktif | Matikan Private DNS di pengaturan jaringan dan pastikan hanya SkyTrace yang memakai VPN |
| Tombol start gagal | Izin VPN ditolak | Ketuk lagi dan setujui dialog VPN |
| Aplikasi gRPC atau HTTP/2 only gagal | Mesin memakai HTTP/1.1 | Gunakan mode TUNNEL untuk host itu atau matikan Intercept TLS di setelan |
| Aplikasi HTTP/3 terasa lambat saat awal | QUIC diblokir agar jatuh ke TCP | Normal. Fallback butuh satu sampai dua detik |
| Nama aplikasi tampil sebagai uid | Android tidak mengembalikan paket untuk uid itu | Biasa terjadi untuk proses sistem |
| Build gagal: flutter.sdk not set | `local.properties` belum ada | Jalankan `flutter pub get` |
| Build gagal: gradle wrapper | Wrapper jar belum dipasang | Jalankan `bash scripts/bootstrap.sh` |
| Release gagal: KEYSTORE_BASE64 secret is missing | Secret belum dibuat | Ikuti langkah keystore di atas |

## Batasan yang perlu kamu tahu

- Mesin memakai HTTP/1.1. Klien yang memaksa HTTP/2 atau gRPC tidak bisa di-intercept.
- IPv6 tidak ditangkap. Query DNS AAAA dijawab kosong agar aplikasi memakai IPv4.
- UDP selain DNS diteruskan apa adanya tanpa dekripsi.
- Pengaturan port tidak ada karena traffic dihentikan langsung di dalam proses (tidak ada listener lokal).
- Body besar dipotong sesuai batas pada setelan. Ukuran asli tetap dicatat.

## Struktur proyek

```
skytrace/
  .github/workflows/   build.yml, release.yml
  android/             proyek Android (Kotlin)
  assets/logo/         logomark, vertikal, horizontal, dark
  docs/                IDENTITY.md
  lib/                 aplikasi Flutter
  scripts/             bootstrap, keystore, lint
  test/                test Dart
```

## Lisensi

Pilih lisensi open-source sebelum publikasi (misalnya Apache-2.0 atau MIT) dan tambahkan file `LICENSE`.
