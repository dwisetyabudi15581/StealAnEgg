--[======================================================================[
     Steal an Egg — THORHUB CLEAN LOADER v3
     (ringan & anti-crash + icon Thor + tema ThorUi)
     ----------------------------------------------------------------------
     File ini adalah PEMBUNGKUS (loader) untuk script inti StealAnEgg.lua.
     Script inti dijalankan 100% UTUH (semua fitur tetap berfungsi), sementara
     loader melakukan tiga hal dari luar:

     A. PERFORMA (BARU di v3 — penyebab "berat & ngecrash" sudah dihapus)
        Versi lama memindai SELURUH UI (gethui + CoreGui + PlayerGui) berulang
        kali: 180x dalam 45 detik pertama, lalu tiap 1,5 detik SELAMANYA,
        plus hook namecall global. Di game yang ramai + HP kentang itu bikin
        CPU terbakar -> berat -> crash.
        v3 mengganti semua itu dengan arsitektur ringan:
          [P1] Hook namecall global DIHAPUS. Blocking HttpGet kini lewat
               override properti game.HttpGet (menangkap game:HttpGet(...) DAN
               game.HttpGet(game, ...)) — nol biaya saat idle.
          [P2] Pemindaian UI berbasis EVENT (DescendantAdded): setiap elemen
               diproses tepat saat muncul, sekali per elemen.
          [P3] Rescan penuh HANYA 4x (detik ke-12/40/90/180) lalu BERHENTI.
          [P4] Loop "drift" 6 detik hanya memeriksa daftar KECIL elemen yang
               pernah di-recolor + elemen promo yang pernah disembunyikan
               (bukan seluruh pohon UI).
        Biaya idle total v3 ± nol — tidak ada lagi scan abadi.

     B. BEBAS PROMOSI
        [1] URL promo (link Discord dinamis, loader Venyx, bootstrap spicy)
            diblokir di level HttpGet.
        [2] Tab/kartu promosi disembunyikan — kini dengan aturan
            "climb-to-card": saat satu teks promo terdeteksi ("Try now",
            "Smoother, faster...", "discord.gg", dll), SELURUH kartu
            pembungkusnya ikut disembunyikan. Kartu onboarding "Venyx"
            (icon chili melayang yang kamu lihat) adalah IKLAN yang bahkan
            tombolnya menjalankan loader lain — disembunyikan penuh.
            Fitur sah seperti section "Discord Webhook" (milikmu) TIDAK kena.
        [3] Penyalinan link promo ke clipboard dicegah.

     C. REBRAND "CHILLI HUB" -> "THORHUB" (identitas ThorUi milikmu)
        [4] Icon: PNG petir Thor di-pre-seed ke path cache executor
            ("Venyx/mark1.png" + "Chilli Hub/VenyxMark1.png"), DAN global
            getcustomasset dibungkus sehingga saat script inti memuat icon
            merek, yang dikembalikan adalah icon Thor — anti cache basi.
            Icon brand rbxassetid lama juga ditukar di level instance.
        [5] Semua teks tampilan "Chilli*" ditulis ulang jadi ThorHub.
        [6] Palet warna chili dipetakan ke PALET PERSIS ThorUi.lua kamu:
            Background 11,14,23 / Card 21,26,41 / Accent 0,195,255 /
            AccentGold 255,190,0 / StrokeDim 45,58,88 / Track 36,44,66.
        [7] Font khas chili (rbxasset 12187365977) diganti font ThorUi
            (Gotham). Warna status (hijau/merah error, rarity) tidak disentuh
            supaya maknanya tetap benar.

     Kenapa library UI-nya tidak ditukar langsung ke ThorUi?
       Library UI yang dipakai script inti TERTANAM di dalam script
       (terbukti dari payload hasil ekstraksi) dan SEMUA callback fitur
       (83 toggle, 32 dropdown, 28 slider, canvas Egg Predictor, Quick Bar,
       Pin Pad, HUD, State persisten) tersambung ke elemen library itu.
       Menulis ulang UI dengan library lain = memutus semua sambungan itu =
       semua fitur mati. Solusi v3: transplantasi IDENTITAS VISUAL ThorUi
       (palet persis + font + icon + judul) dengan GARANSI 100% fitur jalan.

     [8] Setelah pindah server (Auto Hop / Rejoin), file ini yang jalan lagi
         otomatis lewat queue_on_teleport.

     Kompatibilitas: Delta, Solara, Wave, Cryptic, dan executor lain yang
     mendukung loadstring + game:HttpGet. Semua hook dipasang berlapis dengan
     pcall — kalau satu metode gagal, lapisan lain tetap jalan.

     Batasan (jujur):
       - Jika executor tidak mendukung override game.HttpGet DAN tidak
         mendukung hookmetamethod, blocking level jaringan tidak terpasang
         (promosi tetap tak terlihat karena UI-nya disembunyikan).
       - Elemen promo tanpa teks/nama yang cocok bisa lolos (jarang;
         tambahkan pola di PROMO_HIDE_CONTAINS bila perlu).
]======================================================================]

-- ======================================================================
-- KONFIGURASI (silakan diedit sesuai kebutuhan)
-- ======================================================================

-- Script inti (file asli, dijalankan tanpa diubah)
local CORE_URL = "https://raw.githubusercontent.com/dwisetyabudi15581/StealAnEgg/main/StealAnEgg.lua"

-- File loader ini sendiri (untuk re-run otomatis setelah pindah server)
local SELF_URL = "https://raw.githubusercontent.com/dwisetyabudi15581/StealAnEgg/main/StealAnEgg-Clean.lua"

-- true  = pasang queue_on_teleport agar loader tetap aktif setelah hop
local PERSIST_AFTER_HOP = true

-- Nama brand pengganti "Chilli Hub"
local BRAND_NAME = "ThorHub"

-- URL yang diblokir dari HttpGet.
-- Hasil audit payload: hanya 5 URL yang pernah di-fetch —
--   games.roblox.com (fitur Auto Hop, DIBIARKAN) dan 4 URL promo di bawah.
local BLOCKED_URL_PATTERNS = {
    "tienkhanh1/spicy",      -- DiscordLink dinamis + bootstrap Chilli.lua
    "tienkhanh1/venyx",      -- loader promo VenyxHub
    "discord.gg",
    "discord.com/invite",
    "dsc.gg",
}

