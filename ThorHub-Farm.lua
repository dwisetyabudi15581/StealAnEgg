--═══════════════════════════════════════════════════════════════════════════════
--  ⚡ THORHUB — FARM · Steal an Egg
--  ──────────────────────────────────────────────────────────────────────────────
--  Versi      : 5.1  (Auto Steal diperkuat + STEAL PANEL ala kode asli)
--  Library UI : ThorUi  (github.com/dwisetyabudi15581/ThorUi)
--  Platform   : PC & Mobile (drag bebas, keybind RightControl)
--
--  CARA PAKAI (executor):
--    loadstring(game:HttpGet("https://raw.githubusercontent.com/dwisetyabudi15581/StealAnEgg/main/ThorHub-Farm.lua"))()
--
--  ISI — persis TAB FARM kode baru Steal an Egg (11 seksi):
--    1.  AUTO STEAL        — curi telur area/base, Delivery Tween /
--        Instant Steps / Fast Tween, prioritas value/rarity/weight/mutation,
--        filter area & spesies, min rarity & value, missing-index,
--        drop Safe Zone, anti-guard panel, wrong-egg handler, Steal Panel.
--    2.  AUTO PROGRESSION  — beli trail, upgrade base, upgrade treadmill,
--        klaim uang offline, klaim reward index.
--    3.  AUTO MUTATION     — pakai item mutasi (Fractured/Scrambled/
--        Enchanted/Nitro/Spectral) ke telur terpasang.
--    4.  AUTO PLACE EGG    — aturan Always / Steal Idle / After Steal /
--        Night Only, urutan size/value, filter rarity & spesies.
--    5.  AUTO TREADMILL    — naik treadmill di base sendiri.
--    6.  AUTO HATCH & EQUIP — tetaskan telur + pakai pet terbaik.
--    7.  AUTO SELL         — jual pet & telur di bawah batas rarity/value,
--        keep mutasi, daftar hitam, tombol jual sekarang.
--    8.  AUTO FUSE MACHINE — gabungkan pet duplikat di mesin fusion.
--    9.  AUTO FAVORITE     — tandai favorit (aturan Match Any/All,
--        mutasi, spesies, equipped).
--    10. PRIORITY ROTATION — gantian mancing <-> treadmill (Timer /
--        Every Day).
--    11. PRIORITY          — antrian tugas aktif (Task Queue).
--
--  PERBAIKAN v5.1 (hasil audit alur Auto Steal):
--    • Anti-macet: tugas curi dibungkus pcall + watchdog 150 dtk (dulu
--      1 error runtime = Heist.busy nyangkut = mesin mati total).
--    • Snapshot RF: timeout busy 8 dtk (dulu bisa beku selamanya).
--    • Deteksi "membawa telur" diperluas (Tool apa pun + model ber-Hitbox
--      yang di-weld ke karakter — menangkap telur hasil curi base).
--    • Ride.carry meluncurkan Y menuju target (dulu Y terkunci di posisi
--      awal — antaran bisa mandek di elevasi salah).
--    • STEAL PANEL (metode kode asli — hijack HUD game: kloning tombol
--      Pets + frame ActivePets): kartu telur lengkap (rank, warna rarity,
--      nama, $/s, detail, jarak), klik = curi sekarang, ★ prioritas,
--      ▲▼ urut, X batal, tombol Sort (siklus prioritas), Steal (sync
--      toggle), filter All/Halloween/Field, slide, ingat status terbuka.
--    • Chip Anti Guard berganti warna (merah/hijau) + jumlah & jarak
--      guard aktif terdekat (dulu teks putih statis).
--═══════════════════════════════════════════════════════════════════════════════

local THORHUB_VERSION = "5.1"
local THORUI_URL      = "https://raw.githubusercontent.com/dwisetyabudi15581/ThorUi/main/ThorUi.lua"
local CONFIG_FOLDER   = "ThorHub"
local CONFIG_FILE     = "ThorHub_StealAnEgg_Farm.json"

--// ─── Layanan Roblox ──────────────────────────────────────────────────────────
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local StarterGui        = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

--// ─── Helper aman (semua akses dunia game dibungkus pcall) ───────────────────
local function safe(fn, ...)
    local ok, res = pcall(fn, ...)
    if ok then return res end
    return nil
end

local function toastOS(title, text, duration)
    safe(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = duration or 5,
        })
    end)
end

-- format angka ringkas: 1500 -> 1.50K, 2500000 -> 2.50M
local function fmtNum(n)
    n = tonumber(n) or 0
    local neg = n < 0
    if neg then n = -n end
    local units = { "", "K", "M", "B", "T", "Qa" }
    local i = 1
    while n >= 1000 and i < #units do
        n = n / 1000
        i = i + 1
    end
    local text
    if i == 1 then
        text = tostring(math.floor(n))
    elseif n >= 100 then
        text = string.format("%.0f", n)
    elseif n >= 10 then
        text = string.format("%.1f", n)
    else
        text = string.format("%.2f", n)
    end
    return (neg and "-" or "") .. text .. units[i]
end

--═══════════════════════════════════════════════════════════════════════════════
--  BAGIAN 1 · NET — jembatan remote game
--  (semua remote Steal an Egg berada di ReplicatedStorage.Packages.Networking,
--   dengan nama "RE/..." = RemoteEvent dan "RF/..." = RemoteFunction)
--═══════════════════════════════════════════════════════════════════════════════
local Net = {}
do
    local hub = nil

    local function resolveHub()
        if hub ~= nil then return hub end
        local pk = ReplicatedStorage:FindFirstChild("Packages")
        hub = (pk and pk:FindFirstChild("Networking")) or false
        return hub
    end

    function Net.ready()
        return resolveHub() ~= false
    end

    function Net.get(path)
        local h = resolveHub()
        if not h then return nil end
        return h:FindFirstChild(path)
    end

    function Net.fire(path, ...)
        local r = Net.get(path)
        if r and r:IsA("RemoteEvent") then
            return safe(function(...) r:FireServer(...) end, ...) or true
        end
        return false
    end

    function Net.invoke(path, ...)
        local r = Net.get(path)
        if r and r:IsA("RemoteFunction") then
            return safe(function(...) return r:InvokeServer(...) end, ...)
        end
        return nil
    end
end

if not Net.ready() then
    toastOS("⚡ ThorHub", "Game salah! Script ini khusus Steal an Egg.", 7)
    error("[ThorHub] Steal an Egg tidak terdeteksi (ReplicatedStorage.Packages.Networking tidak ada).")
end

--═══════════════════════════════════════════════════════════════════════════════
--  BAGIAN 2 · VAULT — replika data pemain (inventaris telur & pet)
--  Game meletakkan replika save di ModuleScript sisi client supaya UI-nya
--  sendiri bisa membaca; kami mencarinya dengan probe aman (pcall penuh):
--    • modul langsung berbentuk {Inventory, EggInventory, ...}
--    • modul dengan field .state / .data / .profile / ...
--    • modul dengan .Get() / .Peek() yang mengembalikan tabel save
--═══════════════════════════════════════════════════════════════════════════════
local Vault = { bound = false, getter = nil }
do
    local function looksLikeSave(t)
        return type(t) == "table"
            and (type(t.Inventory) == "table" or type(t.EggInventory) == "table")
    end

    local function probeModule(mod)
        if type(mod) ~= "table" then return nil end
        if looksLikeSave(mod) then
            return function() return mod end
        end
        for _, key in ipairs({ "state", "data", "State", "Data", "save", "Save", "profile", "Profile" }) do
            if looksLikeSave(mod[key]) then
                local snapshot = mod[key]
                return function() return snapshot end
            end
        end
        for _, key in ipairs({ "Get", "Peek", "GetAll" }) do
            if type(mod[key]) == "function" then
                if looksLikeSave(safe(mod[key], mod)) then
                    return function() return safe(mod[key], mod) end
                end
            end
        end
        return nil
    end

    local function scanRoot(root)
        for _, inst in ipairs(root:GetChildren()) do
            if inst:IsA("ModuleScript") then
                local low = string.lower(inst.Name)
                if string.find(low, "save", 1, true) or string.find(low, "data", 1, true)
                    or string.find(low, "state", 1, true) or string.find(low, "session", 1, true)
                    or string.find(low, "profile", 1, true) or string.find(low, "replica", 1, true) then
                    local getter = probeModule(safe(require, inst))
                    if getter then return getter end
                end
            end
        end
        return nil
    end

    for _, root in ipairs({
        ReplicatedStorage:FindFirstChild("Packages"),
        ReplicatedStorage:FindFirstChild("Shared"),
        ReplicatedStorage,
    }) do
        if root and not Vault.getter then
            Vault.getter = scanRoot(root)
        end
    end
    Vault.bound = Vault.getter ~= nil
end

function Vault.raw()
    if not Vault.getter then return nil end
    return Vault.getter()
end

function Vault.leader(name)
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    local v = ls and ls:FindFirstChild(name)
    if v then return tonumber(v.Value) end
    return nil
end

function Vault.money()      return Vault.leader("Money") or 0 end
function Vault.speedPower() return Vault.leader("Speed") or 0 end

-- samakan bentuk entri telur / pet jadi satu pola internal ThorHub
local function normEntry(e, isEgg)
    return {
        category  = tostring((isEgg and e.AssetCategory) or e.Category or ""),
        scale     = tonumber(e.AssetScale or e.Scale) or 1,
        mutations = (type(e.Mutations) == "table") and e.Mutations or {},
        placed    = e.Placement ~= nil,
    }
end

function Vault.eggs()
    local out = {}
    local save = Vault.raw()
    if type(save) == "table" and type(save.EggInventory) == "table" then
        for uid, e in pairs(save.EggInventory) do
            if type(e) == "table" then out[tostring(uid)] = normEntry(e, true) end
        end
    end
    return out
end

function Vault.pets()
    local out = {}
    local save = Vault.raw()
    if type(save) == "table" and type(save.Inventory) == "table" then
        for uid, e in pairs(save.Inventory) do
            if type(e) == "table" then out[tostring(uid)] = normEntry(e, false) end
        end
    end
    return out
end

function Vault.bagEggs()
    local out = {}
    for uid, e in pairs(Vault.eggs()) do
        if not e.placed then out[uid] = e end
    end
    return out
end

function Vault.placedEggs()
    local out = {}
    for uid, e in pairs(Vault.eggs()) do
        if e.placed then out[uid] = e end
    end
    return out
end

function Vault.baseLevel()
    local save = Vault.raw()
    return (save and tonumber(save.BaseUpgradeLevel)) or 0
end

-- level upgrade treadmill (dipakai Auto Upgrade Treadmill: cek harga tier berikut)
function Vault.treadmillLevel()
    local save = Vault.raw()
    return (save and tonumber(save.TreadmillUpgradeLevel)) or 0
end

-- uid pet yang sedang dipakai (dipakai Auto Favorite Equipped)
function Vault.equipped()
    local out = {}
    local save = Vault.raw()
    if type(save) == "table" and type(save.EquippedAssets) == "table" then
        for uid in pairs(save.EquippedAssets) do
            table.insert(out, tostring(uid))
        end
    end
    return out
end

-- set spesies yang sudah dimiliki (dipakai Steal Missing Index)
function Vault.ownedSpecies()
    local save = Vault.raw()
    local set = {}
    if type(save) == "table" then
        for _, key in ipairs({ "Inventory", "EggInventory" }) do
            if type(save[key]) == "table" then
                for _, entry in pairs(save[key]) do
                    if type(entry) == "table" then
                        local cat = entry.Category or entry.AssetCategory
                        if cat then set[tostring(cat)] = true end
                    end
                end
            end
        end
        if type(save.Index) == "table" then
            for sp in pairs(save.Index) do set[tostring(sp)] = true end
        end
    end
    return set
end

--═══════════════════════════════════════════════════════════════════════════════
--  BAGIAN 3 · ATLAS — katalog aset game (rarity, earning rate, nilai telur)
--  Direktori aset di-require dari ModuleScript katalog game, lalu dipakai
--  untuk menghitung rarity (Common..Divine) dan nilai $/detik tiap telur.
--═══════════════════════════════════════════════════════════════════════════════
local Atlas = { dir = nil, mut = nil, dirInst = nil }
do
    local function tryLocate(...)
        local inst = ReplicatedStorage
        for _, seg in ipairs({ ... }) do
            if not inst then return nil end
            inst = safe(function() return inst:WaitForChild(seg, 3) end)
        end
        return inst
    end

    local function tryRequire(...)
        local inst = tryLocate(...)
        if inst and inst:IsA("ModuleScript") then
            return safe(require, inst), inst
        end
        return nil
    end

    for _, path in ipairs({
        { "Shared", "Util", "AssetItems" },
        { "Data", "Assets" },
        { "AssetItems" },
        { "Assets" },
    }) do
        local mod, inst = tryRequire(table.unpack(path))
        if type(mod) == "table" then
            local d = (type(mod.Assets) == "table" and mod.Assets.Directory) or mod.Directory
            if type(d) == "table" then
                for _, v in pairs(d) do
                    if type(v) == "table" and type(v.Rarity) == "table" then
                        Atlas.dir = d
                        Atlas.dirInst = inst
                        break
                    end
                end
            end
        end
        if Atlas.dir then break end
    end

    local m = tryRequire("Shared", "Modules", "Mutations")
    if type(m) == "table" and type(m.EarningsFor) == "function" then
        Atlas.mut = m.EarningsFor
    end
end

local RARITY_NUM  = {
    Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5,
    Mythic = 6, Cosmic = 7, Secret = 8, Eternal = 9, Divine = 10,
}
local RARITY_LIST = {
    "Common", "Uncommon", "Rare", "Epic", "Legendary",
    "Mythic", "Cosmic", "Secret", "Eternal", "Divine",
}
local RARITY_ANY = { "Any" }
for _, r in ipairs(RARITY_LIST) do table.insert(RARITY_ANY, r) end
local function rarNum(name)
    return RARITY_NUM[name] or 0
end

function Atlas.spec(name)
    if Atlas.dir then return Atlas.dir[name] end
    return nil
end

function Atlas.rarity(name)
    local s = Atlas.spec(name)
    if type(s) == "table" and type(s.Rarity) == "table" then
        local r = s.Rarity
        local label = tostring(r.DisplayName or r._id or "")
        return label, (tonumber(r.RarityNumber or r.Rank) or RARITY_NUM[label] or 0)
    end
    return "", 0
end

-- nilai telur $/detik: earning rate x pengali ukuran x pengali mutasi
function Atlas.value(name, scale, mutations)
    local s = Atlas.spec(name)
    local rate = (s and tonumber(s.EarningRate)) or 0
    local size = tonumber(scale) or 1
    local sizeMult
    if size > 5 then
        sizeMult = (size / 5) ^ 1.2 * 19.637875755794113
    else
        sizeMult = size ^ 1.85
    end
    local mutMult = 1
    if Atlas.mut and type(mutations) == "table" then
        local m = safe(Atlas.mut, mutations)
        if type(m) == "number" then mutMult = m end
    end
    return rate * sizeMult * mutMult
end

function Atlas.petSpecies()
    local out = {}
    if Atlas.dir then
        for name, s in pairs(Atlas.dir) do
            if type(s) == "table" and type(s.Rarity) == "table" and type(s.Egg) ~= "table" then
                table.insert(out, tostring(name))
            end
        end
    end
    table.sort(out)
    return out
end

function Atlas.eggSpecies()
    local out = {}
    if Atlas.dir then
        for name, s in pairs(Atlas.dir) do
            if type(s) == "table" and type(s.Egg) == "table" then
                table.insert(out, tostring(name))
            end
        end
    end
    table.sort(out)
    return out
end


--// ─── siklus malam (dipakai Place Egg Rule "Night Only") ────────────────────
-- game menghitung fase malam lewat modul AreaEggCycle.IsNightPhase(waktuServer)
local cycleMod = nil
function Atlas.isNight()
    if cycleMod == nil then
        cycleMod = safe(function()
            return require(ReplicatedStorage:WaitForChild("Shared", 5)
                :WaitForChild("Util", 3):WaitForChild("AreaEggCycle", 3))
        end) or false
    end
    if type(cycleMod) == "table" and type(cycleMod.IsNightPhase) == "function" then
        local res = safe(cycleMod.IsNightPhase, safe(function() return workspace:GetServerTimeNow() end))
        if res ~= nil then return res == true end
    end
    return false
end

--// ─── folder trail (dipakai Auto Buy Trail) ─────────────────────────────────
-- daftar trail ada sebagai anak folder "Trailwear"/"Trails"/"TrailWear"
-- berdekatan dengan katalog aset (AssetItems).
function Atlas.trailsFolder()
    local parents = {}
    if Atlas.dirInst and Atlas.dirInst.Parent then
        table.insert(parents, Atlas.dirInst.Parent)
    end
    table.insert(parents, safe(function() return ReplicatedStorage:FindFirstChild("Data") end))
    table.insert(parents, ReplicatedStorage)
    for _, parent in ipairs(parents) do
        if parent then
            for _, cand in ipairs({ "Trailwear", "Trails", "TrailWear" }) do
                local f = safe(function() return parent:FindFirstChild(cand) end)
                if f then return f end
            end
        end
    end
    return nil
end

--// ─── tabel treadmill (dipakai Auto Upgrade Treadmill: cek harga tier) ──────
local treadTable = nil
function Atlas.treadmillData()
    if treadTable == nil then
        local inst = safe(function()
            return ReplicatedStorage:WaitForChild("Data", 5):WaitForChild("Treadmills", 3)
        end)
        local mod = (inst and inst:IsA("ModuleScript")) and safe(require, inst) or nil
        treadTable = (type(mod) == "table") and mod or false
    end
    if type(treadTable) == "table" then return treadTable end
    return nil
end

--// ─── cek spesies belum ada di Index/koleksi (dipakai Missing Index) ────────
local indexMiss, indexAt = nil, 0
function Atlas.indexMissing(name)
    if type(name) ~= "string" or name == "" then return false end
    local now = os.clock()
    if indexMiss and now - indexAt < 5 then
        return indexMiss[name] == true
    end
    indexAt = now
    indexMiss = {}
    local owned = Vault.ownedSpecies()
    for _, sp in ipairs(Atlas.eggSpecies()) do
        if not owned[sp] then indexMiss[sp] = true end
    end
    return indexMiss[name] == true
end
--═══════════════════════════════════════════════════════════════════════════════
--  BAGIAN 4 · HOME — petak base milik sendiri
--  Plot dicari lewat papan nama (PlotSign -> PlayerName), titik jangkar
--  dihitung dari rata-rata posisi telur terpasang kita di PlacedEggRenders.
--═══════════════════════════════════════════════════════════════════════════════
local Home = {}
do
    local anchorCache, anchorAt = nil, 0

    function Home.plot()
        local plots = workspace:FindFirstChild("Plots")
        if not plots then return nil end
        local me = string.lower(LocalPlayer.Name)
        local disp = string.lower(LocalPlayer.DisplayName)
        for _, plot in ipairs(plots:GetChildren()) do
            local sign = plot:FindFirstChild("PlotSign", true)
            local board = sign and sign:FindFirstChild("PlayerPlotSign", true)
            local frame = board and board:FindFirstChild("Frame", true)
            local label = frame and frame:FindFirstChild("PlayerName", true)
            if label and label:IsA("TextLabel") then
                local t = string.lower(label.Text)
                if t ~= "" and (t == me or t == disp) then
                    return plot
                end
            end
        end
        return nil
    end

    function Home.anchor()
        local now = os.clock()
        if anchorCache and (now - anchorAt) < 5 then return anchorCache end
        anchorAt = now

        local renders = workspace:FindFirstChild("PlacedEggRenders")
        local me = tostring(LocalPlayer.UserId)
        if renders then
            local sum, n = Vector3.new(0, 0, 0), 0
            for _, m in ipairs(renders:GetChildren()) do
                if string.find(m.Name, me, 1, true) then
                    local cf = safe(function()
                        if m:IsA("Model") then return m:GetPivot() end
                        return m.CFrame
                    end)
                    if cf then
                        sum = sum + cf.Position
                        n = n + 1
                    end
                end
            end
            if n > 0 then
                anchorCache = sum / n
                return anchorCache
            end
        end

        local plot = Home.plot()
        if plot then
            local up = plot:FindFirstChild("ToUpdate", true)
            local pen = (up and up:FindFirstChild("StarterPen"))
                or plot:FindFirstChild("StarterPen")
                or plot:FindFirstChild("CenterPoint")
            local cf = pen and safe(function()
                if pen:IsA("Model") then return pen:GetPivot() end
                return pen.CFrame
            end)
            if cf then
                anchorCache = cf.Position
                return anchorCache
            end
            local bb = safe(function()
                local _, c = plot:GetBoundingBox()
                return c
            end)
            if bb then
                anchorCache = bb.Position
                return anchorCache
            end
        end
        return anchorCache
    end
end

