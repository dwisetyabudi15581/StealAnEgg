# 📖 Panduan Lengkap Fitur — Steal an Egg (Chilli Hub)

Dokumen ini adalah **terjemahan dan penjelasan lengkap** dari semua fitur di dalam script, diekstrak langsung dari kode tersembunyinya. Setiap toggle, slider, dan dropdown dijelaskan dalam Bahasa Indonesia supaya kamu tahu persis apa yang kamu jalankan.

Script memakai UI **Venyx** dengan struktur: **Tab → Section → Pengaturan**.

---

## 🟢 TAB 1: FARM (Fitur Utama)

### Auto Steal — Mencuri Egg Otomatis

Fitur inti script ini. Karakter kamu akan otomatis berjalan/tween ke egg yang lolos filter, mengambilnya, lalu membawanya pulang ke base.

| Pengaturan | Penjelasan |
|------------|-----------|
| **Auto Steal** | Mengaktifkan pencurian otomatis — membaca daftar egg area dari snapshot server (`RF/EggWorld/AskFieldEggSnapshot`), lalu terbang ke egg dan menembak prompt `SmartPromptPart.CarryAreaEgg` terdekat, seperti script asli |
| **Steal Panel** | Panel melayang tambahan: daftar semua item yang bisa dicuri (egg area dari snapshot server + egg event Halloween + egg di base pemain lain) dengan nama/area/rarity/nilai/jarak/pemilik; klik baris = kunci item jadi target prioritas, tombol Steal = curi langsung; otomatis terbuka saat Auto Steal ON (versi ThorHub) |
| **Target Areas** | Pilih zona mana saja yang di-scan (misal hanya zona tertentu) |
| **Min Rarity** | Rarity minimal egg yang mau dicuri — pasang `Eternal`/`Divine` biar cuma kejar egg langka |
| **Min Steal Value** | Nilai jual minimal egg yang mau dicuri (angka, satuannya per detik /s) |
| **Target Specific Eggs** | Pilih jenis egg spesifik yang mau dicuri saja |
| **Steal Missing Index Eggs** | Cuma curi egg yang belum ada di Index/koleksi kamu |
| **Drop Eggs At Safe Zone** | Setelah mencuri, egg dijatuhkan di zona aman biar tidak bisa direbut balik |
| **Steal Priority** | Urutan prioritas kalau ada beberapa egg sekaligus: Best Rarity / Biggest Weight / Best Mutation / Highest Value / Lowest Value |
| **Instant Steal** (V1) | Antar egg ke safe zone dalam beberapa detik lewat lompatan steps — "Delivers the egg to the safe zone in a few seconds, needs enough Speed" |
| **Instant Steal Steps** | Jumlah titik lepas-tengah saat mode steps (1–6, default 3) — "Higher is safer but takes longer" |
| **Fast Delivery** | Antar pakai fast tween Instant Steal V2 alih-alih steps — untuk V1 |
| **Instant Steal V2** | Fast tween 3000–4500 studs/s; saat dinyalakan muncul dialog konfirmasi berisi FPS & ping kamu (pola asli) |
| **Move To Egg** | Cara menuju egg saat V2 aktif: Teleport (satu lompatan penuh) / Step (rantai langkah) |
| **V2 Tween Speed** | Kecepatan fast tween (3000–4500, default 3300) |
| **Instant Steal Zones** | Zona tempat V2 dipakai: Titan Temple / Light Dark / Enchanted Forest (default semua) |
| **Teleport To Egg** (V3) | Rantai teleport: teleport ke egg → grab (tembak prompt tiap 0.08 dtk, 3 ronde) → teleport ke Star Handler / belt Admin Treadmill sambil bawa egg → belt mengantarkan ke safe zone |

Rarity di game ini dari rendah ke tinggi: `Common → Uncommon → Rare → Epic → Legendary → Mythic → Cosmic → Secret → Eternal → Divine`

### Shooting Star — Bintang Jatuh

| Pengaturan | Penjelasan |
|------------|-----------|
| **Auto Catch Shooting Star** | Otomatis tangkap bintang jatuh yang bisa menjatuhkan egg/pet langka |

### Butterfly Bloom — Event Kupu-kupu

