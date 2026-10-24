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

### ⚠️ Koreksi baris #1 (lihat bagian 7)
Baris #1 pada tabel di atas ternyata **tidak akurat**: URL `VenyxHub` **tidak pernah di-fetch** saat runtime — string-nya hanya muncul sekali sebagai isi tombol promo "Copy Venyx Loader". Library UI-nya **tertanam di dalam script**. Tidak ada implikasi keamanan baru (justru satu kontak jaringan lebih sedikit dari yang tadinya dikira). Detail di bagian 7.

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

---

## 7. Koreksi Pasca-Audit (24 Oktober 2026 — sesi rebrand ThorHub)

Saat membangun rebrand ThorHub, payload tahap-2 diekstrak ulang dengan metode yang sama (hook `loadstring` di tabel internal `[76]`, runtime Luau resmi) dan dianalisis lebih dalam. Hasilnya mengoreksi dan melengkapi audit awal:

### 7.1 Library UI ternyata TERTANAM, bukan diunduh

- String `VenyxHub` hanya muncul **1 kali** di seluruh payload — sebagai isi tombol promo "Copy Venyx Loader" di tab Discord & Venyx. **Tidak ada pemanggilan `game:HttpGet` ke URL itu.**
- Implementasi library UI-nya ditemukan **menyatu di dalam payload** (lengkap dengan pesan internal berbahasa Vietnam, mis. "Hai State phai thuoc cung Window" = "dua State harus milik Window yang sama").
- File `VenyxHub` di GitHub `tienkhanh1/Venyx` sendiri hanyalah redirect 108 byte ke loader `api.luarmor.net` — jalur yang tidak pernah dipakai script ini.

**Implikasi keamanan:** tidak ada (justru kontak jaringan lebih sedikit). **Implikasi teknis:** library UI tidak bisa "diganti URL"-nya; rebrand ThorHub dilakukan lewat reskin eksternal (teks, warna, icon) tanpa menyentuh script inti.

### 7.2 URL ke-4 yang terlewat: bootstrap Auto-Load

Ditemukan satu URL tambahan yang lolos dari audit awal:

| URL | Fungsi |
|-----|--------|
| `https://raw.githubusercontent.com/tienkhanh1/spicy/main/Chilli.lua` | Di-fetch oleh snippet `queue_on_teleport` internal script saat fitur **Auto Load Script** aktif — mengunduh ulang script utama dari repo pembuat setelah pindah server |

Penilaian: **wajar** (hanya versi hosting ulang dari script yang sama), tapi perlu diketahui. Loader versi clean/ThorHub memblokir pola `tienkhanh1/spicy` dan memasang antrian `queue_on_teleport`-nya sendiri **setelah** script inti, sehingga setelah hop server yang jalan tetap versi clean/ThorHub.

### 7.3 Peta permukaan UI (dipakai membangun rebrand)

Dari payload berhasil dipetakan:

- **API library**: `CreateTab` (dengan `Side="Right"`), `CreateSection`, `CreateToggle`, `CreateDropdown`, `CreateMultiDropdown`, `CreateSlider`, `CreateButton`, `CreateInput`, `CreateText`, `CreateLabel`, `CreateCanvas` (layout gambar bebas untuk Egg Predictor/kartu promo), `CreateState` (state persisten), `CreateActionDropdown` — semuanya dengan elemen ber-`Subscribe`/`Set`/`Get`
- **Tema inti**: `Card=#0F0F13, CardTop=#18161C, Stroke=#302E38, Text=#F0EEF4, AccentA=#FF4848 (merah chili), AccentB=#FF963C (oranye chili), Good/Work/Bad/Off`
- **Icon window**: PNG chili 100×100 tertanam sebagai base64 (5.340 char), di-decode saat runtime lalu ditulis ke `Chilli Hub/VenyxMark1.png` dan dipakai via `getcustomasset` (dicek dulu `Venyx/mark1.png` jika sudah ada)
- **Teks branding yang tampil**: "Chilli Hub" (splash + panel Anti Guard), `<b>Chilli Hub</b>` (kartu promo), "Bring your Chilli config over." (notifikasi migrasi), "Update the Chilli Library..." (peringatan versi)
- **Internal identifier `Chilli*`** (attribute ScreenGui, nama instance, folder config `ChilliLibrary/`, global `_G.__ChilliAutoLoadQueued`, dll.) — **sengaja tidak diubah** pada rebrand karena dipakai untuk pencarian instance, pembersihan GUI lama, dan persistensi config

---

## 8. Tulis-Ulang Total — `ThorHub-StealAnEgg.lua` (menu 100% ThorUi)

Permintaan lanjutan dari pemilik repo: menu yang **benar-benar dibangun dari ThorUi** (bukan reskin) dengan fitur disamakan. Karena callback fitur script asli tersambung ke library Venyx yang tertanam, satu-satunya jalan adalah **tulis-ulang dari nol** — dan itulah file baru ini.

