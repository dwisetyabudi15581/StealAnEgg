# 🥚 Steal an Egg — Script Chilli Hub (GRATIS, TANPA KEY)

Repo ini berisi script **Steal an Egg** buatan Chilli Hub yang sudah saya **audit total dari dalam** (dibongkar dari pembungkus Luraph Obfuscator v15.1) dan diverifikasi:

- ✅ **TANPA KEY SYSTEM** — tidak ada lisensi, whitelist, HWID, atau gerbang kunci apa pun
- ✅ **TANPA TRACKING** — tidak ada pengiriman data ke server pembuat (beda dengan script repo lama yang ada beacon Firebase)
- ✅ **GRATIS SEPENUHNYA** — langsung jalan tanpa verifikasi apa pun

> Hasil audit lengkap ada di [docs/AUDIT-KEAMANAN.md](docs/AUDIT-KEAMANAN.md)
> Panduan semua fitur dalam Bahasa Indonesia: [docs/FITUR-LENGKAP.md](docs/FITUR-LENGKAP.md)

---

## 🧼 Versi CLEAN — Tanpa Promosi (REKOMENDASI)

Pakai `StealAnEgg-Clean.lua` kalau mau script jalan **tanpa unsur promosi apa pun** (link & tab Discord, tombol Venyx, branding Chilli Hub / Venyx):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/dwisetyabudi15581/StealAnEgg/main/StealAnEgg-Clean.lua"))()
```

**Cara kerjanya** (loader bisa kamu baca sendiri di repo, ±290 baris, berkomentar Bahasa Indonesia):

1. Script inti `StealAnEgg.lua` dijalankan **100% utuh** — semua fitur terjaga
2. Fetch link Discord dinamis (`.../spicy/DiscordLink`) **diblokir di level HttpGet** — link promo tidak pernah diunduh
3. Tab "Discord & Venyx", tombol "Copy Discord Link" / "Try Venyx Now" / "Copy Venyx Loader", dan semua branding **disembunyikan dari UI**
4. Penyalinan link promo ke **clipboard dicegah**
5. `queue_on_teleport` — setelah Auto Hop / Rejoin, **versi clean yang jalan lagi otomatis**

> Yang diblokir dari jaringan **hanya** file promo & invite Discord. Unduhan library UI Venyx dan API server Roblox tetap diizinkan supaya semua fitur berfungsi normal. Pola blokirnya bisa diedit di bagian `KONFIGURASI` paling atas file.

---

## 🚀 Loadstring — Versi Asli (masih memuat tab promosi)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/dwisetyabudi15581/StealAnEgg/main/StealAnEgg.lua"))()
```

Jalankan di game **Steal an Egg** (GameId: `10563114921`). Bisa dipakai di Delta, Solara, Wave, Cryptic, dan executor lain yang mendukung `loadstring` + `game:HttpGet`.

---

## 📋 Kenapa Ada File .lua yang Tetap Terenkripsi?

Kode aslinya diproteksi **Luraph Obfuscator v15.1** — obfuscator komersial berbasis VM yang mengubah kode menjadi 1,28 MB instruksi mesin virtual. Membongkarnya 100% ke bentuk source asli secara praktis **tidak mungkin** (butuh riset devirtualisasi berminggu-minggu dan hasilnya pun tidak sempurna).

Yang saya lakukan sebagai gantinya:

1. **Membongkar pembungkus kompresinya** — payload tersembunyi diekstrak utuh (file 1,28 MB)
2. **Membaca seluruh tabel string-nya** — 3.044 string unik berhasil dibaca dan dianalisis (label UI, URL, remote game, pesan-pesan)
3. **Memetakan struktur UI-nya** — semua tab, toggle, slider, dan dropdown berhasil diekstrak dari DSL internal script
4. **Mengaudit keamanannya** — memastikan tidak ada key system, tidak ada pencurian data
5. **Menerjemahkan semuanya ke Bahasa Indonesia** — lihat [docs/FITUR-LENGKAP.md](docs/FITUR-LENGKAP.md), di situ semua fitur dijelaskan sehingga bisa dibaca manusia