| Pengaturan | Penjelasan |
|------------|-----------|
| **Auto Butterfly Bloom** | Ikut event Butterfly Bloom otomatis |
| **Catch Mode** | Mode penangkapan kupu-kupu |
| **Catch Priority** | Kupu-kupu mana yang diprioritaskan |
| **Catch Butterflies** | Pilih jenis kupu-kupu yang mau ditangkap |
| **Tween Speed** | Kecepatan gerak saat menangkap |
| **Auto Trade Up** | Otomatis tukar kupu-kupu naik tier |
| **Trade Up Tiers** | Tier mana saja yang ikut ditukar |
| **Smart Trade For Essence** | Tukar kupu-kupu jadi essence secara cerdas |
| **Auto Craft Essence** | Otomatis crafting essence |

### Wisp & Banjo Cricket

| Pengaturan | Penjelasan |
|------------|-----------|
| **Auto Wisp** | Kerjakan quest Wisp otomatis |
| **Auto Banjo Cricket** | Ikut event Banjo Cricket otomatis |

### Auto Mutation — Mutasi Egg/Pet

| Pengaturan | Penjelasan |
|------------|-----------|
| **Auto Mutate** | Otomatis pakai item mutasi ke egg/pet |
| **Mutations To Use** | Pilih item mutasi yang dipakai (Golden, Silver, Rainbow, Boss, Monstrous, Sakura, GreatBloom) |
| **Mutate Min Rarity** | Rarity minimal yang boleh dimutasi |
| **Mutate Min Value** | Nilai minimal yang boleh dimutasi |
| **Mutate Target Eggs** | Target egg spesifik untuk dimutasi |
| **Mutate Priority** | Urutan mutasi: Highest Value / Best Rarity / Biggest Size |

### Auto Place Egg — Menaruh Egg

| Pengaturan | Penjelasan |
|------------|-----------|
| **Auto Place Egg** | Otomatis menaruh egg di base biar menghasilkan uang |
| **Place Egg Rule** | Kapan menaruh: Always / Steal Idle / After Steal / Night Only |
| **Place Egg Order** | Urutan penaruhan: Biggest Size / Highest Value / Smallest Size |
| **Place Rarities** | Rarity egg mana yang ditaruh |
| **Place Specific Eggs** | Jenis egg spesifik yang ditaruh |
| **Min Place Value** | Nilai minimal egg yang ditaruh |

### Auto Treadmill — Treadmill (Alat Lari)

| Pengaturan | Penjelasan |
|------------|-----------|
| **Auto Treadmill** | Otomatis naik treadmill untuk naikkan speed |
| **Auto Upgrade Treadmill** | Otomatis upgrade level treadmill |
| **Use Admin Treadmill** | Pakai treadmill admin (lebih cepat) |

### Auto Hatch & Equip — Menetaskan & Melengkapi Pet

| Pengaturan | Penjelasan |
|------------|-----------|
| **Auto Hatch** | Otomatis menetaskan egg |
| **Hatch Min Rarity** | Rarity minimal egg yang ditetaskan |
| **Min Hatch Value** | Nilai minimal egg yang ditetaskan |
| **Hatch Specific Eggs** | Jenis egg spesifik yang ditetaskan |
| **Auto Equip Best** | Otomatis pasang pet terbaik setelah menetas |

### Auto Sell — Jual Otomatis

| Pengaturan | Penjelasan |
|------------|-----------|
| **Auto Sell Pet** | Otomatis jual pet sesuai filter |
| **Pet Max Rarity** | Jual pet di bawah rarity ini (misal: jual semua di bawah Legendary) |
| **Pet Sell Value** | Jual pet yang nilainya di bawah angka ini |
| **Keep Mutated Pets** | Jangan jual pet yang sudah termutasi |
| **Blacklist Sell Pets** | Pet yang tidak boleh dijual walau apa pun |
| **Auto Sell Egg** | Otomatis jual egg sesuai filter |
| **Egg Max Rarity** | Jual egg di bawah rarity ini |
| **Egg Sell Value** | Jual egg yang nilainya di bawah angka ini |
| **Keep Mutated Eggs** | Jangan jual egg termutasi |
| **Blacklist Sell Eggs** | Egg yang tidak boleh dijual |
| **Sell Eggs Now / Sell Pets Now** | Tombol jual sekali putaran sekarang |

