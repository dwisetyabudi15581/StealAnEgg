--[======================================================================[
     Steal an Egg — THORHUB CLEAN LOADER (bebas promosi + rebrand ThorHub)
     ----------------------------------------------------------------------
     File ini adalah PEMBUNGKUS (loader) untuk script inti StealAnEgg.lua.

     Script inti dijalankan 100% UTUH (semua fitur tetap berfungsi),
     sementara dari luar loader melakukan dua hal:

     A. MEMBUANG SEMUA PROMOSI
        [1] Fetch link Discord dinamis (file DiscordLink milik pembuat)
            diblokir di level HttpGet — link promo tidak pernah diunduh.
        [2] Tab / tombol / kartu promosi (Discord & Venyx) disembunyikan
            dari menu — ATURAN PRESISI: judul section fitur sah
            "Discord Webhook" (webhook milikmu sendiri) TIDAK ikut
            disembunyikan.
        [3] Penyalinan link promosi ke clipboard dicegah.

     B. REBRAND "CHILLI HUB" -> "THORHUB" (tema ThorUi milikmu)
        [4] Icon window ditukar jadi icon petir Thor — caranya: icon
            lama (PNG chili) sebenarnya di-cache executor di file
            "Venyx/mark1.png" / "Chilli Hub/VenyxMark1.png". Loader
            menulis PNG petir Thor ke path itu SEBELUM script inti
            jalan, sehingga script memuat icon Thor dengan sukarela.
        [5] Semua teks yang terlihat user ("Chilli Hub", "Chilli
            Library", dll) ditulis ulang jadi "ThorHub" secara
            berkala (aman: internal identifier Chilli* TIDAK disentuh,
            hanya properti .Text yang tampil di layar).
        [6] Palet warna chili (merah/oranye hangat) dipetakan ke palet
            ThorUi (midnight blue + electric blue + lightning gold) —
            di tingkat instance UI (latar, aksen, stroke, gradien),
            tanpa mengubah layout sedikit pun.

     Kenapa lewat loader, bukan ganti library UI-nya langsung?
       Library UI "Venyx" yang dipakai script inti ternyata TERTANAM
       di dalam script (bukan diunduh saat runtime) dan API-nya jauh
       lebih luas dari library UI biasa: canvas gambar bebas (Egg
       Predictor), Quick Bar, Pin Pad, HUD, sistem State persisten,
       dan tab dua sisi. Menu-library sederhana tidak bisa menggantikan
       semua itu tanpa mem-break fitur. Reskin eksternal ini memberi
       tampilan & brand ThorHub dengan GARANSI 100% fitur tetap jalan.
       (Bukti teknis: payload inti diekstrak & diaudit — lihat
       docs/AUDIT-KEAMANAN.md bagian koreksi pasca-audit.)

     [7] Setelah pindah server (Auto Hop / Rejoin), file INI yang jalan
         lagi otomatis lewat queue_on_teleport.

     Kompatibilitas: Delta, Solara, Wave, Cryptic, dan executor lain yang
     mendukung loadstring + game:HttpGet. Semua hook dipasang berlapis
     dengan pcall — kalau satu metode gagal, lapisan lain tetap jalan.

     Batasan (jujur):
       - Reskin teks/warna/icon bersifat kosmetik berkala; elemen yang
         baru dibuat bisa tampil sesaat dengan gaya lama sebelum
         tertangkap pass berikutnya (paling cepat 0.25 dtk).
       - Elemen promo tanpa teks/nama yang cocok bisa lolos (jarang;
         tambahkan pola di PROMO_HIDE_CONTAINS bila perlu).
       - Jika executor tidak mendukung writefile/getcustomasset,
         penyeedaan icon otomatis dilewati (fitur tetap jalan normal).
]======================================================================]

-- ======================================================================
-- KONFIGURASI (silakan diedit sesuai kebutuhan)
-- ======================================================================

-- Script inti (file asli, dijalankan tanpa diubah)
local CORE_URL = "https://raw.githubusercontent.com/dwisetyabudi15581/StealAnEgg/main/StealAnEgg.lua"

-- File loader ini sendiri (untuk re-run otomatis setelah pindah server)
local SELF_URL = "https://raw.githubusercontent.com/dwisetyabudi15581/StealAnEgg/main/StealAnEgg-Clean.lua"

-- true  = pasang queue_on_teleport agar loader ini tetap aktif
--         setelah Auto Hop / Rejoin
-- false = hanya aktif pada eksekusi pertama
local PERSIST_AFTER_HOP = true

-- Nama brand pengganti "Chilli Hub"
local BRAND_NAME = "ThorHub"

-- URL yang diblokir dari HttpGet.
-- Catatan: URL tienkhanh1/Venyx kini ikut diblokir — terbukti dari
-- audit payload bahwa library UI TERTANAM di script inti, URL itu
-- hanya muncul sebagai teks promo "Copy Venyx Loader", tidak pernah
-- di-fetch untuk kebutuhan fitur.
local BLOCKED_URL_PATTERNS = {
    "tienkhanh1/spicy",      -- DiscordLink (link promo dinamis) + bootstrap Chilli.lua lama
    "tienkhanh1/venyx",      -- loader promo Venyx (teks "Copy Venyx Loader")
    "discord.gg",            -- invite Discord
    "discord.com/invite",
    "dsc.gg",
}

-- Elemen promosi yang disembunyikan — aturan PRESISI:
--   EXACT    = nama/teks persis sama (tab & kanvas promo "Discord"/"Venyx")
--   CONTAINS = nama/teks mengandung frasa promo di bawah
-- Fitur sah seperti section "Discord Webhook" (milikmu) TIDAK kena.
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
    { "Chilli",         BRAND_NAME },
}

