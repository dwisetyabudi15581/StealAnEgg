--[[════════════════════════════════════════════════════════════════════════════
  ⚡ THORHUB — AUTO FARM (Steal an Egg)
  Edisi khusus AUTO FARM: hanya mesin farming + UI floating (ThorUi ⚡).
  v2.0 — BERBASIS KODE BARU Chilli (SAE v172610): + Auto Hop (Egg Finder),
  + Auto Progression, + mutasi baru (Scrambled/Bloom/Spirit Bloom/Fractured/
  Enchanted/Parasite/Nitro/Spectral). ThorUi embedded + boot shield + guard.
  Semua fitur diimplementasi ulang secara native (tanpa kode obfuscate).
  Tanpa promosi apa pun: tidak ada link Discord pihak ketiga, tidak ada
  bootstrap pihak ketiga, tidak ada teks "Chilli/Venyx".

  Fitur (semua di tab FARM):
    Auto Steal (V1/V2/V3 Instant) · Shooting Star · Butterfly Bloom ·
    Wisp & Banjo · Auto Mutation · Auto Place Egg · Auto Treadmill ·
    Auto Hatch & Equip · Auto Sell (Pet/Egg) · Auto Fuse · Auto Favorite

  UI:
    - Library  : ThorUi v2 (github.com/dwisetyabudi15581/ThorUi) — branding ThorHub
    - Floating : tombol ⚡ melayang (drag bebas) + keybind RightControl

  Sumber identitas fitur (dipetakan dari script asli):
    - Remote game : ReplicatedStorage.Packages.Networking ("RE/..." / "RF/...")
    - Data game   : ReplicatedStorage.Data.*, ReplicatedStorage.Shared.*
    - Dunia       : workspace.World, WorldEggs, Plots, PlacedEggRenders,
                    GuardAreas, AreaEggSlotsClient, SafeZone
════════════════════════════════════════════════════════════════════════════]]

--────────────────────────────[ BOOTSTRAP & GUARD ]────────────────────────────
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Gill = (getgenv and getgenv()) or _G
if Gill.__THORHUB_AF_LOADED then
    local old = Gill.__THORHUB_AF_DESTROY
    if type(old) == "function" then pcall(old) end
end

-- v2.0: log bootstrap — memudahkan verifikasi versi yang berjalan
if type(print) == "function" then
    print("[ThorHub] Auto Farm v2.0 dimuat (basis kode baru SAE v172610 - self-contained)")
end

local Services = {}
local function S(name)
    if not Services[name] then
        Services[name] = game:GetService(name)
    end
    return Services[name]
end

local Players          = S("Players")
local ReplicatedStorage = S("ReplicatedStorage")
local TweenService     = S("TweenService")
local RunService       = S("RunService")
local UserInputService = S("UserInputService")
local HttpService      = S("HttpService")
local TeleportService  = S("TeleportService")
local Stats            = S("Stats")
local Lighting         = S("Lighting")
local StarterGui       = S("StarterGui")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    repeat LocalPlayer = Players.LocalPlayer task.wait(0.05) until LocalPlayer
end

local PLACE_ID  = game.PlaceId
local JOB_ID    = game.JobId
local SOURCE_URL = "https://raw.githubusercontent.com/dwisetyabudi15581/StealAnEgg/main/ThorHub-AutoFarm.lua"
local THORUI_URL = "https://raw.githubusercontent.com/dwisetyabudi15581/ThorUi/main/ThorUi.lua"
-- (loader tangguh fetchLua/queueReload didefinisikan setelah helper P)

-- pcall wrapper yang selalu aman
local function P(fn, ...)
    local a, b = pcall(fn, ...)
    if a then return b end
    return nil
end

-- round helper
local function round(n, d)
    local m = 10 ^ (d or 0)
    return math.floor(n * m + 0.5) / m
end

local function fmtNum(n)
    n = tonumber(n) or 0
    local abs = math.abs(n)
    if abs >= 1e12 then return round(n / 1e12, 2) .. "T" end
    if abs >= 1e9  then return round(n / 1e9, 2) .. "B" end
    if abs >= 1e6  then return round(n / 1e6, 2) .. "M" end
    if abs >= 1e3  then return round(n / 1e3, 1) .. "K" end
    return tostring(math.floor(n + 0.5))
end

local function lower(s) return type(s) == "string" and string.lower(s) or "" end

-- ==== loader tangguh (anti "attempt to call a nil value") ====
-- Loader satu-baris `loadstring(game:HttpGet(url))()` bisa error "attempt
-- to call a nil value" di Line 1 kalau HttpGet balas 404/rate-limit/halaman
-- error (proxy executor sering kena) — loadstring lalu return nil.
-- fetchLua: retry + mirror CDN jsDelivr + validasi isi sebelum dipakai.

local function mirrorUrl(url)
    -- raw.githubusercontent.com/user/repo/branch/x -> cdn.jsdelivr.net/gh/user/repo@branch/x
    return (string.gsub(url, "^https://raw%.githubusercontent%.com/([^/]+)/([^/]+)/([^/]+)",
        "https://cdn.jsdelivr.net/gh/%1/%2@%3"))
end

local function fetchLua(name, urls, minLen)
    minLen = minLen or 1000
    local last = "no body"
    for attempt = 1, 3 do
        for _, u in ipairs(urls) do
            local body = P(function() return game:HttpGet(u) end)
            if type(body) == "string" and #body > minLen
                and not string.match(body, "^%s*[45]%d%d") then
                return body
            end
            if type(body) == "string" and #body > 0 then
                last = string.sub(body, 1, 120)
            end
        end
        task.wait(0.6 * attempt)
    end
    error(string.format("[ThorHub] Gagal mengambil %s (cek koneksi/URL): %s",
        tostring(name), tostring(last)), 0)
end

-- versi robust untuk queue_on_teleport: kode multi-baris yang retry sendiri
-- + fallback mirror, jadi re-execute setelah hop tidak mati oleh 404 sesaat.
local function queueReload()
    if type(queue_on_teleport) ~= "function" then return end
    queue_on_teleport(string.format([[local U={"%s","%s"}
local B=nil
for _=1,3 do
for _,u in ipairs(U) do
local ok,r=pcall(function()return game:HttpGet(u)end)
if ok and type(r)=="string" and #r>1000 and not r:match("^%%s*[45]%%d%%d") then B=r break end
end
if B then break end
task.wait(0.5)
end
if B then
local f=loadstring(B)
if f then f() end
end]], SOURCE_URL, mirrorUrl(SOURCE_URL)))
end

--────────────────────────────[ REPO LAYER ]────────────────────────────
-- Lapisan akses data game. Semua akses dibungkus pcall: kalau struktur
-- game berubah, fitur terdegradasi sopan (status "tidak tersedia"),
-- tidak pernah crash.

local Repo = { Directory = nil, DirectoryOK = false, Mut = nil, Save = nil,
               SaveOK = false, SaveGet = nil, SaveWatch = nil }

-- ==== A. Asset Directory (nama -> spec {DisplayName,Icon,EarningRate,Rarity}) ====
local function resolveDirectoryFrom(mod)
    if type(mod) ~= "table" then return nil end
    local t = mod.Assets
    if type(t) == "table" then
        if type(t.Directory) == "table" then
            return t.Directory
        end
    end
    if type(t) == "table" then
        -- heuristik: kumpulan name->spec
        for _, v in pairs(t) do
            if type(v) == "table" and type(v.Rarity) == "table" then
                return t
            end
            break
        end
    end
    if type(mod.Directory) == "table" then return mod.Directory end
    return nil
end

local function tryRequire(...)
    -- ambil ModuleScript dari path bersegmen; selalu aman (pcall penuh)
    local inst = ReplicatedStorage
    for _, seg in ipairs({...}) do
        if not inst then return nil end
        local ok, next_ = pcall(function() return inst:WaitForChild(seg, 3) end)
        inst = ok and next_ or nil
    end
    if not inst or not inst:IsA("ModuleScript") then return nil end
    return P(require, inst)
end

local function probeDirectory()
    local mods = {
        tryRequire("Shared", "Util", "AssetItems"),
        tryRequire("Data", "Assets"),
        tryRequire("AssetItems"),
        tryRequire("Assets"),
    }
    for _, mod in ipairs(mods) do
        local dir = resolveDirectoryFrom(mod)
        if dir then
            -- validasi sampel
            for _, v in pairs(dir) do
                if type(v) == "table" and type(v.Rarity) == "table" then
                    return dir
                end
                break
            end
        end
    end
    return nil
end

Repo.Directory = probeDirectory()
Repo.DirectoryOK = Repo.Directory ~= nil

-- ==== B. Modul Mutations (EarningsFor) ====
do
    local m = P(function()
        return require(ReplicatedStorage:WaitForChild("Shared", 5):WaitForChild("Modules", 3):WaitForChild("Mutations", 3))
    end)
    if type(m) == "table" and type(m.EarningsFor) == "function" then
        Repo.Mut = m
    end
end

-- ==== C. Save replica (Inventory / EggInventory / Money / dst.) ====
-- Game menyimpan replika data pemain di sisi client supaya UI sendiri bisa
-- membacanya. Kami mencarinya dengan probe aman (require murni, pcall).
local function looksLikeSave(tbl)
    if type(tbl) ~= "table" then return false end
    if type(tbl.Inventory) == "table" or type(tbl.EggInventory) == "table" then
        return true
    end
    if type(tbl.Money) ~= nil and (type(tbl.Inventory) ~= nil or type(tbl.BaseUpgradeLevel) ~= nil) then
        return true
    end
    return false
end

local function probeSaveModule(mod)
    if type(mod) ~= "table" then return nil end
    -- pola B dulu (murni baca field, tanpa memanggil fungsi):
    if looksLikeSave(mod) then
        return function() return mod end
    end
    -- pola C: modul .state / .data field
    for _, name in ipairs({"state", "data", "State", "Data", "save", "Save", "profile", "Profile"}) do
        if looksLikeSave(mod[name]) then
            return function() return mod[name] end
        end
    end
    -- pola A: modul dengan .Get() / .Peek() yang mengembalikan save table
    for _, name in ipairs({"Get", "Peek", "GetAll"}) do
        if type(mod[name]) == "function" then
            local ok, res = pcall(mod[name], mod)
            if looksLikeSave(res) then
                return function() return P(mod[name], mod) end
            end
        end
    end
    return nil
end

local function initSaveDiscovery()
    local roots = {}
    local pk = ReplicatedStorage:FindFirstChild("Packages")
    if pk then table.insert(roots, pk) end
    local sh = ReplicatedStorage:FindFirstChild("Shared")
    if sh then table.insert(roots, sh) end
    table.insert(roots, ReplicatedStorage)

    local tried = 0
    for _, root in ipairs(roots) do
        for _, inst in ipairs(root:GetChildren()) do
            if tried > 60 then break end
            if inst:IsA("ModuleScript") then
                tried = tried + 1
                local name = inst.Name
                local hot = (name:lower():find("save", 1, true) or name:lower():find("data", 1, true)
                             or name:lower():find("state", 1, true) or name:lower():find("session", 1, true)
                             or name:lower():find("profile", 1, true) or name:lower():find("replica", 1, true))
                if hot then
                    local mod = P(require, inst)
                    local getter = probeSaveModule(mod)
                    if getter then
                        Repo.SaveGet = getter
                        -- sinyal perubahan (opsional)
                        if type(mod) == "table" then
                            for _, sig in ipairs({"FieldSignal", "Watch", "OnChanged", "Changed"}) do
                                if type(mod[sig]) == "function" then
                                    Repo.SaveWatch = function(field, cb)
                                        local ok, ev = pcall(mod[sig], field)
                                        if ok and type(ev) == "table" and type(ev.Connect) == "function" then
                                            return P(function() return ev:Connect(cb) end)
                                        end
                                        return nil
                                    end
                                    break
                                end
                            end
                        end
                        return
                    end
                end
            end
        end
    end
end

initSaveDiscovery()
Repo.SaveOK = Repo.SaveGet ~= nil

function Repo.SaveData()
    if Repo.SaveGet then return Repo.SaveGet() end
    return nil
end

-- leaderstats (Money / Speed) — selalu tersedia, tanpa replica
function Repo.Leader(name)
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if not ls then return nil end
    local v = ls:FindFirstChild(name)
    if v then return tonumber(v.Value) end
    return nil
end

function Repo.Money() return Repo.Leader("Money") or 0 end
function Repo.SpeedPower() return Repo.Leader("Speed") or 0 end

-- ==== D. Remote resolver ====
local function Networking()
    local pk = ReplicatedStorage:FindFirstChild("Packages")
    return pk and pk:FindFirstChild("Networking")
end

function Repo.Remote(path)
    local net = Networking()
    if not net then return nil end
    return net:FindFirstChild(path)
end

function Repo.Fire(path, ...)
    local r = Repo.Remote(path)
    if r and r:IsA("RemoteEvent") then
        return P(function(...) r:FireServer(...) end, ...)
    end
    return false
end

function Repo.Invoke(path, ...)
    local r = Repo.Remote(path)
    if r and r:IsA("RemoteFunction") then
        return r:InvokeServer(...)
    end
    return nil
end

function Repo.Connect(path, fn)
    local r = Repo.Remote(path)
    if r and r:IsA("RemoteEvent") then
        local ok, conn = pcall(function() return r.OnClientEvent:Connect(fn) end)
        if ok then return conn end
    end
    return nil
end

-- ==== E. World scanning ====
function Repo.World()
    return workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
end

function Repo.Areas()
    local w = Repo.World()
    return w and w:FindFirstChild("Areas")
end

function Repo.WorldEggs()
    -- WorldEggs = sarang egg DIMENSI HALLOWEEN (payload asli:
    -- workspace.HalloweenDimension.WorldEggs, anak model dgn atribut
    -- HalloweenEggUid + StealPrompt). Fallback lama tetap disediakan.
    local dim = Repo.HalloweenDim()
    if dim then
        local f = dim:FindFirstChild("WorldEggs")
        if f then return f end
    end
    local w = Repo.World()
    if w then
        local f = w:FindFirstChild("WorldEggs")
        if f then return f end
    end
    return workspace:FindFirstChild("WorldEggs")
end

function Repo.HalloweenDim()
    return workspace:FindFirstChild("HalloweenDimension")
end

function Repo.HalloweenSafeZone()
    -- SafeZone khusus dimensi Halloween, fallback SafeZone dunia utama
    local dim = Repo.HalloweenDim()
    local f = dim and dim:FindFirstChild("SafeZone", true)
    if f and f:IsA("BasePart") then return f end
    return Repo.SafeZone()
end

function Repo.Plots()
    return workspace:FindFirstChild("Plots")
end

function Repo.PlacedEggRenders()
    return workspace:FindFirstChild("PlacedEggRenders")
end

function Repo.GuardAreas()
    local a = Repo.Areas()
    return a and a:FindFirstChild("GuardAreas")
end

function Repo.AreaSlots()
    return workspace:FindFirstChild("AreaEggSlotsClient")
end

function Repo.SafeZone()
    local w = Repo.World()
    if w then
        local f = w:FindFirstChild("SafeZone", true)
        if f and f:IsA("BasePart") then return f end
    end
    return workspace:FindFirstChild("SafeZone", true)
end

-- plot milik sendiri (dicocokkan lewat PlotSign)
function Repo.OwnPlot()
    local plots = Repo.Plots()
    if not plots then return nil end
    local myName = lower(LocalPlayer.Name)
    local myDisp = lower(LocalPlayer.DisplayName)
    for _, plot in ipairs(plots:GetChildren()) do
        local sign = plot:FindFirstChild("PlotSign", true)
        if sign then
            local pn = sign:FindFirstChild("PlayerPlotSign", true)
            if pn then
                local frame = pn:FindFirstChild("Frame", true)
                if frame then
                    local label = frame:FindFirstChild("PlayerName", true)
                    if label and label:IsA("TextLabel") then
                        local t = lower(label.Text)
                        if t ~= "" and (t == myName or t == myDisp) then
                            return plot
                        end
                    end
                end
            end
        end
    end
    return nil
end

local penAnchorCache, penAnchorAt = nil, 0
function Repo.PenAnchor()
    -- titik "rumah": rata-rata posisi egg terpasang, atau StarterPen plot
    local now = os.clock()
    if penAnchorCache and now - penAnchorAt < 5 then return penAnchorCache end
    penAnchorAt = now

    local renders = Repo.PlacedEggRenders()
    local uid = tostring(LocalPlayer.UserId)
    if renders then
        local sum, n = Vector3.new(0, 0, 0), 0
        for _, m in ipairs(renders:GetChildren()) do
            if string.find(m.Name, uid, 1, true) then
                local cf = P(function()
                    if m:IsA("Model") then return m:GetPivot() else return m.CFrame end
                end)
                if cf then
                    sum = sum + cf.Position
                    n = n + 1
                end
            end
        end
        if n > 0 then
            penAnchorCache = sum / n
            return penAnchorCache
        end
    end

    local plot = Repo.OwnPlot()
    if plot then
        local sp = plot:FindFirstChild("ToUpdate", true)
        sp = (sp and sp:FindFirstChild("StarterPen")) or plot:FindFirstChild("StarterPen") or plot:FindFirstChild("CenterPoint")
        if sp then
            local cf = P(function()
                if sp:IsA("Model") then return sp:GetPivot() else return sp.CFrame end
            end)
            if cf then
                penAnchorCache = cf.Position
                return penAnchorCache
            end
        end
        local bb = P(function() local _, c = plot:GetBoundingBox() return c end)
        if bb then penAnchorCache = bb.Position return penAnchorCache end
    end
    return nil
end

-- ==== F. Resolusi nama egg & nilai ====
local RARITY = {
    ["Common"] = 1, ["Uncommon"] = 2, ["Rare"] = 3, ["Epic"] = 4,
    ["Legendary"] = 5, ["Mythic"] = 6, ["Cosmic"] = 7, ["Secret"] = 8,
    ["Eternal"] = 9, ["Divine"] = 10,
}
Repo.Rarity = RARITY
Repo.RarityOrder = {"Common", "Uncommon", "Rare", "Epic", "Legendary",
                    "Mythic", "Cosmic", "Secret", "Eternal", "Divine"}

local hwNameCache = {}
local function halloweenName(model)
    -- nama egg Halloween dari atribut + katalog HalloweenPets
    local uidAttr = model:GetAttribute("HalloweenEggUid")
    local src = model:GetAttribute("PreparedSourceName")
    if src then return src end
    if not uidAttr then return nil end
    if hwNameCache[uidAttr] then return hwNameCache[uidAttr] end
    local specs = P(function()
        return require(ReplicatedStorage:WaitForChild("Data", 5):WaitForChild("HalloweenPets", 3)).Specs
    end)
    if type(specs) == "table" then
        for id, spec in pairs(specs) do
            if type(spec) == "table" then
                if spec.EggSource == src or spec.EggModel == src then
                    hwNameCache[uidAttr] = tostring(spec.Id or id)
                    return hwNameCache[uidAttr]
                end
            end
        end
    end
    return "Mystery Egg (Zone " .. tostring(model:GetAttribute("Zone") or "?") .. ")"
end

function Repo.EggName(model)
    if not model or not model:IsA("Instance") then return "" end
    local src = model:GetAttribute("PreparedSourceName")
    if src then return tostring(src) end
    local hw = halloweenName(model)
    if hw then return hw end
    return model.Name
end

function Repo.Spec(name)
    if not Repo.DirectoryOK or type(name) ~= "string" then return nil end
    return Repo.Directory[name]
end

function Repo.RarityOf(name)
    local spec = Repo.Spec(name)
    if type(spec) == "table" and type(spec.Rarity) == "table" then
        local r = spec.Rarity
        local label = tostring(r.DisplayName or r._id or "")
        local num = tonumber(r.RarityNumber or r.Rank) or RARITY[label] or 0
        return label, num
    end
    return "", 0
end

function Repo.ScaleOf(model)
    if model:IsA("Model") then
        return tonumber(P(function() return model:GetScale() end)) or 1
    end
    return 1
end

-- nilai egg per detik: EarningRate x pengali skala x pengali mutasi
function Repo.EggValue(name, scale, mutations)
    local spec = Repo.Spec(name)
    local rate = (spec and tonumber(spec.EarningRate)) or 0
    scale = tonumber(scale) or 1
    local mult
    if scale > 5 then
        mult = (scale / 5) ^ 1.2 * 19.637875755794113
    else
        mult = scale ^ 1.85
    end
    local mutMult = 1
    if Repo.Mut and type(mutations) == "table" then
        local ok, m = pcall(Repo.Mut.EarningsFor, mutations)
        if ok and type(m) == "number" then mutMult = m end
    end
    return rate * mult * mutMult
end

-- daftar spesies egg & pet dari Directory
local eggSpecies, petSpecies = nil, nil
function Repo.Species()
    if eggSpecies then return eggSpecies, petSpecies end
    eggSpecies, petSpecies = {}, {}
    if Repo.DirectoryOK then
        for name, spec in pairs(Repo.Directory) do
            if type(spec) == "table" then
                if type(spec.Egg) == "table" then
                    table.insert(eggSpecies, tostring(name))
                elseif type(spec.Rarity) == "table" then
                    table.insert(petSpecies, tostring(name))
                end
            end
        end
        table.sort(eggSpecies)
        table.sort(petSpecies)
    end
    return eggSpecies, petSpecies
end

-- daftar area (zona) dari folder Areas
local areaCache, areaAt = nil, 0
function Repo.AreaNames()
    local now = os.clock()
    if areaCache and now - areaAt < 10 then return areaCache end
    areaAt = now
    local names = {}
    local areas = Repo.Areas()
    if areas then
        for _, a in ipairs(areas:GetChildren()) do
            if a.Name ~= "GuardAreas" then table.insert(names, a.Name) end
        end
    end
    if #names == 0 then names = {"All"} end
    areaCache = names
    return names
end

-- ==== G. Index (koleksi) pemain ====
local indexMiss, indexAt = nil, 0
function Repo.OwnedSpecies()
    -- set spesies yang sudah dimiliki (dari Inventory + EggInventory)
    local save = Repo.SaveData()
    local set = {}
    if type(save) == "table" then
        for _, key in ipairs({"Inventory", "EggInventory"}) do
            if type(save[key]) == "table" then
                for _, entry in pairs(save[key]) do
                    if type(entry) == "table" then
                        local cat = entry.Category or entry.AssetCategory
                        if cat then set[tostring(cat)] = true end
                    end
                end
            end
        end
    end
    return set
end

function Repo.IndexMissing(name)
    -- true bila spesies belum ada di Index/koleksi
    local now = os.clock()
    if indexMiss and now - indexAt < 5 then
        return indexMiss[name] == true
    end
    indexAt = now
    indexMiss = {}
    local owned = Repo.OwnedSpecies()
    local eggs = (Repo.Species())
    for _, sp in ipairs(eggs) do
        if not owned[sp] then indexMiss[sp] = true end
    end
    -- gabung juga dari Index bila replica menyediakannya
    local save = Repo.SaveData()
    if type(save) == "table" and type(save.Index) == "table" then
        for sp in pairs(save.Index) do indexMiss[sp] = nil end
    end
    return indexMiss[name] == true
end

-- ==== H. Field egg snapshot (RF) ====
-- Sumber utama data egg area dunia utama (payload asli memanggil
-- RF/EggWorld/AskFieldEggSnapshot lalu membaca .Records).
-- NON-BLOCKING: invoke dijalankan di task terpisah + guard "pending"
-- supaya pemanggil tidak pernah menggantung menunggu server.
local snapCache, snapAt = nil, -math.huge
local snapPending, snapFailed = false, 0
function Repo.FieldSnapshot(maxAge, force)
    local now = os.clock()
    if not force and snapCache and now - snapAt < (maxAge or 2) then
        return snapCache
    end
    if snapPending then return snapCache end
    if snapFailed >= 5 and snapCache and now - snapAt < 15 then
        -- remote tampaknya tak tersedia: pelankan percobaan ulang
        return snapCache
    end
    snapPending = true
    task.spawn(function()
        local ok, res = pcall(Repo.Invoke, "RF/EggWorld/AskFieldEggSnapshot")
        if ok and type(res) == "table" and type(res.Records) == "table" then
            snapCache = res
            snapAt = os.clock()
            snapFailed = 0
        else
            snapFailed = snapFailed + 1
        end
        snapPending = false
    end)
    return snapCache
end

function Repo.SnapshotOK()
    return type(snapCache) == "table" and type(snapCache.Records) == "table"
end

-- ==== H2. Modul EggState game (opsional, probe aman) ====
-- Script asli memakai modul EggState game untuk fallback curi saat
-- SmartPromptPart tidak ketemu: EggState.CarryFieldEgg(uid) dan
-- EggState.DropFieldEgg(reason). Modul dicari sekali (ModuleScript
-- bernama "EggState" di bawah Packages/Shared/ReplicatedStorage);
-- bila tidak ditemukan, fitur terdegradasi sopan lewat prompt biasa.
local eggStateMod, eggStateTried = nil, false
function Repo.EggStateModule()
    if eggStateMod or eggStateTried then return eggStateMod end
    eggStateTried = true
    local roots = {}
    local pk = ReplicatedStorage:FindFirstChild("Packages")
    if pk then table.insert(roots, pk) end
    local sh = ReplicatedStorage:FindFirstChild("Shared")
    if sh then table.insert(roots, sh) end
    table.insert(roots, ReplicatedStorage)
    for _, root in ipairs(roots) do
        local kids = P(function() return root:GetDescendants() end)
        if type(kids) == "table" then
            for _, inst in ipairs(kids) do
                local isMod = P(function()
                    return inst:IsA("ModuleScript") and inst.Name == "EggState"
                end)
                if isMod then
                    local mod = P(require, inst)
                    if type(mod) == "table"
                        and (type(mod.CarryFieldEgg) == "function"
                            or type(mod.ReadFieldEggs) == "function") then
                        eggStateMod = mod
                        return eggStateMod
                    end
                end
            end
        end
    end
    return nil
end

-- fallback curi via modul game (pola C[13] asli); return true bila terpakai.
-- Pola asli "Taking the starter egg": uid egg starter (FirstAreaEgg_..)
-- membawa akhiran _<NamaArea>:Slot_N — modul game butuh nama slotnya
-- sebagai argumen kedua; egg biasa cukup uid saja (slot = nil).
function Repo.CarryFieldEgg(uid)
    local m = Repo.EggStateModule()
    if m and type(m.CarryFieldEgg) == "function" and type(uid) == "string" and uid ~= "" then
        local slot = string.match(uid, "_([%w ]+:Slot_%d+)$")
        P(m.CarryFieldEgg, uid, slot)
        return true
    end
    return false
end

-- lepas egg via modul game (pola WrongEgg asli: DropFieldEgg + tunggu <=1s)
function Repo.DropFieldEgg()
    local m = Repo.EggStateModule()
    if m and type(m.DropFieldEgg) == "function" then
        P(m.DropFieldEgg, "PlayerRequest")
        return true
    end
    return false
end

-- ==== I. Malam / siklus area ====
local cycleMod = nil
function Repo.IsNight()
    cycleMod = cycleMod or P(function()
        return require(ReplicatedStorage:WaitForChild("Shared", 5):WaitForChild("Util", 3):WaitForChild("AreaEggCycle", 3))
    end)
    if type(cycleMod) == "table" and type(cycleMod.IsNightPhase) == "function" then
        local ok, res = pcall(cycleMod.IsNightPhase, workspace:GetServerTimeNow())
        if ok then return res == true end
    end
    return false
end

--════════════ BAGIAN 1 — MOVEMENT & MODUL INTI ════════════
--────────────────────────────[ MOVEMENT LAYER ]────────────────────────────
-- Sistem gerak meniru script asli: langkah pivot per-frame (bukan tween
-- kaku), klaim kepemilikan gerak antar-fitur (biar tidak saling rebut),
-- dan fisika "bawa egg" berbasis AssemblyLinearVelocity.

local Movement = { Owner = nil, PlaceWanted = false, StealFirst = false }
local Character = { Parts = nil, Original = nil, Clone = nil }

function Movement.Root()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsDescendantOf(workspace) then return hrp end
    return nil
end

function Movement.Humanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid") or nil
end

function Movement.Pos()
    local r = Movement.Root()
    return r and r.Position or nil
end

function Movement.WalkSpeed()
    local hum = Movement.Humanoid()
    return (hum and hum.WalkSpeed) or 100
end

function Movement.Claim(owner)
    if Movement.Owner == nil then
        Movement.Owner = owner
        return true
    end
    return Movement.Owner == owner
end

function Movement.Release(owner)
    if Movement.Owner == owner then Movement.Owner = nil end
end

-- langkah menuju posisi: pivot per Heartbeat, jarak per langkah dibatasi
function Movement.StepTo(pos, step, speedCap)
    local root = Movement.Root()
    if not root then return false, "no-root" end
    local delta = pos - root.Position
    local dist = delta.Magnitude
    if dist < 1 then return true end
    local stepLen = math.min(dist, step or 40)
    local cf
    if speedCap then stepLen = math.min(stepLen, speedCap) end
    cf = CFrame.lookAt(root.Position + delta.Unit * stepLen, pos)
    root.CFrame = CFrame.new(cf.Position) * CFrame.Angles(0, math.atan2(-delta.X, -delta.Z), 0)
    return dist <= stepLen
end

-- jalan halus beberapa frame (dipakai fitur yang butuh gerak "terlihat")
function Movement.WalkTo(pos, timeout, done)
    timeout = timeout or 8
    local until_ = os.clock() + timeout
    while os.clock() < until_ do
        local root = Movement.Root()
        if not root then return false end
        if done and done() then return true end
        local d = pos - root.Position
        if d.Magnitude < 3 then return true end
        Movement.StepTo(pos, 12)
        task.wait()
    end
    return false
end

-- terbang ke posisi: langkah besar per frame sampai sampai
function Movement.FlyTo(pos, done, step)
    step = step or 40
    while true do
        local root = Movement.Root()
        if not root then return false end
        if done and done() then return true end
        local d = pos - root.Position
        if d.Magnitude < 4 then return true end
        Movement.StepTo(pos, step)
        task.wait()
    end
end

-- bawa egg dengan fisika velocity (aman antar-collision server)
-- speedMult : pengali kecepatan dasar (WalkSpeed x1.5) — dipakai mode Normal
--             (membuat slider "Carry Speed" benar-benar berpengaruh).
-- speedAbs  : kecepatan absolut studs/dtk — dipakai mode Pull Instant Steal V2
--             (default asli 3300, jangkauan 3000-4500).
function Movement.CarryTo(pos, done, timeout, speedMult, speedAbs)
    timeout = timeout or 30
    local until_ = os.clock() + timeout
    local heldY = nil
    local collided = {}
    local root = Movement.Root()
    heldY = root and root.Position.Y or nil
    while os.clock() < until_ do
        root = Movement.Root()
        if not root then break end
        if done and done() then break end
        if heldY == nil then heldY = root.Position.Y end
        -- pola asli: saat kena ragdoll (guard/tembakan pemain lain), berhenti
        -- melawan fisika — pulihkan dulu, baru lanjut antar egg.
        if Movement.IsRagged() then
            Character.AntiRagdollOnce()
            task.wait(0.15)
        else
            -- matikan collision karakter selama membawa (seperti asli)
            local char = LocalPlayer.Character
            if char then
                for _, p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide and not collided[p] then
                        collided[p] = true
                        pcall(function() p.CanCollide = false end)
                    end
                end
            end
            local delta = pos - root.Position
            delta = Vector3.new(delta.X, 0, delta.Z)
            local base = speedAbs or (Movement.WalkSpeed() * 1.5 * (speedMult or 1))
            local spd = math.min(base, delta.Magnitude / 0.05)
            local vel = Vector3.new(0, 0, 0)
            if delta.Magnitude > 3 then
                vel = delta.Unit * spd
            end
            vel = vel + Vector3.new(0, (heldY - root.Position.Y) * 8, 0)
            pcall(function() root.AssemblyLinearVelocity = vel end)
        end
        task.wait()
    end
    root = Movement.Root()
    if root then pcall(function() root.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end) end
    for p in pairs(collided) do
        if p.Parent then pcall(function() p.CanCollide = true end) end
    end
end

-- deteksi "saya memegang egg": weld ke model yang dibawa
-- model egg (nama 32 char) yang sedang di-weld ke KARAKTER KITA.
-- Ini pola "HeldByMe" script asli: model egg dibawa muncul di akar
-- workspace dengan nama GUID 32-char dan di-weld ke karakter.
-- Tool biasa (pet, dll) TIDAK dianggap membawa egg.
function Movement.MyHeldEggModel()
    local char = LocalPlayer.Character
    if not char then return nil end
    for _, m in ipairs(workspace:GetChildren()) do
        local isEggModel = P(function() return m:IsA("Model") and #m.Name == 32 end)
        if isEggModel then
            local welded = P(function()
                for _, j in ipairs(m:GetDescendants()) do
                    if j:IsA("JointInstance") or j:IsA("WeldConstraint") or j:IsA("RigidConstraint") then
                        local p0, p1 = j.Part0, j.Part1
                        for _, part in ipairs({ p0, p1 }) do
                            if typeof(part) == "Instance" and part:IsDescendantOf(char) then
                                return true
                            end
                        end
                    end
                end
                return false
            end)
            if welded then return m end
        end
    end
    return nil
end

function Movement.CarryingUid()
    -- uid egg yang sedang dibawa (model weld / tool bernama uid), bukan tool biasa
    local held = Movement.MyHeldEggModel()
    if held then return tostring(held.Name), held end
    local char = LocalPlayer.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if P(function() return t:IsA("Tool") end) then
                local nm = tostring(t.Name)
                local au = P(function() return t:GetAttribute("Uid") end)
                if #nm == 32 then return nm, t end
                if type(au) == "string" and #au >= 8 then return au, t end
            end
        end
    end
    return nil, nil
end

-- keluar treadmill bila root ter-anchor (pola asli "getting off the
-- treadmill first"): CarryTo pakai velocity — root anchored = gerak mati.
function Movement.ExitBeltIfAnchored()
    local root = Movement.Root()
    if not root then return false end
    if not P(function() return root.Anchored end) then return false end
    local hum = Movement.Humanoid()
    if hum then
        pcall(function() hum:UnequipTools() end)
        pcall(function() hum.Jump = true end)
    end
    task.wait(0.15)
    if P(function() return root.Anchored end) then
        pcall(function() root.Anchored = false end)
    end
    return true
end

--────────────────────────────[ CHARACTER FEATURES HELPERS ]────────────────────────────

function Character.OnDeathReset()
    Character.Parts = nil
    Character.Original = nil
    if Character.Clone then
        pcall(function() Character.Clone:Destroy() end)
        Character.Clone = nil
    end
end

function Character.ApplyInvisibility(on)
    local char = LocalPlayer.Character
    if not char then return end
    if on then
        if not Character.Original then
            Character.Original = {}
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") or p:IsA("Decal") then
                    Character.Original[p] = p.Transparency
                    pcall(function() p.Transparency = 1 end)
                end
            end
            local face = char:FindFirstChild("Head")
            if face then
                local fd = face:FindFirstChildOfClass("Decal")
                if fd then fd.Transparency = 1 end
            end
        end
    else
        if Character.Original then
            for p, t in pairs(Character.Original) do
                if p.Parent then pcall(function() p.Transparency = t end) end
            end
            Character.Original = nil
        end
    end
end

function Character.AntiRagdollOnce()
    local char = LocalPlayer.Character
    if not char then return end
    local endT = tonumber(P(function() return char:GetAttribute("RagdollEndTime") end))
    local now = P(function() return workspace:GetServerTimeNow() end) or 0
    if endT and endT > now then
        pcall(function() char:SetAttribute("RagdollEndTime", 0) end)
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        if P(function() return hum.PlatformStand end) then
            pcall(function() hum.PlatformStand = false end)
        end
        local st = P(function() return hum:GetState() end)
        if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end
    end
    -- lepas jebakan (trap): objek yang mengunci karakter
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("BasePart") and (t.Name:lower():find("trap") or t.Name:lower():find("snare")) then
            pcall(function() t:Destroy() end)
        end
    end
end

-- ==== deteksi ragdoll (pola C[14] asli) ====
-- Script asli mengecek atribut RagdollEndTime + state Humanoid sebelum
-- bergerak: melawan fisika saat ragdoll hanya bikin server rubber-band
-- (dan curi selalu gagal). Dipakai di seluruh jalur curi/antar egg.
function Movement.IsRagged()
    local char = LocalPlayer.Character
    if not char then return false end
    local endT = tonumber(P(function() return char:GetAttribute("RagdollEndTime") end))
    if endT then
        local now = P(function() return workspace:GetServerTimeNow() end) or 0
        if endT > now then return true end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        local st = P(function() return hum:GetState() end)
        if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll then
            return true
        end
    end
    return false
end

-- pulihkan dari ragdoll lalu tunggu sampai benar-benar berdiri (max maxT).
-- Return true bila sudah bisa bergerak lagi.
function Movement.WaitUnragdoll(maxT)
    maxT = maxT or 2
    local t0 = os.clock()
    while os.clock() - t0 < maxT do
        if not Movement.IsRagged() then return true end
        Character.AntiRagdollOnce()
        task.wait(0.15)
    end
    return not Movement.IsRagged()
end

--────────────────────────────[ SCAN CACHE (anti-lag) ]────────────────────────────
-- workspace:GetDescendants() itu mahal. Semua fitur yang butuh memindai
-- isi workspace memakai cache bersama yang di-refresh tiap 4 detik.

local Scan = { cache = nil, at = 0 }

function Scan.Workspace()
    local now = os.clock()
    if not Scan.cache or now - Scan.at > 4 then
        Scan.cache = workspace:GetDescendants()
        Scan.at = now
    end
    return Scan.cache
end

--────────────────────────────[ TASK SCHEDULER ]────────────────────────────
-- Anti-lag: tidak ada loop while-true tanpa jeda. Setiap worker punya
-- interval minimum; dispatcher tunggal berjalan tiap Heartbeat.

local Labels = {}   -- name -> objek status {SetText=fn} (diisi menu builder)
local Webhook = { url = "", everyone = false, events = {}, minRarity = 0, minValue = 0 }
QueueElem = QueueElem or {}

local Tasks = { list = {}, byName = {} }

function Tasks.Add(name, interval, fn)
    Tasks.byName[name] = { name = name, interval = interval, fn = fn, next = 0,
                           busy = false, status = "" }
end

function Tasks.Remove(name)
    Tasks.byName[name] = nil
end

function Tasks.Wake(name)
    local t = Tasks.byName[name]
    if t then t.next = 0 end
end

function Tasks.Status(name, text)
    local t = Tasks.byName[name]
    if t then
        if t.status ~= text then
            t.status = text
            Tasks.byName[name] = t
        end
    end
    local lab = Labels[name]
    if lab and text ~= "" then
        pcall(lab.SetText, lab, text)
    end
end

--────────────────────────────[ NOTIFY & STATUS ]────────────────────────────

local NotifyState = { on = true }

function SetStatusOwner(labelName, label)
    Labels[labelName] = label
end

function Notify(title, text, dur)
    if not NotifyState.on then return end
    if ThorUI and ThorUI.Notify then
        P(function()
            ThorUI:Notify({ Title = title or "ThorHub", Content = text or "", Duration = dur or 4, Icon = "⚡" })
        end)
    end
end

--────────────────────────────[ FILESYSTEM / CONFIG ]────────────────────────────
-- Folder: ThorHub/Games/<PlaceId>/configs/... + config_state.json
-- Semua pcall: executor tanpa FS tetap jalan (config feature mati sopan).

local FS = { ok = false }
do
    local base = "ThorHub"
    if makefolder and writefile and readfile and isfile and isfolder then
        FS.ok = true
    end
    function FS.Path(rel)
        return base .. "/" .. rel
    end
    function FS.GamePath(rel)
        return base .. "/Games/" .. tostring(PLACE_ID) .. "/" .. rel
    end
    function FS.Ensure(path)
        -- pastikan semua segmen folder ada
        local segs = {}
        for seg in string.gmatch(path, "[^/]+") do table.insert(segs, seg) end
        local acc = ""
        for i, seg in ipairs(segs) do
            acc = (i == 1) and seg or (acc .. "/" .. seg)
            if i < #segs then
                if not isfolder(acc) then pcall(makefolder, acc) end
            end
        end
    end
    function FS.Write(path, content)
        if not FS.ok then return false end
        pcall(function()
            FS.Ensure(path)
            writefile(path, content)
        end)
        return true
    end
    function FS.Read(path)
        if not FS.ok then return nil end
        if not pcall(function() return isfile(path) end) then return nil end
        local ok, res = pcall(function() return isfile(path) and readfile(path) or nil end)
        if ok then return res end
        return nil
    end
    function FS.List(path)
        if not FS.ok then return {} end
        local ok, res = pcall(listfiles, path)
        if ok and type(res) == "table" then return res end
        return {}
    end
    function FS.Delete(path)
        if not FS.ok then return end
        pcall(delfile, path)
    end
end

local function jsonEnc(t)
    local ok, res = pcall(function() return HttpService:JSONEncode(t) end)
    if ok then return res end
    return nil
end

local function jsonDec(s)
    local ok, res = pcall(function() return HttpService:JSONDecode(s) end)
    if ok and type(res) == "table" then return res end
    return nil
end

-- ==== Config engine ====
local Config = { Data = {}, Elements = {}, Name = "Default", Startup = nil, AutoLoad = true, AutoSave = false }

function Config.Register(key, elem)
    Config.Elements[key] = elem
end

function Config.Get(key)
    return Config.Data[key]
end

function Config.Set(key, value)
    Config.Data[key] = value
end

function Config.FileList()
    local dir = FS.GamePath("configs")
    local files = FS.List(dir)
    local names = {}
    for _, f in ipairs(files) do
        local n = string.match(f, "([^/\\]+)%.json$")
        if n then table.insert(names, n) end
    end
    table.sort(names)
    if #names == 0 then names = {"Default"} end
    return names
end

function Config.FilePath(name)
    return FS.GamePath("configs/" .. tostring(name) .. ".json")
end

function Config.Save(name)
    if not FS.ok then return false, "no-fs" end
    local payload = { __thorhub = true, States = Config.Data }
    local json = jsonEnc(payload)
    if not json then return false, "encode-fail" end
    FS.Write(Config.FilePath(name), json)
    return true
end

function Config.Load(name, apply)
    if not FS.ok then return false, "no-fs" end
    local json = FS.Read(Config.FilePath(name))
    if not json then return false, "missing" end
    local data = jsonDec(json)
    if not data or type(data.States) ~= "table" then return false, "bad-json" end
    Config.Data = {}
    for k, v in pairs(data.States) do Config.Data[k] = v end
    if apply ~= false then
        for key, value in pairs(Config.Data) do
            local elem = Config.Elements[key]
            if elem and elem.Set then
                -- fire callback: supaya tabel state fitur ikut ter-update
                P(function() elem:Set(value) end)
            end
        end
    end
    return true
end

function Config.Delete(name)
    FS.Delete(Config.FilePath(name))
end

function Config.LoadState()
    -- config_state.json: { Active, Startup, AutoLoad, AutoSave }
    local json = FS.Read(FS.GamePath("config_state.json"))
    local data = json and jsonDec(json)
    if data then
        Config.Name = tostring(data.Active or "Default")
        Config.Startup = data.Startup
        Config.AutoLoad = data.AutoLoad ~= false
        Config.AutoSave = data.AutoSave == true
    end
end

function Config.SaveState()
    FS.Write(FS.GamePath("config_state.json"), jsonEnc({
        Active = Config.Name, Startup = Config.Startup,
        AutoLoad = Config.AutoLoad, AutoSave = Config.AutoSave,
    }) or "")
end

function Config.WriteAllOff()
    for key, elem in pairs(Config.Elements) do
        -- matikan semua elemen bertipe toggle
        P(function()
            if elem.__kind == "toggle" then elem:Set(false) end
        end)
    end
end

--════════════ BAGIAN 2 — ENGINE AUTO FARM ════════════
--────────────────────────────[ EGG STATE (native) ]────────────────────────────
-- Pengganti "EggState" internal script asli. Data egg area dunia utama
-- datang dari RF/EggWorld/AskFieldEggSnapshot (.Records) persis seperti
-- script asli; dimensi Halloween discan dari folder HalloweenDimension.
-- WorldEggs; egg base pemain lain dibaca dari PlacedEggRenders (root).

local EggState = {}

function EggState.OwnEggs()
    -- daftar egg sendiri: {uid = {AssetCategory, AssetScale, Mutations, Placement}}
    local save = Repo.SaveData()
    local out = {}
    if type(save) == "table" and type(save.EggInventory) == "table" then
        for uid, entry in pairs(save.EggInventory) do
            if type(entry) == "table" then
                out[tostring(uid)] = {
                    AssetCategory = tostring(entry.AssetCategory or ""),
                    AssetScale = tonumber(entry.AssetScale) or 1,
                    Mutations = type(entry.Mutations) == "table" and entry.Mutations or {},
                    Placement = entry.Placement,
                }
            end
        end
    end
    return out
end

function EggState.OwnPets()
    local save = Repo.SaveData()
    local out = {}
    if type(save) == "table" and type(save.Inventory) == "table" then
        for uid, entry in pairs(save.Inventory) do
            if type(entry) == "table" then
                out[tostring(uid)] = {
                    Category = tostring(entry.Category or ""),
                    Scale = tonumber(entry.Scale) or 1,
                    Mutations = type(entry.Mutations) == "table" and entry.Mutations or {},
                }
            end
        end
    end
    return out
end

-- ==== helper pemilik & nama egg di base ====
local function renderOwnerUid(m)
    -- Nama render mengandung UserId pemilik (pola asli: find(uid));
    -- atribut "Uid" adalah id EGG, bukan pemilik, jadi jangan dipakai.
    for _, attr in ipairs({ "OwnerUid", "PlayerUid", "Owner" }) do
        local v = m:GetAttribute(attr)
        if v and tostring(v) ~= "" then return tostring(v) end
    end
    if #m.Name == 32 then return "" end -- GUID: bukan render pemain
    local digits = {}
    for run in string.gmatch(m.Name, "%d+") do
        if #run >= 5 then table.insert(digits, run) end
    end
    for _, run in ipairs(digits) do
        local num = tonumber(run)
        if num and P(function() return Players:GetPlayerByUserId(num) end) then
            return run
        end
    end
    return digits[1] or ""
end

local ownerNameCache = {}
local function ownerDisplayName(uid)
    if ownerNameCache[uid] then return ownerNameCache[uid] end
    local name = nil
    local num = tonumber(uid)
    if num then
        local pl = P(function() return Players:GetPlayerByUserId(num) end)
        local dn = pl and P(function() return pl.DisplayName end) or nil
        if dn and dn ~= "" then name = tostring(dn) end
    end
    if not name and num then
        -- papan plot: PlotSign berteks "Nama (uid)"
        local plots = Repo.Plots()
        if plots then
            local needle = tostring(num)
            for _, plot in ipairs(plots:GetChildren()) do
                local sign = P(function() return plot:FindFirstChild("PlotSign", true) end)
                    or P(function() return plot:FindFirstChild("PlayerPlotSign", true) end)
                if sign then
                    for _, d in ipairs(sign:GetDescendants()) do
                        local hit = P(function()
                            return d:IsA("TextLabel") and string.find(d.Text, needle, 1, true)
                        end)
                        if hit then
                            local nm = string.match(d.Text, "^%s*([^%(]+)")
                            if nm and nm ~= "" then name = nm break end
                        end
                    end
                    if name then break end
                end
            end
        end
    end
    ownerNameCache[uid] = name or ("Player " .. tostring(uid))
    return ownerNameCache[uid]
end

local function baseEggLabel(m)
    -- nama egg di base: atribut -> Repo.EggName -> teks billboard -> nama model
    local viaRepo = Repo.EggName(m)
    if viaRepo and viaRepo ~= m.Name then return viaRepo end
    for _, attr in ipairs({ "PreparedSourceName", "AssetCategory", "Category", "EggName", "SourceName" }) do
        local v = m:GetAttribute(attr)
        if v and tostring(v) ~= "" then return tostring(v) end
    end
    local bb = P(function() return m:FindFirstChildWhichIsA("BillboardGui", true) end)
    if bb then
        for _, d in ipairs(bb:GetDescendants()) do
            local isText = P(function() return d:IsA("TextLabel") end)
                or P(function() return d:IsA("TextButton") end)
            local txt = isText and P(function() return d.Text end) or nil
            if type(txt) == "string" and #txt > 2 and not string.match(txt, "^[%d.,/]+") then
                return txt
            end
        end
    end
    return m.Name
end

local function makeEggEntry(model, prompt, kind, ownerUid)
    local name
    if kind == "Base" then
        name = baseEggLabel(model)
    else
        name = Repo.EggName(model)
    end
    local label, num = Repo.RarityOf(name)
    local scale = Repo.ScaleOf(model)
    local pos = P(function()
        if model:IsA("Model") then return model:GetPivot().Position else return model.CFrame.Position end
    end)
    return {
        Model = model, Prompt = prompt, Name = name,
        RarityLabel = label, RarityNum = num, Scale = scale,
        Value = Repo.EggValue(name, scale),
        Mutations = {}, Pos = pos,
        Zone = model:GetAttribute("Zone"),
        HwUid = model:GetAttribute("HalloweenEggUid"),
        Kind = kind, OwnerUid = ownerUid, OwnerName = nil,
    }
end

-- posisi model apa pun (Model -> pivot; part -> CFrame)
local function modelPos(m)
    return P(function()
        if m:IsA("Model") then return m:GetPivot().Position else return m.CFrame.Position end
    end)
end

-- model egg yang sedang dipegang pemain? (weld ke karakter)
local function weldCarrier(m)
    return P(function()
        for _, j in ipairs(m:GetDescendants()) do
            if j:IsA("JointInstance") or j:IsA("WeldConstraint") or j:IsA("RigidConstraint") then
                local p0, p1 = j.Part0, j.Part1
                for _, part in ipairs({ p0, p1 }) do
                    if typeof(part) == "Instance" and not part:IsDescendantOf(m) then
                        local anc = part:FindFirstAncestorOfClass("Model")
                        if anc and anc ~= m then
                            local plr = Players:GetPlayerFromCharacter(anc)
                            if plr then return plr.Character end
                        end
                    end
                end
            end
        end
        return nil
    end)
end

-- instance model egg area berdasar Uid (slot di AreaEggSlotsClient / GUID di root)
local function slotModelOf(uid)
    return P(function()
        return workspace:FindFirstChild(uid)
            or (Repo.AreaSlots() and Repo.AreaSlots():FindFirstChild(uid))
            or nil
    end)
end

-- entri dari record snapshot (format asli: Uid/State/AreaId/NestId/
-- BottomCFrame/CarrierUserId/AssetCategory/AssetScale/Mutations)
local function recordEntry(rec)
    if type(rec) ~= "table" then return nil end
    local uid = rec.Uid and tostring(rec.Uid) or nil
    if not uid or uid == "" then return nil end
    local state = rec.State
    if state == "Carried" or state == "Claimed" then return nil end
    local cat = tostring(rec.AssetCategory or rec.Category or "")
    local name = cat
    local spec = Repo.Spec(cat)
    if type(spec) == "table" then
        local dn = spec.DisplayName or spec._id
        if dn and tostring(dn) ~= "" then name = tostring(dn) end
    end
    if name == "" then name = uid end
    local label, num = Repo.RarityOf(cat)
    local scale = tonumber(rec.AssetScale) or 1
    local muts = type(rec.Mutations) == "table" and rec.Mutations or {}
    local m = slotModelOf(uid)
    local pos = nil
    if typeof(rec.BottomCFrame) == "CFrame" then
        pos = rec.BottomCFrame.Position
    elseif m then
        pos = modelPos(m)
    end
    return {
        Uid = uid, Kind = "Field", Model = m, Prompt = nil,
        Name = name, Category = cat,
        RarityLabel = label, RarityNum = num,
        Scale = scale, Mutations = muts,
        Value = Repo.EggValue(cat, scale, muts),
        Pos = pos, Area = tostring(rec.AreaId or ""),
        NestId = rec.NestId and tostring(rec.NestId) or nil,
        State = state, Key = "F:" .. uid,
    }
end

local feCache, feAt, feSrc = nil, 0, "?"
function EggState.FieldEggs()
    -- EGG AREA dunia utama. Sumber utama = snapshot RF (Records), lalu
    -- dilengkapi scan instance (AreaEggSlotsClient + model GUID di root)
    -- supaya panel tetap terisi walau remote tak terjangkau.
    local now = os.clock()
    if feCache and now - feAt < 2 then return feCache, feSrc end
    feAt = now
    local out, seen = {}, {}
    feSrc = Repo.SnapshotOK() and "RF" or "scan"

    local snap = Repo.FieldSnapshot(1.2, true)
    if type(snap) == "table" and type(snap.Records) == "table" then
        for _, rec in pairs(snap.Records) do
            local e = P(recordEntry, rec)
            if e and not seen[e.Key] then
                seen[e.Key] = true
                table.insert(out, e)
            end
        end
    end

    -- fallback: slot instance yang tak tercakup snapshot
    local slots = Repo.AreaSlots()
    if slots then
        for _, m in ipairs(slots:GetChildren()) do
            if P(function() return m:IsA("Model") end) and not seen["F:" .. m.Name]
                and not weldCarrier(m) then
                local name = Repo.EggName(m)
                local label, num = Repo.RarityOf(name)
                local scale = Repo.ScaleOf(m)
                seen["F:" .. m.Name] = true
                table.insert(out, {
                    Uid = m.Name, Kind = "Field", Model = m, Prompt = nil,
                    Name = name, Category = name,
                    RarityLabel = label, RarityNum = num,
                    Scale = scale, Mutations = {},
                    Value = Repo.EggValue(name, scale),
                    Pos = modelPos(m), Area = "",
                    State = "Slot", Key = "F:" .. m.Name,
                })
            end
        end
    end

    -- egg tergeletak/jatuh: model GUID (32 char + Hitbox) di akar workspace
    for _, m in ipairs(workspace:GetChildren()) do
        if P(function() return m:IsA("Model") and #m.Name == 32 end)
            and not seen["F:" .. m.Name]
            and P(function() return m:FindFirstChild("Hitbox") end)
            and not weldCarrier(m) then
            local name = Repo.EggName(m)
            local label, num = Repo.RarityOf(name)
            local scale = Repo.ScaleOf(m)
            seen["F:" .. m.Name] = true
            table.insert(out, {
                Uid = m.Name, Kind = "Field", Model = m, Prompt = nil,
                Name = name, Category = name,
                RarityLabel = label, RarityNum = num,
                Scale = scale, Mutations = {},
                Value = Repo.EggValue(name, scale),
                Pos = modelPos(m), Area = "",
                State = "Dropped", Key = "F:" .. m.Name,
            })
        end
    end

    feCache = out
    return out, feSrc
end

function EggState.HalloweenEggs()
    -- egg event dimensi Halloween: anak HalloweenDimension.WorldEggs
    -- dengan atribut HalloweenEggUid + StealPrompt aktif (persis asli).
    local out = {}
    local dim = Repo.HalloweenDim()
    local folder = dim and dim:FindFirstChild("WorldEggs") or nil
    if not folder then return out end
    for _, m in ipairs(folder:GetChildren()) do
        local uid = P(function() return m:GetAttribute("HalloweenEggUid") end)
        local prompt = P(function() return m:FindFirstChild("StealPrompt", true) end)
        local live = prompt and P(function()
            return prompt:IsA("ProximityPrompt") and prompt.Enabled
        end) or nil
        if uid and prompt and live then
            local name = Repo.EggName(m)
            local label, num = Repo.RarityOf(name)
            local scale = Repo.ScaleOf(m)
            local zone = P(function() return m:GetAttribute("Zone") end)
            table.insert(out, {
                Uid = tostring(uid), HwUid = tostring(uid), Kind = "Halloween",
                Model = m, Prompt = prompt,
                Name = name, Category = name,
                RarityLabel = label, RarityNum = num,
                Scale = scale, Mutations = {},
                Value = Repo.EggValue(name, scale),
                Pos = modelPos(m), Zone = zone,
                Area = tostring(zone or ""),
                State = "Slot", Key = "H:" .. tostring(uid),
            })
        end
    end
    return out
end

local function promptHolders(m, out)
    -- model pembawa StealPrompt: model itu sendiri, atau anak-anaknya
    local direct = P(function() return m:FindFirstChild("StealPrompt") end)
    if direct and P(function() return direct:IsA("ProximityPrompt") end) then
        table.insert(out, m)
        return
    end
    for _, c in ipairs(m:GetChildren()) do
        promptHolders(c, out)
    end
end

local stCache, stAt = nil, 0
function EggState.StealTargets()
    -- SEMUA item yang bisa dicuri: egg area (snapshot RF) + egg event
    -- Halloween + egg terpasang milik pemain lain (PlacedEggRenders,
    -- bila tersedia prompt curinya). Di-cache 3 detik biar murah.
    local now = os.clock()
    if stCache and now - stAt < 3 then return stCache end
    stAt = now
    local out, seen = {}, {}
    for _, egg in ipairs(EggState.FieldEggs()) do
        if not seen[egg.Key] then
            seen[egg.Key] = true
            table.insert(out, egg)
        end
    end
    for _, egg in ipairs(EggState.HalloweenEggs()) do
        if not seen[egg.Key] then
            seen[egg.Key] = true
            table.insert(out, egg)
        end
    end
    local renders = Repo.PlacedEggRenders()
    local myUid = tostring(LocalPlayer.UserId)
    if renders then
        for _, m in ipairs(renders:GetChildren()) do
            if not string.find(m.Name, myUid, 1, true) then
                local ownerUid = renderOwnerUid(m)
                if ownerUid ~= "" and ownerUid ~= myUid then
                    local holders = {}
                    P(promptHolders, m, holders)
                    for _, holder in ipairs(holders) do
                        local prompt = P(function() return holder:FindFirstChild("StealPrompt") end)
                        local live = prompt and P(function()
                            return prompt:IsA("ProximityPrompt") and prompt.Enabled
                        end) or nil
                        if prompt and live and not seen["B:" .. m.Name] then
                            seen["B:" .. m.Name] = true
                            local egg = makeEggEntry(holder, prompt, "Base", ownerUid)
                            egg.OwnerName = ownerDisplayName(ownerUid)
                            egg.RenderRoot = m
                            egg.Uid = tostring(P(function() return m:GetAttribute("Uid") end) or m.Name)
                            egg.Key = "B:" .. m.Name
                            table.insert(out, egg)
                        end
                    end
                end
            end
        end
    end
    stCache = out
    return out
end

function EggState.PlacedEggsOf(userId)
    -- egg terpasang di base pemain (via PlacedEggRenders)
    local out = {}
    local renders = Repo.PlacedEggRenders()
    if not renders then return out end
    local uid = tostring(userId)
    for _, m in ipairs(renders:GetChildren()) do
        if string.find(m.Name, uid, 1, true) or tostring(m:GetAttribute("Uid") or "") == uid then
            local cf = P(function()
                if m:IsA("Model") then return m:GetPivot() else return m.CFrame end
            end)
            if cf then
                table.insert(out, { Model = m, Uid = m.Name, Pos = cf.Position })
            end
        end
    end
    return out
end

-- egg sendiri yang siap diproses (ditempatkan / di tas)
function EggState.PlacedOwn()
    local own = EggState.OwnEggs()
    local out = {}
    for uid, e in pairs(own) do
        if e.Placement ~= nil then out[uid] = e end
    end
    return out
end

function EggState.InBagOwn()
    local own = EggState.OwnEggs()
    local out = {}
    for uid, e in pairs(own) do
        if e.Placement == nil then out[uid] = e end
    end
    return out
end

--────────────────────────────[ AUTO STEAL ]────────────────────────────

local Steal = {
    on = false, areas = {}, minRarity = 0, minValue = 0, specific = {},
    -- lock = Key entry pilihan manual dari Steal Panel (string, stabil
    -- lintas pembaruan cache; di-resolve ulang tiap pick)
    lock = nil,
    missingIndex = false, dropSafe = false, priority = "Best Rarity",
    tweenSpeed = 100, carrySpeed = 100, instant = false, v2 = false, v3 = false,
    -- keluarga metode Instant Steal (pola SafeCarry asli):
    -- V1 "Instant Steal"  : antar steps + titik lepas tengah (LineDrop)
    -- V1 "Fast Delivery" : antar pakai fast tween (sama jalur dgn V2)
    -- V2 "Instant Steal V2": fast tween 3000-4500 studs/s, zona terbatas
    -- V3 "Teleport To Egg": rantai teleport — ke egg, grab, lalu ke Star
    --                        Handler / belt Admin Treadmill (belt mengantar)
    instantSteps = 3, fastDelivery = false,
    v2Approach = "Teleport", v2Speed = 3300,
    v2Zones = { ["Titan Temple"] = true, ["Light Dark"] = true, ["Enchanted Forest"] = true },
    busy = false, bad = {}, stolen = 0, best = nil, bestRank = -1,
    history = {}, lastDeliver = 0, hwDelivered = 0,
    -- pola SafeCarry.Blocked asli: uid egg yang pernah direbut guard saat
    -- diantar — di-skip 60 dtk ("the guard caught you with this egg before")
    blocked = {},
}

-- jarak horizontal (pola g() asli): hanya sumbu X-Z, tinggi diabaikan —
-- dipakai pencarian SmartPromptPart supaya tidak salah pilih antar lantai.
local function horizDist(a, b)
    local dx, dz = (a.X or 0) - (b.X or 0), (a.Z or 0) - (b.Z or 0)
    return math.sqrt(dx * dx + dz * dz)
end

-- ==== zona metode instant (peta zona asli) ====
local V3_ZONES = {
    ["Prehistoric"] = true, ["Cosmic"] = true, ["Cherry Blossom"] = true,
    ["Titan Temple"] = true, ["Light Dark"] = true, ["Enchanted Forest"] = true,
}

local function zoneKey(egg)
    local z = tostring((egg and (egg.Area or egg.Zone)) or "")
    if z == "CherryBlossom" then z = "Cherry Blossom" end
    return z
end

local function v2ZoneOk(egg)
    local z = zoneKey(egg)
    if z == "" then return false end
    return Steal.v2Zones[z] == true
end

local function v3ZoneOk(egg)
    return V3_ZONES[zoneKey(egg)] == true
end

-- mode antar egg (pola DeliveryMode asli; V3 punya jalur sendiri).
-- Prioritas: V2 (zona lolos) > V1 Fast Delivery (Pull) > V1 Steps > Normal.
local function deliveryMode(egg)
    if Steal.v2 and v2ZoneOk(egg) then return "Pull" end
    if Steal.instant then
        if Steal.fastDelivery then return "Pull" end
        return "Steps"
    end
    return "Normal"
end

-- pengukur FPS/ping untuk dialog konfirmasi Instant Steal V2 (pola asli)
function Steal.V2Fps()
    local t0, n = os.clock(), 0
    while os.clock() - t0 < 0.5 do
        RunService.Heartbeat:Wait()
        n = n + 1
    end
    return n / math.max(os.clock() - t0, 0.01)
end

function Steal.V2Ping()
    local ok, v = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if ok and tonumber(v) then return tonumber(v) end
    local ok2, p = pcall(function() return LocalPlayer:GetNetworkPing() end)
    if ok2 and tonumber(p) then return tonumber(p) * 1000 end
    return 0
end

local function stealAreaOk(egg)
    if next(Steal.areas) == nil then return true end
    -- area/zone hanya untuk egg lapangan; egg di base pemain lain selalu lolos
    if egg.Kind == "Base" then return true end
    -- egg snapshot punya AreaId resmi (mis. "Forest") langsung dari server
    local area = tostring(egg.Area or egg.Zone or "")
    if area ~= "" and Steal.areas[area] then return true end
    -- cocokkan nama area juga lewat posisi (folder Areas)
    local areas = Repo.Areas()
    if areas and egg.Pos then
        for name, sel in pairs(Steal.areas) do
            if sel then
                local a = areas:FindFirstChild(name)
                if a then
                    local ok, cf, size = pcall(function() local c, s = a:GetBoundingBox() return c, s end)
                    if ok and cf then
                        local rel = cf:PointToObjectSpace(egg.Pos)
                        if math.abs(rel.X) <= size.X / 2 and math.abs(rel.Z) <= size.Z / 2 then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

local function stealFilterOk(egg)
    if not stealAreaOk(egg) then return false end
    -- "Target Specific Eggs" memakai kategori aset (kunci Directory),
    -- persis opsi menu; fallback ke nama tampilan
    local specificKey = egg.Category or egg.Name
    if next(Steal.specific) ~= nil and not Steal.specific[specificKey] then return false end
    if Steal.minRarity > 0 and egg.RarityNum < Steal.minRarity then return false end
    if Steal.minValue > 0 and egg.Value < Steal.minValue then return false end
    if Steal.missingIndex and not Repo.IndexMissing(egg.Category or egg.Name) then return false end
    return true
end

local function stealScore(egg)
    local p = Steal.priority
    if p == "Best Rarity" then return egg.RarityNum * 1e12 + egg.Value end
    if p == "Biggest Weight" then return egg.Scale * 1e12 + egg.Value end
    if p == "Best Mutation" then return #egg.Mutations * 1e12 + egg.Value end
    if p == "Highest Value" then return egg.Value end
    if p == "Lowest Value" then return -egg.Value end
    return egg.Value
end

local function pickStealTarget()
    local targets = EggState.StealTargets()
    -- target pilihan manual dari Steal Panel selalu menang (tanpa filter);
    -- lock berupa Key, di-resolve ke entri terbaru supaya posisi live
    if Steal.lock then
        for _, egg in ipairs(targets) do
            if egg.Key == Steal.lock then return egg end
        end
        Steal.lock = nil
    end
    local best, bestScore = nil, -math.huge
    local now = os.clock()
    for _, egg in ipairs(targets) do
        -- AUTO hanya egg lapangan + Halloween (pola asli); egg base pemain
        -- lain hanya bisa dicuri manual lewat tombol Steal di panel.
        if egg.Kind ~= "Base"
            and not (Steal.bad[egg.Key] and Steal.bad[egg.Key] > now)
            and not (Steal.blocked[egg.Uid] and Steal.blocked[egg.Uid] > now) then
            if stealFilterOk(egg) then
                local sc = stealScore(egg)
                if sc > bestScore then
                    best, bestScore = egg, sc
                end
            end
        end
    end
    return best
end

-- ==== deteksi "sedang membawa egg" (pola HeldByMe asli + cache anti-flicker) ====
-- Script asli TIDAK menebak dari "ada Tool apa pun" (pet biasa BUKAN egg!).
-- Ia mengecek: (a) record snapshot ber-state Carried dengan carrier kita,
-- (b) model egg GUID-32 di workspace yang di-weld ke karakter (HeldByMe),
-- (c) atribut HalloweenCarrying — lalu watchdog 0.2 dtk dengan histeresis:
-- baru dianggap lepas setelah hilang > 0.8 dtk (pola GuessedDrop asli),
-- supaya callback cancel CarryTo tidak salah abort di tengah jalan.
-- Hasil dibaca dari CACHE — murah dan stabil, bukan scan tiap frame.

local carryState = { on = false, uid = nil, seenAt = 0 }
Steal.carryWatch = false -- disetel true oleh task Halloween (p4)

local function detectCarryNow()
    -- return uid egg yang sedang dibawa (string), atau nil
    local char = LocalPlayer.Character
    if not char then return nil end
    -- (a) record snapshot: server bilang kita pembawanya (sinyal terkuat)
    local snap = Repo.FieldSnapshot(1.2)
    if type(snap) == "table" and type(snap.Records) == "table" then
        local myId = LocalPlayer.UserId
        for _, rec in pairs(snap.Records) do
            if type(rec) == "table" and rec.State == "Carried"
                and tonumber(rec.CarrierUserId) == myId then
                return tostring(rec.Uid or "")
            end
        end
    end
    -- (b) model egg GUID-32 di-weld ke karakter kita (HeldByMe)
    local held = Movement.MyHeldEggModel()
    if held then return tostring(held.Name) end
    -- (c) atribut dimensi Halloween (pola asli)
    if P(function() return workspace:GetAttribute("HalloweenCarrying") end) == true then
        return "halloween"
    end
    -- (d) Tool bernama GUID-32 / ber-atribut Uid panjang — BUKAN tool biasa
    for _, t in ipairs(char:GetChildren()) do
        if P(function() return t:IsA("Tool") end) then
            local nm = tostring(t.Name)
            local au = P(function() return t:GetAttribute("Uid") end)
            if #nm == 32 then return nm end
            if type(au) == "string" and #au >= 8 then return au end
        end
    end
    return nil
end

Tasks.Add("stealcarry", 0.2, function()
    -- watchdog hanya hidup saat fitur curi aktif / sedang membawa
    if not (Steal.on or Steal.busy or carryState.on or Steal.carryWatch) then return end
    local uid = detectCarryNow()
    if uid then
        carryState.on = true
        carryState.uid = uid
        carryState.seenAt = os.clock()
    elseif carryState.on then
        -- histeresis: hilang > 0.8 dtk baru dianggap lepas
        if os.clock() - carryState.seenAt > 0.8 then
            carryState.on = false
            carryState.uid = nil
        end
    end
end)

local function isCarrying()
    return carryState.on == true
end

local function carryingUid()
    return carryState.uid
end

-- ==== mode antar "Steps" (V1, pola LineDrop asli) ====
-- lompat 350 stud per langkah menuju rumah, dengan jeda micro di titik
-- tengah (fraksi InstantMidDrops dari slider "Instant Steal Steps").
local function deliverSteps(target)
    local root = Movement.Root()
    if not root then return end
    local from = root.Position
    local steps = math.clamp(math.floor(tonumber(Steal.instantSteps) or 3), 1, 6)
    local deadline = os.clock() + 25
    for i = 1, steps - 1 do
        if not isCarrying() or os.clock() > deadline then return end
        local mid = from:Lerp(target, i / steps)
        Movement.FlyTo(mid, function() return not isCarrying() or os.clock() > deadline end, 350)
        task.wait(0.45) -- DropWait asli
    end
    Movement.FlyTo(target, function() return not isCarrying() or os.clock() > deadline end, 350)
end

local function deliverEgg(egg)
    -- bawa egg pulang: ke base (auto-redeem) atau drop di safe zone.
    -- Untuk egg event Halloween: antar ke SafeZone dimensi Halloween lalu
    -- minta drop via RF (pola asli AskDropEgg).
    -- Mode antar (pola SafeCarry asli): Pull (V2/Fast Delivery) →
    -- Steps (V1) → Normal.
    local claimed = Movement.Claim("steal")

    -- pola asli: jangan antar sambil naik treadmill (root anchored = gerak mati)
    Movement.ExitBeltIfAnchored()

    if P(function() return workspace:GetAttribute("HalloweenCarrying") end) == true then
        local sz = Repo.HalloweenSafeZone()
        if sz and sz:IsA("BasePart") then
            Tasks.Status("steal", "HOLD EGG  |  menuju SafeZone Halloween")
            local root = Movement.Root()
            if root then
                local rel = sz.CFrame:PointToObjectSpace(root.Position)
                local mx = math.max(sz.Size.X / 2 - 6, 0)
                local mz = math.max(sz.Size.Z / 2 - 6, 0)
                local goal = sz.CFrame:PointToWorldSpace(Vector3.new(
                    math.clamp(rel.X, -mx, mx), 0, math.clamp(rel.Z, -mz, mz)))
                Movement.CarryTo(goal, function() return not isCarrying() end, 60, Steal.carrySpeed / 100)
            end
            Repo.Invoke("RF/HalloweenDimension/AskDropEgg")
            task.wait(0.6)
            Steal.hwDelivered = Steal.hwDelivered + 1
            Tasks.Status("steal", "Halloween egg secured #" .. Steal.hwDelivered)
            Webhook.Post("Halloween Egg", "Halloween egg secured! #" .. Steal.hwDelivered, 0)
        end
        Movement.Release("steal")
        Steal.busy = false
        return
    end

    local mode = deliveryMode(egg)
    Tasks.Status("steal", "HOLD EGG  |  delivering (" .. mode .. ")")
    local wantSafe = Steal.dropSafe
    local home = nil
    if wantSafe then
        local sz = Repo.SafeZone()
        if sz and sz:IsA("BasePart") then home = sz end
    end
    if not home then
        home = Repo.PenAnchor()
    end
    if not home then
        -- fallback: tunggu di tempat (server redeem saat masuk base)
        Tasks.Status("steal", "HOLD EGG  |  no base anchor, waiting")
        task.wait(1.5)
        Movement.Release("steal")
        Steal.busy = false
        return
    end

    local target = home
    if typeof(home) == "Instance" and home:IsA("BasePart") then
        -- clamp ke dalam zona
        local root = Movement.Root()
        if root then
            local rel = home.CFrame:PointToObjectSpace(root.Position)
            local mx = math.max(home.Size.X / 2 - 8, 0)
            local mz = math.max(home.Size.Z / 2 - 8, 0)
            target = home.CFrame:PointToWorldSpace(Vector3.new(
                math.clamp(rel.X, -mx, mx), 0, math.clamp(rel.Z, -mz, mz)))
        end
    end

    if mode == "Pull" then
        -- fast tween 3000-4500 studs/s (Instant Steal V2 / Fast Delivery)
        Movement.CarryTo(target, function()
            return not isCarrying()
        end, 12, nil, Steal.v2Speed)
    elseif mode == "Steps" then
        deliverSteps(target)
    else
        Movement.CarryTo(target, function()
            return not isCarrying()
        end, 45, Steal.carrySpeed / 100)
    end

    -- beri kesempatan server redeem. Konfirmasi utama: RE verdict
    -- (RF FieldEggRedeemVerdict menaikkan Steal.lastDeliver) — bukan
    -- sekadar "tidak lagi membawa", karena egg bisa Direbut guard
    -- di tengah jalan (pola SafeCarry asli: Blocked list).
    local verdictMark = Steal.lastDeliver or 0
    local t = os.clock() + 8
    while isCarrying() and os.clock() < t and Steal.lastDeliver <= verdictMark do
        task.wait(0.1)
    end
    if isCarrying() and Steal.lastDeliver <= verdictMark then
        -- mungkin belum sampai zona redeem: lepas tool di dekat target
        local hum = Movement.Humanoid()
        if hum then pcall(function() hum:UnequipTools() end) end
        local t2 = os.clock() + 1.5
        while isCarrying() and os.clock() < t2 do task.wait(0.1) end
    end
    if Steal.lastDeliver > verdictMark then
        Tasks.Status("steal", "Delivered")
    elseif not isCarrying() then
        -- egg lepas tanpa verdict: dekat rumah = sukses redeem diam-diam,
        -- jauh dari rumah = Direbut/tercecer di jalan (guard)
        local root = Movement.Root()
        local targetPos = target
        if typeof(target) == "Instance" then
            targetPos = P(function()
                if target:IsA("BasePart") then return target.Position end
                if target:IsA("Model") then return target:GetPivot().Position end
            end)
        end
        local nearHome = root and targetPos
            and (root.Position - targetPos).Magnitude < 40
        if nearHome or targetPos == nil then
            Tasks.Status("steal", "Delivered")
            Steal.lastDeliver = os.clock()
        else
            Tasks.Status("steal", "Egg Direbut di jalan — the guard caught you with this "
                .. tostring(egg.Name) .. " before, skipping it")
            Steal.blocked[tostring(egg.Uid or egg.Key)] = os.clock() + 60
        end
    else
        Tasks.Status("steal", "Delivery stuck — egg belum masuk zona redeem, mencoba lagi")
    end
    Movement.Release("steal")
    Steal.busy = false
end

-- ==== pencarian record snapshot per Uid ====
local function fieldRecord(uid)
    local snap = Repo.FieldSnapshot(1.5)
    if type(snap) ~= "table" or type(snap.Records) ~= "table" then return nil end
    for _, rec in pairs(snap.Records) do
        if type(rec) == "table" and tostring(rec.Uid or "") == uid then
            return rec
        end
    end
    return nil
end

-- ==== prompt curi egg area (pola C[9] asli, presisi 1:1) ====
-- Prompt curi egg area TIDAK menempel di egg: game memasang part global
-- "SmartPromptPart" (anak workspace) berisi ProximityPrompt
-- "CarryAreaEgg". Asli memilih part terdekat ke EGG dengan batas 14 STUD
-- dan jarak HORIZONTAL (X-Z saja) — bukan 3D — lalu memverifikasi part itu
-- bukan milik slot egg lain (AreaEggSlotsClient) atau egg yang sedang
-- dibawa pemain lain (model 32-char ber-Hitbox). Ambil 3D-40-stud =
-- sering nembak prompt egg sebelah → curi selalu gagal.
local function nearestCarryPrompt(egg, maxDist)
    local pos = egg.Pos
    if not pos then return nil end
    -- batas jarak (pola asli): 14 stud horizontal, prompt lebih jauh
    -- dianggap melayani egg lain
    local bestPrompt, bestPart, bestD = nil, nil, maxDist or 14
    for _, m in ipairs(workspace:GetChildren()) do
        if m.Name == "SmartPromptPart" then
            local isPart = P(function() return m:IsA("BasePart") end)
            if isPart then
                local pr = P(function() return m:FindFirstChild("CarryAreaEgg") end)
                if pr and P(function() return pr:IsA("ProximityPrompt") end) then
                    local mp = P(function() return m.Position end)
                    if mp then
                        local d = horizDist(mp, pos)
                        if d < bestD then bestPrompt, bestPart, bestD = pr, m, d end
                    end
                end
            end
        end
    end
    if not bestPrompt or not bestPart then return nil end
    local pp = P(function() return bestPart.Position end)
    if not pp then return nil end
    local myD = horizDist(pp, pos)
    -- pola W asli: prompt TIDAK BOLEH lebih dekat ke slot/egg lain
    -- (margin 1.5 stud) daripada ke egg kita — kalau iya, part itu
    -- melayani egg sebelah, jangan ditembak.
    local slots = P(function() return workspace:FindFirstChild("AreaEggSlotsClient") end)
    if slots then
        for _, t in ipairs(slots:GetChildren()) do
            local tp = P(function()
                if t:IsA("Model") then return t:GetPivot().Position end
            end)
            if tp and horizDist(tp, pp) + 1.5 < myD then
                return nil
            end
        end
    end
    for _, m in ipairs(workspace:GetChildren()) do
        if P(function() return m:IsA("Model") end)
            and #tostring(m.Name) == 32
            and P(function() return m:FindFirstChild("Hitbox") end) then
            local mp = P(function() return m:GetPivot().Position end)
            if mp and horizDist(mp, pp) + 1.5 < myD then
                return nil
            end
        end
    end
    return bestPrompt
end

-- ==== langkah pendekatan menuju egg ====
-- "Move To Egg" Instant Steal V2 (pola asli): Teleport = lompatan penuh
-- satu frame; Step = rantai langkah kecil (dipakai juga V1/Normal).
local function approachStep(egg)
    if Steal.v2 and Steal.v2Approach == "Teleport" and v2ZoneOk(egg) then
        return math.huge -- teleport penuh satu frame
    end
    if Steal.instant then return 60 end
    return Steal.tweenSpeed / 100 * 40
end

-- ==== alur curi egg AREA (dunia utama, tanpa prompt di egg) ====
-- Pola C[11] asli: jendela grab 1.5 dtk per ronde, tembak prompt tiap
-- 0.06 dtk; prompt tidak ketemu -> fallback EggState.CarryFieldEgg(uid);
-- 4 miss berturut-turut = ronde gagal.
local function firePromptInstance(prompt)
    if not prompt or not prompt.Parent then return false end
    pcall(function() prompt.HoldDuration = 0 end)
    if fireproximityprompt then
        pcall(fireproximityprompt, prompt)
    else
        pcall(function() prompt:InputHoldBegin() prompt:InputHoldEnd() end)
    end
    return true
end

local function stealFieldEgg(egg)
    local step = approachStep(egg)
    local attempt = 0
    while attempt < 4 and not isCarrying() do
        attempt = attempt + 1
        -- pola C[14] asli: jangan buang jendela grab saat masih ragdoll
        -- (kena pukulan guard / pemain lain) — pulihkan dulu.
        if not Movement.WaitUnragdoll(1.5) then
            return "fail"
        end
        local rec = fieldRecord(egg.Uid)
        local m = egg.Model
        local modelAlive = m and P(function() return m.Parent ~= nil end) == true

        if rec then
            if rec.State == "Claimed" then return "taken" end
            if rec.State == "Carried" then
                if tonumber(rec.CarrierUserId) == LocalPlayer.UserId then
                    return "ok"
                end
                return "taken"
            end
            if typeof(rec.BottomCFrame) == "CFrame" then
                egg.Pos = rec.BottomCFrame.Position
            end
        elseif not modelAlive then
            return "gone" -- hilang dari snapshot & dunia: diambil/despawn
        end

        -- egg yang tiba-tiba di-weld ke orang lain = sudah diambil
        if m and modelAlive and weldCarrier(m) ~= nil then return "taken" end

        local pos = egg.Pos
        if m and modelAlive and not pos then pos = modelPos(m) end
        if not pos then return "gone" end

        -- jendela grab 1.5 dtk (pola asli), tembak tiap 0.06 dtk
        local t = os.clock() + 1.5
        local nextFire, misses = 0, 0
        while os.clock() < t and not isCarrying() do
            local root = Movement.Root()
            if not root then return "fail" end
            if Movement.IsRagged() then break end -- ronde berikutnya menunggu
            local live = (m and modelAlive and modelPos(m)) or pos
            local d = (live - root.Position).Magnitude
            if d > 6 then
                Movement.StepTo(live + Vector3.new(0, 2.5, 0), step)
            elseif os.clock() >= nextFire then
                nextFire = os.clock() + 0.06
                local prompt = nearestCarryPrompt(egg)
                if prompt then
                    firePromptInstance(prompt)
                    misses = 0
                else
                    -- fallback asli: EggState.CarryFieldEgg(uid)
                    misses = misses + 1
                    if misses >= 4 then break end
                    Repo.CarryFieldEgg(egg.Uid)
                end
            end
            task.wait()
        end
        if isCarrying() then return "ok" end
        task.wait(0.15)
    end
    if isCarrying() then return "ok" end
    local m = egg.Model
    if m and not P(function() return m.Parent ~= nil end) then return "gone" end
    return "fail"
end

-- ==== alur curi egg BER-PROMPT (Halloween / base pemain lain) ====
local function stealPromptEgg(egg)
    local model, prompt = egg.Model, egg.Prompt
    local step = approachStep(egg)
    local attempt = 0
    while attempt < 3 and not isCarrying() do
        attempt = attempt + 1
        -- pola C[14] asli: pulihkan ragdoll dulu sebelum mengejar egg
        if not Movement.WaitUnragdoll(1.5) then
            return "fail"
        end
        if not model.Parent or not prompt or not prompt.Parent then
            return (model.Parent and "fail") or "gone"
        end
        -- egg ter-weld ke pemain lain = sudah diambil (pola TakenWatch asli)
        local carrier = weldCarrier(model)
        if carrier and carrier ~= LocalPlayer.Character then return "taken" end
        local deadline = os.clock() + 3
        while os.clock() < deadline do
            local root = Movement.Root()
            if not root then break end
            if not model.Parent then break end
            if Movement.IsRagged() then break end -- coba lagi ronde berikutnya
            local pos = modelPos(model)
            if not pos then break end
            local d = pos - root.Position
            if d.Magnitude < 5 then
                firePromptInstance(prompt)
                if isCarrying() or not model.Parent then break end
                task.wait(0.06)
            else
                Movement.StepTo(pos + Vector3.new(0, 3, 0), step)
            end
            task.wait()
        end
        -- last push: tembak prompt beberapa kali
        local t = os.clock() + 1.2
        while os.clock() < t and not isCarrying() and model.Parent do
            firePromptInstance(prompt)
            task.wait(0.12)
        end
        if isCarrying() then break end
        task.wait(0.2)
    end
    if isCarrying() then return "ok" end
    if not model.Parent then return "gone" end
    return "fail"
end

-- ==== Instant Steal V3: rantai teleport (pola asli) ====
-- ke egg (BottomCFrame + 3Y) → grab (tembak prompt tiap 0.08 dtk, 3 ronde
-- x 2.5 dtk mengikuti egg) → teleport ke Star Handler / belt Admin Treadmill
-- sambil membawa egg → belt mengantarkan ke safe zone.

local V3_STAR_FALLBACK = Vector3.new(540, 70.4, -397)
local V3_BELT_FALLBACK = Vector3.new(540.05, 71.6, -369.7)

local function v3StarHandlerStand()
    local w = workspace:FindFirstChild("World")
    local b = w and w:FindFirstChild("Build")
    local sh = b and b:FindFirstChild("StarHandler")
    if sh and sh:IsA("Model") then
        local ok, cf = pcall(function() return sh:GetPivot() end)
        if ok and typeof(cf) == "CFrame" then
            return cf.Position + cf.LookVector * 6 + Vector3.new(0, 3, 0)
        end
    end
    return V3_STAR_FALLBACK
end

local function v3AdminBeltStand()
    -- pola FindAdminBelt asli: cari permukaan belt treadmill admin; fallback
    -- ke spot tersimpan (540.05, 71.6, -369.7)
    local at = workspace:FindFirstChild("AdminTreadmill")
    if at then
        local best, bestArea = nil, 0
        for _, p in ipairs(at:GetDescendants()) do
            if p:IsA("BasePart") then
                local ok, area = pcall(function() return p.Size.X * p.Size.Z end)
                if ok and area and area > bestArea then best, bestArea = p, area end
            end
        end
        if best then
            return best.Position + Vector3.new(0, best.Size.Y / 2 + 3, 0)
        end
    end
    return V3_BELT_FALLBACK
end

local function v3Teleport(pos)
    local root = Movement.Root()
    if not root then return false end
    P(function()
        root.CFrame = CFrame.new(pos)
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end)
    return true
end

local function v3StarHandlerPresent()
    local w = workspace:FindFirstChild("World")
    local b = w and w:FindFirstChild("Build")
    local sh = b and b:FindFirstChild("StarHandler")
    return sh and sh:IsA("Model") and true or false
end

local function v3Deliver()
    -- Star Handler hadir? antar ke sana; kalau tidak, naik belt Admin
    -- Treadmill (pola asli: N and StarHandler or AdminTreadmill).
    local toStar = v3StarHandlerPresent()
    local pos = toStar and v3StarHandlerStand() or v3AdminBeltStand()
    if not v3Teleport(pos) then return false end
    -- tunggu sampai egg tidak dibawa lagi (max 4 dtk; jaga posisi ala V3Hold:
    -- teleport balik kalau terdorong > 15 stud)
    local tEnd = os.clock() + 4
    while isCarrying() and os.clock() < tEnd do
        local root = Movement.Root()
        if root and (root.Position - pos).Magnitude > 15 then
            v3Teleport(pos)
        end
        task.wait(0.1)
    end
    return not isCarrying()
end

local function stealEggV3(egg)
    Tasks.Status("steal", "Instant Steal V3  |  teleporting to " .. tostring(egg.Name))
    for round = 1, 3 do
        if round > 1 then
            Tasks.Status("steal", "Instant Steal V3  |  missed, following the egg (try " .. round .. "/3)")
        end
        -- pola C[14] asli: tunggu ragdoll selesai (guard bisa memukul
        -- tepat setelah teleport masuk areanya)
        Movement.WaitUnragdoll(1.2)
        local deadline = os.clock() + 2.5
        local taken = false
        while os.clock() < deadline and not isCarrying() do
            if Movement.IsRagged() then break end
            local pos = nil
            local rec = fieldRecord(egg.Uid)
            if rec then
                if rec.State == "Claimed" then
                    taken = true
                    break
                end
                if rec.State == "Carried" then
                    if tonumber(rec.CarrierUserId) ~= LocalPlayer.UserId then
                        taken = true
                        break
                    end
                end
                if typeof(rec.BottomCFrame) == "CFrame" then
                    pos = rec.BottomCFrame.Position
                end
            end
            local m = egg.Model
            if not pos and m and m.Parent then pos = modelPos(m) end
            if not pos then return "gone" end
            -- teleport tepat di atas egg (pola asli: BottomCFrame + 3Y)
            v3Teleport(pos + Vector3.new(0, 3, 0))
            -- tembak prompt (pola asli: tiap 0.08 dtk)
            local prompt = egg.Prompt
            if not prompt or not prompt.Parent then
                if egg.Kind == "Field" then prompt = nearestCarryPrompt(egg) end
            end
            if prompt then
                firePromptInstance(prompt)
            elseif egg.Kind == "Field" then
                -- V3Grab asli: spam fallback remote CarryFieldEgg tiap ronde
                Repo.CarryFieldEgg(egg.Uid)
            end
            task.wait(0.08)
        end
        if taken then return "taken" end
        if isCarrying() then
            Tasks.Status("steal", "Instant Steal V3  |  teleporting to "
                .. (v3StarHandlerPresent() and "the Star Handler" or "the Admin Treadmill")
                .. " with the egg")
            if v3Deliver() then
                return "delivered"
            end
            return "ok" -- masih memegang: lanjut deliverEgg mode biasa
        end
        task.wait(0.2)
    end
    Tasks.Status("steal", "Instant Steal V3  |  could not grab the egg")
    return "fail"
end

-- statistik sukses curi (dipakai semua jalur, termasuk V3)
local function stealSuccess(egg)
    Steal.stolen = Steal.stolen + 1
    table.insert(Steal.history, { name = egg.Name, rarity = egg.RarityLabel, value = egg.Value, at = os.time() })
    if #Steal.history > 20 then table.remove(Steal.history, 1) end
    if egg.RarityNum >= Steal.bestRank then
        Steal.bestRank = egg.RarityNum
        Steal.best = { name = egg.Name, rarity = egg.RarityLabel, value = egg.Value }
    end
    Notify("⚡ Egg dicuri!", tostring(egg.Name) .. " [" .. tostring(egg.RarityLabel) .. "]", 4)
    Webhook.Post("Egg Stolen", string.format("**%s** [%s] — value %s/s",
        tostring(egg.Name), tostring(egg.RarityLabel), fmtNum(egg.Value)), egg.RarityNum)
end

-- ==== WrongEgg (pola asli): entri filter untuk egg yang nyasar ke tangan ====
local function heldEggEntry(heldUid)
    local snap = Repo.FieldSnapshot(0.8)
    if type(snap) ~= "table" or type(snap.Records) ~= "table" then return nil end
    for _, rec in pairs(snap.Records) do
        if type(rec) == "table" and tostring(rec.Uid or "") == heldUid then
            local cat = tostring(rec.AssetCategory or "")
            local name = cat
            local spec = Repo.Spec(cat)
            if type(spec) == "table" then
                local dn = spec.DisplayName or spec._id
                if dn and tostring(dn) ~= "" then name = tostring(dn) end
            end
            local label, num = Repo.RarityOf(cat)
            local scale = tonumber(rec.AssetScale) or 1
            local muts = type(rec.Mutations) == "table" and rec.Mutations or {}
            return {
                Uid = heldUid, Kind = "Field", Model = nil, Prompt = nil,
                Name = name == "" and heldUid or name, Category = cat,
                RarityLabel = label, RarityNum = num,
                Scale = scale, Mutations = muts,
                Value = Repo.EggValue(cat, scale, muts),
                Pos = nil, Area = tostring(rec.AreaId or ""), Zone = nil,
                State = rec.State, Key = "F:" .. heldUid,
            }
        end
    end
    return nil
end

-- lepas egg dari tangan (pola WrongEgg asli: DropFieldEgg + tunggu <= 1 dtk)
local function dropCarriedEgg()
    Repo.DropFieldEgg()
    local hum = Movement.Humanoid()
    if hum then pcall(function() hum:UnequipTools() end) end
    local t = os.clock() + 1
    while isCarrying() and os.clock() < t do
        RunService.Heartbeat:Wait()
    end
    carryState.on = false
    carryState.uid = nil
end

-- ==== tunggu guard area tidur (pola SafeCarry.Settle asli) ====
-- Guard membawa atribut GuardState ("Sleeping"/aktif). Kalau guard yang
-- berjaga dekat egg sedang aktif, menyerobot hanya bikin kena ragdoll dan
-- egg gagal dibawa — asli menunggu ("Waiting for the guard to sleep").
local function waitGuardSleep(egg)
    local pos = egg and egg.Pos
    if not pos then return end
    local t0 = os.clock()
    while os.clock() - t0 < 3 do
        local awake = nil
        for _, inst in ipairs(Scan.Workspace()) do
            local gs = P(function() return inst:GetAttribute("GuardState") end)
            if type(gs) == "string" and gs ~= "Sleeping" then
                local gp = P(function()
                    if inst:IsA("BasePart") then return inst.Position end
                    if inst:IsA("Model") then return inst:GetPivot().Position end
                end)
                if gp and (gp - pos).Magnitude < 35 then
                    awake = gs
                    break
                end
            end
        end
        if not awake then return end
        Tasks.Status("steal", "Waiting for the guard to sleep")
        task.wait(0.25)
    end
end

local function stealEgg(egg)
    local claimed = Movement.Claim("steal")
    if not claimed then
        -- teks asli saat Auto Place memegang gerakan
        Tasks.Status("steal", "Waiting for Auto Place")
        Steal.busy = false
        return
    end
    if Movement.ExitBeltIfAnchored() then
        Tasks.Status("steal", "Getting off the treadmill first")
        task.wait(0.2)
    end
    -- pola SafeCarry.Settle asli: kalau guard area sedang aktif dekat egg,
    -- tunggu sampai dia tidur (max 3 dtk) supaya tidak tertangkap basah.
    waitGuardSleep(egg)
    local res
    if Steal.v3 and v3ZoneOk(egg) then
        -- Instant Steal V3: rantai teleport + belt/Star Handler (pola asli)
        res = stealEggV3(egg)
    else
        Tasks.Status("steal", "FLY TO EGG  |  " .. tostring(egg.Name))
        if egg.Kind == "Field" and not egg.Prompt then
            res = stealFieldEgg(egg)
        else
            res = stealPromptEgg(egg)
        end
    end

    if Steal.lock and Steal.lock == egg.Key then Steal.lock = nil end
    if res == "delivered" then
        -- V3 selesai total: egg sudah diantar belt / Star Handler
        stealSuccess(egg)
        Tasks.Status("steal", "Instant Steal V3  |  delivered")
        Movement.Release("steal")
        Steal.busy = false
    elseif res == "ok" and isCarrying() then
        -- cek WrongEgg (pola asli): egg lain nyasar ke tangan?
        local heldUid = carryingUid()
        local wantUid = tostring(egg.Uid or "")
        local wrong = heldUid ~= nil and wantUid ~= ""
            and heldUid ~= wantUid and heldUid ~= "halloween"
        if wrong then
            local alt = heldEggEntry(heldUid)
            if alt and stealFilterOk(alt) then
                -- asli: "Holding another egg that still matches, delivering it"
                Tasks.Status("steal", "Holding another egg that still matches, delivering it")
                stealSuccess(alt)
                deliverEgg(alt)
                return
            end
            -- asli: "Wrong egg in hand, dropping it"
            Tasks.Status("steal", "Wrong egg in hand, dropping it")
            dropCarriedEgg()
            Steal.bad[egg.Key] = os.clock() + 4
            Movement.Release("steal")
            Steal.busy = false
            return
        end
        stealSuccess(egg)
        deliverEgg(egg)
    elseif res == "gone" or res == "taken" then
        Steal.bad[egg.Key] = os.clock() + 8
        -- teks asli saat target diambil pemain lain
        Tasks.Status("steal", "Someone took the target egg, picking another one")
        Movement.Release("steal")
        Steal.busy = false
    else
        -- gagal: blacklist sebentar (teks asli: "The egg never reached the hand")
        Steal.bad[egg.Key] = os.clock() + 20
        Tasks.Status("steal", "The egg never reached the hand — moving to another target")
        Movement.Release("steal")
        Steal.busy = false
    end
end

Tasks.Add("steal", 0.4, function()
    if not Steal.on then return end
    if Steal.busy then return end
    if isCarrying() then
        Steal.busy = true
        task.spawn(deliverEgg)
        return
    end
    local target = pickStealTarget()
    if target then
        Steal.busy = true
        task.spawn(stealEgg, target)
    else
        local total = #EggState.StealTargets()
        local fe, src = EggState.FieldEggs()
        if #fe == 0 and src ~= "RF" and not Repo.AreaSlots() then
            Tasks.Status("steal", "Idle  |  snapshot RF belum terjangkau & tidak ada slot egg terlihat")
        elseif total == 0 then
            Tasks.Status("steal", "Idle  |  belum ada egg stealable terlihat")
        else
            Tasks.Status("steal", "Idle  |  " .. total .. " egg terlihat, semua tercegat filter")
        end
    end
end)

-- event redeem (dipakai HUD & webhook)
Repo.Connect("RE/EggWorld/FieldEggRedeemVerdict", function(data)
    Steal.lastDeliver = os.clock()
    if type(data) == "table" then
        local name = tostring(data.AssetCategory or data.DisplayName or "Egg")
        local _, num = Repo.RarityOf(name)
        Webhook.Post("Egg Delivered", "**" .. name .. "** tiba di base", num)
    end
end)

--────────────────────────────[ AUTO HATCH & EQUIP ]────────────────────────────

local Hatch = { on = false, minRarity = 0, minValue = 0, specific = {}, equipBest = false,
                cooldown = {}, tries = 0 }

Tasks.Add("hatch", 2.0, function()
    if not Hatch.on then return end
    if Movement.Owner == "steal" then return end
    local placed = EggState.PlacedOwn()
    local budget = 0
    for uid, e in pairs(placed) do
        if budget >= 4 then break end
        local label, num = Repo.RarityOf(e.AssetCategory)
        if Hatch.minRarity > 0 and num < Hatch.minRarity then -- skip
        elseif Hatch.minValue > 0 and Repo.EggValue(e.AssetCategory, e.AssetScale, e.Mutations) < Hatch.minValue then -- skip
        elseif next(Hatch.specific) ~= nil and not Hatch.specific[e.AssetCategory] then -- skip
        elseif (Hatch.cooldown[uid] or 0) > os.clock() then -- skip
        else
            budget = budget + 1
            Hatch.cooldown[uid] = os.clock() + 30
            task.spawn(function()
                local ok = Repo.Invoke("RF/EggWorld/AskHatch", uid)
                if ok ~= nil and ok ~= false then
                    task.wait(0.35)
                    Repo.Invoke("RF/EggWorld/AskFinishHatch", uid)
                    Hatch.tries = Hatch.tries + 1
                    Tasks.Status("hatch", "Hatched " .. tostring(Hatch.tries) .. " eggs")
                end
            end)
        end
    end
    if budget == 0 then
        Tasks.Status("hatch", next(placed) == nil and "Tidak ada egg ditempatkan" or "Menunggu egg siap")
    end
end)

Tasks.Add("equipbest", 10.0, function()
    if not Hatch.equipBest then return end
    Repo.Invoke("RF/Haul/WearBest")
    Repo.Invoke("RF/Haul/FetchWearBestStatus")
end)

--────────────────────────────[ AUTO SELL ]────────────────────────────

local Sell = {
    petOn = false, eggOn = false,
    petRule = "Rarity And Value", petMax = 5, petValue = 0, petKeepMut = true, petBlack = {},
    eggRule = "Rarity And Value", eggMax = 5, eggValue = 0, eggKeepMut = true, eggBlack = {},
}

local function rulePass(rule, rarityOk, valueOk)
    if rule == "Rarity Only" then return rarityOk end
    if rule == "Value Only" then return valueOk end
    if rule == "Rarity And Value" then return rarityOk and valueOk end
    if rule == "Rarity Or Value" then return rarityOk or valueOk end
    return false
end

local function buildSellList(items, cfg, key)
    local out = {}
    for uid, e in pairs(items) do
        local name = e.Category or e.AssetCategory
        local label, num = Repo.RarityOf(name)
        local scale = e.Scale or e.AssetScale or 1
        local value = Repo.EggValue(name, scale, e.Mutations)
        if key == "pet" and cfg.petKeepMut and #e.Mutations > 0 then -- keep
        elseif key == "egg" and cfg.eggKeepMut and #e.Mutations > 0 then -- keep
        elseif cfg[key .. "Black"][name] then -- blacklist
        else
            local rarityOk = num < cfg[key .. "Max"]
            local valueOk = cfg[key .. "Value"] <= 0 or value < cfg[key .. "Value"]
            if rulePass(cfg[key .. "Rule"], rarityOk, valueOk) then
                table.insert(out, uid)
            end
        end
    end
    return out
end

function Sell.RunOnce()
    if not Repo.SaveOK then
        Notify("Auto Sell", "Data inventaris tidak tersedia", 4)
        return
    end
    local pets = buildSellList(EggState.OwnPets(), Sell, "pet")
    local eggs = buildSellList(EggState.OwnEggs(), Sell, "egg")
    if #pets > 0 then Repo.Fire("RE/PetSatchel/SellSelection", pets) end
    if #eggs > 0 then Repo.Fire("RE/PetSatchel/SellSelection", eggs) end
    Notify("Sell Now", "Menjual " .. #pets .. " pet & " .. #eggs .. " egg", 4)
end

Tasks.Add("sell", 5.0, function()
    if not (Sell.petOn or Sell.eggOn) then return end
    if not Repo.SaveOK then return end
    if Sell.petOn then
        local pets = buildSellList(EggState.OwnPets(), Sell, "pet")
        if #pets > 0 then
            Repo.Fire("RE/PetSatchel/SellSelection", pets)
            Tasks.Status("sell", "Sold " .. #pets .. " pets")
        end
    end
    if Sell.eggOn then
        local eggs = buildSellList(EggState.OwnEggs(), Sell, "egg")
        if #eggs > 0 then
            Repo.Fire("RE/PetSatchel/SellSelection", eggs)
            Tasks.Status("sell", "Sold " .. #eggs .. " eggs")
        end
    end
end)

--────────────────────────────[ AUTO FAVORITE ]────────────────────────────

local Fav = { on = false, rule = "Match Any", minRarity = 0, minValue = 0,
              mutations = {}, species = {}, equipped = false, unfav = false }

function Fav.Matches(e)
    local name = e.Category
    local label, num = Repo.RarityOf(name)
    local checks, pass = {}, 0
    local any = false
    if Fav.minRarity > 0 then
        table.insert(checks, num >= Fav.minRarity)
    end
    if Fav.minValue > 0 then
        table.insert(checks, Repo.EggValue(name, e.Scale, e.Mutations) >= Fav.minValue)
    end
    if next(Fav.mutations) ~= nil then
        local hit = false
        for _, m in ipairs(e.Mutations) do
            if Fav.mutations[m] then hit = true end
        end
        table.insert(checks, hit)
    end
    if next(Fav.species) ~= nil then
        table.insert(checks, Fav.species[name] == true)
    end
    if #checks == 0 then return false end
    for _, ok in ipairs(checks) do
        if ok then pass = pass + 1 end
    end
    if Fav.rule == "Match All" then return pass == #checks end
    return pass > 0
end

function Fav.RunOnce(unfavorite)
    if not Repo.SaveOK then return end
    local list = {}
    for uid, e in pairs(EggState.OwnPets()) do
        if Fav.Matches(e) then table.insert(list, uid) end
    end
    if #list > 0 then
        Repo.Fire("RE/PetSatchel/WriteFavourite", list, not unfavorite)
        Notify("Favorite", (unfavorite and "Unfavorited " or "Favorited ") .. #list .. " pets", 3)
    else
        Notify("Favorite", "Tidak ada pet yang cocok", 3)
    end
end

Tasks.Add("fav", 6.0, function()
    if not (Fav.on or Fav.equipped or Fav.unfav) then return end
    if not Repo.SaveOK then return end
    if Fav.on then
        local list = {}
        for uid, e in pairs(EggState.OwnPets()) do
            if Fav.Matches(e) then table.insert(list, uid) end
        end
        if #list > 0 then Repo.Fire("RE/PetSatchel/WriteFavourite", list, true) end
    end
    if Fav.equipped or Fav.unfav then
        local equipped = {}
        local save = Repo.SaveData()
        if type(save) == "table" and type(save.EquippedAssets) == "table" then
            for uid in pairs(save.EquippedAssets) do
                table.insert(equipped, tostring(uid))
            end
        end
        if #equipped > 0 then
            Repo.Fire("RE/PetSatchel/WriteFavourite", equipped, Fav.equipped)
        end
    end
end)

--────────────────────────────[ AUTO PLACE EGG ]────────────────────────────

local Place = { on = false, rule = "Always", order = "Biggest Size", rarities = {},
                specific = {}, minValue = 0, busy = false, placed = 0 }

function Place.Pick()
    local best, bestKey = nil, -math.huge
    for uid, e in pairs(EggState.InBagOwn()) do
        local label, num = Repo.RarityOf(e.AssetCategory)
        if next(Place.rarities) ~= nil and not Place.rarities[label] then -- skip
        elseif next(Place.specific) ~= nil and not Place.specific[e.AssetCategory] then -- skip
        elseif Place.minValue > 0 and Repo.EggValue(e.AssetCategory, e.AssetScale, e.Mutations) < Place.minValue then -- skip
        else
            local key
            if Place.order == "Biggest Size" then key = e.AssetScale
            elseif Place.order == "Highest Value" then key = Repo.EggValue(e.AssetCategory, e.AssetScale, e.Mutations)
            else key = -e.AssetScale end
            if key > bestKey then best, bestKey = uid, key end
        end
    end
    return best
end

Tasks.Add("place", 2.5, function()
    if not Place.on then return end
    if Place.busy then return end
    if Movement.Owner and Movement.Owner ~= "place" then return end
    if not Repo.SaveOK then Tasks.Status("place", "Inventaris tidak tersedia") return end
    -- aturan timing
    if Place.rule == "Steal Idle" and Steal.on and isCarrying() then return end
    if Place.rule == "After Steal" and os.clock() - Steal.lastDeliver > 10 then return end
    if Place.rule == "Night Only" and not Repo.IsNight() then
        Tasks.Status("place", "Menunggu malam") return
    end
    local uid = Place.Pick()
    if not uid then return end
    local home = Repo.PenAnchor()
    if not home then Tasks.Status("place", "Base belum ketemu") return end
    Place.busy = true
    task.spawn(function()
        if Movement.Claim("place") then
            Tasks.Status("place", "Placing eggs")
            Movement.FlyTo(home, nil, 40)
            local ok = Repo.Invoke("RF/EggWorld/AskPlaceEgg", uid)
            if ok then Place.placed = Place.placed + 1 end
            Movement.Release("place")
        end
        Place.busy = false
    end)
end)

--────────────────────────────[ AUTO MUTATE ]────────────────────────────

local Mutate = { on = false, use = {}, minRarity = 0, minValue = 0, targets = {},
                 priority = "Highest Value", cooldown = {} }

function Mutate.Pick()
    local best, bestKey = nil, -math.huge
    for uid, e in pairs(EggState.OwnEggs()) do
        if e.Placement ~= nil then
            local label, num = Repo.RarityOf(e.AssetCategory)
            if Mutate.minRarity > 0 and num < Mutate.minRarity then -- skip
            elseif Mutate.minValue > 0 and Repo.EggValue(e.AssetCategory, e.AssetScale, e.Mutations) < Mutate.minValue then -- skip
            elseif next(Mutate.targets) ~= nil and not Mutate.targets[e.AssetCategory] then -- skip
            elseif (Mutate.cooldown[uid] or 0) > os.clock() then -- skip
            else
                local key
                if Mutate.priority == "Highest Value" then key = Repo.EggValue(e.AssetCategory, e.AssetScale, e.Mutations)
                elseif Mutate.priority == "Best Rarity" then key = num
                else key = e.AssetScale end
                if key > bestKey then best, bestKey = uid, key end
            end
        end
    end
    return best
end

Tasks.Add("mutate", 6.0, function()
    if not Mutate.on then return end
    if next(Mutate.use) == nil then Tasks.Status("mutate", "Pilih minimal 1 mutasi") return end
    if not Repo.SaveOK then return end
    local uid = Mutate.Pick()
    if not uid then Tasks.Status("mutate", "Tidak ada target mutasi") return end
    Mutate.cooldown[uid] = os.clock() + 25
    -- coba tiap mutasi terpilih hingga satu diterima
    task.spawn(function()
        for name, sel in pairs(Mutate.use) do
            if sel then
                local ok = Repo.Invoke("RF/BossMastery/AskUseMutationConsumable", name, uid)
                if ok == nil then ok = Repo.Invoke("RF/BossMastery/AskUseMutationConsumable", uid, name) end
                if ok then
                    Tasks.Status("mutate", "Mutasi " .. tostring(name) .. " dipakai")
                    break
                end
            end
        end
    end)
end)

--────────────────────────────[ AUTO FUSE ]────────────────────────────

local Fuse = { on = false, mode = "Lowest Rarity First", order = "Lowest To Highest",
               maxRarity = 10, species = {}, skipMut = true, eject = true,
               cooldown = 0, fused = 0 }

function Fuse.Candidates()
    -- kumpulkan spesies yang punya >= 2 copy
    local groups = {}
    for uid, e in pairs(EggState.OwnPets()) do
        local label, num = Repo.RarityOf(e.Category)
        if num <= Fuse.maxRarity then
            if next(Fuse.species) ~= nil and not Fuse.species[e.Category] then -- skip
            elseif Fuse.skipMut and #e.Mutations > 0 then -- skip
            else
                if not groups[e.Category] then groups[e.Category] = { rarity = num, list = {} } end
                table.insert(groups[e.Category].list, uid)
            end
        end
    end
    local out = {}
    for _, g in pairs(groups) do
        if #g.list >= 2 then
            table.sort(g.list, function(a, b) return a < b end)
            table.insert(out, g)
        end
    end
    table.sort(out, function(a, b)
        if Fuse.mode == "Lowest Rarity First" then return a.rarity < b.rarity end
        if Fuse.mode == "Highest Rarity First" then return a.rarity > b.rarity end
        return false
    end)
    return out
end

Tasks.Add("fuse", 10.0, function()
    if not Fuse.on then return end
    if not Repo.SaveOK then return end
    if os.clock() < Fuse.cooldown then return end
    local groups = Fuse.Candidates()
    if #groups == 0 then Tasks.Status("fuse", "Tidak ada pasangan pet") return end
    Fuse.cooldown = os.clock() + 12
    task.spawn(function()
        if not Movement.Claim("fuse") then return end
        local g = groups[1]
        local a, b = g.list[1], g.list[2]
        if Fuse.order == "Highest To Lowest" then
            a, b = g.list[#g.list], g.list[#g.list - 1]
        end
        Tasks.Status("fuse", "Fusing " .. tostring(#g.list) .. "x pets")
        Repo.Invoke("RF/Fusery/LoadPet", a)
        task.wait(0.3)
        Repo.Invoke("RF/Fusery/LoadPet", b)
        task.wait(0.3)
        Repo.Invoke("RF/Fusery/ConfirmBriefing")
        task.wait(0.3)
        Repo.Invoke("RF/Fusery/BeginFuse")
        task.wait(1.2)
        Repo.Invoke("RF/Fusery/FinishReveal")
        Fuse.fused = Fuse.fused + 1
        Webhook.Post("Egg Fused", "Fusion ke-" .. Fuse.fused .. " selesai", 0)
        if Fuse.eject then
            task.wait(0.2)
            Repo.Invoke("RF/Fusery/EjectPet")
        end
        Movement.Release("fuse")
    end)
end)

--────────────────────────────[ TREADMILL / BASE / CLAIM ]────────────────────────────

local Tread = { on = false, upgrade = false, admin = false, riding = false }

Tasks.Add("treadupgrade", 4.0, function()
    if not Tread.upgrade then return end
    local save = Repo.SaveData()
    if type(save) ~= "table" then return end
    local level = tonumber(save.TreadmillUpgradeLevel) or 0
    local mod = P(function()
        return require(ReplicatedStorage:WaitForChild("Data", 5):WaitForChild("Treadmills", 3))
    end)
    if type(mod) ~= "table" or type(mod.GetByUpgradeLevel) ~= "function" then return end
    local ok, nextT = pcall(mod.GetByUpgradeLevel, level + 1)
    if not ok or type(nextT) ~= "table" then return end
    local price = tonumber(nextT.Price) or math.huge
    if Repo.Money() >= price then
        Repo.Invoke("RF/Treadmill/AskTierRaise")
        Tasks.Status("treadmill", "Upgraded treadmill ($" .. fmtNum(price) .. ")")
    else
        Tasks.Status("treadmill", "Nabung upgrade: $" .. fmtNum(price))
    end
end)

Tasks.Add("treadride", 1.0, function()
    if not Tread.on then return end
    if Movement.Owner and Movement.Owner ~= "tread" then return end
    if Tread.riding then return end
    -- cari treadmill: di plot sendiri (atau di mana saja kalau admin)
    local belts = {}
    local scanList
    if Tread.admin then
        scanList = Scan.Workspace()
    else
        local plot = Repo.OwnPlot()
        scanList = (plot and plot:GetDescendants()) or {}
    end
    for _, inst in ipairs(scanList) do
        local n = lower(inst.Name)
        if (n:find("treadmill", 1, true) or n:find("belt", 1, true)) and inst:IsA("BasePart") then
            table.insert(belts, inst)
        end
    end
    if #belts == 0 then return end
    local root = Movement.Root()
    if not root then return end
    table.sort(belts, function(a, b)
        return (a.Position - root.Position).Magnitude < (b.Position - root.Position).Magnitude
    end)
    if (belts[1].Position - root.Position).Magnitude > 8 then
        Tread.riding = true
        task.spawn(function()
            if Movement.Claim("tread") then
                Movement.FlyTo(belts[1].Position, nil, 35)
                Movement.Release("tread")
            end
            Tread.riding = false
        end)
    else
        Tasks.Status("treadmill", "Riding treadmill")
    end
end)
--════════════ BAGIAN 3 — WEBHOOK (milik user sendiri) ════════════
-- Objek Webhook dideklarasikan di bagian Movement/Config (forward decl).

local function httpPost(url, body)
    local fn = (syn and syn.request) or http_request or request or (http and http.request)
    if not fn then
        return P(function()
            HttpService:RequestAsync({
                Url = url, Method = "POST",
                Headers = { ["Content-Type"] = "application/json" }, Body = body,
            })
        end) ~= nil
    end
    local ok = pcall(fn, {
        Url = url, Method = "POST",
        Headers = { ["Content-Type"] = "application/json" }, Body = body,
    })
    return ok
end

-- Webhook.Post(event, message, rarityNum)
function Webhook.Post(event, message, rarityNum)
    if Webhook.url == "" then return end
    if not Webhook.events[event] then return end
    if (tonumber(rarityNum) or 0) > 0 and Webhook.minRarity > 0 and rarityNum < Webhook.minRarity then return end
    local content = message
    if Webhook.everyone then content = "@everyone " .. message end
    local payload = HttpService:JSONEncode({ content = content, username = "ThorHub", })
    task.spawn(httpPost, Webhook.url, payload)
end
--════════════ BAGIAN 4 — STAR / BUTTERFLY / WISP / BANJO ════════════
--────────────────────────────[ SHOOTING STAR ]────────────────────────────

local Star = { on = false, status = "Idle", landAt = nil, pos = nil, busy = false }

Repo.Connect("RE/ShootingStar/Fall", function(data)
    Star.status = "Star falling, lands in " .. tostring(type(data) == "table" and (data.Seconds or data.TimeLeft or "?") or "?")
    if type(data) == "table" then
        Star.pos = (typeof(data.Position) == "Vector3" and data.Position)
            or (type(data.Position) == "table" and Vector3.new(tonumber(data.Position.X) or 0, tonumber(data.Position.Y) or 0, tonumber(data.Position.Z) or 0))
            or Star.pos
    end
    Webhook.Post("Shooting Star", "Bintang jatuh! 🌟", 0)
end)
Repo.Connect("RE/ShootingStar/Claimed", function() Star.status = "Star claimed" Star.busy = false end)
Repo.Connect("RE/ShootingStar/Expired", function() Star.status = "Star expired" Star.pos = nil Star.busy = false end)
Repo.Connect("RE/ShootingStar/Slipped", function() Star.status = "Star slipped" Star.busy = false end)

Tasks.Add("star", 0.7, function()
    if not Star.on then return end
    if Star.busy then return end
    local state = Repo.Invoke("RF/ShootingStar/AskState")
    if type(state) == "table" then
        Star.status = tostring(state.Status or state.Kind or Star.status)
        Star.pos = (typeof(state.Position) == "Vector3" and state.Position) or Star.pos
    end
    if not Star.pos then Tasks.Status("star", Star.status) return end
    if Movement.Owner and Movement.Owner ~= "star" then return end
    Star.busy = true
    task.spawn(function()
        if Movement.Claim("star") then
            Tasks.Status("star", "Menangkap bintang...")
            Movement.FlyTo(Star.pos, function()
                return not Star.on
            end, 45)
            -- cari prompt di sekitar bintang & tembak
            local root = Movement.Root()
            if root then
                local PromptService = S("ProximityPromptService")
                for _, inst in ipairs(PromptService.Prompts) do
                    local near = P(function()
                        local pp = inst.Parent
                        local pos
                        if pp then
                            if pp:IsA("Model") then pos = pp:GetPivot().Position
                            elseif pp:IsA("BasePart") then pos = pp.Position end
                        end
                        return pos and (pos - root.Position).Magnitude < 12
                    end)
                    if near then
                        pcall(function() inst.HoldDuration = 0 end)
                        if fireproximityprompt then pcall(fireproximityprompt, inst) end
                        break
                    end
                end
            end
            Movement.Release("star")
        end
        Star.busy = false
    end)
end)

--────────────────────────────[ BUTTERFLIES ]────────────────────────────

local Butter = { on = false, mode = "Stand", priority = "Rarest", list = {},
                  tweenSpeed = 320, tradeUp = false, tiers = {}, essence = false, craft = false,
                  bloomCenter = nil, busy = false }

local function butterRarity(ref)
    if type(Butter.__cat) ~= "table" then
        Butter.__cat = P(function()
            return require(ReplicatedStorage:WaitForChild("Shared", 5):WaitForChild("Modules", 3):WaitForChild("ButterflyCatalog", 3))
        end)
    end
    local cat = Butter.__cat
    if type(cat) == "table" then
        for id, spec in pairs(cat) do
            if type(spec) == "table" then
                if (typeof(ref) == "Instance" and (ref.Name == id or ref:GetAttribute("Id") == id))
                    or (type(ref) == "table" and (ref.Id == id or tostring(ref.Id) == id)) then
                    local _, num = Repo.RarityOf(spec.Category or spec.Name or id)
                    return num
                end
            end
        end
    end
    return 0
end

Repo.Connect("RE/Butterflies/Spawned", function(data)
    local entry
    if typeof(data) == "Instance" then
        entry = { inst = data, pos = P(function() return data:GetPivot().Position end) }
    elseif type(data) == "table" then
        entry = { id = data.Id or data.id, pos = data.Position and Vector3.new(tonumber(data.Position.X) or 0, tonumber(data.Position.Y) or 0, tonumber(data.Position.Z) or 0) }
    end
    if entry then
        table.insert(Butter.list, entry)
        if not Butter.bloomCenter and entry.pos then Butter.bloomCenter = entry.pos end
    end
end)

Repo.Connect("RE/Butterflies/Removed", function(data) end)
Repo.Connect("RE/Butterflies/Escaped", function(data) end)

local function butterClaim(entry)
    local arg = entry.inst or entry.id
    if arg == nil then return end
    local ok = Repo.Invoke("RF/Butterflies/AskClaimNet", arg)
    if ok == nil then
        -- mungkin bentuk arg berbeda; coba beberapa varian
        if entry.id then Repo.Invoke("RF/Butterflies/AskClaimNet", tostring(entry.id)) end
    end
    for i, e in ipairs(Butter.list) do
        if e == entry then table.remove(Butter.list, i) break end
    end
end

Tasks.Add("butterflies", 0.8, function()
    if not Butter.on then return end
    -- bersihkan entri mati
    for i = #Butter.list, 1, -1 do
        local e = Butter.list[i]
        if e.inst and not e.inst.Parent then table.remove(Butter.list, i) end
    end
    if #Butter.list == 0 then
        Butter.bloomCenter = nil
        Tasks.Status("butterflies", "Menunggu kupu-kupu")
        return
    end
    if Butter.busy then return end
    if Movement.Owner and Movement.Owner ~= "butter" then return end

    local target = Butter.list[1]
    if Butter.priority == "Rarest" then
        local best = -1
        for _, e in ipairs(Butter.list) do
            local r = butterRarity(e.inst or e)
            if r > best then best, target = r, e end
        end
    else
        local root = Movement.Root()
        if root then
            local bd = math.huge
            for _, e in ipairs(Butter.list) do
                if e.pos then
                    local d = (e.pos - root.Position).Magnitude
                    if d < bd then bd, target = d, e end
                end
            end
        end
    end

    Butter.busy = true
    task.spawn(function()
        if Movement.Claim("butter") then
            if Butter.mode == "Stand" and Butter.bloomCenter then
                Movement.FlyTo(Butter.bloomCenter, nil, Butter.tweenSpeed / 100 * 40)
                Tasks.Status("butterflies", "Standing in the bloom  |  " .. #Butter.list .. " flying")
                for _, e in ipairs({ target }) do butterClaim(e) end
            else
                if target and target.pos then
                    Tasks.Status("butterflies", "Standing, catching a butterfly  |  " .. #Butter.list .. " flying")
                    Movement.FlyTo(target.pos, nil, Butter.tweenSpeed / 100 * 40)
                    butterClaim(target)
                end
            end
            if Butter.tradeUp and next(Butter.tiers) ~= nil then
                for tier, sel in pairs(Butter.tiers) do
                    if sel then Repo.Invoke("RF/Butterflies/AskTradeUp", tier) end
                end
            end
            if Butter.essence then Repo.Invoke("RF/Butterflies/AskTradeUp", "Essence") end
            if Butter.craft then Repo.Invoke("RF/Butterflies/AskCraftEssence") end
            Movement.Release("butter")
        end
        Butter.busy = false
    end)
end)

--────────────────────────────[ WISP & BANJO ]────────────────────────────

local Wisp = { on = false, threshold = 1e9, lastTry = 0 }

Tasks.Add("wisp", 20.0, function()
    if not Wisp.on then return end
    local speed = Repo.SpeedPower()
    local need = Wisp.threshold
    if speed >= need then
        if os.clock() - Wisp.lastTry > 10 then
            Wisp.lastTry = os.clock()
            Repo.Invoke("RF/WispCompanion/Request")
            Tasks.Status("wisp", "Wisp dipanggil")
        end
    else
        Tasks.Status("wisp", "Needs " .. fmtNum(need) .. " Speed Power (you have " .. fmtNum(speed) .. ")")
    end
end)

local Banjo = { on = false, busy = false }

Repo.Connect("RE/BanjoCricket/Aim", function(data)
    if not Banjo.on then return end
    local pos
    if typeof(data) == "Vector3" then pos = data
    elseif type(data) == "table" and data.Position then
        pos = Vector3.new(tonumber(data.Position.X) or 0, tonumber(data.Position.Y) or 0, tonumber(data.Position.Z) or 0)
    elseif typeof(data) == "Instance" then
        pos = P(function() return data:GetPivot().Position end)
    end
    if pos and not Banjo.busy then
        Banjo.busy = true
        task.spawn(function()
            if Movement.Claim("banjo") then
                Tasks.Status("banjo", "Menuju sasaran banjo")
                Movement.FlyTo(pos, nil, 40)
                Repo.Invoke("RF/BanjoCricket/AskClaim")
                Movement.Release("banjo")
            end
            Banjo.busy = false
        end)
    end
end)
--════════════ BAGIAN 5 — STEAL PANEL ════════════
--────────────────────────────[ STEAL PANEL ]────────────────────────────
-- UI tambahan ala script asli: panel melayang kecil yang menampilkan
-- semua item yang bisa dicuri (egg lapangan + egg di base pemain lain),
-- memilih item target untuk Auto Steal (prioritas, tanpa filter), dan
-- tombol "Steal" per baris untuk mencuri langsung. Posisi & status
-- terbuka tersimpan (config + getgenv), panel bisa dikecilkan, dan
-- drag-nya ramah mouse maupun layar sentuh.

local StealPanel = {
    gui = nil, root = nil, list = nil, rows = {}, body = {}, conns = {},
    open = false, collapsed = false, autoOpen = true, built = false,
    sort = "Best Rarity",
    SORTS = { "Best Rarity", "Highest Value", "Biggest Weight", "Nearest" },
    sig = "", selected = nil,
    lblAuto = nil, lblHw = nil, lblEggs = nil, lblSort = nil,
    lblNight = nil, lblSel = nil,
}

-- palet & font persis ThorUi, biar satu keluarga dengan menu utama
local SP_BG     = Color3.fromRGB(11, 14, 23)
local SP_CARD   = Color3.fromRGB(21, 26, 41)
local SP_CARDH  = Color3.fromRGB(28, 36, 56)
local SP_ACCENT = Color3.fromRGB(0, 195, 255)
local SP_GOLD   = Color3.fromRGB(255, 190, 0)
local SP_TEXT   = Color3.fromRGB(240, 244, 255)
local SP_DIM    = Color3.fromRGB(145, 155, 180)
local SP_STROKE = Color3.fromRGB(45, 58, 88)
local SP_DARK   = Color3.fromRGB(30, 24, 0)

local function spNew(class, props, parent)
    local inst = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            P(function() inst[k] = v end)
        end
    end
    if parent then
        P(function() inst.Parent = parent end)
    end
    return inst
end

local function spCorner(parent, r)
    spNew("UICorner", { CornerRadius = UDim.new(0, r or 6) }, parent)
end

local function spStroke(parent)
    spNew("UIStroke", { Color = SP_STROKE, Thickness = 1 }, parent)
end

function StealPanel.Destroy()
    for _, c in ipairs(StealPanel.conns) do
        P(function() c:Disconnect() end)
    end
    StealPanel.conns = {}
    if StealPanel.gui then
        P(function() StealPanel.gui:Destroy() end)
    end
    StealPanel.gui = nil
    StealPanel.root = nil
    StealPanel.list = nil
    StealPanel.rows = {}
    StealPanel.built = false
    StealPanel.open = false
    StealPanel.sig = ""
end

local function destroyOldPanels()
    -- buang panel dari eksekusi sebelumnya (re-execute / rejoin)
    local scopes = {}
    if gethui then
        local h = P(gethui)
        if h then table.insert(scopes, h) end
    end
    if LocalPlayer then
        local pg = P(function() return LocalPlayer:FindFirstChild("PlayerGui") end)
        if pg then table.insert(scopes, pg) end
    end
    for _, scope in ipairs(scopes) do
        for _, d in ipairs(scope:GetChildren()) do
            if d.Name == "ThorHubStealPanel" then
                P(function() d:Destroy() end)
            end
        end
    end
end

local function selectEgg(eg)
    -- entry snapshot tidak punya Model; validasi cukup lewat Key
    if not eg or not eg.Key then return end
    StealPanel.selected = eg
    Steal.lock = eg.Key
    Tasks.Status("steal", "Target dipilih: " .. tostring(eg.Name))
end

local function stealNow(eg)
    if not eg or not eg.Key then return end
    StealPanel.selected = eg
    Steal.lock = eg.Key
    if Steal.busy then
        Notify("Steal Panel", "Masih sibuk — target ini disimpan sebagai prioritas", 3)
        return
    end
    Steal.busy = true
    task.spawn(stealEgg, eg)
end

local function sortTargets(targets, mode)
    local sorted = {}
    for _, t in ipairs(targets) do sorted[#sorted + 1] = t end
    if mode == "Highest Value" then
        table.sort(sorted, function(a, b) return (a.Value or 0) > (b.Value or 0) end)
    elseif mode == "Biggest Weight" then
        table.sort(sorted, function(a, b) return (a.Scale or 1) > (b.Scale or 1) end)
    elseif mode == "Nearest" then
        table.sort(sorted, function(a, b) return (a.Dist or math.huge) < (b.Dist or math.huge) end)
    else -- Best Rarity (default)
        table.sort(sorted, function(a, b)
            local ka = (a.RarityNum or 0) * 1e9 + (a.Value or 0)
            local kb = (b.RarityNum or 0) * 1e9 + (b.Value or 0)
            return ka > kb
        end)
    end
    return sorted
end

local function rebuildRows(sorted)
    local list = StealPanel.list
    if not list then return end
    for _, r in ipairs(StealPanel.rows) do
        P(function() r.frame:Destroy() end)
    end
    StealPanel.rows = {}
    local n = math.min(#sorted, 60)
    for i = 1, n do
        local eg = sorted[i]
        local row = spNew("TextButton", {
            Name = "Row",
            Size = UDim2.new(1, -6, 0, 30),
            BackgroundColor3 = SP_CARD,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
        }, list)
        spCorner(row, 5)

        local disp = tostring(eg.Name)
        if eg.Kind == "Base" then
            disp = disp .. " @ " .. tostring(eg.OwnerName or "?")
        elseif eg.Kind == "Halloween" then
            disp = "[HW] " .. disp
        elseif eg.Area and eg.Area ~= "" then
            disp = disp .. "  [" .. tostring(eg.Area) .. "]"
        end
        if #disp > 30 then disp = disp:sub(1, 29) .. "..." end
        local rnum = eg.RarityNum or 0

        spNew("TextLabel", {
            Size = UDim2.new(0, 30, 1, 0), Position = UDim2.new(0, 6, 0, 0),
            BackgroundTransparency = 1, Font = Enum.Font.Gotham,
            TextSize = 11, TextColor3 = SP_DIM,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "#" .. i,
        }, row)

        spNew("TextLabel", {
            Size = UDim2.new(1, -238, 1, 0), Position = UDim2.new(0, 40, 0, 0),
            BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
            TextSize = 12, TextColor3 = SP_TEXT,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = disp,
        }, row)

        spNew("TextLabel", {
            Size = UDim2.new(0, 52, 1, 0), Position = UDim2.new(1, -196, 0, 0),
            BackgroundTransparency = 1, Font = Enum.Font.Gotham,
            TextSize = 10,
            TextColor3 = rnum >= 5 and SP_GOLD or (rnum >= 3 and SP_ACCENT or SP_DIM),
            TextXAlignment = Enum.TextXAlignment.Right,
            Text = (eg.RarityLabel and eg.RarityLabel ~= "") and tostring(eg.RarityLabel) or "-",
        }, row)

        spNew("TextLabel", {
            Size = UDim2.new(0, 54, 1, 0), Position = UDim2.new(1, -142, 0, 0),
            BackgroundTransparency = 1, Font = Enum.Font.Gotham,
            TextSize = 10, TextColor3 = SP_ACCENT,
            TextXAlignment = Enum.TextXAlignment.Right,
            Text = fmtNum(eg.Value) .. "/s",
        }, row)

        local dst = spNew("TextLabel", {
            Size = UDim2.new(0, 34, 1, 0), Position = UDim2.new(1, -84, 0, 0),
            BackgroundTransparency = 1, Font = Enum.Font.Gotham,
            TextSize = 10, TextColor3 = SP_DIM,
            TextXAlignment = Enum.TextXAlignment.Right,
            Text = "?",
        }, row)

        local stealBtn = spNew("TextButton", {
            Size = UDim2.new(0, 44, 0, 22), Position = UDim2.new(1, -46, 0, 4),
            BackgroundColor3 = SP_ACCENT, BorderSizePixel = 0,
            Font = Enum.Font.GothamBold, TextSize = 11,
            TextColor3 = Color3.fromRGB(8, 12, 20), Text = "Steal",
        }, row)
        spCorner(stealBtn, 5)

        P(function() stealBtn.Activated:Connect(function() stealNow(eg) end) end)
        P(function() row.Activated:Connect(function() selectEgg(eg) end) end)

        table.insert(StealPanel.rows, { frame = row, eg = eg, dst = dst })
    end
    P(function() list.CanvasSize = UDim2.new(0, 0, 0, #StealPanel.rows * 32 + 4) end)
end

function StealPanel.Update()
    local root = StealPanel.root
    if not root or not StealPanel.open then return end

    local targets = EggState.StealTargets()
    local myRoot = Movement.Root()
    local myPos = myRoot and myRoot.Position or nil

    -- bar status
    if StealPanel.lblAuto then
        StealPanel.lblAuto.Text = Steal.on and "Auto Steal: ON" or "Auto Steal: OFF"
        StealPanel.lblAuto.BackgroundColor3 = Steal.on and SP_GOLD or SP_CARD
        StealPanel.lblAuto.TextColor3 = Steal.on and SP_DARK or SP_DIM
    end
    if StealPanel.lblHw then
        local hwEl = Config.Elements["admin/hwsteal"]
        local hwOn = (hwEl and hwEl:Get() == true) or false
        StealPanel.lblHw.Text = hwOn and "Halloween: ON" or "Halloween: OFF"
        StealPanel.lblHw.BackgroundColor3 = hwOn and SP_GOLD or SP_CARD
        StealPanel.lblHw.TextColor3 = hwOn and SP_DARK or SP_DIM
    end

    local liveKeys, nField, nBase, nHw = {}, 0, 0, 0
    for _, t in ipairs(targets) do
        liveKeys[t.Key] = true
        if t.Kind == "Base" then
            nBase = nBase + 1
        elseif t.Kind == "Halloween" then
            nHw = nHw + 1
        else
            nField = nField + 1
        end
        if myPos and t.Pos then
            t.Dist = (t.Pos - myPos).Magnitude
        else
            t.Dist = nil
        end
    end
    if StealPanel.lblEggs then
        StealPanel.lblEggs.Text = string.format("Eggs: %d (F%d/H%d/B%d)",
            #targets, nField, nHw, nBase)
    end
    if StealPanel.lblSort then
        StealPanel.lblSort.Text = "Sort: " .. tostring(StealPanel.sort)
    end
    if StealPanel.lblNight then
        local ct = tonumber(P(function() return Lighting.ClockTime end)) or 12
        local night = ct >= 18 or ct < 6
        StealPanel.lblNight.Text = night and "Night" or "Day"
        StealPanel.lblNight.TextColor3 = night and SP_GOLD or SP_DIM
    end

    -- seleksi valid? (Key tetap ada di daftar target terbaru)
    local sel = StealPanel.selected
    if sel and not (liveKeys[sel.Key] or (sel.Model and sel.Model.Parent)) then
        StealPanel.selected = nil
        sel = nil
    end
    if Steal.lock and not liveKeys[Steal.lock] then
        Steal.lock = nil
    end
    if StealPanel.lblSel then
        if sel then
            StealPanel.lblSel.Text = "Selected: " .. tostring(sel.Name)
                .. (sel.Kind == "Base" and (" @ " .. tostring(sel.OwnerName or "?")) or "")
        else
            StealPanel.lblSel.Text = "Selected: none (klik baris di bawah untuk memilih)"
        end
    end

    if StealPanel.collapsed then return end

    local sorted = sortTargets(targets, StealPanel.sort)

    -- bangun ulang hanya kalau komposisi berubah (hemat CPU)
    local sigParts = {}
    for _, t in ipairs(sorted) do
        sigParts[#sigParts + 1] = tostring(t.Key) .. ":" .. tostring(t.Name)
            .. ":" .. tostring(t.RarityNum)
    end
    local sig = table.concat(sigParts, "|")
    if sig ~= StealPanel.sig then
        StealPanel.sig = sig
        rebuildRows(sorted)
    end

    -- update teks tiap baris (jarak berubah terus)
    for _, r in ipairs(StealPanel.rows) do
        local eg = r.eg
        local alive = (eg.Model and eg.Model.Parent ~= nil) or liveKeys[eg.Key] == true
        P(function()
            r.frame.Visible = alive and true or false
            if not alive then return end
            r.dst.Text = eg.Dist and (tostring(math.floor(eg.Dist + 0.5)) .. "m") or "?"
            local isSel = StealPanel.selected and StealPanel.selected.Key == eg.Key
            r.frame.BackgroundColor3 = isSel and SP_CARDH or SP_CARD
        end)
    end
end

function StealPanel.Build()
    StealPanel.Destroy()
    destroyOldPanels()

    local gui = spNew("ScreenGui", {
        Name = "ThorHubStealPanel", ResetOnSpawn = false, DisplayOrder = 55,
    })
    local parent = nil
    if gethui then parent = P(gethui) end
    if not parent and LocalPlayer then
        parent = P(function() return LocalPlayer:FindFirstChild("PlayerGui") end)
    end
    if parent then P(function() gui.Parent = parent end) end
    StealPanel.gui = gui

    local root = spNew("Frame", {
        Name = "Root", Size = UDim2.new(0, 360, 0, 438),
        BackgroundColor3 = SP_BG, BorderSizePixel = 0, Active = true,
    }, gui)
    spCorner(root, 10)
    spStroke(root)
    StealPanel.root = root

    local pos = Config.Get("panel/pos")
    if type(pos) ~= "table" and Gill then pos = Gill.__THORHUB_PANEL_POS end
    if type(pos) == "table" and tonumber(pos.x) and tonumber(pos.y) then
        root.Position = UDim2.new(0, pos.x, 0, pos.y)
    else
        root.Position = UDim2.new(0, 14, 0.5, -219)
    end

    -- == header (drag handle) ==
    local header = spNew("Frame", {
        Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1,
    }, root)

    spNew("TextLabel", {
        Size = UDim2.new(1, -76, 1, 0), Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
        TextSize = 14, TextColor3 = SP_TEXT,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Steal Panel",
    }, header)

    local collapseBtn = spNew("TextButton", {
        Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(1, -60, 0, 4),
        BackgroundColor3 = SP_CARD, BorderSizePixel = 0,
        Font = Enum.Font.GothamBold, TextSize = 14,
        TextColor3 = SP_DIM, Text = "-",
    }, header)
    spCorner(collapseBtn, 6)

    local closeBtn = spNew("TextButton", {
        Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(1, -30, 0, 4),
        BackgroundColor3 = SP_CARD, BorderSizePixel = 0,
        Font = Enum.Font.GothamBold, TextSize = 14,
        TextColor3 = SP_DIM, Text = "x",
    }, header)
    spCorner(closeBtn, 6)

    -- == bar status ==
    local rowA = spNew("Frame", {
        Size = UDim2.new(1, -12, 0, 26), Position = UDim2.new(0, 6, 0, 38),
        BackgroundTransparency = 1,
    }, root)

    local lblAuto = spNew("TextButton", {
        Size = UDim2.new(0, 112, 1, 0), Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = SP_CARD, BorderSizePixel = 0, AutoButtonColor = false,
        Font = Enum.Font.GothamBold, TextSize = 10,
        TextColor3 = SP_DIM, Text = "Auto Steal: OFF",
    }, rowA)
    spCorner(lblAuto, 6)
    spStroke(lblAuto)
    StealPanel.lblAuto = lblAuto

    local lblHw = spNew("TextButton", {
        Size = UDim2.new(0, 96, 1, 0), Position = UDim2.new(0, 118, 0, 0),
        BackgroundColor3 = SP_CARD, BorderSizePixel = 0, AutoButtonColor = false,
        Font = Enum.Font.GothamBold, TextSize = 10,
        TextColor3 = SP_DIM, Text = "Halloween: OFF",
    }, rowA)
    spCorner(lblHw, 6)
    spStroke(lblHw)
    StealPanel.lblHw = lblHw

    local lblEggs = spNew("TextLabel", {
        Size = UDim2.new(0, 128, 1, 0), Position = UDim2.new(1, -128, 0, 0),
        BackgroundTransparency = 1, Font = Enum.Font.Gotham,
        TextSize = 10, TextColor3 = SP_DIM,
        TextXAlignment = Enum.TextXAlignment.Right,
        Text = "Eggs: 0",
    }, rowA)
    StealPanel.lblEggs = lblEggs

    -- == bar kontrol ==
    local rowB = spNew("Frame", {
        Size = UDim2.new(1, -12, 0, 24), Position = UDim2.new(0, 6, 0, 68),
        BackgroundTransparency = 1,
    }, root)

    local lblSort = spNew("TextButton", {
        Size = UDim2.new(0, 150, 1, 0), Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = SP_CARD, BorderSizePixel = 0, AutoButtonColor = false,
        Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = SP_TEXT, Text = "Sort: Best Rarity",
    }, rowB)
    spCorner(lblSort, 6)
    spStroke(lblSort)
    StealPanel.lblSort = lblSort

    local lblNight = spNew("TextLabel", {
        Size = UDim2.new(0, 60, 1, 0), Position = UDim2.new(1, -60, 0, 0),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
        TextSize = 11, TextColor3 = SP_DIM,
        TextXAlignment = Enum.TextXAlignment.Right, Text = "Day",
    }, rowB)
    StealPanel.lblNight = lblNight

    -- == baris "selected" ==
    local lblSel = spNew("TextButton", {
        Size = UDim2.new(1, -12, 0, 22), Position = UDim2.new(0, 6, 0, 96),
        BackgroundColor3 = SP_CARD, BorderSizePixel = 0, AutoButtonColor = false,
        Font = Enum.Font.Gotham, TextSize = 10,
        TextColor3 = SP_ACCENT,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Selected: none (klik baris di bawah untuk memilih)",
    }, root)
    spCorner(lblSel, 6)
    StealPanel.lblSel = lblSel

    -- == daftar ==
    local list = spNew("ScrollingFrame", {
        Size = UDim2.new(1, -12, 0, 292), Position = UDim2.new(0, 6, 0, 122),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 4, CanvasSize = UDim2.new(0, 0, 0, 0),
    }, root)
    StealPanel.list = list
    spNew("UIListLayout", { Padding = UDim.new(0, 2) }, list)

    -- == footer ==
    local hint = spNew("TextLabel", {
        Size = UDim2.new(1, -12, 0, 16), Position = UDim2.new(0, 6, 1, -20),
        BackgroundTransparency = 1, Font = Enum.Font.Gotham,
        TextSize = 9, TextColor3 = SP_DIM,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Klik baris: pilih target  |  Steal: curi sekarang  |  geser dari header",
    }, root)

    StealPanel.body = { rowA, rowB, lblSel, list, hint }

    -- == interaksi ==

    local function applyCollapsed(state)
        StealPanel.collapsed = state
        Config.Set("panel/collapsed", state)
        P(function()
            collapseBtn.Text = state and "+" or "-"
            root.Size = state and UDim2.new(0, 360, 0, 38) or UDim2.new(0, 360, 0, 438)
            for _, b in ipairs(StealPanel.body) do b.Visible = not state end
        end)
    end

    P(function()
        collapseBtn.Activated:Connect(function() applyCollapsed(not StealPanel.collapsed) end)
    end)
    P(function()
        closeBtn.Activated:Connect(function() StealPanel.Hide() end)
    end)
    P(function()
        lblAuto.Activated:Connect(function()
            local el = Config.Elements["farm/steal"]
            if el then el:Set(not el:Get()) end
        end)
    end)
    P(function()
        lblHw.Activated:Connect(function()
            local el = Config.Elements["admin/hwsteal"]
            if el then el:Set(not el:Get()) end
        end)
    end)
    P(function()
        lblSort.Activated:Connect(function()
            local modes = StealPanel.SORTS
            local idx = 1
            for i, m in ipairs(modes) do
                if m == StealPanel.sort then idx = i break end
            end
            StealPanel.sort = modes[(idx % #modes) + 1]
            StealPanel.sig = "" -- paksa rebuild dengan urutan baru
        end)
    end)
    P(function()
        lblSel.Activated:Connect(function()
            StealPanel.selected = nil
            Steal.lock = nil
        end)
    end)

    -- == drag (mouse & sentuhan) ==
    local dragging, dragStart, startPos = false, nil, nil

    local function savePos()
        local p = root.Position
        local saved = {
            x = P(function() return p.X.Offset end),
            y = P(function() return p.Y.Offset end),
        }
        Config.Set("panel/pos", saved)
        if Gill then Gill.__THORHUB_PANEL_POS = saved end
    end

    local function clampPos(pos)
        local cam = P(function() return workspace.CurrentCamera end)
        local vp = cam and P(function() return cam.ViewportSize end) or nil
        if not vp then return pos end
        local as = P(function() return root.AbsoluteSize end)
        local sx = as and as.X or 360
        local sy = as and as.Y or 438
        local ox = math.clamp(pos.X.Offset, 4, math.max(vp.X - sx - 4, 4))
        local oy = math.clamp(pos.Y.Offset, 4, math.max(vp.Y - sy - 4, 4))
        return UDim2.new(0, ox, 0, oy)
    end

    local c1 = P(function()
        return header.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = root.Position
            end
        end)
    end)
    if c1 then table.insert(StealPanel.conns, c1) end

    local c2 = P(function()
        return UserInputService.InputChanged:Connect(function(input)
            if not dragging then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                local delta = input.Position - dragStart
                root.Position = clampPos(UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y))
            end
        end)
    end)
    if c2 then table.insert(StealPanel.conns, c2) end

    local c3 = P(function()
        return UserInputService.InputEnded:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch) then
                dragging = false
                savePos()
            end
        end)
    end)
    if c3 then table.insert(StealPanel.conns, c3) end

    if Config.Get("panel/collapsed") == true then
        applyCollapsed(true)
    end

    StealPanel.built = true
    P(StealPanel.Update)
end

function StealPanel.Show()
    if StealPanel.open and StealPanel.root then return end
    if not StealPanel.built or not StealPanel.root then
        StealPanel.Build()
    end
    if StealPanel.root then
        P(function() StealPanel.root.Visible = true end)
        StealPanel.open = true
        Config.Set("panel/open", true)
        if Gill then Gill.__THORHUB_PANEL_OPEN = true end
        P(StealPanel.Update)
    end
end

function StealPanel.Hide()
    if StealPanel.root then
        P(function() StealPanel.root.Visible = false end)
    end
    StealPanel.open = false
    Config.Set("panel/open", false)
    if Gill then Gill.__THORHUB_PANEL_OPEN = false end
end

-- updater panel: sekali per detik, ikut dispatcher (anti memory-leak)
Tasks.Add("stealpanel", 1.0, function()
    if not StealPanel.open then return end
    P(StealPanel.Update)
end)
--════════════ BAGIAN 6 — MENU THORUI (TAB FARM) ════════════
--────────────────────────────[ THORUI LOADER ]────────────────────────────
-- ThorUI adalah GLOBAL: fungsi Notify (bagian awal) membacanya.

ThorUI = nil
-- ==== ThorUi v2.1.0 EMBEDDED — self-contained, tanpa fetch saat runtime ====--
-- Seluruh sumber library dibundel di THORUI_SRC. Fallback online
-- (fetchLua + mirror jsDelivr) tetap ada kalau embedding ternyata gagal.
local THORUI_SRC = [==[
--════════════════════════════════════════════════════════════════════════════
--  ⚡  ThorUi v2.3.1 — Roblox UI Library bertema Dewa Petir (Thor / Petir)
--      Desain, layout & tema 100% original ThorUi ⚡
--  ──────────────────────────────────────────────────────────────────────────
--  Versi     : 2.3.1 (ModuleScript tunggal, tanpa dependensi eksternal)
--  Platform  : PC & Mobile — draggable, resizable, cross-platform
--
--  BARU DI v2.0.0 (tampilan modern)
--  • Splash screen      : logo ⚡ + progress bar + status "memanggil petir"
--  • Sidebar tab        : tab vertikal ber-ikon di sisi kiri (auto icon-only
--                         saat window sempit / mobile)
--  • Search bar         : cari & filter elemen di tab aktif secara real-time
--  • ColorPicker        : kotak SV + slider hue + tampilan HEX/RGB
--  • Confirm dialog     : modal konfirmasi modern (overlay + pop)
--  • Toggle switch      : pill + knob meluncur ala kilat
--
--  BARU & FIX DI v2.1.1 (audit ulang tata letak + keterangan elemen)
--  • Description        : SEMUA elemen (Button/Toggle/Slider/Dropdown/
--                         TextInput/Keybind/ColorPicker/Section) menerima
--                         cfg.Description → teks keterangan kecil di bawah
--                         judul, terbaca jelas di mobile & desktop +
--                         Element:SetDescription(teks) untuk ubah kapan pun
--  • FIX tombol minimize : tombol "—" tidak lagi menimpa search bar
--  • FIX ikon            : ikon tab otomatis DI TENGAH saat sidebar
--                         icon-only; glyph emoji dinudge agar tidak
--                         "melayang" ke atas
--  • FIX drag ikon ⚡    : sumber input (touch/mouse) DIKUNCI saat gesture
--                         → tidak loncat di perangkat hybrid (PC layar
--                         sentuh / tablet + mouse); jari kedua aman
--  • FIX ikon ⚡ klik    : TIDAK LAGI LONCAT saat ditekan — konversi posisi
--                         kini meniru formula engine (bukan AbsolutePosition
--                         yang beda basis koordinat di sebagian executor) +
--                         anchor pusat → animasi pop simetris dari tengah;
--                         snapshot (0,0) dari executor juga diamankan
--  • FIX ColorPicker     : slider HUE kini bisa digeser dengan JARI
--                         (dulu hanya mouse); drag window/resize/slider
--                         juga sudah source-lock & multi-touch aman
--  • FIX slider          : nilai (angka + suffix) tidak terpotong
--  • Confirm dialog      : lebar kartu auto-fit di layar sempit (mobile)
--
--  FIX DI v2.1.2 (dari screenshot user: keterangan slider tertimpa track)
--  • FIX ketimpa teks    : SEMUA teks panjang/wrapped (Description semua
--                         elemen, Label, Paragraph, isi notifikasi, pesan
--                         Confirm) kini diukur tingginya secara SINKRON
--                         (TextService:GetTextSize) → Size eksplisit.
--                         Dulu AutomaticSize.Y di sebagian perangkat (DPI
--                         tinggi / executor) memesan tinggi lebih kecil
--                         dari render asli → track slider / tombol / box
--                         input MENIMPA separuh bawah teks keterangan
--  • Re-ukur otomatis    : tinggi teks dihitung ulang saat teks berubah /
--                         window di-resize / layar dirotasi — selalu pas
--
--  FIX DI v2.1.3 (dari log error user: "'Value' is not a valid member of UDim")
--  • FIX crash fatal     : helper pengukur v2.1.2 mengakses .Value pada
--                         UDim (member itu TIDAK ADA — UDim hanya punya
--                         .Scale & .Offset) → error di fitTextHeight yang
--                         MENGGAGALKAN pembuatan elemen ber-Description
--                         (stack: AddToggle → attachDescription →
--                         autoFitText → fit → fitTextHeight) di SEMUA
--                         perangkat. Kini memakai .Offset yang benar —
--                         elemen dibuat normal & pengukuran anti-ketimpa
--                         v2.1.2 berjalan sebagaimana mestinya.
--
--  FIX DI v2.1.4 (dari screenshot user: "masih ketimpa warna abu-abu")
--  • FIX UIGradient TINT : UIGradient MENGALIKAN warna dengan
--                         BackgroundColor3 (tint — BUKAN menimpa!). Semua
--                         frame ber-gradien yang background-nya BUKAN
--                         putih selama ini render SALAH: sidebar & header
--                         NYARIS HITAM RGB(1,2,4), fill slider BIRU
--                         REDUP→HIJAU (emas tak pernah muncul karena R
--                         background = 0), tombol ⚡ & lingkaran splash
--                         nyaris hitam, garis petir hijau gelap. Kini
--                         SEMUA frame ber-gradien berlatar PUTIH → warna
--                         gradien tampil persis tema (navy, emas, biru).
--  • FIX fill slider      : gradien biru→emas selalu melintas zona abu
--                         kehijauan (interpolasi sRGB) — diganti gradien
--                         selaras-hue biru→biru muda vertikal (efek
--                         "kilat menyala") + stroke KNOB emas. Slider
--                         kini cerah, tanpa jejak abu-abu/kehijauan.
--  • FIX tombol Confirm   : gradien biru→emas (berefek kotor sama)
--                         diganti solid Electric Blue + teks putih.
--
--  FIX DI v2.1.5 (dari screenshot user: nilai slider "124 spd" & pilihan
--                  dropdown "Mjolnir" tampak DI DALAM KOTAK ABU-ABU)
--  • FIX kotak abu-abu   : TextLabel nilai — slider ("124 spd"), dropdown
--                         ("Mjolnir ▾"), keybind, hex ColorPicker — tidak
--                         diberi BackgroundTransparency, sehingga Roblox
--                         merender background DEFAULT abu-abu
--                         RGB(163,162,165) di belakang teksnya. Kini SEMUA
--                         label nilai TRANSPARAN: teks emas/biru tema
--                         langsung di atas kartu navy — tanpa kotak.
--  • Helper Create        : kini mencegah kotak abu serupa di masa depan —
--                         TextLabel tanpa background eksplisit otomatis
--                         transparan (audit: tidak ada TextLabel
--                         ber-background di seluruh kodebase; swatch warna
--                         ColorPicker adalah Frame, bukan TextLabel).
--
--  OPTIMASI DI v2.2.0 (permintaan user: "masih terasa berat banyak
--                      rendutan — bikin seringan mungkin")
--  • Cache pengukuran    : pengukur tinggi teks (GetTextSize) kini ber-
--                         cache — teks & lebar tidak berubah = NOL ukur
--                         ulang; Size hanya ditulis bila tinggi benar2
--                         berubah (memutus reaksi berantai layout↔signal)
--  • Refit terjadwal     : semua re-ukur digabung maksimal SATU pass per
--                         frame utk SELURUH label (dulu: per label per
--                         frame saat resize/rotasi → sumber rendutan)
--  • Registry otomatis    : tween yang SELESAI otomatis keluar dari daftar
--                         — dulu tiap hover/tap menumpuk tween mati sampai
--                         window dihancurkan (ribuan entri di sesi panjang
--                         → memori bengkak + Destroy/Remove makin lambat)
--  • Hover hemat mobile  : efek hover card hanya dipasang di perangkat
--                         bermouse — sentuhan mobile tak lagi membuat 2-4
--                         tween percuma per ketukan (feedback tetap ada:
--                         kilat Zap, animasi switch, splash tombol)
--  • Search debounce     : filter elemen digabung 0.1s sekali saat mengetik
--                         (dulu re-layout penuh tiap huruf)
--  • Rebranding          : semua referensi library luar dihapus — desain,
--                         layout & tema kini 100% original ThorUi
--
--  BARU DI v2.2.1 (permintaan user: "di dalam menu ada fitur — tolong
--                  tambahkan minimize menu biar lebih rapi")
--  • Menu minimizable    : judul section kini bisa DIKLIK untuk menutup /
--                         membuka SEMUA fitur di dalamnya (sampai section
--                         berikutnya) — panah lipat emas berputar sebagai
--                         penanda; judul section lain tetap terlihat
--  • AddSection(cfg)     : Collapsed = true → menu dibuat langsung terlipat
--  • API programatik     : Section:SetCollapsed(bool) · :Toggle() ·
--                         :IsCollapsed() · SetDescription(teks)
--  • Search-aware        : pencarian TIDAK membuka lipatan menu — anggota
--                         menu yang di-minimize tetap tersembunyi, dan
--                         judul menu tanpa hasil cocok ikut disembunyikan
--  • Hemat performa      : lipatan diterapkan TANPA tween per elemen (satu
--                         pass visibility) — setia pada optimasi v2.2.0
--
--  BARU DI v2.2.2 (permintaan user: "AddSection jangan kotak — ganti anak
--                  panah; drag UI jangan ada batas; semua section tutup saat
--                  pertama execute; UI jangan terlalu gede")
--  • Panah DIGAMBAR     : chevron section & panah dropdown kini DIGAMBAR
--                         dari 2 batang miring (geometri murni, tanpa
--                         font). Glyph unicode "▾" ternyata dirender Roblox
--                         sebagai KOTAK kosong (tofu) di sebagian perangkat
--                         — itulah "kotak" di judul section. Panah kini
--                         DIJAMIN tampil sebagai panah di semua perangkat.
--  • Section terlipat    : SEMUA section MULAI TERLIPAT saat pertama
--                         execute — daftar fitur langsung rapi; klik judul
--                         untuk membuka. Collapsed = false di AddSection
--                         untuk mulai terbuka (default kini TERLIPAT).
--  • Drag TANPA BATAS    : window bisa digeser bebas keluar layar ke kiri /
--                         kanan / atas / bawah — NOL clamp. Tidak akan
--                         hilang: saat dimunculkan lagi (tombol ⚡ /
--                         keybind) otomatis ditarik balik ke dalam layar.
--  • Default ringkas     : ukuran default window kini 540 x 350 (dulu
--                         620 x 430) — tampil langsung proporsional,
--                         tetap bisa di-resize / minimize sesuka hati.
--
--  BARU DI v2.3.0 (rilis fitur besar — semua tetap tema Thor, nol aset)
--  • STATE + BINDING      : ThorUi:CreateState — satu nilai bersama untuk
--                          banyak elemen; ubah salah satu, semuanya ikut
--                          (2 arah). st:Bind(el, {ToState, ToOption}),
--                          st:BindMany, st:Subscribe, st:Unbind
--  • DEPENDS              : baris muncul/sembunyi OTOMATIS mengikuti nilai
--                          sumber: AddSlider({..., Depends = {Element =
--                          toggleX, Value = true}}) · runtime
--                          Element:SetDependency / ClearDependency
--  • SUB-ROW (AddChild)   : elemen bertingkat! toggle:AddChild("Slider",
--                          {...}) — anak tampil di dalam kartu induk
--                          (terinden, garis pemandu petir, chevron lipat)
--  • SLIDER UNITS         : multi-satuan + konversi otomatis (m ↔ km),
--                          chip pemilih satuan, awalan/satuan berwarna
--                          (RichText), KLIK ANGKA untuk ketik nilai eksak,
--                          setter runtime :SetRange/:SetDecimals/
--                          :SetIncrement/:SetSuffix/:SetUnit
--  • BUTTON ConfirmText   : klik dua tahap untuk aksi berisiko (batal
--                          otomatis 2.5 dtk) + :ResetConfirm
--  • DROPDOWN ++          : Search (filter opsi), ApplyButton (mode aksi:
--                          pilih lalu Apply → callback(nilai, indeks)),
--                          :SetValues/:AddValue/:RemoveValue/:Filter
--  • LIST (baru)          : browser item — Search, Groups, Multi, badge
--                          TopRight, gambar opsional milik user, OnItemClick
--  • MODELVIEW (baru)     : etalase 3D ViewportFrame + kamera auto-frame
--                          + Spin; tanpa model diberikan → palu petir
--                          geometris BAWAAN (murni Part, tetap nol aset)
--  • CANVAS (baru)        : dashboard mini deklaratif — Text/Bar/Button/
--                          Divider + :Set(nama, props)/:Get(nama)/:Fire
--  • GROUP (radio)        : ThorUi:CreateGroup({KeepNone}) + AddToggle({...
--                          , Group = g}) — maksimal satu aktif
--  • QUICK ACTION         : ThorUi:AddQuickAction({Icon, Name, Callback})
--                          — deret tombol melayang yang bisa digeser
--  • SetTheme(patch)      : pengganti edit ThorUi.Theme manual (tetap
--                          dipanggil SEBELUM CreateWindow)
--
--  BARU DI v2.2.3 (permintaan user: "ukuran default bikin rada persegi, jangan
--                  terlalu wide; drag bebas belum work — window langsung
--                  terpotong padahal belum sampai pinggir layar")
--  • Rada persegu        : ukuran default window kini benar2 RADA PERSEGU
--                          (rasio akhir 1:1 s.d. 1.15:1), dihitung murni
--                          dari DIMENSI layar aktual: lebar = terkecil dari
--                          440px / 86% lebar layar / 62% tinggi layar;
--                          tinggi = terkecil dari 390px / 62% tinggi layar
--                          / 1.15x lebar (lihat CreateWindow)
--  • Fix "terpotong"     : AKARNYA BUKAN clamp drag (drag window memang
--                          sudah NOL clamp) — default lama dipilih lewat
--                          deteksi MouseEnabled: sebagian Android/emulator/
--                          executor melaporkan MouseEnabled = true walau
--                          perangkat TANPA mouse → salah mengambil default
--                          PC 540px yang LEBIH LEBAR dari layar HP →
--                          window tampak terpotong di kedua sisi SEJAK
--                          MUNCUL ("belum sampai pinggir layar" pun sudah
--                          kepotong). Kini default murni dari dimensi
--                          viewport → DIJAMIN muat + selalu menyisakan
--                          margin terlihat di semua sisi, jadi drag tidak
--                          langsung menabrak tepi layar
--  • Margin anti-nempel  : auto-clamp MinSize utk layar kecil diperlebar
--                          (margin 20 → 56px) — window kecil pun tetap
--                          berjarak nyaman dari tepi layar
--  • Sidebar tetap label : ambang icon-only diturunkan 520 → 430 px —
--                          default 440px tetap menampilkan NAMA tab;
--                          hanya layar benar2 sempit (hp) yang icon-only
--
--  BARU DI v2.3.1 (permintaan user: "ganti logonya ambil dari repo ThorHub")
--  • LOGO THORHUB       : logo ⚡ resmi diganti PALU MJOLNIR — identitas
--                          ThorHub (kepala emas ber-gradien + 2 paku keling
--                          + gagang biru ber-gradien + kilau). Digambar MURNI
--                          dari Frame (pola ChevronIcon): tanpa font & tanpa
--                          Asset ID → DIJAMIN tampil identik di semua
--                          perangkat (glyph ⚡ lama bergantung pada font
--                          perangkat & sering "melayang" dari garis dasar).
--                          Terpasang di 3 titik brand: lingkaran SPLASH,
--                          baris LOGO SIDEBAR (auto ke tengah saat sidebar
--                          icon-only), dan TOMBOL MELAYANG toggle window
--  • LOGO BISA DIGANTI  : pengguna library bisa memasang logo sendiri —
--                          ThorUi:SetLogo({ Image = "rbxassetid://...",
--                          Size = 26 }) SEBELUM CreateWindow, atau per-window
--                          via CreateWindow({ Logo = { Image, Size } }).
--                          Tanpa itu → palu ThorHub bawaan (tetap nol aset)
--  • Brand "ThorHub"    : judul default splash & sidebar kini "ThorHub"
--                          (tetap bisa dioverride lewat Title)
--  • Mjolnir 3D senada  : palu bawaan AddModelView dicat ulang persis
--                          logo — kepala emas + gagang biru
--
--  FITUR LANJUTAN
--  • Tema Lightning & Thunder : Midnight Blue + Electric Blue / Lightning Gold
--  • Animasi snappy ala kilat : TweenService (Back / Quart / Quad, cepat)
--  • Glow sederhana           : UIGradient + layer transparan + stroke neon
--  • Window draggable         : Mouse & Touch via UserInputService — BEBAS
--                               tanpa batas layar (v2.2.2; pulih otomatis di Show())
--  • Window resizable         : drag-handle di sudut kanan-bawah window
--  • UISizeConstraint         : ukuran minimal (default 400 x 250)
--  • Floating toggle (logo)   : tombol palu ThorHub — bisa digeser BEBAS ke
--                               mana pun (di-clamp ke layar)
--  • Keybind toggle UI        : default RightControl (bisa diganti)
--  • Konten ScrollingFrame    : AutomaticCanvasSize (elemen tak terbatas)
--  • 100% murni script        : Instance.new / UICorner / UIStroke — tanpa
--                               Asset ID gambar sama sekali (anti banned asset)
--  • Anti memory-leak         : semua connection & tween masuk garbage table
--                               (Registry), otomatis di-Clean saat Destroy
--
--  RINGKASAN API
--  ──────────────────────────────────────────────────────────────────────────
--  ThorUi:CreateWindow({Title, Logo, Size, MinSize, Position, Keybind,
--                       ShowToggle, Splash})
--  ThorUi:Notify({Title, Content, Duration, Icon})
--  ThorUi:SetKeybind(Enum.KeyCode.X)    ThorUi:Toggle()    ThorUi:Destroy()
--  ThorUi:SetToggleVisible(bool)
--  ThorUi:SetTheme({Accent = Color3...})        (v2.3.0, sebelum CreateWindow)
--  ThorUi:SetLogo({Image, Size})                (v2.3.1, logo custom, sebelum CreateWindow)
--  ThorUi:CreateState({Name, Default, Callback, Normalize})    (v2.3.0)
--     st:Get()  st:Set(v)  st:Subscribe(fn)  st:Bind(el,{ToState,ToOption})
--     st:BindMany({...})  st:Unbind(el)
--  ThorUi:CreateGroup({KeepNone})               (v2.3.0 — radio toggles)
--  ThorUi:AddQuickAction({Icon, Name, Callback}) (v2.3.0 — tombol melayang)
--
--  Window:CreateTab({Name, Icon})        Window:Show()/Hide()/Toggle()
--  Window:SetCollapsed(bool)             Window:Destroy()
--  Window:SetKeybind(Enum.KeyCode.X)     Window:SetTitle(text)
--  Window:Confirm({Title, Content, ConfirmText, CancelText, OnConfirm, OnCancel})
--
--  Tab:AddButton({Name, ConfirmText, Callback})        (v2.3.0: klik 2 tahap)
--  Tab:AddToggle({Name, Default, Callback, Group})     :Set(bool) / :Get()
--  Tab:AddSlider({Name, Min, Max, Default, Increment, Precision, Suffix,
--                 Prefix, Units, Callback})             :Set(n) / :Get()
--     Units = { Options = {{Name, Suffix, Prefix, FromBase, ToBase, Format,
--               Decimals}}, Default = "m", Callback = fn }
--     v2.3.0: klik ANGKA utk ketik eksak · :SetRange :SetDecimals
--             :SetIncrement :SetSuffix :SetUnit
--  Tab:AddDropdown({Name, Values, Default, Multi, Search, ApplyButton,
--                   Callback})                         :Set(v) / :Get()
--     v2.3.0: :SetValues :AddValue :RemoveValue :Filter
--  Tab:AddTextInput({Name, Text, Placeholder, ClearOnFocus, Callback(text, enter)})
--  Tab:AddKeybind({Name, Default, Callback})             :SetKey(enum) / :Get()
--  Tab:AddColorPicker({Name, Default, Callback})          :Set(Color3) / :Get()
--  Tab:AddList({Name, Items|Groups, Multi, Search, Selected, MaxHeight,
--               OnItemClick})                    (v2.3.0 — browser item)
--     :Get()  :Set(sel)  :SetItems(items, groups)  :Clear()  :Filter(q)
--  Tab:AddModelView({Name, Model, Height, Spin})  (v2.3.0 — etalase 3D)
--     :SetModel(inst)  :SetSpin(bool)  :Get()
--  Tab:AddCanvas({Name, Widgets})                 (v2.3.0 — dashboard mini)
--     Widgets: {Type="Text"|"Bar"|"Button"|"Divider", Name, Text, Value,
--               Color, Callback}
--     :Set(nama, props)  :Get(nama)  :AddWidget(spec)  :Fire(nama)
--  Tab:AddSection({Name, Description, Collapsed})   → Section (menu)
--     Collapsed default = true (v2.2.2) · false = mulai terbuka
--     Section:SetCollapsed(bool)  Section:Toggle()  Section:IsCollapsed()
--  Tab:AddLabel({Text})   Tab:AddParagraph({Title, Text})
--  Element:Set(...)         Element:Get()          Element:Remove()
--  Element:SetDescription(teks)   → ubah keterangan elemen kapan pun
--  v2.3.0 (semua elemen inti):
--  Element:AddChild(kind, cfg)  → anak bertingkat ("Toggle"/"Slider"/
--     "Dropdown"/"Button"/"TextInput"/"Keybind"/"ColorPicker"/"Label"/
--     "Paragraph"/"List"/"ModelView"/"Canvas")
--  Element:SetExpanded(bool)  Element:ToggleExpanded()  Element:IsExpanded()
--  Element:SetDependency({Element|State, Value|Predicate})
--  Element:ClearDependency()
--
--  Catatan: SEMUA elemen menerima Description = "keterangan kecil" yang
--  ditampilkan di bawah judul elemen. Ubah warna lewat ThorUi:SetTheme({...})
--  atau ThorUi.Theme SEBELUM CreateWindow untuk custom tema. Contoh
--  implementasi lengkap ada di BLOK PALING BAWAH file ini.
--════════════════════════════════════════════════════════════════════════════

--// ───────────────────────────── Services ──────────────────────────────────
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")
local TextService      = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer

--// ─────────────────────────────── Library ──────────────────────────────────
local ThorUi = {
    Version = "2.3.1",
}

--// ──────────────────────────────── Tema ────────────────────────────────────
--  Midnight Blue pekat sebagai dasar; Electric Blue & Lightning Gold sebagai
--  aksen tombol aktif, toggle, slider, dan UIStroke.
local Theme = {
    Background    = Color3.fromRGB(11, 14, 23),   -- midnight blue pekat
    BackgroundAlt = Color3.fromRGB(16, 20, 32),
    Card          = Color3.fromRGB(21, 26, 41),   -- background elemen
    CardHover     = Color3.fromRGB(28, 36, 56),
    Track         = Color3.fromRGB(36, 44, 66),   -- slider / toggle OFF
    Accent        = Color3.fromRGB(0, 195, 255),  -- electric blue (cyan neon)
    AccentGold    = Color3.fromRGB(255, 190, 0),  -- petir emas (lightning gold)
    Text          = Color3.fromRGB(240, 244, 255),
    TextDim       = Color3.fromRGB(145, 155, 180),
    White         = Color3.fromRGB(255, 255, 255),
    Stroke        = Color3.fromRGB(0, 150, 200),  -- garis tepi aktif
    StrokeDim     = Color3.fromRGB(45, 58, 88),   -- garis tepi pasif
    Danger        = Color3.fromRGB(255, 84, 84),
    FontMain      = Enum.Font.Gotham,
    FontMedium    = Enum.Font.GothamMedium,
    FontBold      = Enum.Font.GothamBold,
}
ThorUi.Theme = Theme

--// ─────────────────────── Easing "kilat petir" (snappy) ────────────────────
local TI_HOVER  = TweenInfo.new(0.12, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local TI_SNAP   = TweenInfo.new(0.18, Enum.EasingStyle.Quart,  Enum.EasingDirection.Out)
local TI_STRIKE = TweenInfo.new(0.28, Enum.EasingStyle.Back,   Enum.EasingDirection.Out)
local TI_EXIT   = TweenInfo.new(0.16, Enum.EasingStyle.Quart,  Enum.EasingDirection.In)

--// ──────────────── Registry: garbage table anti memory-leak ────────────────
--  Semua RBXScriptConnection & Tween disimpan ke dalam satu table sampah,
--  lalu diputus (:Disconnect() / :Cancel()) otomatis oleh Registry:Clean()
--  saat window / elemen / UI dihancurkan.
local Registry = {}
Registry.__index = Registry

function Registry.new()
    return setmetatable({ _conns = {}, _tweens = {} }, Registry)
end

function Registry:Connect(signal, handler)
    local conn = signal:Connect(handler)
    table.insert(self._conns, conn)
    return conn
end

--  v2.3.0: putus SATU koneksi lebih awal (koneksi tetap aman bila lupa
--  dipanggil — Clean() tetap memutus semuanya saat elemen dihancurkan).
--  CATATAN: pencarian manual (bukan removeFrom) karena util tersebut
--  dideklarasikan lebih bawah di file ini.
function Registry:Disconnect(conn)
    if typeof(conn) == "RBXScriptConnection" then
        pcall(function()
            conn:Disconnect()
        end)
        for i, c in ipairs(self._conns) do
            if c == conn then
                table.remove(self._conns, i)
                break
            end
        end
    end
end

--  OPTIMASI v2.2.0: tween yang SUDAH SELESAI otomatis keluar dari daftar.
--  Dulu setiap Tween() (hover, zap, animasi) menempel di _tweens SAMPAI
--  registry di-Clean — di sesi panjang menumpuk RIBUAN tween mati (memori
--  bengkak + Clean/Destroy makin lambat). Completed juga terpicu oleh
--  :Cancel(), jadi entri ikut bersih saat Clean.
function Registry:Track(tween)
    local list = self._tweens
    list[#list + 1] = tween
    local function release()
        local t = self._tweens
        local n = #t
        for i = 1, n do
            if t[i] == tween then
                t[i] = t[n]
                t[n] = nil
                break
            end
        end
    end
    tween.Completed:Connect(release)
    return tween
end

function Registry:Clean()
    -- OPTIMASI v2.2.0: kosongkan daftar DULU, baru proses snapshot —
    -- menghindari mutasi-tengah-iterasi saat :Cancel() memicu Completed
    -- (yang kini melepas tween dari daftar).
    local conns = self._conns
    local tweens = self._tweens
    self._conns = {}
    self._tweens = {}
    for _, conn in ipairs(conns) do
        if conn.Connected then
            pcall(function()
                conn:Disconnect()
            end)
        end
    end
    for _, tween in ipairs(tweens) do
        pcall(function()
            tween:Cancel()
        end)
    end
end

--// ───────────────────────── Helper inti (murni script) ─────────────────────
--  Instance builder: properti dipasang dulu, Parent paling akhir.
local function Create(className, props)
    local inst = Instance.new(className)
    if props then
        -- FIX v2.1.5: TextLabel tanpa BackgroundTransparency & tanpa
        -- BackgroundColor3 eksplisit merender KOTAK ABU-ABU default Roblox
        -- (RGB 163,162,165) di belakang teksnya — inilah "kotak abu abu"
        -- yang menimpa nilai slider "124 spd" & pilihan dropdown "Mjolnir".
        -- Default-kan transparan (audit: TIDAK ada TextLabel ber-background
        -- di kodebase; swatch warna ColorPicker adalah Frame, bukan TextLabel).
        if className == "TextLabel"
            and props.BackgroundTransparency == nil
            and props.BackgroundColor3 == nil then
            inst.BackgroundTransparency = 1
        end
        for key, value in pairs(props) do
            if key ~= "Parent" and value ~= nil then
                inst[key] = value
            end
        end
        if props.Parent ~= nil then
            inst.Parent = props.Parent
        end
    end
    return inst
end

local function Corner(parent, radius)
    if typeof(radius) == "UDim" then
        return Create("UICorner", { CornerRadius = radius, Parent = parent })
    end
    return Create("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

local function Stroke(parent, props)
    props = props or {}
    return Create("UIStroke", {
        Color = props.Color or Theme.StrokeDim,
        Thickness = props.Thickness or 1,
        Transparency = props.Transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function Gradient(parent, colorA, colorB, rotation, transparency)
    local props = {
        Color = ColorSequence.new(colorA, colorB),
        Rotation = rotation or 0,
        Parent = parent,
    }
    if transparency then
        props.Transparency = transparency
    end
    return Create("UIGradient", props)
end

--  v2.2.2: Panah chevron DIGAMBAR, bukan glyph teks. Glyph unicode "▾"
--  (U+25BE) tidak tersedia di font Roblox (Gotham) sehingga dirender
--  sebagai KOTAK kosong (tofu) di sebagian perangkat — itulah "kotak"
--  yang user lihat di judul section. Dua batang miring murni geometri
--  (tanpa font / tanpa Asset ID) = panah yang DIJAMIN tampil di semua
--  perangkat. Rotasi container: 0 = panah bawah (terbuka) ·
--  -90 = panah kanan (terlipat). Warna via BackgroundColor3 kedua batang.
local function ChevronIcon(parent, props)
    props = props or {}
    local px = props.Size or 12
    local center = px * 0.5
    local arm = math.max(6, px * 0.66) -- panjang batang
    local half = arm * 0.3536         -- 1/2 proyeksi diagonal batang
    local color = props.Color or Theme.AccentGold
    local box = Create("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = props.AnchorPoint,
        Position = props.Position,
        Size = UDim2.new(0, px, 0, px),
        Rotation = props.Rotation or 0,
        Parent = parent,
    })
    local function armFrame(offsetX, rot)
        return Create("Frame", {
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, math.floor(center + offsetX + 0.5), 0.5, 0),
            Size = UDim2.new(0, math.floor(arm + 0.5), 0, 2),
            Rotation = rot,
            Parent = box,
        })
    end
    local b1 = armFrame(-half, 45)  -- batang kiri ↘ (ujung bertemu di puncak)
    local b2 = armFrame(half, -45)  -- batang kanan ↗
    return box, b1, b2
end

--  LOGO THORHUB (v2.3.1): palu Mjolnir — identitas resmi ThorHub — DIGAMBAR
--  murni dari Frame (kepala emas ber-gradien 3 titik + 2 paku keling +
--  gagang biru ber-gradien + kilau), menelusuri jejak ChevronIcon: tanpa
--  font & tanpa Asset ID → DIJAMIN tampil identik di semua perangkat.
--  Spesifikasi logo 48x48: kepala (7,4) 34x17 · gagang (20.5,21) 7x23.
--  CATATAN v2.1.4: frame ber-gradien wajib berlatar PUTIH agar tint murni.
local function ThorHubLogo(parent, props)
    props = props or {}
    local S = props.Size or 24
    local function px(v)
        return math.max(1, math.floor(v / 48 * S + 0.5))
    end
    local root = Create("Frame", {
        Name = "ThorHubLogo",
        BackgroundTransparency = 1,
        AnchorPoint = props.AnchorPoint,
        Position = props.Position,
        Size = UDim2.fromOffset(S, S),
        Parent = parent,
    })
    -- kepala palu: emas (3 titik gradien terang→tengah→gelap, diagonal)
    local head = Create("Frame", {
        Position = UDim2.fromOffset(px(7), px(4)),
        Size = UDim2.fromOffset(px(34), px(17)),
        BackgroundColor3 = Theme.White,
        BorderSizePixel = 0,
        Parent = root,
    })
    Corner(head, UDim.new(0, px(4.5)))
    Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(253, 230, 138)),
            ColorSequenceKeypoint.new(0.55, Color3.fromRGB(251, 191, 36)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 83, 9)),
        }),
        Rotation = 45,
        Parent = head,
    })
    -- kilau permukaan atas kepala
    local shine = Create("Frame", {
        Position = UDim2.fromOffset(px(7) + 1, px(5)),
        Size = UDim2.fromOffset(px(34) - 2, px(6)),
        BackgroundColor3 = Theme.White,
        BackgroundTransparency = 0.75,
        BorderSizePixel = 0,
        Parent = root,
    })
    Corner(shine, UDim.new(0, px(3)))
    -- paku keling kiri & kanan
    local function rivet(x)
        local r = Create("Frame", {
            Position = UDim2.fromOffset(px(x), px(9)),
            Size = UDim2.fromOffset(px(4), px(7)),
            BackgroundColor3 = Color3.fromRGB(120, 53, 15),
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            Parent = root,
        })
        Corner(r, UDim.new(0, px(1.6)))
    end
    rivet(13)
    rivet(31)
    -- gagang: biru (terang→gelap, vertikal)
    local handle = Create("Frame", {
        Position = UDim2.fromOffset(px(20.5), px(21)),
        Size = UDim2.fromOffset(px(7), px(23)),
        BackgroundColor3 = Theme.White,
        BorderSizePixel = 0,
        Parent = root,
    })
    Corner(handle, UDim.new(0, px(3)))
    Gradient(handle, Color3.fromRGB(147, 197, 253), Color3.fromRGB(37, 99, 235), 90)
    -- kilau gagang
    local hShine = Create("Frame", {
        Position = UDim2.fromOffset(px(22.7), px(21)),
        Size = UDim2.fromOffset(px(2.6), px(23)),
        BackgroundColor3 = Theme.White,
        BackgroundTransparency = 0.72,
        BorderSizePixel = 0,
        Parent = root,
    })
    Corner(hShine, UDim.new(0, px(1.3)))
    return root
end

--  Render logo ke parent (v2.3.1). logoCfg = { Image = "rbxassetid://...",
--  Size = n } dari ThorUi:SetLogo / CreateWindow({ Logo = ... }):
--    • Image ada    → ImageLabel milik user sendiri (boleh Asset ID mereka)
--    • tanpa Image  → palu ThorHub geometris bawaan (default, nol aset)
--  props.Size = ukuran default per- lokasi (ditimpa logoCfg.Size bila ada).
local function MakeLogo(parent, props, logoCfg)
    props = props or {}
    logoCfg = (type(logoCfg) == "table") and logoCfg or {}
    local size = tonumber(logoCfg.Size) or props.Size or 24
    local img = logoCfg.Image
    if type(img) == "string" and img ~= "" then
        return Create("ImageLabel", {
            Name = "ThorHubLogo",
            BackgroundTransparency = 1,
            AnchorPoint = props.AnchorPoint,
            Position = props.Position,
            Size = UDim2.fromOffset(size, size),
            Image = img,
            ScaleType = Enum.ScaleType.Fit,
            Parent = parent,
        })
    end
    return ThorHubLogo(parent, {
        Size = size,
        AnchorPoint = props.AnchorPoint,
        Position = props.Position,
    })
end

--  Buat & mainkan tween langsung; otomatis masuk garbage table.
local function Tween(registry, object, info, goal)
    local tween = TweenService:Create(object, info, goal)
    if registry then
        registry:Track(tween)
    end
    tween:Play()
    return tween
end

--  Kilatan petir: overlay cepat memudar saat elemen diklik.
local function Zap(registry, parent, color, radius)
    local flash = Create("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = color or Theme.AccentGold,
        BackgroundTransparency = 0.62,
        BorderSizePixel = 0,
        ZIndex = 6,
        Parent = parent,
    })
    Corner(flash, radius or 8)
    local tween = TweenService:Create(
        flash,
        TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = 1 }
    )
    if registry then
        registry:Track(tween)
    end
    tween:Play()
    local function onZapDone()
        flash:Destroy()
    end
    if registry then
        registry:Connect(tween.Completed, onZapDone)
    else
        tween.Completed:Connect(onZapDone)
    end
end

--  Efek hover standar untuk card interaktif (stroke neon menyala).
--  OPTIMASI v2.2.0: hover hanya dipasang di perangkat BERMOUSE. Di layar
--  sentuh, tiap tap ikut memicu MouseEnter/Leave → 2-4 tween percuma per
--  ketukan. Umpan balik sentuh tetap ada: kilat Zap & animasi switch/knob.
local HOVER_FOR_MOUSE = UserInputService.MouseEnabled

local function cardHover(registry, card, stroke)
    if not HOVER_FOR_MOUSE then
        return
    end
    registry:Connect(card.MouseEnter, function()
        Tween(registry, card, TI_HOVER, { BackgroundColor3 = Theme.CardHover })
        Tween(registry, stroke, TI_HOVER, { Color = Theme.Stroke, Transparency = 0.05 })
    end)
    registry:Connect(card.MouseLeave, function()
        Tween(registry, card, TI_HOVER, { BackgroundColor3 = Theme.Card })
        Tween(registry, stroke, TI_HOVER, { Color = Theme.StrokeDim, Transparency = 0.35 })
    end)
end

--// ──────────────────────── Util platform & angka ───────────────────────────
--  v2.2.3: fungsi IsMobile() DIHAPUS — ukuran default window kini dihitung
--  murni dari DIMENSI viewport (lihat CreateWindow). TouchEnabled /
--  MouseEnabled terbukti tidak andal di sebagian Android/emulator/executor
--  (sering melaporkan MouseEnabled = true di perangkat tanpa mouse →
--  default PC 540px pernah terpasang di layar HP yang lebih sempit →
--  window tampak langsung terpotong di kedua sisi).

local function GetViewport()
    local camera = workspace.CurrentCamera
    if camera then
        return camera.ViewportSize
    end
    return Vector2.new(1280, 720)
end

--  Filter gerakan untuk gesture yang sedang berjalan (drag/geser).
--  FIX v2.1.1 "loncat-loncat" di perangkat HYBRID (mouse + layar sentuh):
--  begitu gesture dimulai dari SENTUHAN, hanya InputObject sentuhan YANG
--  SAMA yang boleh menggerakkan UI; begitu dari MOUSE, hanya MouseMovement.
--  Tanpa ini, posisi mouse yang menetap di tempat lain ikut terbaca →
--  ikon / jendela / slider meloncat ke posisi aneh.
local function gestureInput(startInput, input)
    if not startInput then
        return false
    end
    if startInput.UserInputType == Enum.UserInputType.Touch then
        return input == startInput
    end
    return input.UserInputType == Enum.UserInputType.MouseMovement
end

--  Filter akhir gesture: hanya input yang MEMULAI gesture (atau lepasnya
--  klik kiri mouse) yang boleh mengakhirinya — jari kedua / tombol lain
--  tidak mengganggu drag yang sedang berjalan.
local function gestureEnded(startInput, input)
    if startInput and startInput.UserInputType == Enum.UserInputType.Touch then
        return input == startInput
    end
    return input.UserInputType == Enum.UserInputType.MouseButton1
end

--// ── FIX v2.1.2: pengukuran tinggi teks SINKRON (anti ketimpa teks) ─────
--  Pola "TextLabel TextWrapped + AutomaticSize.Y" TIDAK AKURAT di sebagian
--  perangkat (layar DPI tinggi / executor / AutomaticSize bersarang dalam
--  kartu yang juga automatic): tinggi yang dipesan untuk UIListLayout LEBIH
--  KECIL dari tinggi render teks → baris setelahnya (track slider, box
--  input, tombol, garis section) MENIMPA separuh bawah teks keterangan.
--  (Gejala dari screenshot user: keterangan slider "...karakter (16 - 200)"
--  terpotong track slider.) Solusi: ukur tinggi teks secara EKSPLISIT via
--  TextService:GetTextSize — sinkron, memakai lebar render sesungguhnya —
--  lalu set Size eksplisit. UIListLayout selalu memesan ruang yang PAS.
--// ── OPTIMASI v2.2.0: cache + refit terjadwal (anti rendutan) ───────────
--  GetTextSize itu MAHAL bila dipanggil per-frame. Pola v2.1.2 menghubung-
--  kan tiap label ke sinyal AbsoluteSize parent → saat window di-resize /
--  layar dirotasi, pengukuran menyeruak PER FRAME untuk SEMUA label, lalu
--  tulisan Size memicu re-layout berantai (card AutomaticSize.Y → holder
--  → ScrollingFrame AutomaticCanvasSize) — inilah sumber "rendutan".
--  Solusi dua lapis:
--    (1) CACHE   : teks & lebar tak berubah → NOL ukur ulang; Size hanya
--                 ditulis bila tinggi benar-benar berubah (memutus reaksi
--                 berantai layout ↔ signal).
--    (2) BATCHED: semua permintaan re-ukur digabung maksimal SATU pass
--                 per frame (task.defer) untuk seluruh label.
--  Tabel ber-key LEMAH (weak) → label yang di-:Destroy() otomatis ke-GC.
local FitCache = setmetatable({}, { __mode = "k" })
local FitQueue = setmetatable({}, { __mode = "k" })
local fitIdle = true

local function fitTextHeight(label, minH)
    local parent = label.Parent
    if not parent then
        return
    end
    local pad = 0
    for _, ch in ipairs(parent:GetChildren()) do
        if ch:IsA("UIPadding") then
            pad = ch.PaddingLeft.Offset + ch.PaddingRight.Offset
            break
        end
    end
    -- lebar render label (semua teks fit ini lebar penuh: Scale X = 1 dari
    -- area konten parent = lebar parent - padding kiri/kanan)
    local w = math.max(parent.AbsoluteSize.X - pad, 60)
    -- OPTIMASI v2.2.0: teks & lebar tidak berubah → skip GetTextSize
    local c = FitCache[label]
    if c and c.Text == label.Text and c.W == w and c.H == label.Size.Y.Offset then
        return
    end
    local bounds = TextService:GetTextSize(label.Text or "", label.TextSize, label.Font, Vector2.new(w, 10000))
    local h = math.max(minH or 14, math.ceil(bounds.Y) + 3)
    FitCache[label] = { Text = label.Text, W = w, H = h }
    if label.Size.Y.Offset ~= h then
        label.Size = UDim2.new(1, 0, 0, h)
    end
end

local function scheduleFit(label, minH)
    FitQueue[label] = minH
    if fitIdle then
        fitIdle = false
        task.defer(function()
            fitIdle = true
            local queue = FitQueue
            FitQueue = setmetatable({}, { __mode = "k" })
            for l, mh in pairs(queue) do
                if l.Parent then
                    pcall(fitTextHeight, l, mh)
                end
            end
        end)
    end
end

--  Pasang pengukuran otomatis: hitung ulang saat teks berubah / lebar
--  parent berubah (resize window, rotasi layar, pass layout pertama).
--  Koneksi signal mati sendiri saat label / parent di-:Destroy() → aman memori.
local function autoFitText(label, minH)
    label:GetPropertyChangedSignal("Text"):Connect(function()
        scheduleFit(label, minH)
    end)
    if label.Parent then
        label.Parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            scheduleFit(label, minH)
        end)
    end
    fitTextHeight(label, minH)
    scheduleFit(label, minH) -- re-cek sekali setelah pass layout pertama
end

local function decimalsOf(n)
    local s = tostring(n)
    local dot = string.find(s, ".", 1, true)
    return dot and (#s - dot) or 0
end

local function formatValue(value, precision)
    precision = precision or 0
    if precision <= 0 then
        return tostring(math.floor(value + 0.5))
    end
    return string.format("%." .. precision .. "f", value)
end

local function contains(list, value)
    for _, v in ipairs(list) do
        if v == value then
            return true
        end
    end
    return false
end

local function removeFrom(list, value)
    for i, v in ipairs(list) do
        if v == value then
            table.remove(list, i)
            return true
        end
    end
    return false
end

local function hexFromColor3(c)
    return string.format(
        "#%02X%02X%02X",
        math.floor(c.R * 255 + 0.5),
        math.floor(c.G * 255 + 0.5),
        math.floor(c.B * 255 + 0.5)
    )
end

--// ───────────── v2.3.0: RichText (angka berwarna pada nilai slider) ────────
--  Escape teks agar aman di dalam RichText, lalu bungkus dengan tag warna.
--  Dipakai slider: ANGKA tetap emas, awalan/satuan tampil redup kebiruan.
local function escapeRT(text)
    local s = tostring(text)
    s = s:gsub("&", "&amp;")
    s = s:gsub("<", "&lt;")
    s = s:gsub(">", "&gt;")
    return s
end

local function rtColor(color, text)
    return string.format(
        '<font color="rgb(%d,%d,%d)">%s</font>',
        math.floor(color.R * 255 + 0.5),
        math.floor(color.G * 255 + 0.5),
        math.floor(color.B * 255 + 0.5),
        escapeRT(text)
    )
end

--// ──────────────── v2.3.0: perbandingan nilai (rekursif aman) ──────────────
--  Dipakai State & Dependency untuk mendeteksi "nilai benar2 berubah"
--  (array multi-dropdown dibandingkan per-isinya, bukan per-referensi).
local function valuesEqual(a, b, seen)
    if a == b then
        return true
    end
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    seen = seen or {}
    if seen[a] == b then
        return true
    end
    seen[a] = b
    for k, v in pairs(a) do
        if not valuesEqual(v, b[k], seen) then
            return false
        end
    end
    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end
    return true
end

--// ───────────────── v2.3.0: SISTEM STATE + BINDING + DEPENDENCY ────────────
--  STATE   : satu nilai bersama yang bisa DIKAITKAN ke banyak elemen — ubah
--            salah satu, semuanya ikut (dua arah, bebas echo/loop).
--  DEPENDS : baris elemen muncul/sembunyi OTOMATIS mengikuti nilai sumber
--            (mis. slider "Kecepatan" hanya tampil saat toggle "Speed" ON).
--  GROUP   : perilaku radio — sekumpulan toggle, maksimal satu aktif.
local StateClass = {}
StateClass.__index = StateClass

local function isThorState(v)
    return type(v) == "table" and v._kind == "ThorState"
end

--  Dependensi: [sumber] = { {El = elemen}, ... } — sumber bisa elemen/state.
--  Weak-key: sumber yang sudah dihancurkan & GC tidak menahan memori.
local DepRegistry = setmetatable({}, { __mode = "k" })
local AllGroups = {} -- semua grup eksklusif (untuk pembersihan saat Remove)

--  Nilai terkini sebuah sumber (elemen → :Get(), state → .Value).
local function sourceValue(src)
    if isThorState(src) then
        return src.Value
    end
    if type(src) == "table" and type(src.Get) == "function" then
        local ok, v = pcall(src.Get, src)
        if ok then
            return v
        end
    end
    return nil
end

--  Terapkan visibilitas satu baris dependen (dengan kaskade ke turunannya).
local depApply
local function evaluateDepsOf(source)
    local deps = DepRegistry[source]
    if not deps then
        return
    end
    for i = #deps, 1, -1 do
        local entry = deps[i]
        local el = entry.El
        if type(el) ~= "table" or not el.Instance or not el.Instance.Parent then
            table.remove(deps, i)
        else
            depApply(el)
        end
    end
end

depApply = function(el)
    local src = el._depSource
    if not src then
        return
    end
    local visible
    if type(el._depPredicate) == "function" then
        local ok, result = pcall(el._depPredicate, sourceValue(src), src, el)
        visible = ok and result == true
    else
        visible = valuesEqual(sourceValue(src), el._depExpected)
    end
    -- rantai: sumber disembunyikan oleh dependensinya sendiri → ikut sembunyi
    if visible and src._depSource and src._depVisible == false then
        visible = false
    end
    el._depVisible = visible
    local show = visible
    if show and el.Section and el.Section.Collapsed then
        show = false -- section sedang terlipat: tetap ikut terlipat
    end
    if el.Instance then
        el.Instance.Visible = show
    end
    evaluateDepsOf(el)
end

--  Daftarkan ketergantungan sebuah elemen. Konfigurasi:
--    Depends = { Element = toggleX, Value = true }
--    Depends = { State   = stateY,  Value = 25 }
--    Depends = { Element = toggleX, Predicate = function(v) return v == true end }
local function registerDependency(el, cfg)
    if type(cfg) ~= "table" then
        return
    end
    local src = cfg.Element or cfg.State or cfg.Source
    if src == nil then
        return
    end
    -- lepas dependensi lama bila ada
    if el._depSource then
        local old = DepRegistry[el._depSource]
        if old then
            for i, entry in ipairs(old) do
                if entry.El == el then
                    table.remove(old, i)
                    break
                end
            end
        end
    end
    el._depSource = src
    el._depExpected = cfg.Value
    el._depPredicate = type(cfg.Predicate) == "function" and cfg.Predicate or nil
    local list = DepRegistry[src]
    if not list then
        list = {}
        DepRegistry[src] = list
    end
    table.insert(list, { El = el })
    depApply(el)
end

local function clearDependency(el)
    if el._depSource then
        local old = DepRegistry[el._depSource]
        if old then
            for i, entry in ipairs(old) do
                if entry.El == el then
                    table.remove(old, i)
                    break
                end
            end
        end
    end
    el._depSource = nil
    el._depExpected = nil
    el._depPredicate = nil
    el._depVisible = nil
    if el.Instance and el.Instance.Parent then
        local show = true
        if el.Section and el.Section.Collapsed then
            show = false
        end
        el.Instance.Visible = show
    end
end

--  Sinkronisasi grup eksklusif — dipanggil setiap nilai toggle berubah.
local function syncGroup(el)
    if type(el) ~= "table" then return end
    local g = el._group
    if type(g) ~= "table" then
        return
    end
    if el.Get and el:Get() == true then
        g.Active = el
        for _, other in ipairs(g.Options) do
            if other ~= el and other.Get and other:Get() == true then
                other:Set(false)
            end
        end
    elseif g.Active == el and g.KeepNone == false then
        -- grup mewajibkan satu aktif → nyalakan kembali
        el:Set(true)
    end
end

--  Pipeline perubahan nilai elemen: (1) dorong ke state terikat, (2) evaluasi
--  baris yang Depends pada elemen ini. Dipanggil pabrik elemen SETIAP kali
--  nilainya berubah — baik oleh aksi pengguna maupun :Set() programatik.
local function notifyChange(element)
    if type(element) ~= "table" or not element.Instance then
        return
    end
    for _, link in ipairs(element._links or {}) do
        if not link._pushing then
            local v = sourceValue(element)
            local mapped = v
            if type(link.ToState) == "function" then
                mapped = link.ToState(v, element)
            end
            link._pushing = true
            link.State:Set(mapped, true)
            link._pushing = false
        end
    end
    evaluateDepsOf(element)
end

--  Lepas elemen dari semua registry global (dipanggil :Remove() elemen).
local function unregisterElement(el)
    for _, link in ipairs(el._links or {}) do
        removeFrom(link.State._links, link)
    end
    el._links = nil
    if el._depSource then
        local old = DepRegistry[el._depSource]
        if old then
            for i, entry in ipairs(old) do
                if entry.El == el then
                    table.remove(old, i)
                    break
                end
            end
        end
    end
    DepRegistry[el] = nil
    el._depSource = nil
    for _, g in ipairs(AllGroups) do
        removeFrom(g.Options, el)
        if g.Active == el then
            g.Active = nil
        end
    end
    el._group = nil
end

--  ── State API publik ──
--  ThorUi:CreateState({ Name, Default, Callback, Normalize })
--  st:Get() / st:Set(v) / st:Subscribe(fn) / st:Bind(target, {ToState, ToOption})
--  / st:BindMany({...}) / st:Unbind(target)
function ThorUi:CreateState(cfg)
    cfg = cfg or {}
    local st = setmetatable({
        _kind = "ThorState",
        Name = tostring(cfg.Name or "State"),
        Value = cfg.Default,
        Normalize = type(cfg.Normalize) == "function" and cfg.Normalize or nil,
        Callback = type(cfg.Callback) == "function" and cfg.Callback or nil,
        _links = {},
        _subs = {},
    }, StateClass)
    return st
end

function StateClass:Get()
    return self.Value
end

--  Dorong nilai state ke satu target (elemen :Set silent / state lain :Set).
local function pushLink(link, stateValue)
    local mapped = stateValue
    if type(link.ToOption) == "function" then
        mapped = link.ToOption(stateValue, link.Target)
    end
    local t = link.Target
    if isThorState(t) then
        t:Set(mapped, true)
    elseif type(t) == "table" and type(t.Set) == "function" then
        pcall(t.Set, t, mapped, true)
    end
end

function StateClass:Set(value, fireCallback)
    if type(self.Normalize) == "function" then
        value = self.Normalize(value)
    end
    local changed = not valuesEqual(self.Value, value)
    self.Value = value
    if changed then
        for _, link in ipairs(self._links) do
            if not link._pushing then
                link._pushing = true
                pushLink(link, value)
                link._pushing = false
            end
        end
        evaluateDepsOf(self)
    end
    if fireCallback ~= false then
        if self.Callback then
            self.Callback(value)
        end
        for _, fn in ipairs(self._subs) do
            fn(value)
        end
    end
    return self
end

function StateClass:Subscribe(fn)
    if type(fn) ~= "function" then
        return function() end
    end
    table.insert(self._subs, fn)
    return function()
        removeFrom(self._subs, fn)
    end
end

function StateClass:Bind(target, opts)
    if target == nil then
        return nil
    end
    opts = opts or {}
    local link = {
        State = self,
        Target = target,
        ToState = type(opts.ToState) == "function" and opts.ToState or nil,
        ToOption = type(opts.ToOption) == "function" and opts.ToOption or nil,
        _pushing = false,
    }
    table.insert(self._links, link)
    if isThorState(target) then
        target._links = target._links or {}
        table.insert(target._links, link)
    elseif type(target) == "table" then
        target._links = target._links or {}
        table.insert(target._links, link)
    end
    -- sync awal: state menang; state kosong (nil) → adopsi nilai target
    if self.Value == nil then
        self.Value = sourceValue(target)
    end
    link._pushing = true
    pushLink(link, self.Value)
    link._pushing = false
    return link
end

--  BindMany({ elemA, elemB, {Element = elemC, ToOption = fn}, ... })
function StateClass:BindMany(list, opts)
    for _, t in ipairs(list or {}) do
        if type(t) == "table" and (t.Element or t.Target) and t.Get == nil and t.Set == nil then
            self:Bind(t.Element or t.Target, t)
        else
            self:Bind(t, opts)
        end
    end
end

function StateClass:Unbind(target)
    for i = #self._links, 1, -1 do
        local link = self._links[i]
        if link.Target == target then
            table.remove(self._links, i)
            if type(target) == "table" and target._links then
                removeFrom(target._links, link)
            end
        end
    end
end

--  ── Grup eksklusif (radio) ──
--  local mode = ThorUi:CreateGroup({ KeepNone = true })
--  Tab:AddToggle({ Name = "A", Group = mode }) ...
--  mode:Get() → toggle aktif · mode:Set(el) · mode:Clear()
function ThorUi:CreateGroup(cfg)
    cfg = cfg or {}
    local group = {
        _kind = "ThorGroup",
        Name = tostring(cfg.Name or "Group"),
        KeepNone = cfg.KeepNone ~= false,
        Options = {},
        Active = nil,
    }
    function group:Set(el)
        for _, other in ipairs(group.Options) do
            if other == el then
                other:Set(true)
            elseif other.Get and other:Get() == true then
                other:Set(false)
            end
        end
    end
    function group:Get()
        return group.Active
    end
    function group:Clear()
        for _, other in ipairs(group.Options) do
            if other.Get and other:Get() == true then
                other:Set(false)
            end
        end
        group.Active = nil
    end
    table.insert(AllGroups, group)
    return group
end

--// ────────────────────────── State library-level ───────────────────────────
local _state = {
    Gui           = nil,  -- ScreenGui utama (CoreGui → PlayerGui fallback)
    NotifyHolder  = nil,  -- kolom notifikasi (kanan atas)
    ToggleButton  = nil,  -- tombol melayang (logo palu)
    TogglePulse   = nil,  -- tween denyut tombol melayang
    Logo          = nil,  -- logo custom {Image, Size} via ThorUi:SetLogo (v2.3.1)
    ToggleKey     = Enum.KeyCode.RightControl,
    ToggleVisible = true,
    KeyConn       = nil,
    Windows       = {},
    Notifs        = {},
    Registry      = Registry.new(), -- garbage table level library
    SplashDone    = false, -- splash hanya sekali per sesi (window pertama)
    SplashActive  = false,
}

local TOGGLE_SIZE = 48

--// ─────────────────── Parenting (CoreGui → PlayerGui) ──────────────────────
local function ensureGui()
    if _state.Gui and _state.Gui.Parent then
        return _state.Gui
    end
    -- bersihkan sisa UI ThorUi dari eksekusi sebelumnya (hindari tombol ⚡
    -- dan window LAMA menumpuk di atas UI yang baru — penting saat re-execute)
    local function purgeOld(container)
        if not container then
            return
        end
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("ScreenGui") and string.sub(child.Name, 1, 7) == "ThorUi_" then
                child:Destroy()
            end
        end
    end
    pcall(purgeOld, game:GetService("CoreGui"))
    if LocalPlayer then
        pcall(purgeOld, LocalPlayer:FindFirstChild("PlayerGui"))
    end
    local gui = Create("ScreenGui", {
        Name = "ThorUi_" .. tostring(math.floor(os.clock() * 1000)),
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 99999,
    })
    local ok = pcall(function()
        gui.Parent = game:GetService("CoreGui")
    end)
    if not ok or not gui.Parent then
        gui.Parent = LocalPlayer and LocalPlayer:WaitForChild("PlayerGui")
    end
    _state.Gui = gui
    return gui
end

--// ───────────────────────── Notifikasi (⚡ slide) ───────────────────────────
local function ensureNotifyHolder()
    if _state.NotifyHolder and _state.NotifyHolder.Parent then
        return _state.NotifyHolder
    end
    local gui = ensureGui()
    local holder = Create("Frame", {
        Name = "ThorUi_NotifyStack",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, 10),
        Size = UDim2.new(0, 300, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex = 60,
        Parent = gui,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = holder,
    })
    _state.NotifyHolder = holder
    return holder
end

local function despawnNotification(entry, instant)
    if not entry or entry.Dead then
        return
    end
    entry.Dead = true
    if entry.Task then
        pcall(function()
            task.cancel(entry.Task)
        end)
    end
    for i, e in ipairs(_state.Notifs) do
        if e == entry then
            table.remove(_state.Notifs, i)
            break
        end
    end
    if instant or not entry.Container.Parent then
        entry.Container:Destroy()
        return
    end
    local out = TweenService:Create(entry.Notif, TI_EXIT, {
        Position = UDim2.new(1, 0, 0, 0),
        GroupTransparency = 1,
    })
    out:Play()
    out.Completed:Connect(function()
        entry.Container:Destroy()
    end)
end

--  ThorUi:Notify({ Title = "⚡ Petir Menyambar", Content = "...", Duration = 3 })
--  Muncul dari sudut kanan atas layar dengan animasi menyambar + fade cepat.
function ThorUi:Notify(cfg)
    if not LocalPlayer then
        warn("[ThorUi] Notify hanya bisa dipanggil dari client.")
        return nil
    end
    cfg = cfg or {}
    local holder = ensureNotifyHolder()

    -- container (diatur UIListLayout, tinggi otomatis)
    local container = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 300, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = #_state.Notifs + 1,
        Parent = holder,
    })

    -- badan notifikasi (CanvasGroup agar bisa fade GroupTransparency)
    local notif = Create("CanvasGroup", {
        Position = UDim2.new(1, 0, 0, 0), -- mulai offscreen kanan
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        GroupTransparency = 1,
        BackgroundColor3 = Theme.BackgroundAlt,
        BorderSizePixel = 0,
        Parent = container,
    })
    Corner(notif, 10)
    Stroke(notif, { Color = Theme.Stroke, Transparency = 0.3 })

    -- bar petir di sisi kiri
    local bar = Create("Frame", {
        Size = UDim2.new(0, 3, 1, 0),
        -- PUTIH: UIGradient menint/mengalikan → warna gradien tampil murni
        BackgroundColor3 = Theme.White,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = notif,
    })
    Corner(bar, UDim.new(1, 0))
    Gradient(bar, Theme.AccentGold, Theme.Accent, 90)

    -- konten dibungkus inner frame agar bar tidak ikut UIListLayout
    local inner = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = notif,
    })
    Create("UIPadding", {
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 14),
        PaddingRight = UDim.new(0, 12),
        Parent = inner,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = inner,
    })

    local row1 = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 16),
        LayoutOrder = 1,
        Parent = inner,
    })
    Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 14, 1, 0),
        Text = cfg.Icon or "⚡",
        Font = Theme.FontBold,
        TextSize = 12,
        TextColor3 = Theme.AccentGold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row1,
    })
    Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 18, 0, 0),
        Size = UDim2.new(1, -18, 1, 0),
        Text = cfg.Title or "ThorHub",
        Font = Theme.FontBold,
        TextSize = 13,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row1,
    })
    local contentLabel = Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 14),
        -- FIX v2.1.2: tinggi eksplisit terukur (autoFitText) — bukan
        -- AutomaticSize.Y yang bisa memesan tinggi kurang dari teks →
        -- teks notifikasi terpotong di dasar kartu
        Text = cfg.Content or "",
        Font = Theme.FontMain,
        TextSize = 12,
        TextColor3 = Theme.TextDim,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        LayoutOrder = 2,
        Parent = inner,
    })
    autoFitText(contentLabel, 0)

    local entry = { Container = container, Notif = notif, Dead = false, Task = nil }
    table.insert(_state.Notifs, entry)

    -- batasi jumlah notifikasi yang tampil (max 5)
    if #_state.Notifs > 5 then
        despawnNotification(_state.Notifs[1], true)
    end

    -- animasi masuk: tunggu layout selesai (2 frame), lalu menyambar masuk
    task.spawn(function()
        RunService.RenderStepped:Wait()
        RunService.RenderStepped:Wait()
        if not container.Parent or entry.Dead then
            return
        end
        Tween(_state.Registry, notif, TI_STRIKE, { Position = UDim2.new(0, 0, 0, 0) })
        Tween(_state.Registry, notif, TI_SNAP, { GroupTransparency = 0 })
    end)

    -- auto-tutup sesuai Duration
    entry.Task = task.delay((cfg.Duration or 4) + 0.45, function()
        despawnNotification(entry, false)
    end)

    -- ketuk / sentuh untuk menutup lebih cepat
    container.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            despawnNotification(entry, false)
        end
    end)

    return entry
end

--// ─────────────────── Toggle semua window (⚡ / keybind) ────────────────────
local function toggleWindows()
    if #_state.Windows == 0 then
        return
    end
    -- window yang sedang proses menutup (_closing) dihitung "tidak terlihat"
    -- supaya tap cepat berturut-turut langsung membatalkan hide & pop kembali
    local anyVisible = false
    for _, w in ipairs(_state.Windows) do
        if w.Frame.Visible and not w._closing then
            anyVisible = true
            break
        end
    end
    for _, w in ipairs(_state.Windows) do
        if anyVisible then
            w:Hide()
        else
            w:Show()
        end
    end
end

local function bindToggleKey(key)
    if key then
        _state.ToggleKey = key
    end
    if _state.KeyConn then
        return
    end
    -- satu koneksi global; key dibaca dinamis saat runtime
    _state.KeyConn = _state.Registry:Connect(UserInputService.InputBegan, function(input, processed)
        if processed then
            return
        end
        if input.KeyCode == _state.ToggleKey then
            toggleWindows()
        end
    end)
end

--// ─────────── Tombol melayang (logo palu — drag bebas + ketuk) ───────────
local function ensureToggleButton()
    if _state.ToggleButton and _state.ToggleButton.Parent then
        _state.ToggleButton.Visible = _state.ToggleVisible
        return _state.ToggleButton
    end
    local gui = ensureGui()
    local reg = _state.Registry

    local btn = Create("TextButton", {
        Name = "ThorUi_Toggle",
        Text = "",
        AutoButtonColor = false,
        ZIndex = 50,
        -- anchor TENGAH (0.5,0.5) permanen: animasi pop & efek "digenggam"
        -- menyala SIMETRIS dari pusat. (Dengan anchor 0,0 ikon membesar ke
        -- kanan-bawah → tampak seperti terloncat setiap kali diketuk.)
        -- Anchor tidak pernah diubah saat drag → tidak ada loncatan anchor.
        AnchorPoint = Vector2.new(0.5, 0.5),
        -- posisi awal = titik TENGAH ikon: tepi kanan 16px, 72% tinggi layar
        Position = UDim2.new(1, -16 - TOGGLE_SIZE * 0.5, 0.72, 0),
        Size = UDim2.fromOffset(TOGGLE_SIZE, TOGGLE_SIZE),
        -- PUTIH: agar gradien Card→Alt tampil murni (bukan tertint gelap)
        BackgroundColor3 = Theme.White,
        BorderSizePixel = 0,
        Visible = _state.ToggleVisible,
        Parent = gui,
    })
    Corner(btn, UDim.new(1, 0))
    Gradient(btn, Theme.Card, Theme.BackgroundAlt, 45)
    Stroke(btn, { Color = Theme.Accent, Thickness = 1.5, Transparency = 0.1 })

    -- logo palu ThorHub (v2.3.1) / logo custom (ThorUi:SetLogo) — geometri
    -- murni: presisi persis di tengah, tanpa nudge +2px ala glyph emoji ⚡
    MakeLogo(btn, {
        Size = 26,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
    }, _state.Logo)

    -- halo berdenyut (glow petir sederhana via transparansi)
    local glow = Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(1.18, 0, 1.18, 0),
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 0.86,
        BorderSizePixel = 0,
        ZIndex = 0,
        Parent = btn,
    })
    Corner(glow, UDim.new(1, 0))
    local pulse = TweenService:Create(
        glow,
        TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { BackgroundTransparency = 0.94 }
    )
    reg:Track(pulse)
    pulse:Play()
    _state.TogglePulse = pulse

    local scale = Create("UIScale", { Parent = btn })

    local function popScale()
        local t1 = Tween(reg, scale, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.22 })
        reg:Connect(t1.Completed, function(playback)
            if playback == Enum.PlaybackState.Completed and btn.Parent then
                Tween(reg, scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
            end
        end)
    end

    -- drag BEBAS + klik (responsif mouse & sentuhan, aman multi-touch)
    --  FIX v2.1.1: sumber input DIKUNCI saat gesture (touch → InputObject
    --  yang sama; mouse → MouseMovement) + snapshot NILAI posisi awal.
    --  FIX "loncat setiap kali diklik": dulu posisi awal drag dibaca dari
    --  AbsolutePosition lalu ditulis ke Position — di beberapa lingkungan
    --  (CoreGui/executor/DPI mobile) keduanya berbeda basis koordinat,
    --  sehingga SETIAP tekanan ikon melompat dulu baru bisa digeser.
    --  Kini konversi scale→offset meniru formula engine sendiri
    --  (posisi = Scale × ukuran parent + Offset) → identitas visual
    --  TERJAMIN di semua perangkat: nol loncatan saat ditekan.
    --  • geser → ikon mengikuti jari/mouse & TETAP di posisi terakhir
    --  • ketuk (tanpa bergeser > 6px) → buka/tutup semua window
    --  • jari kedua yang menumpuk di ikon TIDAK me-reset anchor drag
    local dragging = false
    local moved = false
    local startInput = nil
    local startVec = nil      -- snapshot NILAI posisi input saat gesture mulai
    local startOffset = nil   -- snapshot NILAI titik TENGAH ikon saat mulai

    reg:Connect(btn.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                return
            end
            dragging = true
            moved = false
            startInput = input
            startVec = input.Position -- Vector3 disalin PER NILAI saat dibaca
            -- kunci posisi jadi offset murni TANPA AbsolutePosition:
            -- tiru persis formula yang dipakai engine menempatkan elemen,
            -- sehingga hasilnya 100% identik secara visual (tidak meloncat)
            local p = btn.Position
            local ps = (btn.Parent and btn.Parent.AbsoluteSize.X > 0)
                and btn.Parent.AbsoluteSize
                or GetViewport()
            startOffset = Vector2.new(
                p.X.Scale * ps.X + p.X.Offset,
                p.Y.Scale * ps.Y + p.Y.Offset
            )
            btn.Position = UDim2.new(0, startOffset.X, 0, startOffset.Y)
        end
    end)

    reg:Connect(UserInputService.InputChanged, function(input)
        if not dragging then
            return
        end
        -- FIX v2.1.1: hanya gerakan dari sumber input yang MEMULAI gesture
        if not gestureInput(startInput, input) then
            return
        end
        -- sebagian executor melaporkan InputBegan sentuhan di (0,0) → delta
        -- awal jadi raksasa & ikon melayang lintas layar. Jika snapshot
        -- mencurigakan, ambil ulang dari gerakan pertama (ikon tetap di
        -- tempatnya, lalu mengikuti jari dari titik ini — tidak meloncat).
        if startVec.X == 0 and startVec.Y == 0 and startVec.Z == 0 then
            startVec = input.Position
        end
        local delta = input.Position - startVec
        if math.abs(delta.X) > 6 or math.abs(delta.Y) > 6 then
            if not moved then
                moved = true
                -- angkat sedikit saat mulai digeser (efek "dicengkeram petir")
                Tween(reg, scale, TI_HOVER, { Scale = 1.15 })
            end
        end
        -- posisi bebas + clamp: SELURUH ikon tetap terlihat (margin 4px).
        -- startOffset = titik TENGAH ikon (anchor 0.5,0.5), jadi batas clamp
        -- dihitung dari setengah ukuran — ikon yang sedang membesar saat
        -- digenggam (×1.15) pun tidak pernah keluar dari layar.
        local vp = GetViewport()
        local halfX = (btn.AbsoluteSize.X > 0 and btn.AbsoluteSize.X or TOGGLE_SIZE) * 0.5
        local halfY = (btn.AbsoluteSize.Y > 0 and btn.AbsoluteSize.Y or TOGGLE_SIZE) * 0.5
        local nx = math.clamp(startOffset.X + delta.X, 4 + halfX, math.max(4 + halfX, vp.X - halfX - 4))
        local ny = math.clamp(startOffset.Y + delta.Y, 4 + halfY, math.max(4 + halfY, vp.Y - halfY - 4))
        -- offset dibulatkan agar ikon tidak "getar" di antara pixel
        btn.Position = UDim2.new(0, math.floor(nx + 0.5), 0, math.floor(ny + 0.5))
    end)

    reg:Connect(UserInputService.InputEnded, function(input)
        if not dragging then
            return
        end
        -- hanya jari/klik yang MEMULAI drag yang boleh mengakhirinya
        if not gestureEnded(startInput, input) then
            return
        end
        dragging = false
        if moved then
            -- tetap di posisi terakhir dilepas (tidak di-snap ke tepi)
            Tween(reg, scale, TI_SNAP, { Scale = 1 })
        else
            -- dianggap ketuk → buka/tutup UI
            popScale()
            toggleWindows()
        end
    end)

    _state.ToggleButton = btn
    return btn
end

--// ────────────── Metode publik level-library (⚡ / keybind) ─────────────
--  ThorUi:Toggle()             — tampilkan/sembunyikan semua window
--  ThorUi:SetKeybind(key)      — ganti keybind toggle global (mis. Enum.KeyCode.K)
--  ThorUi:SetToggleVisible(b)  — tampil/sembunyikan tombol ⚡ melayang
function ThorUi:Toggle()
    toggleWindows()
end

function ThorUi:SetKeybind(key)
    bindToggleKey(key)
end

function ThorUi:SetToggleVisible(visible)
    _state.ToggleVisible = visible and true or false
    local btn = _state.ToggleButton
    if _state.ToggleVisible and not (btn and btn.Parent) then
        ensureToggleButton()
        btn = _state.ToggleButton
    end
    if btn and btn.Parent then
        btn.Visible = _state.ToggleVisible
    end
end

--// ────────────────── v2.3.0: TEMA (merge sebelum CreateWindow) ─────────────
--  ThorUi:SetTheme({ Accent = Color3.fromRGB(...) }) — gabungkan patch ke
--  tema aktif. Panggil SEBELUM CreateWindow: elemen mengambil warna saat
--  dibuat, jadi perubahan setelah window ada tidak mengecat ulang.
function ThorUi:SetTheme(patch)
    if type(patch) == "table" then
        for k, v in pairs(patch) do
            Theme[k] = v
        end
    end
    return Theme
end

--// ────────────────── v2.3.1: LOGO (pasang sebelum CreateWindow) ─────────────
--  ThorUi:SetLogo({ Image = "rbxassetid://...", Size = 26 }) — pengguna
--  library bisa memasang LOGO SENDIRI; berlaku di splash, sidebar & tombol
--  melayang. Panggil SEBELUM CreateWindow. Tanpa dipanggil → palu ThorHub
--  geometris bawaan (nol Asset ID). Override per-window:
--  CreateWindow({ Logo = { Image = "...", Size = 26 } }).
function ThorUi:SetLogo(cfg)
    _state.Logo = (type(cfg) == "table") and cfg or nil
    return _state.Logo
end

--// ──────────── v2.3.0: QUICK ACTION (tombol aksi melayang) ────────────────
--  Tombol bundar kecil di deret pinggir layar — pintasan aksi favorit yang
--  selalu terlihat walau window tertutup. Seluruh deret bisa DIGESER
--  (drag), ketuk = eksekusi. Contoh:
--      ThorUi:AddQuickAction({ Icon = "⚡", Name = "Rejoin",
--          Callback = function() ... end })
local QUICK_SIZE = 36
local function ensureQuickDock()
    if _state.QuickDock and _state.QuickDock.Parent then
        return _state.QuickDock
    end
    local gui = ensureGui()
    local reg = _state.Registry

    local dock = Create("Frame", {
        Name = "ThorUi_QuickDock",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.28, 0),
        Size = UDim2.fromOffset(QUICK_SIZE, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 40,
        Parent = gui,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        Parent = dock,
    })
    _state.QuickDock = dock

    -- drag deret: posisi dikunci offset murni (formula engine, tanpa
    -- AbsolutePosition — anti-loncat di semua lingkungan, pola tombol ⚡)
    reg:Connect(dock:GetPropertyChangedSignal("AbsoluteSize"), function()
        -- ukuran berubah (tombol ditambah) → pastikan tetap di dalam layar
        local vp = GetViewport()
        local p = dock.Position
        local x = math.min(p.X.Offset, vp.X - 20)
        local y = math.clamp(p.Y.Offset, 40, math.max(40, vp.Y - 40))
        dock.Position = UDim2.new(0, x, 0, y)
    end)
    return dock
end

--  Handler drag + tap untuk satu tombol quick action (menggerakkan DERET).
local function bindQuickButton(reg, btn, onTap)
    local dragging = false
    local moved = false
    local startInput = nil
    local startVec = nil
    local startPos = nil -- posisi {x,y} TENGAH deret saat mulai

    reg:Connect(btn.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                return
            end
            dragging = true
            moved = false
            startInput = input
            startVec = input.Position
            local dock = btn.Parent
            local p = dock.Position
            local ps = (dock.Parent and dock.Parent.AbsoluteSize.X > 0)
                and dock.Parent.AbsoluteSize
                or GetViewport()
            startPos = Vector2.new(
                p.X.Scale * ps.X + p.X.Offset,
                p.Y.Scale * ps.Y + p.Y.Offset
            )
            dock.Position = UDim2.new(0, startPos.X, 0, startPos.Y)
        end
    end)

    reg:Connect(UserInputService.InputChanged, function(input)
        if not dragging or not gestureInput(startInput, input) then
            return
        end
        if startVec.X == 0 and startVec.Y == 0 and startVec.Z == 0 then
            startVec = input.Position
        end
        local delta = input.Position - startVec
        if math.abs(delta.X) > 6 or math.abs(delta.Y) > 6 then
            moved = true
        end
        local dock = btn.Parent
        local vp = GetViewport()
        local halfX = QUICK_SIZE * 0.5
        local halfY = math.max(dock.AbsoluteSize.Y * 0.5, QUICK_SIZE * 0.5)
        local nx = math.clamp(startPos.X + delta.X, halfX + 4, math.max(halfX + 4, vp.X - halfX - 4))
        local ny = math.clamp(startPos.Y + delta.Y, halfY + 4, math.max(halfY + 4, vp.Y - halfY - 4))
        dock.Position = UDim2.new(0, math.floor(nx + 0.5), 0, math.floor(ny + 0.5))
    end)

    reg:Connect(UserInputService.InputEnded, function(input)
        if not dragging or not gestureEnded(startInput, input) then
            return
        end
        dragging = false
        if not moved then
            onTap()
        end
    end)
end

--  ThorUi:AddQuickAction({ Icon, Name, Callback }) → { Remove() }
function ThorUi:AddQuickAction(cfg)
    cfg = cfg or {}
    if type(cfg.Callback) ~= "function" then
        return nil
    end
    local dock = ensureQuickDock()
    local reg = _state.Registry

    local btn = Create("TextButton", {
        Text = "",
        AutoButtonColor = false,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(QUICK_SIZE, QUICK_SIZE),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        LayoutOrder = #dock:GetChildren(),
        Parent = dock,
    })
    Corner(btn, UDim.new(1, 0))
    Stroke(btn, { Color = Theme.AccentGold, Thickness = 1, Transparency = 0.25 })
    local scale = Create("UIScale", { Parent = btn })
    Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 1),
        Size = UDim2.new(1, 0, 1, 0),
        Text = tostring(cfg.Icon or "⚡"),
        Font = Theme.FontBold,
        TextSize = 15,
        TextColor3 = Theme.AccentGold,
        Parent = btn,
    })

    -- tooltip nama (hanya perangkat bermouse)
    if HOVER_FOR_MOUSE then
        local tip = Create("TextLabel", {
            BackgroundColor3 = Theme.BackgroundAlt,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(0, -12, 0.5, 0),
            Size = UDim2.new(0, math.max(40, #tostring(cfg.Name or "Aksi") * 7 + 16), 0, 22),
            Text = tostring(cfg.Name or "Aksi"),
            Font = Theme.FontMedium,
            TextSize = 11,
            TextColor3 = Theme.Text,
            Visible = false,
            ZIndex = 6,
            Parent = btn,
        })
        Corner(tip, 6)
        Stroke(tip, { Color = Theme.StrokeDim, Transparency = 0.3 })
        reg:Connect(btn.MouseEnter, function()
            tip.Visible = true
            Tween(reg, btn, TI_HOVER, { BackgroundColor3 = Theme.CardHover })
        end)
        reg:Connect(btn.MouseLeave, function()
            tip.Visible = false
            Tween(reg, btn, TI_HOVER, { BackgroundColor3 = Theme.Card })
        end)
    end

    bindQuickButton(reg, btn, function()
        Tween(reg, scale, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.2 })
        task.delay(0.08, function()
            if btn.Parent then
                Tween(reg, scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
            end
        end)
        Zap(reg, btn, Theme.AccentGold, UDim.new(1, 0))
        cfg.Callback()
    end)

    return {
        Remove = function()
            btn:Destroy()
            if _state.QuickDock and #_state.QuickDock:GetChildren() == 0 then
                _state.QuickDock:Destroy()
                _state.QuickDock = nil
            end
        end,
    }
end

--// ────────────────────────── SPLASH SCREEN (tema Thor) ─────────────────────────────
--  Layar pembuka: logo palu memantul + progress bar petir + status menggemas.
--  playSplash(onDone, brand) tidak memblokir; onDone dipanggil setelah
--  fade-out. brand = { Logo, Title } dari CreateWindow (v2.3.1) — tanpa itu
--  dipakai ThorUi:SetLogo / default palu ThorHub + judul "ThorHub".
local function playSplash(onDone, brand)
    local gui = ensureGui()
    local reg = Registry.new()
    _state.SplashActive = true
    local logoCfg = (type(brand) == "table" and brand.Logo) or _state.Logo
    local titleText = (type(brand) == "table" and brand.Title) or "ThorHub"

    local overlay = Create("Frame", {
        Name = "ThorUi_Splash",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 100,
        Parent = gui,
    })

    -- konten tengah (diatur UIListLayout, center)
    local holder = Create("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.44, 0),
        Size = UDim2.new(0, 260, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = overlay,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        Parent = holder,
    })

    -- lingkaran logo (pop memantul saat muncul) — v2.3.1: palu ThorHub
    local circle = Create("Frame", {
        Size = UDim2.fromOffset(88, 88),
        -- PUTIH: agar gradien Card→BackgroundAlt tampil murni (bukan tertint)
        BackgroundColor3 = Theme.White,
        BorderSizePixel = 0,
        LayoutOrder = 1,
        Parent = holder,
    })
    Corner(circle, UDim.new(1, 0))
    Gradient(circle, Theme.Card, Theme.BackgroundAlt, 45)
    Stroke(circle, { Color = Theme.Accent, Thickness = 1.5, Transparency = 0.05 })
    local circleScale = Create("UIScale", { Scale = 0.3, Parent = circle })
    MakeLogo(circle, {
        Size = 48,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
    }, logoCfg)

    -- judul dengan teks gradien emas → cyan
    local title = Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 24),
        Text = titleText,
        Font = Theme.FontBold,
        TextSize = 22,
        TextColor3 = Theme.White,
        LayoutOrder = 2,
        Parent = holder,
    })
    Gradient(title, Theme.AccentGold, Theme.Accent, 25)

    Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 14),
        Text = "v" .. ThorUi.Version .. " — Dewa Petir",
        Font = Theme.FontMain,
        TextSize = 12,
        TextColor3 = Theme.TextDim,
        LayoutOrder = 3,
        Parent = holder,
    })

    -- progress bar petir
    local barTrack = Create("Frame", {
        Size = UDim2.new(0, 220, 0, 4),
        BackgroundColor3 = Theme.Track,
        BorderSizePixel = 0,
        LayoutOrder = 4,
        Parent = holder,
    })
    Corner(barTrack, UDim.new(1, 0))
    local barFill = Create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.White, -- PUTIH: UIGradient menint -> gradien murni
        BorderSizePixel = 0,
        Parent = barTrack,
    })
    Corner(barFill, UDim.new(1, 0))
    -- FIX v2.1.4: gradien selaras-hue biru->biru muda (vertikal); gradien
    -- biru->emas lama ternyata tertint Accent sehingga tampak HIJAU
    Gradient(barFill, Color3.fromRGB(0, 170, 235), Color3.fromRGB(90, 220, 255), 90)

    local status = Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 14),
        Text = "...",
        Font = Theme.FontMain,
        TextSize = 11,
        TextColor3 = Theme.TextDim,
        LayoutOrder = 5,
        Parent = holder,
    })

    -- fade-in cepat lalu logo memantul
    Tween(reg, overlay, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0 })
    Tween(reg, circleScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })

    -- urutan animasi (async, tidak memblokir caller)
    task.spawn(function()
        local statuses = { "Menghubungkan ke Valhalla...", "Memanggil petir...", "Menempa Mjolnir..." }
        for _, s in ipairs(statuses) do
            if not overlay.Parent or not _state.SplashActive then
                return
            end
            status.Text = s
            task.wait(0.33)
        end

        local fill = Tween(reg, barFill, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, 0, 1, 0),
        })
        fill.Completed:Wait()
        if not overlay.Parent or not _state.SplashActive then
            return
        end

        status.Text = "⚡ Siap!"
        task.wait(0.18)

        local fade = Tween(reg, overlay, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            BackgroundTransparency = 1,
        })
        fade.Completed:Wait()
        reg:Clean()
        if overlay.Parent then
            overlay:Destroy()
        end
        _state.SplashActive = false
        if onDone then
            onDone()
        end
    end)
end

--// ──────────────────────────────── Tab ─────────────────────────────────────
--  v2: tombol tab vertikal di SIDEBAR (ikon + nama), bukan lagi tab horizontal.
local TabClass = {}
TabClass.__index = TabClass

function TabClass.new(window, cfg)
    cfg = cfg or {}
    local reg = Registry.new()

    -- tombol tab di sidebar (vertikal, ber-ikon)
    local btn = Create("TextButton", {
        Name = "Tab_" .. tostring(cfg.Name or "Tab"),
        Text = "",
        AutoButtonColor = false,
        BackgroundColor3 = Theme.Card,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 34),
        BorderSizePixel = 0,
        LayoutOrder = #window.Tabs + 1,
        Parent = window.TabList,
    })
    Corner(btn, 8)

    -- indikator petir di sisi kiri (menyambar saat tab aktif)
    local indicator = Create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 3, 0, 0),
        BackgroundColor3 = Theme.White, -- PUTIH: gradien emas->biru murni
        BorderSizePixel = 0,
        Parent = btn,
    })
    Corner(indicator, UDim.new(1, 0))
    Gradient(indicator, Theme.AccentGold, Theme.Accent, 90)

    local icon = Create("TextLabel", {
        BackgroundTransparency = 1,
        -- +1px: glyph emoji bawaan Roblox cenderung "melayang" ke atas;
        -- saat sidebar icon-only posisi digeser ke tengah oleh _updateResponsive
        Position = UDim2.new(0, 10, 0, 1),
        Size = UDim2.new(0, 18, 1, 0),
        Text = tostring(cfg.Icon or "⚡"),
        Font = Theme.FontBold,
        TextSize = 13,
        TextColor3 = Theme.TextDim,
        Parent = btn,
    })
    local label = Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 32, 0, 0),
        Size = UDim2.new(1, -36, 1, 0),
        Text = tostring(cfg.Name or "Tab"),
        Font = Theme.FontMedium,
        TextSize = 12,
        TextColor3 = Theme.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = btn,
    })

    -- konten tab: langsung ditaruh di ScrollingFrame utama (AutomaticCanvasSize)
    local container = Create("Frame", {
        Name = "TabContent_" .. tostring(cfg.Name or "Tab"),
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false,
        Parent = window.Content,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = container,
    })
    Create("UIPadding", {
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        Parent = container,
    })

    local self = setmetatable({
        Window = window,
        Registry = reg,
        Button = btn,
        Icon = icon,
        Label = label,
        Indicator = indicator,
        Container = container,
        Elements = {},
        Sections = {}, -- v2.2.1: daftar menu (section) — bisa di-minimize
        Order = 0,
        Active = false,
        FilterQuery = "",
    }, TabClass)

    reg:Connect(btn.Activated, function()
        window:SelectTab(self)
    end)
    reg:Connect(btn.MouseEnter, function()
        if not self.Active then
            Tween(reg, btn, TI_HOVER, { BackgroundTransparency = 0.75 })
            Tween(reg, label, TI_HOVER, { TextColor3 = Theme.Text })
            Tween(reg, icon, TI_HOVER, { TextColor3 = Theme.Text })
        end
    end)
    reg:Connect(btn.MouseLeave, function()
        if not self.Active then
            Tween(reg, btn, TI_HOVER, { BackgroundTransparency = 1 })
            Tween(reg, label, TI_HOVER, { TextColor3 = Theme.TextDim })
            Tween(reg, icon, TI_HOVER, { TextColor3 = Theme.TextDim })
        end
    end)

    return self
end

function TabClass:_nextOrder()
    self.Order = self.Order + 1
    return self.Order
end

--  Daftarkan elemen ke tab + pasang :Remove() yang membersihkan registry-nya.
function TabClass:_track(element)
    local tab = self
    table.insert(tab.Elements, element)
    -- v2.2.1: elemen otomatis menjadi ANGGOTA menu (section) aktif terakhir
    tab:_own(element)
    function element:Remove()
        -- v2.3.0: anak2 (AddChild) dihapus dulu — registry & kaitan
        -- state/dependensi/grup mereka ikut bersih sebelum kartu hancur
        if self.Children then
            local kids = {}
            for _, c in ipairs(self.Children) do
                kids[#kids + 1] = c
            end
            for _, c in ipairs(kids) do
                if type(c.Remove) == "function" then
                    c:Remove()
                end
            end
        end
        -- v2.3.0: lepas dari registry State/Depends/Group
        unregisterElement(self)
        if self.Registry then
            self.Registry:Clean()
        end
        if self.Instance and self.Instance.Parent then
            self.Instance:Destroy()
        end
        for i, el in ipairs(tab.Elements) do
            if el == self then
                table.remove(tab.Elements, i)
                break
            end
        end
        -- v2.2.1: keluar juga dari daftar anggota menu (section)-nya
        local sec = self.Section
        if sec and sec.Members then
            for i, m in ipairs(sec.Members) do
                if m == self then
                    table.remove(sec.Members, i)
                    break
                end
            end
        end
    end
end

--  v2.2.1: daftarkan elemen sebagai anggota menu (section) yang sedang aktif.
--  Dipanggil oleh _track (elemen interaktif) dan AddLabel/AddParagraph
--  (elemen statis) — semua fitur yang dibuat SETELAH AddSection otomatis
--  tergabung ke menu itu, sehingga bisa di-minimize bersama dengan satu klik
--  pada judul section-nya.
function TabClass:_own(element)
    local sec = self._currentSection
    if sec and sec.Members then
        element.Section = sec
        table.insert(sec.Members, element)
        -- menu sedang di-minimize → elemen baru langsung tersembunyi
        if sec.Collapsed and element.Instance then
            element.Instance.Visible = false
        end
    end
end

--  Filter pencarian: sembunyikan elemen yang namanya tidak cocok.
--  Dipanggil oleh search bar window (hanya memengaruhi tab aktif).
function TabClass:ApplyFilter(query)
    query = tostring(query or "")
    self.FilterQuery = query
    local needle = query:lower()
    local filtering = needle ~= ""
    for _, el in ipairs(self.Elements) do
        if el.Instance then
            local name = el.Name
            local visible
            if not filtering or name == nil or name == "" then
                visible = true
            else
                visible = string.find(tostring(name):lower(), needle, 1, true) ~= nil
            end
            -- v2.2.1: menu sedang di-minimize → anggotanya TETAP tersembunyi
            -- (pencarian tidak membuka lipatan menu)
            if el.Section and el.Section.Collapsed then
                visible = false
            end
            -- v2.3.0: disembunyikan oleh Depends → tetap sembunyi
            if el._depVisible == false then
                visible = false
            end
            el.Instance.Visible = visible
        end
    end
    -- v2.2.1: saat mencari, judul menu tanpa anggota yang cocok ikut
    -- disembunyikan supaya hasil pencarian lebih rapat
    for _, sec in ipairs(self.Sections) do
        if sec.Instance then
            if not filtering then
                sec.Instance.Visible = true
            else
                local anyVisible = false
                for _, m in ipairs(sec.Members) do
                    if m.Instance and m.Instance.Visible then
                        anyVisible = true
                        break
                    end
                end
                sec.Instance.Visible = anyVisible
            end
        end
    end
end

--  Card dasar semua elemen: bg + UICorner + UIStroke + padding + UIListLayout
function TabClass:_card(className)
    className = className or "Frame"
    local props = {
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = self:_nextOrder(),
        Parent = self.Container,
    }
    if className == "TextButton" then
        props.Text = ""
        props.AutoButtonColor = false
    end
    local card = Create(className, props)
    Corner(card, 10)
    local stroke = Stroke(card, { Color = Theme.StrokeDim, Transparency = 0.35 })
    Create("UIPadding", {
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        Parent = card,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = card,
    })
    return card, stroke
end

function TabClass:Remove()
    local elements = {}
    for _, el in ipairs(self.Elements) do
        table.insert(elements, el)
    end
    for _, el in ipairs(elements) do
        el:Remove()
    end
    -- v2.2.1: bersihkan registry semua menu (section) di tab ini
    local sections = {}
    for _, sec in ipairs(self.Sections) do
        table.insert(sections, sec)
    end
    for _, sec in ipairs(sections) do
        sec:Remove()
    end
    self.Registry:Clean()
    if self.Button and self.Button.Parent then
        self.Button:Destroy()
    end
    if self.Container and self.Container.Parent then
        self.Container:Destroy()
    end
    local tabs = self.Window.Tabs
    for i, t in ipairs(tabs) do
        if t == self then
            table.remove(tabs, i)
            break
        end
    end
    if self.Window._activeTab == self then
        self.Window._activeTab = nil
        if tabs[1] then
            self.Window:SelectTab(tabs[1])
        end
    end
end

--// ───────────── Elemen: keterangan/Description (modern) ────────────
--  Teks kecil redup di bawah judul elemen. Dibuat SECARA MALAS (hanya saat
--  ada isinya) supaya jarak antar-baris tidak berubah saat tidak dipakai.
--  FIX v2.1.1: sebelumnya config Description diabaikan total → "keterangan
--  slider dll tidak kelihatan".
--  FIX v2.1.2 (dari screenshot user): tinggi keterangan kini DIUKUR SINKRON
--  (autoFitText → TextService:GetTextSize → Size eksplisit). Dulu memakai
--  AutomaticSize.Y yang di sebagian perangkat memesan tinggi lebih kecil
--  dari render → baris setelahnya (track slider, box input, garis section)
--  MENIMPA separuh bawah teks keterangan. Pemakaian:
--      local setDesc = attachDescription(card, 2)  -- urutan setelah judul
--      setDesc(cfg.Description)                     -- boleh nil/kosong
--      setDesc("teks baru")                         -- dipanggil ulang kapan pun
local function attachDescription(card, order)
    local label = nil
    return function(text)
        if text == nil or tostring(text) == "" then
            if label then
                label.Visible = false
            end
            return
        end
        if not label then
            label = Create("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 14),
                Font = Theme.FontMain,
                TextSize = 12, -- cukup besar untuk dibaca di mobile, tetap halus
                TextColor3 = Theme.TextDim,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                LayoutOrder = order,
                Parent = card,
            })
            -- FIX v2.1.2: ukur tinggi teks eksplisit + re-ukur saat teks /
            -- lebar kartu berubah — keterangan TIDAK PERNAH lagi tertimpa
            autoFitText(label, 14)
        end
        label.Visible = true
        label.Text = tostring(text)
    end
end

--// ──────────────────── v2.3.0: SUB-ROW (Element:AddChild) ──────────────────
--  Setiap elemen interaktif bisa punya ANAK (elemen bertingkat):
--      toggle:AddChild("Slider", { Name = "Kecepatan", Min = 0, Max = 100 })
--  Anak tampil di dalam kartu induk, terinden 16px, dibuka/ditutup lewat
--  panah kecil di kiri judul (chevron tergambar — konsisten anti-tofu).
--  API induk: AddChild(kind, cfg) · SetExpanded(bool) · ToggleExpanded()
--             IsExpanded() · .Children
local CHILD_FACTORIES = {
    Button      = "AddButton",
    Toggle      = "AddToggle",
    Slider      = "AddSlider",
    Dropdown    = "AddDropdown",
    TextInput   = "AddTextInput",
    Keybind     = "AddKeybind",
    ColorPicker = "AddColorPicker",
    Label       = "AddLabel",
    Paragraph   = "AddParagraph",
    List        = "AddList",
    ModelView   = "AddModelView",
    Canvas      = "AddCanvas",
}

local function normalizeChildKind(kind)
    local k = tostring(kind or "")
    k = k:gsub("^%l", string.upper)
    return CHILD_FACTORIES[k] and k or nil
end

--  Dipanggil pabrik elemen SETELAH :_track(element):
--    EnableChildren(tab, element, cfg, row, titleLabel, "row"|"card", yCenter)
--  mode "row"  → chevron di tengah vertikal baris judul (row = Frame baris)
--  mode "card" → judul menempel langsung di kartu (chevron di yCenter px)
--  Sekaligus memasang kaitan Depends (visibilitas otomatis) dari cfg.
local function EnableChildren(tab, element, cfg, row, titleLabel, mode, yCenter)
    element.Children = {}

    local subHost = nil   -- wadah anak (dibuat malas saat anak pertama)
    local chevBtn = nil
    local chevron, chevA, chevB = nil, nil, nil
    local expanded = false

    local function buildSubUI()
        if subHost then
            return
        end
        -- panah kecil di kiri judul (digambar — tanpa glyph font)
        local parentRow = (mode == "card") and element.Instance or row
        chevBtn = Create("TextButton", {
            Name = "Expand",
            Text = "",
            AutoButtonColor = false,
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0, 0.5),
            Size = UDim2.fromOffset(16, 16),
            ZIndex = 5,
            Parent = parentRow,
        })
        if mode == "card" then
            chevBtn.Position = UDim2.new(0, -2, 0, yCenter or 9)
        else
            chevBtn.Position = UDim2.new(0, -2, 0.5, 0)
        end
        chevron, chevA, chevB = ChevronIcon(chevBtn, {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = 9,
            Color = Theme.TextDim,
        })
        chevron.Rotation = -90 -- terlipat: panah menghadap kanan
        -- geser judul ke kanan agar tidak bertabrakan dengan panah
        if titleLabel then
            local p = titleLabel.Position
            titleLabel.Position = UDim2.new(p.X.Scale, p.X.Offset + 14, p.Y.Scale, p.Y.Offset)
            titleLabel.Size = UDim2.new(
                titleLabel.Size.X.Scale,
                titleLabel.Size.X.Offset - 14,
                titleLabel.Size.Y.Scale,
                titleLabel.Size.Y.Offset
            )
        end
        element.Registry:Connect(chevBtn.Activated, function()
            element:ToggleExpanded()
        end)
        -- wadah anak: terinden 16px + garis pemandu vertikal tipis di kiri
        subHost = Create("Frame", {
            Name = "SubRows",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Visible = false,
            LayoutOrder = 40,
            Parent = element.Instance,
        })
        Create("UIListLayout", {
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = subHost,
        })
        Create("UIPadding", {
            PaddingLeft = UDim.new(0, 16),
            Parent = subHost,
        })
        local guide = Create("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 4, 0.5, 0),
            Size = UDim2.fromOffset(2, 0),
            BackgroundColor3 = Theme.White,
            BorderSizePixel = 0,
            Parent = subHost,
        })
        Corner(guide, UDim.new(1, 0))
        Gradient(guide, Theme.Accent, Theme.AccentGold, 90, NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.5, 0.55),
            NumberSequenceKeypoint.new(1, 0),
        }))
        -- garis pemandu mengikuti tinggi konten anak
        element.Registry:Connect(subHost:GetPropertyChangedSignal("AbsoluteContentSize"), function()
            local lay = subHost:FindFirstChildOfClass("UIListLayout")
            local h = lay and lay.AbsoluteContentSize.Y or 0
            guide.Size = UDim2.fromOffset(2, math.max(0, h))
        end)
    end

    --  Proxy "tab" untuk membangun anak di dalam subHost: pabrik elemen
    --  (AddToggle dll.) bekerja normal, tapi kartu anak masuk ke subHost,
    --  tetap terdaftar di Elements/membership section tab asal (filter &
    --  lipatan section tetap berfungsi), dan :Remove() anak juga keluar
    --  dari daftar anak induk.
    local proxy = nil
    local function ensureProxy()
        if proxy then
            return proxy
        end
        proxy = setmetatable({
            Window = tab.Window,
            Container = subHost,
            Elements = tab.Elements,
            Sections = tab.Sections,
            Order = 0,
            FilterQuery = "",
            _parentElement = element,
        }, TabClass)
        function proxy:_track(child)
            table.insert(tab.Elements, child)
            tab:_own(child)
            child._parentElement = element
            table.insert(element.Children, child)
            function child:Remove()
                if self.Children then
                    local kids = {}
                    for _, c in ipairs(self.Children) do
                        kids[#kids + 1] = c
                    end
                    for _, c in ipairs(kids) do
                        if type(c.Remove) == "function" then
                            c:Remove()
                        end
                    end
                end
                unregisterElement(self)
                if self.Registry then
                    self.Registry:Clean()
                end
                if self.Instance and self.Instance.Parent then
                    self.Instance:Destroy()
                end
                for i, el in ipairs(tab.Elements) do
                    if el == self then
                        table.remove(tab.Elements, i)
                        break
                    end
                end
                local sec = self.Section
                if sec and sec.Members then
                    for i, m in ipairs(sec.Members) do
                        if m == self then
                            table.remove(sec.Members, i)
                            break
                        end
                    end
                end
                for i, c in ipairs(element.Children) do
                    if c == self then
                        table.remove(element.Children, i)
                        break
                    end
                end
            end
        end
        return proxy
    end

    function element:AddChild(kind, childCfg)
        local k = normalizeChildKind(kind)
        if not k then
            return nil
        end
        buildSubUI()
        local p = ensureProxy()
        p._currentSection = tab._currentSection -- anak ikut section aktif
        local factory = TabClass[CHILD_FACTORIES[k]]
        local child = factory(p, childCfg or {})
        if child then
            child.Instance.LayoutOrder = #element.Children
        end
        return child
    end

    function element:SetExpanded(v)
        if not subHost then
            return
        end
        expanded = v == true
        subHost.Visible = expanded
        local c = expanded and Theme.Accent or Theme.TextDim
        if chevBtn then
            Tween(element.Registry, chevron, TI_HOVER, { Rotation = expanded and 0 or -90 })
            Tween(element.Registry, chevA, TI_HOVER, { BackgroundColor3 = c })
            Tween(element.Registry, chevB, TI_HOVER, { BackgroundColor3 = c })
        end
    end

    function element:ToggleExpanded()
        element:SetExpanded(not expanded)
    end

    function element:IsExpanded()
        return expanded
    end

    --  v2.3.0: Depends — baris ini muncul/hilang otomatis mengikuti sumber
    element.SetDependency = function(_, dep)
        registerDependency(element, dep)
    end
    element.ClearDependency = function(_)
        clearDependency(element)
    end
    if cfg and cfg.Depends then
        registerDependency(element, cfg.Depends)
    end
end

--// ─────────────────────────── Elemen: BUTTON ───────────────────────────────
--  v2.3.0: ConfirmText — klik dua tahap (klik 1 = "siapkan", klik 2 = eksekusi;
--  otomatis batal setelah 2.5 detik) untuk aksi berisiko.
function TabClass:AddButton(cfg)
    cfg = cfg or {}
    local reg = Registry.new()
    local card, stroke = self:_card("TextButton")

    local baseText = tostring(cfg.Name or "Button")
    local label = Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 18),
        Text = baseText,
        Font = Theme.FontMedium,
        TextSize = 13,
        TextColor3 = Theme.Text,
        LayoutOrder = 1,
        Parent = card,
    })

    local setDesc = attachDescription(card, 2)
    setDesc(cfg.Description)

    cardHover(reg, card, stroke)

    -- mode konfirmasi dua tahap
    local confirmText = cfg.ConfirmText ~= nil and tostring(cfg.ConfirmText)
        or (cfg.Confirm == true and "Yakin?" or nil)
    local armed = false
    local armToken = 0

    local function disarm()
        armed = false
        label.Text = baseText
        label.TextColor3 = Theme.Text
        Tween(reg, stroke, TI_HOVER, { Color = Theme.StrokeDim, Transparency = 0.35 })
    end

    local function arm()
        armed = true
        armToken = armToken + 1
        label.Text = confirmText
        label.TextColor3 = Theme.AccentGold
        Tween(reg, stroke, TI_HOVER, { Color = Theme.AccentGold, Transparency = 0 })
        Zap(reg, card, Theme.AccentGold, 10)
        -- batal otomatis setelah 2.5 detik tanpa aktivitas
        local token = armToken
        task.delay(2.5, function()
            if armed and armToken == token and card.Parent then
                disarm()
            end
        end)
    end

    local function fire()
        if cfg.Callback then
            cfg.Callback()
        end
    end

    reg:Connect(card.Activated, function()
        if confirmText then
            if armed then
                disarm()
                Zap(reg, card, Theme.Accent, 10)
                fire()
                return
            end
            arm()
            return
        end
        Zap(reg, card, Theme.Accent, 10)
        fire()
    end)

    local element = {
        Type = "Button",
        Name = cfg.Name,
        Instance = card,
        Registry = reg,
        SetDescription = function(_, t)
            setDesc(t)
        end,
        Get = function(_)
            return baseText
        end,
        Set = function(_, name)
            baseText = tostring(name)
            if not armed then
                label.Text = baseText
            end
        end,
        Fire = function(_)
            fire()
        end,
        ResetConfirm = function(_)
            if confirmText and armed then
                disarm()
            end
        end,
    }
    self:_track(element)
    EnableChildren(self, element, cfg, nil, label, "card", 9)
    return element
end

--// ─────────────────────────── Elemen: TOGGLE ───────────────────────────────
--  v2: switch modern — track memanjang + knob bulat meluncur kilat.
function TabClass:AddToggle(cfg)
    cfg = cfg or {}
    local reg = Registry.new()
    local card, stroke = self:_card("TextButton")

    local row = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 22),
        LayoutOrder = 1,
        Parent = card,
    })
    local titleLabel = Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -64, 1, 0),
        Text = cfg.Name or "Toggle",
        Font = Theme.FontMedium,
        TextSize = 13,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })

    -- switch: track 40x20 + knob 16 bulat
    local pill = Create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(40, 20),
        BackgroundColor3 = Theme.Track,
        BorderSizePixel = 0,
        Parent = row,
    })
    Corner(pill, UDim.new(1, 0))
    local pillStroke = Stroke(pill, { Color = Theme.StrokeDim, Transparency = 0.2 })
    local knob = Create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 2, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        BackgroundColor3 = Theme.TextDim,
        BorderSizePixel = 0,
        Parent = pill,
    })
    Corner(knob, UDim.new(1, 0))
    Stroke(knob, { Color = Theme.Background, Thickness = 1, Transparency = 0.4 })

    -- keterangan kecil di bawah judul
    local setDesc = attachDescription(card, 2)
    setDesc(cfg.Description)

    local state = { Value = cfg.Default == true, Callback = cfg.Callback }

    local function render(instant)
        local goalFill = state.Value and Theme.Accent or Theme.Track
        local goalKnobPos = state.Value and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
        local goalKnobColor = state.Value and Theme.White or Theme.TextDim
        local goalStrokeColor = state.Value and Theme.Accent or Theme.StrokeDim
        if instant then
            pill.BackgroundColor3 = goalFill
            knob.Position = goalKnobPos
            knob.BackgroundColor3 = goalKnobColor
            pillStroke.Color = goalStrokeColor
        else
            Tween(reg, pill, TI_SNAP, { BackgroundColor3 = goalFill })
            Tween(reg, knob, TI_STRIKE, { Position = goalKnobPos, BackgroundColor3 = goalKnobColor })
            Tween(reg, pillStroke, TI_SNAP, { Color = goalStrokeColor })
        end
    end

    render(true)
    cardHover(reg, card, stroke)

    -- v2.3.0: nilai berubah (apa pun sumbernya) → grup radio + pipeline
    -- State/Depends. Dipisah dari callback user supaya :Set silent pun
    -- tetap menyinkronkan tampilan & dependensi.
    local function afterChange()
        syncGroup(element)
        notifyChange(element)
    end

    reg:Connect(card.Activated, function()
        state.Value = not state.Value
        render(false)
        Zap(reg, pill, Theme.AccentGold, UDim.new(1, 0))
        if state.Callback then
            state.Callback(state.Value)
        end
        afterChange()
    end)

    local element = {
        Type = "Toggle",
        Name = cfg.Name,
        Instance = card,
        Registry = reg,
        SetDescription = function(_, t)
            setDesc(t)
        end,
        Get = function(_)
            return state.Value
        end,
        Set = function(_, value, silent)
            state.Value = value == true
            render(true)
            if silent ~= true and state.Callback then
                state.Callback(state.Value)
            end
            afterChange()
        end,
    }
    self:_track(element)
    -- v2.3.0: grup eksklusif (radio) — maksimal satu toggle aktif
    if type(cfg.Group) == "table" and cfg.Group.Options then
        element._group = cfg.Group
        table.insert(cfg.Group.Options, element)
        if state.Value then
            syncGroup(element)
        end
    end
    EnableChildren(self, element, cfg, row, titleLabel, "row")
    return element
end

--// ─────────────────────────── Elemen: SLIDER ───────────────────────────────
--  v2.3.0: UNITS multi-satuan + ketik nilai eksak + setter runtime.
--  Nilai internal (state.Value & callback) SELALU dalam satuan dasar;
--  tampilan dikonversi via FromBase/ToBase per satuan.
function TabClass:AddSlider(cfg)
    cfg = cfg or {}
    local reg = Registry.new()
    local card, stroke = self:_card()

    -- ── normalisasi konfigurasi UNITS ──
    --  Shorthand: Units = "m" · Units = { "m", "km" }
    --  Lengkap  : Units = { Options = { {Name="m", Suffix="m"},
    --      {Name="km", Suffix="km", FromBase=fn, ToBase=fn, Decimals=2} },
    --      Default = "km", Callback = fn(namaSatuan) }
    local unitOptions, unitCallback
    do
        local u = cfg.Units
        if type(u) == "string" then
            u = { Options = { u } }
        elseif type(u) == "table" and u.Options == nil and u.List == nil and #u > 0 then
            u = { Options = u }
        end
        if type(u) == "table" then
            unitCallback = type(u.Callback) == "function" and u.Callback or nil
            local rawList = u.Options or u.List
            unitOptions = {}
            if type(rawList) == "table" then
                for _, entry in ipairs(rawList) do
                    if type(entry) == "string" or type(entry) == "number" then
                        table.insert(unitOptions, {
                            Name = tostring(entry), Suffix = tostring(entry),
                        })
                    elseif type(entry) == "table" then
                        local name = tostring(entry.Name or entry.Text or entry.Suffix or "Unit")
                        table.insert(unitOptions, {
                            Name = name,
                            Suffix = entry.Suffix ~= nil and tostring(entry.Suffix) or name,
                            Prefix = entry.Prefix ~= nil and tostring(entry.Prefix) or nil,
                            Format = type(entry.Format) == "function" and entry.Format or nil,
                            FromBase = type(entry.FromBase) == "function" and entry.FromBase or nil,
                            ToBase = type(entry.ToBase) == "function" and entry.ToBase or nil,
                            Decimals = tonumber(entry.Decimals),
                        })
                    end
                end
            end
        end
    end
    local unitCount = unitOptions and #unitOptions or 0
    local currentUnit = nil
    if unitCount > 0 then
        local wanted = (type(cfg.Units) == "table" and cfg.Units.Default ~= nil)
            and tostring(cfg.Units.Default) or ""
        for _, uo in ipairs(unitOptions) do
            if uo.Name == wanted then
                currentUnit = uo
                break
            end
        end
        currentUnit = currentUnit or unitOptions[1]
    end
    local hasChip = unitCount > 1

    local row1 = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 18),
        LayoutOrder = 1,
        Parent = card,
    })
    local titleLabel = Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, hasChip and -130 or -90, 1, 0),
        Text = cfg.Name or "Slider",
        Font = Theme.FontMedium,
        TextSize = 13,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row1,
    })
    --  v2.3.0: nilai RichText — ANGKA emas, awalan/satuan redup kebiruan
    local valueLabel = Create("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, hasChip and -38 or 0, 0, 0),
        Size = UDim2.new(0, hasChip and 80 or 90, 1, 0),
        Text = "",
        RichText = true,
        Font = Theme.FontMedium,
        TextSize = 12,
        TextColor3 = Theme.AccentGold,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row1,
    })

    -- chip pemilih satuan (hanya bila ada >1 satuan)
    local unitChip, chipStroke
    if hasChip then
        unitChip = Create("TextButton", {
            Text = currentUnit.Name,
            AutoButtonColor = false,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(34, 16),
            BackgroundColor3 = Theme.Background,
            BorderSizePixel = 0,
            Font = Theme.FontMedium,
            TextSize = 10,
            TextColor3 = Theme.TextDim,
            Parent = row1,
        })
        Corner(unitChip, 4)
        chipStroke = Stroke(unitChip, { Color = Theme.StrokeDim, Transparency = 0.3 })
    end

    -- keterangan kecil di bawah judul
    local setDesc = attachDescription(card, 2)
    setDesc(cfg.Description)

    -- baris slider ditinggikan (28px) + hit-area transparan supaya nyaman
    -- disentuh jari — bukan cuma track 6px yang harus dibidik (mobile-friendly)
    local row2 = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 28),
        LayoutOrder = 3,
        Parent = card,
    })
    local track = Create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(1, 0, 0, 6),
        BackgroundColor3 = Theme.Track,
        BorderSizePixel = 0,
        Parent = row2,
    })
    Corner(track, UDim.new(1, 0))
    local fill = Create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.White, -- PUTIH: UIGradient menint -> gradien murni
        BorderSizePixel = 0,
        Parent = track,
    })
    Corner(fill, UDim.new(1, 0))
    -- gradien selaras-hue 'kilat menyala' (biru pekat -> biru terang)
    Gradient(fill, Color3.fromRGB(0, 170, 235), Color3.fromRGB(90, 220, 255), 90)
    local knob = Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = Theme.White,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = track,
    })
    Corner(knob, UDim.new(1, 0))
    Stroke(knob, { Color = Theme.AccentGold, Thickness = 1, Transparency = 0.1 })
    local knobScale = Create("UIScale", { Parent = knob })

    -- area sentuh transparan menutupi SELURUH baris slider (ZIndex di atas
    -- track & knob) — drag/ tap dari mana pun di baris tetap terbaca
    local hit = Create("TextButton", {
        Name = "SliderHit",
        Text = "",
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 3,
        Parent = row2,
    })

    local state = {
        Min = cfg.Min or 0,
        Max = cfg.Max or 100,
        Value = cfg.Default,
        Increment = cfg.Increment,
        Precision = cfg.Precision or (cfg.Increment and decimalsOf(cfg.Increment)) or 0,
        Suffix = cfg.Suffix or "",
        Callback = cfg.Callback,
    }
    if state.Min > state.Max then
        state.Min, state.Max = state.Max, state.Min
    end
    if state.Value == nil then
        state.Value = state.Min
    end

    local element -- didefinisi di bawah; apply/render merujuk via upvalue

    -- angka dalam SATUAN TAMPILAN saat ini (sudah dikonversi)
    local function displayNumber()
        local v = state.Value
        local u = currentUnit
        if u then
            if u.FromBase then
                v = u.FromBase(v)
            end
            if u.Format then
                return tostring(u.Format(v))
            end
            return formatValue(v, u.Decimals or state.Precision)
        end
        return formatValue(v, state.Precision)
    end

    local function render()
        local span = state.Max - state.Min
        local rel = span > 0 and (state.Value - state.Min) / span or 0
        rel = math.clamp(rel, 0, 1)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, 0, 0.5, 0)
        -- angka emas + satuan/awalan redup (RichText)
        local u = currentUnit
        local prefix = (u and u.Prefix) or cfg.Prefix or ""
        local suffix = (u and u.Suffix) or state.Suffix or ""
        local parts = {}
        if prefix ~= "" then
            parts[#parts + 1] = rtColor(Theme.TextDim, prefix)
        end
        parts[#parts + 1] = rtColor(Theme.AccentGold, displayNumber())
        if suffix ~= "" then
            parts[#parts + 1] = rtColor(Theme.TextDim, suffix)
        end
        valueLabel.Text = #parts > 1 and table.concat(parts, " ") or parts[1]
    end

    local function apply(raw, silent)
        local v = tonumber(raw)
        if v == nil then
            return
        end
        local inc = state.Increment
        if inc and inc > 0 then
            v = math.floor(v / inc + 0.5) * inc
        end
        v = math.clamp(v, state.Min, state.Max)
        state.Value = v
        render()
        if silent ~= true and state.Callback then
            state.Callback(state.Value)
        end
        notifyChange(element)
    end

    -- ── v2.3.0: ketik nilai eksak — klik angka → TextBox ──
    local editBox = Create("TextBox", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, hasChip and -38 or 0, 0, -1),
        Size = UDim2.new(0, hasChip and 80 or 90, 1, 2),
        BackgroundColor3 = Theme.BackgroundAlt,
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = "angka",
        TextSize = 12,
        TextColor3 = Theme.AccentGold,
        Font = Theme.FontMedium,
        TextXAlignment = Enum.TextXAlignment.Right,
        ClearTextOnFocus = false,
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 5,
        Parent = row1,
    })
    Corner(editBox, 4)
    local editStroke = Stroke(editBox, { Color = Theme.Accent, Transparency = 0 })
    reg:Connect(editBox.FocusLost, function()
        editBox.Visible = false
        valueLabel.Visible = true
        local n = tonumber(editBox.Text)
        if n then
            local u = currentUnit
            if u and u.ToBase then
                n = u.ToBase(n)
            end
            if math.abs(n - state.Value) > 1e-9 then
                apply(n, false)
            end
        end
    end)
    local valueHit = Create("TextButton", {
        Text = "",
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, hasChip and -38 or 0, 0, 0),
        Size = UDim2.new(0, hasChip and 80 or 90, 1, 0),
        ZIndex = 4,
        Parent = row1,
    })
    reg:Connect(valueHit.Activated, function()
        if editBox.Visible then
            return
        end
        editBox.Text = displayNumber()
        valueLabel.Visible = false
        editBox.Visible = true
        task.defer(function()
            if editBox.Visible and editBox.Parent then
                editBox:CaptureFocus()
            end
        end)
    end)

    -- ── v2.3.0: daftar pilihan satuan (di dalam kartu, ala dropdown) ──
    local unitHolder
    local unitExpanded = false
    local function setUnit(uo, silent)
        if uo == currentUnit then
            return
        end
        currentUnit = uo
        if unitChip then
            unitChip.Text = uo.Name
        end
        render()
        if silent ~= true and unitCallback then
            unitCallback(uo.Name)
        end
    end
    if hasChip then
        unitHolder = Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Visible = false,
            LayoutOrder = 4,
            Parent = card,
        })
        Create("UIListLayout", {
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = unitHolder,
        })
        for idx, uo in ipairs(unitOptions) do
            local ubtn = Create("TextButton", {
                Text = "",
                AutoButtonColor = false,
                BackgroundColor3 = Theme.Card,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 26),
                BorderSizePixel = 0,
                LayoutOrder = idx,
                Parent = unitHolder,
            })
            Corner(ubtn, 6)
            local udot = Create("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 8, 0.5, 0),
                Size = UDim2.fromOffset(6, 6),
                BackgroundColor3 = Theme.TextDim,
                BackgroundTransparency = 0.6,
                BorderSizePixel = 0,
                Parent = ubtn,
            })
            Corner(udot, UDim.new(1, 0))
            local ulabel = Create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 20, 0, 0),
                Size = UDim2.new(1, -24, 1, 0),
                Text = uo.Name,
                Font = Theme.FontMain,
                TextSize = 12,
                TextColor3 = Theme.TextDim,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = ubtn,
            })
            local function paintUnit()
                local sel = (uo == currentUnit)
                udot.BackgroundColor3 = sel and Theme.Accent or Theme.TextDim
                udot.BackgroundTransparency = sel and 0 or 0.6
                ulabel.TextColor3 = sel and Theme.Text or Theme.TextDim
            end
            paintUnit()
            reg:Connect(ubtn.MouseEnter, function()
                Tween(reg, ubtn, TI_HOVER, { BackgroundTransparency = 0.6, BackgroundColor3 = Theme.CardHover })
            end)
            reg:Connect(ubtn.MouseLeave, function()
                Tween(reg, ubtn, TI_HOVER, { BackgroundTransparency = 1, BackgroundColor3 = Theme.Card })
            end)
            reg:Connect(ubtn.Activated, function()
                setUnit(uo)
                paintUnit()
                unitExpanded = false
                unitHolder.Visible = false
                if chipStroke then
                    Tween(reg, chipStroke, TI_HOVER, { Color = Theme.StrokeDim, Transparency = 0.3 })
                end
                Zap(reg, ubtn, Theme.Accent, 6)
            end)
            -- repainting saat satuan berubah dari jalur lain
            uo._paint = paintUnit
        end
        reg:Connect(unitChip.Activated, function()
            unitExpanded = not unitExpanded
            unitHolder.Visible = unitExpanded
            for _, uo in ipairs(unitOptions) do
                if uo._paint then
                    uo._paint()
                end
            end
            Tween(reg, chipStroke, TI_HOVER, {
                Color = unitExpanded and Theme.Accent or Theme.StrokeDim,
                Transparency = unitExpanded and 0 or 0.3,
            })
            Zap(reg, unitChip, Theme.AccentGold, 4)
        end)
    end

    -- interaksi: mouse & sentuhan (UserInputService)
    local sliding = false
    local slideInput = nil

    local function updateFromX(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        apply(state.Min + rel * (state.Max - state.Min), false)
    end

    local function beginSlide(input)
        if sliding then
            return
        end
        sliding = true
        slideInput = input
        Tween(reg, knobScale, TI_HOVER, { Scale = 1.3 })
        Tween(reg, stroke, TI_HOVER, { Color = Theme.Stroke, Transparency = 0.05 })
        updateFromX(input.Position.X)
    end

    reg:Connect(hit.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            beginSlide(input)
        end
    end)
    reg:Connect(UserInputService.InputChanged, function(input)
        if sliding and gestureInput(slideInput, input) then
            updateFromX(input.Position.X)
        end
    end)
    reg:Connect(UserInputService.InputEnded, function(input)
        if sliding and gestureEnded(slideInput, input) then
            sliding = false
            slideInput = nil
            Tween(reg, knobScale, TI_HOVER, { Scale = 1 })
            Tween(reg, stroke, TI_HOVER, { Color = Theme.StrokeDim, Transparency = 0.35 })
        end
    end)

    apply(state.Value, true)

    element = {
        Type = "Slider",
        Name = cfg.Name,
        Instance = card,
        Registry = reg,
        SetDescription = function(_, t)
            setDesc(t)
        end,
        Get = function(_)
            return state.Value
        end,
        Set = function(_, value, silent)
            apply(tonumber(value) or state.Min, silent)
        end,
        -- ── v2.3.0: setter runtime ──
        SetDecimals = function(_, n)
            state.Precision = math.max(0, math.floor(tonumber(n) or 0))
            render()
        end,
        SetIncrement = function(_, n)
            state.Increment = tonumber(n)
        end,
        SetRange = function(_, mn, mx)
            state.Min = tonumber(mn) or state.Min
            state.Max = tonumber(mx) or state.Max
            if state.Min > state.Max then
                state.Min, state.Max = state.Max, state.Min
            end
            apply(state.Value, true)
        end,
        SetSuffix = function(_, s)
            state.Suffix = tostring(s or "")
            render()
        end,
        SetUnit = function(_, name)
            local wanted = tostring(name)
            for _, uo in ipairs(unitOptions or {}) do
                if uo.Name == wanted then
                    setUnit(uo)
                    if uo._paint then
                        uo._paint()
                    end
                    return
                end
            end
        end,
    }
    self:_track(element)
    EnableChildren(self, element, cfg, row1, titleLabel, "row")
    return element
end

--// ─────────────────────────── Elemen: DROPDOWN ─────────────────────────────
--  v2.3.0: Search (filter opsi), ApplyButton (mode aksi: pilih lalu terapkan),
--  SetValues/AddValue/RemoveValue (kelola opsi saat runtime).
function TabClass:AddDropdown(cfg)
    cfg = cfg or {}
    local reg = Registry.new()
    local card = self:_card()

    local multi = cfg.Multi == true
    local state = {
        Value = multi and {} or nil,
        Callback = cfg.Callback,
    }
    local element -- upvalue untuk pipeline notifyChange

    -- mode aksi: pilihan TIDAK langsung menembak callback; tombol "Apply"
    -- yang mengirimkannya (callback(nilai, indeks))
    local applyLabel = nil
    if cfg.ApplyButton then
        applyLabel = (cfg.ApplyButton == true) and "Apply"
            or tostring(cfg.ApplyButton)
    end
    local applyMode = applyLabel ~= nil

    -- header (klik untuk expand/collapse)
    local header = Create("TextButton", {
        Text = "",
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 20),
        LayoutOrder = 1,
        Parent = card,
    })
    local titleLabel = Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -150, 1, 0),
        Text = cfg.Name or "Dropdown",
        Font = Theme.FontMedium,
        TextSize = 13,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = header,
    })
    local selectLabel = Create("TextLabel", {
        BackgroundTransparency = 1, -- tanpa kotak abu di belakang nilai
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 0),
        Size = UDim2.new(0, 120, 1, 0),
        Text = "Pilih...",
        Font = Theme.FontMain,
        TextSize = 12,
        TextColor3 = Theme.AccentGold,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = header,
    })
    -- panah DIGAMBAR (2 batang miring) — glyph "▾" dirender Roblox sebagai
    -- KOTAK kosong (tofu) di sebagian perangkat (lihat ChevronIcon)
    local arrow, arrowA, arrowB = ChevronIcon(header, {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -1, 0.5, 0),
        Size = 10,
        Color = Theme.TextDim,
    })

    -- keterangan kecil di bawah judul
    local setDesc = attachDescription(card, 2)
    setDesc(cfg.Description)

    -- daftar opsi (card otomatis memanjang via AutomaticSize)
    local holder = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false,
        LayoutOrder = 3,
        Parent = card,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = holder,
    })

    -- ── v2.3.0: kotak pencarian opsional di atas daftar opsi ──
    local searchBox
    if cfg.Search == true then
        searchBox = Create("TextBox", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundColor3 = Theme.Background,
            BorderSizePixel = 0,
            Text = "",
            PlaceholderText = "Cari...",
            PlaceholderColor3 = Theme.TextDim,
            TextSize = 12,
            TextColor3 = Theme.Text,
            Font = Theme.FontMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            ClipsDescendants = true,
            LayoutOrder = 0,
            Parent = holder,
        })
        Corner(searchBox, 6)
        Create("UIPadding", {
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            Parent = searchBox,
        })
        Stroke(searchBox, { Color = Theme.StrokeDim, Transparency = 0.3 })
    end

    local options = {}
    local expanded = false
    local applyBtn

    local function updateHeader()
        if multi then
            local n = #state.Value
            if n == 0 then
                selectLabel.Text = "Pilih..."
            elseif n == 1 then
                selectLabel.Text = tostring(state.Value[1])
            else
                selectLabel.Text = tostring(n) .. " dipilih"
            end
        else
            selectLabel.Text = state.Value ~= nil and tostring(state.Value) or "Pilih..."
        end
    end

    local function refresh()
        for _, opt in ipairs(options) do
            local selected
            if multi then
                selected = contains(state.Value, opt.Value)
            else
                selected = (state.Value == opt.Value)
            end
            if selected then
                opt.Dot.BackgroundColor3 = Theme.Accent
                opt.Dot.BackgroundTransparency = 0
                opt.Label.TextColor3 = Theme.Text
            else
                opt.Dot.BackgroundColor3 = Theme.TextDim
                opt.Dot.BackgroundTransparency = 0.6
                opt.Label.TextColor3 = Theme.TextDim
            end
        end
    end

    --  v2.3.0: filter daftar opsi (dipakai search box & :Filter)
    local function filterOptions(query)
        local needle = tostring(query or ""):lower()
        for _, opt in ipairs(options) do
            if opt.Btn then
                if needle == "" then
                    opt.Btn.Visible = true
                else
                    opt.Btn.Visible = string.find(
                        tostring(opt.Value):lower(), needle, 1, true) ~= nil
                end
            end
        end
    end

    local function setExpanded(v)
        expanded = v
        holder.Visible = v
        local c = v and Theme.Accent or Theme.TextDim
        Tween(reg, arrowA, TI_HOVER, { BackgroundColor3 = c })
        Tween(reg, arrowB, TI_HOVER, { BackgroundColor3 = c })
    end

    --  v2.3.0: bangun ulang baris opsi (dipakai saat create & SetValues)
    local function buildOptions(values)
        -- bersihkan baris lama (kecuali search box LayoutOrder 0)
        for _, opt in ipairs(options) do
            if opt.Btn then
                opt.Btn:Destroy()
            end
        end
        options = {}
        if applyBtn then
            applyBtn:Destroy()
            applyBtn = nil
        end

        for _, value in ipairs(values or {}) do
            local opt = { Value = value }
            local btn = Create("TextButton", {
                Text = "",
                AutoButtonColor = false,
                BackgroundColor3 = Theme.Card,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 28), -- 28px: area sentuh nyaman di jari
                BorderSizePixel = 0,
                LayoutOrder = #options + 1,
                Parent = holder,
            })
            Corner(btn, 6)
            opt.Btn = btn
            opt.Dot = Create("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 8, 0.5, 0),
                Size = UDim2.fromOffset(6, 6),
                BackgroundColor3 = Theme.TextDim,
                BackgroundTransparency = 0.6,
                BorderSizePixel = 0,
                Parent = btn,
            })
            Corner(opt.Dot, UDim.new(1, 0))
            opt.Label = Create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 20, 0, 0),
                Size = UDim2.new(1, -24, 1, 0),
                Text = tostring(value),
                Font = Theme.FontMain,
                TextSize = 12,
                TextColor3 = Theme.TextDim,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = btn,
            })

            reg:Connect(btn.MouseEnter, function()
                Tween(reg, btn, TI_HOVER, { BackgroundTransparency = 0.6, BackgroundColor3 = Theme.CardHover })
            end)
            reg:Connect(btn.MouseLeave, function()
                Tween(reg, btn, TI_HOVER, { BackgroundTransparency = 1, BackgroundColor3 = Theme.Card })
            end)

            reg:Connect(btn.Activated, function()
                if multi then
                    if contains(state.Value, value) then
                        removeFrom(state.Value, value)
                    else
                        table.insert(state.Value, value)
                    end
                    refresh()
                    updateHeader()
                    Zap(reg, btn, Theme.Accent, 6)
                    if not applyMode then
                        if state.Callback then
                            local snapshot = {}
                            for i, v in ipairs(state.Value) do
                                snapshot[i] = v
                            end
                            state.Callback(snapshot)
                        end
                        notifyChange(element)
                    end
                else
                    state.Value = value
                    refresh()
                    updateHeader()
                    if not applyMode then
                        setExpanded(false)
                    end
                    Zap(reg, btn, Theme.Accent, 6)
                    if not applyMode then
                        if state.Callback then
                            state.Callback(state.Value)
                        end
                        notifyChange(element)
                    end
                end
            end)

            table.insert(options, opt)
        end

        -- tombol Apply (mode aksi) di ujung daftar
        if applyMode then
            applyBtn = Create("TextButton", {
                Text = "",
                AutoButtonColor = false,
                BackgroundColor3 = Theme.Card,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 28),
                BorderSizePixel = 0,
                LayoutOrder = #options + 1,
                Parent = holder,
            })
            Corner(applyBtn, 6)
            local applyStroke = Stroke(applyBtn, { Color = Theme.Accent, Transparency = 0.4 })
            Create("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Text = applyLabel,
                Font = Theme.FontBold,
                TextSize = 12,
                TextColor3 = Theme.Accent,
                Parent = applyBtn,
            })
            reg:Connect(applyBtn.MouseEnter, function()
                Tween(reg, applyBtn, TI_HOVER, { BackgroundTransparency = 0.5, BackgroundColor3 = Theme.CardHover })
                Tween(reg, applyStroke, TI_HOVER, { Transparency = 0 })
            end)
            reg:Connect(applyBtn.MouseLeave, function()
                Tween(reg, applyBtn, TI_HOVER, { BackgroundTransparency = 1, BackgroundColor3 = Theme.Card })
                Tween(reg, applyStroke, TI_HOVER, { Transparency = 0.4 })
            end)
            reg:Connect(applyBtn.Activated, function()
                Zap(reg, applyBtn, Theme.AccentGold, 6)
                setExpanded(false)
                if state.Callback then
                    if multi then
                        local snapshot, indices = {}, {}
                        for i, v in ipairs(state.Value) do
                            snapshot[i] = v
                        end
                        for i, opt in ipairs(options) do
                            if contains(state.Value, opt.Value) then
                                indices[#indices + 1] = i
                            end
                        end
                        state.Callback(snapshot, indices)
                    else
                        local idx = nil
                        for i, opt in ipairs(options) do
                            if state.Value == opt.Value then
                                idx = i
                                break
                            end
                        end
                        state.Callback(state.Value, idx)
                    end
                end
                notifyChange(element)
            end)
        end

        filterOptions(searchBox and searchBox.Text or "")
    end

    buildOptions(cfg.Values or {})

    if searchBox then
        reg:Connect(searchBox:GetPropertyChangedSignal("Text"), function()
            filterOptions(searchBox.Text)
        end)
    end

    reg:Connect(header.Activated, function()
        setExpanded(not expanded)
        Zap(reg, header, Theme.AccentGold, 6)
    end)

    -- nilai default
    if multi and type(cfg.Default) == "table" then
        for _, v in ipairs(cfg.Default) do
            table.insert(state.Value, v)
        end
    elseif not multi and cfg.Default ~= nil then
        state.Value = cfg.Default
    end
    refresh()
    updateHeader()

    element = {
        Type = "Dropdown",
        Name = cfg.Name,
        Instance = card,
        Registry = reg,
        SetDescription = function(_, t)
            setDesc(t)
        end,
        Get = function(_)
            if multi then
                local copy = {}
                for i, v in ipairs(state.Value) do
                    copy[i] = v
                end
                return copy
            end
            return state.Value
        end,
        Set = function(_, value, silent)
            if multi and type(value) == "table" then
                state.Value = {}
                for _, v in ipairs(value) do
                    table.insert(state.Value, v)
                end
            elseif not multi then
                state.Value = value
            end
            refresh()
            updateHeader()
            if silent ~= true and state.Callback then
                if multi then
                    local copy = {}
                    for i, v in ipairs(state.Value) do
                        copy[i] = v
                    end
                    state.Callback(copy)
                else
                    state.Callback(state.Value)
                end
            end
            notifyChange(element)
        end,
        -- ── v2.3.0: kelola opsi saat runtime ──
        SetValues = function(_, values)
            local valid = {}
            for _, v in ipairs(values or {}) do
                valid[#valid + 1] = v
            end
            buildOptions(valid)
            -- buang pilihan yang tidak lagi valid
            if multi then
                local kept = {}
                for _, v in ipairs(state.Value) do
                    if contains(valid, v) then
                        kept[#kept + 1] = v
                    end
                end
                state.Value = kept
            elseif state.Value ~= nil and not contains(valid, state.Value) then
                state.Value = nil
            end
            refresh()
            updateHeader()
        end,
        AddValue = function(_, value)
            for _, opt in ipairs(options) do
                if opt.Value == value then
                    return -- sudah ada
                end
            end
            local list = {}
            for _, opt in ipairs(options) do
                list[#list + 1] = opt.Value
            end
            list[#list + 1] = value
            buildOptions(list)
            refresh()
            updateHeader()
        end,
        RemoveValue = function(_, value)
            local list = {}
            for _, opt in ipairs(options) do
                if opt.Value ~= value then
                    list[#list + 1] = opt.Value
                end
            end
            buildOptions(list)
            if multi then
                removeFrom(state.Value, value)
            elseif state.Value == value then
                state.Value = nil
            end
            refresh()
            updateHeader()
        end,
        Filter = function(_, query)
            if searchBox then
                searchBox.Text = tostring(query or "")
            else
                filterOptions(query)
            end
        end,
    }
    self:_track(element)
    EnableChildren(self, element, cfg, header, titleLabel, "row")
    return element
end
--// ────────────────────────── Elemen: TEXTINPUT ─────────────────────────────
function TabClass:AddTextInput(cfg)
    cfg = cfg or {}
    local reg = Registry.new()
    local card = self:_card()

    local titleLabel = Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 16),
        Text = cfg.Name or "Input",
        Font = Theme.FontMedium,
        TextSize = 13,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,
        Parent = card,
    })

    -- keterangan kecil di bawah judul
    local setDesc = attachDescription(card, 2)
    setDesc(cfg.Description)

    local box = Create("TextBox", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Text = cfg.Text or "",
        PlaceholderText = cfg.Placeholder or "Ketik di sini...",
        PlaceholderColor3 = Theme.TextDim,
        TextSize = 12,
        TextColor3 = Theme.Text,
        Font = Theme.FontMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = cfg.ClearOnFocus == true,
        ClipsDescendants = true,
        LayoutOrder = 3,
        Parent = card,
    })
    Corner(box, 8)
    Create("UIPadding", {
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        Parent = box,
    })
    local boxStroke = Stroke(box, { Color = Theme.StrokeDim, Transparency = 0.3 })

    reg:Connect(box.Focused, function()
        Tween(reg, boxStroke, TI_HOVER, { Color = Theme.Accent, Transparency = 0 })
        Tween(reg, box, TI_HOVER, { BackgroundColor3 = Theme.BackgroundAlt })
    end)
    reg:Connect(box.FocusLost, function(enterPressed)
        Tween(reg, boxStroke, TI_HOVER, { Color = Theme.StrokeDim, Transparency = 0.3 })
        Tween(reg, box, TI_HOVER, { BackgroundColor3 = Theme.Background })
        if enterPressed then
            Zap(reg, box, Theme.Accent, 8)
        end
        if cfg.Callback then
            cfg.Callback(box.Text, enterPressed == true)
        end
        notifyChange(element)
    end)

    local element = {
        Type = "TextInput",
        Name = cfg.Name,
        Instance = card,
        Registry = reg,
        SetDescription = function(_, t)
            setDesc(t)
        end,
        Get = function(_)
            return box.Text
        end,
        Set = function(_, text)
            box.Text = tostring(text)
            notifyChange(element)
        end,
    }
    self:_track(element)
    EnableChildren(self, element, cfg, nil, titleLabel, "card", 8)
    return element
end

--// ─────────────────────────── Elemen: KEYBIND ──────────────────────────────
function TabClass:AddKeybind(cfg)
    cfg = cfg or {}
    local reg = Registry.new()
    local card, stroke = self:_card("TextButton")

    local row = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 20),
        LayoutOrder = 1,
        Parent = card,
    })
    local titleLabel = Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -140, 1, 0),
        Text = cfg.Name or "Keybind",
        Font = Theme.FontMedium,
        TextSize = 13,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })
    local bindLabel = Create("TextLabel", {
        BackgroundTransparency = 1, -- FIX v2.1.5: keybind juga tanpa kotak abu
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 135, 1, 0),
        Text = "...",
        Font = Theme.FontMedium,
        TextSize = 12,
        TextColor3 = Theme.TextDim,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })

    -- keterangan kecil di bawah judul
    local setDesc = attachDescription(card, 2)
    setDesc(cfg.Description)

    local state = {
        Bind = cfg.Default,
        Callback = cfg.Callback,
        Listening = false,
        LastCapture = 0,
    }

    local function display()
        if state.Listening then
            bindLabel.Text = "[ tekan tombol ]"
            bindLabel.TextColor3 = Theme.AccentGold
        elseif state.Bind then
            bindLabel.Text = state.Bind.Name
            bindLabel.TextColor3 = Theme.Accent
        else
            bindLabel.Text = "kosong"
            bindLabel.TextColor3 = Theme.TextDim
        end
    end

    reg:Connect(UserInputService.InputBegan, function(input, processed)
        if state.Listening then
            if processed then
                return
            end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                state.Bind = input.KeyCode
                state.Listening = false
                state.LastCapture = os.clock()
            elseif input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.MouseButton2 then
                state.Bind = input.UserInputType
                state.Listening = false
                state.LastCapture = os.clock()
            else
                return
            end
            display()
            notifyChange(element)
            return
        end
        -- mode normal: panggil callback saat tombol terikat ditekan
        if not state.Bind or processed then
            return
        end
        local matched
        if state.Bind.EnumType == Enum.KeyCode then
            matched = (input.KeyCode == state.Bind)
        else
            matched = (input.UserInputType == state.Bind)
        end
        if matched then
            Zap(reg, card, Theme.Accent, 10)
            if state.Callback then
                state.Callback(state.Bind, input)
            end
        end
    end)

    reg:Connect(card.Activated, function()
        -- jeda 0.4s agar klik penangkap mouse tidak langsung re-listen
        if os.clock() - state.LastCapture < 0.4 then
            return
        end
        state.Listening = not state.Listening
        display()
    end)

    cardHover(reg, card, stroke)
    display()

    local element = {
        Type = "Keybind",
        Name = cfg.Name,
        Instance = card,
        Registry = reg,
        SetDescription = function(_, t)
            setDesc(t)
        end,
        Get = function(_)
            return state.Bind
        end,
        Set = function(_, enumItem, silent)
            if typeof(enumItem) == "EnumItem" or typeof(enumItem) == "EnumItemType" then
                state.Bind = enumItem
                display()
                if silent ~= true and state.Callback then
                    state.Callback(state.Bind, nil)
                end
                notifyChange(element)
            end
        end,
        SetKey = function(_, enumItem)
            if typeof(enumItem) == "EnumItem" then
                state.Bind = enumItem
                display()
                notifyChange(element)
            end
        end,
    }
    self:_track(element)
    EnableChildren(self, element, cfg, row, titleLabel, "row")
    return element
end

--// ────────────────────────── Elemen: COLORPICKER (v2) ──────────────────────
--  Picker warna modern: kotak Saturasi-Value + slider Hue + HEX/RGB.
--  Semua elemen digambar murni script (UIGradient), tanpa aset gambar.
function TabClass:AddColorPicker(cfg)
    cfg = cfg or {}
    local reg = Registry.new()
    local card = self:_card()

    local state = {
        H = 0.55, S = 1, V = 1,
        Callback = cfg.Callback,
    }
    do
        local d = cfg.Default or Theme.Accent
        if typeof(d) == "Color3" then
            local h, s, v = Color3.toHSV(d)
            state.H, state.S, state.V = h, s, v
        end
    end

    -- ── header: nama + hex + swatch preview ──
    local header = Create("TextButton", {
        Text = "",
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 22),
        LayoutOrder = 1,
        Parent = card,
    })
    local titleLabel = Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -130, 1, 0),
        Text = cfg.Name or "Warna",
        Font = Theme.FontMedium,
        TextSize = 13,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = header,
    })
    local hexLabel = Create("TextLabel", {
        BackgroundTransparency = 1, -- FIX v2.1.5: hex code tanpa kotak abu
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -36, 0.5, 0),
        Size = UDim2.new(0, 76, 1, 0),
        Text = "#00C3FF",
        Font = Theme.FontMain,
        TextSize = 11,
        TextColor3 = Theme.AccentGold,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = header,
    })
    local swatch = Create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(24, 24),
        BorderSizePixel = 0,
        Parent = header,
    })
    Corner(swatch, 6)
    local swatchStroke = Stroke(swatch, { Color = Theme.White, Thickness = 1, Transparency = 0.45 })

    -- keterangan kecil di bawah judul
    local setDesc = attachDescription(card, 2)
    setDesc(cfg.Description)

    -- ── panel picker (expand/collapse seperti dropdown) ──
    local panel = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false,
        LayoutOrder = 3,
        Parent = card,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = panel,
    })

    -- kotak Saturation-Value
    local svBox = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 110),
        BackgroundColor3 = Color3.fromHSV(state.H, 1, 1),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true, -- FIX v2.1.1: serap sentuhan agar tidak ikut menggulir konten saat menggeser warna
        LayoutOrder = 1,
        Parent = panel,
    })
    Corner(svBox, 8)
    local svStroke = Stroke(svBox, { Color = Theme.StrokeDim, Transparency = 0.3 })

    -- gradient putih → transparan (kiri→kanan) = saturasi
    local whiteLayer = Create("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.White,
        BorderSizePixel = 0,
        Parent = svBox,
    })
    Create("UIGradient", {
        Color = ColorSequence.new(Theme.White, Theme.White),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Rotation = 0,
        Parent = whiteLayer,
    })
    -- gradient transparan → hitam (atas→bawah) = value
    local blackLayer = Create("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
        Parent = svBox,
    })
    Create("UIGradient", {
        Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.new(0, 0, 0)),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
        Rotation = 90,
        Parent = blackLayer,
    })
    local svCursor = Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(state.S, 0, 1 - state.V, 0),
        Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = Theme.White,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = svBox,
    })
    Corner(svCursor, UDim.new(1, 0))
    Stroke(svCursor, { Color = Theme.Background, Thickness = 2, Transparency = 0 })

    -- slider HUE (pelangi)
    local hueBar = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 14),
        BackgroundColor3 = Theme.White,
        BorderSizePixel = 0,
        Active = true, -- FIX v2.1.1: serap sentuhan (drag di mobile tidak menggulir konten)
        LayoutOrder = 2,
        Parent = panel,
    })
    Corner(hueBar, UDim.new(1, 0))
    Stroke(hueBar, { Color = Theme.Background, Thickness = 1, Transparency = 0.2 })
    Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
        }),
        Parent = hueBar,
    })
    local hueCursor = Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(state.H, 0, 0.5, 0),
        Size = UDim2.fromOffset(4, 18),
        BackgroundColor3 = Theme.White,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = hueBar,
    })
    Corner(hueCursor, UDim.new(1, 0))
    Stroke(hueCursor, { Color = Theme.Background, Thickness = 1, Transparency = 0 })

    -- baris info RGB
    local rgbLabel = Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 14),
        Text = "RGB 0, 195, 255",
        Font = Theme.FontMain,
        TextSize = 11,
        TextColor3 = Theme.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 3,
        Parent = panel,
    })

    local function currentColor()
        return Color3.fromHSV(state.H, state.S, state.V)
    end

    local function render()
        local color = currentColor()
        swatch.BackgroundColor3 = color
        hexLabel.Text = hexFromColor3(color)
        rgbLabel.Text = string.format("RGB %d, %d, %d",
            math.floor(color.R * 255 + 0.5),
            math.floor(color.G * 255 + 0.5),
            math.floor(color.B * 255 + 0.5))
        svBox.BackgroundColor3 = Color3.fromHSV(state.H, 1, 1)
        svCursor.Position = UDim2.new(state.S, 0, 1 - state.V, 0)
        hueCursor.Position = UDim2.new(state.H, 0, 0.5, 0)
    end

    -- interaksi drag (mouse & sentuhan) — pola sama seperti slider
    local svDragging = false
    local hueDragging = false
    local svInput = nil
    local hueInput = nil

    local function updateSV(x, y)
        local relX = math.clamp((x - svBox.AbsolutePosition.X) / math.max(svBox.AbsoluteSize.X, 1), 0, 1)
        local relY = math.clamp((y - svBox.AbsolutePosition.Y) / math.max(svBox.AbsoluteSize.Y, 1), 0, 1)
        state.S = relX
        state.V = 1 - relY
        render()
        if state.Callback then
            state.Callback(currentColor())
        end
        notifyChange(element)
    end

    local function updateHue(x)
        local rel = math.clamp((x - hueBar.AbsolutePosition.X) / math.max(hueBar.AbsoluteSize.X, 1), 0, 1)
        state.H = rel
        render()
        if state.Callback then
            state.Callback(currentColor())
        end
        notifyChange(element)
    end

    reg:Connect(svBox.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if svDragging or hueDragging then
                return
            end
            svDragging = true
            svInput = input
            Tween(reg, svStroke, TI_HOVER, { Color = Theme.Stroke, Transparency = 0 })
            updateSV(input.Position.X, input.Position.Y)
        end
    end)
    reg:Connect(hueBar.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if svDragging or hueDragging then
                return
            end
            hueDragging = true
            hueInput = input
            updateHue(input.Position.X)
        end
    end)
    reg:Connect(UserInputService.InputChanged, function(input)
        if svDragging and gestureInput(svInput, input) then
            updateSV(input.Position.X, input.Position.Y)
        elseif hueDragging and gestureInput(hueInput, input) then
            -- FIX v2.1.1: slider HUE kini mengikuti JARI juga — dulu filter
            -- hanya memeriksa svInput sehingga drag hue via sentuhan MATI total
            updateHue(input.Position.X)
        end
    end)
    reg:Connect(UserInputService.InputEnded, function(input)
        if svDragging and gestureEnded(svInput, input) then
            svDragging = false
            svInput = nil
            Tween(reg, svStroke, TI_HOVER, { Color = Theme.StrokeDim, Transparency = 0.3 })
            Zap(reg, swatch, Theme.AccentGold, 6)
        end
        if hueDragging and gestureEnded(hueInput, input) then
            hueDragging = false
            hueInput = nil
        end
    end)

    -- expand/collapse
    local expanded = false
    reg:Connect(header.Activated, function()
        expanded = not expanded
        panel.Visible = expanded
        Tween(reg, swatchStroke, TI_HOVER, {
            Color = expanded and Theme.Accent or Theme.White,
            Transparency = expanded and 0 or 0.45,
        })
        Zap(reg, header, Theme.AccentGold, 6)
    end)

    render()

    local element = {
        Type = "ColorPicker",
        Name = cfg.Name,
        Instance = card,
        Registry = reg,
        SetDescription = function(_, t)
            setDesc(t)
        end,
        Get = function(_)
            return currentColor()
        end,
        Set = function(_, color, silent)
            if typeof(color) == "Color3" then
                local h, s, v = Color3.toHSV(color)
                state.H, state.S, state.V = h, s, v
                render()
                if silent ~= true and state.Callback then
                    state.Callback(currentColor())
                end
                notifyChange(element)
            end
        end,
    }
    self:_track(element)
    EnableChildren(self, element, cfg, header, titleLabel, "row")
    return element
end

--// ─────────────────────────── Elemen: SECTION ──────────────────────────────
--  MENU BISA DI-MINIMIZE — klik judul section untuk menutup/membuka semua
--  fitur di dalamnya (sampai section berikutnya). Panah lipat DIGAMBAR
--  (bukan glyph — v2.2.2) berputar sebagai penanda. Elemen yang dibuat
--  SETELAH AddSection otomatis menjadi anggota menu tersebut (via
--  _own / _track).
--  v2.2.2: section MULAI TERLIPAT saat pertama execute (biar rapi) —
--  beri Collapsed = false untuk membuatnya dalam keadaan TERBUKA.
function TabClass:AddSection(cfg)
    cfg = cfg or {}
    local reg = Registry.new()
    local holder = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = self:_nextOrder(),
        Parent = self.Container,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = holder,
    })

    -- baris judul = TextButton — area ketuk selarik judul, nyaman di mobile
    local row = Create("TextButton", {
        Name = "SectionHeader",
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 20),
        Text = "",
        LayoutOrder = 1,
        Parent = holder,
    })
    local title = Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, -18, 1, 0),
        Text = cfg.Name or "Section",
        Font = Theme.FontBold,
        TextSize = 12,
        TextColor3 = Theme.AccentGold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })
    -- v2.2.2: panah penanda lipatan DIGAMBAR (2 batang miring emas) —
    -- glyph "▾" tampil sebagai KOTAK kosong (tofu) di sebagian perangkat.
    -- Rotasi ikon: 0 = panah bawah (terbuka) ↔ -90 = panah kanan (terlipat)
    local chevron, chevA, chevB = ChevronIcon(row, {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -3, 0.5, 0),
        Size = 12,
        Color = Theme.AccentGold,
    })

    -- keterangan kecil di bawah judul section
    local setDesc = attachDescription(holder, 2)
    setDesc(cfg.Description)
    local line = Create("Frame", {
        BackgroundColor3 = Theme.White, -- PUTIH: gradien emas->biru murni
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1),
        LayoutOrder = 3,
        Parent = holder,
    })
    Gradient(line, Theme.AccentGold, Theme.Accent, 0, NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 0.85),
    }))

    local el = {
        Type = "Section",
        Name = cfg.Name,
        Instance = holder,
        Registry = reg,
        Members = {}, -- elemen yang dibuat setelah section ini
        Collapsed = true, -- v2.2.2: TERLIPAT adalah default awal
    }

    -- Terapkan lipatan: sembunyikan/tampilkan semua anggota dalam SATU pass
    -- (tanpa tween per elemen — hemat performa). Daftar anggota yang sudah
    -- di-Remove dibersihkan otomatis saat lewat.
    local function applyVisibility()
        local members = el.Members
        for i = #members, 1, -1 do
            local m = members[i]
            if not m.Instance or not m.Instance.Parent then
                table.remove(members, i) -- anggota sudah dihancurkan
            else
                m.Instance.Visible = not el.Collapsed
                    and m._depVisible ~= false -- v2.3.0: hormati Depends
            end
        end
    end

    function el:SetCollapsed(collapsed)
        collapsed = collapsed == true
        if el.Collapsed == collapsed then
            return
        end
        el.Collapsed = collapsed
        Tween(reg, chevron, TI_HOVER, { Rotation = collapsed and -90 or 0 })
        applyVisibility()
    end

    function el:Toggle()
        self:SetCollapsed(not el.Collapsed)
    end

    function el:IsCollapsed()
        return el.Collapsed
    end

    el.SetDescription = function(_, text)
        setDesc(text)
    end

    reg:Connect(row.Activated, function()
        el:Toggle()
    end)

    -- hover hemat: hanya di perangkat bermouse (mobile tak buat tween percuma)
    if HOVER_FOR_MOUSE then
        reg:Connect(row.MouseEnter, function()
            Tween(reg, title, TI_HOVER, { TextColor3 = Theme.Text })
            Tween(reg, chevA, TI_HOVER, { BackgroundColor3 = Theme.Text })
            Tween(reg, chevB, TI_HOVER, { BackgroundColor3 = Theme.Text })
        end)
        reg:Connect(row.MouseLeave, function()
            Tween(reg, title, TI_HOVER, { TextColor3 = Theme.AccentGold })
            Tween(reg, chevA, TI_HOVER, { BackgroundColor3 = Theme.AccentGold })
            Tween(reg, chevB, TI_HOVER, { BackgroundColor3 = Theme.AccentGold })
        end)
    end

    function el:Remove()
        -- anggota dikembalikan terlihat & lepas dari menu ini
        el.Collapsed = false
        applyVisibility()
        for _, m in ipairs(el.Members) do
            m.Section = nil
        end
        el.Members = {}
        reg:Clean()
        if self.Instance and self.Instance.Parent then
            self.Instance:Destroy()
        end
    end

    -- section baru = menu aktif: elemen SELANJUTNYA jadi anggotanya
    self._currentSection = el
    table.insert(self.Sections, el)

    -- v2.2.2: SEMUA section MULAI TERLIPAT saat pertama execute (permintaan:
    -- "semua section di tutup biar rapi"). cfg.Collapsed = false → menu
    -- dibuat dalam keadaan TERBUKA; anggota yang dibuat kemudian tetap
    -- terdaftar ke menu ini dan mengikuti status lipatnya.
    if cfg.Collapsed == false then
        el.Collapsed = false
    else
        el.Collapsed = true
        chevron.Rotation = -90
    end

    return el
end

--// ─────────────────────────── Elemen: LABEL ────────────────────────────────
function TabClass:AddLabel(cfg)
    cfg = cfg or {}
    local lbl = Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 14),
        -- FIX v2.1.2: tinggi eksplisit terukur (autoFitText) — bukan
        -- AutomaticSize.Y yang bisa memesan tinggi kurang dari teks →
        -- elemen berikutnya menimpa teks Label
        Text = cfg.Text or cfg.Name or "Label",
        Font = Theme.FontMain,
        TextSize = 12,
        TextColor3 = Theme.TextDim,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = self:_nextOrder(),
        Parent = self.Container,
    })
    autoFitText(lbl, 0)
    local el = { Type = "Label", Instance = lbl }
    el.SetText = function(text) -- dipanggil: el.SetText("teks baru")
        lbl.Text = tostring(text)
    end
    function el:Remove()
        if self.Instance and self.Instance.Parent then
            self.Instance:Destroy()
        end
    end
    -- v2.2.1: label ikut menjadi anggota menu (section) aktif → bisa
    -- di-minimize bersama fitur lain di menu yang sama
    self:_own(el)
    return el
end

--// ────────────────────────── Elemen: PARAGRAPH ─────────────────────────────
function TabClass:AddParagraph(cfg)
    cfg = cfg or {}
    local holder = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = self:_nextOrder(),
        Parent = self.Container,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = holder,
    })
    Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 14),
        Text = cfg.Title or "Paragraph",
        Font = Theme.FontBold,
        TextSize = 12,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,
        Parent = holder,
    })
    local body = Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 14),
        -- FIX v2.1.2: tinggi eksplisit terukur (autoFitText) — bukan
        -- AutomaticSize.Y (dapat memesan tinggi kurang dari teks →
        -- teks paragraph tumpah keluar kartu / tertimpa elemen bawahnya)
        Text = cfg.Text or "",
        Font = Theme.FontMain,
        TextSize = 12,
        TextColor3 = Theme.TextDim,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        LayoutOrder = 2,
        Parent = holder,
    })
    autoFitText(body, 0)
    local el = { Type = "Paragraph", Instance = holder }
    el.SetText = function(text) -- dipanggil: el.SetText("teks baru")
        body.Text = tostring(text)
    end
    function el:Remove()
        if self.Instance and self.Instance.Parent then
            self.Instance:Destroy()
        end
    end
    -- v2.2.1: paragraph ikut menjadi anggota menu (section) aktif
    self:_own(el)
    return el
end

--// ──────────────────── Elemen: LIST (v2.3.0 — browser item) ────────────────
--  Daftar item yang bisa DILACAK (Search), DIKELOMPOKKAN (Groups), dan
--  DIPILIH (klik / Multi). Setiap item boleh punya badge kanan (TopRight),
--  gambar sendiri (Image, rbxassetid milik pengguna — opsional), dan Id.
--      Tab:AddList({ Name = "Inventaris", Search = true, Multi = false,
--          Items = { "Stormbreaker",
--              { Text = "Mjolnir", TopRight = "Legendary" } },
--          OnItemClick = function(item, index, selected) end })
function TabClass:AddList(cfg)
    cfg = cfg or {}
    local reg = Registry.new()
    local card = self:_card()
    local element -- upvalue untuk notifyChange

    local multi = cfg.Multi == true
    local selected = {} -- array item (normalisasi) yang terpilih
    local itemRows = {} -- { {Item, Btn, Dot, Label, Badge, GroupFrame} }
    local maxH = tonumber(cfg.MaxHeight) or 180

    -- ── normalisasi item ──
    local function normalizeItem(item)
        if type(item) == "table" then
            return {
                Text = tostring(item.Text or item.Name or ""),
                TopRight = item.TopRight ~= nil and tostring(item.TopRight) or nil,
                Image = item.Image ~= nil and tostring(item.Image) or nil,
                ImageColor = typeof(item.ImageColor) == "Color3" and item.ImageColor or nil,
                Id = item.Id,
            }
        end
        return { Text = tostring(item) }
    end

    local function itemMatchesSel(it, sel)
        if it == sel then
            return true
        end
        if type(sel) == "table" then
            if sel.Id ~= nil then
                return it.Id == sel.Id
            end
            return it.Text == tostring(sel.Text or sel)
        end
        return it.Text == tostring(sel)
    end

    local function isSelected(it)
        for _, s in ipairs(selected) do
            if itemMatchesSel(it, s) then
                return true
            end
        end
        return false
    end

    -- ── baris judul ──
    local titleRow = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 20),
        LayoutOrder = 1,
        Parent = card,
    })
    local titleLabel = Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -90, 1, 0),
        Text = cfg.Name or "List",
        Font = Theme.FontMedium,
        TextSize = 13,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = titleRow,
    })
    local countLabel = Create("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 90, 1, 0),
        Text = "",
        Font = Theme.FontMain,
        TextSize = 11,
        TextColor3 = Theme.TextDim,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = titleRow,
    })

    local setDesc = attachDescription(card, 2)
    setDesc(cfg.Description)

    -- ── kotak pencarian (opsional) ──
    local searchBox
    if cfg.Search == true then
        searchBox = Create("TextBox", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundColor3 = Theme.Background,
            BorderSizePixel = 0,
            Text = "",
            PlaceholderText = "Cari...",
            PlaceholderColor3 = Theme.TextDim,
            TextSize = 12,
            TextColor3 = Theme.Text,
            Font = Theme.FontMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            ClipsDescendants = true,
            LayoutOrder = 3,
            Parent = card,
        })
        Corner(searchBox, 6)
        Create("UIPadding", {
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            Parent = searchBox,
        })
        Stroke(searchBox, { Color = Theme.StrokeDim, Transparency = 0.3 })
    end

    -- ── scroll daftar item ──
    local scroll = Create("ScrollingFrame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.Accent,
        ScrollBarImageTransparency = 0.4,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        BorderSizePixel = 0,
        LayoutOrder = 5,
        Parent = card,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 3),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = scroll,
    })
    -- tinggi scroll mengikuti konten (maks maxH) — card ikut memanjang
    reg:Connect(scroll:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        local lay = scroll:FindFirstChildOfClass("UIListLayout")
        local h = lay and lay.AbsoluteContentSize.Y or 0
        scroll.Size = UDim2.new(1, 0, 0, math.clamp(h, 0, maxH))
    end)

    local function updateCount()
        local total = 0
        for _, r in ipairs(itemRows) do
            if not r.IsHeader then
                total = total + 1
            end
        end
        if multi then
            countLabel.Text = #selected .. "/" .. total
        else
            countLabel.Text = (#selected > 0 and selected[1].Text or "...")
        end
    end

    local function paintRow(r)
        -- FIX v2.3.0: baris judul GRUP tidak punya Item — jangan dinilai
        if r.IsHeader or r.Item == nil then
            return
        end
        local sel = isSelected(r.Item)
        if r.Dot then
            r.Dot.BackgroundColor3 = sel and Theme.Accent or Theme.TextDim
            r.Dot.BackgroundTransparency = sel and 0 or 0.6
        end
        if r.Label then
            r.Label.TextColor3 = sel and Theme.Text or Theme.TextDim
        end
        if r.Btn then
            if sel then
                r.Btn.BackgroundColor3 = Theme.CardHover
                r.Btn.BackgroundTransparency = 0.35
            else
                r.Btn.BackgroundColor3 = Theme.Card
                r.Btn.BackgroundTransparency = 1
            end
        end
    end

    local function repaint()
        for _, r in ipairs(itemRows) do
            paintRow(r)
        end
    end

    --  Filter tampilan (dipakai search box & :Filter) — group tanpa anak
    --  yang cocok ikut disembunyikan.
    local function applyFilter(query)
        local needle = tostring(query or ""):lower()
        local groupVisible = {}
        for _, r in ipairs(itemRows) do
            if r.IsHeader then
                r.Btn.Visible = needle == ""
                groupVisible[r.Btn] = false
            else
                local match = needle == ""
                    or string.find(r.Item.Text:lower(), needle, 1, true) ~= nil
                r.Btn.Visible = match
                if match and r.GroupFrame then
                    groupVisible[r.GroupFrame] = true
                end
            end
        end
        for btn, vis in pairs(groupVisible) do
            if needle ~= "" then
                btn.Visible = vis
            end
        end
    end

    local function onItemClick(r)
        local it = r.Item
        if multi then
            -- keluarkan bila sudah terpilih, masukkan bila belum
            for i, s in ipairs(selected) do
                if itemMatchesSel(it, s) then
                    table.remove(selected, i)
                    repaint()
                    updateCount()
                    Zap(reg, r.Btn, Theme.Accent, 6)
                    if cfg.OnItemClick then
                        cfg.OnItemClick(it, r.Index, false)
                    end
                    notifyChange(element)
                    return
                end
            end
            table.insert(selected, it)
        else
            selected = { it }
        end
        repaint()
        updateCount()
        Zap(reg, r.Btn, Theme.Accent, 6)
        if cfg.OnItemClick then
            cfg.OnItemClick(it, r.Index, true)
        end
        notifyChange(element)
    end

    --  Bangun ulang seluruh daftar (dipakai saat create & :SetItems)
    local function buildAll(items, groups)
        for _, r in ipairs(itemRows) do
            if r.Btn then
                r.Btn:Destroy()
            end
        end
        itemRows = {}
        selected = {}
        local order = 0
        local index = 0

        local function addHeader(text)
            order = order + 1
            local h = Create("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 18),
                Text = tostring(text or ""),
                Font = Theme.FontBold,
                TextSize = 11,
                TextColor3 = Theme.AccentGold,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                LayoutOrder = order,
                Parent = scroll,
            })
            itemRows[#itemRows + 1] = { IsHeader = true, Btn = h }
        end

        local function addItem(it)
            order = order + 1
            index = index + 1
            local btn = Create("TextButton", {
                Text = "",
                AutoButtonColor = false,
                BackgroundColor3 = Theme.Card,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 28),
                BorderSizePixel = 0,
                LayoutOrder = order,
                Parent = scroll,
            })
            Corner(btn, 6)
            local xOff = 8
            local dot = Create("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 8, 0.5, 0),
                Size = UDim2.fromOffset(6, 6),
                BackgroundColor3 = Theme.TextDim,
                BackgroundTransparency = 0.6,
                BorderSizePixel = 0,
                Parent = btn,
            })
            Corner(dot, UDim.new(1, 0))
            xOff = 20
            -- gambar opsional milik pengguna (rbxassetid) — ThorUi sendiri
            -- tetap 100% tanpa aset
            if it.Image then
                local img = Create("ImageLabel", {
                    AnchorPoint = Vector2.new(0, 0.5),
                    Position = UDim2.new(0, xOff, 0.5, 0),
                    Size = UDim2.fromOffset(18, 18),
                    BackgroundTransparency = 1,
                    Image = it.Image,
                    ImageColor3 = it.ImageColor or Theme.Text,
                    Parent = btn,
                })
                Corner(img, 4)
                xOff = xOff + 24
            end
            local label = Create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, xOff, 0, 0),
                Size = UDim2.new(1, -xOff - (it.TopRight and 64 or 0), 1, 0),
                Text = it.Text,
                Font = Theme.FontMain,
                TextSize = 12,
                TextColor3 = Theme.TextDim,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = btn,
            })
            if it.TopRight then
                Create("TextLabel", {
                    BackgroundTransparency = 1,
                    AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.new(1, -8, 0, 0),
                    Size = UDim2.new(0, 60, 1, 0),
                    Text = it.TopRight,
                    Font = Theme.FontBold,
                    TextSize = 10,
                    TextColor3 = Theme.AccentGold,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Parent = btn,
                })
            end
            reg:Connect(btn.MouseEnter, function()
                Tween(reg, btn, TI_HOVER, { BackgroundTransparency = 0.5, BackgroundColor3 = Theme.CardHover })
            end)
            reg:Connect(btn.MouseLeave, function()
                paintRow({ Item = it, Btn = btn, Dot = dot, Label = label })
            end)
            reg:Connect(btn.Activated, function()
                onItemClick({ Item = it, Btn = btn, Dot = dot, Label = label, Index = index })
            end)
            itemRows[#itemRows + 1] = { Item = it, Btn = btn, Dot = dot, Label = label, Index = index }
        end

        if type(groups) == "table" then
            for _, g in ipairs(groups) do
                if type(g) == "table" then
                    addHeader(g.Title or g.Name or "")
                    local groupBtn = itemRows[#itemRows].Btn
                    for _, raw in ipairs(g.Items or {}) do
                        addItem(normalizeItem(raw))
                        itemRows[#itemRows].GroupFrame = groupBtn
                    end
                end
            end
        else
            for _, raw in ipairs(items or {}) do
                addItem(normalizeItem(raw))
            end
        end

        -- terapkan pilihan awal (Selected)
        if cfg.Selected ~= nil then
            local function markSel(sel)
                for _, r in ipairs(itemRows) do
                    if not r.IsHeader and itemMatchesSel(r.Item, sel) then
                        if multi then
                            local already = false
                            for _, s in ipairs(selected) do
                                if itemMatchesSel(r.Item, s) then
                                    already = true
                                end
                            end
                            if not already then
                                table.insert(selected, r.Item)
                            end
                        else
                            selected = { r.Item }
                        end
                    end
                end
            end
            if multi and type(cfg.Selected) == "table" then
                for _, s in ipairs(cfg.Selected) do
                    markSel(s)
                end
            else
                markSel(cfg.Selected)
            end
        end

        repaint()
        updateCount()
        if searchBox then
            applyFilter(searchBox.Text)
        end
    end

    buildAll(cfg.Items, cfg.Groups)

    if searchBox then
        reg:Connect(searchBox:GetPropertyChangedSignal("Text"), function()
            applyFilter(searchBox.Text)
        end)
    end

    element = {
        Type = "List",
        Name = cfg.Name,
        Instance = card,
        Registry = reg,
        SetDescription = function(_, t)
            setDesc(t)
        end,
        Get = function(_)
            if multi then
                local copy = {}
                for i, s in ipairs(selected) do
                    copy[i] = s
                end
                return copy
            end
            return selected[1]
        end,
        Set = function(_, sel, silent)
            selected = {}
            local function mark(selOne)
                for _, r in ipairs(itemRows) do
                    if not r.IsHeader and itemMatchesSel(r.Item, selOne) then
                        if multi then
                            selected[#selected + 1] = r.Item
                        else
                            selected = { r.Item }
                        end
                    end
                end
            end
            if multi and type(sel) == "table" then
                for _, s in ipairs(sel) do
                    mark(s)
                end
            elseif sel ~= nil then
                mark(sel)
            end
            repaint()
            updateCount()
            if silent ~= true and cfg.OnItemClick then
                cfg.OnItemClick(element.Get and element:Get(), nil, true)
            end
            notifyChange(element)
        end,
        SetItems = function(_, items, groups)
            buildAll(items, groups)
            notifyChange(element)
        end,
        Clear = function(_)
            selected = {}
            repaint()
            updateCount()
        end,
        Filter = function(_, query)
            if searchBox then
                searchBox.Text = tostring(query or "")
            else
                applyFilter(query)
            end
        end,
    }
    self:_track(element)
    EnableChildren(self, element, cfg, titleRow, titleLabel, "row")
    return element
end

--// ─────────────── Elemen: MODELVIEW (v2.3.0 — etalase 3D) ──────────────────
--  ViewportFrame untuk memajangkan Model/Part 3D langsung di dalam UI.
--  Kamera otomatis membingkai objek + opsi putar (Spin). Tanpa model yang
--  diberikan, etalase menampilkan palu petir geometris BAWAAN (murni Part —
--  tetap nol aset gambar).
--      Tab:AddModelView({ Name = "Palu", Model = someModel, Spin = true })
function TabClass:AddModelView(cfg)
    cfg = cfg or {}
    local reg = Registry.new()
    local card = self:_card()

    local height = math.clamp(tonumber(cfg.Height) or 150, 90, 400)
    local spinEnabled = cfg.Spin ~= false

    local titleRow = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 18),
        LayoutOrder = 1,
        Parent = card,
    })
    local titleLabel = Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -90, 1, 0),
        Text = cfg.Name or "Model",
        Font = Theme.FontMedium,
        TextSize = 13,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = titleRow,
    })
    local spinBtn = Create("TextButton", {
        Text = "",
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(64, 16),
        Font = Theme.FontBold,
        TextSize = 10,
        TextColor3 = Theme.TextDim,
        Text = spinEnabled and "SPIN ON" or "SPIN OFF",
        Parent = titleRow,
    })

    local setDesc = attachDescription(card, 2)
    setDesc(cfg.Description)

    local vp = Create("ViewportFrame", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = Theme.BackgroundAlt,
        BorderSizePixel = 0,
        LayoutOrder = 3,
        Ambient = Color3.fromRGB(70, 78, 100),
        LightColor = Color3.fromRGB(255, 240, 200),
        LightDirection = Vector3.new(-0.6, -1, -0.8),
        Parent = card,
    })
    Corner(vp, 8)
    Stroke(vp, { Color = Theme.StrokeDim, Transparency = 0.35 })
    local camera = Instance.new("Camera")
    camera.FieldOfView = 45
    camera.Parent = vp
    vp.CurrentCamera = camera

    --  Bersihkan klon dari efek/scripts/suara; jangkar semua part.
    local function cleanClone(inst)
        local ok, copy = pcall(function()
            return inst:Clone()
        end)
        if not ok or not copy then
            return nil
        end
        for _, d in ipairs(copy:GetDescendants()) do
            if d:IsA("LuaSourceContainer")
                or d:IsA("ParticleEmitter")
                or d:IsA("Trail")
                or d:IsA("Beam")
                or d:IsA("Light")
                or d:IsA("Sound")
                or d:IsA("Fire")
                or d:IsA("Smoke")
                or d:IsA("Sparkles") then
                d:Destroy()
            elseif d:IsA("BasePart") then
                d.Anchored = true
                d.CanCollide = false
                d.CastShadow = false
            end
        end
        if copy:IsA("BasePart") then
            copy.Anchored = true
            copy.CanCollide = false
            copy.CastShadow = false
        end
        return copy
    end

    --  Bingkai kamera agar objek selalu pas di tengah viewport.
    local function frameCamera(shown)
        local size
        local center
        if shown:IsA("Model") then
            local cf, sz = nil, nil
            local ok = pcall(function()
                cf, sz = shown:GetBoundingBox()
            end)
            if ok and cf then
                center, size = cf.Position, sz
            end
        end
        if not center then
            -- Part tunggal / fallback: pakai ukuran & posisi langsung
            size = shown:IsA("BasePart") and shown.Size or Vector3.new(4, 4, 4)
            center = shown:IsA("BasePart") and shown.Position or Vector3.zero
        end
        local dist = math.max(size.X, size.Y, size.Z) * 2.1 + 2
        camera.CFrame = CFrame.lookAt(
            center + Vector3.new(0, size.Y * 0.3, dist),
            center
        )
    end

    local currentModel = nil

    local function setModel(inst)
        for _, child in ipairs(vp:GetChildren()) do
            if child ~= camera then
                child:Destroy()
            end
        end
        if typeof(inst) ~= "Instance" then
            currentModel = nil
            return
        end
        local shown = inst
        if not inst:IsDescendantOf(vp) then
            shown = cleanClone(inst) or inst
        end
        shown.Parent = vp
        currentModel = shown
        frameCamera(shown)
    end

    -- ── palu petir geometris bawaan (nol aset — murni Part box);
    --    v2.3.1: warna SENADA LOGO THORHUB — kepala emas + gagang biru ──
    local function buildDefaultMjolnir()
        local m = Instance.new("Model")
        m.Name = "Mjolnir"
        local function part(size, color, material, pos)
            local p = Instance.new("Part")
            p.Size = size
            p.Color = color
            p.Material = material
            p.Anchored = true
            p.CanCollide = false
            p.CastShadow = false
            p.CFrame = CFrame.new(pos)
            p.Parent = m
            return p
        end
        local gold      = Color3.fromRGB(251, 191, 36)  -- kepala (persis logo)
        local goldDeep  = Color3.fromRGB(180, 83, 9)    -- plat pengikat kepala
        local blue      = Color3.fromRGB(37, 99, 235)   -- gagang (persis logo)
        local blueLight = Color3.fromRGB(147, 197, 253) -- balutan gagang
        -- kepala palu emas
        part(Vector3.new(0.9, 1.5, 1.5), gold, Enum.Material.Metal, Vector3.new(0, 2.55, 0))
        part(Vector3.new(0.5, 1.62, 1.62), gold, Enum.Material.Metal, Vector3.new(0, 2.55, 0))
        -- plat emas tua pengikat atas & bawah kepala
        part(Vector3.new(0.96, 0.18, 1.56), goldDeep, Enum.Material.Metal, Vector3.new(0, 3.22, 0))
        part(Vector3.new(0.96, 0.18, 1.56), goldDeep, Enum.Material.Metal, Vector3.new(0, 1.88, 0))
        -- gagang biru + balutan biru muda
        part(Vector3.new(0.42, 1.9, 0.42), blue, Enum.Material.Metal, Vector3.new(0, 1.0, 0))
        part(Vector3.new(0.5, 0.14, 0.5), blueLight, Enum.Material.Metal, Vector3.new(0, 1.85, 0))
        part(Vector3.new(0.5, 0.14, 0.5), blueLight, Enum.Material.Metal, Vector3.new(0, 0.28, 0))
        -- pommel emas
        part(Vector3.new(0.56, 0.3, 0.56), gold, Enum.Material.Metal, Vector3.new(0, 0.06, 0))
        return m
    end

    setModel(cfg.Model or buildDefaultMjolnir())

    -- rotasi halus (bisa dimatikan)
    local spinConn
    local function startSpin()
        if spinConn then
            return
        end
        spinConn = reg:Connect(RunService.Heartbeat, function(dt)
            if currentModel then
                currentModel:PivotTo(
                    currentModel:GetPivot() * CFrame.Angles(0, math.rad(42 * dt), 0)
                )
            end
        end)
    end
    local function stopSpin()
        if spinConn then
            spinConn:Disconnect()
            reg:Disconnect(spinConn)
            spinConn = nil
        end
    end

    reg:Connect(spinBtn.Activated, function()
        spinEnabled = not spinEnabled
        spinBtn.Text = spinEnabled and "SPIN ON" or "SPIN OFF"
        spinBtn.TextColor3 = spinEnabled and Theme.Accent or Theme.TextDim
        if spinEnabled then
            startSpin()
        else
            stopSpin()
        end
        Zap(reg, spinBtn, Theme.AccentGold, 4)
    end)
    if spinEnabled then
        spinBtn.TextColor3 = Theme.Accent
        startSpin()
    end

    local element = {
        Type = "ModelView",
        Name = cfg.Name,
        Instance = card,
        Registry = reg,
        SetDescription = function(_, t)
            setDesc(t)
        end,
        Get = function(_)
            return currentModel
        end,
        Set = function(_, inst)
            setModel(inst)
        end,
        SetModel = function(_, inst)
            setModel(inst)
        end,
        SetSpin = function(_, on)
            spinEnabled = on == true
            spinBtn.Text = spinEnabled and "SPIN ON" or "SPIN OFF"
            spinBtn.TextColor3 = spinEnabled and Theme.Accent or Theme.TextDim
            if spinEnabled then
                startSpin()
            else
                stopSpin()
            end
        end,
    }
    self:_track(element)
    EnableChildren(self, element, cfg, titleRow, titleLabel, "row")
    return element
end

--// ─────────────── Elemen: CANVAS (v2.3.0 — dashboard deklaratif) ───────────
--  Widget mini-dashboard yang dideklarasikan lewat tabel — baris teks
--  (label + nilai), bar progress, tombol, dan pemisah — semuanya bisa
--  diperbarui saat runtime lewat :Set(nama, props).
--      local dash = Tab:AddCanvas({ Name = "Statistik", Widgets = {
--          { Type = "Text", Name = "kills", Text = "Kills", Value = "0" },
--          { Type = "Bar",  Name = "hp",    Text = "Health", Value = 1 },
--          { Type = "Button", Name = "rejoin", Text = "Rejoin", Callback = fn },
--      } })
--      dash:Set("kills", { Value = "128" })
function TabClass:AddCanvas(cfg)
    cfg = cfg or {}
    local reg = Registry.new()
    local card = self:_card()

    local titleRow = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 18),
        LayoutOrder = 1,
        Parent = card,
    })
    local titleLabel = Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Text = cfg.Name or "Canvas",
        Font = Theme.FontMedium,
        TextSize = 13,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = titleRow,
    })

    local setDesc = attachDescription(card, 2)
    setDesc(cfg.Description)

    local body = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 3,
        Parent = card,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = body,
    })

    local handles = {}
    local order = 0

    local function buildWidget(w)
        order = order + 1
        local wtype = string.lower(tostring(w.Type or "text"))
        local name = tostring(w.Name or wtype .. order)

        if wtype == "text" then
            local row = Create("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 18),
                LayoutOrder = order,
                Parent = body,
            })
            local lbl = Create("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -90, 1, 0),
                Text = tostring(w.Text or name),
                Font = Theme.FontMain,
                TextSize = 12,
                TextColor3 = Theme.TextDim,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = row,
            })
            local val = Create("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, 0, 0, 0),
                Size = UDim2.new(0, 90, 1, 0),
                Text = tostring(w.Value or ""),
                Font = Theme.FontBold,
                TextSize = 12,
                TextColor3 = Theme.AccentGold,
                TextXAlignment = Enum.TextXAlignment.Right,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = row,
            })
            handles[name] = {
                Type = "Text",
                Set = function(props)
                    if props.Text ~= nil then
                        lbl.Text = tostring(props.Text)
                    end
                    if props.Value ~= nil then
                        val.Text = tostring(props.Value)
                    end
                end,
                Get = function()
                    return { Text = lbl.Text, Value = val.Text }
                end,
            }

        elseif wtype == "bar" then
            local row = Create("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 24),
                LayoutOrder = order,
                Parent = body,
            })
            local lbl = Create("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(0.38, -6, 1, 0),
                Text = tostring(w.Text or name),
                Font = Theme.FontMain,
                TextSize = 12,
                TextColor3 = Theme.TextDim,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = row,
            })
            local barTrack = Create("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, 0, 0.5, 0),
                Size = UDim2.new(0.62, 0, 6, 0),
                BackgroundColor3 = Theme.Track,
                BorderSizePixel = 0,
                Parent = row,
            })
            Corner(barTrack, UDim.new(1, 0))
            local barFill = Create("Frame", {
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = Theme.White, -- PUTIH → gradien murni
                BorderSizePixel = 0,
                Parent = barTrack,
            })
            Corner(barFill, UDim.new(1, 0))
            Gradient(barFill, Color3.fromRGB(0, 170, 235), Color3.fromRGB(90, 220, 255), 90)
            local function setBar(v)
                local rel = math.clamp(tonumber(v) or 0, 0, 1)
                barFill.Size = UDim2.new(rel, 0, 1, 0)
            end
            setBar(w.Value)
            handles[name] = {
                Type = "Bar",
                Set = function(props)
                    if props.Text ~= nil then
                        lbl.Text = tostring(props.Text)
                    end
                    if props.Value ~= nil then
                        setBar(props.Value)
                    end
                    if typeof(props.Color) == "Color3" then
                        barFill.BackgroundColor3 = props.Color
                    end
                end,
                Get = function()
                    return { Text = lbl.Text, Value = barFill.Size.X.Scale }
                end,
            }

        elseif wtype == "button" then
            local btn = Create("TextButton", {
                Text = "",
                AutoButtonColor = false,
                BackgroundColor3 = Theme.Card,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 28),
                BorderSizePixel = 0,
                LayoutOrder = order,
                Parent = body,
            })
            Corner(btn, 6)
            local bStroke = Stroke(btn, { Color = Theme.Accent, Transparency = 0.4 })
            local bLabel = Create("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Text = tostring(w.Text or name),
                Font = Theme.FontBold,
                TextSize = 12,
                TextColor3 = Theme.Accent,
                Parent = btn,
            })
            reg:Connect(btn.MouseEnter, function()
                Tween(reg, btn, TI_HOVER, { BackgroundTransparency = 0.5, BackgroundColor3 = Theme.CardHover })
                Tween(reg, bStroke, TI_HOVER, { Transparency = 0 })
            end)
            reg:Connect(btn.MouseLeave, function()
                Tween(reg, btn, TI_HOVER, { BackgroundTransparency = 1, BackgroundColor3 = Theme.Card })
                Tween(reg, bStroke, TI_HOVER, { Transparency = 0.4 })
            end)
            reg:Connect(btn.Activated, function()
                Zap(reg, btn, Theme.AccentGold, 6)
                if type(w.Callback) == "function" then
                    w.Callback()
                end
            end)
            handles[name] = {
                Type = "Button",
                Set = function(props)
                    if props.Text ~= nil then
                        bLabel.Text = tostring(props.Text)
                    end
                end,
                Get = function()
                    return { Text = bLabel.Text }
                end,
                Fire = function()
                    if type(w.Callback) == "function" then
                        w.Callback()
                    end
                end,
            }

        elseif wtype == "divider" then
            local line = Create("Frame", {
                BackgroundColor3 = Theme.White,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 1),
                LayoutOrder = order,
                Parent = body,
            })
            Gradient(line, Theme.AccentGold, Theme.Accent, 0, NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, 0.85),
            }))
            handles[name] = {
                Type = "Divider",
                Set = function() end,
                Get = function()
                    return {}
                end,
            }
        end
    end

    for _, w in ipairs(cfg.Widgets or {}) do
        buildWidget(w)
    end

    local element = {
        Type = "Canvas",
        Name = cfg.Name,
        Instance = card,
        Registry = reg,
        SetDescription = function(_, t)
            setDesc(t)
        end,
        Get = function(_, name)
            local h = handles[tostring(name or "")]
            return h and h.Get and h.Get() or nil
        end,
        Set = function(_, name, props)
            local h = handles[tostring(name or "")]
            if h and h.Set then
                h.Set(props or {})
            end
        end,
        AddWidget = function(_, w)
            buildWidget(w)
        end,
        Fire = function(_, name)
            local h = handles[tostring(name or "")]
            if h and h.Fire then
                h.Fire()
            end
        end,
    }
    self:_track(element)
    EnableChildren(self, element, cfg, titleRow, titleLabel, "row")
    return element
end

--// ──────────────────────────────── Window ──────────────────────────────────
--  v2: layout modern — sidebar vertikal (logo + tab ber-ikon + versi)
--  di kiri, header dengan SEARCH BAR di kanan atas, konten scroll di bawah.
local WindowClass = {}
WindowClass.__index = WindowClass

local SIDEBAR_W   = 156  -- lebar sidebar penuh (nama tab tampil)
local SIDEBAR_MIN = 48   -- lebar sidebar sempit (hanya ikon, window kecil)
local HEADER_H    = 46   -- tinggi header (search + tombol kontrol)

--  Ubah ukuran frame tetapi sisi kiri-atas dipertahankan (aman untuk anchor 0.5)
local function setSizeKeepTopLeft(frame, targetSize)
    local oldAbs = frame.AbsoluteSize
    frame.Size = UDim2.fromOffset(targetSize.X, targetSize.Y)
    frame.Position = UDim2.new(
        frame.Position.X.Scale, frame.Position.X.Offset + (targetSize.X - oldAbs.X) * 0.5,
        frame.Position.Y.Scale, frame.Position.Y.Offset + (targetSize.Y - oldAbs.Y) * 0.5
    )
end

function ThorUi:CreateWindow(cfg)
    if not LocalPlayer then
        warn("[ThorUi] CreateWindow hanya bisa dipanggil dari client (LocalScript).")
        return nil
    end
    cfg = cfg or {}
    local gui = ensureGui()
    local reg = Registry.new()
    local viewport = GetViewport()

    -- batas minimal ukuran (UISizeConstraint) + auto-clamp untuk layar kecil
    -- v2.2.3: margin auto-clamp diperlebar 20 → 56 px — window di layar kecil
    -- pun tetap punya ruang napas dari tepi layar (tidak menempel/terpotong).
    local minSize = cfg.MinSize or Vector2.new(400, 250)
    minSize = Vector2.new(
        math.min(minSize.X, math.max(viewport.X - 56, 220)),
        math.min(minSize.Y, math.max(viewport.Y - 56, 160))
    )

    -- v2.2.3: ukuran default RADA PERSEGU + DIJAMIN MUAT di layar apa pun
    -- perangkatnya — dihitung murni dari DIMENSI viewport aktual, bukan lagi
    -- dari deteksi MouseEnabled (sebagian Android/emulator/executor
    -- melaporkan MouseEnabled = true walau perangkat tanpa mouse → dulu
    -- salah mengambil default PC 540px yang LEBIH LEBAR dari layar HP →
    -- window tampak "langsung terpotong" di kedua sisi padahal belum
    -- diseret ke tepi layar).
    --   • lebar  : terkecil dari 440px / 86% lebar layar / 62% tinggi layar
    --   • tinggi : terkecil dari 390px / 62% tinggi layar / 1.15x lebar
    --   → rasio akhir selalu 1:1 s.d. 1.15:1 (rada persegu) DAN selalu
    --     menyisakan margin terlihat di semua sisi layar.
    local size = cfg.Size
    if not size then
        local w = math.min(440, viewport.X * 0.86, viewport.Y * 0.62)
        local h = math.min(390, viewport.Y * 0.62, w * 1.15)
        w = math.min(w, viewport.X - 24)
        h = math.min(h, viewport.Y - 24)
        size = UDim2.fromOffset(math.floor(w + 0.5), math.floor(h + 0.5))
    end

    -- ── Frame utama ──
    local frame = Create("Frame", {
        Name = "ThorUi_Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = cfg.Position or UDim2.new(0.5, 0, 0.5, 0),
        Size = size,
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true,
        Visible = false, -- muncul setelah splash (atau langsung jika tanpa splash)
        Parent = gui,
    })
    Corner(frame, 12)
    Stroke(frame, { Color = Theme.Stroke, Thickness = 1, Transparency = 0.15 })
    local sizeConstraint = Create("UISizeConstraint", { MinSize = minSize, Parent = frame })
    local uiScale = Create("UIScale", { Parent = frame })

    -- ── SIDEBAR (logo + tab vertikal + versi) ──
    local sidebar = Create("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, SIDEBAR_W, 1, 0),
        BackgroundColor3 = Theme.White, -- PUTIH: gradien navy murni (bukan RGB(1,2,4)!)
        BorderSizePixel = 0,
        Active = true,
        Parent = frame,
    })
    Gradient(sidebar, Theme.BackgroundAlt, Theme.Background, 90)

    -- baris logo (juga area drag)
    local logoRow = Create("Frame", {
        Name = "LogoRow",
        Size = UDim2.new(1, 0, 0, 54),
        BackgroundTransparency = 1,
        Active = true,
        Parent = sidebar,
    })
    -- v2.3.1: logo palu ThorHub geometris (atau logo custom via cfg.Logo /
    -- ThorUi:SetLogo) — presisi di tengah baris, tanpa nudge glyph emoji.
    -- cfg.Logo MENIMPA config global sepenuhnya (termasuk Size) supaya
    -- ukuran render (MakeLogo) dan offset teks selalu KONSISTEN.
    local effLogo = cfg.Logo or _state.Logo
    local logoSize = tonumber(effLogo and effLogo.Size) or 22
    local logoMark = MakeLogo(logoRow, {
        Size = 22,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 12 + logoSize / 2, 0.5, 0),
    }, effLogo)
    local logoText = Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12 + logoSize + 6, 0, 0),
        Size = UDim2.new(1, -(logoSize + 26), 1, 0),
        Text = cfg.Title or "ThorHub",
        Font = Theme.FontBold,
        TextSize = 14,
        TextColor3 = Theme.White,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = logoRow,
    })
    Gradient(logoText, Theme.AccentGold, Theme.Accent, 15)

    -- pembatas bawah logo
    local logoDivider = Create("Frame", {
        Position = UDim2.new(0, 10, 0, 54),
        Size = UDim2.new(1, -20, 0, 1),
        BackgroundColor3 = Theme.Stroke,
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        Parent = sidebar,
    })

    -- daftar tab (scrollable vertikal)
    local tabList = Create("ScrollingFrame", {
        Name = "TabList",
        Position = UDim2.new(0, 0, 0, 62),
        -- ruang bawah disisakan untuk tombol expand "+" & label versi
        Size = UDim2.new(1, 0, 1, -120),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Accent,
        ScrollBarImageTransparency = 0.4,
        Parent = sidebar,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = tabList,
    })
    Create("UIPadding", {
        PaddingTop = UDim.new(0, 2),
        PaddingBottom = UDim.new(0, 4),
        PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 6),
        Parent = tabList,
    })

    -- versi di pojok bawah sidebar
    local versionLabel = Create("TextLabel", {
        Position = UDim2.new(0, 0, 1, -24),
        Size = UDim2.new(1, 0, 0, 16),
        Text = "v" .. ThorUi.Version,
        Font = Theme.FontMain,
        TextSize = 11,
        TextColor3 = Theme.TextDim,
        BackgroundTransparency = 1,
        Parent = sidebar,
    })

    -- ── SISI KANAN: header (search + kontrol) + konten ──
    local right = Create("Frame", {
        Name = "Right",
        Position = UDim2.new(0, SIDEBAR_W, 0, 0),
        Size = UDim2.new(1, -SIDEBAR_W, 1, 0),
        BackgroundTransparency = 1,
        Parent = frame,
    })

    local header = Create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, HEADER_H),
        BackgroundColor3 = Theme.White, -- PUTIH: gradien navy murni
        BorderSizePixel = 0,
        Parent = right,
    })
    Gradient(header, Theme.BackgroundAlt, Theme.Background, 90)

    -- strip drag di belakang konten header (search & tombol kontrol Active
    -- sehingga tidak ikut ter-drag saat diklik)
    local dragStrip = Create("Frame", {
        Name = "DragStrip",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Active = true,
        Parent = header,
    })

    -- SEARCH BAR (filter elemen di tab aktif, real-time)
    local searchWrap = Create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 10, 0.5, 0),
        -- FIX v2.1.1: lebar dikurangi agar TIDAK menimpa tombol minimize "—"
        -- (dulu tepi kanan search masuk ke area tombol kontrol → tombol "—"
        -- tampak menempel di atas search bar / "tidak pada tempatnya")
        Size = UDim2.new(1, -90, 0, 30),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        Active = true, -- serap klik agar tidak memicu drag window
        Parent = header,
    })
    Corner(searchWrap, 8)
    local searchStroke = Stroke(searchWrap, { Color = Theme.StrokeDim, Transparency = 0.35 })
    Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 8, 0, 1), -- +1px nudge glyph 🔍
        Size = UDim2.new(0, 16, 1, 0),
        Text = "🔍",
        Font = Theme.FontMain,
        TextSize = 11,
        TextColor3 = Theme.TextDim,
        Parent = searchWrap,
    })
    local searchBox = Create("TextBox", {
        Position = UDim2.new(0, 28, 0, 0),
        Size = UDim2.new(1, -34, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = "Cari elemen...",
        PlaceholderColor3 = Theme.TextDim,
        Font = Theme.FontMain,
        TextSize = 12,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        ClipsDescendants = true,
        Parent = searchWrap,
    })

    -- objek window (dibuat lebih awal agar bisa dipakai closure tombol kontrol)
    local self = setmetatable({
        Frame = frame,
        Gui = gui,
        Registry = reg,
        UiScale = uiScale,
        SizeConstraint = sizeConstraint,
        Sidebar = sidebar,
        LogoRow = logoRow,
        LogoMark = logoMark,
        LogoText = logoText,
        _logoSize = logoSize,
        VersionLabel = versionLabel,
        TabList = tabList,
        Right = right,
        Header = header,
        SearchBox = searchBox,
        Tabs = {},
        Collapsed = false,
        _closing = false,
        _activeTab = nil,
        _minSize = minSize,
        _savedAbs = nil,
        _narrow = nil,
        _sidebarW = SIDEBAR_W,
        _searchQuery = "",
        _overlays = {},
        CollapseLabel = nil,
    }, WindowClass)

    reg:Connect(searchBox:GetPropertyChangedSignal("Text"), function()
        -- OPTIMASI v2.2.0: debounce 0.1s — filter per ketikan memicu
        -- re-layout penuh seluruh elemen tab; kini digabung satu kali.
        local text = searchBox.Text
        self._searchTick = (self._searchTick or 0) + 1
        local tick = self._searchTick
        task.delay(0.1, function()
            if self._searchTick == tick and self.Frame.Parent then
                self:_applySearch(text)
            end
        end)
    end)
    reg:Connect(searchBox.Focused, function()
        Tween(reg, searchStroke, TI_HOVER, { Color = Theme.Accent, Transparency = 0 })
    end)
    reg:Connect(searchBox.FocusLost, function()
        Tween(reg, searchStroke, TI_HOVER, { Color = Theme.StrokeDim, Transparency = 0.35 })
    end)

    -- ── Tombol kontrol (— collapse, ✕ close) ──
    local function makeControl(text, offsetX, hoverColor, onClick)
        local btn = Create("TextButton", {
            Text = "",
            AutoButtonColor = false,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, offsetX, 0.5, 0),
            Size = UDim2.fromOffset(32, 32),
            BackgroundColor3 = Theme.Card,
            BackgroundTransparency = 0.4,
            BorderSizePixel = 0,
            ZIndex = 3,
            Parent = header,
        })
        Corner(btn, 8)
        local lbl = Create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, 1), -- +1px: glyph — / ✕ agar pas di tengah
            Size = UDim2.new(1, 0, 1, 0),
            Text = text,
            Font = Theme.FontBold,
            TextSize = 16,
            TextColor3 = Theme.TextDim,
            Parent = btn,
        })
        reg:Connect(btn.MouseEnter, function()
            Tween(reg, lbl, TI_HOVER, { TextColor3 = hoverColor })
        end)
        reg:Connect(btn.MouseLeave, function()
            Tween(reg, lbl, TI_HOVER, { TextColor3 = Theme.TextDim })
        end)
        reg:Connect(btn.Activated, onClick)
        return btn, lbl
    end

    -- posisi tombol kontrol (dari kanan header):
    --   "—" tepi kanan di -44 (rentang -76..-44)   "✕" tepi kanan di -6
    --   (rentang -38..-6) → search bar berhenti di -80, tidak ada yang bertumpuk
    local collapseBtn, collapseLabel = makeControl("—", -44, Theme.AccentGold, function()
        Zap(reg, collapseBtn, Theme.AccentGold, 8)
        self:SetCollapsed(not self.Collapsed)
    end)
    self.CollapseLabel = collapseLabel
    local closeBtn = makeControl("✕", -6, Theme.Danger, function()
        Zap(reg, closeBtn, Theme.Danger, 8)
        self:Hide()
    end)

    -- ── Tombol expand "+" di sidebar (hanya tampil saat window MINIMIZED) ──
    --  Saat collapse, panel kanan (termasuk tombol "—" di header) disembunyikan,
    --  jadi tombol ini satu-satunya cara membesarkan window kembali.
    local expandBtn = Create("TextButton", {
        Name = "ExpandBtn",
        Text = "",
        AutoButtonColor = false,
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -24),
        Size = UDim2.fromOffset(34, 34),
        BackgroundColor3 = Theme.Card,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 4,
        Parent = sidebar,
    })
    Corner(expandBtn, 9)
    local expandStroke = Stroke(expandBtn, { Color = Theme.AccentGold, Thickness = 1, Transparency = 0.25 })
    Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Text = "+",
        Font = Theme.FontBold,
        TextSize = 20,
        TextColor3 = Theme.AccentGold,
        Parent = expandBtn,
    })
    reg:Connect(expandBtn.MouseEnter, function()
        Tween(reg, expandBtn, TI_HOVER, { BackgroundTransparency = 0.1 })
        Tween(reg, expandStroke, TI_HOVER, { Transparency = 0 })
    end)
    reg:Connect(expandBtn.MouseLeave, function()
        Tween(reg, expandBtn, TI_HOVER, { BackgroundTransparency = 0.35 })
        Tween(reg, expandStroke, TI_HOVER, { Transparency = 0.25 })
    end)
    reg:Connect(expandBtn.Activated, function()
        Zap(reg, expandBtn, Theme.AccentGold, 9)
        self:SetCollapsed(false)
    end)
    self.ExpandBtn = expandBtn

    -- garis petir di bawah header (aksen emas → cyan)
    local thunderLine = Create("Frame", {
        Position = UDim2.new(0, 0, 0, HEADER_H),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.White, -- PUTIH: garis petir emas->biru murni
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = right,
    })
    Gradient(thunderLine, Theme.AccentGold, Theme.Accent, 0, NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 0.9),
    }))

    -- ── Konten: ScrollingFrame + AutomaticCanvasSize (elemen tak terbatas) ──
    local content = Create("ScrollingFrame", {
        Name = "Content",
        Position = UDim2.new(0, 0, 0, HEADER_H + 1),
        Size = UDim2.new(1, 0, 1, -(HEADER_H + 1)),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Accent,
        ScrollBarImageTransparency = 0.2,
        Parent = right,
    })
    self.Content = content

    -- ── Corner resize handle (drag di sudut kanan-bawah) ──
    local grip = Create("TextButton", {
        Name = "ResizeGrip",
        Text = "",
        AutoButtonColor = false,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -2, 1, -2),
        Size = UDim2.fromOffset(34, 34),
        BackgroundTransparency = 1,
        ZIndex = 5,
        Parent = frame,
    })
    self.Grip = grip
    local gripLines = {}
    for i = 0, 2 do
        local line = Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 4 - i * 5, 0.5, 4 - i * 5),
            Size = UDim2.new(0, 10, 0, 2),
            Rotation = 45,
            BackgroundColor3 = Theme.TextDim,
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0,
            Parent = grip,
        })
        Corner(line, UDim.new(1, 0))
        table.insert(gripLines, line)
    end
    reg:Connect(grip.MouseEnter, function()
        for _, line in ipairs(gripLines) do
            Tween(reg, line, TI_HOVER, { BackgroundColor3 = Theme.Accent })
        end
    end)
    reg:Connect(grip.MouseLeave, function()
        for _, line in ipairs(gripLines) do
            Tween(reg, line, TI_HOVER, { BackgroundColor3 = Theme.TextDim })
        end
    end)

    -- ── Drag window: Mouse & Touch via UserInputService ──
    -- (area drag: baris logo sidebar + header kanan)
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil
    local function beginDrag(input, handle)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                return
            end
            -- bawa window ini ke depan
            for _, w in ipairs(_state.Windows) do
                w.Frame.ZIndex = 1
            end
            frame.ZIndex = 2
            dragging = true
            dragInput = input
            dragStart = input.Position
            startPos = frame.Position
        end
    end
    reg:Connect(logoRow.InputBegan, function(input)
        beginDrag(input, logoRow)
    end)
    reg:Connect(dragStrip.InputBegan, function(input)
        beginDrag(input, dragStrip)
    end)
    reg:Connect(UserInputService.InputChanged, function(input)
        if dragging and gestureInput(dragInput, input) then
            local delta = input.Position - dragStart
            local vp = GetViewport()
            -- v2.2.2: drag SEPENUHNYA BEBAS — TANPA BATAS (permintaan user:
            -- "tidak ada batas ketika geser ke kiri kanan"). Window boleh
            -- dibawa keluar layar ke kiri/kanan/atas/bawah; tidak akan
            -- hilang selamanya — Window:Show() menariknya balik ke layar.
            frame.Position = UDim2.new(
                0, startPos.X.Scale * vp.X + startPos.X.Offset + delta.X,
                0, startPos.Y.Scale * vp.Y + startPos.Y.Offset + delta.Y
            )
        end
    end)
    reg:Connect(UserInputService.InputEnded, function(input)
        if dragging and gestureEnded(dragInput, input) then
            dragging = false
            dragInput = nil
        end
    end)

    -- ── Resize window: tahan & geser handle sudut (Mouse & Touch) ──
    local resizing = false
    local resizeInput = nil
    local resizeStartPos = nil
    local resizeStartSize = nil
    local resizeFramePos = nil
    reg:Connect(grip.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if self.Collapsed then
                return
            end
            if resizing then
                return
            end
            resizing = true
            resizeInput = input
            resizeStartPos = input.Position
            resizeStartSize = frame.AbsoluteSize
            resizeFramePos = frame.Position
            for _, line in ipairs(gripLines) do
                Tween(reg, line, TI_HOVER, { BackgroundColor3 = Theme.AccentGold })
            end
        end
    end)
    reg:Connect(UserInputService.InputChanged, function(input)
        if resizing and gestureInput(resizeInput, input) then
            local delta = input.Position - resizeStartPos
            local vp = GetViewport()
            local target = Vector2.new(
                math.clamp(resizeStartSize.X + delta.X, self._minSize.X, vp.X - 12),
                math.clamp(resizeStartSize.Y + delta.Y, self._minSize.Y, vp.Y - 12)
            )
            frame.Size = UDim2.fromOffset(target.X, target.Y)
            -- kompensasi posisi agar sisi kiri-atas tidak bergeser (anchor 0.5,0.5)
            frame.Position = UDim2.new(
                resizeFramePos.X.Scale, resizeFramePos.X.Offset + (target.X - resizeStartSize.X) * 0.5,
                resizeFramePos.Y.Scale, resizeFramePos.Y.Offset + (target.Y - resizeStartSize.Y) * 0.5
            )
        end
    end)
    reg:Connect(UserInputService.InputEnded, function(input)
        if resizing and gestureEnded(resizeInput, input) then
            resizing = false
            resizeInput = nil
            for _, line in ipairs(gripLines) do
                Tween(reg, line, TI_HOVER, { BackgroundColor3 = Theme.TextDim })
            end
        end
    end)

    -- ── Responsif: sidebar auto icon-only saat window sempit ──
    reg:Connect(frame:GetPropertyChangedSignal("AbsoluteSize"), function()
        self:_updateResponsive()
    end)

    -- daftarkan window
    table.insert(_state.Windows, self)

    -- keybind toggle + tombol ⚡ melayang
    bindToggleKey(cfg.Keybind)
    if cfg.ShowToggle ~= false then
        _state.ToggleVisible = true
        ensureToggleButton()
        ThorUi:SetToggleVisible(true)
    end

    -- tata layout awal (sidebar lebar/sembunyi sesuai lebar window)
    self:_updateResponsive()

    -- ── Splash screen (sekali per sesi) lalu window pop muncul ──
    local useSplash = cfg.Splash
    if useSplash == nil then
        useSplash = not _state.SplashDone
    end
    if useSplash then
        _state.SplashDone = true
        playSplash(function()
            self:Show()
        end, { Logo = cfg.Logo, Title = cfg.Title })
    else
        self:Show()
    end

    return self
end

--// ────────────────────────── Metode Window ─────────────────────────────────
function WindowClass:CreateTab(cfg)
    local tab = TabClass.new(self, cfg)
    table.insert(self.Tabs, tab)
    if not self._activeTab then
        self:SelectTab(tab)
    end
    return tab
end

function WindowClass:SelectTab(tab)
    for _, t in ipairs(self.Tabs) do
        if t ~= tab then
            t.Active = false
            t.Container.Visible = false
            t.Label.TextColor3 = Theme.TextDim
            t.Icon.TextColor3 = Theme.TextDim
            t.Button.BackgroundTransparency = 1
            t.Indicator.Size = UDim2.new(0, 3, 0, 0)
        end
    end
    self._activeTab = tab
    tab.Active = true
    tab.Container.Visible = true
    tab.Label.TextColor3 = Theme.Text
    tab.Icon.TextColor3 = Theme.AccentGold
    tab.Button.BackgroundTransparency = 0.55
    tab.Button.BackgroundColor3 = Theme.Card
    -- animasi indikator petir "menyambar" + konten slide-in kilat
    tab.Indicator.Size = UDim2.new(0, 3, 0, 0)
    Tween(self.Registry, tab.Indicator, TI_STRIKE, { Size = UDim2.new(0, 3, 0, 18) })
    tab.Container.Position = UDim2.new(0, 0, 0, 8)
    Tween(self.Registry, tab.Container, TI_SNAP, { Position = UDim2.new(0, 0, 0, 0) })
    self.Content.CanvasPosition = Vector2.new(0, 0)
    -- terapkan filter pencarian yang sedang aktif
    tab:ApplyFilter(self._searchQuery or "")
end

function WindowClass:Show()
    self._closing = false -- batalkan hide yang sedang berjalan
    if self.Frame.Visible and (self.UiScale.Scale or 1) >= 0.99 then
        return
    end
    -- v2.2.2: window boleh digeser BEBAS keluar layar (drag tanpa batas).
    -- Saat DIMUNCULKAN kembali (tombol ⚡ / keybind), tarik balik ke dalam
    -- layar — minimal 56px sisi kiri/kanan & 30px baris judul terlihat —
    -- agar window tidak "hilang" selamanya.
    local f = self.Frame
    local size = f.AbsoluteSize
    if size.X > 0 and size.Y > 0 then
        local vp = GetViewport()
        local center = Vector2.new(
            f.Position.X.Scale * vp.X + f.Position.X.Offset,
            f.Position.Y.Scale * vp.Y + f.Position.Y.Offset
        )
        local loX = 56 - size.X * 0.5
        local hiX = math.max(loX, vp.X - 56 + size.X * 0.5)
        local loY = 30 - size.Y * 0.5
        local hiY = math.max(loY, vp.Y - 30 + size.Y * 0.5)
        f.Position = UDim2.new(
            0, math.clamp(center.X, loX, hiX),
            0, math.clamp(center.Y, loY, hiY)
        )
    end
    f.Visible = true
    self.UiScale.Scale = 0.75
    Tween(self.Registry, self.UiScale, TI_STRIKE, { Scale = 1 })
end

function WindowClass:Hide()
    if self._closing or not self.Frame.Visible then
        return
    end
    self._closing = true
    local tween = Tween(self.Registry, self.UiScale, TI_EXIT, { Scale = 0.7 })
    self.Registry:Connect(tween.Completed, function(playback)
        if playback == Enum.PlaybackState.Completed and self._closing then
            self.Frame.Visible = false
            self.UiScale.Scale = 0.75
            self._closing = false
        end
    end)
end

function WindowClass:Toggle()
    -- window yang sedang menutup dianggap "tersembunyi":
    -- tap beruntun membatalkan hide & langsung memunculkan kembali
    if self._closing or not self.Frame.Visible then
        self:Show()
    else
        self:Hide()
    end
end

--  v2: collapse = window menyusut jadi sidebar saja (kanan disembunyikan).
--  Tombol "+" di bawah sidebar muncul saat minimized untuk memperbesar kembali.
function WindowClass:SetCollapsed(collapsed)
    if self.Collapsed == collapsed then
        return
    end
    self.Collapsed = collapsed
    local sideW = self._sidebarW or SIDEBAR_W
    if collapsed then
        self._savedAbs = self.Frame.AbsoluteSize
        self.Right.Visible = false
        self.Grip.Visible = false
        self.SizeConstraint.MinSize = Vector2.new(SIDEBAR_MIN, 120)
        setSizeKeepTopLeft(self.Frame, Vector2.new(sideW, self.Frame.AbsoluteSize.Y))
    else
        self.Right.Visible = true
        self.Grip.Visible = true
        -- kembalikan ukuran SEBELUM MinSize dipulihkan, agar frame sempit
        -- (48-156px) tidak sempat di-clamp ke atas oleh UISizeConstraint;
        -- clamp juga ke viewport saat ini (aman saat rotasi layar mobile)
        if self._savedAbs then
            local vp = GetViewport()
            local target = Vector2.new(
                math.max(self._minSize.X, math.min(self._savedAbs.X, vp.X - 12)),
                math.max(self._minSize.Y, math.min(self._savedAbs.Y, vp.Y - 12))
            )
            setSizeKeepTopLeft(self.Frame, target)
        end
        self.SizeConstraint.MinSize = self._minSize
    end
    if self.CollapseLabel then
        self.CollapseLabel.Text = collapsed and "+" or "—"
    end
    -- tombol expand "+" di sidebar hanya tampil saat minimized;
    -- label versi disembunyikan agar tidak bertabrakan
    if self.ExpandBtn then
        self.ExpandBtn.Visible = collapsed
    end
    if self.VersionLabel then
        self.VersionLabel.Visible = not collapsed and not self._narrow
    end
    Zap(self.Registry, self.Header, Theme.AccentGold, 8)
end

function WindowClass:SetKeybind(key)
    ThorUi:SetKeybind(key)
end

function WindowClass:SetTitle(text)
    self.LogoText.Text = tostring(text or "ThorUi")
end

--  Sidebar responsif: window sempit (< 430px) → icon-only (lebar 48px).
--  v2.2.3: ambang diturunkan 520 → 430 — default persegu 440px tetap
--  menampilkan NAMA tab; hanya layar benar-benar sempit (hp portrait)
--  yang otomatis icon-only.
function WindowClass:_updateResponsive()
    -- saat collapsed, ukur "lebar logis" (ukuran sebelum minimize) supaya
    -- sidebar tidak ikut menyempit hanya karena window sedang dikecilkan;
    -- jika AbsoluteSize belum ter-layout (0), perkirakan dari Size x viewport
    local width = self.Frame.AbsoluteSize.X
    if self.Collapsed and self._savedAbs then
        width = self._savedAbs.X
    elseif width <= 0 then
        local vp = GetViewport()
        width = self.Frame.Size.X.Scale * vp.X + self.Frame.Size.X.Offset
    end
    local narrow = width < 430
    if narrow == self._narrow then
        return
    end
    self._narrow = narrow
    local w = narrow and SIDEBAR_MIN or SIDEBAR_W
    self._sidebarW = w
    self.Sidebar.Size = UDim2.new(0, w, 1, 0)
    self.Right.Position = UDim2.new(0, w, 0, 0)
    self.Right.Size = UDim2.new(1, -w, 1, 0)
    self.LogoText.Visible = not narrow
    -- v2.3.1: logo palu/custom ikut ke TENGAH saat sidebar icon-only
    -- (pola penempatan ikon tab v2.1.1)
    self.LogoMark.Position = narrow
        and UDim2.new(0.5, 0, 0.5, 0)
        or UDim2.new(0, 12 + (self._logoSize or 22) / 2, 0.5, 0)
    self.VersionLabel.Visible = not narrow and not self.Collapsed
    for _, t in ipairs(self.Tabs) do
        t.Label.Visible = not narrow
        -- FIX v2.1.1: saat sidebar icon-only, ikon diletakkan PERSIS di tengah
        -- tombol (dulu tetap menempel di kiri → ikon terlihat "tidak di tempatnya")
        t.Icon.Position = narrow
            and UDim2.new(0.5, -9, 0, 1)
            or UDim2.new(0, 10, 0, 1)
    end
    if self.Collapsed then
        setSizeKeepTopLeft(self.Frame, Vector2.new(w, self.Frame.AbsoluteSize.Y))
    end
end

--  Search bar: filter elemen di tab aktif secara real-time.
function WindowClass:_applySearch(text)
    self._searchQuery = tostring(text or "")
    if self._activeTab then
        self._activeTab:ApplyFilter(self._searchQuery)
    end
end

--// ──────────────── CONFIRM DIALOG (modal modern) ──────────────────────
--  Window:Confirm({
--      Title = "Hapus semua data?",
--      Content = "Tindakan ini tidak bisa dibatalkan.",
--      ConfirmText = "Ya, hapus", CancelText = "Batal",
--      OnConfirm = function() ... end, OnCancel = function() ... end,
--  })
function WindowClass:Confirm(cfg)
    cfg = cfg or {}
    local gui = self.Gui or self.Frame.Parent
    if not gui then
        return
    end
    local reg = Registry.new()

    -- overlay gelap + tombol latar (klik di luar kartu = batal)
    local overlay = Create("Frame", {
        Name = "ThorUi_Confirm",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 80,
        Parent = gui,
    })
    local bgBtn = Create("TextButton", {
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 80,
        Parent = overlay,
    })

    -- kartu dialog (CanvasGroup agar bisa fade)
    -- FIX v2.1.1: lebar auto-fit agar tidak keluar layar di mobile
    local vp = GetViewport()
    local card = Create("CanvasGroup", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, math.min(320, math.max(220, math.floor(vp.X - 30))), 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.BackgroundAlt,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        Active = true, -- serap klik agar bgBtn tidak terpicu
        ZIndex = 81,
        Parent = overlay,
    })
    Corner(card, 12)
    Stroke(card, { Color = Theme.Stroke, Transparency = 0.25 })
    local cardScale = Create("UIScale", { Scale = 0.85, Parent = card })

    local inner = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = card,
    })
    Create("UIPadding", {
        PaddingTop = UDim.new(0, 16),
        PaddingBottom = UDim.new(0, 14),
        PaddingLeft = UDim.new(0, 16),
        PaddingRight = UDim.new(0, 16),
        Parent = inner,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = inner,
    })

    Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 16),
        Text = cfg.Title or "Konfirmasi",
        Font = Theme.FontBold,
        TextSize = 14,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,
        Parent = inner,
    })
    local msgLabel = Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 14),
        -- FIX v2.1.2: tinggi eksplisit terukur — dulu AutomaticSize.Y bisa
        -- memesan tinggi kurang dari teks → baris TOMBOL menimpa pesan
        Text = cfg.Content or "",
        Font = Theme.FontMain,
        TextSize = 12,
        TextColor3 = Theme.TextDim,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        LayoutOrder = 2,
        Parent = inner,
    })
    autoFitText(msgLabel, 0)

    -- baris tombol: Batal | Konfirmasi
    local btnRow = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 34),
        LayoutOrder = 3,
        Parent = inner,
    })
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = btnRow,
    })

    local function makeDialogBtn(order, bg, txtColor, text, onClick)
        local btn = Create("TextButton", {
            Text = "",
            AutoButtonColor = false,
            Size = UDim2.new(0.5, -4, 1, 0),
            BackgroundColor3 = bg,
            BorderSizePixel = 0,
            LayoutOrder = order,
            Parent = btnRow,
        })
        Corner(btn, 8)
        local lbl = Create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Text = text,
            Font = Theme.FontBold,
            TextSize = 12,
            TextColor3 = txtColor,
            Parent = btn,
        })
        reg:Connect(btn.MouseEnter, function()
            Tween(reg, btn, TI_HOVER, { BackgroundColor3 = Theme.CardHover })
        end)
        reg:Connect(btn.Activated, function()
            Zap(reg, btn, Theme.Accent, 8)
            onClick()
        end)
        _ = lbl
        return btn
    end

    local entry = { Overlay = overlay, Reg = reg, Closed = false }
    table.insert(self._overlays, entry)

    local function close(result)
        if entry.Closed then
            return
        end
        entry.Closed = true
        for i, e in ipairs(self._overlays) do
            if e == entry then
                table.remove(self._overlays, i)
                break
            end
        end
        local out = Tween(reg, card, TI_EXIT, { GroupTransparency = 1 })
        Tween(reg, cardScale, TI_EXIT, { Scale = 0.9 })
        Tween(reg, bgBtn, TI_EXIT, { BackgroundTransparency = 1 })
        out.Completed:Connect(function()
            reg:Clean()
            if overlay.Parent then
                overlay:Destroy()
            end
            if result and cfg.OnConfirm then
                cfg.OnConfirm()
            elseif not result and cfg.OnCancel then
                cfg.OnCancel()
            end
        end)
    end

    makeDialogBtn(1, Theme.Card, Theme.TextDim, cfg.CancelText or "Batal", function()
        close(false)
    end)
    local confirmBtn = makeDialogBtn(2, Theme.Accent, Theme.White, cfg.ConfirmText or "Konfirmasi", function()
        close(true)
    end)
    -- FIX v2.1.4: gradien confirmBtn DIHAPUS — selain tertint (hover
    -- men-tween bg ke CardHover -> gradien ikut berubah kotor), interpolasi
    -- biru->emas juga melintas abu kehijauan. Solid Electric Blue: bersih.

    reg:Connect(bgBtn.Activated, function()
        close(false)
    end)

    -- animasi masuk
    Tween(reg, bgBtn, TI_SNAP, { BackgroundTransparency = 0.45 })
    Tween(reg, card, TI_SNAP, { GroupTransparency = 0 })
    Tween(reg, cardScale, TI_STRIKE, { Scale = 1 })
end

function WindowClass:Destroy()
    -- tutup semua dialog Confirm yang masih terbuka
    for _, o in ipairs(self._overlays) do
        o.Reg:Clean()
        if o.Overlay.Parent then
            o.Overlay:Destroy()
        end
    end
    self._overlays = {}
    -- putuskan SEMUA koneksi milik window ini (anti memory-leak)
    self.Registry:Clean()
    for _, tab in ipairs(self.Tabs) do
        tab.Registry:Clean()
    end
    local elements = {}
    for _, tab in ipairs(self.Tabs) do
        for _, el in ipairs(tab.Elements) do
            table.insert(elements, el)
        end
    end
    for _, el in ipairs(elements) do
        el:Remove()
    end
    if self.Frame and self.Frame.Parent then
        self.Frame:Destroy()
    end
    for i, w in ipairs(_state.Windows) do
        if w == self then
            table.remove(_state.Windows, i)
            break
        end
    end
    -- sembunyikan tombol ⚡ jika sudah tidak ada window tersisa
    if #_state.Windows == 0 then
        ThorUi:SetToggleVisible(false)
    end
end

--// ──────────────────────── Hancurkan SELURUH UI ────────────────────────────
function ThorUi:Destroy()
    -- 1) hancurkan semua window (memicu Clean semua registry window/tab/elemen)
    local windows = {}
    for _, w in ipairs(_state.Windows) do
        table.insert(windows, w)
    end
    for _, w in ipairs(windows) do
        w:Destroy()
    end
    -- 2) tutup semua notifikasi (cancel task.delay yang masih berjalan)
    local notifs = {}
    for _, n in ipairs(_state.Notifs) do
        table.insert(notifs, n)
    end
    for _, n in ipairs(notifs) do
        despawnNotification(n, true)
    end
    -- 3) hentikan splash jika sedang berjalan
    _state.SplashActive = false
    -- 4) bersihkan garbage table level library (semua connection & tween)
    _state.Registry:Clean()
    _state.KeyConn = nil
    _state.TogglePulse = nil
    -- 5) hancurkan ScreenGui
    if _state.Gui then
        _state.Gui:Destroy()
    end
    _state.Gui = nil
    _state.NotifyHolder = nil
    _state.ToggleButton = nil
    _state.QuickDock = nil -- v2.3.0: deret quick action ikut hancur bersama Gui
    _state.Windows = {}
    _state.Notifs = {}
end

return ThorUi

--[[ ═════════════════════════════════════════════════════════════════════════
        CONTOH IMPLEMENTASI
        ═══════════════════════════════════════════════════════════════════════

        A. CARA PEMAKAIAN DI ROBLOX STUDIO
           1. Buat ModuleScript bernama "ThorUi" (misalnya di ReplicatedStorage),
              lalu tempel seluruh isi file ini ke dalamnya.
           2. Buat LocalScript di StarterPlayer > StarterPlayerScripts.
           3. Tulis kode berikut di LocalScript tersebut:

        ──────────────────────────── potong di sini ────────────────────────────

        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local Players = game:GetService("Players")

        local ThorUi = require(ReplicatedStorage:WaitForChild("ThorUi"))

        -- (Opsional) kustomisasi tema SEBELUM membuat window:
        -- ThorUi:SetTheme({ Accent = Color3.fromRGB(170, 90, 255),
        --                    AccentGold = Color3.fromRGB(255, 200, 60) })

        -- (Opsional) pasang LOGO SENDIRI — pengguna library bisa mengganti
        -- palu ThorHub bawaan (v2.3.1). Berlaku di splash + sidebar +
        -- tombol melayang; atau per-window: CreateWindow({ Logo = {...} }):
        -- ThorUi:SetLogo({ Image = "rbxassetid://123456789", Size = 26 })

        local Window = ThorUi:CreateWindow({
                Title   = "ThorHub ⚡",
                Size    = UDim2.new(0, 440, 0, 390),  -- v2.2.3: default rada persegu; kosongkan agar otomatis responsif + SELALU muat di layar
                MinSize = Vector2.new(400, 250),       -- batas minimal saat resize
                Keybind = Enum.KeyCode.RightControl,  -- toggle buka/tutup UI (PC)
                Splash = true,                        -- splash screen (default: window pertama)
                -- ShowToggle = false,                 -- sembunyikan tombol ⚡ melayang
        })

        local Tab  = Window:CreateTab({ Name = "Main",  Icon = "⚡" })
        local Tab2 = Window:CreateTab({ Name = "Info",  Icon = "🌩" })

        -- v2.2.2: SEMUA section (menu) MULAI TERLIPAT saat pertama execute
        -- biar daftar rapi — klik judulnya untuk membuka; atau beri
        -- Collapsed = false agar menu ini mulai TERBUKA:
        Tab:AddSection({ Name = "MENU UTAMA" })

        Tab:AddButton({
                Name = "Kirim Petir!",
                Callback = function()
                        ThorUi:Notify({
                                Title = "⚡ Petir Menyambar",
                                Content = "BOOM! Petir berhasil dikirim ke target.",
                                Duration = 3,
                        })
                end,
        })

        Tab:AddButton({
                Name = "Hapus Semua (pakai Confirm)",
                Callback = function()
                        Window:Confirm({
                                Title = "Hapus semua data?",
                                Content = "Tindakan ini tidak bisa dibatalkan. Lanjutkan?",
                                ConfirmText = "Ya, hapus",
                                CancelText = "Batal",
                                OnConfirm = function()
                                        ThorUi:Notify({ Title = "💥 Dihapus", Content = "Data telah dibersihkan." })
                                end,
                        })
                end,
        })

        local godMode = Tab:AddToggle({
                Name = "God Mode",
                Description = "Kamu jadi kebal dari semua damage selama aktif.",
                Default = false,
                Callback = function(value)
                        print("God Mode:", value)
                end,
        })

        -- v2.3.0: SUB-ROW — toggle ini punya ANAK (buka panah kecil di kiri)
        local speedToggle = Tab:AddToggle({
                Name = "Speed Hack",
                Default = false,
                Callback = function(v) print("Speed Hack:", v) end,
        })
        speedToggle:AddChild("Slider", {
                Name = "Nilai Speed",
                Min = 16, Max = 500, Default = 16, Suffix = " spd",
                Callback = function(v) print("Speed:", v) end,
        })
        speedToggle:AddChild("Toggle", {
                Name = "Saat Lompat Juga",
                Default = true,
                Callback = function(v) print("Jump boost:", v) end,
        })

        -- v2.3.0: DEPENDS — slider ini HANYA tampil saat God Mode ON
        local regenSlider = Tab:AddSlider({
                Name = "Regen / detik",
                Min = 0, Max = 100, Default = 10,
                Depends = { Element = godMode, Value = true },
                Callback = function(v) print("Regen:", v) end,
        })

        -- v2.3.0: STATE + BINDING — 2 slider berbagi SATU nilai (0..100):
        -- geser salah satu, yang lain ikut
        local st = ThorUi:CreateState({
                Name = "PowerLevel", Default = 50,
                Callback = function(v) print("Power:", v) end,
        })
        local s1 = Tab:AddSlider({ Name = "Power (A)", Min = 0, Max = 100, Default = 50 })
        local s2 = Tab:AddSlider({ Name = "Power (B)", Min = 0, Max = 100, Default = 50 })
        st:Bind(s1)
        st:Bind(s2)

        -- v2.3.0: SLIDER UNITS — konversi m ↔ km otomatis (nilai internal
        -- selalu meter); klik ANGKA untuk mengetik nilai eksak
        Tab:AddSlider({
                Name = "Jarak Serangan",
                Min = 0, Max = 10000, Default = 1000,
                Units = {
                        Default = "m",
                        Options = {
                                { Name = "m",  Suffix = "m" },
                                { Name = "km", Suffix = "km", Decimals = 2,
                                  FromBase = function(m) return m / 1000 end,
                                  ToBase   = function(km) return km * 1000 end },
                        },
                },
                Callback = function(m) print("Jarak (meter):", m) end,
        })

        -- v2.3.0: BUTTON dua tahap (ConfirmText)
        Tab:AddButton({
                Name = "Reset Progress",
                ConfirmText = "Yakin? Klik lagi!",
                Callback = function() print("Progress direset!") end,
        })

        -- v2.3.0: DROPDOWN + Search + ApplyButton
        Tab:AddDropdown({
                Name = "Target Farm",
                Values = { "Mob Perum", "Mob Kuil", "Boss Petir", "Boss Es", "Mini Boss" },
                Multi = true, Search = true, ApplyButton = "Terapkan",
                Callback = function(values, indices)
                        print("Farm:", table.concat(values, ", "))
                end,
        })

        Tab:AddSlider({
                Name = "WalkSpeed",
                Description = "Atur kecepatan jalan karakter (16 - 200).",
                Min = 16, Max = 200, Default = 16,
                Increment = 1, Suffix = " spd",
                Callback = function(value)
                        local char = Players.LocalPlayer.Character
                        local hum = char and char:FindFirstChildOfClass("Humanoid")
                        if hum then
                                hum.WalkSpeed = value
                        end
                end,
        })

        Tab:AddDropdown({
                Name = "Senjata",
                Description = "Pilih senjata andalan Sang Dewa Petir.",
                Values = { "Mjolnir", "Stormbreaker", "Gungnir" },
                Default = "Mjolnir",
                -- Multi = true,  -- aktifkan untuk multi-select
                Callback = function(value)
                        print("Senjata:", value)
                end,
        })

        Tab:AddColorPicker({
                Name = "Warna Petir",
                Default = Color3.fromRGB(0, 195, 255),
                Callback = function(color)
                        print("Warna:", color)
                end,
        })

        Tab:AddTextInput({
                Name = "Nama Target",
                Placeholder = "Ketik nama pemain...",
                Callback = function(text, enterPressed)
                        print("Input:", text, "| Enter:", enterPressed)
                end,
        })

        Tab:AddKeybind({
                Name = "Skill Petir",
                Default = Enum.KeyCode.R,
                Callback = function(bind)
                        print("Skill dipanggil dengan:", bind.Name)
                end,
        })

        -- v2.2.1: MENU (section) BISA DI-MINIMIZE — klik judulnya untuk
        -- melipat semua fitur di dalamnya (panah lipat berputar).
        -- v2.2.2: TERLIPAT kini default — Collapsed = false untuk terbuka:
        local menuLanjutan = Tab:AddSection({
                Name = "MENU LANJUTAN (klik untuk minimize)",
                Collapsed = true, -- eksplisit (sama dengan default v2.2.2)
        })
        Tab:AddLabel({ Text = "Menu ini dibuat TERLIPAT — klik judulnya untuk membuka." })

        -- ── v2.3.0: WIDGET BARU ──

        -- LIST: browser item — cari, pilah per grup, klik untuk pilih
        Tab:AddList({
                Name = "Gudang Senjata",
                Search = true,
                Groups = {
                        { Title = "Palu", Items = {
                                { Text = "Mjolnir", TopRight = "Legendary" },
                                { Text = "Stormbreaker", TopRight = "Mythic" },
                        } },
                        { Title = "Tombak", Items = { "Gungnir", "Trisula" } },
                },
                OnItemClick = function(item, index, selected)
                        print("Pilih:", item.Text, "→", selected)
                end,
        })

        -- MODELVIEW: etalase 3D (tanpa model → palu petir bawaan, murni Part)
        local palu = Tab:AddModelView({ Name = "Etalase", Height = 150, Spin = true })
        -- palu:SetModel(workspace.SomeModel)  → ganti objek kapan pun

        -- CANVAS: dashboard mini + update runtime
        local dash = Tab:AddCanvas({
                Name = "Statistik",
                Widgets = {
                        { Type = "Text", Name = "kills", Text = "Kills", Value = "0" },
                        { Type = "Bar",  Name = "hp",    Text = "Health", Value = 1 },
                        { Type = "Button", Name = "rejoin", Text = "Rejoin",
                          Callback = function() print("rejoin!") end },
                },
        })
        -- dash:Set("kills", { Value = "128" })  → update dari script

        -- GROUP (radio): maksimal satu mode aktif
        local modeGroup = ThorUi:CreateGroup({ Name = "Mode Aim" })
        Tab:AddToggle({ Name = "Aim: Kepala", Group = modeGroup, Default = true })
        Tab:AddToggle({ Name = "Aim: Dada",   Group = modeGroup })
        Tab:AddToggle({ Name = "Aim: Kaki",   Group = modeGroup })

        -- QUICK ACTION: tombol melayang yang bisa digeser
        ThorUi:AddQuickAction({
                Icon = "⚡", Name = "Sambar Sekarang",
                Callback = function() print("ZAP!") end,
        })

        Tab2:AddParagraph({
                Title = "Tentang ThorHub v2.3",
                Text = "UI library Dewa Petir: sidebar tab ber-ikon, search bar, "
                        .. "splash screen, ColorPicker, Confirm dialog, section yang "
                        .. "bisa di-minimize, PLUS v2.3: State binding antar-elemen, "
                        .. "Depends (baris otomatis muncul/sembunyi), sub-row AddChild, "
                        .. "slider multi-satuan, List browser item, etalase 3D "
                        .. "ModelView, dashboard Canvas, grup radio, dan quick "
                        .. "action melayang.",
        })

        ThorUi:Notify({ Title = "⚡ Petir Menyambar", Content = "Script berhasil dimuat!", Duration = 3 })

        -- Kontrol programatik:
        -- godMode:Set(true)         → set nilai + panggil callback
        -- godMode:Set(true, false)  → set nilai TANPA callback
        -- godMode:Get()             → ambil nilai
        -- godMode:SetDescription("teks keterangan baru")
        -- menuLanjutan:Toggle()  → minimize/buka menu dari script
        -- menuLanjutan:SetCollapsed(false) → buka paksa
        -- speedToggle:SetExpanded(true)  → buka anak2 sub-row dari script
        -- regenSlider:SetDependency({ Element = godMode, Value = true })
        -- Window:Toggle() / Window:Destroy()
        -- Window:SetTitle("Judul Baru")
        -- ThorUi:Destroy()          → hancurkan seluruh UI + bersihkan memory

        ──────────────────────────── potong di sini ────────────────────────────

        B. CARA PEMAKAIAN DI EXECUTOR
           Satu baris (loader otomatis dari GitHub):
               loadstring(game:HttpGet("https://raw.githubusercontent.com/dwisetyabudi15581/ThorUi/main/Loader.lua"))()
           Atau salin seluruh file ini ke executor, bungkus sebagai module,
           lalu panggil seperti contoh di atas. ScreenGui otomatis mencoba
           CoreGui, fallback ke PlayerGui.
]]
]==]

do
    local ok, lib = pcall(function()
        local chunk = loadstring(THORUI_SRC)
        if not chunk then error("ThorUi embedded parse gagal", 0) end
        return chunk()
    end)
    if not (ok and type(lib) == "table") then
        if type(warn) == "function" then
            warn("[ThorHub] ThorUi embedded gagal (" .. tostring(lib) .. ") — coba online")
        end
        ok, lib = pcall(function()
            local src = fetchLua("ThorUi", { THORUI_URL, mirrorUrl(THORUI_URL) }, 300)
            local chunk = assert(loadstring(src), "ThorUi parse gagal")
            return chunk()
        end)
    end
    if ok and type(lib) == "table" then
        ThorUI = lib
    else
        if type(warn) == "function" then
            warn("[ThorHub] Gagal memuat ThorUi: " .. tostring(lib))
        end
        return
    end
end

if not ThorUI.Version or ThorUI.Version < "2.0" then
    -- tetap lanjut, hanya catat
    if type(warn) == "function" then
        warn("[ThorHub] ThorUi versi lama terdeteksi: " .. tostring(ThorUI.Version))
    end
end

--────────────────────────────[ AUTO HOP — EGG FINDER ]────────────────────────────
-- Fitur tab "Auto Hop | Egg Finder" dari kode baru (SAE v172610):
-- pindah server otomatis sampai egg sesuai filter ditemukan. Tiga mode
-- ala script baru:
--   Until An Egg Matches  → hop terus selama belum ada egg yang cocok
--   Steal Then Hop        → hop setelah berhasil mencuri egg
--   After A Rare Spawns   → hop begitu egg rarity+ terdeteksi spawn

local HOP_RARITY_NUM = {
    Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5,
    Mythic = 6, Cosmic = 7, Secret = 8, Eternal = 9, Divine = 10,
}

local AutoHop = {
    on = false,
    mode = "Until An Egg Matches",
    waitRarity = "Mythic",
    firstDelay = 20,
    tOn = 0,
    busy = false,
    lastTry = 0,
    seen = {},
    matchCount = -1,
}

function AutoHop.HopNow(reason)
    if AutoHop.busy then return end
    if os.clock() - AutoHop.lastTry < 15 then return end
    AutoHop.busy = true
    AutoHop.lastTry = os.clock()
    Tasks.Status("autohop", "Pindah server: " .. tostring(reason))
    task.spawn(function()
        local picked = nil
        local ok, err = pcall(function()
            local cursor = ""
            for page = 1, 3 do
                local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&excludeFullGames=true&limit=100")
                    :format(game.PlaceId)
                if page > 1 then url = url .. "&cursor=" .. cursor end
                local body = game:HttpGet(url)
                local data = jsonDec(body)
                if type(data) ~= "table" or type(data.data) ~= "table" then break end
                for _, sv in ipairs(data.data) do
                    if type(sv) == "table" and tostring(sv.id) ~= tostring(game.JobId)
                        and (tonumber(sv.playing) or 0) < (tonumber(sv.maxPlayers) or 100) then
                        if not picked or (tonumber(sv.playing) or 0) < (tonumber(picked.playing) or 0) then
                            picked = sv
                        end
                    end
                end
                cursor = tostring(data.nextPageCursor or "")
                if cursor == "" or cursor == "nil" then break end
            end
            if not picked then error("tidak ada server lain yang tersedia") end
            if type(Gill) == "table" then Gill.__THORHUB_AUTOHOP = true end
            Tasks.Status("autohop", "Menuju server " .. tostring(picked.id)
                .. " (" .. tostring(picked.playing) .. " pemain)")
            TeleportService:TeleportToPlaceInstance(game.PlaceId, picked.id, LocalPlayer)
            task.delay(10, function() AutoHop.busy = false end)
        end)
        if not ok then
            AutoHop.busy = false
            Tasks.Status("autohop", "Hop gagal: " .. tostring(err))
        end
    end)
end

Tasks.Add("autohop", 2.0, function()
    if not AutoHop.on or AutoHop.busy then return end
    local now = os.clock()
    if now - AutoHop.lastTry < 15 then return end
    local rareNum = HOP_RARITY_NUM[AutoHop.waitRarity] or 6
    local targets = P(function() return EggState.StealTargets() end)
    local matched, freshRare = 0, false
    for _, egg in ipairs(targets or {}) do
        if egg.Kind ~= "Base" and (egg.RarityNum or 0) >= rareNum then
            matched += 1
            local key = tostring(egg.Uid or egg.Key or egg.Name or "")
            if AutoHop.seen[key] == nil then freshRare = true end
            AutoHop.seen[key] = now
        end
    end
    AutoHop.matchCount = matched
    if AutoHop.mode == "Until An Egg Matches" then
        if matched > 0 then
            Tasks.Status("autohop", matched .. " egg >= " .. AutoHop.waitRarity .. " ada di sini — tinggal")
            return
        end
        if now - AutoHop.tOn < AutoHop.firstDelay then
            Tasks.Status("autohop", "Belum ada match — hop dalam "
                .. math.ceil(AutoHop.firstDelay - (now - AutoHop.tOn)) .. "s")
            return
        end
        AutoHop.HopNow("belum ada egg >= " .. AutoHop.waitRarity)
    elseif AutoHop.mode == "Steal Then Hop" then
        if Steal.lastDeliver and Steal.lastDeliver > AutoHop.tOn then
            AutoHop.HopNow("selesai mencuri egg")
        else
            Tasks.Status("autohop", "Menunggu sukses curi sebelum hop")
        end
    elseif AutoHop.mode == "After A Rare Spawns" then
        if freshRare then
            AutoHop.HopNow("egg " .. AutoHop.waitRarity .. "+ baru spawn")
        else
            Tasks.Status("autohop", "Menunggu spawn egg >= " .. AutoHop.waitRarity
                .. " (match: " .. matched .. ")")
        end
    end
end)

--────────────────────────────[ AUTO PROGRESSION ]────────────────────────────
-- Fitur tab "Progress | Auto Progression" dari kode baru (SAE v172610).
local Progress = {
    upBase = false, claimCash = false, claimIndex = false, buyTrail = false,
    nextAt = {},
}

local LIMITED_REDEEMS = {
    "LimitedEgg", "GravityDisruptor", "MechaReroll", "BrainrotEgg",
    "BeeLauncher", "MonsterEgg", "Mecha",
}

local function progGate(k, gap)
    local now = os.clock()
    if (Progress.nextAt[k] or 0) > now then return false end
    Progress.nextAt[k] = now + gap
    return true
end

Tasks.Add("progress", 8.0, function()
    if not (Progress.upBase or Progress.claimCash or Progress.claimIndex or Progress.buyTrail) then return end
    if not Repo.SaveOK then return end
    if Progress.upBase and progGate("base", 30) then
        local ok = Repo.Fire("RE/Homestead/AskBaseTierRaise")
        Tasks.Status("progress", ok and "Base tier raise dikirim" or "Base: maksimal / gagal")
    end
    if Progress.claimCash and progGate("cash", 45) then
        P(function() Repo.Invoke("RF/AwayEarnings/FetchSummary") end)
        local ok = Repo.Invoke("RF/AwayEarnings/AskCollect")
        Tasks.Status("progress", ok and "Uang offline diklaim" or "Tidak ada uang offline")
    end
    if Progress.claimIndex and progGate("index", 300) then
        local ok = Repo.Invoke("RF/Codex/AskRedeemAll")
        for _, nm in ipairs(LIMITED_REDEEMS) do
            P(function() Repo.Invoke("RF/Codex/AskRedeemLimitedEgg", nm) end)
        end
        Tasks.Status("progress", ok and "Reward index diklaim" or "Index: tidak ada reward")
    end
    if Progress.buyTrail and progGate("trail", 60) then
        local bought, folder = false, nil
        local dir = Repo.Directory
        if dir then
            for _, cand in ipairs({ "Trailwear", "Trails", "TrailWear" }) do
                folder = P(function() return dir:FindFirstChild(cand) end)
                if folder then break end
            end
        end
        if folder then
            for _, tr in ipairs(P(function() return folder:GetChildren() end) or {}) do
                if P(function() return Repo.Invoke("RF/Trailwear/AskPurchase", tostring(tr.Name)) end) then
                    bought = true
                end
            end
        end
        Tasks.Status("progress", bought and "Trail dibeli" or "Trail: tidak ada yang bisa dibeli")
    end
end)

--────────────────────────────[ MENU HELPERS ]────────────────────────────

-- ==== BOOT SHIELD v2.0 ====--
-- Pembangunan menu + seluruh boot sequence dibungkus pcall. Kalau game
-- update / API berubah, error muncul sebagai "warn [ThorHub] BOOT GAGAL:"
-- yang jelas — bukan stack trace misterius yang menyesatkan.
local bootOK, bootErr = pcall(function()

local Window = ThorUI:CreateWindow({
    Title = "ThorHub ⚡ Auto Farm",
    Keybind = Enum.KeyCode.RightControl,
    Splash = true,
    ShowToggle = true,
})

QueueElem = QueueElem or {}

local function reg(key, elem)
    Config.Register(key, elem)
    Config.Set(key, elem:Get())
    return elem
end

local function mkToggle(tab, key, name, default, cb, note)
    local e = tab:AddToggle({
        Name = name, Default = default, Note = note or nil,
        Callback = function(v)
            Config.Set(key, v)
            if cb then cb(v) end
        end,
    })
    e.__kind = "toggle"
    return reg(key, e)
end

local function mkSlider(tab, key, name, min, max, default, inc, suffix, cb, note)
    local e = tab:AddSlider({
        Name = name, Min = min, Max = max, Default = default,
        Increment = inc or 1, Suffix = suffix or "", Note = note or nil,
        Callback = function(v)
            Config.Set(key, v)
            if cb then cb(v) end
        end,
    })
    e.__kind = "slider"
    return reg(key, e)
end

local function mkDropdown(tab, key, name, values, default, cb, note)
    local e = tab:AddDropdown({
        Name = name, Values = values, Default = default, Note = note or nil,
        Callback = function(v)
            Config.Set(key, v)
            if cb then cb(v) end
        end,
    })
    e.__kind = "dropdown"
    return reg(key, e)
end

local function mkMulti(tab, key, name, values, cb, note, defaults)
    local e = tab:AddDropdown({
        Name = name, Values = values, Default = defaults or {}, Multi = true,
        Note = note or nil,
        Callback = function(list)
            if type(list) ~= "table" then return end
            Config.Set(key, list)
            if cb then cb(list) end
        end,
    })
    e.__kind = "multi"
    return reg(key, e)
end

local function mkButton(tab, name, cb, note)
    local e = tab:AddButton({ Name = name, Callback = function() task.spawn(cb) end })
    return e
end

local function mkInput(tab, key, name, placeholder, cb)
    local e = tab:AddTextInput({
        Name = name, Placeholder = placeholder or "", ClearOnFocus = false,
        Callback = function(text)
            Config.Set(key, text)
            if cb then cb(text) end
        end,
    })
    e.__kind = "input"
    return reg(key, e)
end

local function mkKeybind(tab, key, name, default, cb)
    local e = tab:AddKeybind({
        Name = name, Default = default,
        Callback = function(bind)
            Config.Set(key, tostring(bind))
            if cb then cb(bind) end
        end,
    })
    e.__kind = "keybind"
    return reg(key, e)
end

local function mkSection(tab, name)
    return tab:AddSection({ Name = name })
end

-- status label: objek dengan SetText supaya Tasks.Status bisa update
local function mkStatus(tab, taskName, initial)
    local e = tab:AddLabel({ Text = initial or "Idle" })
    SetStatusOwner(taskName, {
        SetText = function(_, text)
            P(function() e:Set(text) end)
        end,
    })
    return e
end

-- konversi util
local function rarityNumFromLabel(label)
    if type(label) ~= "string" or label == "Off" then return 0 end
    return Repo.Rarity[label] or 0
end

local function listToSet(list)
    local set = {}
    if type(list) == "table" then
        for _, v in ipairs(list) do set[tostring(v)] = true end
    end
    return set
end

-- daftar nilai dinamis dengan fallback
local eggSpecies, petSpecies = Repo.Species()
if #eggSpecies == 0 then eggSpecies = { "(data tidak tersedia)" } end
if #petSpecies == 0 then petSpecies = { "(data tidak tersedia)" } end
local rarityChoices = {}
do
    table.insert(rarityChoices, "Off")
    for _, r in ipairs(Repo.RarityOrder) do table.insert(rarityChoices, r) end
end
local areaNames = Repo.AreaNames()

--══════════════════════════ TAB 1: FARM ══════════════════════════
local FarmTab = Window:CreateTab({ Name = "Farm", Icon = "⚡" })

mkSection(FarmTab, "Auto Steal")
mkToggle(FarmTab, "farm/steal", "Auto Steal", false, function(v)
    Steal.on = v
    Tasks.Wake("steal")
    if v and StealPanel.autoOpen then StealPanel.Show() end
end)
mkMulti(FarmTab, "farm/areas", "Target Areas", areaNames, function(l) Steal.areas = listToSet(l) end)
mkDropdown(FarmTab, "farm/minrarity", "Min Rarity", rarityChoices, "Off",
    function(v) Steal.minRarity = rarityNumFromLabel(v) end)
mkSlider(FarmTab, "farm/minvalue", "Min Steal Value", 0, 100000, 0, 500, "/s",
    function(v) Steal.minValue = v end)
mkMulti(FarmTab, "farm/specific", "Target Specific Eggs", eggSpecies, function(l) Steal.specific = listToSet(l) end)
mkToggle(FarmTab, "farm/missing", "Steal Missing Index Eggs", false, function(v) Steal.missingIndex = v end)
mkToggle(FarmTab, "farm/dropsafe", "Drop Eggs At Safe Zone", false, function(v) Steal.dropSafe = v end)
mkDropdown(FarmTab, "farm/priority", "Steal Priority",
    { "Best Rarity", "Biggest Weight", "Best Mutation", "Highest Value", "Lowest Value" },
    "Best Rarity", function(v) Steal.priority = v end)
mkSlider(FarmTab, "farm/tweenspeed", "Tween Speed", 50, 120, 100, 5, "", function(v) Steal.tweenSpeed = v end)
mkSlider(FarmTab, "farm/carryspeed", "Carry Speed", 80, 120, 100, 5, "", function(v) Steal.carrySpeed = v end)
-- keluarga metode Instant Steal (pola SafeCarry script asli):
-- V1 antar steps / Fast Delivery, V2 fast tween (zona terbatas),
-- V3 rantai teleport lewat Star Handler / Admin Treadmill.
mkToggle(FarmTab, "farm/instant", "Instant Steal", false, function(v) Steal.instant = v end,
    "Delivers the egg to the safe zone in a few seconds, needs enough Speed")
mkSlider(FarmTab, "farm/instantsteps", "Instant Steal Steps", 1, 6, 3, 1, "",
    function(v) Steal.instantSteps = v end,
    "Higher is safer but takes longer")
mkToggle(FarmTab, "farm/fastdelivery", "Fast Delivery", false, function(v) Steal.fastDelivery = v end,
    "Delivers with the Instant Steal V2 fast tween instead of using steps")
mkToggle(FarmTab, "farm/v2", "Instant Steal V2", false, function(v)
    Steal.v2 = v
    if v then
        -- pola asli: dialog konfirmasi dengan info FPS/ping sebelum menyalakan
        task.spawn(function()
            local okF, fps = P(function() return Steal.V2Fps() end)
            local okP, ping = P(function() return Steal.V2Ping() end)
            fps = (okF and tonumber(fps)) and math.floor(fps) or 0
            ping = (okP and tonumber(ping)) and math.floor(ping) or 0
            P(function()
                Window:Confirm({
                    Title = "Instant Steal V2",
                    Content = string.format(
                        "Your FPS %d, ping %d ms.\nUsing it with Invisibility may cause some bugs.",
                        fps, ping),
                    ConfirmText = "Turn On",
                    CancelText = "Cancel",
                    OnConfirm = function() end,
                    OnCancel = function()
                        local el = Config.Elements["farm/v2"]
                        if el then el:Set(false) end
                    end,
                })
            end)
        end)
    end
end, "Super fast tween delivery (3000-4500 studs/s), only in selected zones")
mkDropdown(FarmTab, "farm/v2approach", "Move To Egg", { "Teleport", "Step" }, "Teleport",
    function(v) Steal.v2Approach = v end,
    "How to reach the egg while Instant Steal V2 is on")
mkSlider(FarmTab, "farm/v2speed", "V2 Tween Speed", 3000, 4500, 3300, 50, "",
    function(v) Steal.v2Speed = v end, "Speed of the fast tween in studs/s")
mkMulti(FarmTab, "farm/v2zones", "Instant Steal Zones",
    { "Titan Temple", "Light Dark", "Enchanted Forest" },
    function(l) Steal.v2Zones = listToSet(l) end,
    "Zones where Instant Steal V2 is used",
    { "Titan Temple", "Light Dark", "Enchanted Forest" })
mkToggle(FarmTab, "farm/v3", "Teleport To Egg", false, function(v) Steal.v3 = v end,
    "(V3) Teleport to the egg, then deliver via Star Handler / Admin Treadmill")
mkStatus(FarmTab, "steal", "Steal: idle")
mkToggle(FarmTab, "farm/panelauto", "Steal Panel Auto Open", true, function(v) StealPanel.autoOpen = v end)
mkButton(FarmTab, "Open Steal Panel", function() StealPanel.Show() end)

mkSection(FarmTab, "Shooting Star")
mkToggle(FarmTab, "farm/star", "Auto Catch Shooting Star", false, function(v) Star.on = v Tasks.Wake("star") end)
mkStatus(FarmTab, "star", "Star: idle")

mkSection(FarmTab, "Butterfly Bloom")
mkToggle(FarmTab, "farm/butter", "Auto Butterfly Bloom", false, function(v) Butter.on = v Tasks.Wake("butterflies") end)
mkDropdown(FarmTab, "farm/buttermode", "Catch Mode", { "Stand", "Chase" }, "Stand", function(v) Butter.mode = v end)
mkDropdown(FarmTab, "farm/butterprio", "Catch Priority", { "Rarest", "Nearest First" }, "Rarest",
    function(v) Butter.priority = v end)
mkMulti(FarmTab, "farm/butterlist", "Catch Butterflies",
    { "Common (Emerald)", "Rare (Sapphire)", "Epic (Amethyst)", "Legendary (Radiant)", "Radiant (Golden)" },
    function(l) Butter.list = {} Butter.onlySet = listToSet(l) end)
mkSlider(FarmTab, "farm/butterspeed", "Tween Speed", 100, 600, 320, 20, "", function(v) Butter.tweenSpeed = v end)
mkToggle(FarmTab, "farm/tradeup", "Auto Trade Up", false, function(v) Butter.tradeUp = v end)
mkMulti(FarmTab, "farm/tiers", "Trade Up Tiers",
    { "Common (Emerald)", "Rare (Sapphire)", "Epic (Amethyst)", "Legendary (Radiant)", "Radiant (Golden)" },
    function(l) Butter.tiers = listToSet(l) end)
mkToggle(FarmTab, "farm/essence", "Smart Trade For Essence", false, function(v) Butter.essence = v end)
mkToggle(FarmTab, "farm/craft", "Auto Craft Essence", false, function(v) Butter.craft = v end)
mkStatus(FarmTab, "butterflies", "Butterflies: idle")

mkSection(FarmTab, "Wisp & Banjo")
mkToggle(FarmTab, "farm/wisp", "Auto Wisp", false, function(v) Wisp.on = v Tasks.Wake("wisp") end)
mkSlider(FarmTab, "farm/wispneed", "Wisp Speed Power (B)", 1, 10000, 100, 100, "B",
    function(v) Wisp.threshold = v * 1e9 end)
mkToggle(FarmTab, "farm/banjo", "Auto Banjo Cricket", false, function(v) Banjo.on = v end)
mkStatus(FarmTab, "wisp", "Wisp: idle")

mkSection(FarmTab, "Auto Mutation")
mkToggle(FarmTab, "farm/mutate", "Auto Mutate", false, function(v) Mutate.on = v Tasks.Wake("mutate") end)
mkMulti(FarmTab, "farm/mutlist", "Mutations To Use",
    { "Scrambled", "Golden", "Rainbow", "Silver", "Bloom", "Spirit Bloom",
      "Fractured", "Enchanted", "Parasite", "Nitro", "Spectral",
      "Boss", "Monstrous", "Sakura", "GreatBloom" },
    function(l) Mutate.use = listToSet(l) end)
mkDropdown(FarmTab, "farm/mutrarity", "Mutate Min Rarity", rarityChoices, "Off",
    function(v) Mutate.minRarity = rarityNumFromLabel(v) end)
mkSlider(FarmTab, "farm/mutvalue", "Mutate Min Value", 0, 100000, 0, 500, "/s",
    function(v) Mutate.minValue = v end)
mkMulti(FarmTab, "farm/muttarget", "Mutate Target Eggs", eggSpecies, function(l) Mutate.targets = listToSet(l) end)
mkDropdown(FarmTab, "farm/mutprio", "Mutate Priority",
    { "Highest Value", "Best Rarity", "Biggest Size" }, "Highest Value", function(v) Mutate.priority = v end)
mkStatus(FarmTab, "mutate", "Mutation: idle")

mkSection(FarmTab, "Auto Place Egg")
mkToggle(FarmTab, "farm/place", "Auto Place Egg", false, function(v) Place.on = v Tasks.Wake("place") end)
mkDropdown(FarmTab, "farm/placerule", "Place Egg Rule",
    { "Always", "Steal Idle", "After Steal", "Night Only" }, "Always", function(v) Place.rule = v end)
mkDropdown(FarmTab, "farm/placeorder", "Place Egg Order",
    { "Biggest Size", "Highest Value", "Smallest Size" }, "Biggest Size", function(v) Place.order = v end)
mkMulti(FarmTab, "farm/placerarity", "Place Rarities", Repo.RarityOrder, function(l) Place.rarities = listToSet(l) end)
mkMulti(FarmTab, "farm/placespecific", "Place Specific Eggs", eggSpecies, function(l) Place.specific = listToSet(l) end)
mkSlider(FarmTab, "farm/placevalue", "Min Place Value", 0, 100000, 0, 500, "/s", function(v) Place.minValue = v end)
mkStatus(FarmTab, "place", "Place: idle")

mkSection(FarmTab, "Auto Treadmill")
mkToggle(FarmTab, "farm/tread", "Auto Treadmill", false, function(v) Tread.on = v Tasks.Wake("treadride") end)
mkToggle(FarmTab, "farm/treadup", "Auto Upgrade Treadmill", false, function(v) Tread.upgrade = v end)
mkToggle(FarmTab, "farm/treadadmin", "Use Admin Treadmill", false, function(v) Tread.admin = v end)
mkStatus(FarmTab, "treadmill", "Treadmill: idle")

mkSection(FarmTab, "Auto Hatch & Equip")
mkToggle(FarmTab, "farm/hatch", "Auto Hatch", false, function(v) Hatch.on = v Tasks.Wake("hatch") end)
mkDropdown(FarmTab, "farm/hatchrarity", "Hatch Min Rarity", rarityChoices, "Off",
    function(v) Hatch.minRarity = rarityNumFromLabel(v) end)
mkSlider(FarmTab, "farm/hatchvalue", "Min Hatch Value", 0, 100000, 0, 500, "/s", function(v) Hatch.minValue = v end)
mkMulti(FarmTab, "farm/hatchlist", "Hatch Specific Eggs", eggSpecies, function(l) Hatch.specific = listToSet(l) end)
mkToggle(FarmTab, "farm/equipbest", "Auto Equip Best", false, function(v) Hatch.equipBest = v end)
mkStatus(FarmTab, "hatch", "Hatch: idle")

mkSection(FarmTab, "Auto Sell")
mkToggle(FarmTab, "farm/sellpet", "Auto Sell Pet", false, function(v) Sell.petOn = v Tasks.Wake("sell") end)
mkButton(FarmTab, "Sell Pets Now", function() Sell.RunOnce() end)
mkDropdown(FarmTab, "farm/sellpetrule", "Sell Pet Rule",
    { "Rarity Only", "Value Only", "Rarity And Value", "Rarity Or Value" },
    "Rarity And Value", function(v) Sell.petRule = v end)
mkDropdown(FarmTab, "farm/sellpetmax", "Pet Max Rarity", rarityChoices, "Epic",
    function(v) Sell.petMax = rarityNumFromLabel(v) end)
mkSlider(FarmTab, "farm/sellpetvalue", "Pet Sell Value", 0, 100000, 0, 500, "/s",
    function(v) Sell.petValue = v end)
mkToggle(FarmTab, "farm/keepmutpet", "Keep Mutated Pets", true, function(v) Sell.petKeepMut = v end)
mkMulti(FarmTab, "farm/blackpet", "Blacklist Sell Pets", petSpecies, function(l) Sell.petBlack = listToSet(l) end)
mkToggle(FarmTab, "farm/sellegg", "Auto Sell Egg", false, function(v) Sell.eggOn = v end)
mkButton(FarmTab, "Sell Eggs Now", function() Sell.RunOnce() end)
mkDropdown(FarmTab, "farm/selleggrule", "Sell Egg Rule",
    { "Rarity Only", "Value Only", "Rarity And Value", "Rarity Or Value" },
    "Rarity And Value", function(v) Sell.eggRule = v end)
mkDropdown(FarmTab, "farm/selleggmax", "Egg Max Rarity", rarityChoices, "Epic",
    function(v) Sell.eggMax = rarityNumFromLabel(v) end)
mkSlider(FarmTab, "farm/selleggvalue", "Egg Sell Value", 0, 100000, 0, 500, "/s",
    function(v) Sell.eggValue = v end)
mkToggle(FarmTab, "farm/keepmutegg", "Keep Mutated Eggs", true, function(v) Sell.eggKeepMut = v end)
mkMulti(FarmTab, "farm/blackegg", "Blacklist Sell Eggs", eggSpecies, function(l) Sell.eggBlack = listToSet(l) end)
mkStatus(FarmTab, "sell", "Sell: idle")

mkSection(FarmTab, "Auto Fuse Machine")
mkToggle(FarmTab, "farm/fuse", "Auto Fuse Machine", false, function(v) Fuse.on = v Tasks.Wake("fuse") end)
mkDropdown(FarmTab, "farm/fusemode", "Fuse Priority Mode",
    { "Lowest Rarity First", "Highest Rarity First", "Most Copies First", "Lowest Value First" },
    "Lowest Rarity First", function(v) Fuse.mode = v end)
mkDropdown(FarmTab, "farm/fuseorder", "Pets To Use",
    { "Lowest To Highest", "Highest To Lowest" }, "Lowest To Highest", function(v) Fuse.order = v end)
mkDropdown(FarmTab, "farm/fusemax", "Max Rarity to Fuse", rarityChoices, "Divine",
    function(v) Fuse.maxRarity = rarityNumFromLabel(v) == 0 and 10 or rarityNumFromLabel(v) end)
mkMulti(FarmTab, "farm/fusespecies", "Specific Species to Fuse", petSpecies, function(l) Fuse.species = listToSet(l) end)
mkToggle(FarmTab, "farm/fuseskipmut", "Skip Mutated Pets", true, function(v) Fuse.skipMut = v end)
mkToggle(FarmTab, "farm/fuseeject", "Eject Incomplete Slots", true, function(v) Fuse.eject = v end)
mkStatus(FarmTab, "fuse", "Fuse: idle")

mkSection(FarmTab, "Auto Favorite")
mkToggle(FarmTab, "farm/fav", "Auto Favorite Pet", false, function(v) Fav.on = v Tasks.Wake("fav") end)
mkButton(FarmTab, "Favorite Pets Now", function() Fav.RunOnce(false) end)
mkDropdown(FarmTab, "farm/favrule", "Favorite Rule", { "Match Any", "Match All" }, "Match Any",
    function(v) Fav.rule = v end)
mkDropdown(FarmTab, "farm/favrarity", "Favorite Min Rarity", rarityChoices, "Off",
    function(v) Fav.minRarity = rarityNumFromLabel(v) end)
mkSlider(FarmTab, "farm/favvalue", "Min Favorite Value", 0, 100000, 0, 500, "/s", function(v) Fav.minValue = v end)
mkMulti(FarmTab, "farm/favmut", "Favorite Mutations",
    { "Any Mutation", "No Mutation", "Golden", "Silver", "Rainbow", "Boss", "Monstrous", "Sakura", "GreatBloom" },
    function(l) Fav.mutations = listToSet(l) end)
mkMulti(FarmTab, "farm/favspecies", "Always Favorite Species", petSpecies, function(l) Fav.species = listToSet(l) end)
mkToggle(FarmTab, "farm/favequip", "Auto Favorite Equipped", false, function(v) Fav.equipped = v end)
mkToggle(FarmTab, "farm/favunequip", "Auto Unfavorite Equipped", false, function(v) Fav.unfav = v end)
mkButton(FarmTab, "Favorite Equipped Now", function() Fav.RunOnce(false) end)
--════════════ BAGIAN 7 — TAB CONFIG & BOOT ════════════
--══════════════════════════ TAB 2: CONFIG ══════════════════════════
--────────────────────────────[ TAB: AUTO HOP + PROGRESS ]────────────────────────────
-- Paritas struktur kode baru (SAE v172610): tab "Auto Hop | Egg Finder"
-- dan tab "Progress | Auto Progression".

local HopTab = Window:CreateTab({ Name = "Auto Hop", Icon = "🥚" })
mkSection(HopTab, "Egg Finder")
mkToggle(HopTab, "hop/on", "Auto Hop", false, function(v)
    AutoHop.on = v
    AutoHop.tOn = os.clock()
    AutoHop.busy = false
    AutoHop.seen = {}
    if type(Gill) == "table" then
        if v then Gill.__THORHUB_AUTOHOP = true else Gill.__THORHUB_AUTOHOP = nil end
    end
    Tasks.Wake("autohop")
end)
mkDropdown(HopTab, "hop/mode", "Hop Mode",
    { "Until An Egg Matches", "Steal Then Hop", "After A Rare Spawns" },
    "Until An Egg Matches", function(v) AutoHop.mode = v end)
mkDropdown(HopTab, "hop/rarity", "Rarity To Wait For", rarityChoices, "Mythic",
    function(v) AutoHop.waitRarity = v end)
mkSlider(HopTab, "hop/firstdelay", "First Hop Delay", 5, 120, 20, 1, "s",
    function(v) AutoHop.firstDelay = v end)
P(function()
    HopTab:AddParagraph({
        Title = "Cara kerja Auto Hop",
        Text = "Pindah server otomatis sampai ketemu egg sesuai Rarity To Wait For. "
            .. "Steal Then Hop: pindah setelah tiap sukses curi. After A Rare Spawns: "
            .. "pindah begitu egg rare+ terdeteksi spawn. Status ON dipulihkan otomatis "
            .. "setelah pindah server.",
    })
end)

local ProgTab = Window:CreateTab({ Name = "Progress", Icon = "📈" })
mkSection(ProgTab, "Auto Progression")
mkToggle(ProgTab, "prog/upbase", "Auto Upgrade Base", false, function(v)
    Progress.upBase = v Tasks.Wake("progress")
end)
mkToggle(ProgTab, "prog/claimcash", "Auto Claim Money", false, function(v)
    Progress.claimCash = v Tasks.Wake("progress")
end)
mkToggle(ProgTab, "prog/claimindex", "Auto Claim Index", false, function(v)
    Progress.claimIndex = v Tasks.Wake("progress")
end)
mkToggle(ProgTab, "prog/buytrail", "Auto Buy Trail", false, function(v)
    Progress.buyTrail = v Tasks.Wake("progress")
end)
P(function()
    ProgTab:AddParagraph({
        Title = "Catatan",
        Text = "Paritas tab Progress dari kode baru (SAE v172610). Auto Upgrade "
            .. "Treadmill tetap ada di tab Farm. Auto Buy Trail membeli semua trail "
            .. "yang tersedia di asset Directory.",
    })
end)

local ConfigTab = Window:CreateTab({ Name = "Config", Icon = "💾" })

local configListLabel = nil
local function refreshConfigLabel()
    if not configListLabel then return end
    local names = Config.FileList()
    local line = "Configs tersedia: " .. table.concat(names, ", ")
    P(function() configListLabel:Set(line) end)
end

mkSection(ConfigTab, "Defaults")
mkButton(ConfigTab, "Reset to Defaults", function()
    Config.Data = {}
    Notify("Config", "Semua pengaturan direset (reload script untuk efek penuh)", 4)
end)
mkButton(ConfigTab, "Turn Off All Toggles", function() Config.WriteAllOff() end)

mkSection(ConfigTab, "Configs")
configListLabel = ConfigTab:AddLabel({ Text = "Configs: memuat..." })
mkToggle(ConfigTab, "cfg/autosave", "Auto Save Config", false, function(v) Config.AutoSave = v Config.SaveState() end)
mkToggle(ConfigTab, "cfg/autoload", "Auto Load Config", true, function(v) Config.AutoLoad = v Config.SaveState() end)
mkInput(ConfigTab, "cfg/newname", "New Config Name", "nama config baru...")
mkButton(ConfigTab, "Create New Config", function()
    local el = Config.Elements["cfg/newname"]
    local name = el and tostring(el:Get() or "") or ""
    if name == "" then Notify("Config", "Isi nama dulu", 3) return end
    Config.Name = name
    Config.Save(name)
    Config.SaveState()
    refreshConfigLabel()
    Notify("Config", "Config dibuat: " .. name, 3)
end)
mkButton(ConfigTab, "Save Config", function()
    Config.Save(Config.Name)
    Notify("Config", "Tersimpan ke: " .. Config.Name, 3)
    refreshConfigLabel()
end)
mkButton(ConfigTab, "Load Config", function()
    local el = Config.Elements["cfg/newname"]
    local name = el and tostring(el:Get() or "") or ""
    if name == "" then name = Config.Name end
    local ok = Config.Load(name, true)
    Notify("Config", ok and ("Dimuat: " .. name) or "Gagal memuat (cek nama)", 4)
end)
mkButton(ConfigTab, "Delete Config", function()
    local el = Config.Elements["cfg/newname"]
    local name = el and tostring(el:Get() or "") or ""
    if name == "" then Notify("Config", "Isi nama config yang mau dihapus", 3) return end
    Config.Delete(name)
    refreshConfigLabel()
    Notify("Config", "Dihapus (kalau ada): " .. name, 3)
end)
mkButton(ConfigTab, "Set Startup Config", function()
    local el = Config.Elements["cfg/newname"]
    local name = el and tostring(el:Get() or "") or Config.Name
    Config.Startup = name
    Config.SaveState()
    Notify("Config", "Startup config: " .. name, 3)
end)

mkSection(ConfigTab, "Import / Export")
mkButton(ConfigTab, "Export Config", function()
    local payload = { __thorhub = true, States = Config.Data }
    local json = jsonEnc(payload)
    if not json then Notify("Config", "Encode gagal", 3) return end
    if setclipboard then
        pcall(setclipboard, json)
        Notify("Config", "Config disalin ke clipboard", 3)
    else
        Notify("Config", "Executor tidak punya setclipboard", 3)
    end
end)
mkInput(ConfigTab, "cfg/import", "Import Config Text", "tempel JSON config di sini...")
mkButton(ConfigTab, "Import Config", function()
    local el = Config.Elements["cfg/import"]
    local json = el and tostring(el:Get() or "") or ""
    if json == "" then Notify("Config", "Tempel JSON dulu", 3) return end
    local data = jsonDec(json)
    if not data or type(data.States) ~= "table" then Notify("Config", "JSON tidak valid", 3) return end
    for k, v in pairs(data.States) do Config.Set(k, v) end
    for key, value in pairs(data.States) do
        local elem = Config.Elements[key]
        if elem and elem.Set then P(function() elem:Set(value, false) end) end
    end
    Notify("Config", "Config diimpor", 3)
end)

mkSection(ConfigTab, "Info")
ConfigTab:AddParagraph({
    Title = "ThorHub — Auto Farm (Steal an Egg)",
    Text = "Edisi Auto Farm: hanya fitur farming + UI floating ThorUi. "
        .. "Semua fitur native, tanpa obfuscate, tanpa promosi. Basis: kode baru "
        .. "Chilli (SAE v172610, Okt 2026) - fitur farm diparitaskan penuh. "
        .. "PENTING: jalankan script ini SAJA — jangan bersamaan dengan script hub "
        .. "lain (mis. Chilli Hub); dua engine farm yang jalan bareng bisa saling "
        .. "ganggu dan memunculkan error. Error console dengan nama script acak "
        .. "(kode LPH, huruf acak 20+ karakter) berasal dari script Chilli Hub lain "
        .. "yang masih berjalan di executor (cek tab Auto-Exec), BUKAN dari ThorHub - "
        .. "log ThorHub selalu berawalan [ThorHub]. Data game: Directory "
        .. (Repo.DirectoryOK and "OK" or "n/a") .. ", Save replica "
        .. (Repo.SaveOK and "OK" or "n/a") .. ", Filesystem "
        .. (FS.ok and "OK" or "n/a") .. ".",
})

--────────────────────────────[ BOOT SEQUENCE ]────────────────────────────

refreshConfigLabel()

-- muat config tersimpan
Config.LoadState()
if Config.AutoLoad and FS.ok then
    local target = Config.Startup or Config.Name
    if target then
        local ok = Config.Load(target, true)
        if ok then
            task.delay(1.5, function()
                Notify("💾 Config", "Config dimuat: " .. target, 3)
            end)
        end
    end
end

-- Steal Panel: pulihkan status terbuka (default terbuka, ala script asli)
task.delay(1.2, function()
    local saved = Config.Get("panel/open")
    if saved == nil and Gill then saved = Gill.__THORHUB_PANEL_OPEN end
    if saved ~= false then
        StealPanel.Show()
        print("[ThorHub] 2 UI aktif: menu utama + panel daftar telur (ala script asli)")
    end
end)

-- Auto Hop: pulihkan ON setelah hop server (flag genv, basis kode baru)
if type(Gill) == "table" and Gill.__THORHUB_AUTOHOP then
    task.delay(1.5, function()
        local el = Config.Elements["hop/on"]
        if el and el.Set then
            P(function() el:Set(true, true) end)
        end
    end)
end

-- auto load setelah teleport (queueReload cek queue_on_teleport sendiri)
queueReload()

-- reset visibility saat respawn
LocalPlayer.CharacterAdded:Connect(function(char)
    char:WaitForChild("Humanoid", 10)
    task.wait(0.5)
    Character.OnDeathReset()
end)

-- cleanup & destroy handler
local function DestroyAll()
    pcall(function() StealPanel.Destroy() end)
    Character.ApplyInvisibility(false)
    if ThorUI then P(function() ThorUI:Destroy() end) end
end

Gill.__THORHUB_AF_LOADED = true
Gill.__THORHUB_AF_DESTROY = DestroyAll

Notify("⚡ ThorHub", "Auto Farm siap! Menu dibangun 100% dari ThorUi.", 6)
if not Repo.DirectoryOK then
    task.delay(2, function()
        Notify("ThorHub", "Asset Directory tidak ketemu — beberapa filter memakai fallback", 6)
    end)
end
if not Repo.SaveOK then
    task.delay(3, function()
        Notify("ThorHub", "Save replica tidak ketemu — fitur inventaris (Sell/Fuse/Fav) terbatas", 6)
    end)
end
end)
if bootOK then
    print("[ThorHub] Menu siap. Buka/tutup: tombol petir melayang atau RightControl.")
else
    warn("[ThorHub] BOOT GAGAL: " .. tostring(bootErr))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "ThorHub - Gagal Start",
            Text = "Menu gagal dibangun (cek console [ThorHub]).",
            Duration = 10,
        })
    end)
end