### Auto Fuse Machine — Mesin Fusion

| Pengaturan | Penjelasan |
|------------|-----------|
| **Auto Fuse Machine** | Otomatis menggabungkan pet di mesin fusion |
| **Fuse Priority Mode** | Urutan fusion: Lowest/Highest Rarity, Most Copies, Lowest Value |
| **Pets To Use** | Pet mana yang dipakai bahan fusion |
| **Max Rarity to Fuse** | Batas rarity pet yang boleh difuse |
| **Specific Species to Fuse** | Spesies pet spesifik untuk difuse |
| **Skip Mutated Pets** | Lewati pet termutasi saat fusion |
| **Eject Incomplete Slots** | Keluarkan pet dari slot yang belum lengkap |

### Auto Favorite — Favorit Otomatis

| Pengaturan | Penjelasan |
|------------|-----------|
| **Auto Favorite Pet** | Otomatis tandai pet jadi favorit (biar tidak terjual) |
| **Favorite Rule** | Aturan pencocokan: Match Any / Match All |
| **Favorite Min Rarity** | Rarity minimal yang di-favoritkan |
| **Min Favorite Value** | Nilai minimal yang di-favoritkan |
| **Always Favorite Species** | Spesies yang selalu di-favoritkan |
| **Auto Favorite Equipped** | Favoritkan pet yang sedang dipakai |

---

## 🟠 TAB 2: ADMIN ABUSE (Event Admin)

Fitur untuk momen event admin di server (admin spawn egg istimewa).

| Pengaturan | Penjelasan |
|------------|-----------|
| **Auto Capture Event Egg** | Otomatis rebut egg yang di-spawn admin |
| **Take It From The Holder** | Rebut langsung dari pemain yang memegangnya |
| **Hold Height** | Ketinggian memegang egg saat dibawa |
| **Keep Away Distance** | Jaga jarak dari pemain lain saat memegang egg |
| **Use Admin Treadmill** | Pakai treadmill saat admin abuse aktif |
| **Auto Steal Minigame Egg** | Rebut egg dari minigame otomatis |
| **Auto Steal Halloween Eggs / Instant Steal Halloween Eggs** | Versi Halloween-nya |
| **Steal Missing Halloween Index** | Cuma curi egg Halloween yang belum ada di index |

Fitur Halloween lain yang tersedia: Auto Buy Halloween Dimension Egg, Auto Vacuum Ghouler Boss, Auto Pumpkin Moon, Auto Phantom Express, Auto Ghost Dog Quest, Auto Trade Souls, Auto Play Cursed Island Wars.

---

## 🔵 TAB 3: PLAYER (Karakter & Visual)

### ESP — Melihat Melalui Dinding

| Pengaturan | Penjelasan |
|------------|-----------|
| **ESP Eggs** | Tandai egg di lapangan (chams + info) |
| **ESP Fixed Size** | Ukuran teks ESP tetap walau jauh |
| **ESP Min Rarity** | Filter rarity minimal egg yang di-ESP |
| **ESP Show Info** | Info yang ditampilkan: Icon, Name, Rarity, Value, Mutation, Size, Weight, Area, Sell Price, Distance, State |
| **ESP Own Base Eggs** | ESP egg di base sendiri |
| **ESP Other Base Eggs** | ESP egg di base pemain lain |
| **ESP Guards** | ESP posisi guard/pengawas (biar tidak ketahuan) |
| **ESP Players** | ESP pemain lain |
| **ESP Player Info** | Info pemain yang ditampilkan |
| **ESP Egg/Guard/Player Size** | Ukuran masing-masing ESP |

### Movement — Gerakan

| Pengaturan | Penjelasan |
|------------|-----------|
| **Speed Boost** | Kecepatan jalan dinaikkan |
| **Boost Speed** | Seberapa cepat (slider) |
| **Infinite Jump** | Lompat tanpa batas di udara |

### Character — Proteksi Karakter

