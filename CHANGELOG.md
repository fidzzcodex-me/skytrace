# Changelog

Format mengikuti Keep a Changelog dan versi mengikuti Semantic Versioning.

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