-- Pemetaan warna: "r,g,b" chili -> {r,g,b} ThorUi.
-- Hanya warna brand/latar yang dipetakan; warna status (hijau/merah
-- error, rarity, dsb.) sengaja TIDAK disentuh supaya makna tetap benar.
local COLOR_REMAP_RAW = {
    ["15,15,19"]    = { 11, 14, 23 },    -- Card (latar menu)       -> ThorUi Background
    ["18,18,22"]    = { 11, 14, 23 },    -- latar splash loading    -> Background
    ["18,18,26"]    = { 16, 20, 32 },    -- latar HUD/canvas        -> BackgroundAlt
    ["24,22,28"]    = { 16, 20, 32 },    -- CardTop                 -> BackgroundAlt
    ["28,26,32"]    = { 21, 26, 41 },    -- slot icon panel         -> CardHover
    ["48,46,56"]    = { 44, 52, 78 },    -- Stroke                  -> stroke biru gelap
    ["58,56,66"]    = { 46, 54, 80 },    -- Off (nonaktif)          -> dim biru
    ["170,170,185"] = { 150, 163, 190 }, -- teks abu splash         -> abu kebiruan
    ["170,174,184"] = { 150, 163, 190 }, -- teks dim                -> abu kebiruan
    ["255,72,72"]   = { 0, 195, 255 },   -- AccentA merah chili     -> electric blue
    ["255,150,60"]  = { 255, 190, 0 },   -- AccentB oranye chili    -> lightning gold
    ["255,60,60"]   = { 0, 195, 255 },   -- stroke splash merah     -> electric blue
    ["255,120,90"]  = { 0, 195, 255 },   -- persen splash           -> electric blue
    ["255,120,100"] = { 0, 195, 255 },   -- gradien judul (awal)    -> electric blue
    ["255,190,110"] = { 255, 214, 90 },  -- gradien judul (akhir)   -> emas terang
    ["255,132,123"] = { 120, 220, 255 }, -- aksen warm turunan      -> biru muda
}

-- Asset gambar yang terbukti sebagai icon BRAND script (ditukar ke icon
-- Thor). Icon egg/pet/game dan aset font TIDAK masuk daftar ini.
local ICON_BRAND_BLACKLIST = {
    ["rbxassetid://128961717706452"] = true, -- icon panel "Chilli Hub / Anti Guard"
}