| Pengaturan | Penjelasan |
|------------|-----------|
| **Invisibility** | Karakter jadi tidak terlihat |
| **Anti Ragdoll** | Tidak bisa di-ragdoll (dijatuhkan) pemain lain |
| **Anti Trap** | Kebal jebakan yang dipasang pemain lain |
| **Instant Prompts** | Prompt/interaksi jadi instan tanpa tahan tombol |
| **Anti AFK** | Tidak di-kick karena idle |

### Combat — Pertaruran

| Pengaturan | Penjelasan |
|------------|-----------|
| **Auto Hit Nearest Player** | Pukul otomatis pemain terdekat (untuk melumpuhkan pembawa egg) |
| **Auto Hit Egg Holders** | Prioritaskan pukul pemain yang memegang egg |
| **Hit Player** | Target siapa yang dipukul |
| **Hit Aura** | Pukul semua yang masuk radius |
| **Hit Tween Speed** | Kecepatan mengejar target |
| **Hit Lead** | Prediksi arah larinya target |
| **Hit Max Speed / Hit Sweep** | Batas kecepatan dan sapuan pukulan |
| **Carry Speed** | Kecepatan saat memanggul egg |
| **Walk Speed** | Kecepatan jalan dasar |

---

## 🟣 TAB 4: PREDICTOR (Prediktor & Notifikasi)

### Egg Predictor — Prediksi Egg

| Pengaturan | Penjelasan |
|------------|-----------|
| **Sort By** | Urutan daftar prediksi: Value / Rarity / Time Left |
| **Preview Card** | Tampilkan kartu preview egg yang akan spawn |
| **Egg Card Image** | Gaya gambar kartu |

Script memonitor event game (`RE/LiveEvents/Began`, `RE/ShootingStar/*`, dsb.) dan memprediksi egg apa yang akan muncul beserta sisa waktunya.

### Discord Webhook — Notifikasi ke Discord Kamu

| Pengaturan | Penjelasan |
|------------|-----------|
| **Webhook URL** | Isi webhook Discord **milik kamu sendiri** (kosong = tidak ada notifikasi) |
| **Ping @everyone** | Notifikasi menyebut @everyone |
| **Notify On** | Event apa yang dikabari |
| **Webhook Min Rarity** | Rarity minimal yang dikabarkan |
| **Webhook Min Value** | Nilai minimal yang dikabarkan |

> ⚠️ Ini murni fitur untukmu — script TIDAK punya webhook pembuat yang tersembunyi (sudah diverifikasi di audit).

---

## 🟤 TAB 5: PROGRESS (Kemajuan Otomatis)

| Pengaturan | Penjelasan |
|------------|-----------|
| **Auto Buy Trail** | Beli trail otomatis saat uang cukup |
| **Auto Upgrade Base** | Upgrade level base otomatis |
| **Auto Upgrade Treadmill** | Upgrade treadmill otomatis |
| **Auto Claim** | Klaim hadiah offline cash otomatis |
| **Auto Claim Index** | Klaim hadiah index/koleksi otomatis |
| **Auto Equip Best** | Pasang pet terkuat otomatis |
| **Auto Farm Monsters** | Bunuh monster otomatis untuk hadiah |
| **Monsters To Kill** | Pilih monster yang diburu (Candy Corn, Hollow Bat, Scarecrow, Chest Mimic, Pumpkin Golem, Soul Phantom) |
| **Monster Order** | Urutan prioritas monster |
| **Auto Fishing** | Memancing otomatis |
| **Auto Buy Trail** | Beli trail otomatis |

---

## ⚪ TAB 6: SERVER (Server & Hop)

| Pengaturan | Penjelasan |
|------------|-----------|
| **Auto Load Script** | Script otomatis jalan lagi saat pindah/teleport server |
| **Server Hop Mode** | Mode hop: Least Players (server sepi) / Most Players / Random |
| **Auto Rejoin When Disconnect** | Masuk lagi otomatis saat koneksi putus atau di-kick |
| **Auto Hop** | Pindah server otomatis sampai ketemu egg sesuai kriteria |
| **Hop Mode** | Kapan hop: Until An Egg Matches / Steal Then Hop / After A Rare Spawns |
| **Rarity To Wait For** | Rarity yang dicari sebelum berhenti hop |
| **First Hop Delay** | Jeda sebelum hop pertama |
| **Server Hop / Rejoin Server** | Tombol manual |
| **Join Job ID** | Masuk server spesifik lewat Job ID |
| **Copy Current Job ID** | Salin Job ID server sekarang |