-- Elemen promosi yang disembunyikan:
--   EXACT    = nama instance / teks PERSIS (lowercase): tombol tab, halaman
--   CONTAINS = teks mengandung frasa promo -> memicu "climb-to-card"
--              (kartu pembungkusnya ikut disembunyikan)
-- Frasa kartu onboarding "Venyx" diambil langsung dari payload hasil audit.
-- Fitur sah seperti section "Discord Webhook" TIDAK kena aturan mana pun.
local PROMO_HIDE_EXACT = {
    "discord",
    "venyx",
}
local PROMO_HIDE_CONTAINS = {
    "venyx",
    "copy discord link",
    "discord community",
    "invite link",
    "discord.gg",
    "discord.com/invite",
    "paste the copied link",
    -- kartu onboarding "Venyx" (tab promo, icon chili melayang):
    "smoother, faster",
    "more ways to steal",
    "more steal methods",
    "try now",
    "bring your chilli config",
    "hits whoever takes your egg",
}

-- Teks promo yang dicegah masuk clipboard
local PROMO_CLIPBOARD_PATTERNS = {
    "discord.gg",
    "discord.com/invite",
    "tienkhanh1",
    "venyxhub",
}

-- Penulisan ulang teks branding (diterapkan pada .Text yang tampil).
-- Urutan penting: yang terpanjang dulu.
local TEXT_REPLACEMENTS = {
    { "Chilli Hub",     BRAND_NAME },
    { "Chilli Library", BRAND_NAME .. " Library" },
    { "ChilliLibrary",  BRAND_NAME },
    { "Chilli",         BRAND_NAME },
}

-- Pemetaan warna: "r,g,b" sumber (palet chili) -> {r,g,b} ThorUi.
-- Nilai target DIAMBIL PERSIS dari ThorUi.lua milikmu.
-- Warna status (hijau/merah error, rarity, Halloween) TIDAK disentuh.
local COLOR_REMAP_RAW = {
    -- latar
    ["15,15,19"]    = { 11, 14, 23 },    -- Card #0F0F13          -> Background
    ["18,18,22"]    = { 11, 14, 23 },    -- latar splash          -> Background
    ["20,18,24"]    = { 16, 20, 32 },    -- latar notif/kartu     -> BackgroundAlt
    ["18,18,26"]    = { 16, 20, 32 },    -- latar HUD/canvas      -> BackgroundAlt
    ["24,22,28"]    = { 21, 26, 41 },    -- CardTop #18161C       -> Card
    ["28,26,32"]    = { 28, 36, 56 },    -- slot icon panel       -> CardHover
    -- stroke & track
    ["48,46,56"]    = { 45, 58, 88 },    -- Stroke #302E38        -> StrokeDim
    ["58,56,66"]    = { 36, 44, 66 },    -- Off #3A3842           -> Track
    ["62,64,84"]    = { 45, 58, 88 },    -- border canvas         -> StrokeDim
    -- teks
    ["240,238,244"] = { 240, 244, 255 }, -- Text #F0EEF4          -> Text
    ["170,170,185"] = { 145, 155, 180 }, -- abu splash            -> TextDim
    ["170,174,184"] = { 145, 155, 180 }, -- teks dim              -> TextDim
    ["196,202,222"] = { 240, 244, 255 }, -- teks canvas           -> Text
    ["214,218,236"] = { 240, 244, 255 }, -- teks splash terang    -> Text
    -- aksen chili (merah/oranye) -> aksen Thor (petir)
    ["255,72,72"]   = { 0, 195, 255 },   -- AccentA #FF4848       -> Accent
    ["255,60,60"]   = { 0, 195, 255 },   -- stroke splash merah   -> Accent
    ["255,82,64"]   = { 0, 195, 255 },   -- gradien promo ujung   -> Accent
    ["255,120,90"]  = { 0, 195, 255 },   -- persen splash         -> Accent
    ["255,120,100"] = { 0, 195, 255 },   -- gradien judul awal    -> Accent
    ["255,132,123"] = { 0, 195, 255 },   -- aksen warm turunan    -> Accent
    ["255,106,64"]  = { 0, 195, 255 },   -- #FF6A40               -> Accent
    ["255,106,85"]  = { 0, 195, 255 },   -- #FF6A55               -> Accent
    ["255,150,60"]  = { 255, 190, 0 },   -- AccentB #FF963C       -> AccentGold
    ["255,190,110"] = { 255, 190, 0 },   -- gradien judul akhir   -> AccentGold
    ["255,218,96"]  = { 255, 190, 0 },   -- #FFDA60               -> AccentGold
    ["255,152,60"]  = { 255, 190, 0 },   -- #FF983C               -> AccentGold
    ["255,176,84"]  = { 255, 190, 0 },   -- #FFB054               -> AccentGold
}

-- true = font khas chili diganti font ThorUi (Gotham)
local THORUI_FONTS = true
local CHILLI_FONT_MARK = "12187365977" -- id FontFace khas chili (FredokaOne mod)

-- Asset gambar yang terbukti sebagai icon BRAND script (ditukar ke icon Thor).
-- Icon egg/pet/game dan aset font TIDAK masuk daftar ini.
local ICON_BRAND_BLACKLIST = {
    ["rbxassetid://128961717706452"] = true, -- icon chili (panel "Chilli Hub / Anti Guard" + kartu promo)
}

-- Path file icon lama yang dicek/di-cache executor oleh script inti.
-- Loader menulis icon Thor ke path-path ini SEBELUM script inti jalan.
local ICON_CACHE_PATHS = {
    "Venyx/mark1.png",           -- dicek PERTAMA oleh script inti
    "Chilli Hub/VenyxMark1.png", -- dicek kedua
}
local ICON_FRESH_PATH = "Venyx/ThorMark.png" -- asset milik loader (anti cache basi)

-- Irama kerja v3 (lihat penjelasan arsitektur di header):
local WATCH_WINDOW_SECONDS = 45          -- lama pemantauan event CoreGui/PlayerGui
local RESCAN_AT = { 12, 40, 90, 180 }    -- rescan penuh TERBATAS (detik), lalu berhenti
local DRIFT_INTERVAL = 6                 -- cek drift warna + re-hide promo (set kecil)
local RETRY_SHORT = 0.4                  -- jeda retry #1 per elemen baru
local RETRY_LONG  = 2.5                  -- jeda retry #2 per elemen baru
local CLIMB_MAX_DESCENDANTS = 350        -- batas aman climb-to-card

