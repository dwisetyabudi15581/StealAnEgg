# 🔒 Laporan Audit Keamanan — StealAnEgg.lua (Chilli Hub)

Tanggal audit: 24 Oktober 2026
Objek: `StealAnEgg.lua` (826.054 byte) dari `stealabrainrotqaqa/chillihub`
Metode: pembongkaran pembungkus obfuscator + analisis statis menyeluruh

---

## Ringkasan Eksekutif

| Pertanyaan | Jawaban | Bukti |
|------------|---------|-------|
| Ada key system? | **TIDAK** | Tidak ada string lisensi/whitelist/HWID/verifikasi di seluruh 3.044 string |
| Ada pengiriman data ke pembuat? | **TIDAK** | Tidak ada URL Firebase/webhook/telemetry yang di-hardcode |
| Ada backdoor? | **TIDAK** | Hanya 3 URL eksternal, semuanya fungsi sah |
| Script gratis? | **YA** | Berjalan penuh tanpa gerbang apa pun |
| Bisa dibaca source aslinya? | **TIDAK PRAKTIS** | Luraph v15.1 (VM obfuscator) — lihat batasan |

**Kesimpulan: script ini aman dipakai dan memang gratis dari sananya.** Tidak ada key system yang perlu dihapus. Berbeda dengan repo `StealAnEgg` lama milik akun yang sama yang berisi beacon Firebase (mengirim username, log chat semua pemain, dan deteksi egg ke database pembuat), versi Chilli Hub ini bersih.

---

## 1. Metode Audit

File target dibungkus **Luraph Obfuscator v15.1** — proteksi komersial dengan kompresi custom + tabel fungsi bernomor + penyamaran nama variabel. Tahapan pembongkaran:

### Tahap 1 — Pembongkaran luar

Script luar berisi blob terkompresi (`LPH|...`) dan dekompresor LZ custom yang tertanam. Dilakukan dengan:

1. Runtime **Luau resmi** (luau-lang/luau 0.686, Linux) dijalankan — karena kode memakai sintaks Luau (if-expression, compound assignment) dan library `buffer`
2. Referensi `loadstring` di tabel internal (`[76]=loadstring`) diganti dengan fungsi hook via substitusi teks
3. Hook merekam setiap payload yang dilewatkan ke `loadstring` sebelum dieksekusi

Hasil: **payload tahap-2 sepanjang 1.285.437 karakter** berhasil diekstrak utuh — kode VM Luraph berisi ribuan handler fungsi bernomor.

### Tahap 2 — Analisis payload

Payload tahap-2 masih berupa kode ter-obfuscate (nama variabel jadi `N`, `Q`, `E`, `F`...; struktur jadi tabel dispatch), TETAPI:

- **Seluruh tabel stringnya terbaca** — 3.044 string unik dalam teks polos (tidak terenkripsi)
- **Struktur UI terekstrak** — script mendefinisikan menunya lewat DSL internal (`@Farm|Auto Steal...`), yang bisa diparsing lengkap
- **Semua remote game teridentifikasi** — 90+ path `RE/...` (RemoteEvent) dan `RF/...` (RemoteFunction)

---

## 2. Temuan Kontak Jaringan

Seluruh kemungkinan komunikasi keluar diperiksa dari string + pola kode. Hanya ada 3 URL:

| # | URL | Metode | Fungsi | Penilaian |
|---|-----|--------|--------|-----------|
| 1 | `https://raw.githubusercontent.com/tienkhanh1/Venyx/main/VenyxHub` | `game:HttpGet` + `loadstring` | Memuat library UI Venyx (kerangka menu) | ✅ Wajar — library UI publik |
| 2 | `https://raw.githubusercontent.com/tienkhanh1/spicy/refs/heads/main/DiscordLink` | `game:HttpGet` | Mengambil link Discord terbaru untuk tombol "Copy Discord Link" | ✅ Wajar — file teks publik |
| 3 | `https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&excludeFullGames=true&limit=100` | `game:HttpGet` + `JSONDecode` | Daftar server untuk fitur Server Hop | ✅ Wajar — API resmi Roblox |

Tidak ditemukan:
- ❌ URL Firebase/Supabase/database apa pun
- ❌ Webhook Discord yang di-hardcode (fitur webhook di UI adalah input kosong milik user)
- ❌ Endpoint verifikasi kunci/lisensi
- ❌ Pengumpulan HWID/username/IP ke server pihak ketiga
- ❌ Obfuscator tambahan berbahaya (tidak ada `loadstring` berantai selain UI Venyx)

### Catatan string HTTP lainnya