-- Path file icon lama yang di-cache executor oleh script inti.
-- Loader menulis icon Thor ke path-path ini SEBELUM script inti jalan
-- sehingga script memuat icon Thor secara alami (tanpa dipatch).
local ICON_CACHE_PATHS = {
    "Venyx/mark1.png",           -- dicek PERTAMA oleh script inti
    "Chilli Hub/VenyxMark1.png", -- dicek kedua
}
local ICON_FRESH_PATH = "Venyx/ThorMark.png" -- asset milik loader (anti cache basi)

-- Icon petir Thor (PNG 128x128, palet ThorUi) dalam base64
local THOR_ICON_B64 = "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"

-- Irama pemindaian UI
local FAST_SCAN_SECONDS = 45 -- fase cepat (0.25 dtk) setelah loader jalan
local FAST_INTERVAL = 0.25
local SLOW_INTERVAL = 1.5

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
-- [4a] PERSIAPKAN ICON THOR (sebelum script inti jalan)
-- ======================================================================

local THOR_ASSET_ID = nil -- id asset icon Thor (untuk lapisan reicon)

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

    -- Daftarkan icon Thor sebagai asset lokal executor (untuk lapisan reicon)
    local assetFn = getcustomasset or getsynasset
    if type(assetFn) == "function" then
        local ok, id = pcall(assetFn, ICON_FRESH_PATH)
        if ok and type(id) == "string" and id ~= "" then
            THOR_ASSET_ID = id
        end
    end
end)

-- ======================================================================
-- [1] BLOKIR FETCH LINK PROMO DI LEVEL HttpGet
-- ======================================================================

local httpHookInstalled = false

-- Lapis 1: hookmetamethod __namecall — menangkap game:HttpGet(url) dari
-- script mana pun (termasuk script inti). Paling andal di executor modern.
pcall(function()
    if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
        return
    end
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", nclosure(function(self, ...)
        if getnamecallmethod() == "HttpGet" then
            local url = select(1, ...)
            if isPromoUrl(url) then
                return "" -- promo: balas kosong, script lanjut normal
            end
        end
        return oldNamecall(self, ...)
    end))
    httpHookInstalled = true
end)

-- Lapis 2 (cadangan): override properti game.HttpGet langsung
if not httpHookInstalled then
    pcall(function()
        local oldHttpGet = game.HttpGet
        game.HttpGet = nclosure(function(self, url, ...)
            if isPromoUrl(url) then
                return ""
            end
            return oldHttpGet(self, url, ...)
        end)
        httpHookInstalled = true
    end)
end

-- ======================================================================
-- [3] CEGAH PENYALINAN LINK PROMO KE CLIPBOARD
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
-- [2] WATCHER UI — sembunyikan promo + rebrand ThorHub
-- ======================================================================

-- Snapshot GUI game yang sudah ada SEBELUM script inti jalan,
-- supaya UI bawaan game tidak ikut diproses
local existingPlayerGuiChildren = {}
pcall(function()
    local player = game:GetService("Players").LocalPlayer
    local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        for _, child in ipairs(playerGui:GetChildren()) do
            existingPlayerGuiChildren[child] = true
        end
    end
end)

-- Set nama/teks persis yang dianggap promo (lowercase)
local promoExactSet = {}
for _, s in ipairs(PROMO_HIDE_EXACT) do
    promoExactSet[string.lower(s)] = true
end

-- Peta warna chili -> warna ThorUi (dibangun sekali di awal)
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

-- Gradien yang sudah diproses tidak diproses ulang (sekali per instance,
-- supaya tidak tarik-menarik dengan animasi gradien milik library)
local gradientDone = setmetatable({}, { __mode = "k" })

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

-- Ganti warna pada satu properti bila nilainya termasuk palet chili
local function remapColorProp(obj, propName)
    local c = obj[propName]
    if not isColor3Value(c) then
        return
    end
    local mapped = COLOR_MAP[colorKey(c)]
    if mapped then
        obj[propName] = mapped
    end
end

-- Remap semua keypoint gradien yang warnanya masuk peta chili
local function remapGradient(obj)
    if gradientDone[obj] then
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

