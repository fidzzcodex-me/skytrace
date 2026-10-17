# Changelog

Format mengikuti Keep a Changelog dan versi mengikuti Semantic Versioning.

## [1.5.0]

### Diubah

- Tema cloud dan sky diperkuat: langit yang bereaksi pada status capture di kartu hero Beranda (mendung, mencerah, cerah dengan awan bergeser, senja saat dijeda), garis cakrawala di AppBar, gradasi langit di latar, dan ilustrasi awan pada keadaan kosong
- Beranda dirapikan: hero menampilkan jumlah request besar dengan satu tombol Mulai atau Hentikan
- Kontras teks diperbaiki: teks sekunder memakai warna lebih gelap dan tombol teks memakai biru tua agar lolos AA
- Animasi masuk dan awan dihentikan bila pengaturan sistem menghapus animasi
- Dokumen identitas diperbarui dan ada tes otomatis untuk kontras teks di atas langit

## [1.4.0]

### Ditambahkan

- Jendela mengambang berisi seluruh aplikasi SkyTrace (traffic, detail, aturan, statistik, setelan). Ketuk bubble untuk membukanya, seret judul untuk memindahkan, seret pojok kanan bawah untuk mengubah ukuran, tombol kotak membuka aplikasi penuh, minus atau silang menutupnya. Posisi dan ukuran tersimpan. Default mati karena jendela ini menampilkan URL dan isi traffic; dinyalakan lewat Setelan, Bubble mengambang

## [1.3.0]

### Ditambahkan

- Bubble mengambang di atas aplikasi lain saat capture aktif. Bubble hanya menampilkan ikon dan badge jumlah request baru, tanpa URL atau isi traffic. Bisa digeser (posisi terakhir tersimpan dan menempel ke tepi layar), diketuk untuk panel mini (status, jumlah request, Stop capture, Buka SkyTrace), serta disembunyikan dengan tekan lama atau ditarik ke tanda X
- Pengecekan dukungan overlay berlapis: versi Android, jenis perangkat (TV, jam, mobil tidak didukung), izin "Tampilkan di atas aplikasi lain", dan uji nyata window manager. Hasilnya tampil di Setelan dan Diagnostik sebagai Didukung, Perlu izin, atau Tidak didukung di perangkat ini
- Bila tidak didukung, toggle dinonaktifkan dengan keterangan yang jelas dan aplikasi tetap berjalan normal

## [1.2.0]

### Ditambahkan

- Live Monitor: dashboard web di HP yang bisa dibuka dari browser PC di WiFi yang sama. Traffic tampil real-time lewat WebSocket, dengan filter, pencarian, detail, ekspor HAR dan cURL, serta hapus histori. Port bisa diubah, ada QR code, PIN 4 sampai 6 angka (disimpan sebagai hash), pembatasan percobaan PIN, sesi berakhir setelah 20 menit tidak aktif, dan hanya menerima koneksi dari jaringan lokal
- Hapus histori: per item, berdasarkan filter, atau semua, dari aplikasi maupun dari dashboard Live Monitor
- Deteksi kemungkinan certificate pinning dengan lencana dan saran di halaman detail
- Panduan optimasi baterai di Beranda dengan tombol langsung ke pengaturan sistem
- Jeda perekaman, tombol "N request baru" agar daftar tidak loncat saat di-scroll
- Salin sebagai Python, JavaScript fetch, Kotlin OkHttp, dan HTTPie
- Ekspor dan impor rules dan breakpoint dalam JSON
- Halaman Diagnostik untuk memeriksa CA, VPN lain, baterai, notifikasi, dan koneksi
- Flow control jendela TCP agar upload besar tidak menumpuk di memori
- Berkas LICENSE (MIT)

### Diubah

- Remote proxy kini hanya mendengarkan localhost secara default. Membuka ke perangkat lain harus dinyalakan di Setelan dan disarankan memakai password

## [1.1.0]

### Ditambahkan

- Metode capture kedua: Remote Proxy (HTTP dan HTTPS CONNECT) untuk aplikasi yang menolak VPN, dengan password opsional dan pilihan membuka port untuk perangkat lain
- Pemilih aplikasi target untuk mode VPN
- Daftar domain yang tidak di-intercept (mendukung wildcard)
- Popup update otomatis dari GitHub Releases, dengan opsi Unduh, Nanti, dan Lewati versi ini
- Tombol Periksa update di Setelan
- Navbar bawah baru: bar melayang dengan indikator animasi dan tombol power di tengah
- Setelan dipindah ke ikon gear di AppBar

## [1.0.0]

### Ditambahkan

- VPN lokal tanpa root dengan stack TCP dan UDP user-space
- Intersepsi TLS dengan CA lokal (BouncyCastle) dan fallback tunnel otomatis
- Daftar traffic real-time, detail, filter, pencarian, dan statistik
- Breakpoint request dan response dengan editor
- Rewrite rule: redirect, ubah header, ganti body, mock, delay
- Replay dan replay dengan edit
- Ekspor HAR, cURL, dan raw
- Onboarding dengan panduan sertifikat
- Notifikasi foreground dengan statistik
- Tema terang dan gelap, bahasa Indonesia dan Inggris
- Workflow GitHub Actions untuk build dan release bertanda tangan