Jadi file `StealAnEgg.lua` tetap dalam bentuk terenkripsi **karena memang begitu bentuk aslinya dari pembuatnya** — tetapi isi dan perilakunya sudah terbaca lengkap dan terdokumentasi. Script berjalan normal apa adanya tanpa perlu diubah.

---

## 🎮 Cara Pakai

1. Buka game **Steal an Egg** di Roblox
2. Buka executor kamu, tempel loadstring di atas, tekan Execute
3. UI **Venyx** akan muncul (library UI yang diunduh otomatis oleh script)
4. Buka tab **Farm** untuk fitur utama (Auto Steal, Auto Hatch, Auto Sell, dst.)
5. Atur filter sesuai selera — misal `Min Rarity: Eternal` untuk auto steal egg Eternal saja

### Fitur Highlight

| Kategori | Fitur |
|----------|-------|
| 🥚 Steal | Auto Steal (filter zona/rarity/nilai/prioritas), Instant Steal V1-V3, Steal Missing Index |
| 🐛 Event | Shooting Star, Butterfly Bloom, Wisp, Banjo Cricket, Halloween lengkap, Ghost Dog Quest, Phantom Express |
| 🔄 Otomasi | Auto Hatch + Equip, Auto Sell pet & egg, Auto Fuse, Auto Mutate, Auto Place Egg, Auto Treadmill |
| 👁️ ESP | ESP egg, ESP pemain, ESP guard, ESP base sendiri/orang, info lengkap (rarity, nilai, jarak) |
| ⚔️ Combat | Auto Hit, Hit Aura, Hit Sweep/Lead, target pemain/pembawa egg |
| 🏃 Movement | Speed Boost, Infinite Jump, Invisibility, Anti Ragdoll/Trap/AFK |
| 🌐 Server | Auto Hop pintar (cari egg langka antar server), Auto Rejoin saat koneksi putus |
| ⚙️ Optimasi | FPS Cap, Disable 3D Render, Optimizer grafis, Hide Game UI |
| 🔔 Notifikasi | Discord Webhook sendiri (opsional), Egg Predictor, HUD FPS/Ping |
| 💾 Config | Save/Load/Import/Export pengaturan, Startup Config otomatis |

Daftar lengkap 150+ pengaturan: [docs/FITUR-LENGKAP.md](docs/FITUR-LENGKAP.md)

---

## 🔍 Ringkasan Audit Keamanan

Script hanya melakukan 3 jenis kontak jaringan, semuanya wajar:

| URL | Fungsi |
|-----|--------|
| `raw.githubusercontent.com/tienkhanh1/Venyx/main/VenyxHub` | Mengunduh library UI Venyx (kerangka tampilan menu) |
| `raw.githubusercontent.com/tienkhanh1/spicy/refs/heads/main/DiscordLink` | Mengambil link Discord komunitas terbaru |
| `games.roblox.com/v1/games/.../servers/Public` | API resmi Roblox untuk fitur server hop |

Fitur **Discord Webhook** di dalam script adalah **input kosong milik kamu** — kalau tidak kamu isi, script tidak mengirim apa pun ke mana pun. Tidak ada webhook yang di-hardcode.

Detail lengkap metode pembongkaran dan temuan: [docs/AUDIT-KEAMANAN.md](docs/AUDIT-KEAMANAN.md)

---

## 📁 Struktur Repo

```
StealAnEgg.lua              ← Script utama (jalan apa adanya, tanpa key)
StealAnEgg-Clean.lua        ← VERSI CLEAN — loader tanpa promosi (rekomendasi)
docs/
  FITUR-LENGKAP.md          ← Terjemahan & penjelasan semua fitur (Bahasa Indonesia)
  AUDIT-KEAMANAN.md         ← Laporan audit keamanan & metode pembongkaran
```

---

## 🙏 Kredit

- Script asli: **Chilli Hub** (tienkhanh1) — script gratis komunitas
- Sumber: [stealabrainrotqaqa/chillihub](https://github.com/stealabrainrotqaqa/chillihub)
- Repo ini: mirror + audit + dokumentasi Bahasa Indonesia

⚠️ *Gunakan dengan bijak — risiko ban akun tetap ada seperti semua script Roblox.*
