# 🥚 Steal an Egg — THORHUB EDITION (GRATIS, TANPA KEY)

Repo ini berisi script **Steal an Egg** yang sudah saya **audit total dari dalam** (dibongkar dari pembungkus Luraph Obfuscator v15.1), diverifikasi, lalu dibungkus ulang jadi versi **ThorHub** — bebas promosi + branding ThorUi:

- ✅ **TANPA KEY SYSTEM** — tidak ada lisensi, whitelist, HWID, atau gerbang kunci apa pun
- ✅ **TANPA TRACKING** — tidak ada pengiriman data ke server pembuat (beda dengan script repo lama yang ada beacon Firebase)
- ✅ **GRATIS SEPENUHNYA** — langsung jalan tanpa verifikasi apa pun

> Hasil audit lengkap ada di [docs/AUDIT-KEAMANAN.md](docs/AUDIT-KEAMANAN.md)
> Panduan semua fitur dalam Bahasa Indonesia: [docs/FITUR-LENGKAP.md](docs/FITUR-LENGKAP.md)

---

## ⚡ Versi CLEAN + THORHUB — Rebrand Petir Thor (REKOMENDASI)

Pakai `StealAnEgg-Clean.lua` untuk script yang jalan **tanpa unsur promosi apa pun** (link & tab Discord, tombol Venyx) **plus rebrand penuh ke ThorHub**: nama, icon petir ⚡, dan tema warna ThorUi:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/dwisetyabudi15581/StealAnEgg/main/StealAnEgg-Clean.lua"))()
```

**Cara kerjanya** (loader bisa kamu baca sendiri di repo, ±600 baris, berkomentar Bahasa Indonesia):

1. Script inti `StealAnEgg.lua` dijalankan **100% utuh** — semua fitur terjaga
2. Fetch link Discord dinamis (`.../spicy/DiscordLink`) & loader promo Venyx **diblokir di level HttpGet**
3. Tab "Discord & Venyx", tombol "Copy Discord Link" / "Try Venyx Now" / "Copy Venyx Loader" **disembunyikan dari UI** — dengan aturan presisi sehingga section fitur sah **"Discord Webhook" (webhook milikmu) tetap tampil normal**
4. Penyalinan link promo ke **clipboard dicegah**
5. **Rebrand ThorHub**: semua teks yang terlihat user ("Chilli Hub", "Chilli Library", dst.) ditulis ulang jadi **ThorHub** — internal identifier tidak disentuh supaya fitur tetap stabil
6. **Icon petir Thor**: icon lama (PNG chili) ternyata di-cache executor di `Venyx/mark1.png` / `Chilli Hub/VenyxMark1.png` — loader menulis PNG petir ⚡ ke path itu *sebelum* script jalan, jadi script memuat icon Thor secara alami
7. **Tema ThorUi**: palet chili (merah `#FF4848` / oranye `#FF963C`) dipetakan ke palet ThorUi (midnight blue `#0B0E17` + electric blue `#00C3FF` + lightning gold `#FFBE00`) di tingkat instance UI — layout & perilaku tidak berubah; warna status (hijau/merah error, rarity egg) sengaja dibiarkan supaya maknanya tetap benar
8. `queue_on_teleport` — setelah Auto Hop / Rejoin, **versi ThorHub yang jalan lagi otomatis**

> Kenapa reskin lewat loader, bukan ganti library UI-nya? Library UI "Venyx" ternyata **tertanam di dalam script** (bukan diunduh saat runtime) dan API-nya jauh lebih luas dari library biasa: canvas gambar bebas (Egg Predictor), Quick Bar, Pin Pad, HUD, sistem State persisten, tab dua sisi. Menu-library sederhana tidak bisa menggantikan semuanya tanpa mem-break fitur. Reskin eksternal ini memberi brand ThorHub dengan **garansi 100% fitur tetap jalan**. Bukti teknisnya di [docs/AUDIT-KEAMANAN.md](docs/AUDIT-KEAMANAN.md) bagian koreksi pasca-audit.

---

## 🚀 Loadstring — Versi Asli (tanpa rebrand, masih memuat tab promosi)

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
StealAnEgg-Clean.lua        ← VERSI CLEAN + THORHUB — loader rebrand petir (rekomendasi)
docs/
  FITUR-LENGKAP.md          ← Terjemahan & penjelasan semua fitur (Bahasa Indonesia)
  AUDIT-KEAMANAN.md         ← Laporan audit keamanan & metode pembongkaran
```

---

⚠️ *Gunakan dengan bijak — risiko ban akun tetap ada seperti semua script Roblox.*