-- Sembunyikan elemen promosi (aturan presisi, lihat KONFIGURASI)
local function hidePromoObject(obj)
    if not obj:IsA("GuiObject") then
        return
    end
    local name = string.lower(tostring(obj.Name))
    if promoExactSet[name] or listMatchesAny(obj.Name, PROMO_HIDE_CONTAINS) then
        obj.Visible = false
        return
    end
    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
        local text = string.lower(tostring(obj.Text))
        if promoExactSet[text] or listMatchesAny(obj.Text, PROMO_HIDE_CONTAINS) then
            obj.Visible = false
            obj.Active = false
        end
    end
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
    -- tooltip beberapa executor menampilkannya di UI
    local newTip = rebrandString(obj.Tooltip)
    if newTip then
        obj.Tooltip = newTip
    end
end

-- Pemetaan warna chili -> ThorUi pada instance UI
local function recolorObject(obj)
    if obj:IsA("GuiObject") then
        remapColorProp(obj, "BackgroundColor3")
    end
    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
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
        remapGradient(obj)
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

local function processObject(obj)
    pcall(function()
        hidePromoObject(obj)
        rebrandObject(obj)
        recolorObject(obj)
        reiconObject(obj)
    end)
end

local function collectScanRoots()
    local roots = {}
    local seen = {}

    local function addRoot(root)
        if root and not seen[root] then
            seen[root] = true
            roots[#roots + 1] = root
        end
    end

    -- 1) Folder UI executor (gethui) — tempat script biasa menaruh menu
    pcall(function()
        if type(gethui) == "function" then
            addRoot(gethui())
        end
    end)

    -- 2) CoreGui — lokasi klasik UI script
    pcall(function()
        addRoot(game:FindService("CoreGui"))
    end)

    -- 3) PlayerGui — HANYA GUI baru yang muncul setelah loader jalan
    pcall(function()
        local player = game:GetService("Players").LocalPlayer
        local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
        if playerGui then
            for _, child in ipairs(playerGui:GetChildren()) do
                if not existingPlayerGuiChildren[child] then
                    addRoot(child)
                end
            end
        end
    end)

    return roots
end

local function processAllUI()
    for _, root in ipairs(collectScanRoots()) do
        pcall(function()
            for _, obj in ipairs(root:GetDescendants()) do
                processObject(obj)
            end
        end)
    end
end

local function watcherLoop()
    local fastRoundsLeft = math.floor(FAST_SCAN_SECONDS / FAST_INTERVAL)
    while true do
        processAllUI()
        if fastRoundsLeft > 0 then
            fastRoundsLeft = fastRoundsLeft - 1
            waitSeconds(FAST_INTERVAL)
        else
            waitSeconds(SLOW_INTERVAL)
        end
    end
end

local function startWatcherLoop()
    if type(task) == "table" and type(task.spawn) == "function" then
        task.spawn(watcherLoop)
        return true
    elseif type(spawn) == "function" then
        spawn(watcherLoop)
        return true
    end
    return false
end

-- Jalankan watcher di latar belakang SEBELUM script inti, supaya
-- elemen promosi langsung disembunyikan & branding ThorHub langsung
-- diterapkan begitu UI dibangun
if not startWatcherLoop() then
    -- Executor tanpa dukungan async (sangat jarang): proses sekali saja
    processAllUI()
end

-- ======================================================================
-- [4b] JALANKAN SCRIPT INTI (TANPA DIUBAH SEDIKIT PUN)
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
-- [7] TETAP AKTIF SETELAH PINDAH SERVER
-- ======================================================================
-- Dipasang SETELAH script inti jalan supaya antrian loader ini yang
-- paling akhir (executor umumnya memakai antrian queue_on_teleport
-- yang terakhir dipasang).
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

print("[ThorHub Loader] Aktif — script inti utuh, promosi diblokir, brand " .. BRAND_NAME .. " + icon petir diterapkan.")
pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Steal an Egg — " .. BRAND_NAME,
        Text = "Loader aktif: semua fitur jalan, tanpa iklan, tema petir Thor.",
        Duration = 6,
    })
end)