Server hop memakai API resmi Roblox (`games.roblox.com/v1/games/.../servers/Public`) — aman dan standar.

---

## ⚫ TAB 7: MISC (Performa & Tampilan)

| Pengaturan | Penjelasan |
|------------|-----------|
| **FPS Cap** | Batasi FPS biar hemat baterai/PC |
| **Optimizer** | Turunkan grafis ke paling rendah |
| **FPS and Ping** | Tampilkan HUD FPS & ping |
| **Disable 3D Render** | Matikan render 3D (untuk farming AFK berat) |
| **Background Color** | Warna latar saat render dimatikan |
| **Hide Game UI** | Sembunyikan semua UI game |
| **UI Toggle Key** | Tombol buka/tutup menu (bisa di-custom) |
| **UI Size** | Ukuran window menu |
| **Notifications** | Notifikasi on-screen dari script |
| **Farm HUD** | HUD statistik farming (egg tercuri, dll.) |
| **HUD Size / HUD Items** | Ukuran dan isi HUD |
| **Open On Launch** | Menu terbuka otomatis saat script jalan |

---

## 🟡 TAB 8: QUICK (Bar Cepat & Keybind)

| Pengaturan | Penjelasan |
|------------|-----------|
| **Quick Bar** | Bar fitur cepat di layar (bisa pin fitur favorit) |
| **Quick Keybinds** | Hotkey fitur tanpa buka menu |
| **Enable Keybinds** | Master switch semua hotkey |
| **Reset Keybinds** | Reset hotkey ke default |
| **Pin Pad** | Panel pin fitur yang sering dipakai |
| **Show Pin Pads / Pin & Key List / Reset Pins** | Atur pin panel |
| **Visible Quick Bars** | Bar mana yang tampil |
| **Add/Remove Hits On Quick Bar 2** | Tambah toggle combat ke bar 2 |

---

## 🔴 TAB 9: CONFIG (Pengaturan Tersimpan)

| Pengaturan | Penjelasan |
|------------|-----------|
| **Save Config / Create New Config** | Simpan pengaturan ke file config |
| **Load Config** | Muat config tersimpan |
| **Auto Load Config** | Config otomatis dimuat saat script jalan |
| **Set Startup Config** | Jadikan config default permanen |
| **Import Config / Import Config Text** | Tempel config dari teks |
| **Export Config** | Salin config ke clipboard |
| **Delete Config** | Hapus config |
| **Reset to Defaults / Turn Off All Toggles** | Reset semuanya / matikan semua fitur sekaligus |

Config tersimpan per-akun dan per-game otomatis.

---

## ⚪ TAB 10: DISCORD & VENYX (Komunitas)

- **Copy Discord Link** — salin link komunitas Chilli Hub (`discord.gg/CJK4bs2mgT`), diambil dinamis dari file `DiscordLink` milik pembuat supaya selalu ter-update
- **Try Venyx Now / Copy Venyx Loader** — promo library UI Venyx yang dipakai script ini

---

## 📊 Cheat Sheet Filter Cepat

**Mau farming uang aman:**
1. Auto Steal ON — Min Rarity: `Epic`
2. Auto Sell Egg/Pet ON — Max Rarity: `Epic`
3. Auto Place Egg ON
4. FPS Cap: 30 + Optimizer ON (hemat)

**Mau berburu egg legendaris:**
1. Auto Steal ON — Min Rarity: `Eternal`
2. Auto Hop ON — Hop Mode: `Until An Egg Matches`, Rarity To Wait For: `Eternal`
3. Webhook URL diisi (kalau mau notifikasi ke Discord kamu)
4. ESP Eggs ON biar kelihatan dari jauh

**Mau AFK total:**
1. Semua Auto ON
2. Anti AFK ON
3. Auto Rejoin ON
4. Disable 3D Render ON
5. Auto Load Script ON