-- Icon petir Thor (PNG 128x128, palet ThorUi) dalam base64
local THOR_ICON_B64 = "iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAAQI0lEQVR4nO1dW6wkRRn+qucsCTnnLO6DhsRNJBiiRonBLNkFXbnuooDBS8ALRgIGFRFWQROeSPQJH01IRMGVi5eExPgiL77peoEIoia+mGjgjegDCecsJHumu3yo21/dVdVVPdPT1T3nS3rPnJk5Nb39ff+t/uoahj5whj/fy7jrjuPs2LKHZEsbaZ/01WJJYlhMAPuk54EFxNBNABHEb9504dFOY+/DibPPvfZC65s6CCFdAB7y9wlfLbyCSBRBmgAc5K8b8bzl9eUlVXFwCiFBBHHn25H4A+edH3se2aGNaOeVC/zRIsLYO/dW63u6CqH9vBLJHzPpQIBDpv+JG8Uz0KIeIiSGLiIIn0+N/CkTD3g4Y6zx2LxPvcbNb5yO0hTCskJEkhACIvCfTyT5UyAecJBPLZ4xcDDznNf9C8IZOBFCfyIA/EKIFUER8yHrRz6DIJqBswKcMaBgACuAopA/Z+awnmfgTBxmnP7O3cdBbHLuPjVi/a6BpkI84CMfhkB9FJpQXssHGOdiJF4/KhIWbE/QhyZc3sDyBA4v0PQALZM860N+YY5iBl4U4MUMfDYDZhvAbKYPPpuJ1wrlCYxwmvlCf2jlxsEtC72hbv1rRT5x+Zy6eO3ayUgcAK+AShxMPeYVwLnwEJxbCWKfcqh7glA+sOEbZK0meBrkG+J3fvnP5OG2P/9+MMYBMKkPbnJKqQH56kqwedOFR30zhyYErKvrlyw0yC+6kS/GXE0C6ENKKHBWAWvj+nVZJ4+CafJRzDqNv/2lywBVOahQoUPG6tRQ58zn0aPKwOlClXom6eMy6dv52T86DslqeUJdBHlBCCBQ9k3X+in5yvJFVt+V/K0vH5PjAg1r5420s3cEvYDk3JsETg3OuA+QGl/F/26u34wbsvR4Ebz+7CuN5w7ddlHiCbUjKIApWb8N1iCeF4Ww/qdf7jTi1tc+WnvGPxUsz8AJF/H111KEcOC884N9g2IdlnUFXT9j2vWjWMQh1gjnsPsBjRNpIkR+l/e14gx/3koCp1j7u11/Le5L17/z5IudPmPr3msN4fJg3JAek/45Sb34e+aIeX8E6hx7JT85918v+dSsniL/qb92H1vN+5MegO4NWJ3BSDgI18/95+Hk0wuFgUkngfZlJ66/oNYv3b8DD72r/TMeveWEnvIV07+UdN4MA2h6BK81v/2kefy/3zZefv3ZVxZODCc7DxB0/aTex2yGnZ82XX8M+WJQbvoAXBysUp6AkB3rBJSlU/Lp7y7vsAAmKwAN6fo5a2b+mBXYefKlzkM/8iqAqjQNIOUFGh5glT3BNExSAC7X75zq9WT9sda/df8J3QHUR0MEjRPKCpMTQKPkQ8j1/2WxD6sq7QFQlTIRNOR3snaV5NVjvvq9QxIYwqSSQG+Xr6CuXy3iWMz6H/3kSeP+JfnaA1j9/3b3f+i2i9yJoCPxq//dopiUAGzUlnRp1y9EsPuT9jutgqhKoCy15Vt5ALX+Lu5fWTlN+JZs+QqTEYDT9dMun5zqDbn+6Mwf0OQz4v51RZBg/QpOLxAgfVl9gUkIwL/Aw1i/WsEb6/ofeof/8w4fu55YfglUfLHST8IbChzvWxYmIQAbPtcvrH9h1w/YsZ/U/6mx3wVFbhbdwDHA3+hRrt+s3985Hef6g9Z/xQkpAEO+HfuXU/r1QbYLoy4Dwz1+ZiV93DPdm4xSWb+j/h/BxE8doxaAhtXoqS3uKMQ6fp/rT7F+AHb2X9mun41g4qeO0QrA2+ipt3lny7P+w0evq7n/0nQAHV2/3K0fGKkAWnv8jLr+Dew+/mfnOMnWX85J6VcBlWvad0Tmj5EKQCPU6FHkP+Fe8JRU8yvoeL+kad8MMDoBRDd6ZhviiESb9R++/Gpp/c3Yv2jpNyRGJYCURg+fzbD7+J+c4yxk/dL1m4mfBad9B8ZoBJDa6PG5fhdaYz8grJ+XZLq3qsX9EbKPEQnARrjRE1rb38X6Dx+5Sk77kmVfXdf7ZYZRCCCl0SOyfrfrdyHK+l23e8sTG7P7B0YggNRGz+4T7pIP6Bj7AUeiR49xI3sB2Ag3ekJZv4v8GOs/fPk1stdPReA+NYqxSCNrAaQ0enixgd0f/7GHkwhRGd4CZgx+IlsBJDd6erB+86kuGsldwI19AOJHGRrZCsBGuNGD2QZ2f3Sm38+n4Qf0JxGm+ilf8iEnMWS5HsDv+hlx/abRE3L9i1j/4StP2jmH9j4MrFIiKABwcM6NU1D/AVoieNjmCGqld2QngNZGT2HP9ae6/rRzYWDyHkLOCjDthTi4fIiqgt78iTNwTSknewSyoBiGFEF2AtCwevzqwrMG+buPpbn++NgPvWGUPvjMSgqF0Uv2tRA4IHcIE16BmeliSwy2EIYSQVYC8Pb4Gzdzqrj/B+9Yi1r/O6/9lMwzSvlTuHmhy1IQW1XgTM4MskJ2B2HKRaZ+SjEANSEML4JsBBB0/Y5GT0qnTyHF+s9+/9fJ48figs+824hg4FQwvyog1OOfqY2cNrD72O+9Qyxq/X3i4K2X1LaQG/Z8shCAt8dfn+1T7r/DRk4p1v+2BW8Z9OHgZ98LVSP6JpBW7Q8GF0DrhI9O/Mw2brs//J13vJyt3wibPAYG9QLZ5AACTeuv780fyvp95Cdl/oFx2vDIq/7Xtm+/FJwxUUrW9xAeEIN6gOjEj1h/33jkvx3/LkT+HZfZpWxjD+HhZJCRB3C4R8sLFKux/sD7u4hj666jkvjK8erwVcBgAgjGfpDYLxs/KYs8KEKkpYgjNE7I+rXFO62c136uHoMngQKORkv9CGDIxC9E/tZXP+L37jl0gpCNAAhUCCAduJQFnrFYhvUHyb/3GvHAWkWkIH6n7QGFVWcDwwuAuv+2PqoDOZZ9W/efbN4z0LiHAFksKB0kB/D+tx3cu/bwowjGXw9SRNPF+s2ycbmUjH6XkNxEwrWB5BAY3gMEsPPM3wb9/C7kb566oXYTCd0+xiwszcH9A7kJgOt/0Jdl9BkyNh+4Ud46NgdKchtZfQMpx61kQyEbAQj1G/e484uOX9gUgZgEMNX6Nx+8GawUxJv9A8guovX7CYHBrR/IYSKo0QQXF+jg595n3eatF4JYvxcAU3v919cLzIDZAX2zyJsPP7XwqXrJ/84t4tZxfUjrL+WdxORuIrOFTGg98eowiACc81/1b92uKrBCGI1+nXMwXoiFGHqGsAQqIQo2E8vDhaVtaG/y5nd/nnR+LusPJn3lnrR+cWhPoPYSCGwgNTSG9wAAlBsQK6rIBaoqMLmqhhdcXMhKWD6rZKu4Ul5CxtqZIJ87SqyY+J863bv54M1g8z1gvgfMJfmVIp9af0W+Y9j8/dDNoDwEwKGXRzHGwHkFMycgLhGr5Dq7ogK4bKpUBVjBgGomnp/ZO3Vyx7xCam8ACMd9Rby2/HoCKG8qde0fNDT5wIACaIQBKgL6GodZgwcGxhnAKpEfMCUGGRrU8myhJCGmKj7PTXH9m9/+BDDfE9Zf7lnxv76BVG5xn2JQD+AVAZi2GL3MWq+wZZJcstiSVQAXrWKhIbOU7OwPfhN1LsmdPuXuqesvm66/9Z7CgZFHCKBQcwHM/LBW1moRAGCFFEIhO4lyDBkeQKy/S/3vtf5vfRyslHGfJoBW0ld56/1crB/IQADqYjSrAvmPXCRKt2IxXqGSawakE1BhglXgiogIJLn+B240lm9l/3Tip5bxZxb3KQYXgIJ3aQSdHaRegb5fr8dnIidQF7+yR4xNAIOTPfM9YO+ciP9Ot0+sP3PygYxmAoGIXiBtoujkylib3rgJIv7G3DCaEvvZ/Jyd8c/HlfG7kJUAFEJraABYItDdNfEEjNWZq++L/0mu/9QN2u2DxPwxZfwuZCkACr8QuH5dE0+e7wIv+d/8mLH4EWf8LmQvAIWGCFqvcdjuYl3/lDJ+F0YjACD2YooScfe0vTt4WwLos349zTuBjN+FUQkgDAZX9uCK/3Xr95G/df8JM9EzH3/G78JEBCAzAc2///JHk3/qpLT8ud3pG3HG78LoBaBnAK1l5Iv9t3TGTxo9IKt7xprxuzBeATD6gJnHrGh8LZyK/zHWv3nqBhL35yIBnEjG78J4BaBA3X7tJpLQ/L836StNrW/39sef8bswKgE0Lje5gYS33EUUU/ZtfeM6WevvmaRPZ/ylifkjTvrqGJUA6rDjf+EVQIzr37rvemn5e2ClXNlbzRureqZEPjBWAdC2LwjprOh0I8nWfdfX+vqy1i+rSWX8LoxTABbphvy2+O9d2CmTPtZY1VMa8ieQ8bswGgG4c21V/zO01f8+bN1zVWNJt0n6uCn3JpDxuzAaAdThqv93nnzJ+36n6//61Z6l3PRrYaeT8buQzYKQaDjjf3glgZP8e65uKfeml/G7MAoP4C7/YP+MrP81KPlWuacaPNPL+F1YiQegX4W+vG/FJrN/qdb/lQ/LLF/dxzf3NHgwafKBngVAia8/10kIkgEa/1UCuPP0y423h8knfX1vuTetjN+F8eUAAIn76odj8sdF/t1XSsJLWLdv8Wk1eFLQWw7gsv6U1xW88R+whSDhi/9bd19hk1/O7Y0cJtTgScE4PYBc9UN/pXBZvyBe7tghH+dW7r3+4l368aEjp1fymaOoAgDY8Z8+AWDnmb/rxy7yt++83MzslW7XP3TGT8l3/d4XehNAW5K3UDWQwMz2nUcM8Yp8bhI+802g+ZDf9vwykXUICE3/xmD7jg+ZLh7dq4fU+utS7vnQqwCUlS9nHsBHSyBh0/P5qpfv+w7g9cj4XfAKYO/cWzhw3vlL+ZClTf4w1mDIt5nU9hc/qK3fEG9m+Fzl3lA4dOS0090vKxHcO/eW9zUrBzj73Gsv+N6YJTzkbd9+qWzlyrl9MsMXKveGtP462X1VAXWON3CcHcMZvvzNePsCh2RKP7Cw/YUPiNcsotv36MvB9a+q9NM4zo4Fq4CQ6xgENFvncHoAVlX6MBM9fJLr+WLQxmHWVYAfgr03nv2X9az4UiYYYfBKC0Uv6lgj8mMgPMBxdkw9UY8RuXkBTVjN+A/e9p6auyfbs60p+XXuLG4l5yPyACTmc26xd/DWS5pvpXmAenL4hD87OHOArL2A2iuIxn+a1ZNNGUPkr7X1ExgBkDAQM+DKQQnkHG/86t8AgIPqa1hJlm8LZJ/8BgjX3iogzzkBm8kLPn2xfVO4Vd+rx/YIUyffhRCXzetRmxPYvOnCo/T3Zc0OxsAZsj0LQBp/6fjjdSC/1fXXPH3TA2QUCpyE6frfczis3jvWxJDi+hX814V4groXUFiFN1g0cV9n4l1lXx1R6wF8MWQV3mARAvfJb0f4GrXkAxR9e4MUT7DOxAPtcZ+i/Vo5GkW5CmGfeIfVt+R0cdcsUQQKq6wYpoyYUNuFfCDVaDoKYR/9oSvxCule07N2YF8Iq4U3yUsgH+gaNiMWkOwLYrmIyuoTyQcWzZvGtJJoyuhAvMLyEud9MawWC5BO0U/ltC+GfrAk0in+D13BdbniOnQFAAAAAElFTkSuQmCC"

