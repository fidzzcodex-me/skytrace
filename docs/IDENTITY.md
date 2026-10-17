# Identitas visual SkyTrace

Dokumen ini mengikuti kerangka identitas dari skill desain: inti merek, wilayah visual, token dengan peran, elemen penanda, gerak, aksesibilitas, lalu audit. Seluruh nilai tinggal di `lib/theme`.

## Inti merek

| Pertanyaan | Jawaban |
| --- | --- |
| Siapa pemakainya | Developer Android yang men-debug API miliknya sendiri, sering di HP, sering sambil memegang aplikasi lain |
| Apa janjinya | Melihat, menjeda, mengubah, dan mengirim ulang traffic dengan tenang dan jernih |
| Kepribadian | Ringan, jernih, presisi, tenang, dapat diandalkan |
| Apa yang bukan | Gelap, bising, penuh glow ala alat peretasan. SkyTrace alat kerja yang rapi |
| Satu kalimat | Alat debugging yang terasa seperti langit cerah: datanya padat, suasananya tidak |

## Wilayah visual

Kata kunci: awan putih, biru langit, garis cakrawala, busur tipis dari logo, ruang napas, data padat tapi tenang.

Yang dihindari: gradien ungu, efek neon, kaca buram di mana-mana, ikon dalam lingkaran berwarna tanpa fungsi, bayangan hitam pekat.

## Token (peran, bukan sekadar warna)

| Peran | Token | Nilai | Catatan |
| --- | --- | --- | --- |
| Aksi utama, ikon aktif | primaryBlue | 4A90E2 | tidak dipakai untuk teks kecil (kontras 3,3:1) |
| Teks penekanan, tombol teks | deepBlue | 2C5F9E | kontras 6,9:1 di atas putih |
| Permukaan sekunder, divider | softSky | E8F4FD | |
| Permukaan utama | cloudWhite | FFFFFF | |
| Aksen gradien, busur | accentBlue | 87CEEB | |
| Teks utama | textDark | 1A2B4A | |
| Teks sekunder | textSecondary | 5A6E87 | kontras 5,2:1 di putih, 4,7:1 di softSky |
| Ikon nonaktif saja | textMuted | 7A8FA6 | tidak dipakai untuk teks karena kontras 3,3:1 |
| Status | successGreen, warningAmber, errorRed | 4CAF50, FFB300, E53935 | selalu disertai teks atau ikon, bukan warna saja |

Skala jarak: 4, 8, 12, 16 (halaman), 12 (antar kartu). Radius: 12 kontrol, 16 kartu, 20 dialog. Gerak: 250, 320, 400 ms dengan easeOutCubic. Mode gelap memakai palet malam (`AppPalette.dark`) dan langit malam di `AppSky`.

## Tipografi

Plus Jakarta Sans (400, 500, 600, 700) dengan cadangan Inter lalu Poppins. Skala: display 32, title 20, heading 16, body 14, caption 12, label 11. Angka besar memakai angka tabular supaya tidak bergoyang saat berubah. Teks teknis memakai monospace.

## Elemen penanda

Tiga hal yang membuat SkyTrace dikenali tanpa logo, masing-masing punya fungsi:

1. **Langit yang bereaksi pada status.** Kartu hero di Beranda adalah langit. Mendung saat capture mati, mencerah saat memulai atau berhenti, cerah dengan awan yang bergeser pelan saat menangkap traffic, senja saat perekaman dijeda. Pemakai membaca status dari suasana sebelum membaca teks.
2. **Rel status.** Setiap baris request punya rel vertikal 4 dp berwarna status, sehingga daftar panjang bisa dipindai dari warna.
3. **Busur jejak dan cakrawala.** Busur tipis dari logo dipakai di dalam langit. Garis cakrawala bergradasi memisahkan AppBar dari isi. Awan menjadi bentuk dasar ilustrasi keadaan kosong.

## Gerak

- Fade dan naik pelan untuk kartu, stagger 40 ms (maksimal 12 item)
- Awan bergeser dalam siklus 90 detik dan hanya berjalan saat tab terlihat. Ticker berhenti otomatis di tab yang tidak aktif sehingga hemat baterai
- Peralihan suasana langit memakai pencampuran warna 400 ms
- Bila pengaturan sistem "hapus animasi" aktif, semua animasi masuk dihentikan dan awan diam

## Aksesibilitas

- Semua teks di atas langit diuji otomatis untuk kontras minimal 4,5:1 pada empat suasana dan dua tema (`test/theme_test.dart`)
- Teks sekunder memakai `textSecondary`, bukan `textMuted`
- Tombol teks memakai deepBlue
- Status tidak pernah hanya berupa warna

## Audit

| Uji | Hasil |
| --- | --- |
| Uji buta (tanpa logo, apakah terlihat seperti SkyTrace) | Langit status, rel status, dan cakrawala membedakannya dari aplikasi Material bawaan |
| Uji gantian (ganti font dan palet, apakah masih terasa sama) | Tidak lolos penuh: identitas bergantung pada palet biru langit dan awan, bukan hanya pada font. Itu disengaja |
| Uji hapus (buang dekorasi, apakah ada yang hilang fungsinya) | Langit membawa status, rel membawa status, busur dan cakrawala murni dekorasi ringan dan boleh dibuang di mode hemat |

Catatan jujur: audit ini dikerjakan dari kode dan perhitungan kontras, bukan dari tangkapan layar perangkat. Kerapian visual sebenarnya perlu dicek di HP.

## Penempatan logo

| Tempat | Varian |
| --- | --- |
| Splash | vertikal di atas langit cerah |
| Onboarding | logomark dan vertikal di atas langit yang mulai cerah |
| AppBar | logomark tinggi 28 dp |
| Tentang | vertikal besar di atas langit |
| Ikon aplikasi dan bubble | logomark |

Logo tidak diregangkan dan selalu diberi ruang minimal 16 dp.

## Aturan tegas

- Tanpa emoji di UI, kode, dan dokumentasi
- Semua ikon Font Awesome
- Tanpa komentar di dalam kode (`scripts/lint_no_comments.py` memeriksanya di CI)