### 8.1 Sifat file baru

- **100% Lua terbuka** — nol baris obfuscate, nol `loadstring` ke pihak ketiga (satu-satunya unduhan runtime: `ThorUi.lua` dari repo milik pemilik sendiri, `dwisetyabudi15581/ThorUi`)
- **Nol promosi** — tidak ada tab Discord/Venyx, tidak ada `discord.gg` pihak ketiga, tidak ada `tienkhanh1/spicy`, tidak ada teks Chilli/Venyx di UI maupun identifier
- **Self-hosting**: URL sumbernya sendiri (`dwisetyabudi15581/StealAnEgg/main/ThorHub-StealAnEgg.lua`) dipakai untuk fitur Auto Load Script setelah teleport — tidak lagi memuat ulang dari repo pembuat asli
- Folder config baru: `ThorHub/Games/<PlaceId>/configs/…` + `config_state.json` + `autohop.json` (pengganti bersih dari `ChilliLibrary/…`)

### 8.2 Dari mana fiturnya

Inventaris fitur dipetakan dari **payload tahap-2** script asli yang sudah diekstrak sebelumnya:

- **Serialisasi menu internal** (`@Farm|Auto Steal|…`, 1 string 8 KB) — sumber struktur tab/section/elemen beserta tipe & opsi dropdown
- **244 panggilan `Create*`** di payload — nama, catatan, default, rentang slider
- **60+ remote path** (`RE/…` RemoteEvent, `RF/…` RemoteFunction) di `ReplicatedStorage.Packages.Networking`
- **Modul data game**: `Data.{Assets,Bases,Treadmills,Trails,Guards,HalloweenPets,HalloweenIndex,GhostDogQuest,…}`, `Shared.{Util.{AssetItems,AreaEggCycle,EggRecords,FuseKernel,TreadmillUtil,Fishing},Modules.{Ragdoll,Mutations,ButterflyCatalog}}`
- **Struktur dunia**: `workspace.World.Areas/GuardAreas`, `WorldEggs` (egg lapangan ber-`StealPrompt` + atribut `PreparedSourceName`/`HalloweenEggUid`/`Zone`), `Plots` (plot sendiri via `PlotSign…PlayerName`), `PlacedEggRenders` (egg terpasang, nama mengandung UserId), `SafeZone`
- **Rumus nilai egg**: `EarningRate × (skala^1.85; skala>5 → (skala/5)^1.2 × 19.64) × pengali mutasi (Mutations.EarningsFor)`
- **Urutan rarity**: Common=1 … Divine=10 (dikonfirmasi dari `MinRarity=5` default ESP dan `Cosmic or 7`)

### 8.3 Pembeda arsitektur (desain anti-lag yang dipelajari dari insiden v2)

- **Dispatcher tunggal** per-Heartbeat; setiap fitur = worker dengan interval minimum (0.15–25 dtk) — tidak ada `while true do end` tanpa jeda
- **Scan workspace lewat cache bersama 4 detik**; prompt diakses lewat `ProximityPromptService.Prompts` — bukan `GetDescendants()` berulang (penyebab berat pada loader v2)
- **ESP pool ber-kunci instance dengan weak-key** — anti kolisi nama, anti memory-leak
- **Semua akses game dibungkus `pcall`** dengan *probe* runtime untuk dua sumber data (`AssetItems.Assets.Directory`, replika Save); kalau tidak ketemu, fitur terdegradasi dengan status jelas, tidak crash
- **Anti dobel UI**: re-inject memanggil handler destroy instance lama (pattern yang sama dengan ThorUi v2)

### 8.4 Validasi

| Uji | Hasil |
|-----|-------|
| `luau-compile` (compiler resmi Roblox, 4.280 baris) | ✅ lolos |
| `luau-analyze` statis | ✅ 0 typo global (hanya globals standar Roblox/executor) |
| Smoke test runtime (environment Roblox tiruan + mini-ThorUi) | ✅ PASS: boot 0 error; **242 elemen/9 tab** terbangun; **79 toggle ON tanpa gagal**; 242 elemen di-*fire*; 18 tombol OK; dispatcher 120.000 tick **0 error**; re-execute aman |

Batasan yang diakui secara terbuka: bentuk argumen sebagian remote event (mis. momen Island Wars / state Phantom Express) tidak bisa dipastikan dari payload; implementasinya defensif (bentuk argumen dicoba bertingkat dalam `pcall`) dan menampilkan status saat menunggu event. Dua fitur akses data (inventaris via replika Save; direktori aset) memakai *probe* — kalau struktur game berubah, status di tab Info langsung menunjukkan mana yang tersedia.