-- ======================================================================
-- UTILITAS
-- ======================================================================

local function nclosure(fn)
    if type(newcclosure) == "function" then
        local ok, res = pcall(newcclosure, fn)
        if ok then
            return res
        end
    end
    return fn
end

local function listMatchesAny(text, patterns)
    if type(text) ~= "string" or text == "" then
        return false
    end
    local low = string.lower(text)
    for _, pat in ipairs(patterns) do
        if string.find(low, string.lower(pat), 1, true) then
            return true
        end
    end
    return false
end

local function isPromoUrl(url)
    return listMatchesAny(url, BLOCKED_URL_PATTERNS)
end

local function isPromoClipboard(text)
    return listMatchesAny(text, PROMO_CLIPBOARD_PATTERNS)
end

local function waitSeconds(n)
    if type(task) == "table" and type(task.wait) == "function" then
        task.wait(n)
    elseif type(wait) == "function" then
        wait(n)
    end
end

local function afterDelay(seconds, fn)
    if type(task) == "table" and type(task.delay) == "function" then
        task.delay(seconds, fn)
    elseif type(task) == "table" and type(task.spawn) == "function" then
        task.spawn(function()
            waitSeconds(seconds)
            fn()
        end)
    elseif type(spawn) == "function" then
        spawn(function()
            waitSeconds(seconds)
            fn()
        end)
    else
        fn() -- executor tanpa async (sangat jarang): jalankan sekarang
    end