--═══════════════════════════════════════════════════════════════════════════════
--  BAGIAN 4A · PREY — inventaris telur yang bisa dicuri
--  Sumber: (1) snapshot remote RF/EggWorld/AskFieldEggSnapshot (.Records),
--          (2) scan folder AreaEggSlotsClient (fallback bila RF tak terjangkau),
--          (3) model GUID-32 ber-Hitbox di akar workspace (telur tercecer),
--          (4) telur terpasang di base pemain lain (PlacedEggRenders +
--              ProximityPrompt "StealPrompt" yang masih aktif).
--═══════════════════════════════════════════════════════════════════════════════
local Prey = {}
do
    --// snapshot non-blocking: invoke jalan di task terpisah, hasil di-cache.
    -- v5.1: busy punya TIMEOUT 8 dtk — InvokeServer yang menggantung tidak
    -- lagi membekukan snapshot selamanya (bug lama: snapBusy tak pernah
    -- reset -> daftar target bergantung fallback scan saja).
    local snap, snapAt, snapBusy, snapBusyAt, snapFails =
        nil, -math.huge, false, 0, 0
    function Prey.snapshot(maxAge)
        local now = os.clock()
        if snap and (now - snapAt) < (maxAge or 2) then return snap end
        if snapBusy then
            if (now - snapBusyAt) > 8 then
                snapBusy = false      -- invoke menggantung: anggap gagal
                snapFails = snapFails + 1
            else
                return snap
            end
        end
        if snapFails >= 5 and snap and (now - snapAt) < 15 then return snap end
        snapBusy = true
        snapBusyAt = now
        task.spawn(function()
            local ok, res = pcall(Net.invoke, "RF/EggWorld/AskFieldEggSnapshot")
            if ok and type(res) == "table" and type(res.Records) == "table" then
                snap, snapAt, snapFails = res, os.clock(), 0
            else
                snapFails = snapFails + 1
            end
            snapBusy = false
        end)
        return snap
    end

    function Prey.snapshotOK()
        return type(snap) == "table" and type(snap.Records) == "table"
    end

    --// posisi model apa pun (Model -> pivot; part -> CFrame)
    function Prey.modelPos(m)
        return safe(function()
            if m:IsA("Model") then return m:GetPivot().Position end
            return m.CFrame.Position
        end)
    end

    --// model telur yang di-weld ke karakter pemain mana pun -> karakter itu
    -- (dipakai untuk mendeteksi "telur sudah diambil orang" / HeldByMe)
    function Prey.weldCarrier(m)
        return safe(function()
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

    --// nama spesies telur dari model: atribut -> teks billboard -> nama model
    local function eggLabel(m)
        for _, attr in ipairs({ "PreparedSourceName", "AssetCategory", "Category", "EggName", "SourceName" }) do
            local v = safe(function() return m:GetAttribute(attr) end)
            if v and tostring(v) ~= "" then return tostring(v) end
        end
        local bb = safe(function() return m:FindFirstChildWhichIsA("BillboardGui", true) end)
        if bb then
            local kids = safe(function() return bb:GetDescendants() end) or {}
            for _, d in ipairs(kids) do
                local txt = safe(function()
                    if d:IsA("TextLabel") or d:IsA("TextButton") then return d.Text end
                    return nil
                end)
                if type(txt) == "string" and #txt > 2 and not string.match(txt, "^[%d.,/]+$") then
                    return txt
                end
            end
        end
        return tostring(m.Name)
    end

    --// ukuran telur dari atribut
    local function eggScale(m)
        local s = safe(function() return m:GetAttribute("AssetScale") end)
            or safe(function() return m:GetAttribute("Scale") end)
        return tonumber(s) or 1
    end

    --// entri seragam telur
    local function entry(o)
        local label, num = Atlas.rarity(o.category or o.name)
        return {
            uid = o.uid, key = o.key, kind = o.kind or "Field",
            model = o.model, prompt = o.prompt,
            name = o.name, category = o.category or o.name,
            rarityLabel = label, rarityNum = num,
            scale = o.scale or 1, mutations = o.mutations or {},
            value = Atlas.value(o.category or o.name, o.scale or 1, o.mutations or {}),
            pos = o.pos, area = o.area or "", ownerUid = o.ownerUid,
        }
    end

    --// (1) entri dari record snapshot (Uid/State/AreaId/BottomCFrame/
    -- CarrierUserId/AssetCategory/AssetScale/Mutations)
    local function fromRecord(rec)
        if type(rec) ~= "table" then return nil end
        local uid = rec.Uid and tostring(rec.Uid) or nil
        if not uid or uid == "" then return nil end
        local state = tostring(rec.State or "")
        if state == "Carried" or state == "Claimed" then return nil end
        local cat = tostring(rec.AssetCategory or rec.Category or "")
        local name = cat
        local spec = Atlas.spec(cat)
        if type(spec) == "table" then
            local dn = spec.DisplayName or spec._id
            if dn and tostring(dn) ~= "" then name = tostring(dn) end
        end
        if name == "" then name = uid end
        local model = safe(function()
            local slotFolder = workspace:FindFirstChild("AreaEggSlotsClient")
            return workspace:FindFirstChild(uid)
                or (slotFolder and slotFolder:FindFirstChild(uid))
                or nil
        end)
        local pos = nil
        if typeof(rec.BottomCFrame) == "CFrame" then
            pos = rec.BottomCFrame.Position
        elseif model then
            pos = Prey.modelPos(model)
        end
        return entry({
            uid = uid, key = "F:" .. uid, kind = "Field",
            model = model, prompt = nil, name = name, category = cat,
            scale = tonumber(rec.AssetScale) or 1,
            mutations = (type(rec.Mutations) == "table") and rec.Mutations or {},
            pos = pos, area = tostring(rec.AreaId or ""),
        })
    end

    --// telur area dunia utama (snapshot + scan fallback), cache 2 dtk
    local feCache, feAt = nil, 0
    function Prey.field()
        local now = os.clock()
        if feCache and (now - feAt) < 2 then return feCache end
        feAt = now
        local out, seen = {}, {}

        local snapT = Prey.snapshot(1.2)
        if type(snapT) == "table" and type(snapT.Records) == "table" then
            for _, rec in pairs(snapT.Records) do
                local e = safe(fromRecord, rec)
                if e and not seen[e.key] then
                    seen[e.key] = true
                    table.insert(out, e)
                end
            end
        end

        -- fallback: slot instance yang tak tercakup snapshot
        local slots = workspace:FindFirstChild("AreaEggSlotsClient")
        if slots then
            local kids = safe(function() return slots:GetChildren() end) or {}
            for _, m in ipairs(kids) do
                if safe(function() return m:IsA("Model") end)
                    and not seen["F:" .. m.Name]
                    and not Prey.weldCarrier(m) then
                    local name = eggLabel(m)
                    seen["F:" .. m.Name] = true
                    table.insert(out, entry({
                        uid = tostring(m.Name), key = "F:" .. m.Name, kind = "Field",
                        model = m, prompt = nil, name = name, category = name,
                        scale = eggScale(m), mutations = {},
                        pos = Prey.modelPos(m), area = "",
                    }))
                end
            end
        end

        -- telur tercecer: model GUID-32 ber-Hitbox di akar workspace
        for _, m in ipairs(workspace:GetChildren()) do
            if safe(function() return m:IsA("Model") and #m.Name == 32 end)
                and not seen["F:" .. m.Name]
                and safe(function() return m:FindFirstChild("Hitbox") end)
                and not Prey.weldCarrier(m) then
                local name = eggLabel(m)
                seen["F:" .. m.Name] = true
                table.insert(out, entry({
                    uid = tostring(m.Name), key = "F:" .. m.Name, kind = "Field",
                    model = m, prompt = nil, name = name, category = name,
                    scale = eggScale(m), mutations = {},
                    pos = Prey.modelPos(m), area = "",
                }))
            end
        end

        feCache = out
        return out
    end

    --// UserId pemilik render (nama render mengandung UserId pemilik)
    local function renderOwnerUid(m)
        for _, attr in ipairs({ "OwnerUid", "PlayerUid", "Owner" }) do
            local v = safe(function() return m:GetAttribute(attr) end)
            if v and tostring(v) ~= "" then return tostring(v) end
        end
        if #tostring(m.Name) == 32 then return "" end -- GUID: bukan render pemain
        local digits = {}
        for run in string.gmatch(tostring(m.Name), "%d+") do
            if #run >= 5 then table.insert(digits, run) end
        end
        for _, run in ipairs(digits) do
            local num = tonumber(run)
            if num and safe(Players.GetPlayerByUserId, Players, num) then
                return run
            end
        end
        return digits[1] or ""
    end

    --// model pembawa StealPrompt: model itu sendiri atau anak-anaknya
    local function promptHolders(m, out, depth)
        local direct = safe(function() return m:FindFirstChild("StealPrompt") end)
        if direct and safe(function() return direct:IsA("ProximityPrompt") end) then
            table.insert(out, m)
            return
        end
        if depth and depth <= 0 then return end
        local kids = safe(function() return m:GetChildren() end) or {}
        for _, c in ipairs(kids) do
            promptHolders(c, out, (depth or 2) - 1)
        end
    end

    --// telur terpasang di base pemain lain (bisa dicuri lewat StealPrompt)
    local beCache, beAt = nil, 0
    function Prey.baseEggs()
        local now = os.clock()
        if beCache and (now - beAt) < 3 then return beCache end
        beAt = now
        local out = {}
        local renders = workspace:FindFirstChild("PlacedEggRenders")
        local myUid = tostring(LocalPlayer.UserId)
        if renders then
            local kids = safe(function() return renders:GetChildren() end) or {}
            for _, m in ipairs(kids) do
                local nm = tostring(m.Name)
                if not string.find(nm, myUid, 1, true) then
                    local owner = renderOwnerUid(m)
                    if owner ~= "" and owner ~= myUid then
                        local holders = {}
                        promptHolders(m, holders, 2)
                        for _, holder in ipairs(holders) do
                            local prompt = safe(function()
                                return holder:FindFirstChild("StealPrompt")
                            end)
                            local live = prompt and safe(function()
                                return prompt:IsA("ProximityPrompt") and prompt.Enabled
                            end) or nil
                            if prompt and live then
                                local label = eggLabel(m)
                                table.insert(out, entry({
                                    uid = tostring(safe(function()
                                        return m:GetAttribute("Uid")
                                    end) or nm),
                                    key = "B:" .. nm, kind = "Base",
                                    model = holder, prompt = prompt,
                                    name = label, category = label,
                                    scale = eggScale(m), mutations = {},
                                    pos = Prey.modelPos(holder), area = "",
                                    ownerUid = owner,
                                }))
                            end
                        end
                    end
                end
            end
        end
        beCache = out
        return out
    end

    --// semua target curi (area + base), cache 2 dtk
    local allCache, allAt = nil, 0
    function Prey.all()
        local now = os.clock()
        if allCache and (now - allAt) < 2 then return allCache end
        allAt = now
        local out, seen = {}, {}
        for _, e in ipairs(Prey.field()) do
            if not seen[e.key] then
                seen[e.key] = true
                table.insert(out, e)
            end
        end
        for _, e in ipairs(Prey.baseEggs()) do
            if not seen[e.key] then
                seen[e.key] = true
                table.insert(out, e)
            end
        end
        allCache = out
        return out
    end
end

--═══════════════════════════════════════════════════════════════════════════════
--  BAGIAN 4B · RIDE — primitif gerak & kondisi tubuh
--  Game memakai atribut RagdollEndTime + state Humanoid untuk ragdoll;
--  melawan fisika saat ragdoll hanya bikin server rubber-band (curi gagal).
--═══════════════════════════════════════════════════════════════════════════════
local Ride = {}
do
    function Ride.root()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and hrp:IsDescendantOf(workspace) then return hrp end
        return nil
    end

    function Ride.humanoid()
        local char = LocalPlayer.Character
        return char and char:FindFirstChildOfClass("Humanoid") or nil
    end

    function Ride.walkSpeed()
        local hum = Ride.humanoid()
        return (hum and tonumber(hum.WalkSpeed)) or 100
    end

    -- pulihkan dari ragdoll sekali (pola AntiRagdoll: reset atribut + state)
    function Ride.calm()
        local char = LocalPlayer.Character
        if not char then return end
        local endT = tonumber(safe(function() return char:GetAttribute("RagdollEndTime") end))
        local now = safe(function() return workspace:GetServerTimeNow() end) or 0
        if endT and endT > now then
            safe(function() char:SetAttribute("RagdollEndTime", 0) end)
        end
        local hum = Ride.humanoid()
        if hum then
            if safe(function() return hum.PlatformStand end) then
                safe(function() hum.PlatformStand = false end)
            end
            local st = safe(function() return hum:GetState() end)
            if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll then
                safe(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            end
        end
    end

    function Ride.ragged()
        local char = LocalPlayer.Character
        if not char then return false end
        local endT = tonumber(safe(function() return char:GetAttribute("RagdollEndTime") end))
        if endT then
            local now = safe(function() return workspace:GetServerTimeNow() end) or 0
            if endT > now then return true end
        end
        local hum = Ride.humanoid()
        if hum then
            local st = safe(function() return hum:GetState() end)
            if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll then
                return true
            end
        end
        return false
    end

    -- pulihkan lalu tunggu sampai benar-benar berdiri (maks maxT detik)
    function Ride.waitCalm(maxT)
        local t0 = os.clock()
        while (os.clock() - t0) < (maxT or 2) do
            if not Ride.ragged() then return true end
            Ride.calm()
            task.wait(0.15)
        end
        return not Ride.ragged()
    end

    -- keluar treadmill bila root ter-anchor (velocity tidak berefek saat anchor)
    function Ride.leaveBelt()
        local root = Ride.root()
        if not root then return false end
        if not safe(function() return root.Anchored end) then return false end
        local hum = Ride.humanoid()
        if hum then
            safe(function() hum:UnequipTools() end)
            safe(function() hum.Jump = true end)
        end
        task.wait(0.15)
        if safe(function() return root.Anchored end) then
            safe(function() root.Anchored = false end)
        end
        return true
    end

    -- satu langkah pivot menuju posisi (jarak per langkah dibatasi cap)
    function Ride.step(pos, cap)
        local root = Ride.root()
        if not root then return false end
        local delta = pos - root.Position
        local dist = delta.Magnitude
        if dist < 1 then return true end
        local len = math.min(dist, cap or 40)
        local target = root.Position + delta.Unit * len
        safe(function()
            root.CFrame = CFrame.new(target)
                * CFrame.Angles(0, math.atan(-delta.X, -delta.Z), 0)
        end)
        return dist <= len
    end

    -- terbang bertahap sampai sampai / selesai (done) — dipakai mode Steps
    function Ride.fly(pos, done, step)
        step = step or 40
        local tEnd = os.clock() + 25
        while os.clock() < tEnd do
            local root = Ride.root()
            if not root then return false end
            if done and done() then return true end
            local d = pos - root.Position
            if d.Magnitude < 4 then return true end
            Ride.step(pos, step)
            task.wait()
        end
        return false
    end

    -- antar pakai velocity: matikan collision, jaga ketinggian, pulihkan ragdoll.
    -- speedAbs = kecepatan absolut studs/dtk (Fast Tween / Tween WalkSpeed x1.5)
    -- v5.1: ketinggian jaga (heldY) kini MELUNCUR menuju Y target — dulu
    -- terkunci di Y posisi ambil telur, antaran bisa mandek di elevasi salah
    -- dan verdict tak pernah terpicu.
    function Ride.carry(pos, done, timeout, speedAbs)
        timeout = timeout or 30
        local tEnd = os.clock() + timeout
        local collided = {}
        local root = Ride.root()
        local heldY = root and root.Position.Y or nil
        while os.clock() < tEnd do
            root = Ride.root()
            if not root then break end
            if done and done() then break end
            if heldY == nil then heldY = root.Position.Y end
            -- luncurkan ketinggian jaga menuju ketinggian target (cepat saat
            -- sudah dekat secara horizontal)
            local dHoriz = math.sqrt((pos.X - root.Position.X) ^ 2
                + (pos.Z - root.Position.Z) ^ 2)
            heldY = heldY + (pos.Y - heldY) * (dHoriz < 24 and 0.25 or 0.06)
            if Ride.ragged() then
                Ride.calm()
                task.wait(0.15)
            else
                local char = LocalPlayer.Character
                if char then
                    local parts = safe(function() return char:GetDescendants() end) or {}
                    for _, p in ipairs(parts) do
                        if safe(function() return p:IsA("BasePart") and p.CanCollide end)
                            and not collided[p] then
                            collided[p] = true
                            safe(function() p.CanCollide = false end)
                        end
                    end
                end
                local delta = pos - root.Position
                delta = Vector3.new(delta.X, 0, delta.Z)
                local spd = math.min(speedAbs or 200, delta.Magnitude / 0.05)
                local vel = Vector3.new(0, 0, 0)
                if delta.Magnitude > 3 then
                    vel = delta.Unit * spd
                end
                vel = vel + Vector3.new(0, (heldY - root.Position.Y) * 8, 0)
                safe(function() root.AssemblyLinearVelocity = vel end)
            end
            task.wait()
        end
        root = Ride.root()
        if root then safe(function() root.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end) end
        for p in pairs(collided) do
            if p.Parent then safe(function() p.CanCollide = true end) end
        end
    end

    -- teleport penuh satu frame (pendekatan mode Fast Tween)
    function Ride.jumpTo(pos)
        local root = Ride.root()
        if not root then return false end
        safe(function()
            root.CFrame = CFrame.new(pos)
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end)
        return true
    end
end

--═══════════════════════════════════════════════════════════════════════════════
--  BAGIAN 5 · ENGINE — mesin TAB FARM lengkap (11 seksi, persis menu kode baru)
--  Seksi 1 (Auto Steal) ada di BAGIAN 5B (HEIST). Bagian ini memuat:
--    Progression · Mutation · Place · Treadmill · Hatch & Equip · Sell ·
--    Fuse · Favorite · Rotation (mancing<->treadmill) · Task Queue.
--═══════════════════════════════════════════════════════════════════════════════

local UI = { ThorUi = nil }
function UI.toast() end -- stub; diganti setelah ThorUi termuat

-- label status per seksi (diisi BAGIAN 7 saat UI dibangun)
local Status = {}
local function setStatus(k, text)
    local el = Status[k]
    if el then safe(function() el.SetText(text) end) end
end

-- referensi elemen UI (dipakai rotasi untuk men-toggle seksi lain)
local El = {}

-- deklarasi maju: HEIST (BAGIAN 5B) mengisi tabel ini
local Heist

-- canvas statistik (diisi saat UI dibangun)
local Board, StealBoard = nil, nil

--// ─── state seksi 2-10 tab Farm (sek. 1 Auto Steal = Heist di 5B) ─────────────
local Progress = {
    buyTrail = false, upBase = false, upTread = false,
    claimCash = false, claimIndex = false,
    nextAt = {}, -- gerbang rate-limit per aksi
}

local Mutate = {
    on = false, use = {}, minRarity = "Any", minValue = 0,
    targets = {}, priority = "Highest Value",
    cooldown = {}, done = 0,
}

local Place = {
    on = false, rule = "Always", order = "Biggest Size",
    rarities = {}, specific = {}, minValue = 0, done = 0,
}

local Tread = { on = false, riding = false }

local Hatch = {
    on = false, minRarity = "Any", minValue = 0, specific = {},
    equipBest = false, cooldown = {}, done = 0,
}

local Sell = {
    petOn = false, petMax = "Epic", petValue = 0,
    petKeepMut = true, petBlack = {},
    eggOn = false, eggMax = "Epic", eggValue = 0,
    eggKeepMut = true, eggBlack = {},
}

local Fuse = {
    on = false, mode = "Lowest Rarity First", order = "Lowest To Highest",
    maxRarity = "Divine", species = {}, skipMut = true, eject = true,
    cooldown = 0, done = 0,
}

local Fav = {
    on = false, rule = "Match Any", minRarity = "Any", minValue = 0,
    mutations = {}, species = {}, equipped = false, unfav = false,
    done = 0,
}

local Cycle = {
    on = false, mode = "Timer", fishMin = 5, treadMin = 5,
    phase = "fishing", swapAt = 0, lastNight = nil,
}

-- mesin pancing internal (dipakai Priority Rotation; tanpa UI sendiri —
-- pengaturan pancing ada di tab Event kode asli, rotasi memakai default)
local Angler = { on = false, lastCast = 0, castWait = 7, reelAt = 0 }

-- generator versi: loop lama mati sendiri saat script dijalankan ulang
local GEN = (_G.__THORHUB_FARM_GEN or 0) + 1
_G.__THORHUB_FARM_GEN = GEN

local Engine = {}
function Engine.every(interval, fn)
    task.spawn(function()
        while _G.__THORHUB_FARM_GEN == GEN do
            task.wait(interval)
            if _G.__THORHUB_FARM_GEN == GEN then
                safe(fn)
            end
        end
    end)
end

-- peringatan sekali saja bila replika data belum ketemu
local warnedVault = false
local function needVault()
    if Vault.bound then return true end
    if not warnedVault then
        warnedVault = true
        UI.toast("⏳ Data Belum Siap", "Replika inventaris belum ditemukan — fitur menunggu data...", 6)
    end
    return false
end

-- daftar mutasi tampilan -> id item consumable (pola kode baru)
local MUT_DISPLAY = { "Fractured", "Scrambled", "Enchanted", "Nitro", "Spectral" }
local MUT_TO_ID = {
    Fractured = "Boss", Scrambled = "Scrambled", Enchanted = "Enchanted",
    Nitro = "Nitro", Spectral = "Spectral",
}
local LIMITED_REDEEMS = {
    "LimitedEgg", "GravityDisruptor", "MechaReroll", "BrainrotEgg",
    "BeeLauncher", "MonsterEgg", "Mecha",
}

--// ─── tabel data base (untuk cek biaya upgrade base) ─────────────────────────
local basesTable = nil
local function basesData()
    if basesTable == nil then
        local inst = safe(function()
            return ReplicatedStorage:WaitForChild("Data", 5):WaitForChild("Bases", 3)
        end)
        local mod = (inst and inst:IsA("ModuleScript")) and safe(require, inst) or nil
        basesTable = (type(mod) == "table") and (mod.BASES or mod) or false
    end
    if type(basesTable) == "table" then return basesTable end
    return nil
end

-- gerbang rate-limit progression: aksi maks. sekali per gap detik
local function progGate(k, gap)
    local now = os.clock()
    if (Progress.nextAt[k] or 0) > now then return false end
    Progress.nextAt[k] = now + gap
    return true
end

--═══════════════════════════════════════════════════════════════════════════════
--  MESIN 1 · AUTO PROGRESSION (sek. "Auto Progression")
--═══════════════════════════════════════════════════════════════════════════════
Engine.every(8.0, function()
    if not (Progress.upBase or Progress.upTread or Progress.claimCash
        or Progress.claimIndex or Progress.buyTrail) then return end

    -- Upgrade Base: cek biaya tier berikutnya dari Data/Bases
    if Progress.upBase and progGate("base", 30) then
        local ok = false
        local bases = basesData()
        if bases and Vault.bound then
            local level = Vault.baseLevel()
            local nxt = bases[level + 1]
            if not nxt and type(bases.GetByLevel) == "function" then
                nxt = safe(bases.GetByLevel, level + 1)
            end
            local cost = nxt and tonumber(nxt.Cost)
            if cost and Vault.money() >= cost then
                ok = Net.fire("RE/Homestead/AskBaseTierRaise")
            end
        else
            ok = Net.fire("RE/Homestead/AskBaseTierRaise")
        end
        if ok then
            UI.toast("🏠 Upgrade Base", "Base dinaikkan ke level " .. tostring(Vault.baseLevel() + 1) .. "!", 4)
        end
    end

    -- Upgrade Treadmill: cek harga tier berikutnya dari Data/Treadmills
    if Progress.upTread and progGate("tread", 30) then
        local data = Atlas.treadmillData()
        local bought = false
        if type(data) == "table" and type(data.GetByUpgradeLevel) == "function" and Vault.bound then
            local nxt = safe(data.GetByUpgradeLevel, Vault.treadmillLevel() + 1)
            local price = nxt and tonumber(nxt.Price)
            if price and Vault.money() >= price then
                Net.invoke("RF/Treadmill/AskTierRaise")
                bought = true
            end
        else
            Net.invoke("RF/Treadmill/AskTierRaise")
            bought = true
        end
        if bought then
            UI.toast("🏃 Upgrade Treadmill", "Treadmill dinaikkan ke tier " .. tostring(Vault.treadmillLevel() + 1) .. "!", 4)
        end
    end

    -- Claim Money: cek pending offline lalu klaim
    if Progress.claimCash and progGate("cash", 45) then
        local pending = Net.invoke("RF/AwayEarnings/PendingCheck")
        if pending == nil then
            safe(function() Net.invoke("RF/AwayEarnings/FetchSummary") end)
        end
        local amount = nil
        if type(pending) == "number" then
            amount = pending
        elseif type(pending) == "table" then
            amount = tonumber(pending.amount or pending.Amount or pending.Pending)
        end
        if amount and amount > 0 then
            Net.invoke("RF/AwayEarnings/AskCollect")
            UI.toast("💵 Claim Money", "Cash offline $" .. fmtNum(amount) .. " berhasil diklaim!", 4)
        else
            -- coba klaim langsung (ada sebagian versi game tanpa angka pending)
            Net.invoke("RF/AwayEarnings/AskCollect")
        end
    end

    -- Claim Index: redeem semua reward koleksi + egg terbatas
    if Progress.claimIndex and progGate("index", 300) then
        Net.invoke("RF/Codex/AskRedeemAll")
        for _, nm in ipairs(LIMITED_REDEEMS) do
            safe(function() Net.invoke("RF/Codex/AskRedeemLimitedEgg", nm) end)
        end
    end

    -- Buy Trail: beli semua trail yang belum dibeli dari folder katalog
    if Progress.buyTrail and progGate("trail", 60) then
        local folder = Atlas.trailsFolder()
        if folder then
            local bought = 0
            for _, tr in ipairs(safe(function() return folder:GetChildren() end) or {}) do
                if safe(function() return Net.invoke("RF/Trailwear/AskPurchase", tostring(tr.Name)) end) then
                    bought = bought + 1
                end
            end
            if bought > 0 then
                UI.toast("✨ Buy Trail", bought .. " trail baru berhasil dibeli!", 4)
            end
        end
    end
end)

--═══════════════════════════════════════════════════════════════════════════════
--  MESIN 2 · AUTO MUTATION (sek. "Auto Mutation")
--  Target: telur TERPASANG di base (Placement ~= nil). Coba tiap item mutasi
--  terpilih hingga satu diterima server (RF/BossMastery/AskUseMutationConsumable).
--═══════════════════════════════════════════════════════════════════════════════
local function pickMutateTarget()
    local best, bestKey = nil, -math.huge
    for uid, e in pairs(Vault.placedEggs()) do
        local _, num = Atlas.rarity(e.category)
        local value = Atlas.value(e.category, e.scale, e.mutations)
        if (Mutate.minRarity ~= "Any" and num < rarNum(Mutate.minRarity))
            or (Mutate.minValue > 0 and value < Mutate.minValue)
            or (next(Mutate.targets) ~= nil and not Mutate.targets[e.category])
            or ((Mutate.cooldown[uid] or 0) > os.clock()) then
            -- terfilter / masih jeda: lewati
        else
            local key
            if Mutate.priority == "Best Rarity" then
                key = num
            elseif Mutate.priority == "Biggest Size" then
                key = e.scale
            else
                key = value
            end
            if key > bestKey then best, bestKey = uid, key end
        end
    end
    return best
end

Engine.every(6.0, function()
    if not Mutate.on then return end
    if next(Mutate.use) == nil then
        setStatus("mutate", "Mutate Status  |  pilih minimal 1 mutasi")
        return
    end
    if not needVault() then return end
    local uid = pickMutateTarget()
    if not uid then
        setStatus("mutate", "Mutate Status  |  tidak ada target")
        return
    end
    Mutate.cooldown[uid] = os.clock() + 25
    task.spawn(function()
        for disp, sel in pairs(Mutate.use) do
            if sel then
                local id = MUT_TO_ID[disp] or disp
                local ok = Net.invoke("RF/BossMastery/AskUseMutationConsumable", id, uid)
                if ok == nil then
                    ok = Net.invoke("RF/BossMastery/AskUseMutationConsumable", uid, id)
                end
                if ok then
                    Mutate.done = Mutate.done + 1
                    setStatus("mutate", "Mutate Status  |  " .. tostring(disp) .. " dipakai (#" .. Mutate.done .. ")")
                    break
                end
            end
        end
    end)
end)

--═══════════════════════════════════════════════════════════════════════════════
--  MESIN 3 · AUTO PLACE EGG (sek. "Auto Place Egg")
--  Rule: Always / Steal Idle (jangan saat mengantar curian) /
--  After Steal (hanya 10 dtk setelah verdict sukses) / Night Only.
--═══════════════════════════════════════════════════════════════════════════════
local function pickPlaceEgg()
    local best, bestKey = nil, -math.huge
    for uid, e in pairs(Vault.bagEggs()) do
        local label, num = Atlas.rarity(e.category)
        local value = Atlas.value(e.category, e.scale, e.mutations)
        if (next(Place.rarities) ~= nil and not Place.rarities[label])
            or (next(Place.specific) ~= nil and not Place.specific[e.category])
            or (Place.minValue > 0 and value < Place.minValue) then
            -- terfilter: lewati
        else
            local key
            if Place.order == "Highest Value" then
                key = value
            elseif Place.order == "Smallest Size" then
                key = -e.scale
            else
                key = e.scale
            end
            if key > bestKey then best, bestKey = uid, key end
        end
    end
    return best
end

Engine.every(2.5, function()
    if not Place.on then return end
    if type(Heist) ~= "table" then return end
    if Heist.busy or Heist.carrying then return end -- Auto Steal punya prioritas gerak
    -- aturan timing
    if Place.rule == "Steal Idle" and Heist.on and Heist.carrying then return end
    if Place.rule == "After Steal" and (os.clock() - (Heist.lastVerdict or 0)) > 10 then return end
    if Place.rule == "Night Only" and not Atlas.isNight() then
        setStatus("place", "Pen Status  |  menunggu malam")
        return
    end
    if not needVault() then return end
    local uid = pickPlaceEgg()
    if not uid then return end
    local anchor = Home.anchor()
    if not anchor then
        setStatus("place", "Pen Status  |  base belum ketemu")
        return
    end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root and (root.Position - anchor).Magnitude > 60 then
        safe(function() char:PivotTo(CFrame.new(anchor + Vector3.new(0, 8, 0))) end)
        task.wait(0.25)
    end
    if Net.invoke("RF/EggWorld/AskPlaceEgg", uid) then
        Place.done = Place.done + 1
        setStatus("place", "Pen Status  |  menempatkan telur (#" .. Place.done .. ")")
    end
end)

--═══════════════════════════════════════════════════════════════════════════════
--  MESIN 4 · AUTO TREADMILL (sek. "Auto Treadmill")
--  Cari belt treadmill di petak base sendiri; kalau jauh (> 8 stud) terbang
--  ke sana, kalau sudah dekat status "riding" ( karakter berdiri di belt ).
--═══════════════════════════════════════════════════════════════════════════════
Engine.every(1.0, function()
    if not Tread.on then
        Tread.riding = false
        return
    end
    if type(Heist) == "table" and (Heist.busy or Heist.carrying) then return end
    local plot = Home.plot()
    if not plot then return end
    local root = safe(function()
        local c = LocalPlayer.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end)
    if not root then return end
    -- kumpulkan belt treadmill di plot sendiri
    local belts = {}
    for _, inst in ipairs(safe(function() return plot:GetDescendants() end) or {}) do
        local n = safe(function() return inst.Name:lower() end) or ""
        if (n:find("treadmill", 1, true) or n:find("belt", 1, true)) and safe(function() return inst:IsA("BasePart") end) then
            table.insert(belts, inst)
        end
    end
    if #belts == 0 then return end
    table.sort(belts, function(a, b)
        local pa, pb = safe(function() return a.Position end), safe(function() return b.Position end)
        if not pa or not pb then return false end
        return (pa - root.Position).Magnitude < (pb - root.Position).Magnitude
    end)
    local nearest = safe(function() return belts[1].Position end)
    if not nearest then return end
    if (nearest - root.Position).Magnitude > 8 then
        if Tread.riding then return end
        Tread.riding = true
        task.spawn(function()
            safe(function()
                local tween = game:GetService("TweenService")
                local dist = (nearest - root.Position).Magnitude
                local time = math.max(dist / 35, 0.15)
                tween:Create(root, TweenInfo.new(time, Enum.EasingStyle.Linear), {
                    CFrame = CFrame.new(nearest + Vector3.new(0, 4, 0)),
                }):Play()
                task.wait(time)
            end)
            Tread.riding = false
        end)
    end
end)

--═══════════════════════════════════════════════════════════════════════════════
--  MESIN 5 · AUTO HATCH & EQUIP (sek. "Auto Hatch & Equip")
--═══════════════════════════════════════════════════════════════════════════════
Engine.every(2.0, function()
    if not Hatch.on then return end
    if type(Heist) == "table" and (Heist.busy or Heist.carrying) then return end
    if not needVault() then return end
    local attempts = 0
    for uid, e in pairs(Vault.placedEggs()) do
        if attempts >= 4 then break end
        local _, num = Atlas.rarity(e.category)
        local value = Atlas.value(e.category, e.scale, e.mutations)
        local skip
            = (Hatch.minRarity ~= "Any" and num < rarNum(Hatch.minRarity))
            or (Hatch.minValue > 0 and value < Hatch.minValue)
            or (next(Hatch.specific) ~= nil and not Hatch.specific[e.category])
            or ((Hatch.cooldown[uid] or 0) > os.clock())
        if not skip then
            attempts = attempts + 1
            Hatch.cooldown[uid] = os.clock() + 30
            task.spawn(function()
                local ok = Net.invoke("RF/EggWorld/AskHatch", uid)
                if ok ~= nil and ok ~= false then
                    task.wait(0.35)
                    Net.invoke("RF/EggWorld/AskFinishHatch", uid)
                    Hatch.done = Hatch.done + 1
                end
            end)
        end
    end
end)

Engine.every(10.0, function()
    if not Hatch.equipBest then return end
    Net.invoke("RF/Haul/WearBest")
    Net.invoke("RF/Haul/FetchWearBestStatus")
end)

--═══════════════════════════════════════════════════════════════════════════════
--  MESIN 6 · AUTO SELL (sek. "Auto Sell")
--  Jual pet/telur dengan rarity DI BAWAH batas DAN (nilai DI BAWAH ambang
--  nilai — 0 = abaikan nilai). Pet bermutasi & daftar hitam dipertahankan.
--═══════════════════════════════════════════════════════════════════════════════
local function buildSellList(entries, maxRarity, maxValue, keepMut, blacklist)
    local out = {}
    for uid, e in pairs(entries) do
        local _, num = Atlas.rarity(e.category)
        local value = Atlas.value(e.category, e.scale, e.mutations)
        if keepMut and #e.mutations > 0 then
            -- bermutasi: dipertahankan
        elseif blacklist[e.category] then
            -- daftar hitam: dipertahankan
        elseif num < rarNum(maxRarity) and (maxValue <= 0 or value < maxValue) then
            table.insert(out, uid)
        end
    end
    return out
end

Engine.every(5.0, function()
    if not (Sell.petOn or Sell.eggOn) then return end
    if not needVault() then return end
    local pets = Sell.petOn
        and buildSellList(Vault.pets(), Sell.petMax, Sell.petValue, Sell.petKeepMut, Sell.petBlack)
        or {}
    local eggs = Sell.eggOn
        and buildSellList(Vault.eggs(), Sell.eggMax, Sell.eggValue, Sell.eggKeepMut, Sell.eggBlack)
        or {}
    if #pets > 0 then Net.fire("RE/PetSatchel/SellSelection", pets) end
    if #eggs > 0 then Net.fire("RE/PetSatchel/SellSelection", eggs) end
    if (#pets + #eggs) > 0 then
        UI.toast("💰 Auto Sell", string.format("Menjual %d pet & %d telur", #pets, #eggs), 3)
    end
end)

--═══════════════════════════════════════════════════════════════════════════════
--  MESIN 7 · AUTO FUSE MACHINE (sek. "Auto Fuse Machine")
--  Kumpulkan pet duplikat (>= 2 copy per spesies) -> muat 2 pet ke mesin
--  fusion -> konfirmasi -> fuse -> reveal -> eject slot sisa.
--═══════════════════════════════════════════════════════════════════════════════
local function fuseCandidates()
    local groups = {}
    for uid, e in pairs(Vault.pets()) do
        local label, num = Atlas.rarity(e.category)
        if num > rarNum(Fuse.maxRarity) then
            -- di atas batas rarity: jangan dijadikan bahan
        elseif next(Fuse.species) ~= nil and not Fuse.species[e.category] then
            -- bukan spesies terpilih
        elseif Fuse.skipMut and #e.mutations > 0 then
            -- bermutasi: dilewati
        else
            if not groups[e.category] then
                groups[e.category] = { rarity = num, copies = 0, value = 0, list = {} }
            end
            local g = groups[e.category]
            g.copies = g.copies + 1
            g.value = g.value + Atlas.value(e.category, e.scale, e.mutations)
            table.insert(g.list, uid)
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
        if Fuse.mode == "Most Copies First" then return a.copies > b.copies end
        if Fuse.mode == "Lowest Value First" then return a.value < b.value end
        return false
    end)
    return out
end

Engine.every(10.0, function()
    if not Fuse.on then return end
    if not needVault() then return end
    if os.clock() < Fuse.cooldown then return end
    local groups = fuseCandidates()
    local n = #groups
    if n == 0 then
        setStatus("fuse", "Fuse Preview  |  tidak ada pasangan pet")
        return
    end
    -- teks preview: "3x SpesiesA · 2x SpesiesB"
    local names = {}
    for cat, g in pairs(groups) do
        table.insert(names, g.copies .. "x " .. tostring(cat))
    end
    table.sort(names)
    local show = names
    if #show > 3 then
        show = { names[1], names[2], names[3] .. " (+" .. (#names - 3) .. ")" }
    end
    setStatus("fuse", "Fuse Preview  |  " .. (#show > 0 and table.concat(show, " · ") or "-"))
    Fuse.cooldown = os.clock() + 12
    local g = groups[1]
    local a, b = g.list[1], g.list[2]
    if Fuse.order == "Highest To Lowest" then
        a, b = g.list[#g.list], g.list[#g.list - 1]
    end
    task.spawn(function()
        Net.invoke("RF/Fusery/LoadPet", a)
        task.wait(0.3)
        Net.invoke("RF/Fusery/LoadPet", b)
        task.wait(0.3)
        Net.invoke("RF/Fusery/ConfirmBriefing")
        task.wait(0.3)
        Net.invoke("RF/Fusery/BeginFuse")
        task.wait(1.2)
        Net.invoke("RF/Fusery/FinishReveal")
        Fuse.done = Fuse.done + 1
        setStatus("fuse", "Fusing  |  fusion ke-" .. Fuse.done .. " selesai")
        if Fuse.eject then
            task.wait(0.2)
            Net.invoke("RF/Fusery/EjectPet")
        end
    end)
end)

--═══════════════════════════════════════════════════════════════════════════════
--  MESIN 8 · AUTO FAVORITE (sek. "Auto Favorite")
--  Aturan pencocokan: rarity minimal, nilai minimal, mutasi, spesies —
--  digabung dengan "Match Any" (cukup satu lolos) / "Match All" (semua).
--═══════════════════════════════════════════════════════════════════════════════
local function favMatches(e)
    local label, num = Atlas.rarity(e.category)
    local checks = {}
    if Fav.minRarity ~= "Any" then
        table.insert(checks, num >= rarNum(Fav.minRarity))
    end
    if Fav.minValue > 0 then
        table.insert(checks, Atlas.value(e.category, e.scale, e.mutations) >= Fav.minValue)
    end
    if next(Fav.mutations) ~= nil then
        local hit = false
        if Fav.mutations["No Mutation"] and #e.mutations == 0 then
            hit = true
        elseif Fav.mutations["Any Mutation"] and #e.mutations > 0 then
            hit = true
        else
            for _, m in ipairs(e.mutations) do
                if Fav.mutations[tostring(m)] then hit = true break end
            end
        end
        table.insert(checks, hit)
    end
    if next(Fav.species) ~= nil then
        table.insert(checks, Fav.species[e.category] == true)
    end
    if #checks == 0 then return false end
    local pass = 0
    for _, ok in ipairs(checks) do
        if ok then pass = pass + 1 end
    end
    if Fav.rule == "Match All" then return pass == #checks end
    return pass > 0
end

Engine.every(6.0, function()
    if not (Fav.on or Fav.equipped or Fav.unfav) then return end
    if not needVault() then return end
    if Fav.on then
        local list = {}
        for uid, e in pairs(Vault.pets()) do
            if favMatches(e) then table.insert(list, uid) end
        end
        if #list > 0 then
            Net.fire("RE/PetSatchel/WriteFavourite", list, true)
            Fav.done = Fav.done + #list
        end
    end
    if Fav.equipped or Fav.unfav then
        local equipped = Vault.equipped()
        if #equipped > 0 then
            Net.fire("RE/PetSatchel/WriteFavourite", equipped, Fav.equipped)
        end
    end
end)

--═══════════════════════════════════════════════════════════════════════════════
--  MESIN 9 · PRIORITY ROTATION (sek. "Priority Rotation")
--  Gantian mancing <-> treadmill. Timer: tukar tiap N menit.
--  Every Day: tukar setiap pergantian fase siang/malam game.
--═══════════════════════════════════════════════════════════════════════════════
local function cycleApply(fishing)
    Cycle.phase = fishing and "fishing" or "treadmill"
    Angler.on = fishing
    Tread.on = not fishing
    Tread.riding = false
    local el = El.tread
    if el then safe(function() el:Set(not fishing, false) end) end
end

Engine.every(1.5, function()
    if not Angler.on then return end
    local now = os.clock()
    if now - Angler.lastCast < Angler.castWait then return end
    local root = safe(function()
        local c = LocalPlayer.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end)
    if not root then return end
    Angler.lastCast = now
    local pos = safe(function() return root.Position end)
    if not pos then return end
    safe(function() Net.invoke("RF/Fishing/Cast", pos) end)
    task.delay(Angler.castWait - 1.5, function()
        safe(function() Net.invoke("RF/Fishing/Reel") end)
        safe(function() Net.invoke("RF/Fishing/Reel", true) end)
    end)
end)

Engine.every(5.0, function()
    if not Cycle.on then
        Cycle.swapAt = 0
        return
    end
    local now = os.clock()
    if Cycle.mode == "Timer" then
        if Cycle.swapAt == 0 then
            Cycle.swapAt = now + Cycle.fishMin * 60
            cycleApply(true)
            setStatus("rotation", "Rotation  |  memancing")
        elseif now >= Cycle.swapAt then
            local toFishing = Cycle.phase ~= "fishing"
            Cycle.swapAt = now + (toFishing and Cycle.fishMin or Cycle.treadMin) * 60
            cycleApply(toFishing)
            setStatus("rotation", toFishing and "Rotation  |  memancing" or "Rotation  |  treadmill")
        else
            local left = math.max(0, Cycle.swapAt - now)
            setStatus("rotation", "Rotation  |  " .. Cycle.phase
                .. " — tukar " .. math.floor(left / 60) .. "m " .. math.floor(left % 60) .. "s")
        end
    else -- Every Day: tukar tiap pergantian siang <-> malam
        local night = Atlas.isNight()
        if Cycle.lastNight == nil then
            Cycle.lastNight = night
            cycleApply(true)
            setStatus("rotation", "Rotation  |  memancing")
        elseif night ~= Cycle.lastNight then
            Cycle.lastNight = night
            cycleApply(Cycle.phase ~= "fishing")
            setStatus("rotation", Cycle.phase == "fishing" and "Rotation  |  memancing" or "Rotation  |  treadmill")
        else
            setStatus("rotation", "Rotation  |  " .. Cycle.phase .. " (" .. (night and "malam" or "siang") .. ")")
        end
    end
end)

--═══════════════════════════════════════════════════════════════════════════════
--  MESIN 10 · TASK QUEUE (sek. "Priority")
--  Daftar mesin farm yang sedang aktif — persis panel "Task Queue".
--═══════════════════════════════════════════════════════════════════════════════
Engine.every(3.0, function()
    local active = {}
    local function addIf(name, on)
        if on then table.insert(active, name) end
    end
    addIf("steal", type(Heist) == "table" and Heist.on)
    addIf("mutation", Mutate.on)
    addIf("place", Place.on)
    addIf("hatch", Hatch.on or Hatch.equipBest)
    addIf("sell", Sell.petOn or Sell.eggOn)
    addIf("fuse", Fuse.on)
    addIf("favorite", Fav.on or Fav.equipped or Fav.unfav)
    addIf("treadmill", Tread.on)
    addIf("progress", Progress.buyTrail or Progress.upBase or Progress.upTread
        or Progress.claimCash or Progress.claimIndex)
    addIf("fishing", Angler.on)
    addIf("rotation", Cycle.on)
    setStatus("prioqueue", #active > 0
        and ("Task Queue  |  " .. table.concat(active, ", "))
        or "Task Queue  |  Idle")
end)

--═══════════════════════════════════════════════════════════════════════════════
--  STATISTIK — papan live (Canvas di seksi Sistem & Auto Steal)
--═══════════════════════════════════════════════════════════════════════════════
Engine.every(1.0, function()
    local bagN, placedN, petN = 0, 0, 0
    if Vault.bound then
        for _ in pairs(Vault.bagEggs()) do bagN = bagN + 1 end
        for _ in pairs(Vault.placedEggs()) do placedN = placedN + 1 end
        for _ in pairs(Vault.pets()) do petN = petN + 1 end
    end
    if Board then
        safe(function()
            Board:Set("money",  { Value = "$" .. fmtNum(Vault.money()) })
            Board:Set("speed",  { Value = fmtNum(Vault.speedPower()) })
            Board:Set("bag",    { Value = tostring(bagN) })
            Board:Set("placed", { Value = tostring(placedN) })
            Board:Set("pets",   { Value = tostring(petN) })
            Board:Set("base",   { Value = "Lv " .. tostring(Vault.baseLevel()) })
        end)
    end
    if StealBoard and type(Heist) == "table" then
        safe(function()
            StealBoard:Set("stolen",    { Value = tostring(Heist.stolen) })
            StealBoard:Set("delivered", { Value = tostring(Heist.delivered) })
            StealBoard:Set("carry",     { Value = Heist.carrying and "Membawa telur" or "Kosong" })
            StealBoard:Set("targets",   { Value = (Heist.on or Heist.busy)
                and tostring(#Prey.all()) or "-" })
            StealBoard:Set("queue",     { Value = tostring(#Heist.pick) })
            StealBoard:Set("stealstate",{ Value = Heist.on and Heist.state or "Off" })
            StealBoard:Set("best",      { Value = Heist.best or "-" })
        end)
    end
end)

--═══════════════════════════════════════════════════════════════════════════════
--  AKSI MANUAL (tombol-tombol di tab Farm)
--═══════════════════════════════════════════════════════════════════════════════
local function sellPetsNow()
    task.spawn(function()
        if not needVault() then return end
        local list = buildSellList(Vault.pets(), Sell.petMax, Sell.petValue, Sell.petKeepMut, Sell.petBlack)
        if #list > 0 then
            Net.fire("RE/PetSatchel/SellSelection", list)
            UI.toast("💰 Sell Pets Now", "Menjual " .. #list .. " pet.", 4)
        else
            UI.toast("💰 Sell Pets Now", "Tidak ada pet yang lolos filter.", 4)
        end
    end)
end

local function sellEggsNow()
    task.spawn(function()
        if not needVault() then return end
        local list = buildSellList(Vault.eggs(), Sell.eggMax, Sell.eggValue, Sell.eggKeepMut, Sell.eggBlack)
        if #list > 0 then
            Net.fire("RE/PetSatchel/SellSelection", list)
            UI.toast("💰 Sell Eggs Now", "Menjual " .. #list .. " telur.", 4)
        else
            UI.toast("💰 Sell Eggs Now", "Tidak ada telur yang lolos filter.", 4)
        end
    end)
end

local function favoriteNow(unfavorite)
    task.spawn(function()
        if not needVault() then return end
        local list = {}
        for uid, e in pairs(Vault.pets()) do
            if favMatches(e) then table.insert(list, uid) end
        end
        if #list > 0 then
            Net.fire("RE/PetSatchel/WriteFavourite", list, not unfavorite)
            UI.toast("⭐ Favorite", (unfavorite and "Membatal-favorit " or "Memfavoritkan ") .. #list .. " pet.", 4)
        else
            UI.toast("⭐ Favorite", "Tidak ada pet yang cocok filter.", 4)
        end
    end)
end

local function favoriteEquippedNow(favorite)
    task.spawn(function()
        if not needVault() then return end
        local equipped = Vault.equipped()
        if #equipped > 0 then
            Net.fire("RE/PetSatchel/WriteFavourite", equipped, favorite)
            UI.toast("⭐ Favorite", (favorite and "Memfavoritkan " or "Membatal-favorit ") .. #equipped .. " pet terpakai.", 4)
        else
            UI.toast("⭐ Favorite", "Tidak ada pet yang sedang dipakai.", 4)
        end
    end)
end

local function teleportBase()
    local anchor = Home.anchor()
    local char = LocalPlayer.Character
    if anchor and char then
        safe(function() char:PivotTo(CFrame.new(anchor + Vector3.new(0, 8, 0))) end)
        UI.toast("🏠 Teleport", "Sampai di petak base!", 3)
    else
        UI.toast("🏠 Teleport", "Petak base belum ditemukan.", 4)
    end
end

--// ── Anti AFK ────────────────────────────────────────────────────────────────
local antiAFKConn = nil
local function setAntiAFK(on)
    if antiAFKConn then
        safe(function() antiAFKConn:Disconnect() end)
        antiAFKConn = nil
    end
    if on then
        antiAFKConn = LocalPlayer.Idled:Connect(function()
            safe(function()
                local vu = game:GetService("VirtualUser")
                vu:CaptureController()
                vu:ClickButton2(Vector2.new())
            end)
        end)
    end
end

--═══════════════════════════════════════════════════════════════════════════════
--  BAGIAN 5B · HEIST — mesin AUTO STEAL (tab Farm kode baru)
--  Alur: pilih target (filter + prioritas) -> dekati -> tembak prompt curi
--  (SmartPromptPart "CarryAreaEgg" untuk telur area; "StealPrompt" untuk
--  telur base pemain lain; fallback modul game EggState.CarryFieldEgg)
--  -> antar pulang sesuai Delivery (Tween / Instant Steps / Fast Tween)
--  -> server redeem di base, diverifikasi lewat RE/FieldEggRedeemVerdict.
--═══════════════════════════════════════════════════════════════════════════════
Heist = {
    on = false,
    delivery = "Tween",           -- Tween | Instant Steps | Fast Tween
    speedPct = 100,               -- Delivery Speed 80-110% (mode Tween)
    steps = 3,                    -- Step Count 1-6 (mode Instant Steps)
    fastSpeed = 3300,             -- Fast Tween Speed 3000-4500 studs/dtk
    priority = "Highest Value",   -- Highest Value | Best Rarity | Biggest Weight | Best Mutation | Lowest Value
    minRarity = "Any", minValue = 0,
    areas = {}, specific = {},
    missingIndex = false, dropSafe = false, agPanel = true,
    busy = false, busyAt = nil, carrying = false, carriedUid = nil, seenAt = 0,
    bad = {}, blocked = {},
    pick = {}, lock = nil,   -- v5.1: antrean curi dari Steal Panel (★ / klik)
    stolen = 0, delivered = 0, best = nil, bestRank = -1,
    lastVerdict = 0,
    state = "Idle",
}

--// jarak horizontal (X-Z saja; tinggi diabaikan supaya tidak salah pilih lantai)
local function horizDist(a, b)
    local dx = (a.X or 0) - (b.X or 0)
    local dz = (a.Z or 0) - (b.Z or 0)
    return math.sqrt(dx * dx + dz * dz)
end

--// tembak ProximityPrompt instan (HoldDuration = 0)
local function firePrompt(prompt)
    if not prompt or not prompt.Parent then return false end
    safe(function() prompt.HoldDuration = 0 end)
    if fireproximityprompt then
        safe(fireproximityprompt, prompt)
    else
        safe(function()
            prompt:InputHoldBegin()
            prompt:InputHoldEnd()
        end)
    end
    return true
end

--// modul EggState game: fallback curi/lepas lewat modul asli game
local eggStateMod, eggStateTried = nil, false
local function EggStateModule()
    if eggStateMod or eggStateTried then return eggStateMod end
    eggStateTried = true
    for _, root in ipairs({
        ReplicatedStorage:FindFirstChild("Packages"),
        ReplicatedStorage:FindFirstChild("Shared"),
        ReplicatedStorage,
    }) do
        if root then
            local kids = safe(function() return root:GetDescendants() end)
            if type(kids) == "table" then
                for _, inst in ipairs(kids) do
                    local isMod = safe(function()
                        return inst:IsA("ModuleScript") and inst.Name == "EggState"
                    end)
                    if isMod then
                        local mod = safe(require, inst)
                        if type(mod) == "table" and type(mod.CarryFieldEgg) == "function" then
                            eggStateMod = mod
                            return eggStateMod
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- fallback curi via modul game; telur starter membawa akhiran _<Area>:Slot_N
local function carryViaModule(uid)
    local m = EggStateModule()
    if m and type(uid) == "string" and uid ~= "" then
        local slot = string.match(uid, "_([%w ]+:Slot_%d+)$")
        safe(m.CarryFieldEgg, uid, slot)
        return true
    end
    return false
end

local function dropViaModule()
    local m = EggStateModule()
    if m and type(m.DropFieldEgg) == "function" then
        safe(m.DropFieldEgg, "PlayerRequest")
        return true
    end
    return false
end

--// deteksi "sedang membawa telur": record snapshot (server bilang kita
-- pembawanya) -> model telur weld ke karakter -> Tool di tangan.
-- v5.1 diperluas: model weld tidak lagi harus bernama GUID-32 (telur hasil
-- curi base pemain lain bisa bernama lain tapi punya Hitbox); Tool apa pun
-- di tangan dihitung membawa (uid = atribut Uid / nama tool).
local function detectCarryNow()
    local char = LocalPlayer.Character
    if not char then return nil end
    local snapT = Prey.snapshot(1.2)
    if type(snapT) == "table" and type(snapT.Records) == "table" then
        local myId = LocalPlayer.UserId
        for _, rec in pairs(snapT.Records) do
            if type(rec) == "table" and rec.State == "Carried"
                and tonumber(rec.CarrierUserId) == myId then
                return tostring(rec.Uid or "")
            end
        end
    end
    for _, m in ipairs(workspace:GetChildren()) do
        local isEgg = safe(function()
            if not m:IsA("Model") then return false end
            if #m.Name == 32 then return true end
            return m:FindFirstChild("Hitbox") ~= nil
        end)
        if isEgg then
            local welded = safe(function()
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
            if welded then
                local au = safe(function() return m:GetAttribute("Uid") end)
                if type(au) == "string" and #au >= 4 then return au end
                return tostring(m.Name)
            end
        end
    end
    for _, t in ipairs(char:GetChildren()) do
        if safe(function() return t:IsA("Tool") end) then
            local nm = tostring(t.Name)
            local au = safe(function() return t:GetAttribute("Uid") end)
            if type(au) == "string" and #au >= 8 then return au end
            if #nm == 32 then return nm end
            -- v5.1: tool apa pun di tangan saat mencuri = dianggap membawa
            return nm
        end
    end
    -- atribut dimensi event (bila sedang berjalan)
    if safe(function() return workspace:GetAttribute("HalloweenCarrying") end) == true then
        return "halloween"
    end
    return nil
end

--// verdict: server mengonfirmasi telur sampai & ditukar jadi uang
task.spawn(function()
    local verdict = nil
    for _ = 1, 10 do
        verdict = Net.get("RE/EggWorld/FieldEggRedeemVerdict")
        if verdict then break end
        task.wait(3)
    end
    if verdict then
        safe(function()
            verdict.OnClientEvent:Connect(function()
                Heist.lastVerdict = os.clock()
                Heist.delivered = Heist.delivered + 1
            end)
        end)
    end
end)

--// watchdog bawa-telur: cache dengan histeresis 0.8 dtk (anti flicker)
Engine.every(0.2, function()
    if not (Heist.on or Heist.busy or Heist.carrying) then return end
    local uid = detectCarryNow()
    if uid then
        Heist.carrying = true
        Heist.carriedUid = uid
        Heist.seenAt = os.clock()
    elseif Heist.carrying then
        if (os.clock() - Heist.seenAt) > 0.8 then
            Heist.carrying = false
            Heist.carriedUid = nil
        end
    end
end)

--// scan guard ter-cache (mahal — hanya di-refresh selama Auto Steal aktif)
local guardCache, guardAt = nil, 0
local function guardSnapshot()
    if not (Heist.on or Heist.busy) then return nil end
    local now = os.clock()
    if type(guardCache) ~= "table" or (now - guardAt) > 4 then
        guardCache = safe(function() return workspace:GetDescendants() end)
        guardAt = now
    end
    return guardCache
end

-- info guard aktif terdekat dari posisi (radius stud): {state, dist} | nil
-- v5.1: mengembalikan jarak & state (dipakai chip anti-guard: jumlah & jarak)
local function guardInfo(pos, radius)
    local list = guardSnapshot()
    if type(list) ~= "table" or not pos then return nil end
    local best = nil
    for _, inst in ipairs(list) do
        local gs = safe(function() return inst:GetAttribute("GuardState") end)
        if type(gs) == "string" and gs ~= "Sleeping" then
            local gp = safe(function()
                if inst:IsA("BasePart") then return inst.Position end
                if inst:IsA("Model") then return inst:GetPivot().Position end
            end)
            if gp then
                local d = (gp - pos).Magnitude
                if d < (radius or 35) then
                    if not best or d < best.dist then
                        best = { state = gs, dist = d }
                    end
                end
            end
        end
    end
    return best
end

-- guard berjaga dekat posisi (radius 35 stud) sedang aktif?
local function guardAwakeNear(pos)
    return guardInfo(pos, 35)
end

-- tunggu guard tidur (maks 3 dtk): menyerobot guard aktif = pasti ragdoll
local function waitGuardSleep(pos)
    if not pos then return end
    local t0 = os.clock()
    while (os.clock() - t0) < 3 do
        if not guardAwakeNear(pos) then return end
        Heist.state = "Menunggu guard tidur..."
        task.wait(0.25)
    end
end

--// prompt curi telur AREA: part global "SmartPromptPart" (anak workspace)
-- berisi ProximityPrompt "CarryAreaEgg". Pilih yang terdekat ke TELUR
-- (batas 14 stud, jarak HORIZONTAL); tolak bila prompt itu lebih dekat ke
-- slot telur lain / telur yang sedang dibawa orang (margin 1.5 stud).
local function nearestCarryPrompt(egg)
    local pos = egg.pos
    if not pos then return nil end
    local bestPrompt, bestPart, bestD = nil, nil, 14
    for _, m in ipairs(workspace:GetChildren()) do
        if m.Name == "SmartPromptPart" then
            if safe(function() return m:IsA("BasePart") end) then
                local pr = safe(function() return m:FindFirstChild("CarryAreaEgg") end)
                if pr and safe(function() return pr:IsA("ProximityPrompt") end) then
                    local mp = safe(function() return m.Position end)
                    if mp then
                        local d = horizDist(mp, pos)
                        if d < bestD then
                            bestPrompt, bestPart, bestD = pr, m, d
                        end
                    end
                end
            end
        end
    end
    if not bestPrompt or not bestPart then return nil end
    local pp = safe(function() return bestPart.Position end)
    if not pp then return nil end
    local myD = horizDist(pp, pos)
    local slots = workspace:FindFirstChild("AreaEggSlotsClient")
    if slots then
        local kids = safe(function() return slots:GetChildren() end) or {}
        for _, t in ipairs(kids) do
            local tp = safe(function()
                if t:IsA("Model") then return t:GetPivot().Position end
            end)
            if tp and horizDist(tp, pp) + 1.5 < myD then
                return nil -- prompt itu melayani telur sebelah
            end
        end
    end
    for _, m in ipairs(workspace:GetChildren()) do
        if safe(function() return m:IsA("Model") and #m.Name == 32 end)
            and safe(function() return m:FindFirstChild("Hitbox") end) then
            local mp = safe(function() return m:GetPivot().Position end)
            if mp and horizDist(mp, pp) + 1.5 < myD then
                return nil
            end
        end
    end
    return bestPrompt
end

--// filter & skor target
local function areaOk(egg)
    if next(Heist.areas) == nil then return true end
    if egg.kind == "Base" then return true end -- telur base pemain lain selalu dikejar
    local area = tostring(egg.area or "")
    if area ~= "" and Heist.areas[area] then return true end
    -- cocokkan lewat posisi (bounding box folder Areas)
    local areas = safe(function()
        local w = workspace:FindFirstChild("World")
        return w and w:FindFirstChild("Areas")
    end)
    if areas and egg.pos then
        for name in pairs(Heist.areas) do
            local a = safe(function() return areas:FindFirstChild(name) end)
            if a then
                local ok, cf, size = pcall(function()
                    local c, s = a:GetBoundingBox()
                    return c, s
                end)
                if ok and cf and size then
                    local rel = cf:PointToObjectSpace(egg.pos)
                    if math.abs(rel.X) <= size.X / 2 and math.abs(rel.Z) <= size.Z / 2 then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function specificOk(egg)
    if next(Heist.specific) == nil then return true end
    if Heist.specific[egg.category] then return true end
    if Heist.specific[egg.name] then return true end
    return false
end

-- spesies yang belum pernah dimiliki (Index miss) — dari replika save
local ownedCache, ownedAt = nil, 0
local function ownedSpecies()
    local now = os.clock()
    if ownedCache and (now - ownedAt) < 5 then return ownedCache end
    ownedAt = now
    local set = {}
    local save = Vault.raw()
    if type(save) == "table" then
        if type(save.EggInventory) == "table" then
            for _, e in pairs(save.EggInventory) do
                if type(e) == "table" then
                    set[tostring(e.AssetCategory or e.Category or "")] = true
                end
            end
        end
        if type(save.Inventory) == "table" then
            for _, e in pairs(save.Inventory) do
                if type(e) == "table" then set[tostring(e.Category or "")] = true end
            end
        end
        if type(save.Index) == "table" then
            for sp in pairs(save.Index) do set[tostring(sp)] = true end
        end
    end
    ownedCache = set
    return set
end

local function indexMissing(egg)
    if not Atlas.dir then return false end -- katalog belum siap: jangan filter
    local sp = tostring(egg.category or egg.name or "")
    if sp == "" then return false end
    if not Atlas.spec(sp) then return false end -- bukan spesies katalog
    local owned = ownedSpecies()
    return owned[sp] ~= true
end

local function filterOk(egg)
    if not areaOk(egg) then return false end
    if not specificOk(egg) then return false end
    if Heist.minRarity ~= "Any" and egg.rarityNum < rarNum(Heist.minRarity) then return false end
    if Heist.minValue > 0 and egg.value < Heist.minValue then return false end
    if Heist.missingIndex and not indexMissing(egg) then return false end
    return true
end

local function scoreOf(egg)
    local p = Heist.priority
    if p == "Best Rarity" then return egg.rarityNum * 1e12 + egg.value end
    if p == "Biggest Weight" then return egg.scale * 1e12 + egg.value end
    if p == "Best Mutation" then return #egg.mutations * 1e12 + egg.value end
    if p == "Lowest Value" then return -egg.value end
    return egg.value -- Highest Value (default)
end

local function pickTarget()
    local now = os.clock()
    local targets = Prey.all()
    -- v5.1: ANTREAN PANEL MENANG TANPA FILTER (pola kode asli): pilihan
    -- eksplisit (klik kartu / ★) tidak dicegat Min Rarity/Value/dll.;
    -- key basi otomatis dibuang dari antrean. Urutan: pick -> lock.
    if Heist.lock or next(Heist.pick) then
        local byKey = {}
        for _, e in ipairs(targets) do byKey[e.key] = e end
        local queue = {}
        for _, k in ipairs(Heist.pick) do queue[#queue + 1] = k end
        if Heist.lock then queue[#queue + 1] = Heist.lock end
        for _, k in ipairs(queue) do
            local e = byKey[k]
            if e and e.pos
                and (Heist.bad[e.key] or 0) <= now
                and (Heist.blocked[tostring(e.uid)] or 0) <= now then
                return e
            end
            -- key antrean tidak valid lagi -> buang
            local idx = table.find(Heist.pick, k)
            if idx then table.remove(Heist.pick, idx) end
            if Heist.lock == k then Heist.lock = nil end
        end
    end
    -- v5.1: AUTO hanya telur AREA (pola kode asli) — telur base pemain lain
    -- hanya bisa dicuri MANUAL lewat klik kartu di Steal Panel.
    local best, bestScore = nil, -math.huge
    for _, egg in ipairs(targets) do
        if egg.kind == "Base" then
            -- dilewati auto (manual saja via panel)
        elseif (Heist.bad[egg.key] or 0) > now then
            -- masih di-blacklist sementara
        elseif (Heist.blocked[tostring(egg.uid)] or 0) > now then
            -- pernah direbut guard barusan
        elseif not egg.pos then
            -- posisi tidak diketahui
        elseif not filterOk(egg) then
            -- tercegat filter
        else
            local s = scoreOf(egg)
            if s > bestScore then
                best, bestScore = egg, s
            end
        end
    end
    return best
end

--// record snapshot per uid (status real-time saat grab)
local function fieldRecord(uid)
    local snapT = Prey.snapshot(1.5)
    if type(snapT) ~= "table" or type(snapT.Records) ~= "table" then return nil end
    for _, rec in pairs(snapT.Records) do
        if type(rec) == "table" and tostring(rec.Uid or "") == uid then
            return rec
        end
    end
    return nil
end

-- panjang langkah pendekatan sesuai mode delivery
local function approachStep()
    if Heist.delivery == "Fast Tween" then return math.huge end
    if Heist.delivery == "Instant Steps" then return 60 end
    return Heist.speedPct / 100 * 40
end

--// alur curi telur AREA (prompt TIDAK menempel di telur).
-- Jendela grab 1.5 dtk per ronde, tembak prompt tiap 0.06 dtk;
-- prompt tidak ketemu -> fallback modul EggState.CarryFieldEgg;
-- 4 miss berturut-turut = ronde gagal.
local function grabFieldEgg(egg)
    local step = approachStep()
    for _ = 1, 4 do
        if Heist.carrying then return "ok" end
        if not Ride.waitCalm(1.5) then return "fail" end
        local rec = fieldRecord(egg.uid)
        local m = egg.model
        local alive = (m and safe(function() return m.Parent ~= nil end)) == true
        if rec then
            if rec.State == "Claimed" then return "taken" end
            if rec.State == "Carried" then
                if tonumber(rec.CarrierUserId) == LocalPlayer.UserId then
                    return "ok"
                end
                return "taken"
            end
            if typeof(rec.BottomCFrame) == "CFrame" then
                egg.pos = rec.BottomCFrame.Position
            end
        elseif not alive then
            return "gone"
        end
        if m and alive and Prey.weldCarrier(m) ~= nil then return "taken" end
        local pos = egg.pos
        if m and alive and not pos then pos = Prey.modelPos(m) end
        if not pos then return "gone" end

        local tEnd = os.clock() + 1.5
        local nextFire, misses = 0, 0
        while os.clock() < tEnd and not Heist.carrying do
            local root = Ride.root()
            if not root then return "fail" end
            if Ride.ragged() then break end
            local live = (m and alive and Prey.modelPos(m)) or pos
            local d = (live - root.Position).Magnitude
            if d > 6 then
                Ride.step(live + Vector3.new(0, 2.5, 0), step)
            elseif os.clock() >= nextFire then
                nextFire = os.clock() + 0.06
                local prompt = nearestCarryPrompt(egg)
                if prompt then
                    firePrompt(prompt)
                    misses = 0
                else
                    misses = misses + 1
                    if misses >= 4 then break end
                    carryViaModule(egg.uid)
                end
            end
            task.wait()
        end
        if Heist.carrying then return "ok" end
        task.wait(0.15)
    end
    if Heist.carrying then return "ok" end
    local m = egg.model
    if m and not safe(function() return m.Parent ~= nil end) then return "gone" end
    return "fail"
end

--// alur curi telur BER-PROMPT (telur base pemain lain)
local function grabPromptEgg(egg)
    local model, prompt = egg.model, egg.prompt
    local step = approachStep()
    for _ = 1, 3 do
        if Heist.carrying then return "ok" end
        if not Ride.waitCalm(1.5) then return "fail" end
        if not model.Parent or not prompt or not prompt.Parent then
            return (model.Parent and "fail") or "gone"
        end
        local carrier = Prey.weldCarrier(model)
        if carrier and carrier ~= LocalPlayer.Character then return "taken" end
        local deadline = os.clock() + 3
        while os.clock() < deadline do
            if Heist.carrying then return "ok" end
            local root = Ride.root()
            if not root then break end
            if not model.Parent then break end
            if Ride.ragged() then break end
            local pos = Prey.modelPos(model)
            if not pos then break end
            local d = (pos - root.Position).Magnitude
            if d < 5 then
                firePrompt(prompt)
                if Heist.carrying or not model.Parent then break end
                task.wait(0.06)
            else
                Ride.step(pos + Vector3.new(0, 3, 0), step)
            end
            task.wait()
        end
        -- dorongan terakhir: spam prompt 1.2 dtk
        local tEnd = os.clock() + 1.2
        while os.clock() < tEnd and not Heist.carrying and model.Parent do
            firePrompt(prompt)
            task.wait(0.12)
        end
        if Heist.carrying then return "ok" end
        task.wait(0.2)
    end
    if Heist.carrying then return "ok" end
    if not model.Parent then return "gone" end
    return "fail"
end

--// entri telur "nyasar" ke tangan (dari record snapshot) — Wrong Egg
local function heldEntry(uid)
    local snapT = Prey.snapshot(0.8)
    if type(snapT) ~= "table" or type(snapT.Records) ~= "table" then return nil end
    for _, rec in pairs(snapT.Records) do
        if type(rec) == "table" and tostring(rec.Uid or "") == uid then
            local cat = tostring(rec.AssetCategory or rec.Category or "")
            local name = cat
            local spec = Atlas.spec(cat)
            if type(spec) == "table" then
                local dn = spec.DisplayName or spec._id
                if dn and tostring(dn) ~= "" then name = tostring(dn) end
            end
            local muts = (type(rec.Mutations) == "table") and rec.Mutations or {}
            local scale = tonumber(rec.AssetScale) or 1
            local label, num = Atlas.rarity(cat)
            return {
                uid = uid, key = "F:" .. uid, kind = "Field",
                model = nil, prompt = nil,
                name = (name == "" and uid or name), category = cat,
                rarityLabel = label, rarityNum = num,
                scale = scale, mutations = muts,
                value = Atlas.value(cat, scale, muts),
                pos = nil, area = tostring(rec.AreaId or ""),
            }
        end
    end
    return nil
end

--// lepas telur dari tangan (salah telur)
local function dropCarried()
    dropViaModule()
    local hum = Ride.humanoid()
    if hum then safe(function() hum:UnequipTools() end) end
    local tEnd = os.clock() + 1
    while Heist.carrying and os.clock() < tEnd do
        task.wait()
    end
end

--// catat sukses curi (dipakai semua jalur)
local function recordSuccess(egg)
    Heist.stolen = Heist.stolen + 1
    if egg.rarityNum >= Heist.bestRank then
        Heist.bestRank = egg.rarityNum
        Heist.best = tostring(egg.name) .. " [" .. tostring(egg.rarityLabel) .. "]"
    end
    UI.toast("🥷 Telur dicuri!", tostring(egg.name) .. " [" .. tostring(egg.rarityLabel) .. "]", 4)
end

--// zona aman untuk melepas telur
local function safeZonePart()
    return safe(function()
        local w = workspace:FindFirstChild("World")
        local f = w and w:FindFirstChild("SafeZone", true)
        if f and f:IsA("BasePart") then return f end
        return workspace:FindFirstChild("SafeZone", true)
    end)
end

--// titik antar: Safe Zone (bila dipilih) atau jangkar base
local function homeTarget()
    if Heist.dropSafe then
        local sz = safeZonePart()
        if sz and sz:IsA("BasePart") then
            local root = Ride.root()
            if root then
                local rel = sz.CFrame:PointToObjectSpace(root.Position)
                local mx = math.max(sz.Size.X / 2 - 6, 0)
                local mz = math.max(sz.Size.Z / 2 - 6, 0)
                return sz.CFrame:PointToWorldSpace(Vector3.new(
                    math.clamp(rel.X, -mx, mx), 0, math.clamp(rel.Z, -mz, mz))), sz
            end
            return sz.Position, sz
        end
    end
    local anchor = Home.anchor()
    if anchor then return anchor, nil end
    return nil, nil
end

--// antar telur pulang sesuai mode Delivery
local function deliverEgg(egg)
    Ride.leaveBelt()

    -- telur dimensi event: antar ke Safe Zone lalu minta drop via remote
    if tostring(Heist.carriedUid or "") == "halloween"
        or safe(function() return workspace:GetAttribute("HalloweenCarrying") end) == true then
        local sz = safeZonePart()
        if sz then
            Heist.state = "Membawa telur event ke Safe Zone"
            local root = Ride.root()
            if root then
                local rel = sz.CFrame:PointToObjectSpace(root.Position)
                local mx = math.max(sz.Size.X / 2 - 6, 0)
                local mz = math.max(sz.Size.Z / 2 - 6, 0)
                local goal = sz.CFrame:PointToWorldSpace(Vector3.new(
                    math.clamp(rel.X, -mx, mx), 0, math.clamp(rel.Z, -mz, mz)))
                Ride.carry(goal, function() return not Heist.carrying end, 30,
                    Ride.walkSpeed() * 1.5)
            end
            Net.invoke("RF/HalloweenDimension/AskDropEgg")
            task.wait(0.6)
        end
        return
    end

    local target, targetPart = homeTarget()
    if not target then
        Heist.state = "Jangkar base tidak ketemu — menunggu"
        task.wait(1.5)
        return
    end

    local mode = Heist.delivery
    Heist.state = "Membawa telur pulang (" .. mode .. ")"
    local stop = function() return not Heist.carrying end

    if mode == "Fast Tween" then
        Ride.carry(target, stop, 12, Heist.fastSpeed)
    elseif mode == "Instant Steps" then
        local root = Ride.root()
        local from = (root and root.Position) or target
        local n = math.clamp(math.floor(tonumber(Heist.steps) or 3), 1, 6)
        for i = 1, n - 1 do
            if not Heist.carrying then return end
            Ride.fly(from:Lerp(target, i / n), stop, 350)
            task.wait(0.45)
        end
        Ride.fly(target, stop, 350)
    else -- Tween
        Ride.carry(target, stop, 45, Ride.walkSpeed() * 1.5 * (Heist.speedPct / 100))
    end

    -- konfirmasi utama: verdict server (RE/FieldEggRedeemVerdict)
    local mark = Heist.lastVerdict
    local tEnd = os.clock() + 8
    while Heist.carrying and os.clock() < tEnd and Heist.lastVerdict <= mark do
        task.wait(0.1)
    end
    if Heist.carrying and Heist.lastVerdict <= mark then
        -- mungkin belum masuk zona redeem: lepas tool di dekat target
        local hum = Ride.humanoid()
        if hum then safe(function() hum:UnequipTools() end) end
        local t2 = os.clock() + 1.5
        while Heist.carrying and os.clock() < t2 do
            task.wait(0.1)
        end
    end
    if Heist.lastVerdict > mark then
        Heist.state = "Telur tersampaikan ✓"
    elseif not Heist.carrying then
        local root = Ride.root()
        local tp = targetPart and safe(function() return targetPart.Position end) or target
        local near = root and tp and (root.Position - tp).Magnitude < 40
        if near then
            Heist.state = "Telur tersampaikan ✓"
        else
            -- telur lepas jauh dari rumah: direbut guard di tengah jalan
            Heist.state = "Telur direbut guard — skip 60 dtk"
            Heist.blocked[tostring(egg.uid or egg.key)] = os.clock() + 60
        end
    else
        Heist.state = "Antaran macet — telur belum masuk zona redeem"
    end
end

--// alur curi satu telur (target -> grab -> wrong-egg check -> antar)
local function stealOne(egg)
    Ride.leaveBelt()
    waitGuardSleep(egg.pos)

    local res
    if egg.kind == "Field" and not egg.prompt then
        Heist.state = "Terbang ke telur  |  " .. tostring(egg.name)
        res = grabFieldEgg(egg)
    else
        Heist.state = "Menuju telur  |  " .. tostring(egg.name)
        res = grabPromptEgg(egg)
    end

    if res == "ok" and Heist.carrying then
        if egg.kind == "Base" then
            -- v5.1: telur base diambil lewat StealPrompt SPESIFIK — uid di
            -- tangan memang berbeda dari uid render (bukan salah telur);
            -- langsung antar tanpa wrong-egg check (dulu malah dijatuhkan!)
            recordSuccess(egg)
            deliverEgg(egg)
        else
            -- cek Wrong Egg (hanya telur AREA: prompt bisa menyambar telur
            -- sebelah — telur lain nyasar ke tangan)
            local heldUid = tostring(Heist.carriedUid or "")
            local wantUid = tostring(egg.uid or "")
            local wrong = heldUid ~= "" and wantUid ~= ""
                and heldUid ~= wantUid and heldUid ~= "halloween"
            if wrong then
                local alt = heldEntry(heldUid)
                if alt and filterOk(alt) then
                    -- telur lain tapi masih lolos filter: tetap diantar
                    Heist.state = "Telur lain yang cocok di tangan — tetap diantar"
                    recordSuccess(alt)
                    deliverEgg(alt)
                else
                    Heist.state = "Salah telur di tangan — dilepas"
                    dropCarried()
                    Heist.bad[egg.key] = os.clock() + 4
                end
            else
                recordSuccess(egg)
                deliverEgg(egg)
            end
        end
    elseif res == "gone" or res == "taken" then
        Heist.bad[egg.key] = os.clock() + 8
        Heist.state = "Target diambil orang lain — pilih target lain"
    else
        Heist.bad[egg.key] = os.clock() + 20
        Heist.state = "Telur tidak sampai ke tangan — pindah target"
    end
end

--// dispatcher: antar yang sedang dibawa ATAU cari target baru.
-- v5.1 ANTI-MACET: tugas dibungkus pcall (error runtime tidak lagi
-- membuat Heist.busy nyangkut = mesin mati total) + watchdog memaksa
-- reset bila satu tugas menggantung lebih dari 150 dtk.
local function dispatchSteal(fn)
    Heist.busy = true
    Heist.busyAt = os.clock()
    task.spawn(function()
        local ok, err = pcall(fn)
        if not ok then
            Heist.state = "Error internal (dilanjutkan): " .. tostring(err)
            print("[ThorHub][Steal] " .. tostring(err))
        end
        Heist.busy = false
        Heist.busyAt = nil
    end)
end

Engine.every(5, function()
    if Heist.busy and Heist.busyAt
        and (os.clock() - Heist.busyAt) > 150 then
        Heist.busy = false
        Heist.busyAt = nil
        Heist.state = "Reset otomatis — tugas sebelumnya menggantung"
        print("[ThorHub][Steal] watchdog: reset task yang menggantung")
    end
end)

Engine.every(0.4, function()
    if not Heist.on then return end
    if Heist.busy then return end
    if Heist.carrying then
        dispatchSteal(function()
            deliverEgg({ name = "?", uid = Heist.carriedUid,
                key = "F:" .. tostring(Heist.carriedUid) })
        end)
        return
    end
    local target = pickTarget()
    if target then
        dispatchSteal(function() stealOne(target) end)
    else
        local total = #Prey.all()
        if total == 0 then
            Heist.state = "Idle  |  belum ada telur terlihat"
        else
            Heist.state = "Idle  |  " .. total .. " telur terlihat, semua tercegat filter"
        end
    end
end)

--// aksi manual: curi satu kali sekarang (dipakai tombol UI & Steal Panel)
function Heist.stealOnce()
    if Heist.busy then
        UI.toast("🥷 Auto Steal", "Mesin masih sibuk — tunggu sebentar.", 3)
        return
    end
    if Heist.carrying then
        UI.toast("🥷 Auto Steal", "Kamu sedang membawa telur — diantar dulu.", 3)
        dispatchSteal(function()
            deliverEgg({ name = "?", uid = Heist.carriedUid })
        end)
        return
    end
    local target = pickTarget()
    if not target then
        UI.toast("🥷 Auto Steal", "Tidak ada target yang lolos filter.", 4)
        return
    end
    dispatchSteal(function() stealOne(target) end)
end

--// chip anti-guard kanan-bawah (status guard sekitar) saat Auto Steal aktif.
-- v5.1: teks kini BERGANTI WARNA (merah = guard aktif dekat, hijau = aman)
-- + menampilkan jarak & state guard aktif terdekat (pola kode asli:
-- "GUARD | nearby - careful" merah / "GUARD | clear" hijau).
-- bersihkan chip sesi lama bila script di-execute ulang
local GuardHud = { gui = nil }
do
    local scopes = {}
    if type(gethui) == "function" then
        local h = safe(gethui)
        if h then table.insert(scopes, h) end
    end
    local pg = safe(function() return LocalPlayer:FindFirstChild("PlayerGui") end)
    if pg then table.insert(scopes, pg) end
    for _, scope in ipairs(scopes) do
        local kids = safe(function() return scope:GetChildren() end) or {}
        for _, d in ipairs(kids) do
            if tostring(d.Name) == "ThorHubGuardPanel" then
                safe(function() d:Destroy() end)
            end
        end
    end
end
Engine.every(0.5, function()
    local want = Heist.on and Heist.agPanel
    if not want then
        if GuardHud.gui then
            safe(function() GuardHud.gui:Destroy() end)
            GuardHud.gui = nil
        end
        return
    end
    if not GuardHud.gui then
        safe(function()
            local gui = Instance.new("ScreenGui")
            gui.Name = "ThorHubGuardPanel"
            gui.ResetOnSpawn = false
            gui.DisplayOrder = 70
            local chip = Instance.new("Frame")
            chip.AnchorPoint = Vector2.new(1, 1)
            chip.Position = UDim2.new(1, -10, 1, -10)
            chip.Size = UDim2.new(0, 210, 0, 30)
            chip.BackgroundColor3 = Color3.fromRGB(24, 28, 42)
            chip.BackgroundTransparency = 0.2
            chip.BorderSizePixel = 0
            local lbl = Instance.new("TextLabel")
            lbl.BackgroundTransparency = 1
            lbl.Size = UDim2.new(1, -10, 1, 0)
            lbl.Position = UDim2.new(0, 10, 0, 0)
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 12
            lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Text = "GUARD  |  checking"
            lbl.Name = "Lbl"
            lbl.Parent = chip
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = chip
            chip.Parent = gui
            gui.Parent = (type(gethui) == "function" and gethui())
                or LocalPlayer:FindFirstChild("PlayerGui")
            GuardHud.gui = gui
        end)
        if not GuardHud.gui then return end
    end
    safe(function()
        local chip = GuardHud.gui:FindFirstChild("Frame")
        local lbl = chip and chip:FindFirstChild("Lbl")
        if not lbl then return end
        local root = Ride.root()
        local stateTxt, col
        if not root then
            stateTxt = "GUARD  |  karakter belum siap"
            col = Color3.fromRGB(230, 230, 240)
        else
            local info = guardInfo(root.Position, 120)
            if info then
                stateTxt = "GUARD  |  AKTIF! " .. math.floor(info.dist + 0.5) .. "m"
                    .. "  (" .. tostring(info.state) .. ")"
                col = Color3.fromRGB(255, 92, 100)      -- merah: bahaya
            elseif Heist.busy then
                stateTxt = "GUARD  |  aman — sedang mengantar"
                col = Color3.fromRGB(120, 255, 160)    -- hijau
            else
                stateTxt = "GUARD  |  aman"
                col = Color3.fromRGB(120, 255, 160)    -- hijau
            end
        end
        lbl.Text = stateTxt
        lbl.TextColor3 = col
    end)
end)

--═══════════════════════════════════════════════════════════════════════════════
--  BAGIAN 5C · STEAL PANEL — panel curi ala kode asli (hijack HUD game)
--  Dipetakan dari modul HUD kode baru Steal an Egg:
--    * tombol toggle = KLONING tombol Pets game, menempel di kolom tombol
--      kanan (RightButtons), mengikuti posisi tombol Eggs tiap frame
--    * panel = KLONING frame ActivePets game, slide dari kanan, judul
--      diganti "Steal Panel"
--    * header panel: tombol "Sort: <prioritas>" (siklus 5 mode, sync
--      elemen menu Farm > Auto Steal > Steal Priority) + tombol tutup ">"
--    * baris tombol: Steal (sync toggle Auto Steal) · filter
--      All/Halloween/Field (tombol HW kode asli = fitur tab Admin, di luar
--      lingkup rewrite tab Farm — tidak disertakan)
--    * kartu telur: rank #N, blok warna rarity, nama (+@pemilik utk telur
--      base), $value/s, detail (rarity · area · mutasi · jarak), ★ antre
--      prioritas, ▲▼ urut, X batal; KLIK KARTU = curi sekarang
--    * daftar = antrean pilihan (Heist.pick) + maks 8 saran target teratas
--      yang lolos filter
--    * nama instance GUI dirandom + ingat status terbuka
--  Fallback: bila HUD game tak ditemukan -> panel mandiri layout sama.
--═══════════════════════════════════════════════════════════════════════════════

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

--// ─── tema gradien (nilai identik kode asli) ────────────────────────────────
local function spSeq(points)
    local kp = {}
    for _, p in ipairs(points) do
        kp[#kp + 1] = ColorSequenceKeypoint.new(p[1], p[2])
    end
    return ColorSequence.new(kp)
end

local SP_Theme = {
    Toggle = {
        Color = spSeq({
            { 0, Color3.fromRGB(132, 74, 255) }, { 0.34, Color3.fromRGB(178, 74, 255) },
            { 0.6, Color3.fromRGB(255, 104, 206) }, { 0.78, Color3.fromRGB(255, 168, 232) },
            { 1, Color3.fromRGB(146, 66, 255) },
        }),
        Rotation = -115, Stroke = Color3.fromRGB(44, 10, 80),
    },
}

local SP_BG     = Color3.fromRGB(11, 14, 23)
local SP_CARD   = Color3.fromRGB(21, 26, 41)
local SP_STROKE = Color3.fromRGB(45, 58, 88)
local SP_TEXT   = Color3.fromRGB(240, 244, 255)
local SP_DIM    = Color3.fromRGB(145, 155, 180)
local SP_GREEN  = Color3.fromRGB(88, 255, 120)
local SP_RED    = Color3.fromRGB(255, 92, 100)
local SP_GOLD   = Color3.fromRGB(255, 200, 60)

--// ─── util GUI ──────────────────────────────────────────────────────────────
local function spNew(class, props, parent)
    local inst = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            safe(function() inst[k] = v end)
        end
    end
    if parent then safe(function() inst.Parent = parent end) end
    return inst
end

local function spRandName()
    local ok, guid = pcall(function()
        return HttpService:GenerateGUID(false):gsub('-', ''):sub(1, 14)
    end)
    if ok and guid then return guid end
    return tostring(math.random(1000000, 9999999))
end

local function spRename(inst)
    safe(function()
        inst.Name = spRandName()
        for _, d in ipairs(inst:GetDescendants()) do d.Name = spRandName() end
    end)
end

-- klik suara (pola UiClick kode asli: pop acak)
local function spClick()
    safe(function()
        local snd = Instance.new("Sound")
        snd.SoundId = "rbxassetid://100671636189844"
        snd.Volume = 1.5
        snd.PlaybackSpeed = 0.93 + math.random() * 0.13
        snd.Parent = workspace
        snd:Play()
        game:GetService("Debris"):AddItem(snd, 3)
    end)
end

local function spRarityColor(num)
    num = tonumber(num) or 0
    local map = {
        [1] = Color3.fromRGB(196, 200, 210), [2] = Color3.fromRGB(94, 219, 132),
        [3] = Color3.fromRGB(86, 156, 255), [4] = Color3.fromRGB(178, 102, 255),
        [5] = Color3.fromRGB(255, 173, 51), [6] = Color3.fromRGB(255, 84, 112),
        [7] = Color3.fromRGB(88, 116, 255), [8] = Color3.fromRGB(255, 214, 64),
        [9] = Color3.fromRGB(120, 240, 220), [10] = Color3.fromRGB(255, 240, 130),
    }
    return map[num] or Color3.fromRGB(255, 255, 255)
end

-- nama pemilik telur base dari UserId (online -> DisplayName)
local function spOwnerName(uidStr)
    local num = tonumber(uidStr)
    if num then
        local plr = safe(Players.GetPlayerByUserId, Players, num)
        if plr then return plr.DisplayName end
    end
    return tostring(uidStr or "?")
end

--// ─── API antrean curi (dipakai kartu panel) ────────────────────────────────
-- urut target sesuai prioritas aktif (pola StealPlan kode asli)
local function spSortTargets(targets, mode)
    local sorted = {}
    for _, t in ipairs(targets) do sorted[#sorted + 1] = t end
    local m = mode or Heist.priority
    table.sort(sorted, function(a, b)
        local ka, kb
        if m == "Best Rarity" then
            ka, kb = a.rarityNum or 0, b.rarityNum or 0
        elseif m == "Biggest Weight" then
            ka, kb = a.scale or 0, b.scale or 0
        elseif m == "Best Mutation" then
            ka, kb = #(a.mutations or {}), #(b.mutations or {})
        elseif m == "Lowest Value" then
            return (a.value or 0) < (b.value or 0)
        else -- Highest Value (default kode asli)
            ka, kb = a.value or 0, b.value or 0
        end
        if ka ~= kb then return ka > kb end
        return (a.value or 0) > (b.value or 0)
    end)
    return sorted
end

-- plan = antrean pilihan + maks 8 saran target lolos filter
function Heist.plan()
    local out, seen = {}, {}
    for _, key in ipairs(Heist.pick) do
        if not seen[key] then seen[key] = true out[#out + 1] = key end
    end
    if Heist.on then
        local sorted = spSortTargets(Prey.all(), Heist.priority)
        local added = 0
        for _, egg in ipairs(sorted) do
            if added >= 8 then break end
            if egg.kind ~= "Base" and not seen[egg.key] and filterOk(egg) then
                seen[egg.key] = true
                out[#out + 1] = egg.key
                added = added + 1
            end
        end
    end
    return out
end

-- curi telur ini SEKARANG (klik kartu)
function Heist.now(key)
    if type(key) ~= "string" then return end
    Heist.pick = { key }
    Heist.lock = key
    if not Heist.on then
        Heist.on = true
        local el = El.steal
        if el then safe(function() el:Set(true, true) end) end
    end
    Heist.state = "Curi sekarang (dari panel)"
end

-- antre telur ini ke posisi terdepan (★)
function Heist.prioritize(key)
    if type(key) ~= "string" then return end
    local idx = table.find(Heist.pick, key)
    if idx then table.remove(Heist.pick, idx) end
    table.insert(Heist.pick, 1, key)
    Heist.lock = key
    if not Heist.on then
        Heist.on = true
        local el = El.steal
        if el then safe(function() el:Set(true, true) end) end
    end
end

-- batalkan antrean telur ini (X / ★ saat sudah antre)
function Heist.cancel(key)
    if type(key) ~= "string" then return end
    local idx = table.find(Heist.pick, key)
    if idx then table.remove(Heist.pick, idx) end
    if Heist.lock == key then Heist.lock = nil end
end

-- geser urutan dalam plan (▲ ▼)
function Heist.moveInPlan(key, delta)
    local plan = Heist.plan()
    local i = table.find(plan, key)
    if not i then return end
    local j = i + (delta or 0)
    if j < 1 or j > #plan or not plan[j] then return end
    plan[i], plan[j] = plan[j], plan[i]
    local wasPick = {}
    for _, k in ipairs(Heist.pick) do wasPick[k] = true end
    Heist.pick = {}
    for _, k in ipairs(plan) do
        if wasPick[k] then Heist.pick[#Heist.pick + 1] = k end
    end
end

--// ─── pencari HUD game ──────────────────────────────────────────────────────
local function spFindGameHud()
    local pg = safe(function() return LocalPlayer:FindFirstChildOfClass("PlayerGui") end)
    if not pg then return nil end
    local hud = safe(function() return pg:FindFirstChild("HUD") end)
    if not hud then return nil end
    local gameHud = safe(function() return hud:FindFirstChild("GameHUD") end)
    local right = gameHud and safe(function() return gameHud:FindFirstChild("RightButtons") end)
    local eggs = right and safe(function() return right:FindFirstChild("EggsButton") end)
    local pets = right and safe(function() return right:FindFirstChild("PetsButton") end)
    local active = safe(function() return pg:FindFirstChild("ActivePets") end)
    local frame = active and safe(function() return active:FindFirstChild("Frame") end)
    if eggs and pets and frame then
        return { PlayerGui = pg, RightButtons = right, Eggs = eggs, Pets = pets,
            ActivePetsFrame = frame }
    end
    return nil
end

local function spClone(inst)
    local ok, c = pcall(function() return inst:Clone() end)
    if not (ok and typeof(c) == "Instance") then return nil end
    safe(function()
        for _, d in ipairs(c:GetDescendants()) do
            if d:IsA("LuaSourceContainer") then d:Destroy() end
        end
    end)
    return c
end

--// ─── objek panel ───────────────────────────────────────────────────────────
local StealPanel = {
    panelGui = nil, root = nil, list = nil, rows = {},
    btnGui = nil, btn = nil, hudConns = {},
    open = false, built = false,
    filter = "All", -- "All" | "Halloween" | "Field" (pola kode asli)
    SORTS = { "Best Rarity", "Biggest Weight", "Best Mutation", "Highest Value", "Lowest Value" },
    mode = "hijack", -- "hijack" (HUD game) | "own" (fallback)
    origPos = nil,
    lblSort = nil, rowSteal = nil, rowFilter = nil,
}

local function spDestroyOld()
    local scopes = {}
    if type(gethui) == "function" then
        local h = safe(gethui)
        if h then table.insert(scopes, h) end
    end
    if LocalPlayer then
        local pg = safe(function() return LocalPlayer:FindFirstChild("PlayerGui") end)
        if pg then table.insert(scopes, pg) end
    end
    for _, scope in ipairs(scopes) do
        local kids = safe(function() return scope:GetChildren() end) or {}
        for _, d in ipairs(kids) do
            local nm = tostring(d.Name)
            if nm == "ThorHubStealPanel" or nm == "ThorHubSPBtn" then
                safe(function() d:Destroy() end)
            end
        end
    end
end

-- hancurkan panel sesi lama bila script di-execute ulang
spDestroyOld()

function StealPanel.Destroy()
    for _, c in ipairs(StealPanel.hudConns) do
        safe(function() c:Disconnect() end)
    end
    StealPanel.hudConns = {}
    if StealPanel.panelGui then safe(function() StealPanel.panelGui:Destroy() end) end
    if StealPanel.btnGui then safe(function() StealPanel.btnGui:Destroy() end) end
    StealPanel.panelGui = nil
    StealPanel.btnGui = nil
    StealPanel.btn = nil
    StealPanel.root = nil
    StealPanel.list = nil
    StealPanel.rows = {}
    StealPanel.built = false
    StealPanel.open = false
    StealPanel.origPos = nil
    StealPanel.lblSort = nil
    StealPanel.rowSteal = nil
    StealPanel.rowFilter = nil
end

--// ─── kartu telur ───────────────────────────────────────────────────────────
local function spBuildRow(list, egg, rank, picked)
    local rcol = spRarityColor(egg.rarityNum)
    local row = spNew("TextButton", {
        Size = UDim2.new(1, -6, 0, 46),
        BackgroundColor3 = SP_CARD, BorderSizePixel = 0, Text = "",
        AutoButtonColor = false, LayoutOrder = rank,
    }, list)
    spNew("UICorner", { CornerRadius = UDim.new(0, 6) }, row)
    spNew("UIStroke", { Color = SP_STROKE, Thickness = 1 }, row)

    -- rank / tanda antre
    spNew("TextLabel", {
        Size = UDim2.new(0, 26, 1, 0), Position = UDim2.new(0, 6, 0, 0),
        BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = picked and SP_GOLD or SP_DIM,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = picked and ("#" .. tostring(rank)) or tostring(rank),
    }, row)

    -- blok warna rarity sebagai ikon
    local iconBlock = spNew("Frame", {
        Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(0, 34, 0, 8),
        BackgroundColor3 = rcol, BorderSizePixel = 0,
    }, row)
    spNew("UICorner", { CornerRadius = UDim.new(0, 8) }, iconBlock)

    -- nama (+@pemilik utk telur base)
    local nameTxt = tostring(egg.name or "?")
    if egg.kind == "Base" then
        nameTxt = nameTxt .. "  @" .. spOwnerName(egg.ownerUid)
    end
    spNew("TextLabel", {
        Size = UDim2.new(1, -236, 0, 22), Position = UDim2.new(0, 72, 0, 4),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13,
        TextColor3 = SP_TEXT, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Text = nameTxt,
    }, row)

    -- nilai $/dtk
    spNew("TextLabel", {
        Size = UDim2.new(0, 74, 0, 22), Position = UDim2.new(1, -160, 0, 4),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = SP_GREEN, TextXAlignment = Enum.TextXAlignment.Right,
        Text = "$" .. fmtNum(egg.value or 0) .. "/s",
    }, row)

    -- detail: rarity · area · mutasi · jarak
    local dparts = { tostring(egg.rarityLabel or "?") }
    if egg.area and egg.area ~= "" then dparts[#dparts + 1] = tostring(egg.area) end
    if type(egg.mutations) == "table" and #egg.mutations > 0 then
        dparts[#dparts + 1] = table.concat(egg.mutations, " ")
    end
    local myRoot = Ride.root()
    if egg.pos and myRoot then
        dparts[#dparts + 1] = tostring(math.floor((egg.pos - myRoot.Position).Magnitude + 0.5)) .. "m"
    end
    spNew("TextLabel", {
        Size = UDim2.new(1, -236, 0, 16), Position = UDim2.new(0, 72, 0, 26),
        BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 10,
        TextColor3 = SP_DIM, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = table.concat(dparts, "  ·  "),
    }, row)

    -- tombol aksi kanan: ▲ ▼ ★ X
    local function actBtn(x, w, txt, col, cb)
        local b = spNew("TextButton", {
            Size = UDim2.new(0, w, 0, 24), Position = UDim2.new(1, x, 0, 11),
            BackgroundColor3 = Color3.fromRGB(30, 36, 56), BorderSizePixel = 0,
            Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = col, Text = txt,
        }, row)
        spNew("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
        safe(function() b.Activated:Connect(function() spClick() cb() end) end)
        return b
    end
    local key = egg.key
    actBtn(-88, 22, "▲", picked and SP_GOLD or SP_DIM, function()
        Heist.moveInPlan(key, -1)
        StealPanel.Refresh()
    end)
    actBtn(-64, 22, "▼", picked and SP_GOLD or SP_DIM, function()
        Heist.moveInPlan(key, 1)
        StealPanel.Refresh()
    end)
    actBtn(-40, 22, "★", picked and SP_GOLD or SP_DIM, function()
        if picked then Heist.cancel(key) else Heist.prioritize(key) end
        StealPanel.Refresh()
    end)
    actBtn(-16, 22, "X", SP_RED, function()
        Heist.cancel(key)
        StealPanel.Refresh()
    end)

    -- klik baris = curi sekarang
    safe(function()
        row.Activated:Connect(function()
            spClick()
            Heist.now(key)
            Heist.state = "Curi sekarang: " .. tostring(egg.name)
            StealPanel.Refresh()
        end)
    end)
    return { row = row, key = key }
end

--// ─── refresh isi daftar ────────────────────────────────────────────────────
function StealPanel.Refresh()
    if not (StealPanel.list and StealPanel.open) then return end
    for _, r in ipairs(StealPanel.rows) do
        safe(function() r.row:Destroy() end)
    end
    StealPanel.rows = {}

    local targets = Prey.all()
    local byKey = {}
    for _, t in ipairs(targets) do byKey[t.key] = t end

    -- susun: plan (antrean + saran) dulu, lalu sisa lolos filter, maks 24
    local ordered, seen = {}, {}
    local plan = Heist.plan()
    local pickedSet = {}
    for _, k in ipairs(Heist.pick) do pickedSet[k] = true end
    for _, k in ipairs(plan) do
        local egg = byKey[k]
        if egg then
            local show = true
            if StealPanel.filter == "Halloween" then show = egg.kind == "Halloween" end
            if StealPanel.filter == "Field" then show = egg.kind ~= "Halloween" and egg.kind ~= "Base" end
            if show then
                seen[k] = true
                ordered[#ordered + 1] = { egg = egg, picked = pickedSet[k] ~= nil }
            end
        end
    end
    if #ordered < 24 then
        local sorted = spSortTargets(targets, Heist.priority)
        for _, egg in ipairs(sorted) do
            if #ordered >= 24 then break end
            if not seen[egg.key] then
                local show = true
                if StealPanel.filter == "Halloween" then show = egg.kind == "Halloween" end
                if StealPanel.filter == "Field" then show = egg.kind ~= "Halloween" and egg.kind ~= "Base" end
                -- v5.1: telur BASE ikut ditampilkan (klik kartu = curi manual
                -- — satu-satunya jalur curi telur base ala kode asli)
                if show then
                    seen[egg.key] = true
                    ordered[#ordered + 1] = { egg = egg, picked = false }
                end
            end
        end
    end

    for i, item in ipairs(ordered) do
        local r = spBuildRow(StealPanel.list, item.egg, i, item.picked)
        StealPanel.rows[#StealPanel.rows + 1] = r
    end
    safe(function()
        local n = #StealPanel.rows
        StealPanel.list.CanvasSize = UDim2.new(0, 0, 0, n * 52 + 6)
    end)

    if StealPanel.lblSort then
        safe(function() StealPanel.lblSort.Text = "Sort: " .. tostring(Heist.priority) end)
    end
    if StealPanel.rowSteal then
        safe(function()
            StealPanel.rowSteal.Text = Heist.on and "Steal ✓" or "Steal"
            StealPanel.rowSteal.BackgroundColor3 = Heist.on
                and Color3.fromRGB(30, 120, 40) or Color3.fromRGB(30, 36, 56)
        end)
    end
    if StealPanel.rowFilter then
        safe(function()
            StealPanel.rowFilter.Text = StealPanel.filter == "All" and "All"
                or (StealPanel.filter == "Halloween" and "Halloween" or "Field")
        end)
    end
end

--// ─── buka/tutup + animasi slide ───────────────────────────────────────────
function StealPanel.Show()
    if not StealPanel.built then StealPanel.Build() end
    if not StealPanel.root then return end
    StealPanel.open = true
    _G.__THORHUB_SP_OPEN = true
    safe(function()
        StealPanel.panelGui.Enabled = true
        local target = StealPanel.origPos or UDim2.new(1, -12, 0.5, 0)
        local startPos
        if StealPanel.mode == "own" then
            startPos = UDim2.new(1, 60, 0.5, 0)
        else
            startPos = UDim2.new(target.X.Scale, target.X.Offset + 60,
                target.Y.Scale, target.Y.Offset)
        end
        StealPanel.root.Position = startPos
        local tw = TweenService:Create(StealPanel.root,
            TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            { Position = target })
        tw:Play()
    end)
    StealPanel.Refresh()
end

function StealPanel.Hide()
    StealPanel.open = false
    _G.__THORHUB_SP_OPEN = false
    if not StealPanel.root then return end
    safe(function()
        local target = StealPanel.origPos or UDim2.new(1, -12, 0.5, 0)
        local startPos
        if StealPanel.mode == "own" then
            startPos = UDim2.new(1, 60, 0.5, 0)
        else
            startPos = UDim2.new(target.X.Scale, target.X.Offset + 60,
                target.Y.Scale, target.Y.Offset)
        end
        local tw = TweenService:Create(StealPanel.root,
            TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
            { Position = startPos })
        tw:Play()
        task.delay(0.26, function()
            if not StealPanel.open and StealPanel.panelGui then
                StealPanel.panelGui.Enabled = false
            end
        end)
    end)
end

function StealPanel.Toggle()
    if StealPanel.open then StealPanel.Hide() else StealPanel.Show() end
end

--// ─── BUILD ─────────────────────────────────────────────────────────────────
function StealPanel.Build()
    StealPanel.Destroy()
    spDestroyOld()

    local hud = spFindGameHud()

    -- 1) tombol toggle (kloning tombol Pets game)
    local btnGui = spNew("ScreenGui", {
        ResetOnSpawn = false, DisplayOrder = 55, Name = "ThorHubSPBtn",
    })
    safe(function()
        btnGui.Parent = (type(gethui) == "function" and gethui())
            or LocalPlayer:FindFirstChildOfClass("PlayerGui")
    end)
    StealPanel.btnGui = btnGui

    local btn = nil
    if hud then
        local clone = spClone(hud.Pets)
        if clone then
            for _, d in ipairs(clone:GetChildren()) do
                local n = tostring(d.Name)
                if n == "Notification" or n == "ReadyNotification" or n == "NightImage"
                    or n == "NightText" or n == "ConsoleButton" or n == "Badge" then
                    safe(function() d:Destroy() end)
                end
            end
            safe(function()
                clone.Visible = true
                clone.AnchorPoint = Vector2.new(0.5, 0.5)
                clone.Parent = btnGui
            end)
            local lbl = safe(function()
                return clone:FindFirstChild("Label") or clone:FindFirstChildOfClass("TextLabel")
            end)
            if lbl then safe(function() lbl.Text = "Steal" end) end
            local grad = safe(function() return clone:FindFirstChildOfClass("UIGradient") end)
            if grad then
                safe(function()
                    grad.Color = SP_Theme.Toggle.Color
                    grad.Rotation = SP_Theme.Toggle.Rotation
                end)
            else
                safe(function()
                    local g = Instance.new("UIGradient")
                    g.Color = SP_Theme.Toggle.Color
                    g.Rotation = SP_Theme.Toggle.Rotation
                    g.Parent = clone
                end)
            end
            btn = clone
            StealPanel.mode = "hijack"
        end
    end
    if not btn then
        -- fallback: tombol mandiri ⚡ bergaya sama
        btn = spNew("TextButton", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.new(0, 64, 0, 64),
            BackgroundColor3 = Color3.fromRGB(132, 74, 255),
            Text = "⚡", TextSize = 28, Font = Enum.Font.GothamBold,
            TextColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0,
        }, btnGui)
        spNew("UICorner", { CornerRadius = UDim.new(0, 16) }, btn)
        spNew("UIGradient", { Color = SP_Theme.Toggle.Color, Rotation = SP_Theme.Toggle.Rotation }, btn)
        spNew("UIStroke", { Color = SP_Theme.Toggle.Stroke, Thickness = 2 }, btn)
    end
    StealPanel.btn = btn
    safe(function()
        btn.Activated:Connect(function()
            spClick()
            StealPanel.Toggle()
        end)
    end)

    -- ikuti posisi kolom tombol Eggs game (mirror posisi kolom)
    if hud and StealPanel.mode == "hijack" then
        local conn = safe(function()
            return RunService.RenderStepped:Connect(function()
                if not (btn and btn.Parent and hud.Eggs and hud.Eggs.Parent) then return end
                local ePos = hud.Eggs.AbsolutePosition
                local eSize = hud.Eggs.AbsoluteSize
                local gPos = btnGui.AbsolutePosition
                local rel = UDim2.new(0, ePos.X - gPos.X + eSize.X / 2,
                    0, ePos.Y - gPos.Y + eSize.Y * 1.5 + 8)
                if btn.Position ~= rel then btn.Position = rel end
            end)
        end)
        if conn then StealPanel.hudConns[#StealPanel.hudConns + 1] = conn end
    else
        safe(function() btn.Position = UDim2.new(0.5, 0, 0, 80) end)
    end

    -- 2) panel (kloning frame ActivePets game)
    local panelGui = spNew("ScreenGui", {
        ResetOnSpawn = false, DisplayOrder = 56, Name = "ThorHubStealPanel",
        Enabled = false,
    })
    safe(function()
        panelGui.Parent = (type(gethui) == "function" and gethui())
            or LocalPlayer:FindFirstChildOfClass("PlayerGui")
    end)
    StealPanel.panelGui = panelGui

    local root, list
    if hud then
        local frame = spClone(hud.ActivePetsFrame)
        if frame then
            safe(function() frame.Parent = panelGui end)
            spRename(frame)
            root = frame
            StealPanel.origPos = safe(function() return frame.Position end)
            safe(function()
                for _, d in ipairs(frame:GetChildren()) do
                    local n = tostring(d.Name)
                    if n ~= "Header" and n ~= "ScrollingFrame" and n ~= "Close" then
                        d:Destroy()
                    end
                end
            end)
            local header = safe(function() return frame:FindFirstChild("Header")
                or frame:FindFirstChildOfClass("Frame") end)
            if header then
                local lbl = safe(function()
                    return header:FindFirstChild("Title")
                        or header:FindFirstChildOfClass("TextLabel")
                end)
                if lbl then safe(function() lbl.Text = "Steal Panel" end) end
            end
            local close = safe(function() return frame:FindFirstChild("Close") end)
            if close then
                local cl = safe(function() return close:FindFirstChildOfClass("TextLabel")
                    or close:FindFirstChild("Label") end)
                if cl then safe(function() cl.Text = ">" end) end
                safe(function()
                    close.Activated:Connect(function()
                        spClick() StealPanel.Hide()
                    end)
                end)
            end
            list = safe(function() return frame:FindFirstChild("ScrollingFrame") end)
            if list then
                safe(function()
                    for _, d in ipairs(list:GetChildren()) do
                        if d:IsA("GuiObject") then d:Destroy() end
                    end
                end)
            end
        end
    end
    if not root then
        -- fallback: panel mandiri layout sama
        StealPanel.mode = "own"
        root = spNew("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Size = UDim2.new(0, 340, 0, 460),
            BackgroundColor3 = SP_BG, BorderSizePixel = 0, Active = true,
        }, panelGui)
        StealPanel.origPos = UDim2.new(1, -12, 0.5, 0)
        spNew("UICorner", { CornerRadius = UDim.new(0, 10) }, root)
        spNew("UIStroke", { Color = SP_STROKE, Thickness = 1 }, root)
        local header = spNew("Frame", {
            Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = SP_CARD,
            BorderSizePixel = 0,
        }, root)
        spNew("UICorner", { CornerRadius = UDim.new(0, 10) }, header)
        spNew("TextLabel", {
            Size = UDim2.new(1, -80, 1, 0), Position = UDim2.new(0, 12, 0, 0),
            BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 15,
            TextColor3 = SP_TEXT, TextXAlignment = Enum.TextXAlignment.Left,
            Text = "Steal Panel",
        }, header)
        local closeBtn = spNew("TextButton", {
            Size = UDim2.new(0, 30, 0, 26), Position = UDim2.new(1, -36, 0, 6),
            BackgroundColor3 = Color3.fromRGB(30, 36, 56), Text = ">",
            Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = SP_DIM,
            BorderSizePixel = 0,
        }, header)
        spNew("UICorner", { CornerRadius = UDim.new(0, 6) }, closeBtn)
        safe(function()
            closeBtn.Activated:Connect(function()
                spClick() StealPanel.Hide()
            end)
        end)
    end
    StealPanel.root = root

    -- 3) bar tombol: Sort + Steal + Filter
    local topRow = spNew("Frame", {
        Size = UDim2.new(1, -16, 0, 30), Position = UDim2.new(0, 8, 0, 42),
        BackgroundTransparency = 1,
    }, root)
    spNew("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6),
    }, topRow)

    local function topBtn(order, w, txt, cb)
        local b = spNew("TextButton", {
            Size = UDim2.new(0, w, 1, 0), BackgroundColor3 = Color3.fromRGB(30, 36, 56),
            BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 12,
            TextColor3 = SP_TEXT, Text = txt, LayoutOrder = order,
        }, topRow)
        spNew("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
        safe(function() b.Activated:Connect(function() spClick() cb() end) end)
        return b
    end

    -- Sort (siklus prioritas — sync dropdown Steal Priority)
    local sortBtn = topBtn(1, 118, "Sort: " .. tostring(Heist.priority), function()
        local idx = table.find(StealPanel.SORTS, Heist.priority) or 4
        local nxt = StealPanel.SORTS[idx % #StealPanel.SORTS + 1]
        Heist.priority = nxt
        local el = El.stealPrio
        if el then safe(function() el:Set(nxt, true) end) end
        StealPanel.Refresh()
    end)
    StealPanel.lblSort = sortBtn

    -- Steal (sync toggle Auto Steal)
    StealPanel.rowSteal = topBtn(2, 64, "Steal", function()
        local newVal = not Heist.on
        Heist.on = newVal
        local el = El.steal
        if el then safe(function() el:Set(newVal, true) end) end
        StealPanel.Refresh()
    end)

    -- Filter All/Halloween/Field
    StealPanel.rowFilter = topBtn(3, 72, StealPanel.filter, function()
        StealPanel.filter = (StealPanel.filter == "All" and "Halloween")
            or (StealPanel.filter == "Halloween" and "Field") or "All"
        StealPanel.Refresh()
    end)

    -- 4) daftar kartu
    if not list then
        list = spNew("ScrollingFrame", {
            Size = UDim2.new(1, -16, 1, -86), Position = UDim2.new(0, 8, 0, 78),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 4, CanvasSize = UDim2.new(0, 0, 0, 0),
        }, root)
        spNew("UIListLayout", {
            Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
        }, list)
        spNew("UIPadding", { PaddingTop = UDim.new(0, 2) }, list)
    else
        safe(function()
            list.Position = UDim2.new(0, 8, 0, 78)
            list.Size = UDim2.new(1, -16, 1, -86)
            list.BackgroundTransparency = 1
            list.ScrollBarThickness = 4
            for _, d in ipairs(list:GetChildren()) do
                if d:IsA("UIListLayout") or d:IsA("UIPadding") then d:Destroy() end
            end
            local lay = Instance.new("UIListLayout")
            lay.Padding = UDim.new(0, 6)
            lay.SortOrder = Enum.SortOrder.LayoutOrder
            lay.Parent = list
        end)
    end
    StealPanel.list = list
    StealPanel.built = true
end

-- aktif/nonaktif (dipakai toggle "Steal Panel" di menu Farm)
local SP_Wanted = true
function StealPanel.Enable(on)
    SP_Wanted = on == true
    if SP_Wanted then
        if not StealPanel.built then StealPanel.Build() end
        -- pulihkan status terbuka (default: terbuka — pola kode asli)
        if _G.__THORHUB_SP_OPEN ~= false then StealPanel.Show() end
    else
        StealPanel.Destroy()
    end
end
function StealPanel.Wanted() return SP_Wanted end

-- refresh berkala saat terbuka (murah — hanya saat open)
Engine.every(0.6, function()
    if StealPanel.open then StealPanel.Refresh() end
end)

--═══════════════════════════════════════════════════════════════════════════════
--  BAGIAN 6 · STORE — simpan & muat konfigurasi (file JSON di folder ThorHub)
--═══════════════════════════════════════════════════════════════════════════════
local Store = { enabled = false, registry = {}, timer = nil }

function Store.track(name, elem)
    Store.registry[name] = elem
end

function Store.path()
    if type(isfolder) ~= "function" or type(makefolder) ~= "function" then return nil end
    safe(function()
        if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end
    end)
    return CONFIG_FOLDER .. "/" .. CONFIG_FILE
end

function Store.save()
    local p = Store.path()
    if not p or type(writefile) ~= "function" then return end
    local data = {}
    for name, elem in pairs(Store.registry) do
        local ok, v = pcall(function() return elem:Get() end)
        if ok and v ~= nil then data[name] = v end
    end
    safe(function() writefile(p, HttpService:JSONEncode(data)) end)
end

function Store.load()
    local p = Store.path()
    if not p or type(readfile) ~= "function" then return false end
    local raw = safe(readfile, p)
    if type(raw) ~= "string" or #raw == 0 then return false end
    local data = safe(function() return HttpService:JSONDecode(raw) end)
    if type(data) ~= "table" then return false end
    for name, v in pairs(data) do
        local elem = Store.registry[name]
        if elem then
            safe(function() elem:Set(v) end) -- memicu callback => Farm ikut tersinkron
        end
    end
    return true
end

function Store.wipe()
    local p = Store.path()
    if p and type(delfile) == "function" then
        safe(function() delfile(p) end)
    end
end

function Store.queueSave()
    if Store.timer then
        safe(function() task.cancel(Store.timer) end)
        Store.timer = nil
    end
    Store.timer = task.delay(2.0, function()
        Store.timer = nil
        Store.save()
    end)
end

local function onTuned()
    if Store.enabled then Store.queueSave() end
end

--═══════════════════════════════════════════════════════════════════════════════
--  BAGIAN 7 · THORUI — muat library dari GitHub lalu bangun TAB FARM lengkap
--  Struktur seksi & nama elemen 1:1 dengan tab Farm kode baru Steal an Egg.
--═══════════════════════════════════════════════════════════════════════════════
local function acquireThorUi()
    for _ = 1, 3 do
        local lib = safe(function()
            local src = game:HttpGet(THORUI_URL)
            if type(src) ~= "string" or #src < 100 then
                error("download ThorUi gagal / terpotong")
            end
            return loadstring(src, "@ThorUi.lua")()
        end)
        if type(lib) == "table" and type(lib.CreateWindow) == "function" then
            return lib
        end
        task.wait(1)
    end
    return nil
end

local ThorUi = acquireThorUi()
if not ThorUi then
    toastOS("⚡ ThorHub", "Gagal memuat library ThorUi — cek koneksi internet lalu coba lagi.", 7)
    error("[ThorHub] ThorUi gagal dimuat dari " .. THORUI_URL)
end
UI.ThorUi = ThorUi

function UI.toast(title, content, duration)
    safe(function()
        ThorUi:Notify({ Title = title, Content = content, Duration = duration or 4 })
    end)
end

-- hancurkan sesi ThorHub lama bila script di-execute ulang
-- (window lama + tombol melayang & notifikasi dari library lama)
if type(_G.__THORHUB_FARM_WINDOW) == "table" then
    safe(function() _G.__THORHUB_FARM_WINDOW:Destroy() end)
end
if type(_G.__THORHUB_FARM_UI) == "table" then
    safe(function() _G.__THORHUB_FARM_UI:Destroy() end)
end

local Window = ThorUi:CreateWindow({
    Title = "ThorHub ⚡ Farm",
    Keybind = Enum.KeyCode.RightControl,
    Splash = true,
})
_G.__THORHUB_FARM_WINDOW = Window
_G.__THORHUB_FARM_UI = ThorUi

-- daftar toggle untuk tombol "Matikan Semua"
local killList = {}
local function reg(el)
    table.insert(killList, el)
    return el
end

--// daftar nama area dari folder game (untuk filter Target Areas)
local function areaNameList()
    local names = {}
    local areas = safe(function()
        local w = workspace:FindFirstChild("World")
        return w and w:FindFirstChild("Areas")
    end)
    if areas then
        local kids = safe(function() return areas:GetChildren() end) or {}
        for _, a in ipairs(kids) do
            if a.Name ~= "GuardAreas" then table.insert(names, a.Name) end
        end
    end
    if #names == 0 then names = { "All" } end
    return names
end

local function listToSet(list)
    local set = {}
    for _, name in ipairs(list or {}) do set[name] = true end
    return set
end

--═══════════════════════════════════════════════════════════════════════════════
--  TAB: FARM — 11 seksi persis menu kode baru
--═══════════════════════════════════════════════════════════════════════════════
local tab = Window:CreateTab({ Name = "Farm", Icon = "⚡" })

--// ── SEKSI 1 · AUTO STEAL ────────────────────────────────────────────────────
tab:AddSection({ Name = "Auto Steal", Collapsed = false })

local tglSteal = tab:AddToggle({
    Name = "Auto Steal",
    Description = "Curi telur area & telur base pemain lain, lalu antar pulang otomatis.",
    Default = false,
    Callback = function(v) Heist.on = v onTuned() end,
})
Store.track("steal.on", reg(tglSteal))
El.steal = tglSteal -- v5.1: dipakai Steal Panel untuk sync toggle

local ddDelivery = tab:AddDropdown({
    Name = "Delivery",
    Values = { "Tween", "Instant Steps", "Fast Tween" },
    Default = "Tween",
    Description = "Tween: antar halus. Instant Steps: lompat bertahap. Fast Tween: tarik 3000-4500 studs/dtk.",
    Depends = { Element = tglSteal, Value = true },
    Callback = function(v) Heist.delivery = v onTuned() end,
})
Store.track("steal.delivery", ddDelivery)

local slSpeed = tab:AddSlider({
    Name = "Delivery Speed",
    Min = 80, Max = 110, Default = 100, Increment = 1,
    Suffix = "%",
    Description = "Kecepatan antar mode Tween (80-110%).",
    Depends = { Element = ddDelivery, Value = "Tween" },
    Callback = function(v) Heist.speedPct = v onTuned() end,
})
Store.track("steal.speedPct", slSpeed)

local slSteps = tab:AddSlider({
    Name = "Step Count",
    Min = 1, Max = 6, Default = 3, Increment = 1,
    Description = "Jumlah lompatan mode Instant Steps.",
    Depends = { Element = ddDelivery, Value = "Instant Steps" },
    Callback = function(v) Heist.steps = v onTuned() end,
})
Store.track("steal.steps", slSteps)

local slFast = tab:AddSlider({
    Name = "Fast Tween Speed",
    Min = 3000, Max = 4500, Default = 3300, Increment = 50,
    Suffix = " st/s",
    Description = "Kecepatan tarik mode Fast Tween.",
    Depends = { Element = ddDelivery, Value = "Fast Tween" },
    Callback = function(v) Heist.fastSpeed = v onTuned() end,
})
Store.track("steal.fastSpeed", slFast)

local ddPrio = tab:AddDropdown({
    Name = "Steal Priority",
    Values = { "Best Rarity", "Biggest Weight", "Best Mutation", "Highest Value", "Lowest Value" },
    Default = "Highest Value",
    Description = "Urutan pilih kalau ada beberapa target sekaligus.",
    Depends = { Element = tglSteal, Value = true },
    Callback = function(v) Heist.priority = v onTuned() end,
})
Store.track("steal.priority", ddPrio)
El.stealPrio = ddPrio -- v5.1: dipakai Steal Panel untuk sync prioritas

local ddStealRar = tab:AddDropdown({
    Name = "Min Rarity",
    Values = RARITY_ANY,
    Default = "Any",
    Description = "Telur di bawah rarity ini diabaikan.",
    Depends = { Element = tglSteal, Value = true },
    Callback = function(v) Heist.minRarity = v onTuned() end,
})
Store.track("steal.minRarity", ddStealRar)

local slStealVal = tab:AddSlider({
    Name = "Min Steal Value",
    Min = 0, Max = 100000, Default = 0, Increment = 500,
    Suffix = " $/s",
    Description = "Nilai jual minimal telur yang dikejar (0 = abaikan).",
    Depends = { Element = tglSteal, Value = true },
    Callback = function(v) Heist.minValue = v onTuned() end,
})
Store.track("steal.minValue", slStealVal)

local ddAreas = tab:AddDropdown({
    Name = "Target Areas",
    Values = areaNameList(),
    Multi = true, Search = true,
    Description = "Kosong = semua area. Telur base pemain lain dicuri manual lewat Steal Panel (klik kartunya).",
    Depends = { Element = tglSteal, Value = true },
    Callback = function(list)
        Heist.areas = listToSet(list)
        onTuned()
    end,
})
Store.track("steal.areas", ddAreas)

local ddStealEgg = tab:AddDropdown({
    Name = "Target Specific Eggs",
    Values = Atlas.eggSpecies(),
    Multi = true, Search = true,
    Description = "Kosong = semua spesies telur.",
    Depends = { Element = tglSteal, Value = true },
    Callback = function(list)
        Heist.specific = listToSet(list)
        onTuned()
    end,
})
Store.track("steal.specific", ddStealEgg)

local tglMissing = tab:AddToggle({
    Name = "Steal Missing Index Eggs",
    Description = "Hanya kejar spesies yang belum ada di Index/koleksi.",
    Default = false,
    Depends = { Element = tglSteal, Value = true },
    Callback = function(v) Heist.missingIndex = v onTuned() end,
})
Store.track("steal.missingIndex", tglMissing)

local tglDropSafe = tab:AddToggle({
    Name = "Drop Eggs At Safe Zone",
    Description = "Antar ke Safe Zone alih-alih petak base.",
    Default = false,
    Depends = { Element = tglSteal, Value = true },
    Callback = function(v) Heist.dropSafe = v onTuned() end,
})
Store.track("steal.dropSafe", tglDropSafe)

local tglAgPanel = tab:AddToggle({
    Name = "Anti Guard Panel",
    Description = "Chip status guard di kanan-bawah saat Auto Steal aktif (merah = guard aktif dekat, hijau = aman).",
    Default = true,
    Depends = { Element = tglSteal, Value = true },
    Callback = function(v) Heist.agPanel = v onTuned() end,
})
Store.track("steal.agPanel", tglAgPanel)

local tglStealPanel = tab:AddToggle({
    Name = "Steal Panel",
    Description = "Panel daftar telur ala kode asli (hijack HUD game: kloning tombol Pets + frame ActivePets). Klik kartu = curi sekarang, ★ = antre prioritas, ▲▼ urut, X batal, Sort = ganti prioritas, Steal = toggle Auto Steal.",
    Default = true,
    Callback = function(v)
        safe(function() StealPanel.Enable(v) end)
        onTuned()
    end,
})
Store.track("steal.panel", tglStealPanel)

StealBoard = tab:AddCanvas({
    Name = "Hasil Pencurian",
    Widgets = {
        { Type = "Text", Name = "stolen",     Text = "Total Dicuri",    Value = "0" },
        { Type = "Text", Name = "delivered",  Text = "Tersampaikan",    Value = "0" },
        { Type = "Text", Name = "carry",      Text = "Tangan",         Value = "Kosong" },
        { Type = "Text", Name = "targets",    Text = "Target Terlihat", Value = "0" },
        { Type = "Text", Name = "queue",      Text = "Antrean Panel",   Value = "0" },
        { Type = "Divider" },
        { Type = "Text", Name = "stealstate", Text = "Status Mesin",   Value = "Off" },
        { Type = "Text", Name = "best",       Text = "Curian Terbaik", Value = "-" },
    },
})

--// ── SEKSI 2 · AUTO PROGRESSION ──────────────────────────────────────────────
tab:AddSection({ Name = "Auto Progression" })

local tglBuyTrail = tab:AddToggle({
    Name = "Auto Buy Trail",
    Description = "Beli semua trail yang belum dimiliki saat uang cukup.",
    Default = false,
    Callback = function(v) Progress.buyTrail = v onTuned() end,
})
Store.track("prog.buyTrail", reg(tglBuyTrail))

local tglUpBase = tab:AddToggle({
    Name = "Auto Upgrade Base",
    Description = "Naikkan tier petak base saat uang melebihi biaya upgrade.",
    Default = false,
    Callback = function(v) Progress.upBase = v onTuned() end,
})
Store.track("prog.upBase", reg(tglUpBase))

local tglUpTread = tab:AddToggle({
    Name = "Auto Upgrade Treadmill",
    Description = "Naikkan tier treadmill saat uang cukup (cek harga Data/Treadmills).",
    Default = false,
    Callback = function(v) Progress.upTread = v onTuned() end,
})
Store.track("prog.upTread", reg(tglUpTread))

local tglClaimCash = tab:AddToggle({
    Name = "Auto Claim Money",
    Description = "Klaim cash offline (AwayEarnings) otomatis.",
    Default = false,
    Callback = function(v) Progress.claimCash = v onTuned() end,
})
Store.track("prog.claimCash", reg(tglClaimCash))

local tglClaimIndex = tab:AddToggle({
    Name = "Auto Claim Index",
    Description = "Redeem semua reward Index/koleksi + egg terbatas (Codex).",
    Default = false,
    Callback = function(v) Progress.claimIndex = v onTuned() end,
})
Store.track("prog.claimIndex", reg(tglClaimIndex))

--// ── SEKSI 3 · AUTO MUTATION ─────────────────────────────────────────────────
tab:AddSection({ Name = "Auto Mutation" })

local tglMutate = tab:AddToggle({
    Name = "Auto Mutate",
    Description = "Pakai item mutasi ke telur terpasang di base.",
    Default = false,
    Callback = function(v) Mutate.on = v onTuned() end,
})
Store.track("mutate.on", reg(tglMutate))

local ddMutList = tab:AddDropdown({
    Name = "Mutations To Use",
    Values = MUT_DISPLAY,
    Multi = true,
    Description = "Item mutasi yang dipakai (dicoba berurutan sampai satu diterima).",
    Depends = { Element = tglMutate, Value = true },
    Callback = function(list)
        Mutate.use = listToSet(list)
        onTuned()
    end,
})
Store.track("mutate.use", ddMutList)

local ddMutRar = tab:AddDropdown({
    Name = "Mutate Min Rarity",
    Values = RARITY_ANY,
    Default = "Any",
    Description = "Hanya telur dengan rarity minimal ini yang dimutasi.",
    Depends = { Element = tglMutate, Value = true },
    Callback = function(v) Mutate.minRarity = v onTuned() end,
})
Store.track("mutate.minRarity", ddMutRar)

local slMutVal = tab:AddSlider({
    Name = "Mutate Min Value",
    Min = 0, Max = 100000, Default = 0, Increment = 500,
    Suffix = " $/s",
    Description = "Lewati telur bernilai kurang dari ini (0 = abaikan).",
    Depends = { Element = tglMutate, Value = true },
    Callback = function(v) Mutate.minValue = v onTuned() end,
})
Store.track("mutate.minValue", slMutVal)

local ddMutTarget = tab:AddDropdown({
    Name = "Mutate Target Eggs",
    Values = Atlas.eggSpecies(),
    Multi = true, Search = true,
    Description = "Kosong = semua telur terpasang.",
    Depends = { Element = tglMutate, Value = true },
    Callback = function(list)
        Mutate.targets = listToSet(list)
        onTuned()
    end,
})
Store.track("mutate.targets", ddMutTarget)

local ddMutPrio = tab:AddDropdown({
    Name = "Mutate Priority",
    Values = { "Highest Value", "Best Rarity", "Biggest Size" },
    Default = "Highest Value",
    Description = "Telur mana yang dimutasi lebih dulu.",
    Depends = { Element = tglMutate, Value = true },
    Callback = function(v) Mutate.priority = v onTuned() end,
})
Store.track("mutate.priority", ddMutPrio)

Status.mutate = tab:AddLabel({ Text = "Mutate Status  |  Off" })

--// ── SEKSI 4 · AUTO PLACE EGG ────────────────────────────────────────────────
tab:AddSection({ Name = "Auto Place Egg" })

local tglPlace = tab:AddToggle({
    Name = "Auto Place Egg",
    Description = "Taruh telur terbaik dari tas ke petak base agar menghasilkan uang.",
    Default = false,
    Callback = function(v) Place.on = v onTuned() end,
})
Store.track("place.on", reg(tglPlace))

local ddPlaceRule = tab:AddDropdown({
    Name = "Place Egg Rule",
    Values = { "Always", "Steal Idle", "After Steal", "Night Only" },
    Default = "Always",
    Description = "Kapan menaruh: selalu / saat tidak mengantar curian / 10 dtk setelah curi sukses / hanya malam.",
    Depends = { Element = tglPlace, Value = true },
    Callback = function(v) Place.rule = v onTuned() end,
})
Store.track("place.rule", ddPlaceRule)

local ddPlaceOrder = tab:AddDropdown({
    Name = "Place Egg Order",
    Values = { "Biggest Size", "Highest Value", "Smallest Size" },
    Default = "Biggest Size",
    Description = "Telur mana ditaruh lebih dulu.",
    Depends = { Element = tglPlace, Value = true },
    Callback = function(v) Place.order = v onTuned() end,
})
Store.track("place.order", ddPlaceOrder)

local ddPlaceRar = tab:AddDropdown({
    Name = "Place Rarities",
    Values = RARITY_LIST,
    Default = RARITY_LIST,
    Multi = true,
    Description = "Rarity telur yang boleh ditaruh.",
    Depends = { Element = tglPlace, Value = true },
    Callback = function(list)
        Place.rarities = listToSet(list)
        onTuned()
    end,
})
Store.track("place.rarities", ddPlaceRar)

local ddPlaceEgg = tab:AddDropdown({
    Name = "Place Specific Eggs",
    Values = Atlas.eggSpecies(),
    Multi = true, Search = true,
    Description = "Kosong = semua spesies.",
    Depends = { Element = tglPlace, Value = true },
    Callback = function(list)
        Place.specific = listToSet(list)
        onTuned()
    end,
})
Store.track("place.specific", ddPlaceEgg)

local slPlaceVal = tab:AddSlider({
    Name = "Min Place Value",
    Min = 0, Max = 100000, Default = 0, Increment = 500,
    Suffix = " $/s",
    Description = "Telur bernilai kurang dari ini tidak ditaruh (0 = abaikan).",
    Depends = { Element = tglPlace, Value = true },
    Callback = function(v) Place.minValue = v onTuned() end,
})
Store.track("place.minValue", slPlaceVal)

Status.place = tab:AddLabel({ Text = "Pen Status  |  Off" })

--// ── SEKSI 5 · AUTO TREADMILL ───────────────────────────────────────────────
tab:AddSection({ Name = "Auto Treadmill" })

local tglTread = tab:AddToggle({
    Name = "Auto Treadmill",
    Description = "Berdiri di belt treadmill base sendiri untuk menaikkan speed.",
    Default = false,
    Callback = function(v) Tread.on = v onTuned() end,
})
Store.track("tread.on", reg(tglTread))
El.tread = tglTread

--// ── SEKSI 6 · AUTO HATCH & EQUIP ───────────────────────────────────────────
tab:AddSection({ Name = "Auto Hatch & Equip" })

local tglHatch = tab:AddToggle({
    Name = "Auto Hatch",
    Description = "Tetaskan telur terpasang begitu siap (AskHatch + FinishHatch).",
    Default = false,
    Callback = function(v) Hatch.on = v onTuned() end,
})
Store.track("hatch.on", reg(tglHatch))

local ddHatchRar = tab:AddDropdown({
    Name = "Hatch Min Rarity",
    Values = RARITY_ANY,
    Default = "Any",
    Description = "Hanya tetaskan telur dengan rarity minimal ini.",
    Depends = { Element = tglHatch, Value = true },
    Callback = function(v) Hatch.minRarity = v onTuned() end,
})
Store.track("hatch.minRarity", ddHatchRar)

local slHatchVal = tab:AddSlider({
    Name = "Min Hatch Value",
    Min = 0, Max = 100000, Default = 0, Increment = 500,
    Suffix = " $/s",
    Description = "Lewati telur bernilai kurang dari ini (0 = abaikan).",
    Depends = { Element = tglHatch, Value = true },
    Callback = function(v) Hatch.minValue = v onTuned() end,
})
Store.track("hatch.minValue", slHatchVal)

local ddHatchEgg = tab:AddDropdown({
    Name = "Hatch Specific Eggs",
    Values = Atlas.eggSpecies(),
    Multi = true, Search = true,
    Description = "Kosong = semua spesies.",
    Depends = { Element = tglHatch, Value = true },
    Callback = function(list)
        Hatch.specific = listToSet(list)
        onTuned()
    end,
})
Store.track("hatch.specific", ddHatchEgg)

local tglEquipBest = tab:AddToggle({
    Name = "Auto Equip Best",
    Description = "Pakai kombinasi pet terkuat secara berkala (WearBest).",
    Default = false,
    Callback = function(v) Hatch.equipBest = v onTuned() end,
})
Store.track("hatch.equipBest", reg(tglEquipBest))

--// ── SEKSI 7 · AUTO SELL ────────────────────────────────────────────────────
tab:AddSection({ Name = "Auto Sell" })

local tglSellPet = tab:AddToggle({
    Name = "Auto Sell Pet",
    Description = "Jual pet sesuai filter di bawah.",
    Default = false,
    Callback = function(v) Sell.petOn = v onTuned() end,
})
Store.track("sell.petOn", reg(tglSellPet))

local ddPetMax = tab:AddDropdown({
    Name = "Pet Max Rarity",
    Values = RARITY_ANY,
    Default = "Epic",
    Description = "Jual pet dengan rarity DI BAWAH ini.",
    Depends = { Element = tglSellPet, Value = true },
    Callback = function(v) Sell.petMax = v onTuned() end,
})
Store.track("sell.petMax", ddPetMax)

local slPetVal = tab:AddSlider({
    Name = "Pet Sell Value",
    Min = 0, Max = 100000, Default = 0, Increment = 500,
    Suffix = " $/s",
    Description = "Jual pet bernilai DI BAWAH ini (0 = abaikan nilai).",
    Depends = { Element = tglSellPet, Value = true },
    Callback = function(v) Sell.petValue = v onTuned() end,
})
Store.track("sell.petValue", slPetVal)

local tglKeepMutPet = tab:AddToggle({
    Name = "Keep Mutated Pets",
    Description = "Pet bermutasi tidak dijual.",
    Default = true,
    Depends = { Element = tglSellPet, Value = true },
    Callback = function(v) Sell.petKeepMut = v onTuned() end,
})
Store.track("sell.petKeepMut", tglKeepMutPet)

local ddPetBlack = tab:AddDropdown({
    Name = "Blacklist Sell Pets",
    Values = Atlas.petSpecies(),
    Multi = true, Search = true,
    Description = "Spesies pet yang TIDAK PERNAH dijual.",
    Depends = { Element = tglSellPet, Value = true },
    Callback = function(list)
        Sell.petBlack = listToSet(list)
        onTuned()
    end,
})
Store.track("sell.petBlack", ddPetBlack)

tab:AddButton({
    Name = "Sell Pets Now",
    Description = "Jual semua pet yang lolos filter sekali putaran.",
    Callback = function() sellPetsNow() end,
})

local tglSellEgg = tab:AddToggle({
    Name = "Auto Sell Egg",
    Description = "Jual telur sesuai filter di bawah.",
    Default = false,
    Callback = function(v) Sell.eggOn = v onTuned() end,
})
Store.track("sell.eggOn", reg(tglSellEgg))

local ddEggMax = tab:AddDropdown({
    Name = "Egg Max Rarity",
    Values = RARITY_ANY,
    Default = "Epic",
    Description = "Jual telur dengan rarity DI BAWAH ini.",
    Depends = { Element = tglSellEgg, Value = true },
    Callback = function(v) Sell.eggMax = v onTuned() end,
})
Store.track("sell.eggMax", ddEggMax)

local slEggVal = tab:AddSlider({
    Name = "Egg Sell Value",
    Min = 0, Max = 100000, Default = 0, Increment = 500,
    Suffix = " $/s",
    Description = "Jual telur bernilai DI BAWAH ini (0 = abaikan nilai).",
    Depends = { Element = tglSellEgg, Value = true },
    Callback = function(v) Sell.eggValue = v onTuned() end,
})
Store.track("sell.eggValue", slEggVal)

local tglKeepMutEgg = tab:AddToggle({
    Name = "Keep Mutated Eggs",
    Description = "Telur bermutasi tidak dijual.",
    Default = true,
    Depends = { Element = tglSellEgg, Value = true },
    Callback = function(v) Sell.eggKeepMut = v onTuned() end,
})
Store.track("sell.eggKeepMut", tglKeepMutEgg)

local ddEggBlack = tab:AddDropdown({
    Name = "Blacklist Sell Eggs",
    Values = Atlas.eggSpecies(),
    Multi = true, Search = true,
    Description = "Spesies telur yang TIDAK PERNAH dijual.",
    Depends = { Element = tglSellEgg, Value = true },
    Callback = function(list)
        Sell.eggBlack = listToSet(list)
        onTuned()
    end,
})
Store.track("sell.eggBlack", ddEggBlack)

tab:AddButton({
    Name = "Sell Eggs Now",
    Description = "Jual semua telur yang lolos filter sekali putaran.",
    Callback = function() sellEggsNow() end,
})

--// ── SEKSI 8 · AUTO FUSE MACHINE ────────────────────────────────────────────
tab:AddSection({ Name = "Auto Fuse Machine" })

local tglFuse = tab:AddToggle({
    Name = "Auto Fuse Machine",
    Description = "Gabungkan 2 pet duplikat menjadi 1 di mesin fusion.",
    Default = false,
    Callback = function(v) Fuse.on = v onTuned() end,
})
Store.track("fuse.on", reg(tglFuse))

local ddFuseMode = tab:AddDropdown({
    Name = "Fuse Priority Mode",
    Values = { "Lowest Rarity First", "Highest Rarity First", "Most Copies First", "Lowest Value First" },
    Default = "Lowest Rarity First",
    Description = "Kelompok pet mana yang difuse lebih dulu.",
    Depends = { Element = tglFuse, Value = true },
    Callback = function(v) Fuse.mode = v onTuned() end,
})
Store.track("fuse.mode", ddFuseMode)

local ddFuseOrder = tab:AddDropdown({
    Name = "Pets To Use",
    Values = { "Lowest To Highest", "Highest To Lowest" },
    Default = "Lowest To Highest",
    Description = "Dari ujung mana daftar pet dipakai sebagai bahan.",
    Depends = { Element = tglFuse, Value = true },
    Callback = function(v) Fuse.order = v onTuned() end,
})
Store.track("fuse.order", ddFuseOrder)

local ddFuseMax = tab:AddDropdown({
    Name = "Max Rarity to Fuse",
    Values = RARITY_ANY,
    Default = "Divine",
    Description = "Pet di atas rarity ini tidak dijadikan bahan fusion.",
    Depends = { Element = tglFuse, Value = true },
    Callback = function(v) Fuse.maxRarity = v onTuned() end,
})
Store.track("fuse.maxRarity", ddFuseMax)

local ddFuseSpecies = tab:AddDropdown({
    Name = "Specific Species to Fuse",
    Values = Atlas.petSpecies(),
    Multi = true, Search = true,
    Description = "Kosong = semua spesies.",
    Depends = { Element = tglFuse, Value = true },
    Callback = function(list)
        Fuse.species = listToSet(list)
        onTuned()
    end,
})
Store.track("fuse.species", ddFuseSpecies)

local tglFuseSkipMut = tab:AddToggle({
    Name = "Skip Mutated Pets",
    Description = "Pet bermutasi tidak dijadikan bahan.",
    Default = true,
    Depends = { Element = tglFuse, Value = true },
    Callback = function(v) Fuse.skipMut = v onTuned() end,
})
Store.track("fuse.skipMut", tglFuseSkipMut)

local tglFuseEject = tab:AddToggle({
    Name = "Eject Incomplete Slots",
    Description = "Keluarkan pet yang tertinggal di slot fusion.",
    Default = true,
    Depends = { Element = tglFuse, Value = true },
    Callback = function(v) Fuse.eject = v onTuned() end,
})
Store.track("fuse.eject", tglFuseEject)

Status.fuse = tab:AddLabel({ Text = "Fuse Preview" })

--// ── SEKSI 9 · AUTO FAVORITE ────────────────────────────────────────────────
tab:AddSection({ Name = "Auto Favorite" })

local tglFav = tab:AddToggle({
    Name = "Auto Favorite Pet",
    Description = "Tandai favorit pet yang cocok filter (favorit = tidak ikut terjual).",
    Default = false,
    Callback = function(v) Fav.on = v onTuned() end,
})
Store.track("fav.on", reg(tglFav))

local ddFavRule = tab:AddDropdown({
    Name = "Favorite Rule",
    Values = { "Match Any", "Match All" },
    Default = "Match Any",
    Description = "Any = cukup satu filter lolos. All = semua filter harus lolos.",
    Depends = { Element = tglFav, Value = true },
    Callback = function(v) Fav.rule = v onTuned() end,
})
Store.track("fav.rule", ddFavRule)

local ddFavRar = tab:AddDropdown({
    Name = "Favorite Min Rarity",
    Values = RARITY_ANY,
    Default = "Any",
    Description = "Rarity minimal yang di-favoritkan.",
    Depends = { Element = tglFav, Value = true },
    Callback = function(v) Fav.minRarity = v onTuned() end,
})
Store.track("fav.minRarity", ddFavRar)

local ddFavMut = tab:AddDropdown({
    Name = "Favorite Mutations",
    Values = { "Any Mutation", "No Mutation", "Golden", "Silver", "Rainbow", "Sakura",
        "GreatBloom", "Boss", "Monstrous", "Scrambled", "Enchanted", "Nitro", "Spectral" },
    Multi = true,
    Description = "Mutasi yang di-favoritkan.",
    Depends = { Element = tglFav, Value = true },
    Callback = function(list)
        Fav.mutations = listToSet(list)
        onTuned()
    end,
})
Store.track("fav.mutations", ddFavMut)

local slFavVal = tab:AddSlider({
    Name = "Min Favorite Value",
    Min = 0, Max = 100000, Default = 0, Increment = 500,
    Suffix = " $/s",
    Description = "Nilai minimal yang di-favoritkan (0 = abaikan).",
    Depends = { Element = tglFav, Value = true },
    Callback = function(v) Fav.minValue = v onTuned() end,
})
Store.track("fav.minValue", slFavVal)

local ddFavSpecies = tab:AddDropdown({
    Name = "Always Favorite Species",
    Values = Atlas.petSpecies(),
    Multi = true, Search = true,
    Description = "Spesies yang selalu di-favoritkan.",
    Depends = { Element = tglFav, Value = true },
    Callback = function(list)
        Fav.species = listToSet(list)
        onTuned()
    end,
})
Store.track("fav.species", ddFavSpecies)

local tglFavEquip = tab:AddToggle({
    Name = "Auto Favorite Equipped",
    Description = "Favoritkan pet yang sedang dipakai.",
    Default = false,
    Depends = { Element = tglFav, Value = true },
    Callback = function(v) Fav.equipped = v onTuned() end,
})
Store.track("fav.equipped", tglFavEquip)

local tglFavUnfav = tab:AddToggle({
    Name = "Auto Unfavorite Equipped",
    Description = "Hapus favorit pet yang sedang dipakai.",
    Default = false,
    Depends = { Element = tglFav, Value = true },
    Callback = function(v) Fav.unfav = v onTuned() end,
})
Store.track("fav.unfav", tglFavUnfav)

tab:AddButton({
    Name = "Favorite Pets Now",
    Description = "Favoritkan semua pet yang lolos filter sekali putaran.",
    Callback = function() favoriteNow(false) end,
})

tab:AddButton({
    Name = "Favorite Equipped Now",
    Description = "Favoritkan pet yang sedang dipakai.",
    Callback = function() favoriteEquippedNow(true) end,
})

tab:AddButton({
    Name = "Unfavorite Equipped Now",
    Description = "Hapus favorit semua pet yang sedang dipakai.",
    Callback = function() favoriteEquippedNow(false) end,
})

Status.fav = tab:AddLabel({ Text = "Favorite Preview" })

--// ── SEKSI 10 · PRIORITY ROTATION ────────────────────────────────────────────
tab:AddSection({ Name = "Priority Rotation" })

local tglCycle = tab:AddToggle({
    Name = "Rotate Fishing And Treadmill",
    Description = "Gantian memancing dan naik treadmill otomatis.",
    Default = false,
    Callback = function(v)
        Cycle.on = v
        Cycle.swapAt = 0
        Cycle.lastNight = nil
        onTuned()
    end,
})
Store.track("rot.on", reg(tglCycle))

local ddCycleMode = tab:AddDropdown({
    Name = "Rotation Switch",
    Values = { "Timer", "Every Day" },
    Default = "Timer",
    Description = "Timer: tukar tiap N menit. Every Day: tukar tiap pergantian siang/malam.",
    Depends = { Element = tglCycle, Value = true },
    Callback = function(v)
        Cycle.mode = v
        Cycle.swapAt = 0
        Cycle.lastNight = nil
        onTuned()
    end,
})
Store.track("rot.mode", ddCycleMode)

local slFishMin = tab:AddSlider({
    Name = "Fishing Minutes",
    Min = 1, Max = 120, Default = 5, Increment = 1,
    Suffix = " min",
    Depends = { Element = tglCycle, Value = true },
    Callback = function(v) Cycle.fishMin = v onTuned() end,
})
Store.track("rot.fishMin", slFishMin)

local slTreadMin = tab:AddSlider({
    Name = "Treadmill Minutes",
    Min = 1, Max = 120, Default = 5, Increment = 1,
    Suffix = " min",
    Depends = { Element = tglCycle, Value = true },
    Callback = function(v) Cycle.treadMin = v onTuned() end,
})
Store.track("rot.treadMin", slTreadMin)

Status.rotation = tab:AddLabel({ Text = "Rotation Status  |  Off" })

--// ── SEKSI 11 · PRIORITY ────────────────────────────────────────────────────
tab:AddSection({ Name = "Priority" })

Status.prioqueue = tab:AddLabel({ Text = "Task Queue  |  Idle" })

Board = tab:AddCanvas({
    Name = "Statistik Farm",
    Widgets = {
        { Type = "Text", Name = "money",  Text = "Uang",        Value = "$0" },
        { Type = "Text", Name = "speed",  Text = "Speed Power", Value = "0" },
        { Type = "Divider" },
        { Type = "Text", Name = "bag",    Text = "Telur di Tas",     Value = "0" },
        { Type = "Text", Name = "placed", Text = "Telur Terpasang",  Value = "0" },
        { Type = "Text", Name = "pets",   Text = "Total Pet",        Value = "0" },
        { Type = "Text", Name = "base",   Text = "Level Base",       Value = "Lv 0" },
    },
})

--// ── SEKSI SISTEM (utilitas ThorHub — bukan bagian menu asli) ────────────────
tab:AddSection({ Name = "Sistem" })

local tglAntiAFK = tab:AddToggle({
    Name = "Anti AFK",
    Description = "Cegah kick karena idle.",
    Default = false,
    Callback = function(v) setAntiAFK(v) onTuned() end,
})
Store.track("sys.antiAFK", reg(tglAntiAFK))

local tglAutoSave = tab:AddToggle({
    Name = "Auto Simpan Konfigurasi",
    Description = "Simpan otomatis setiap pengaturan diubah.",
    Default = true,
    Callback = function(v) Store.enabled = v onTuned() end,
})
Store.track("sys.autoSave", tglAutoSave)

tab:AddButton({
    Name = "Simpan Konfigurasi",
    Description = "Simpan semua pengaturan ke file sekarang.",
    Callback = function()
        Store.save()
        UI.toast("📂 Konfigurasi", "Pengaturan disimpan.", 3)
    end,
})

tab:AddButton({
    Name = "Muat Konfigurasi",
    Description = "Baca ulang file konfigurasi tersimpan.",
    Callback = function()
        if Store.load() then
            UI.toast("📂 Konfigurasi", "Pengaturan berhasil dimuat.", 3)
        else
            UI.toast("📂 Konfigurasi", "Belum ada file konfigurasi.", 3)
        end
    end,
})

tab:AddButton({
    Name = "Reset Konfigurasi",
    Description = "Hapus file konfigurasi dari perangkat.",
    ConfirmText = "Yakin hapus file?",
    Callback = function()
        Store.wipe()
        UI.toast("🗑️ Konfigurasi", "File konfigurasi dihapus.", 3)
    end,
})

tab:AddButton({
    Name = "Teleport Base",
    Description = "Langsung pindah ke petak base sendiri.",
    Callback = function() teleportBase() end,
})

tab:AddButton({
    Name = "Curi Satu Telur Sekarang",
    Description = "Satu siklus curi-antar tanpa menyalakan Auto Steal.",
    Callback = function() Heist.stealOnce() end,
})

tab:AddButton({
    Name = "Matikan Semua Toggle",
    Description = "Sakelar darurat: semua fitur auto dimatikan sekaligus.",
    ConfirmText = "Matikan semuanya?",
    Callback = function()
        for _, el in ipairs(killList) do
            safe(function() el:Set(false) end)
        end
        UI.toast("🛑 ThorHub", "Semua toggle dimatikan.", 4)
    end,
})

tab:AddParagraph({
    Title = "ThorHub Farm v" .. THORHUB_VERSION,
    Text = "Rewrite TAB FARM lengkap game Steal an Egg — 11 seksi persis menu kode baru: "
        .. "Auto Steal, Auto Progression, Auto Mutation, Auto Place Egg, Auto Treadmill, "
        .. "Auto Hatch & Equip, Auto Sell, Auto Fuse Machine, Auto Favorite, Priority Rotation, Priority.\n"
        .. "UI dibangun oleh ThorUi (github.com/dwisetyabudi15581/ThorUi).",
})

tab:AddLabel({ Text = "Library UI : ThorUi v" .. tostring(ThorUi.Version) })
tab:AddLabel({ Text = "Toggle UI   : tekan RightControl (PC) / ketuk logo palu (Mobile)" })
tab:AddLabel({ Text = "Repositori : github.com/dwisetyabudi15581/StealAnEgg" })

--// ── isi daftar spesies saat katalog game telat termuat ──────────────────────
-- AddValue menolak duplikat sendiri, jadi pengisian ulang selalu aman.
task.spawn(function()
    local waited = 0
    while not Atlas.dir and waited < 30 do
        task.wait(2)
        waited = waited + 2
    end
    if Atlas.dir then
        safe(function()
            for _, name in ipairs(Atlas.petSpecies()) do
                ddPetBlack:AddValue(name)
                ddFuseSpecies:AddValue(name)
                ddFavSpecies:AddValue(name)
            end
            for _, name in ipairs(Atlas.eggSpecies()) do
                ddEggBlack:AddValue(name)
                ddStealEgg:AddValue(name)
                ddPlaceEgg:AddValue(name)
                ddHatchEgg:AddValue(name)
                ddMutTarget:AddValue(name)
            end
        end)
    end
    -- isi ulang nama area (peta bisa telat termuat)
    local names = areaNameList()
    if #names > 0 and names[1] ~= "All" then
        safe(function()
            for _, name in ipairs(names) do
                ddAreas:AddValue(name)
            end
        end)
    end
end)

--═══════════════════════════════════════════════════════════════════════════════
--  BAGIAN 8 · BOOT — muat konfigurasi lalu sinyal siap
--═══════════════════════════════════════════════════════════════════════════════
local restored = Store.load()
if restored then
    UI.toast("📂 Konfigurasi", "Pengaturan tersimpan berhasil dimuat.", 3)
end

-- v5.1: aktifkan Steal Panel sesuai toggle (default ON saat pertama kali,
-- atau sesuai konfigurasi tersimpan yang barusan di-restore lewat callback)
safe(function() StealPanel.Enable(StealPanel.Wanted()) end)

print("[ThorHub] ⚡ Farm v" .. THORHUB_VERSION .. " siap! (11 seksi tab Farm + Steal Panel)")
print("[ThorHub] Library ThorUi v" .. tostring(ThorUi.Version))
print("[ThorHub] Replika data : " .. (Vault.bound and "TERIKAT" or "belum ketemu (menunggu game)"))
print("[ThorHub] Katalog aset : " .. (Atlas.dir and "TERIKAT" or "belum ketemu (nilai telur = 0)"))
print("[ThorHub] Remote game  : " .. (Net.ready() and "OK" or "GAGAL"))
UI.toast("⚡ ThorHub siap!", "Farm v" .. THORHUB_VERSION .. " — 11 seksi + Steal Panel + Anti Guard.", 6)
