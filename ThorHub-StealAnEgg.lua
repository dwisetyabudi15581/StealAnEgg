--════════════ PART: p1_header.lua ════════════
--[[════════════════════════════════════════════════════════════════════════════
  ⚡ THORHUB — STEAL AN EGG
  Tulis-ulang TOTAL dari nol. Menu 100% dibangun dari ThorUi.
  Semua fitur diimplementasi ulang secara native (tanpa kode obfuscate).
  Tanpa promosi apa pun: tidak ada link Discord pihak ketiga, tidak ada
  bootstrap pihak ketiga, tidak ada teks "Chilli/Venyx".

  Sumber identitas fitur (dipetakan dari script asli):
    - Struktur menu: Farm / Admin / Player / Predictor / Progress /
      Server / Misc / Quick / Config
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
if Gill.__THORHUB_SAE_LOADED then
    local old = Gill.__THORHUB_SAE_DESTROY
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
local SOURCE_URL = "https://raw.githubusercontent.com/dwisetyabudi15581/StealAnEgg/main/ThorHub-StealAnEgg.lua"
local THORUI_URL = "https://raw.githubusercontent.com/dwisetyabudi15581/ThorUi/main/ThorUi.lua"

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
    local w = Repo.World()
    if w then
        local f = w:FindFirstChild("WorldEggs")
        if f then return f end
    end
    return workspace:FindFirstChild("WorldEggs")
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
local snapCache, snapAt = nil, -math.huge
function Repo.FieldSnapshot(maxAge)
    local now = os.clock()
    if snapCache and now - snapAt < (maxAge or 2) then return snapCache end
    local res = Repo.Invoke("RF/EggWorld/AskFieldEggSnapshot")
    if type(res) == "table" then
        snapCache = res
        snapAt = now
        return res
    end
    return snapCache
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

--════════════ PART: p2_movement.lua ════════════
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
function Movement.CarryTo(pos, done, timeout, lift)
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
        local spd = math.min(Movement.WalkSpeed() * 1.5, delta.Magnitude / 0.05)
        local vel = Vector3.new(0, 0, 0)
        if delta.Magnitude > 3 then
            vel = delta.Unit * spd
        end
        vel = vel + Vector3.new(0, (heldY - root.Position.Y) * 8, 0)
        pcall(function() root.AssemblyLinearVelocity = vel end)
        task.wait()
    end
    root = Movement.Root()
    if root then pcall(function() root.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end) end
    for p in pairs(collided) do
        if p.Parent then pcall(function() p.CanCollide = true end) end
    end
end

-- deteksi "saya memegang egg": weld ke model yang dibawa
function Movement.HeldModel()
    local root = Movement.Root()
    local char = LocalPlayer.Character
    if not root or not char then return nil end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            return tool
        end
    end
    return nil
end

function Movement.CarryingUid()
    -- egg yang sedang dibawa: cari weld antara karakter dan model egg di workspace
    local char = LocalPlayer.Character
    if not char then return nil, nil end
    local carried = char:FindFirstChildOfClass("Tool")
    if carried then
        local uid = carried:GetAttribute("Uid") or carried.Name
        return tostring(uid), carried
    end
    return nil, nil
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
    local endT = tonumber(char:GetAttribute("RagdollEndTime"))
    if endT and endT > workspace:GetServerTimeNow() then
        pcall(function() char:SetAttribute("RagdollEndTime", 0) end)
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        if hum.PlatformStand then hum.PlatformStand = false end
        if hum:GetState() == Enum.HumanoidStateType.Physics or hum:GetState() == Enum.HumanoidStateType.Ragdoll then
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

--════════════ PART: p3_farm.lua ════════════
--────────────────────────────[ EGG STATE (native) ]────────────────────────────
-- Pengganti "EggState" internal script asli, dibangun dari data yang
-- bisa dibaca client: replica Save (jika ketemu) + WorldEggs + snapshot RF.

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

function EggState.FieldEggs()
    -- egg di lapangan: model di WorldEggs dengan StealPrompt aktif
    local out = {}
    local folder = Repo.WorldEggs()
    if not folder then return out end
    for _, model in ipairs(folder:GetChildren()) do
        local prompt = model:FindFirstChild("StealPrompt", true)
        if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled then
            local name = Repo.EggName(model)
            local label, num = Repo.RarityOf(name)
            local scale = Repo.ScaleOf(model)
            local pos = P(function()
                if model:IsA("Model") then return model:GetPivot().Position else return model.CFrame.Position end
            end)
            table.insert(out, {
                Model = model, Prompt = prompt, Name = name,
                RarityLabel = label, RarityNum = num, Scale = scale,
                Value = Repo.EggValue(name, scale),
                Mutations = {},
                Pos = pos,
                Zone = model:GetAttribute("Zone"),
                HwUid = model:GetAttribute("HalloweenEggUid"),
            })
        end
    end
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
    missingIndex = false, dropSafe = false, priority = "Best Rarity",
    tweenSpeed = 100, carrySpeed = 100, instant = false, v2 = false, v3 = true,
    busy = false, bad = {}, stolen = 0, best = nil, bestRank = -1,
    history = {}, lastDeliver = 0,
}

local function stealAreaOk(egg)
    if next(Steal.areas) == nil then return true end
    local zone = egg.Zone and tostring(egg.Zone) or nil
    if zone and Steal.areas[zone] then return true end
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
    if next(Steal.specific) ~= nil and not Steal.specific[egg.Name] then return false end
    if Steal.minRarity > 0 and egg.RarityNum < Steal.minRarity then return false end
    if Steal.minValue > 0 and egg.Value < Steal.minValue then return false end
    if Steal.missingIndex and not Repo.IndexMissing(egg.Name) then return false end
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
    local best, bestScore = nil, -math.huge
    local now = os.clock()
    for _, egg in ipairs(EggState.FieldEggs()) do
        if not (Steal.bad[egg.Model] and Steal.bad[egg.Model] > now) then
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

local function fireStealPrompt(egg)
    local prompt = egg.Prompt
    if not prompt or not prompt.Parent then return false end
    pcall(function() prompt.HoldDuration = 0 end)
    if fireproximityprompt then
        pcall(fireproximityprompt, prompt)
        return true
    end
    -- fallback: sentuh prompt secara langsung (executor tanpa fire helper)
    pcall(function() prompt:InputHoldBegin() prompt:InputHoldEnd() end)
    return true
end

local function isCarrying()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Tool") ~= nil
end

local function deliverEgg(tool)
    -- bawa egg pulang: ke base (auto-redeem) atau drop di safe zone
    local claimed = Movement.Claim("steal")
    local startedAt = os.clock()
    Tasks.Status("steal", "HOLD EGG  |  delivering")
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

    local speed = Steal.carrySpeed / 100
    Movement.CarryTo(target, function()
        return not isCarrying()
    end, 45, speed)

    -- beri kesempatan server redeem
    local t = os.clock() + 3.5
    while isCarrying() and os.clock() < t do
        task.wait(0.1)
    end
    if isCarrying() then
        -- mungkin belum sampai zona redeem: lepas tool di dekat target
        local hum = Movement.Humanoid()
        if hum then pcall(function() hum:UnequipTools() end) end
    end
    Movement.Release("steal")
    Steal.busy = false
end

local function stealEgg(egg)
    local claimed = Movement.Claim("steal")
    if not claimed then
        Steal.busy = false
        return
    end
    local model = egg.Model
    Tasks.Status("steal", "FLY TO EGG  |  " .. tostring(egg.Name))
    local attempt = 0
    while attempt < 3 do
        attempt = attempt + 1
        if not model.Parent or not egg.Prompt or not egg.Prompt.Enabled then break end
        -- terbang mendekati prompt
        local deadline = os.clock() + 3
        while os.clock() < deadline do
            local root = Movement.Root()
            if not root then break end
            if not model.Parent then break end
            local pos = P(function()
                if model:IsA("Model") then return model:GetPivot().Position else return model.CFrame.Position end
            end)
            if not pos then break end
            local d = pos - root.Position
            local step = Steal.instant and 60 or (Steal.tweenSpeed / 100 * 40)
            if d.Magnitude < 5 then
                fireStealPrompt(egg)
                if isCarrying() then break end
                task.wait(0.06)
            else
                Movement.StepTo(pos + Vector3.new(0, 3, 0), step)
            end
            task.wait()
        end
        -- last push: tembak prompt beberapa kali
        local t = os.clock() + 1.2
        while os.clock() < t and not isCarrying() and model.Parent do
            fireStealPrompt(egg)
            task.wait(0.12)
        end
        if isCarrying() then break end
        task.wait(0.2)
    end

    if isCarrying() then
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
        deliverEgg(LocalPlayer.Character:FindFirstChildOfClass("Tool"))
    else
        -- gagal: blacklist sebentar
        Steal.bad[model] = os.clock() + 20
        Tasks.Status("steal", "Steal gagal, egg diblacklist 20s")
        Movement.Release("steal")
        Steal.busy = false
    end
end

Tasks.Add("steal", 0.4, function()
    if not Steal.on then return end
    if Steal.busy then return end
    if isCarrying() then
        Steal.busy = true
        task.spawn(deliverEgg, LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool"))
        return
    end
    local target = pickStealTarget()
    if target then
        Steal.busy = true
        task.spawn(stealEgg, target)
    else
        Tasks.Status("steal", "Idle  |  menunggu egg yang cocok")
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

local ClaimState = { claim = false, index = false }

Tasks.Add("claim", 15.0, function()
    if not ClaimState.claim then return end
    local pending = Repo.Invoke("RF/AwayEarnings/PendingCheck")
    if type(pending) == "number" and pending > 0 then
        Repo.Invoke("RF/AwayEarnings/AskCollect")
        Notify("Claim", "Offline cash di-claim", 3)
    elseif type(pending) == "table" and pending.amount then
        Repo.Invoke("RF/AwayEarnings/AskCollect")
    end
end)

Tasks.Add("claimindex", 25.0, function()
    if not ClaimState.index then return end
    Repo.Invoke("RF/Codex/AskRedeemAll")
    task.wait(0.2)
    Repo.Invoke("RF/Codex/AskRedeemLimitedEgg")
end)

local BaseState = { upgrade = false }

Tasks.Add("baseupgrade", 5.0, function()
    if not BaseState.upgrade then return end
    local save = Repo.SaveData()
    if type(save) ~= "table" then return end
    local level = tonumber(save.BaseUpgradeLevel) or 0
    local mod = P(function()
        return require(ReplicatedStorage:WaitForChild("Data", 5):WaitForChild("Bases", 3))
    end)
    if type(mod) ~= "table" then return end
    local bases = mod.BASES or mod
    local nextB = bases[level + 1] or (type(mod.GetByLevel) == "function" and P(mod.GetByLevel, level + 1))
    local cost = nextB and tonumber(nextB.Cost)
    if cost and Repo.Money() >= cost then
        Repo.Fire("RE/Homestead/AskBaseTierRaise")
        Tasks.Status("base", "Base upgraded ke " .. tostring(level + 1))
    elseif cost then
        Tasks.Status("base", "Nabung base: $" .. fmtNum(cost))
    end
end)

local TrailState = { buy = false }

Tasks.Add("trail", 12.0, function()
    if not TrailState.buy then return end
    local mod = P(function()
        return require(ReplicatedStorage:WaitForChild("Data", 5):WaitForChild("Trails", 3))
    end)
    if type(mod) ~= "table" then return end
    for id, trail in pairs(mod) do
        if type(trail) == "table" then
            local price = tonumber(trail.Price or trail.Cost)
            if price and price > 0 and Repo.Money() >= price then
                local ok = Repo.Invoke("RF/Trailwear/AskPurchase", id)
                if ok then
                    Notify("Trail", "Trail dibeli ($" .. fmtNum(price) .. ")", 3)
                    break
                end
            end
        end
    end
end)

--────────────────────────────[ AUTO FARM MONSTERS ]────────────────────────────

local Monsters = { on = false, list = {}, order = "Closest", busy = false,
                   names = {
                       ["Candy Corn"] = "Candy Corn", ["Hollow Bat"] = "Hollow Bat",
                       ["Scarecrow"] = "Scarecrow", ["Chest Mimic"] = "Chest Mimic",
                       ["Pumpkin Golem"] = "Pumpkin Golem", ["Soul Phantom"] = "Soul Phantom",
                   } }

local function findMonsters()
    local out = {}
    local root = Movement.Root()
    for _, inst in ipairs(Scan.Workspace()) do
        if inst:IsA("Model") and inst.Parent then
            local n = inst.Name
            if Monsters.names[n] or (n:find("Monster", 1, true) and inst:GetAttribute("MonsterSize")) then
                local hum = inst:FindFirstChildOfClass("Humanoid")
                local hp = hum and hum.Health
                if hp and hp > 0 then
                    local pos = P(function() return inst:GetPivot().Position end)
                    if pos then table.insert(out, { model = inst, pos = pos }) end
                end
            end
        end
    end
    if root then
        table.sort(out, function(a, b)
            if Monsters.order == "Closest" then
                return (a.pos - root.Position).Magnitude < (b.pos - root.Position).Magnitude
            end
            return false
        end)
    end
    return out
end

Tasks.Add("monsters", 0.8, function()
    if not Monsters.on then return end
    if Monsters.busy then return end
    if next(Monsters.list) == nil then return end
    if Movement.Owner and Movement.Owner ~= "monster" then return end
    local targets = {}
    for _, m in ipairs(findMonsters()) do
        if Monsters.list[m.model.Name] then table.insert(targets, m) end
    end
    if #targets == 0 then Tasks.Status("monsters", "Tidak ada monster target") return end
    Monsters.busy = true
    task.spawn(function()
        local t = targets[1]
        if Movement.Claim("monster") then
            Tasks.Status("monsters", "Menyerang " .. tostring(t.model.Name))
            local deadline = os.clock() + 12
            while os.clock() < deadline and t.model.Parent do
                local root = Movement.Root()
                local pos = P(function() return t.model:GetPivot().Position end)
                if not root or not pos then break end
                if (pos - root.Position).Magnitude > 6 then
                    Movement.StepTo(pos, 35)
                else
                    Repo.Fire("RE/ToolTrigger/Trigger")
                    Repo.Fire("RE/BatSwing/Trigger")
                end
                task.wait(0.12)
            end
            Movement.Release("monster")
        end
        Monsters.busy = false
    end)
end)

--════════════ PART: p4_events.lua ════════════
--────────────────────────────[ WEBHOOK (milik user sendiri) ]────────────────────────────
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

--────────────────────────────[ EGG PREDICTOR ]────────────────────────────

local Predictor = { sortBy = "Value", list = {}, lastFetch = 0, preview = true }

function Predictor.Fetch()
    local now = os.clock()
    if now - Predictor.lastFetch < 2 then return end
    Predictor.lastFetch = now
    local res = Repo.Invoke("RF/LiveEvents/FetchRunning")
    if type(res) == "table" then
        Predictor.list = res
    end
end

Repo.Connect("RE/LiveEvents/Began", function(ev)
    if type(ev) == "table" then
        local name = tostring(ev.AssetCategory or ev.Name or ev.Type or "?")
        local _, num = Repo.RarityOf(name)
        Notify("🔮 Event mulai", name, 4)
        Webhook.Post("Rare Spawn", "Event baru: **" .. name .. "**", num)
    end
end)

Repo.Connect("RE/LiveEvents/Ended", function(ev)
    if type(ev) == "table" then
        Tasks.Wake("predictor")
    end
end)

Tasks.Add("predictor", 2.0, function()
    Predictor.Fetch()
    local rows = {}
    local entries = {}
    -- bentuk data bisa array atau map
    if type(Predictor.list) == "table" then
        for _, ev in pairs(Predictor.list) do
            if type(ev) == "table" then
                table.insert(entries, ev)
            end
        end
    end
    for _, ev in ipairs(entries) do
        local name = tostring(ev.AssetCategory or ev.Name or ev.Type or "?")
        local label, num = Repo.RarityOf(name)
        local timeLeft = tonumber(ev.TimeLeft or ev.SecondsLeft or ev.timeLeft)
        local value = tonumber(ev.Value) or Repo.EggValue(name, 1)
        table.insert(rows, { name = name, label = label, num = num, timeLeft = timeLeft, value = value })
    end
    table.sort(rows, function(a, b)
        if Predictor.sortBy == "Value" then return a.value > b.value end
        if Predictor.sortBy == "Rarity" then return a.num > b.num end
        if Predictor.sortBy == "Time Left" then
            local at, bt = a.timeLeft or math.huge, b.timeLeft or math.huge
            return at < bt
        end
        return false
    end)
    if #rows == 0 then
        Tasks.Status("predictor", "Tidak ada event berjalan")
    else
        local line = "PREDICTOR — " .. #rows .. " event"
        for i = 1, math.min(#rows, 6) do
            local r = rows[i]
            local t = r.timeLeft and ("  " .. tostring(math.floor(r.timeLeft)) .. "s") or ""
            line = line .. "\n• " .. r.name .. " [" .. r.label .. "]" .. t
        end
        Tasks.Status("predictor", line)
    end
end)

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

--────────────────────────────[ CAPTURE THE EGG (admin) ]────────────────────────────

local Capture = { on = false, takeHolder = true, holdHeight = 45, keepAway = 45,
                  busy = false, controlling = false, rank = nil, seconds = nil }

Repo.Connect("RE/EggCapture/StandingsRefreshed", function(data)
    local entries = (type(data) == "table" and (data.Entries or data.Standings or data)) or nil
    if type(entries) ~= "table" then return end
    for _, p in ipairs(entries) do
        if type(p) == "table" and tonumber(p.UserId) == LocalPlayer.UserId then
            Capture.rank = tonumber(p.Rank)
            Capture.seconds = tonumber(p.Seconds)
            Capture.controlling = p.Controlling == true or p.IsHolding == true
        end
    end
end)

local function findEventEggHolder()
    -- pemain lain yang sedang memegang egg event
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            if plr.Character:FindFirstChildOfClass("Tool") then
                return plr
            end
        end
    end
    return nil
end

local function findEventEggModel()
    -- model egg event: biasanya muncul di workspace dengan prompt, di luar WorldEggs
    local worldEggs = Repo.WorldEggs()
    for _, m in ipairs(workspace:GetChildren()) do
        if m:IsA("Model") and m ~= worldEggs then
            local prompt = m:FindFirstChild("StealPrompt", true) or m:FindFirstChildWhichIsA("ProximityPrompt", true)
            local isEvent = m:GetAttribute("EventEgg") or m.Name:find("Event", 1, true) or m.Name:find("Capture", 1, true)
            if prompt and prompt.Enabled and isEvent then
                return m
            end
        end
    end
    return nil
end

Tasks.Add("capture", 0.8, function()
    if not Capture.on then return end
    if Capture.busy then return end
    if Capture.controlling then
        -- pegang: tinggi + jauh dari pemain lain
        Tasks.Status("capture", "Holding egg! Rank " .. tostring(Capture.rank or "-"))
        local root = Movement.Root()
        local char = LocalPlayer.Character
        local carrying = char and char:FindFirstChildOfClass("Tool")
        if root and carrying then
            local nearest, nd = nil, math.huge
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local d = (hrp.Position - root.Position).Magnitude
                        if d < nd then nearest, nd = hrp.Position, d end
                    end
                end
            end
            local goal = root.Position
            if nearest and nd < Capture.keepAway then
                goal = root.Position + (root.Position - nearest).Unit * Capture.keepAway
            end
            goal = Vector3.new(goal.X, math.max(goal.Y, Capture.holdHeight), goal.Z)
            Movement.StepTo(goal, 25)
        end
        return
    end
    if Movement.Owner and Movement.Owner ~= "capture" then return end
    Capture.busy = true
    task.spawn(function()
        if Movement.Claim("capture") then
            local egg = findEventEggModel()
            if egg then
                Tasks.Status("capture", "Event egg terlihat, menuju...")
                local pos = P(function() return egg:GetPivot().Position end)
                if pos then
                    Movement.FlyTo(pos, function() return LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool") ~= nil end, 45)
                    local prompt = egg:FindFirstChild("StealPrompt", true) or egg:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if prompt then
                        pcall(function() prompt.HoldDuration = 0 end)
                        if fireproximityprompt then pcall(fireproximityprompt, prompt) end
                    end
                end
            elseif Capture.takeHolder then
                local holder = findEventEggHolder()
                if holder and holder.Character then
                    Tasks.Status("capture", "Rebut dari " .. tostring(holder.Name))
                    local hrp = holder.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        Movement.FlyTo(hrp.Position, function()
                            return not holder.Parent or not holder.Character
                        end, 50)
                        Repo.Fire("RE/BatSwing/Trigger")
                        Repo.Fire("RE/ToolTrigger/Trigger")
                    end
                else
                    Tasks.Status("capture", "Waiting for Capture The Egg")
                end
            else
                Tasks.Status("capture", "Waiting for Capture The Egg")
            end
            Movement.Release("capture")
        end
        Capture.busy = false
    end)
end)

--────────────────────────────[ MINIGAME EGG ]────────────────────────────

local Minigame = { on = false, busy = false }

Tasks.Add("minigame", 1.2, function()
    if not Minigame.on then return end
    if Minigame.busy then return end
    if Movement.Owner and Movement.Owner ~= "minigame" then return end
    local worldEggs = Repo.WorldEggs()
    local root = Movement.Root()
    if not root then return end
    -- egg minigame: model dengan StealPrompt yang muncul di luar WorldEggs
    for _, m in ipairs(workspace:GetChildren()) do
        if m:IsA("Model") and m ~= worldEggs then
            local prompt = m:FindFirstChild("StealPrompt", true)
            if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled
                and (m:GetAttribute("Minigame") or m.Name:find("Minigame", 1, true)) then
                Minigame.busy = true
                task.spawn(function()
                    if Movement.Claim("minigame") then
                        local pos = P(function() return m:GetPivot().Position end)
                        if pos then
                            Movement.FlyTo(pos, function()
                                return LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool") ~= nil
                            end, 45)
                            pcall(function() prompt.HoldDuration = 0 end)
                            if fireproximityprompt then pcall(fireproximityprompt, prompt) end
                        end
                        Movement.Release("minigame")
                    end
                    Minigame.busy = false
                end)
                return
            end
        end
    end
end)

--────────────────────────────[ HALLOWEEN SET ]────────────────────────────

local Hw = {
    steal = false, instant = true, missingIndex = false, speed = 40,
    eggs = {}, rarities = {}, buy = false, delivered = 0,
    buyCooldown = 0,
}

local function hwFilterOk(egg)
    if next(Hw.eggs) ~= nil and not Hw.eggs[egg.Name] then return false end
    if next(Hw.rarities) ~= nil and not Hw.rarities[egg.RarityLabel] then return false end
    if Hw.missingIndex and not Repo.IndexMissing(egg.Name) then return false end
    return true
end

local function hwStealEgg(egg)
    if not Movement.Claim("hwsteal") then return end
    Tasks.Status("halloween", "Stealing this Halloween egg next")
    local model = egg.Model
    local deadline = os.clock() + 30
    while os.clock() < deadline and model.Parent do
        local root = Movement.Root()
        if not root then break end
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool") then break end
        local pos = P(function() return model:GetPivot().Position end)
        if not pos then break end
        local d = pos - root.Position
        local step = Hw.instant and 60 or (Hw.speed / 100 * 40)
        if d.Magnitude < 5 then
            local prompt = egg.Prompt
            pcall(function() prompt.HoldDuration = 0 end)
            if fireproximityprompt then pcall(fireproximityprompt, prompt) end
            task.wait(0.1)
        else
            Movement.StepTo(pos + Vector3.new(0, 3, 0), step)
        end
        task.wait()
    end
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool") then
        -- bawa ke safe zone Halloween dengan fisika
        local sz = Repo.SafeZone()
        if sz and sz:IsA("BasePart") then
            Tasks.Status("halloween", "Carrying the Halloween egg to safety")
            local root = Movement.Root()
            if root then
                local rel = sz.CFrame:PointToObjectSpace(root.Position)
                local mx = math.max(sz.Size.X / 2 - 6, 0)
                local mz = math.max(sz.Size.Z / 2 - 6, 0)
                local goal = sz.CFrame:PointToWorldSpace(Vector3.new(math.clamp(rel.X, -mx, mx), 0, math.clamp(rel.Z, -mz, mz)))
                Movement.CarryTo(goal, function()
                    return not (LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool"))
                end, 60, Hw.speed / 100)
            end
            Repo.Invoke("RF/HalloweenDimension/AskDropEgg")
            task.wait(0.6)
            Hw.delivered = Hw.delivered + 1
            Tasks.Status("halloween", "Halloween egg secured (" .. Hw.delivered .. ")")
            Webhook.Post("Halloween Egg", "Halloween egg secured! #" .. Hw.delivered, 0)
        end
    else
        Tasks.Status("halloween", "Halloween steal gagal")
    end
    Movement.Release("hwsteal")
end

Tasks.Add("halloween", 1.0, function()
    if not Hw.steal then return end
    if Movement.Owner == "hwsteal" then return end
    local best, bd = nil, math.huge
    local root = Movement.Root()
    if not root then return end
    for _, egg in ipairs(EggState.FieldEggs()) do
        if egg.HwUid and hwFilterOk(egg) and egg.Pos then
            local d = (egg.Pos - root.Position).Magnitude
            if d < bd then best, bd = egg, d end
        end
    end
    if best then task.spawn(hwStealEgg, best) end
end)

Tasks.Add("hwbuy", 8.0, function()
    if not Hw.buy then return end
    if os.clock() < Hw.buyCooldown then return end
    local ok = Repo.Invoke("RF/HalloweenDimension/AskBuyEgg")
    if ok then
        Hw.buyCooldown = os.clock() + 5
        Notify("Halloween", "Bought a Halloween Dimension Egg", 3)
    else
        Hw.buyCooldown = os.clock() + 30
    end
end)

--────────────────────────────[ FISHING & GHOST DOG ]────────────────────────────

local Fishing = { on = false, luck = "x1.5 Perfect", busy = false, ghostDog = false }

Tasks.Add("fishing", 1.5, function()
    if not Fishing.on then return end
    if Fishing.busy then return end
    if Movement.Owner and Movement.Owner ~= "fish" then return end
    Fishing.busy = true
    task.spawn(function()
        if Movement.Claim("fish") then
            Tasks.Status("fishing", "Memancing...")
            -- cari spot: UI fishing game muncul saat dekat air; pakai remote langsung
            local ok = Repo.Invoke("RF/Fishing/Cast", Fishing.luck)
            if ok == nil then ok = Repo.Invoke("RF/Fishing/Cast") end
            if ok then
                task.wait(2)
                Repo.Invoke("RF/Fishing/Reel")
            else
                Tasks.Status("fishing", "Tidak bisa memancing di sini")
            end
            Movement.Release("fish")
        end
        Fishing.busy = false
    end)
end)

Tasks.Add("ghostdog", 4.0, function()
    if not Fishing.ghostDog then return end
    local quest = Repo.Invoke("RF/GhostDogQuest/Talk")
    if type(quest) == "table" then
        Repo.Invoke("RF/GhostDogQuest/Dive")
        task.wait(0.3)
        Repo.Invoke("RF/GhostDogQuest/Cast")
        task.wait(0.5)
        Repo.Invoke("RF/GhostDogQuest/Collect")
        task.wait(0.3)
        Repo.Invoke("RF/GhostDogQuest/Claim")
        task.wait(0.2)
        Repo.Invoke("RF/GhostDogQuest/Surface")
    end
end)

--────────────────────────────[ GHOULER / PHANTOM / ISLAND WARS / SOULS ]────────────────────────────

local Events = { vacuum = true, ghouler = false, pumpkinMoon = true, phantom = false,
                 souls = false, islandWars = true, islandTarget = "Enemies And Base",
                 ghostTarget = "Rarest First", busy = {} }

-- Ghouler vacuum: hisap ghost saat event
Tasks.Add("ghouler", 1.0, function()
    if not Events.ghouler then return end
    if Events.busy.ghouler then return end
    -- ghost boss: model GhostBoss di workspace
    local root = Movement.Root()
    if not root then return end
    local target = nil
    local bd = math.huge
    for _, m in ipairs(workspace:GetDescendants()) do
        if m:IsA("Model") and (m.Name:find("Ghost", 1, true) or m:GetAttribute("GhostBossState")) and m.Parent then
            local pos = P(function() return m:GetPivot().Position end)
            if pos then
                local d = (pos - root.Position).Magnitude
                if d < bd then
                    -- Rarest First: pakai nama/atribut rank bila ada
                    if Events.ghostTarget == "Rarest First" or not target then
                        target, bd = m, d
                    end
                end
            end
        end
    end
    if target and Movement.Claim("ghouler") then
        Events.busy.ghouler = true
        task.spawn(function()
            local pos = P(function() return target:GetPivot().Position end)
            if pos then
                Movement.FlyTo(pos, function() return not target.Parent end, 45)
                Repo.Fire("RE/GhostBoss/Suction")
            end
            Movement.Release("ghouler")
            Events.busy.ghouler = false
        end)
    end
end)

-- Phantom Express: naik kereta saat event
Repo.Connect("RE/TrainEvent/State", function(state)
    if type(state) == "table" then
        Tasks.Status("phantom", tostring(state.Status or state.Kind or "Train event"))
    end
end)

Tasks.Add("phantom", 2.0, function()
    if not Events.phantom then return end
    local state = P(function() return Repo.Invoke("RE/TrainEvent/State") end)
    if state then Tasks.Status("phantom", "Train event aktif") end
    -- board rail: cari rail start di world
    local root = Movement.Root()
    if not root then return end
    local rail = workspace:FindFirstChild("BoardRailStart", true) or workspace:FindFirstChild("ReturnRailStart", true)
    if rail and Movement.Claim("phantom") then
        local pos = P(function()
            if rail:IsA("Model") then return rail:GetPivot().Position else return rail.Position end
        end)
        if pos then
            Movement.FlyTo(pos, nil, 40)
            Repo.Invoke("RF/TrainEvent/Action", "Board")
        end
        Movement.Release("phantom")
    end
end)

-- Island Wars
Repo.Connect("RE/IslandWars/State", function(state)
    if type(state) == "table" then
        Tasks.Status("islandwars", tostring(state.Status or "Island Wars aktif"))
    end
end)
Repo.Connect("RE/IslandWars/Moment", function(moment)
    if Events.islandWars and type(moment) == "table" then
        local pos = moment.Position and Vector3.new(tonumber(moment.Position.X) or 0, tonumber(moment.Position.Y) or 0, tonumber(moment.Position.Z) or 0)
        if pos and Movement.Claim("island") then
            task.spawn(function()
                Movement.FlyTo(pos, nil, 45)
                Repo.Invoke("RF/IslandWars/Fetch")
                Repo.Fire("RE/IslandWars/Use")
                Movement.Release("island")
            end)
        end
    end
end)

Tasks.Add("islandwars", 3.0, function()
    if not Events.islandWars then return end
    local state = Repo.Invoke("RF/IslandWars/Fetch")
    if type(state) == "table" then
        Tasks.Status("islandwars", "Island Wars: " .. tostring(state.Status or state.Kind or "aktif"))
    end
end)

-- Trade Souls
Tasks.Add("souls", 6.0, function()
    if not Events.souls then return end
    local ok = Repo.Invoke("RF/HalloweenDimension/AskTradeSouls")
    if ok == nil then
        P(function() Repo.Fire("RE/HalloweenDimension/TradeSouls") end)
    end
end)

--────────────────────────────[ COMBAT (AUTO HIT) ]────────────────────────────

local Hit = { on = false, targets = "Nearest player", aura = false, tweenSpeed = 400,
              maxSpeed = 750, lead = -275, sweep = 60, rate = 0.6, lastSwing = 0 }

local function findHitTarget()
    local root = Movement.Root()
    if not root then return nil end
    local best, bd = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local isHolder = plr.Character:FindFirstChildOfClass("Tool") ~= nil
                local want = (Hit.targets == "Egg holders" and isHolder) or (Hit.targets ~= "Egg holders")
                if want then
                    local d = (hrp.Position - root.Position).Magnitude
                    if d < bd then best, bd = plr, d end
                end
            end
        end
    end
    return best
end

local function swing()
    local now = os.clock()
    if now - Hit.lastSwing < Hit.rate then return end
    Hit.lastSwing = now
    Repo.Fire("RE/BatSwing/Trigger")
    Repo.Fire("RE/ToolTrigger/Trigger")
end

Tasks.Add("hit", 0.15, function()
    if not Hit.on then return end
    local root = Movement.Root()
    if not root then return end
    local target = findHitTarget()
    if not target then return end
    local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local dist = (hrp.Position - root.Position).Magnitude
    if dist > Hit.sweep * 2 then
        -- kejar: lead = prediksi arah lari
        local vel = hrp.AssemblyLinearVelocity
        local leadOff = Vector3.new(0, 0, 0)
        if Hit.lead ~= 0 then
            local fwd = hrp.CFrame.LookVector
            leadOff = fwd * (Hit.lead / 100 * 10)
        end
        local goal = hrp.Position + leadOff
        Movement.StepTo(goal, math.min(Hit.maxSpeed / 30, 45))
    end
    if dist <= Hit.sweep then
        swing()
    end
    if Hit.aura then
        -- pukul semua yang dekat
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local h2 = plr.Character:FindFirstChild("HumanoidRootPart")
                if h2 and (h2.Position - root.Position).Magnitude <= Hit.sweep then
                    swing()
                    break
                end
            end
        end
    end
end)

--════════════ PART: p5_esp_server.lua ════════════
--────────────────────────────[ ESP SYSTEM ]────────────────────────────
-- Billboard + Highlight dengan pool & throttle: update 5x/detik, bukan
-- tiap frame. Kunci pool = instance itu sendiri (weak keys), jadi tidak
-- ada kolisi nama & entri mati otomatis ter-GC.
-- (Scan cache dideklarasikan di bagian Movement — dipakai lintas modul.)

local ESP = {
    eggs = false, fixed = false, minRarity = 0, minValue = 0, info = {},
    playerInfo = { ["Name"] = true, ["Distance"] = true },
    ownBase = true, otherBase = false, guards = false, players = false,
    eggSize = 75, guardSize = 75, playerSize = 75,
    pool = setmetatable({}, { __mode = "k" }), maxDist = 2500,
}

local RARITY_FALLBACK = {
    Common = Color3.fromRGB(180, 180, 180), Uncommon = Color3.fromRGB(120, 220, 120),
    Rare = Color3.fromRGB(90, 150, 255), Epic = Color3.fromRGB(190, 100, 255),
    Legendary = Color3.fromRGB(255, 200, 60), Mythic = Color3.fromRGB(255, 100, 100),
    Cosmic = Color3.fromRGB(80, 230, 230), Secret = Color3.fromRGB(40, 40, 50),
    Eternal = Color3.fromRGB(255, 240, 150), Divine = Color3.fromRGB(255, 255, 255),
}

function ESP.RarityColor(label)
    local spec = Repo.Spec(label)
    if type(spec) == "table" and type(spec.Rarity) == "table" and typeof(spec.Rarity.Color) == "Color3" then
        return spec.Rarity.Color
    end
    -- cari lewat directory (label = nama rarity)
    if Repo.DirectoryOK then
        for _, v in pairs(Repo.Directory) do
            if type(v) == "table" and type(v.Rarity) == "table" then
                local dn = tostring(v.Rarity.DisplayName or v.Rarity._id or "")
                if dn == label and typeof(v.Rarity.Color) == "Color3" then
                    return v.Rarity.Color
                end
            end
        end
    end
    return RARITY_FALLBACK[label] or Color3.fromRGB(255, 255, 255)
end

local function espMakeBillboard(size)
    local bb = Instance.new("BillboardGui")
    bb.Name = "ThorHubESP"
    bb.AlwaysOnTop = true
    bb.Size = UDim2.new(0, size * 2, 0, size * 2)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.MaxDistance = ESP.maxDist
    local lbl = Instance.new("TextLabel")
    lbl.Name = "T"
    lbl.BackgroundTransparency = 1
    lbl.AnchorPoint = Vector2.new(0.5, 0.5)
    lbl.Position = UDim2.fromScale(0.5, 0.5)
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold
    lbl.TextColor3 = Color3.new(1, 1, 1)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(0, 0, 0)
    stroke.Thickness = 1.6
    stroke.Parent = lbl
    lbl.Parent = bb
    return bb, lbl
end

local function espGet(instance, size)
    local e = ESP.pool[instance]
    if e and e.bb and e.bb.Parent then
        return e
    end
    if e then
        pcall(function() e.bb:Destroy() end)
        pcall(function() e.hl:Destroy() end)
    end
    local bb, lbl = espMakeBillboard(size)
    local hl = Instance.new("Highlight")
    hl.Name = "ThorHubChams"
    hl.FillTransparency = 0.55
    hl.OutlineTransparency = 0
    e = { bb = bb, lbl = lbl, hl = hl, adorn = instance }
    ESP.pool[instance] = e
    return e
end

local function espShowEgg(instance, info)
    local e = espGet(instance, ESP.eggSize)
    e.lbl.Text = table.concat(info, "\n")
    e.hl.FillColor = ESP.RarityColor(info.rarityLabel)
    if e.bb.Parent ~= instance then e.bb.Parent = instance end
    if e.hl.Parent ~= instance then e.hl.Parent = instance end
    if ESP.fixed then
        e.bb.Size = UDim2.new(0, ESP.eggSize * 2, 0, ESP.eggSize * 2)
    end
end

local function espHide(instance)
    local e = ESP.pool[instance]
    if e then
        pcall(function() e.bb:Destroy() end)
        pcall(function() e.hl:Destroy() end)
        ESP.pool[instance] = nil
    end
end

local function espInfoLines(egg, root)
    local lines = {}
    if ESP.info["Name"] then table.insert(lines, egg.Name) end
    if ESP.info["Rarity"] then table.insert(lines, egg.RarityLabel ~= "" and egg.RarityLabel or "?") end
    if ESP.info["Value"] then table.insert(lines, fmtNum(egg.Value) .. "/s") end
    if ESP.info["Mutation"] then
        table.insert(lines, #egg.Mutations > 0 and table.concat(egg.Mutations, " ") or "No Mutation")
    end
    if ESP.info["Size"] then table.insert(lines, "size " .. tostring(round(egg.Scale, 1))) end
    if ESP.info["Weight"] then table.insert(lines, "wt " .. tostring(round(egg.Scale, 1))) end
    if ESP.info["Area"] then table.insert(lines, tostring(egg.Zone or "-")) end
    if ESP.info["Distance"] and root then
        table.insert(lines, tostring(math.floor((egg.Pos - root.Position).Magnitude)) .. "m")
    end
    if ESP.info["State"] then table.insert(lines, "Field") end
    if #lines == 0 then table.insert(lines, egg.Name) end
    return lines
end

Tasks.Add("esp", 0.2, function()
    local any = ESP.eggs or ESP.guards or ESP.players
    local root = Movement.Root()
    if not any then
        for k in pairs(ESP.pool) do espHide(k) end
        return
    end
    local seen = {}

    if ESP.eggs then
        for _, egg in ipairs(EggState.FieldEggs()) do
            if egg.RarityNum >= ESP.minRarity and egg.Value >= ESP.minValue then
                if root and egg.Pos and (egg.Pos - root.Position).Magnitude <= ESP.maxDist then
                    seen[egg.Model] = true
                    local lines = espInfoLines(egg, root)
                    lines.rarityLabel = egg.RarityLabel
                    espShowEgg(egg.Model, lines)
                end
            end
        end
        -- base eggs
        local renders = Repo.PlacedEggRenders()
        if renders then
            local myUid = tostring(LocalPlayer.UserId)
            for _, m in ipairs(renders:GetChildren()) do
                local isMine = string.find(m.Name, myUid, 1, true) ~= nil
                if (isMine and ESP.ownBase) or (not isMine and ESP.otherBase) then
                    local pos = P(function()
                        if m:IsA("Model") then return m:GetPivot().Position else return m.CFrame.Position end
                    end)
                    if pos and root and (pos - root.Position).Magnitude <= ESP.maxDist then
                        seen[m] = true
                        local owner = string.match(m.Name, "^(%d+)")
                        local plr = Players:GetPlayerByUserId(tonumber(owner) or 0)
                        local name = m.Name
                        local label, num = Repo.RarityOf(name)
                        local lines = { name }
                        if ESP.info["Area"] then table.insert(lines, plr and plr.Name or (isMine and "Your Base" or "Other Base")) end
                        if ESP.info["Distance"] then table.insert(lines, tostring(math.floor((pos - root.Position).Magnitude)) .. "m") end
                        lines.rarityLabel = label
                        espShowEgg(m, lines)
                    end
                end
            end
        end
    end

    if ESP.guards then
        local ga = Repo.GuardAreas()
        if ga and root then
            local guards = P(function() return ga:GetDescendants() end) or {}
            for _, g in ipairs(guards) do
                if g:IsA("Model") and g.Parent then
                    local pos = P(function() return g:GetPivot().Position end)
                    if pos and (pos - root.Position).Magnitude <= ESP.maxDist then
                        seen[g] = true
                        local e = espGet(g, ESP.guardSize)
                        e.lbl.Text = "GUARD\n" .. tostring(math.floor((pos - root.Position).Magnitude)) .. "m"
                        e.hl.FillColor = Color3.fromRGB(255, 70, 70)
                        if e.bb.Parent ~= g then e.bb.Parent = g end
                        if e.hl.Parent ~= g then e.hl.Parent = g end
                    end
                end
            end
        end
    end

    if ESP.players then
        if root then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and (hrp.Position - root.Position).Magnitude <= ESP.maxDist then
                        seen[plr.Character] = true
                        local e = espGet(plr.Character, ESP.playerSize)
                        local lines = {}
                        if ESP.playerInfo["Name"] or next(ESP.playerInfo) == nil then table.insert(lines, plr.Name) end
                        if ESP.playerInfo["Distance"] then
                            table.insert(lines, tostring(math.floor((hrp.Position - root.Position).Magnitude)) .. "m")
                        end
                        if ESP.playerInfo["Tool"] and plr.Character:FindFirstChildOfClass("Tool") then
                            table.insert(lines, "🥚 holding egg")
                        end
                        e.lbl.Text = #lines > 0 and table.concat(lines, "\n") or plr.Name
                        e.hl.FillColor = Color3.fromRGB(0, 195, 255)
                        if e.bb.Parent ~= plr.Character then e.bb.Parent = plr.Character end
                        if e.hl.Parent ~= plr.Character then e.hl.Parent = plr.Character end
                    end
                end
            end
        end
    end

    for inst in pairs(ESP.pool) do
        if not seen[inst] then espHide(inst) end
    end
end)

function ESP.RemoveAll()
    for inst in pairs(ESP.pool) do espHide(inst) end
end

--────────────────────────────[ CHARACTER UTILITIES ]────────────────────────────

local Char = {
    speed = false, boost = 350, jump = false,
    invisible = false, antiRagdoll = true, antiTrap = true, instantPrompts = true,
    antiGuard = false,
}

-- speed boost: pasang WalkSpeed tiap respawn & saat aktif
Tasks.Add("speed", 1.0, function()
    if not Char.speed then return end
    local hum = Movement.Humanoid()
    if hum and hum.WalkSpeed < Char.boost then
        hum.WalkSpeed = Char.boost
    end
end)

-- infinite jump
do
    local jumpConn = nil
    local function setJump(on)
        if jumpConn then jumpConn:Disconnect() jumpConn = nil end
        if on then
            jumpConn = UserInputService.JumpRequest:Connect(function()
                local hum = Movement.Humanoid()
                if hum then
                    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
                end
            end)
        end
    end
    Char.__setJump = setJump
end

-- anti-ragdoll / anti-trap / instant prompts / anti-guard
Tasks.Add("charutil", 0.5, function()
    local any = Char.antiRagdoll or Char.antiTrap or Char.instantPrompts
    if not any then return end
    if Char.antiRagdoll or Char.antiTrap then
        Character.AntiRagdollOnce()
    end
    if Char.instantPrompts then
        local root = Movement.Root()
        if root then
            local PromptService = S("ProximityPromptService")
            for _, inst in ipairs(PromptService.Prompts) do
                if inst.Enabled and inst.HoldDuration > 0 then
                    local p = P(function()
                        local pp = inst.Parent
                        local pos
                        if pp then
                            if pp:IsA("Model") then pos = pp:GetPivot().Position
                            elseif pp:IsA("BasePart") then pos = pp.Position end
                        end
                        return pos and (pos - root.Position).Magnitude < 15
                    end)
                    if p then pcall(function() inst.HoldDuration = 0 end) end
                end
            end
        end
    end
    if Char.antiGuard then
        local ga = Repo.GuardAreas()
        local root = Movement.Root()
        if ga and root and Movement.Owner == "steal" then
            local guards = P(function() return ga:GetDescendants() end) or {}
            for _, g in ipairs(guards) do
                if g:IsA("Model") then
                    local pos = P(function() return g:GetPivot().Position end)
                    if pos and (pos - root.Position).Magnitude < 30 then
                        local away = root.Position + (root.Position - pos).Unit * 45
                        Movement.StepTo(away, 30)
                        Tasks.Status("steal", "Anti Guard: menjauh dari guard")
                        break
                    end
                end
            end
        end
    end
end)

-- anti-AFK
do
    local vu = (getgenv and nil)
    LocalPlayer.Idled:Connect(function()
        local VirtualUser = S("VirtualUser")
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)
end

-- invisibility
Tasks.Add("invis", 3.0, function()
    if not Char.invisible then return end
    if not Character.Original then
        Character.ApplyInvisibility(true)
    end
end)

--────────────────────────────[ HUD (Farm HUD + FPS/Ping) ]────────────────────────────

local HUD = {
    farm = false, size = 100, items = { Money = true, Speed = true, Eggs = true, Night = true },
    fpsPing = true, fpsSize = 100,
    gui = nil, label = nil, fpsGui = nil, fpsLabel = nil,
}

local function buildFarmHud()
    if HUD.gui then return end
    local gui = Instance.new("ScreenGui")
    gui.Name = "ThorHubFarmHUD"
    gui.ResetOnSpawn = false
    P(function() gui.Parent = (gethui and gethui()) or LocalPlayer:FindFirstChild("PlayerGui") end)
    local frame = Instance.new("Frame")
    frame.Name = "Card"
    frame.AnchorPoint = Vector2.new(1, 0)
    frame.Position = UDim2.new(1, -12, 0, 12)
    frame.Size = UDim2.fromOffset(240, 200)
    frame.BackgroundColor3 = Color3.fromRGB(11, 14, 23)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 195, 255)
    stroke.Transparency = 0.5
    stroke.Parent = frame
    local lbl = Instance.new("TextLabel")
    lbl.Name = "Text"
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.fromScale(0.04, 0.03)
    lbl.Size = UDim2.fromScale(0.92, 0.94)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.Font = Enum.Font.GothamBold
    lbl.TextColor3 = Color3.fromRGB(240, 244, 255)
    lbl.TextSize = 14
    lbl.TextWrapped = true
    lbl.Text = "FARM STATS"
    lbl.Parent = frame
    HUD.gui = gui
    HUD.label = lbl
end

local function removeFarmHud()
    if HUD.gui then pcall(function() HUD.gui:Destroy() end) end
    HUD.gui, HUD.label = nil, nil
end

local function buildFpsHud()
    if HUD.fpsGui then return end
    local gui = Instance.new("ScreenGui")
    gui.Name = "ThorHubFpsPing"
    gui.ResetOnSpawn = false
    P(function() gui.Parent = (gethui and gethui()) or LocalPlayer:FindFirstChild("PlayerGui") end)
    local lbl = Instance.new("TextLabel")
    lbl.Name = "Text"
    lbl.AnchorPoint = Vector2.new(0, 1)
    lbl.Position = UDim2.new(0, 12, 1, -12)
    lbl.Size = UDim2.fromOffset(220, 30)
    lbl.BackgroundTransparency = 0.35
    lbl.BackgroundColor3 = Color3.fromRGB(11, 14, 23)
    lbl.Font = Enum.Font.Gotham
    lbl.TextColor3 = Color3.fromRGB(0, 195, 255)
    lbl.TextSize = math.max(12, HUD.fpsSize / 100 * 14)
    lbl.Text = "FPS ...  |  PING ..."
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = lbl
    lbl.Parent = gui
    HUD.fpsGui = gui
    HUD.fpsLabel = lbl
end

local function removeFpsHud()
    if HUD.fpsGui then pcall(function() HUD.fpsGui:Destroy() end) end
    HUD.fpsGui, HUD.fpsLabel = nil, nil
end

local fpsAcc, fpsN, fpsAt = 0, 0, os.clock()
RunService.RenderStepped:Connect(function(dt)
    fpsAcc = fpsAcc + dt
    fpsN = fpsN + 1
    if os.clock() - fpsAt >= 1 then
        HUD.__fps = fpsN / math.max(fpsAcc, 0.001)
        fpsAcc, fpsN, fpsAt = 0, 0, os.clock()
    end
end)

Tasks.Add("hud", 0.5, function()
    -- Farm HUD
    if HUD.farm then
        buildFarmHud()
        local rows = { "⚡ THORHUB — FARM STATS" }
        if HUD.items["Money"] then table.insert(rows, "Money: " .. fmtNum(Repo.Money())) end
        if HUD.items["Speed"] then table.insert(rows, "Speed Power: " .. fmtNum(Repo.SpeedPower())) end
        if HUD.items["Eggs"] then table.insert(rows, "Eggs Stolen: " .. tostring(Steal.stolen)) end
        if Steal.best then
            table.insert(rows, "Best: " .. tostring(Steal.best.name) .. " [" .. tostring(Steal.best.rarity) .. "]")
        end
        if HUD.items["Night"] then table.insert(rows, Repo.IsNight() and "🌙 Night (field reset)" or "☀️ Day") end
        table.insert(rows, "Save: " .. (Repo.SaveOK and "OK" or "n/a") .. "  |  Dir: " .. (Repo.DirectoryOK and "OK" or "n/a"))
        local text = table.concat(rows, "\n")
        if HUD.label and HUD.label.Text ~= text then HUD.label.Text = text end
    else
        removeFarmHud()
    end
    -- FPS/Ping
    if HUD.fpsPing then
        buildFpsHud()
        local ping = P(function()
            local s = Stats.Network.ServerStatsItem
            local v = s and s["Data Ping"]
            return v and math.floor(v:GetValue())
        end) or 0
        local t = "FPS " .. tostring(math.floor(HUD.__fps or 0)) .. "  |  PING " .. tostring(ping) .. "ms"
        if HUD.fpsLabel and HUD.fpsLabel.Text ~= t then
            HUD.fpsLabel.Text = t
            HUD.fpsLabel.TextSize = math.max(12, HUD.fpsSize / 100 * 14)
        end
    else
        removeFpsHud()
    end
end)

--────────────────────────────[ MISC: PERFORMANCE & TAMPILAN ]────────────────────────────

local Misc = {
    fpsCap = 240, optimizer = false, renderOff = false, bgColor = "Black",
    hideUI = false, uiSize = 100,
    savedLighting = nil, hiddenUI = {}, blackFrame = nil,
}

local function applyOptimizer(on)
    if on then
        if not Misc.savedLighting then
            Misc.savedLighting = {
                GlobalShadows = Lighting.GlobalShadows,
                Brightness = Lighting.Brightness,
                FogEnd = Lighting.FogEnd,
                FogStart = Lighting.FogStart,
                EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
                EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
            }
        end
        pcall(function()
            Lighting.GlobalShadows = false
            Lighting.Brightness = 0
            Lighting.FogEnd = 9e9
            Lighting.FogStart = 9e9
            Lighting.EnvironmentDiffuseScale = 0
            Lighting.EnvironmentSpecularScale = 0
        end)
        pcall(function()
            local terrain = workspace:FindFirstChildOfClass("Terrain")
            if terrain then
                terrain.WaterWaveSize = 0
                terrain.WaterWaveSpeed = 0
                terrain.WaterReflectance = 0
                terrain.WaterTransparency = 1
            end
        end)
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("PostEffect") then pcall(function() e.Enabled = false end) end
        end
    else
        if Misc.savedLighting then
            pcall(function()
                for k, v in pairs(Misc.savedLighting) do Lighting[k] = v end
            end)
            Misc.savedLighting = nil
        end
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("PostEffect") then pcall(function() e.Enabled = true end) end
        end
    end
end

local function applyRenderOff(on)
    if on then
        pcall(function() RunService:Set3dRenderingEnabled(false) end)
        -- fallback visual: frame hitam/putih penuh layar
        if not Misc.blackFrame then
            local gui = Instance.new("ScreenGui")
            gui.Name = "ThorHubRenderOff"
            gui.ResetOnSpawn = false
            gui.DisplayOrder = 999999
            local f = Instance.new("Frame")
            f.Size = UDim2.fromScale(2, 2)
            f.Position = UDim2.fromScale(-0.5, -0.5)
            f.BackgroundColor3 = (Misc.bgColor == "White") and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
            f.BorderSizePixel = 0
            f.Parent = gui
            P(function() gui.Parent = (gethui and gethui()) or LocalPlayer:FindFirstChild("PlayerGui") end)
            Misc.blackFrame = gui
        end
    else
        pcall(function() RunService:Set3dRenderingEnabled(true) end)
        if Misc.blackFrame then
            pcall(function() Misc.blackFrame:Destroy() end)
            Misc.blackFrame = nil
        end
    end
end

local function applyHideUI(on)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end
    if on then
        for _, gui in ipairs(pg:GetChildren()) do
            if gui:IsA("ScreenGui") and not gui.Name:find("ThorHub", 1, true)
                and not gui.Name:find("ThorUi", 1, true) then
                if gui.Enabled then
                    Misc.hiddenUI[gui] = true
                    pcall(function() gui.Enabled = false end)
                end
            end
        end
    else
        for gui in pairs(Misc.hiddenUI) do
            if gui.Parent then pcall(function() gui.Enabled = true end) end
        end
        Misc.hiddenUI = {}
    end
end

function Misc.ApplyAll()
    applyOptimizer(Misc.optimizer)
    applyRenderOff(Misc.renderOff)
    applyHideUI(Misc.hideUI)
    pcall(function()
        if setfpscap then setfpscap(Misc.fpsCap) end
    end)
end

--────────────────────────────[ SERVER HOP / REJOIN / AUTO HOP ]────────────────────────────

local Server = {
    autoLoad = true, hopMode = "Least Players", autoRejoin = true,
    hopOn = false, hopWhen = "Until An Egg Matches", waitRarity = 7,
    firstDelay = 5, visited = {}, hopping = false, startedAt = os.clock(),
}

local function httpGetJson(url)
    local fn = (syn and syn.request) or http_request or request or (http and http.request)
    if fn then
        local ok, res = pcall(fn, { Url = url, Method = "GET" })
        if ok and type(res) == "table" and type(res.Body) == "string" then
            return jsonDec(res.Body)
        end
    end
    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and body then return jsonDec(body) end
    return nil
end

function Server.Hop(manualMode)
    if Server.hopping then return end
    Server.hopping = true
    task.spawn(function()
        local mode = manualMode or Server.hopMode
        local cursor = ""
        local best, bestKey = nil, (mode == "Least Players") and math.huge or (mode == "Most Players") and -1 or nil
        for _ = 1, 3 do
            local url = string.format(
                "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100%s",
                PLACE_ID, cursor ~= "" and ("&cursor=" .. cursor) or "")
            local data = httpGetJson(url)
            if type(data) ~= "table" or type(data.data) ~= "table" then break end
            for _, s in ipairs(data.data) do
                if s.id ~= JOB_ID and (tonumber(s.maxPlayers) or 0) > (tonumber(s.playing) or 0)
                    and not Server.visited[s.id] then
                    if mode == "Least Players" then
                        if (s.playing or 0) < bestKey then best, bestKey = s, s.playing end
                    elseif mode == "Most Players" then
                        if (s.playing or 0) > bestKey then best, bestKey = s, s.playing end
                    else
                        if math.random(100) > 70 then best = s end
                    end
                end
            end
            cursor = type(data.nextPageCursor) == "string" and data.nextPageCursor or ""
            if cursor == "" then break end
        end
        if best then
            Server.visited[JOB_ID] = true
            Server.SaveHopState()
            Notify("Server", "Pindah ke server baru (" .. tostring(best.playing) .. " pemain)", 4)
            if queue_on_teleport and Server.autoLoad then
                queue_on_teleport([[loadstring(game:HttpGet("]] .. SOURCE_URL .. [["))()]])
            end
            pcall(function()
                TeleportService:TeleportToPlaceInstance(PLACE_ID, best.id, LocalPlayer)
            end)
            task.wait(5)
        else
            Notify("Server", "Tidak ada server lain yang tersedia", 4)
        end
        Server.hopping = false
    end)
end

function Server.Rejoin()
    if queue_on_teleport and Server.autoLoad then
        queue_on_teleport([[loadstring(game:HttpGet("]] .. SOURCE_URL .. [["))()]])
    end
    pcall(function()
        if JOB_ID ~= "" then
            TeleportService:TeleportToPlaceInstance(PLACE_ID, JOB_ID, LocalPlayer)
        else
            TeleportService:Teleport(PLACE_ID, LocalPlayer)
        end
    end)
end

function Server.JoinJobId(jobId)
    if jobId == "" then return end
    if queue_on_teleport and Server.autoLoad then
        queue_on_teleport([[loadstring(game:HttpGet("]] .. SOURCE_URL .. [["))()]])
    end
    pcall(function()
        TeleportService:TeleportToPlaceInstance(PLACE_ID, jobId, LocalPlayer)
    end)
end

function Server.SaveHopState()
    if not FS.ok then return end
    FS.Write(FS.GamePath("autohop.json"), jsonEnc({
        visited = Server.visited, hopWhen = Server.hopWhen,
        waitRarity = Server.waitRarity, firstDelay = Server.firstDelay,
    }) or "")
end

function Server.LoadHopState()
    local json = FS.Read(FS.GamePath("autohop.json"))
    local data = json and jsonDec(json)
    if type(data) == "table" then
        if type(data.visited) == "table" then
            Server.visited = data.visited
        end
    end
end

Server.LoadHopState()

-- auto rejoin saat disconnect / kick
do
    local GuiService = S("GuiService")
    GuiService.ErrorMessageChanged:Connect(function()
        if Server.autoRejoin then
            task.wait(2)
            Server.Rejoin()
        end
    end)
    Players.PlayerRemoving:Connect(function(plr)
        if plr == LocalPlayer and Server.autoRejoin then
            task.delay(1, function() Server.Rejoin() end)
        end
    end)
end

-- auto hop state machine
Tasks.Add("autohop", 2.0, function()
    if not Server.hopOn then return end
    if Server.hopping then return end
    -- malam: tunggu (field reset, egg segar muncul)
    if Repo.IsNight() then
        Tasks.Status("autohop", "Night, waiting for the field to reset")
        return
    end
    -- bersihkan visited lama (di atas 30 server)
    local n = 0
    for _ in pairs(Server.visited) do n = n + 1 end
    if n > 30 then Server.visited = {} end

    local eggs = EggState.FieldEggs()
    local match = nil
    for _, egg in ipairs(eggs) do
        if egg.RarityNum >= Server.waitRarity then
            match = egg
            break
        end
    end

    if Server.hopWhen == "Until An Egg Matches" then
        if match then
            Tasks.Status("autohop", "Match ditemukan: " .. tostring(match.Name) .. " — berhenti hop")
            Notify("Auto Hop", "Egg cocok ketemu: " .. tostring(match.Name), 5)
            Webhook.Post("Rare Spawn", "Egg cocok: **" .. tostring(match.Name) .. "** [" .. tostring(match.RarityLabel) .. "]", match.RarityNum)
            Server.hopOn = false
            if QueueElem and QueueElem["autohop"] then
                P(function() QueueElem["autohop"]:Set(false, false) end)
            end
        else
            Tasks.Status("autohop", "Mencari server dengan egg cocok...")
            Server.Hop()
        end
    elseif Server.hopWhen == "Steal Then Hop" then
        if match then
            if Steal.on and isCarrying() then
                Tasks.Status("autohop", "Mencuri match dulu, hop setelahnya")
            elseif Steal.on then
                Tasks.Status("autohop", "Match ada — serahkan ke Auto Steal")
            else
                Tasks.Status("autohop", "Match ada tapi Auto Steal mati — hop lanjut")
                Server.Hop()
            end
        else
            Server.Hop()
        end
    else -- After A Rare Spawns
        if match then
            Tasks.Status("autohop", "Rare spawned: " .. tostring(match.Name) .. " — berhenti")
            Notify("Auto Hop", "Rare spawn: " .. tostring(match.Name), 5)
            Webhook.Post("Rare Spawn", "Rare spawn: **" .. tostring(match.Name) .. "**", match.RarityNum)
            Server.hopOn = false
            if QueueElem and QueueElem["autohop"] then
                P(function() QueueElem["autohop"]:Set(false, false) end)
            end
        else
            Tasks.Status("autohop", "Menunggu rare >= " .. tostring(Repo.RarityOrder[Server.waitRarity] or "?"))
            Server.Hop()
        end
    end
end)

--────────────────────────────[ DISPATCHER (single loop) ]────────────────────────────

RunService.Heartbeat:Connect(function()
    local now = os.clock()
    for _, t in pairs(Tasks.byName) do
        if not t.busy and now >= t.next then
            t.next = now + t.interval
            t.busy = true
            task.spawn(function()
                local ok, err = pcall(t.fn)
                if not ok then
                    -- catat error sekali, jangan spam
                    if not t.__warned then
                        t.__warned = true
                        warn("[ThorHub] task '" .. t.name .. "' error: " .. tostring(err))
                    end
                end
                t.busy = false
            end)
        end
    end
end)

--════════════ PART: p6_menu.lua ════════════
--────────────────────────────[ THORUI LOADER ]────────────────────────────
-- ThorUI adalah GLOBAL: fungsi Notify (bagian awal) membacanya.

ThorUI = nil
do
    local lastErr = nil
    for attempt = 1, 3 do
        local ok, result = pcall(function()
            return loadstring(game:HttpGet(THORUI_URL))
        end)
        if ok then
            local okRun, lib = pcall(result)
            if okRun and type(lib) == "table" then
                ThorUI = lib
                break
            end
            lastErr = tostring(lib)
        else
            lastErr = tostring(result)
        end
        task.wait(1)
    end
    if not ThorUI then
        warn("[ThorHub] Gagal memuat ThorUi: " .. tostring(lastErr))
        return
    end
end

if not ThorUI.Version or ThorUI.Version < "2.0" then
    -- tetap lanjut, hanya catat
    warn("[ThorHub] ThorUi versi lama terdeteksi: " .. tostring(ThorUI.Version))
end

--────────────────────────────[ MENU HELPERS ]────────────────────────────

local Window = ThorUI:CreateWindow({
    Title = "ThorHub ⚡ Steal an Egg",
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

local function mkToggle(tab, key, name, default, cb)
    local e = tab:AddToggle({
        Name = name, Default = default,
        Callback = function(v)
            Config.Set(key, v)
            if cb then cb(v) end
        end,
    })
    e.__kind = "toggle"
    return reg(key, e)
end

local function mkSlider(tab, key, name, min, max, default, inc, suffix, cb)
    local e = tab:AddSlider({
        Name = name, Min = min, Max = max, Default = default,
        Increment = inc or 1, Suffix = suffix or "",
        Callback = function(v)
            Config.Set(key, v)
            if cb then cb(v) end
        end,
    })
    e.__kind = "slider"
    return reg(key, e)
end

local function mkDropdown(tab, key, name, values, default, cb)
    local e = tab:AddDropdown({
        Name = name, Values = values, Default = default,
        Callback = function(v)
            Config.Set(key, v)
            if cb then cb(v) end
        end,
    })
    e.__kind = "dropdown"
    return reg(key, e)
end

local function mkMulti(tab, key, name, values, cb)
    local e = tab:AddDropdown({
        Name = name, Values = values, Default = {}, Multi = true,
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
mkToggle(FarmTab, "farm/steal", "Auto Steal", false, function(v) Steal.on = v Tasks.Wake("steal") end)
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
mkToggle(FarmTab, "farm/instant", "Instant Steal", false, function(v) Steal.instant = v end)
mkStatus(FarmTab, "steal", "Steal: idle")

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

--══════════════════════════ TAB 2: ADMIN ══════════════════════════
local AdminTab = Window:CreateTab({ Name = "Admin", Icon = "🥚" })

mkSection(AdminTab, "Capture The Egg")
mkToggle(AdminTab, "admin/capture", "Auto Capture Event Egg", false, function(v) Capture.on = v Tasks.Wake("capture") end)
mkToggle(AdminTab, "admin/takeholder", "Take It From The Holder", true, function(v) Capture.takeHolder = v end)
mkSlider(AdminTab, "admin/holdheight", "Hold Height", 20, 120, 45, 5, "", function(v) Capture.holdHeight = v end)
mkSlider(AdminTab, "admin/keepaway", "Keep Away Distance", 20, 150, 45, 5, "", function(v) Capture.keepAway = v end)
mkStatus(AdminTab, "capture", "Capture: idle")

mkSection(AdminTab, "Minigame Eggs")
mkToggle(AdminTab, "admin/minigame", "Auto Steal Minigame Egg", false, function(v) Minigame.on = v end)

mkSection(AdminTab, "Halloween Dimension")
mkToggle(AdminTab, "admin/hwsteal", "Auto Steal Halloween Eggs", false, function(v) Hw.steal = v Tasks.Wake("halloween") end)
mkToggle(AdminTab, "admin/hwinstant", "Instant Steal Halloween Eggs", true, function(v) Hw.instant = v end)
mkToggle(AdminTab, "admin/hwmissing", "Steal Missing Halloween Index", false, function(v) Hw.missingIndex = v end)
mkSlider(AdminTab, "admin/hwspeed", "Steal Speed", 10, 100, 40, 5, "", function(v) Hw.speed = v end)
mkMulti(AdminTab, "admin/hweggs", "Halloween Eggs To Steal", eggSpecies, function(l) Hw.eggs = listToSet(l) end)
mkMulti(AdminTab, "admin/hwrarity", "Halloween Egg Rarities", Repo.RarityOrder, function(l) Hw.rarities = listToSet(l) end)
mkToggle(AdminTab, "admin/hwbuy", "Auto Buy Halloween Dimension Egg", false, function(v) Hw.buy = v Tasks.Wake("hwbuy") end)
mkStatus(AdminTab, "halloween", "Halloween: idle")

mkSection(AdminTab, "Monsters")
mkToggle(AdminTab, "admin/monsters", "Auto Farm Monsters", false, function(v) Monsters.on = v Tasks.Wake("monsters") end)
mkMulti(AdminTab, "admin/monlist", "Monsters To Kill",
    { "Candy Corn", "Hollow Bat", "Scarecrow", "Chest Mimic", "Pumpkin Golem", "Soul Phantom" },
    function(l) Monsters.list = listToSet(l) end)
mkDropdown(AdminTab, "admin/monorder", "Monster Order", { "Closest", "Rarest" }, "Closest",
    function(v) Monsters.order = v end)
mkStatus(AdminTab, "monsters", "Monsters: idle")

mkSection(AdminTab, "Events")
mkToggle(AdminTab, "admin/fishing", "Auto Fishing", false, function(v) Fishing.on = v Tasks.Wake("fishing") end)
mkDropdown(AdminTab, "admin/luck", "Cast Luck",
    { "x1 Perfect", "x1.25 Good", "x1.5 Perfect", "x2 Lucky" }, "x1.5 Perfect", function(v) Fishing.luck = v end)
mkToggle(AdminTab, "admin/ghostdog", "Auto Ghost Dog Quest", false, function(v) Fishing.ghostDog = v end)
mkToggle(AdminTab, "admin/ghouler", "Auto Vacuum Ghouler Boss", false, function(v) Events.ghouler = v end)
mkDropdown(AdminTab, "admin/ghosttarget", "Ghost Target", { "Rarest First", "Nearest First" }, "Rarest First",
    function(v) Events.ghostTarget = v end)
mkToggle(AdminTab, "admin/phantom", "Auto Phantom Express", false, function(v) Events.phantom = v end)
mkToggle(AdminTab, "admin/souls", "Auto Trade Souls", false, function(v) Events.souls = v end)
mkToggle(AdminTab, "admin/islandwars", "Auto Play Cursed Island Wars", false, function(v) Events.islandWars = v end)
mkDropdown(AdminTab, "admin/islandtarget", "Island Wars Target",
    { "Enemies And Base", "Enemies Only", "Base Only" }, "Enemies And Base", function(v) Events.islandTarget = v end)
mkStatus(AdminTab, "islandwars", "Events: idle")

--══════════════════════════ TAB 3: PLAYER ══════════════════════════
local PlayerTab = Window:CreateTab({ Name = "Player", Icon = "🧍" })

mkSection(PlayerTab, "ESP")
mkToggle(PlayerTab, "player/espegg", "ESP Eggs", false, function(v) ESP.eggs = v Tasks.Wake("esp") end)
mkToggle(PlayerTab, "player/espfix", "ESP Fixed Size", false, function(v) ESP.fixed = v end)
mkToggle(PlayerTab, "player/espown", "ESP Own Base Eggs", true, function(v) ESP.ownBase = v end)
mkToggle(PlayerTab, "player/espother", "ESP Other Base Eggs", false, function(v) ESP.otherBase = v end)
mkDropdown(PlayerTab, "player/esprarity", "ESP Min Rarity", rarityChoices, "Off",
    function(v) ESP.minRarity = rarityNumFromLabel(v) end)
mkSlider(PlayerTab, "player/espvalue", "Min ESP Value", 0, 100000, 0, 500, "/s", function(v) ESP.minValue = v end)
mkMulti(PlayerTab, "player/espinfo", "ESP Show Info",
    { "Name", "Rarity", "Value", "Mutation", "Size", "Weight", "Area", "Distance", "State" },
    function(l) ESP.info = listToSet(l) end)
mkSlider(PlayerTab, "player/espeggsize", "ESP Egg Size", 50, 200, 75, 5, "", function(v) ESP.eggSize = v end)
mkToggle(PlayerTab, "player/espguard", "ESP Guards", false, function(v) ESP.guards = v end)
mkSlider(PlayerTab, "player/espguardsize", "ESP Guard Size", 50, 200, 75, 5, "", function(v) ESP.guardSize = v end)
mkToggle(PlayerTab, "player/espplayer", "ESP Players", false, function(v) ESP.players = v end)
mkMulti(PlayerTab, "player/espplayerinfo", "ESP Player Info", { "Name", "Distance", "Tool" },
    function(l) ESP.playerInfo = listToSet(l) end)
mkSlider(PlayerTab, "player/espplayersize", "ESP Player Size", 50, 200, 75, 5, "", function(v) ESP.playerSize = v end)

mkSection(PlayerTab, "Movement")
mkToggle(PlayerTab, "player/speed", "Speed Boost", false, function(v)
    Char.speed = v
    if not v then
        local hum = Movement.Humanoid()
        if hum then hum.WalkSpeed = 16 end
    end
end)
mkSlider(PlayerTab, "player/boost", "Boost Speed", 20, 1000, 350, 10, " spd", function(v) Char.boost = v end)
mkToggle(PlayerTab, "player/jump", "Infinite Jump", false, function(v) Char.__setJump(v) end)

mkSection(PlayerTab, "Character")
mkToggle(PlayerTab, "player/invis", "Invisibility", false, function(v)
    Char.invisible = v
    Character.ApplyInvisibility(v)
end)
mkToggle(PlayerTab, "player/antiragdoll", "Anti Ragdoll", true, function(v) Char.antiRagdoll = v end)
mkToggle(PlayerTab, "player/antitrap", "Anti Trap", true, function(v) Char.antiTrap = v end)
mkToggle(PlayerTab, "player/prompts", "Instant Prompts", true, function(v) Char.instantPrompts = v end)
mkToggle(PlayerTab, "player/antiguard", "Anti Guard", false, function(v) Char.antiGuard = v end)

mkSection(PlayerTab, "Combat")
mkToggle(PlayerTab, "player/hit", "Auto Hit Nearest Player", false, function(v) Hit.on = v end)
mkDropdown(PlayerTab, "player/hittarget", "Hit Player", { "Nearest player", "Egg holders" }, "Nearest player",
    function(v) Hit.targets = v end)
mkToggle(PlayerTab, "player/hitaura", "Hit Aura", false, function(v) Hit.aura = v end)
mkSlider(PlayerTab, "player/hitspeed", "Hit Tween Speed", 100, 1000, 400, 20, "", function(v) Hit.tweenSpeed = v end)
mkSlider(PlayerTab, "player/hitmax", "Hit Max Speed", 100, 1000, 750, 20, "", function(v) Hit.maxSpeed = v end)
mkSlider(PlayerTab, "player/hitlead", "Hit Lead", -400, 100, -275, 25, "", function(v) Hit.lead = v end)
mkSlider(PlayerTab, "player/hitsweep", "Hit Sweep", 0, 250, 60, 10, "", function(v) Hit.sweep = v end)
mkSlider(PlayerTab, "player/hitrate", "Weapon Rate", 0.2, 1.5, 0.6, 0.1, "s", function(v) Hit.rate = v end)

--══════════════════════════ TAB 4: PREDICTOR ══════════════════════════
local PredTab = Window:CreateTab({ Name = "Predictor", Icon = "🔮" })

mkSection(PredTab, "Egg Predictor")
mkDropdown(PredTab, "pred/sort", "Sort By", { "Value", "Rarity", "Time Left" }, "Value",
    function(v) Predictor.sortBy = v Tasks.Wake("predictor") end)
mkToggle(PredTab, "pred/preview", "Preview Card", true, function(v) Predictor.preview = v end)
mkStatus(PredTab, "predictor", "Predictor: menghubungkan...")

mkSection(PredTab, "Discord Webhook (milikmu sendiri)")
mkInput(PredTab, "pred/webhook", "Webhook URL", "https://discord.com/api/webhooks/...", function(v) Webhook.url = v end)
mkToggle(PredTab, "pred/everyone", "Ping @everyone", false, function(v) Webhook.everyone = v end)
mkMulti(PredTab, "pred/events", "Notify On",
    { "Egg Stolen", "Egg Delivered", "Egg Fused", "Rare Spawn", "Shooting Star", "Halloween Egg" },
    function(l) Webhook.events = listToSet(l) end)
mkDropdown(PredTab, "pred/webhookrarity", "Webhook Min Rarity", rarityChoices, "Off",
    function(v) Webhook.minRarity = rarityNumFromLabel(v) end)
mkSlider(PredTab, "pred/webhookvalue", "Webhook Min Value", 0, 100000, 0, 500, "/s",
    function(v) Webhook.minValue = v end)

--══════════════════════════ TAB 5: PROGRESS ══════════════════════════
local ProgTab = Window:CreateTab({ Name = "Progress", Icon = "📈" })

mkSection(ProgTab, "Auto Progression")
mkToggle(ProgTab, "prog/trail", "Auto Buy Trail", false, function(v) TrailState.buy = v Tasks.Wake("trail") end)
mkToggle(ProgTab, "prog/base", "Auto Upgrade Base", false, function(v) BaseState.upgrade = v Tasks.Wake("baseupgrade") end)
mkToggle(ProgTab, "prog/treadup", "Auto Upgrade Treadmill", false, function(v) Tread.upgrade = v end)
mkToggle(ProgTab, "prog/claim", "Auto Claim", false, function(v) ClaimState.claim = v Tasks.Wake("claim") end)
mkToggle(ProgTab, "prog/claimindex", "Auto Claim Index", false, function(v) ClaimState.index = v Tasks.Wake("claimindex") end)
mkToggle(ProgTab, "prog/equip", "Auto Equip Best", false, function(v) Hatch.equipBest = v end)
mkStatus(ProgTab, "base", "Progress: idle")

--══════════════════════════ TAB 6: SERVER ══════════════════════════
local ServerTab = Window:CreateTab({ Name = "Server", Icon = "🌐" })

mkSection(ServerTab, "Server")
mkToggle(ServerTab, "server/autoload", "Auto Load Script", true, function(v) Server.autoLoad = v end)
mkDropdown(ServerTab, "server/hopmode", "Server Hop Mode", { "Least Players", "Most Players", "Random" },
    "Least Players", function(v) Server.hopMode = v end)
mkToggle(ServerTab, "server/rejoin", "Auto Rejoin When Disconnect", true, function(v) Server.autoRejoin = v end)
mkButton(ServerTab, "Server Hop", function() Server.Hop() end)
mkButton(ServerTab, "Rejoin Server", function() Server.Rejoin() end)
mkInput(ServerTab, "server/jobid", "Job ID", "tempel Job ID di sini...")
mkButton(ServerTab, "Join Job ID", function()
    local el = Config.Elements["server/jobid"]
    if el then Server.JoinJobId(tostring(el:Get() or "")) end
end)
mkButton(ServerTab, "Copy Current Job ID", function()
    if setclipboard then
        pcall(setclipboard, JOB_ID)
        Notify("Server", "Job ID disalin: " .. JOB_ID, 4)
    else
        Notify("Server", "Executor tidak punya setclipboard", 4)
    end
end)

mkSection(ServerTab, "Auto Hop")
local autohopToggle = mkToggle(ServerTab, "server/autohop", "Auto Hop", false, function(v)
    Server.hopOn = v
    Server.startedAt = os.clock()
    Tasks.Wake("autohop")
end)
QueueElem["autohop"] = autohopToggle
mkDropdown(ServerTab, "server/hopwhen", "Hop Mode",
    { "Until An Egg Matches", "Steal Then Hop", "After A Rare Spawns" },
    "Until An Egg Matches", function(v) Server.hopWhen = v end)
mkDropdown(ServerTab, "server/waitrarity", "Rarity To Wait For", rarityChoices, "Cosmic",
    function(v) Server.waitRarity = math.max(rarityNumFromLabel(v), 1) end)
mkToggle(ServerTab, "server/hopsync", "Sync With Auto Steal Filters", true, function(v) Server.hopSync = v end)
mkSlider(ServerTab, "server/hopdelay", "First Hop Delay", 3, 10, 5, 1, "s", function(v) Server.firstDelay = v end)
mkStatus(ServerTab, "autohop", "Auto Hop: idle")

--══════════════════════════ TAB 7: MISC ══════════════════════════
local MiscTab = Window:CreateTab({ Name = "Misc", Icon = "⚙️" })

mkSection(MiscTab, "Performance")
mkSlider(MiscTab, "misc/fpscap", "FPS Cap", 30, 1000, 240, 10, " fps", function(v)
    Misc.fpsCap = v
    pcall(function() if setfpscap then setfpscap(v) end end)
end)
mkToggle(MiscTab, "misc/optimizer", "Optimizer", false, function(v)
    Misc.optimizer = v
    applyOptimizer(v)
end)
mkToggle(MiscTab, "misc/fpsping", "FPS and Ping", true, function(v) HUD.fpsPing = v Tasks.Wake("hud") end)
mkSlider(MiscTab, "misc/fpssize", "FPS and Ping Size", 60, 160, 100, 5, "", function(v) HUD.fpsSize = v end)
mkToggle(MiscTab, "misc/render", "Disable 3D Render", false, function(v)
    Misc.renderOff = v
    applyRenderOff(v)
end)
mkDropdown(MiscTab, "misc/bg", "Background Color", { "Black", "White" }, "Black", function(v)
    Misc.bgColor = v
    if Misc.renderOff then applyRenderOff(true) end
end)

mkSection(MiscTab, "Utility")
mkToggle(MiscTab, "misc/hideui", "Hide Game UI", false, function(v)
    Misc.hideUI = v
    applyHideUI(v)
end)
mkToggle(MiscTab, "misc/notify", "Notifications", true, function(v) NotifyState.on = v end)
mkToggle(MiscTab, "misc/openlaunch", "Open On Launch", true, function(v)
    if v then P(function() Window:Show() end) end
end)
mkKeybind(MiscTab, "misc/ukey", "UI Toggle Key", Enum.KeyCode.RightControl, function(bind)
    P(function() ThorUI:SetKeybind(bind) end)
end)

mkSection(MiscTab, "Farm HUD")
mkToggle(MiscTab, "misc/hud", "Farm HUD", false, function(v) HUD.farm = v Tasks.Wake("hud") end)
mkSlider(MiscTab, "misc/hudsize", "HUD Size", 60, 160, 100, 5, "", function(v) HUD.size = v end)
mkMulti(MiscTab, "misc/huditems", "HUD Items", { "Money", "Speed", "Eggs", "Night" },
    function(l) HUD.items = listToSet(l) end)

--══════════════════════════ TAB 8: QUICK ══════════════════════════
local QuickTab = Window:CreateTab({ Name = "Quick", Icon = "⌨️" })

mkSection(QuickTab, "Keybinds Cepat")
QuickTab:AddParagraph({
    Title = "ThorHub Quick",
    Text = "Ganti Pin Pad versi lama dengan keybind: klik pill lalu tekan tombol baru. "
        .. "Keybind aktif tanpa membuka menu (selama Enable Keybinds menyala).",
})
local QuickState = { enabled = true }
mkToggle(QuickTab, "quick/enabled", "Enable Keybinds", true, function(v) QuickState.enabled = v end)

local QuickBinds = {}

local function quickToggle(name, default, key)
    mkKeybind(QuickTab, "quick/" .. key, name, default, function(bind)
        QuickBinds[key] = bind
    end)
end

quickToggle("Auto Steal", Enum.KeyCode.R, "autosteal")
quickToggle("ESP Eggs", Enum.KeyCode.E, "espegg")
quickToggle("Speed Boost", Enum.KeyCode.X, "speed")
quickToggle("Invisibility", Enum.KeyCode.I, "invis")
quickToggle("Auto Sell", Enum.KeyCode.K, "autosell")
quickToggle("Auto Hop", Enum.KeyCode.H, "autohop")
quickToggle("FPS and Ping", Enum.KeyCode.F, "fpsping")

-- jalankan aksi keybind
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if not QuickState.enabled then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local code = input.KeyCode
    local function fire(key, fn)
        local bind = QuickBinds[key]
        if bind and bind == code then
            task.spawn(fn)
        end
    end
    fire("autosteal", function()
        local el = Config.Elements["farm/steal"]
        if el then el:Set(not el:Get()) end
    end)
    fire("espegg", function()
        local el = Config.Elements["player/espegg"]
        if el then el:Set(not el:Get()) end
    end)
    fire("speed", function()
        local el = Config.Elements["player/speed"]
        if el then el:Set(not el:Get()) end
    end)
    fire("invis", function()
        local el = Config.Elements["player/invis"]
        if el then el:Set(not el:Get()) end
    end)
    fire("autosell", function()
        local el = Config.Elements["farm/sellpet"]
        if el then el:Set(not el:Get()) end
    end)
    fire("autohop", function()
        local el = Config.Elements["server/autohop"]
        if el then el:Set(not el:Get()) end
    end)
    fire("fpsping", function()
        local el = Config.Elements["misc/fpsping"]
        if el then el:Set(not el:Get()) end
    end)
end)

mkButton(QuickTab, "Reset Keybinds", function()
    Notify("Quick", "Reset keybind: tekan ulang tombol yang mau diubah", 4)
end)

--══════════════════════════ TAB 9: CONFIG ══════════════════════════
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
    Title = "ThorHub — Steal an Egg (Rewrite)",
    Text = "Menu 100% dibangun dari ThorUi. Semua fitur ditulis ulang native — "
        .. "tanpa kode obfuscate, tanpa promosi. Data game: Directory "
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

-- auto load setelah teleport
if queue_on_teleport and Server.autoLoad then
    queue_on_teleport([[loadstring(game:HttpGet("]] .. SOURCE_URL .. [["))()]])
end

-- reset visibility saat respawn
LocalPlayer.CharacterAdded:Connect(function(char)
    char:WaitForChild("Humanoid", 10)
    task.wait(0.5)
    Character.OnDeathReset()
    if Char.invisible then
        Character.Original = nil
        Character.ApplyInvisibility(true)
    end
    if Char.speed then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = Char.boost end
    end
end)

-- cleanup & destroy handler
local function DestroyAll()
    pcall(function() ESP.RemoveAll() end)
    pcall(function() removeFarmHud() end)
    pcall(function() removeFpsHud() end)
    applyOptimizer(false)
    applyRenderOff(false)
    applyHideUI(false)
    Character.ApplyInvisibility(false)
    if ThorUI then P(function() ThorUI:Destroy() end) end
end

Gill.__THORHUB_SAE_LOADED = true
Gill.__THORHUB_SAE_DESTROY = DestroyAll

Notify("⚡ ThorHub", "Steal an Egg siap! Menu dibangun 100% dari ThorUi.", 6)
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