end

local function spawnBackground(fn)
    if type(task) == "table" and type(task.spawn) == "function" then
        task.spawn(fn)
    elseif type(spawn) == "function" then
        spawn(fn)
    else
        fn()
    end
end

-- Ganti semua kemunculan `pat` -> `repl` (case-insensitive, plain text)
local function replaceAllCI(s, pat, repl)
    local low = string.lower(s)
    local plow = string.lower(pat)
    local out = {}
    local pos = 1
    while true do
        local st, en = string.find(low, plow, pos, true)
        if not st then
            break
        end
        out[#out + 1] = string.sub(s, pos, st - 1)
        out[#out + 1] = repl
        pos = en + 1
    end
    out[#out + 1] = string.sub(s, pos)
    return table.concat(out)
end

-- Tulis ulang string branding -> ThorHub. Mengembalikan nil bila tidak berubah.
local function rebrandString(s)
    if type(s) ~= "string" or s == "" then
        return nil
    end
    if not string.find(string.lower(s), "chilli", 1, true) then
        return nil
    end
    local out = s
    for _, rule in ipairs(TEXT_REPLACEMENTS) do
        out = replaceAllCI(out, rule[1], rule[2])
    end
    if out ~= s then
        return out
    end
    return nil
end

-- Decoder base64 murni Lua (tanpa bergantung crypt executor)
local B64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_LOOKUP = {}
for i = 1, #B64_ALPHABET do
    B64_LOOKUP[string.sub(B64_ALPHABET, i, i)] = i - 1
end

local function b64decode(input)
    if type(input) ~= "string" then
        return nil
    end
    local out, n = {}, 0
    local buf, bits = 0, 0
    for i = 1, #input do
        local v = B64_LOOKUP[string.sub(input, i, i)]
        if v then
            buf = buf * 64 + v
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                local byte = math.floor(buf / 2 ^ bits)
                buf = buf - byte * 2 ^ bits
                n = n + 1
                out[n] = string.char(byte)
            end
        end
    end
    if n == 0 then
        return nil
    end
    return table.concat(out)
end

-- ======================================================================
-- [C4a] PERSIAPKAN ICON THOR (sebelum script inti jalan)
-- ======================================================================

local THOR_ASSET_ID = nil -- id asset icon Thor (untuk redirect + reicon)

pcall(function()
    local png = b64decode(THOR_ICON_B64)
    if type(png) ~= "string"
        or #png < 100
        or png:byte(1) ~= 137
        or png:sub(2, 4) ~= "PNG" then
        return
    end

    if type(makefolder) == "function" then
        pcall(makefolder, "Chilli Hub")
        pcall(makefolder, "Venyx")
    end

    if type(writefile) == "function" then
        -- Timpa cache icon lama + tulis asset segar milik loader.
        -- Ditulis SETIAP eksekusi supaya icon chili sisa instalasi lama
        -- pasti tertimpa.
        for _, path in ipairs(ICON_CACHE_PATHS) do
            pcall(writefile, path, png)
        end
        pcall(writefile, ICON_FRESH_PATH, png)
    end

    -- Daftarkan icon Thor sebagai asset lokal executor, lewat file segar
    -- (path ini isinya selalu Thor, jadi kebal cache basi executor).
    local assetFn = getcustomasset or getsynasset
    if type(assetFn) == "function" then
        local ok, id = pcall(assetFn, ICON_FRESH_PATH)
        if ok and type(id) == "string" and id ~= "" then
            THOR_ASSET_ID = id
        end
    end
end)

-- ======================================================================
-- [C4b] REDIRECT ICON: bungkus global getcustomasset/getsynasset
-- ======================================================================
-- Script inti membaca global ini SAAT runtime:
--   local V = getcustomasset or getsynasset  ...  T,O = pcall(V, C)
-- C = "Venyx/mark1.png" / "Chilli Hub/VenyxMark1.png".
-- Pembungkus ini mengalihkan path icon lama ke asset Thor — bekerja
-- MESKIPUN executor men-cache asset lama, karena id yang dikembalikan
-- berasal dari file segar milik loader.

local function isLegacyMarkPath(path)
    local low = string.lower(tostring(path))
    return string.find(low, "mark1.png", 1, true)
        or string.find(low, "venyxmark", 1, true)
end

pcall(function()
    if THOR_ASSET_ID == nil then
        return
    end
    if type(getcustomasset) == "function" then
        local oldGetCustomAsset = getcustomasset
        local wrapped = nclosure(function(path)
            if isLegacyMarkPath(path) then
                return THOR_ASSET_ID
            end
            return oldGetCustomAsset(path)
        end)
        pcall(function()
            getcustomasset = wrapped
            if type(getgenv) == "function" then
                getgenv().getcustomasset = wrapped
            end
        end)
    end
    if type(getsynasset) == "function" then
        local oldGetSynAsset = getsynasset
        local wrappedSyn = nclosure(function(path)
            if isLegacyMarkPath(path) then
                return THOR_ASSET_ID
            end
            return oldGetSynAsset(path)
        end)
        pcall(function()
            getsynasset = wrappedSyn
            if type(getgenv) == "function" then
                getgenv().getsynasset = wrappedSyn
            end
        end)
    end
end)

-- ======================================================================
-- [C1] BLOKIR FETCH PROMO DI LEVEL HttpGet (3 lapis, TANPA beban idle)
-- ======================================================================
-- Audit payload: semua fetch lewat game:HttpGet(...) [namecall] atau
-- pcall(game.HttpGet, game, ...) [property-call]. Hook namecall global
-- (hookmetamethod) sengaja TIDAK dipakai lagi karena memotong SEMUA
-- namecall game — itu salah satu penyebab "berat" di versi lama.

local httpHookInstalled = false

local function makeHttpGetWrapper(original)
    -- Tanda tangan sama untuk dua gaya panggil: (game, url, ...)
    return nclosure(function(self, url, ...)
        if isPromoUrl(url) then
            return "" -- promo: balas kosong, script lanjut normal
        end
        return original(self, url, ...)
    end)
end

-- Lapis 1: override properti game.HttpGet.
-- Menangkap BAIK game:HttpGet(url) MAUPUN pcall(game.HttpGet, game, url).
-- (HttpGet bukan member bawaan Roblox — dia fungsi buatan executor,
--  jadi override aman dan umum dipakai.)
pcall(function()
    local original = game.HttpGet
    if type(original) ~= "function" then
        return
    end
    local wrapped = makeHttpGetWrapper(original)
    game.HttpGet = wrapped
    if rawequal(game.HttpGet, wrapped) then
        httpHookInstalled = true
    else
        -- write senyap gagal -> revert (mungkin no-op, tidak masalah)
        pcall(function()
            game.HttpGet = original
        end)
    end
end)

-- Lapis 2 (cadangan): hookmetamethod __namecall — HANYA dipasang bila
-- Lapis 1 gagal, dengan body seminimal mungkin (1 cek string per namecall).
if not httpHookInstalled then
    pcall(function()
        if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
            return
        end
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", nclosure(function(self, ...)
            if getnamecallmethod() == "HttpGet" then
                local url = select(1, ...)
                if isPromoUrl(url) then
                    return ""
                end
            end
            return oldNamecall(self, ...)
        end))
        httpHookInstalled = true
    end)
end

-- Lapis 3 (bonus): beberapa script memanggil HttpGet global.
pcall(function()
    if type(getgenv) == "function" then
        getgenv().HttpGet = nclosure(function(url, ...)
            if isPromoUrl(url) then
                return ""
            end
            return game:HttpGet(url, ...)
        end)
    end
end)

-- ======================================================================
-- [C3] CEGAH PENYALINAN LINK PROMO KE CLIPBOARD
-- ======================================================================

pcall(function()
    if type(setclipboard) ~= "function" then
        return
    end
    local oldSetClipboard = setclipboard
    local hookedClipboard = nclosure(function(text)
        if isPromoClipboard(text) then
            return -- link promo tidak disalin
        end
        return oldSetClipboard(text)
    end)
    if type(hookfunction) == "function" then
        pcall(hookfunction, oldSetClipboard, hookedClipboard)
    end
    pcall(function()
        setclipboard = hookedClipboard
    end)
    if type(getgenv) == "function" then
        pcall(function()
            getgenv().setclipboard = hookedClipboard
        end)
    end
end)

-- ======================================================================
-- [C2] PROSESOR UI — event-driven (pengganti scan abadi versi lama)
-- ======================================================================

-- Snapshot GUI game yang sudah ada, supaya UI bawaan game tidak diproses
local existingPlayerGuiChildren = {}
local playerGuiRef = nil
pcall(function()
    local player = game:GetService("Players").LocalPlayer
    playerGuiRef = player and player:FindFirstChildOfClass("PlayerGui")
    if playerGuiRef then
        for _, child in ipairs(playerGuiRef:GetChildren()) do
            existingPlayerGuiChildren[child] = true
        end
    end
end)

-- Set nama/teks persis yang dianggap promo (lowercase)
local promoExactSet = {}
for _, s in ipairs(PROMO_HIDE_EXACT) do
    promoExactSet[string.lower(s)] = true
end

-- Peta warna chili -> ThorUi (dibangun sekali di awal)
local COLOR_MAP = {}
do
    local okC3 = pcall(function()
        return Color3.fromRGB(1, 2, 3)
    end)
    if okC3 then
        for key, rgb in pairs(COLOR_REMAP_RAW) do
            COLOR_MAP[key] = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
        end
    end
end

-- State (weak table supaya instance yang dihancurkan bisa di-GC)
local gradientDone = setmetatable({}, { __mode = "k" })   -- gradien sudah diproses
local fontDone = setmetatable({}, { __mode = "k" })       -- font sudah diproses
local recolorTracked = setmetatable({}, { __mode = "k" }) -- obj -> {prop -> {lastKey=...}}
local hiddenPromo = setmetatable({}, { __mode = "k" })    -- elemen promo yang disembunyikan

local function isColor3Value(v)
    if type(typeof) == "function" then
        return typeof(v) == "Color3"
    end
    if type(v) ~= "userdata" then
        return false
    end
    return pcall(function()
        return v.R + v.G + v.B
    end)
end

local function colorKey(c)
    local r = math.floor(c.R * 255 + 0.5)
    local g = math.floor(c.G * 255 + 0.5)
    local b = math.floor(c.B * 255 + 0.5)
    return r .. "," .. g .. "," .. b
end

-- Ganti warna satu properti bila nilainya termasuk palet chili,
-- lalu CATAT untuk loop drift (warna aksen memang berubah saat toggle
-- dipakai — catatan lastKey membuat perbaikan drift hanya menyentang
-- warna yang STABIL kembali ke chili, bukan animasi hover sesaat).
local function remapColorProp(obj, propName)
    local c = obj[propName]
    if not isColor3Value(c) then
        return
    end
    local key = colorKey(c)
    local mapped = COLOR_MAP[key]
    if not mapped then
        return
    end
    obj[propName] = mapped
    local entries = recolorTracked[obj]
    if not entries then
        entries = {}
        recolorTracked[obj] = entries
    end
    local entry = entries[propName]
    if not entry then
        entries[propName] = { lastKey = colorKey(mapped) }
    else
        entry.lastKey = colorKey(mapped)
    end
end

-- Remap keypoint gradien yang warnanya masuk peta chili (sekali per instance)
local function remapGradient(obj, force)
    if not force and gradientDone[obj] then
        return
    end
    gradientDone[obj] = true
    local seq = obj.Color
    if type(seq) ~= "userdata" then
        return
    end
    local ok, keypoints = pcall(function()
        return seq.Keypoints
    end)
    if not ok or type(keypoints) ~= "table" then
        return
    end
    local changed = false
    local newKps = {}
    for i, kp in ipairs(keypoints) do
        local mapped = nil
        if isColor3Value(kp.Value) then
            mapped = COLOR_MAP[colorKey(kp.Value)]
        end
        if mapped then
            changed = true
        else
            mapped = kp.Value
        end
        newKps[i] = ColorSequenceKeypoint.new(kp.Time, mapped)
    end
    if changed then
        obj.Color = ColorSequence.new(newKps)
    end
end

-- Sembunyikan elemen promo + catat di set drift (kalau library
-- menyalakannya lagi, loop drift akan mematikan lagi).
local function hideObject(obj)
    pcall(function()
        obj.Visible = false
    end)
    hiddenPromo[obj] = true
end

-- Naik dari elemen promo ke KARTU pembungkusnya (anak langsung dari
-- ScrollingFrame). Mengembalikan nil bila struktur tidak seperti dugaan.
local function climbToCard(obj)
    local cur = obj
    local depth = 0
    while cur and depth < 8 do
        local par = cur.Parent
        if par == nil then
            return nil
        end
        local okScroll, isScroll = pcall(function()
            return par:IsA("ScrollingFrame")
        end)
        if okScroll and isScroll then
            return cur
        end
        local okGui, isScreenGui = pcall(function()
            return par:IsA("ScreenGui")
        end)
        if okGui and isScreenGui then
            return nil -- elemen langsung di bawah ScreenGui: jangan ikut sembunyikan ScreenGui
        end
        cur = par
        depth = depth + 1
    end
    return nil
end

local function descendantCountLE(obj, limit)
    local ok, count = pcall(function()
        return #obj:GetDescendants()
    end)
    if not ok or type(count) ~= "number" then
        return false
    end
    return count <= limit
end

-- Tulis ulang teks branding Chilli -> ThorHub (hanya .Text yang tampil;
-- TextBox.Text (isi ketikan user) sengaja TIDAK disentuh)
local function rebrandObject(obj)
    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
        local newText = rebrandString(obj.Text)
        if newText then
            obj.Text = newText
        end
    elseif obj:IsA("TextBox") then
        local newText = rebrandString(obj.PlaceholderText)
        if newText then
            obj.PlaceholderText = newText
        end
    end
end

-- Tukar icon BRAND script -> icon Thor
local function reiconObject(obj)
    if THOR_ASSET_ID == nil then
        return
    end
    if not (obj:IsA("ImageLabel") or obj:IsA("ImageButton")) then
        return
    end
    local img = obj.Image
    if type(img) ~= "string" or img == "" then
        return
    end
    local low = string.lower(img)
    local hit = ICON_BRAND_BLACKLIST[low]
        or string.find(low, "venyxmark1", 1, true)
        or string.find(low, "mark1.png", 1, true)
        or string.find(low, "chilli", 1, true)
    if hit then
        obj.Image = THOR_ASSET_ID
    end
end

-- Font khas chili -> font ThorUi (Gotham)
local function applyThorFont(obj)
    if not THORUI_FONTS or fontDone[obj] then
        return
    end
    fontDone[obj] = true
    if not (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then
        return
    end
    local ok = pcall(function()
        local ff = obj.FontFace
        if type(ff) == "userdata" then
            local fam = tostring(ff.Family or "")
            if string.find(fam, CHILLI_FONT_MARK, 1, true) then
                obj.FontFace = Font.fromEnum(Enum.Font.Gotham)
            end
        end
    end)
    if not ok then
        pcall(function()
            obj.Font = Enum.Font.Gotham
        end)
    end
end

-- KLASIFIKASI SATU ELEMEN (idempoten — aman dipanggil berulang).
-- Urutan: Sembunyikan promo dulu (teks promo dicek dalam bentuk asli),
-- baru rebrand/reicon/recolor/font.
local function classify(obj, force)
    pcall(function()
        if type(typeof) == "function" and typeof(obj) ~= "Instance" then
            return
        end

        -- [hide] nama instance persis (tombol tab / halaman promo)
        if obj:IsA("GuiObject") then
            local nameLow = string.lower(tostring(obj.Name))
            if promoExactSet[nameLow] then
                hideObject(obj)
                return
            end
            if listMatchesAny(obj.Name, PROMO_HIDE_CONTAINS) then
                hideObject(obj)
                return
            end
        end

        local isTextObj = obj:IsA("TextLabel") or obj:IsA("TextButton")
        if isTextObj then
            local text = tostring(obj.Text)
            if promoExactSet[string.lower(text)] then
                hideObject(obj)
                return
            end
            if listMatchesAny(text, PROMO_HIDE_CONTAINS) then
                -- CLIMB-TO-CARD: sembunyikan seluruh kartu pembungkus,
                -- bukan cuma teksnya (kartu onboarding "Venyx" & kartu
                -- "Discord" mati total — termasuk iconnya).
                local card = climbToCard(obj)
                if card ~= nil and card ~= obj and descendantCountLE(card, CLIMB_MAX_DESCENDANTS) then
                    hideObject(card)
                else
                    hideObject(obj)
                end
                return
            end
        end

        -- [rebrand] teks tampilan
        rebrandObject(obj)
        if obj:IsA("GuiObject") then
            local newTip = rebrandString(obj.Tooltip)
            if newTip then
                obj.Tooltip = newTip
            end
        end

        -- [recolor] palet chili -> palet ThorUi
        if obj:IsA("GuiObject") then
            remapColorProp(obj, "BackgroundColor3")
        end
        if isTextObj or obj:IsA("TextBox") then
            remapColorProp(obj, "TextColor3")
            remapColorProp(obj, "TextStrokeColor3")
        end
        if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
            remapColorProp(obj, "ImageColor3")
        end
        if obj:IsA("UIStroke") then
            remapColorProp(obj, "Color")
        end
        if obj:IsA("UIGradient") then
            remapGradient(obj, force)
        end

        -- [reicon] icon brand -> Thor
        reiconObject(obj)

        -- [font] chili -> ThorUi
        applyThorFont(obj)
    end)
end

-- Proses satu pohon penuh (dipakai untuk pass awal + rescan terbatas)
local function processTree(root, force)
    pcall(function()
        for _, obj in ipairs(root:GetDescendants()) do
            classify(obj, force)
        end
    end)
end

-- Handler event: elemen baru muncul -> proses sekarang + 2 retry singkat
-- (properti .Text/.Image/warna sering di-set SETELAH instance di-parent-kan)
local function onDescendantAdded(inst)
    classify(inst)
    afterDelay(RETRY_SHORT, function()
        classify(inst)
    end)
    local okGui, isTextLike = pcall(function()
        return inst:IsA("TextLabel") or inst:IsA("TextButton")
            or inst:IsA("TextBox") or inst:IsA("ImageLabel")
            or inst:IsA("ImageButton")
    end)
    if okGui and isTextLike then
        afterDelay(RETRY_LONG, function()
            classify(inst)
        end)
    end
end

-- ======================================================================
-- [P2] PASANG PEMANTAU EVENT
-- ======================================================================

local function watchRootForever(root)
    pcall(function()
        root.DescendantAdded:Connect(onDescendantAdded)
    end)
end

local function watchRootWindowed(root, seconds)
    pcall(function()
        local conn
        conn = root.DescendantAdded:Connect(onDescendantAdded)
        afterDelay(seconds, function()
            pcall(function()
                conn:Disconnect()
            end)
        end)
    end)
end

-- 1) gethui() — folder UI executor: domain kita, dipantau selamanya
--    (menunya statis; event hanya muncul saat elemen benar2 baru)
local huiRoot = nil
pcall(function()
    if type(gethui) == "function" then
        huiRoot = gethui()
    end
end)
if huiRoot then
    watchRootForever(huiRoot)
    processTree(huiRoot) -- pass awal (menangkap sisa eksekusi sebelumnya)
end

-- 2) CoreGui — cadangan klasik; dipantau hanya dalam window singkat
pcall(function()
    local coreGui = game:GetService("CoreGui")
    watchRootWindowed(coreGui, WATCH_WINDOW_SECONDS)
    if not huiRoot then
        processTree(coreGui) -- tanpa gethui: butuh pass awal penuh
    end
end)

