--[======================================================================[
     Steal an Egg — CLEAN LOADER (versi bebas promosi)
     ----------------------------------------------------------------------
     File ini adalah PEMBUNGKUS (loader) untuk script inti StealAnEgg.lua.

     Script inti dijalankan 100% UTUH (semua fitur tetap berfungsi),
     sementara semua unsur promosi dibuang:

       [1] Fetch link Discord dinamis (file DiscordLink milik pembuat)
           diblokir di level HttpGet — link promo tidak pernah diunduh.
       [2] Tab / tombol / label promosi di UI (Discord & Venyx, branding
           "Chilli Hub" / "Venyx") disembunyikan dari menu.
       [3] Penyalinan link promosi ke clipboard dicegah.
       [4] Setelah pindah server (Auto Hop / Rejoin), file INI yang jalan
           lagi otomatis lewat queue_on_teleport.

     Kenapa lewat loader, bukan edit langsung?
       File inti diproteksi Luraph Obfuscator v15.1 (±826 KB bytecode VM)
       sehingga tidak bisa diedit baris per baris. Loader bekerja dari
       luar: script inti tidak diubah sedikit pun.

     Kompatibilitas: Delta, Solara, Wave, Cryptic, dan executor lain yang
     mendukung loadstring + game:HttpGet. Semua hook dipasang berlapis
     (tiered) dengan pcall — kalau satu metode gagal dipasang, metode
     cadangan yang dipakai, dan lapisan pembersih UI tetap jalan.

     Batasan (jujur):
       - Elemen promo ber-ikon tanpa teks/nama yang cocok bisa lolos
         (jarang; tambahkan pola di PROMO_TEXT_PATTERNS bila perlu).
       - Hook HttpGet bersifat best-effort; lapisan UI-cleaner selalu
         aktif apa pun executor-nya.
]======================================================================]

-- ======================================================================
-- KONFIGURASI (silakan diedit sesuai kebutuhan)
-- ======================================================================

-- Script inti (file asli, dijalankan tanpa diubah)
local CORE_URL = "https://raw.githubusercontent.com/dwisetyabudi15581/StealAnEgg/main/StealAnEgg.lua"

-- File loader ini sendiri (untuk re-run otomatis setelah pindah server)
local SELF_URL = "https://raw.githubusercontent.com/dwisetyabudi15581/StealAnEgg/main/StealAnEgg-Clean.lua"

-- true  = pasang queue_on_teleport agar versi clean tetap aktif
--         setelah Auto Hop / Rejoin
-- false = clean hanya pada eksekusi pertama
local PERSIST_AFTER_HOP = true

-- URL yang diblokir dari HttpGet.
-- PENTING: JANGAN blokir "tienkhanh1/Venyx" — itu library UI-nya;
-- kalau diblokir, menu script tidak akan muncul.
local BLOCKED_URL_PATTERNS = {
    "tienkhanh1/spicy",      -- file DiscordLink (link promo dinamis)
    "discord.gg",            -- invite Discord
    "discord.com/invite",
    "dsc.gg",
}

-- Teks/nama elemen UI yang dianggap promosi lalu disembunyikan
-- (pencocokan case-insensitive pada .Text dan .Name)
local PROMO_TEXT_PATTERNS = {
    "discord",
    "venyx",
    "chilli",
}

-- Isi clipboard yang dicegah disalin (link promo)
local PROMO_CLIPBOARD_PATTERNS = {
    "discord.gg",
    "discord.com/invite",
    "tienkhanh1",
    "venyxhub",
}

-- Lama fase pemindaian cepat (detik) setelah loader jalan
local FAST_SCAN_SECONDS = 60

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

local function isPromoText(s)
    return listMatchesAny(s, PROMO_TEXT_PATTERNS)
end

local function waitSeconds(n)
    if type(task) == "table" and type(task.wait) == "function" then
        task.wait(n)
    elseif type(wait) == "function" then
        wait(n)
    end
end

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
-- (dipasang sebelum script inti jalan)
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
    -- beberapa jalur pemasangan sekaligus (kompatibilitas executor)
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
-- [2] SEMBUNYIKAN ELEMEN PROMOSI DI UI
-- ======================================================================

-- Snapshot GUI game yang sudah ada SEBELUM script inti jalan,
-- supaya UI bawaan game tidak ikut dibersihkan
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

local function hidePromoObject(obj)
    local isText = obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")
    local isImage = (not isText)
        and (obj:IsA("ImageLabel") or obj:IsA("ImageButton"))
    if not (isText or isImage) then
        return
    end
    local hit = isPromoText(obj.Name)
    if (not hit) and isText then
        hit = isPromoText(obj.Text)
    end
    if hit then
        pcall(function()
            obj.Visible = false
            obj.Active = false
        end)
    end
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
    --    (UI milik script), bukan UI bawaan game
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

local function cleanPromoUI()
    for _, root in ipairs(collectScanRoots()) do
        pcall(function()
            for _, obj in ipairs(root:GetDescendants()) do
                hidePromoObject(obj)
            end
        end)
    end
end

local function cleanerLoop()
    local fastRoundsLeft = math.floor(FAST_SCAN_SECONDS / 0.5)
    while true do
        cleanPromoUI()
        if fastRoundsLeft > 0 then
            fastRoundsLeft = fastRoundsLeft - 1
            waitSeconds(0.5)
        else
            waitSeconds(3)
        end
    end
end

local function startCleanerLoop()
    if type(task) == "table" and type(task.spawn) == "function" then
        task.spawn(cleanerLoop)
        return true
    elseif type(spawn) == "function" then
        spawn(cleanerLoop)
        return true
    end
    return false
end

-- Jalankan pembersih di latar belakang SEBELUM script inti, supaya
-- elemen promosi langsung disembunyikan begitu UI dibangun
if not startCleanerLoop() then
    -- Executor tanpa dukungan async (sangat jarang): bersihkan sekali saja
    cleanPromoUI()
end

-- ======================================================================
-- [4] JALANKAN SCRIPT INTI (TANPA DIUBAH SEDIKIT PUN)
-- ======================================================================

local function runCore()
    local okFetch, source = pcall(function()
        return game:HttpGet(CORE_URL)
    end)
    if not okFetch or type(source) ~= "string" or #source < 1000 then
        warn("[StealAnEgg-Clean] Gagal mengunduh script inti. Periksa koneksi internet atau URL repo.")
        return false
    end

    local chunk, compileErr = loadstring(source)
    if not chunk then
        warn("[StealAnEgg-Clean] Script inti gagal dikompilasi: " .. tostring(compileErr))
        return false
    end

    local okRun, runErr = pcall(chunk)
    if not okRun then
        warn("[StealAnEgg-Clean] Script inti error saat berjalan: " .. tostring(runErr))
        return false
    end
    return true
end

runCore()

-- ======================================================================
-- [5] TETAP CLEAN SETELAH PINDAH SERVER
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

print("[StealAnEgg-Clean] Aktif — script inti dijalankan utuh, semua promosi diblokir.")
pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Steal an Egg — CLEAN",
        Text = "Loader aktif. Semua fitur jalan normal tanpa iklan.",
        Duration = 6,
    })
end)
