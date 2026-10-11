# Identitas visual SkyTrace

Dokumen ini merangkum keputusan desain yang dipakai di `lib/theme`. Nilai berasal dari brief dan papan logo, bukan dari default framework.

## Arah

Langit cerah: biru lembut, putih, ruang napas besar. Aplikasi terasa ringan walau datanya padat. Logo awan dengan panah melengkung menjadi sumber bentuk: busur tipis dan sudut membulat.

## Token

| Token | Nilai | Pemakaian |
| --- | --- | --- |
| primaryBlue | 4A90E2 | aksi utama, ikon aktif |
| softSky | E8F4FD | latar chip aktif, divider, permukaan sekunder |
| cloudWhite | FFFFFF | kartu dan latar |
| accentBlue | 87CEEB | gradien tombol, busur dekoratif |
| deepBlue | 2C5F9E | teks penekanan, status 3xx |
| textDark | 1A2B4A | teks utama |
| textMuted | 7A8FA6 | teks sekunder |
| successGreen, warningAmber, errorRed | 4CAF50, FFB300, E53935 | status |

Jarak: halaman 16, antar kartu 12. Radius: kartu 16, kontrol 12, dialog 20. Gerak: 250 sampai 400 ms dengan easeOutCubic. Seluruh token ada di `lib/theme/colors.dart`. Widget membaca warna lewat `context.palette` sehingga mode gelap ikut otomatis.

## Tipografi

Plus Jakarta Sans (400, 500, 600, 700) dengan cadangan Inter lalu Poppins. Teks teknis memakai monospace.

## Elemen penanda

Dua hal yang membuat SkyTrace dikenali tanpa logo:

1. Rel status: setiap baris request punya rel vertikal 4 dp di kiri dengan warna status. Daftar panjang bisa dipindai dari warna saja.
2. Busur jejak: tiga busur tipis konsentris dari motif logo, dipakai di kartu hero beranda, splash, onboarding, dan halaman tentang.

## Penempatan logo

| Tempat | Varian |
| --- | --- |
| Splash | vertikal, tengah, latar gradien langit |
| Onboarding | logomark di atas, vertikal di halaman pertama |
| AppBar beranda | logomark tinggi 28 dp, kiri |
| Tentang | vertikal besar, tengah |
| Ikon aplikasi | adaptive icon dari logomark |

Logo tidak pernah diregangkan dan selalu diberi ruang minimal 16 dp.

## Gerak

Fade in dan naik pelan untuk kartu, stagger 40 ms (maksimal 12 item), geser dari kanan untuk halaman detail, skala masuk untuk dialog, hero untuk logo, shimmer untuk loading daftar. Tidak ada animasi pada item daftar setelah 10 baris pertama supaya scroll tetap ringan.

## Aturan tegas

- Tanpa emoji di UI, kode, komentar, dan dokumentasi
- Semua ikon memakai Font Awesome
- Tanpa komentar di dalam kode (`scripts/lint_no_comments.py` memeriksanya di CI)