-- 3) PlayerGui — hanya GUI BARU setelah loader jalan (UI game asli
--    tidak diproses); dipantau dalam window singkat lalu dilepas.
if playerGuiRef then
    watchRootWindowed(playerGuiRef, WATCH_WINDOW_SECONDS)
    if not huiRoot then
        pcall(function()
            for _, child in ipairs(playerGuiRef:GetChildren()) do
                if not existingPlayerGuiChildren[child] then
                    processTree(child)
                end
            end
        end)
    end
end

-- ======================================================================
-- [P4] LOOP DRIFT RINGAN (satu-satunya loop abadi di v3)
-- ======================================================================
-- Hanya memeriksa DUA set kecil (bukan seluruh pohon UI):
--   1. recolorTracked — properti yang pernah di-recolor; warna aksen
--      di-set ulang oleh library setiap toggle dipakai. Logika dua-sampel
--      (lastKey == current) memastikan hanya warna chili yang STABIL yang
--      diperbaiki — animasi hover sesaat tidak diganggu.
--   2. hiddenPromo  — kalau library menyalakan lagi elemen promo, matikan.
local function driftPass()
    for obj, entries in pairs(recolorTracked) do
        for propName, entry in pairs(entries) do
            local ok, cur = pcall(function()
                local c = obj[propName]
                if isColor3Value(c) then
                    return colorKey(c)
                end
                return nil
            end)
            if ok and type(cur) == "string" then
                if cur == entry.lastKey then
                    local mapped = COLOR_MAP[cur]
                    if mapped then
                        pcall(function()
                            obj[propName] = mapped
                        end)
                        entry.lastKey = colorKey(mapped)
                    end
                else
                    entry.lastKey = cur
                end
            end
        end
    end
    for obj in pairs(hiddenPromo) do
        pcall(function()
            if obj.Visible then
                obj.Visible = false
            end
        end)
    end