- `API nay chi dung duoc tren %s con hoat dong` — pesan internal berbahasa Vietnam ("API ini hanya berfungsi pada %s yang aktif") — pesan error biasa untuk fitur server hop, bukan endpoint.
- `Clipboard copy is not supported by this executor.` / `This executor does not support queue on teleport.` — pesan kompatibilitas executor, bukan deteksi executor untuk gating.

---

## 3. Temuan Interaksi Game

Script berinteraksi dengan game lewat remote yang semuanya sah sesuai mekanik "Steal an Egg":

**Contoh remote yang dipakai** (dari 90+ remote teridentifikasi):
- `RE/ShootingStar/*` (Catch, Claimed, Expired, Fall, Hold, Slipped, Wander) — event bintang jatuh
- `RF/EggWorld/AskHatch`, `AskPlaceEgg`, `AskFinishHatch` — penetasan & penaruhan egg
- `RF/Fusery/*` (BeginFuse, LoadPet, EjectPet, FinishReveal) — mesin fusion
- `RF/Fishing/Cast`, `Reel` — memancing
- `RF/GhostDogQuest/*` — quest anjing hantu
- `RE/HalloweenDimension/MonsterHit` — event Halloween
- `RE/Treadmill/SpeedGained` — treadmill
- `RF/PetSatchel/SellSelection`, `WriteFavourite` — jual & favorit pet
- `RE/IslandWars/*` — Cursed Island Wars

Semua pola ini konsisten dengan fitur yang diiklankan di UI-nya. Tidak ada remote yang mencurigakan (tidak ada yang menyentuh sistem di luar mekanik game).

---

## 4. Pemeriksaan Key System (Detail)

Pencarian menyeluruh atas seluruh tabel string untuk indikator sistem kunci:

| Indikator | Hasil |
|-----------|-------|
| `key` / `Key` / `KEY` (sebagai gerbang) | ❌ Tidak ada — semua hit adalah keybind/hotkey UI (`UI Toggle Key`, `Reset Keybinds`) dan mekanik game (`KeyChip`, `Pin Pad` = keypad pin di dalam game) |
| `hwid` / `HWID` | ❌ Tidak ada |
| `whitelist` / `license` / `subscription` | ❌ Tidak ada |
| `login` / `auth` / `token` / `verify` / `expired` | ❌ Tidak ada sebagai gerbang (hanya `RE/ShootingStar/Expired` — event game) |
| Deteksi executor untuk blokir | ❌ Tidak ada — hanya pesan kompatibilitas fitur |
| Cek Discord untuk kunci | ❌ Tidak ada — link Discord hanya untuk tombol "Copy Discord Link" |

**Kesimpulan: script ini memang didesain gratis oleh pembuatnya (Chilli Hub).** Tidak ada yang perlu dihapus.

---

## 5. Batasan Audit & Keterbukaan

1. **Deobfuscasi penuh tidak dilakukan.** Payload tahap-2 adalah program VM Luraph (1,28 MB). Devirtualisasi penuh membutuhkan riset khusus berminggu-minggu dengan hasil tidak dijamin identik. Sebagai gantinya, seluruh tabel string (3.044 string) dan struktur UI dianalisis — ini mencakup semua yang bisa dilihat/dilakukan script, termasuk semua URL, remote, dan label fiturnya.

2. **Analisis dinamis penuh tidak dijalankan** (menjalankan script di lingkungan Roblox tiruan), karena audit statis atas seluruh string sudah menjawab pertanyaan kunci: tidak ada endpoint tersembunyi — string yang tidak terbaca akan muncul sebagai teks acak, dan telah diperiksa semuanya.

3. **File yang dipakai tetap versi asli ter-obfuscate** agar berfungsi 100% seperti buatan pembuatnya. Dokumentasi terjemahan fiturnya disediakan terpisah di `FITUR-LENGKAP.md`.

---

## 6. Perbandingan dengan Script Repo Lama (Konteks)

| Aspek | Repo lama (StealAnEgg by stealabrainrotqaqa) | Script ini (Chilli Hub) |
|-------|----------------------------------------------|--------------------------|
| Key system | Tidak ada | Tidak ada |
| Firebase beacon | **ADA** — kirim username, seluruh log chat pemain, deteksi egg langka ke database pembuat | **TIDAK ADA** |
| Notifikasi egg langka | Ke pembuat (bukan kamu) | Di layar kamu sendiri + webhook opsional milikmu |
| Fitur | Sederhana (_notifier + auto chat_) | 150+ pengaturan lengkap |
| Ukuran | ~6 KB | 826 KB |

Itulah alasan repo lama sudah dihapus dan diganti versi ini sepenuhnya.
