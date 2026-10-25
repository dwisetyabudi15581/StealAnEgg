--[[════════════════════════════════════════════════════════════════════════════
  ⚡ THORHUB — AUTO FARM (Steal an Egg)
  Edisi khusus AUTO FARM: hanya mesin farming + UI floating (ThorUi ⚡).
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
do
    -- loader tangguh (fetchLua): retry + mirror CDN jsDelivr + validasi
    -- isi — cegah "attempt to call a nil value" saat raw.githubusercontent
    -- balas 404/rate-limit sesaat lewat proxy executor.
    -- minLen cukup kecil (300): cukup menyaring halaman 404/429 tanpa
    -- menolak library kecil.
    local ok, lib = pcall(function()
        local src = fetchLua("ThorUi", { THORUI_URL, mirrorUrl(THORUI_URL) }, 300)
        local chunk = assert(loadstring(src), "ThorUi parse gagal")
        return chunk()
    end)
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

--────────────────────────────[ MENU HELPERS ]────────────────────────────

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
    { "Golden", "Silver", "Rainbow", "Boss", "Monstrous", "Sakura", "GreatBloom" },
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
        .. "Semua fitur native, tanpa obfuscate, tanpa promosi. Data game: Directory "
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
    if saved ~= false then StealPanel.Show() end
end)

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