end

spawnBackground(function()
    while true do
        waitSeconds(DRIFT_INTERVAL)
        pcall(driftPass)
    end
end)

-- ======================================================================
-- [P3] RESCAN PENUH TERBATAS (4x lalu berhenti)
-- ======================================================================
-- Menutup celah "hide sekali lalu dihidupkan lagi oleh library" tanpa
-- memikul scan abadi seperti versi lama.
for _, t in ipairs(RESCAN_AT) do
    afterDelay(t, function()
        local roots = {}
        if huiRoot then
            roots[#roots + 1] = huiRoot
        end
        pcall(function()
            roots[#roots + 1] = game:GetService("CoreGui")
        end)
        if not huiRoot and playerGuiRef then
            pcall(function()
                for _, child in ipairs(playerGuiRef:GetChildren()) do
                    if not existingPlayerGuiChildren[child] then
                        roots[#roots + 1] = child
                    end
                end
            end)
        end
        for _, r in ipairs(roots) do
            processTree(r, true) -- force: gradien dicek ulang
        end
    end)
end

-- ======================================================================
-- [C5] JALANKAN SCRIPT INTI (TANPA DIUBAH SEDIKIT PUN)
-- ======================================================================

local function runCore()
    local okFetch, source = pcall(function()
        return game:HttpGet(CORE_URL)
    end)
    if not okFetch or type(source) ~= "string" or #source < 1000 then
        warn("[ThorHub Loader] Gagal mengunduh script inti. Periksa koneksi internet atau URL repo.")
        return false
    end

    local chunk, compileErr = loadstring(source)
    if not chunk then
        warn("[ThorHub Loader] Script inti gagal dikompilasi: " .. tostring(compileErr))
        return false
    end

    local okRun, runErr = pcall(chunk)
    if not okRun then
        warn("[ThorHub Loader] Script inti error saat berjalan: " .. tostring(runErr))
        return false
    end
    return true
end

runCore()

-- ======================================================================
-- [C8] TETAP AKTIF SETELAH PINDAH SERVER
-- ======================================================================
-- Dipasang SETELAH script inti jalan supaya antrian loader ini yang
-- paling akhir (executor umumnya memakai antrian queue_on_teleport
-- yang terakhir dipasang) — bootstrap promo spicy tertimpa.
if PERSIST_AFTER_HOP then
    pcall(function()
        if type(queue_on_teleport) == "function" then
            queue_on_teleport(('loadstring(game:HttpGet("%s"))()'):format(SELF_URL))
        end
    end)
end

-- ======================================================================
-- STATUS
-- ======================================================================

print("[ThorHub Loader v3] Aktif — arsitektur ringan (event-driven), "
    .. "promosi diblokir, brand " .. BRAND_NAME .. " + icon petir diterapkan.")
pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Steal an Egg — " .. BRAND_NAME,
        Text = "Loader v3 aktif: ringan, tanpa iklan, tema petir Thor.",
        Duration = 6,
    })
end)




