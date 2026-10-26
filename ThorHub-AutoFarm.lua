--═══════════════════════════════════════════════════════════════════════════════
--  ⚡ THORHUB — AUTO FARM · Steal an Egg
--  ──────────────────────────────────────────────────────────────────────────────
--  Versi      : 4.1  (rewrite segar — Auto Farm + Auto Steal, ditulis dari nol)
--  Library UI : ThorUi  (github.com/dwisetyabudi15581/ThorUi)
--  Platform   : PC & Mobile (drag bebas, keybind RightControl)
--
--  CARA PAKAI (executor):
--    loadstring(game:HttpGet("https://raw.githubusercontent.com/dwisetyabudi15581/StealAnEgg/main/ThorHub-AutoFarm.lua"))()
--
--  ISI FITUR (tab Farm kode baru):
--    • AUTO STEAL — curi telur area & telur base pemain lain, antar pulang
--      otomatis. Delivery: Tween / Instant Steps / Fast Tween (3000-4500
--      studs/dtk), prioritas value/rarity/weight, filter area & spesies,
--      min rarity & value, missing-index, drop di Safe Zone, anti-guard
--      panel, wrong-egg handler, guard-aware (menunggu guard tidur).
--    • Auto Tempatkan Telur   — telur terbaik dari tas dipindah ke petak base
--    • Auto Tetaskan Telur    — AskHatch + AskFinishHatch begitu telur siap
--    • Auto Jual Pet / Telur  — aturan batas rarity, nilai minimal, mutasi
--    • Auto Pakai Pet Terbaik — WearBest berkala
--    • Auto Klaim Cash Offline & Reward Index (Codex)
--    • Auto Upgrade Base & Treadmill saat uang cukup
--    • Statistik live, Teleport Base, Anti AFK, Simpan Konfigurasi
--═══════════════════════════════════════════════════════════════════════════════

local THORHUB_VERSION = "4.1"
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

--═══════════════════════════════════════════════════════════════════════════════
--  BAGIAN 3 · ATLAS — katalog aset game (rarity, earning rate, nilai telur)
--  Direktori aset di-require dari ModuleScript katalog game, lalu dipakai
--  untuk menghitung rarity (Common..Divine) dan nilai $/detik tiap telur.
--═══════════════════════════════════════════════════════════════════════════════
local Atlas = { dir = nil, mut = nil }
do
    local function tryRequire(...)
        local inst = ReplicatedStorage
        for _, seg in ipairs({ ... }) do
            if not inst then return nil end
            inst = safe(function() return inst:WaitForChild(seg, 3) end)
        end
        if inst and inst:IsA("ModuleScript") then
            return safe(require, inst)
        end
        return nil
    end

    for _, path in ipairs({
        { "Shared", "Util", "AssetItems" },
        { "Data", "Assets" },
        { "AssetItems" },
        { "Assets" },
    }) do
        local mod = tryRequire(table.unpack(path))
        if type(mod) == "table" then
            local d = (type(mod.Assets) == "table" and mod.Assets.Directory) or mod.Directory
            if type(d) == "table" then
                for _, v in pairs(d) do
                    if type(v) == "table" and type(v.Rarity) == "table" then
                        Atlas.dir = d
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
    --// snapshot non-blocking: invoke jalan di task terpisah, hasil di-cache
    local snap, snapAt, snapBusy, snapFails = nil, -math.huge, false, 0
    function Prey.snapshot(maxAge)
        local now = os.clock()
        if snap and (now - snapAt) < (maxAge or 2) then return snap end
        if snapBusy then return snap end
        if snapFails >= 5 and snap and (now - snapAt) < 15 then return snap end
        snapBusy = true
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
--  BAGIAN 5 · ENGINE — mesin Auto Farm
--  Setiap fitur = loop terpisah dengan interval sendiri; semua loop berhenti
--  otomatis bila script di-execute ulang (generator versi via _G).
--═══════════════════════════════════════════════════════════════════════════════
local UI = { ThorUi = nil }
function UI.toast() end -- stub; diganti setelah ThorUi termuat

local Farm = {
    place   = { on = false, order = "Nilai Tertinggi", minRarity = "Common", minValue = 0, done = 0 },
    hatch   = { on = false, minRarity = "Common", minValue = 0, cooldown = {}, done = 0 },
    sell    = {
        petOn = false, eggOn = false,
        petMax = "Rare", eggMax = "Uncommon",
        keepMutPet = true, keepMutEgg = true,
        minValue = 0,
        petBlack = {}, eggBlack = {},
    },
    claim   = { offline = false, index = false },
    growth  = { base = false, treadmill = false, wearBest = false },
    antiAFK = false,
}

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

local Board = nil -- canvas statistik (diisi saat UI dibangun)
local StealBoard = nil -- canvas statistik curi (diisi saat UI dibangun)

--// ── pemilih telur untuk Auto Place ───────────────────────────────────────────
local function pickPlaceEgg()
    local best, bestKey = nil, -math.huge
    for uid, e in pairs(Vault.bagEggs()) do
        local _, num = Atlas.rarity(e.category)
        local value = Atlas.value(e.category, e.scale, e.mutations)
        if num < rarNum(Farm.place.minRarity) or value < Farm.place.minValue then
            -- di bawah syarat minimum: lewati
        else
            local key
            if Farm.place.order == "Ukuran Terbesar" then
                key = e.scale
            elseif Farm.place.order == "Ukuran Terkecil" then
                key = -e.scale
            else
                key = value
            end
            if key > bestKey then
                best, bestKey = uid, key
            end
        end
    end
    return best
end

--// ── penyusun daftar jual ────────────────────────────────────────────────────
local function buildSellList(entries, maxRarity, keepMut, blacklist)
    local out = {}
    for uid, e in pairs(entries) do
        local _, num = Atlas.rarity(e.category)
        if keepMut and #e.mutations > 0 then
            -- bermutasi: dipertahankan
        elseif blacklist[e.category] then
            -- masuk daftar hitam: dipertahankan
        elseif num < rarNum(maxRarity)
            and Atlas.value(e.category, e.scale, e.mutations) >= Farm.sell.minValue then
            table.insert(out, uid)
        end
    end
    return out
end

--// ── tabel data base (untuk cek biaya upgrade) ───────────────────────────────
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

--// ── loop 1: AUTO PLACE (tiap 2.5 detik) ─────────────────────────────────────
Engine.every(2.5, function()
    if not Farm.place.on then return end
    if Heist.busy or Heist.carrying then return end -- Auto Steal punya prioritas gerak
    if not needVault() then return end
    local uid = pickPlaceEgg()
    if not uid then return end
    local anchor = Home.anchor()
    if not anchor then return end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root and (root.Position - anchor).Magnitude > 60 then
        safe(function() char:PivotTo(CFrame.new(anchor + Vector3.new(0, 8, 0))) end)
        task.wait(0.25)
    end
    if Net.invoke("RF/EggWorld/AskPlaceEgg", uid) then
        Farm.place.done = Farm.place.done + 1
    end
end)

--// ── loop 2: AUTO HATCH (tiap 2 detik) ───────────────────────────────────────
Engine.every(2.0, function()
    if not Farm.hatch.on then return end
    if not needVault() then return end
    local attempts = 0
    for uid, e in pairs(Vault.placedEggs()) do
        if attempts >= 4 then break end
        local _, num = Atlas.rarity(e.category)
        local value = Atlas.value(e.category, e.scale, e.mutations)
        if num < rarNum(Farm.hatch.minRarity) or value < Farm.hatch.minValue then
            -- tidak lolos syarat
        elseif (Farm.hatch.cooldown[uid] or 0) > os.clock() then
            -- masih dalam jeda percobaan
        else
            attempts = attempts + 1
            Farm.hatch.cooldown[uid] = os.clock() + 25
            local ok = Net.invoke("RF/EggWorld/AskHatch", uid)
            if ok ~= nil and ok ~= false then
                task.wait(0.35)
                Net.invoke("RF/EggWorld/AskFinishHatch", uid)
                Farm.hatch.done = Farm.hatch.done + 1
            end
        end
    end
end)

--// ── loop 3: AUTO SELL (tiap 5 detik) ────────────────────────────────────────
Engine.every(5.0, function()
    if not (Farm.sell.petOn or Farm.sell.eggOn) then return end
    if not needVault() then return end
    local pets = Farm.sell.petOn
        and buildSellList(Vault.pets(), Farm.sell.petMax, Farm.sell.keepMutPet, Farm.sell.petBlack)
        or {}
    local eggs = Farm.sell.eggOn
        and buildSellList(Vault.bagEggs(), Farm.sell.eggMax, Farm.sell.keepMutEgg, Farm.sell.eggBlack)
        or {}
    if #pets > 0 then Net.fire("RE/PetSatchel/SellSelection", pets) end
    if #eggs > 0 then Net.fire("RE/PetSatchel/SellSelection", eggs) end
    if (#pets + #eggs) > 0 then
        UI.toast("💰 Auto Jual", string.format("Menjual %d pet & %d telur", #pets, #eggs), 3)
    end
end)

--// ── loop 4: AUTO WEAR BEST (tiap 10 detik) ───────────────────────────────────
Engine.every(10.0, function()
    if not Farm.growth.wearBest then return end
    Net.invoke("RF/Haul/WearBest")
    Net.invoke("RF/Haul/FetchWearBestStatus")
end)

--// ── loop 5: AUTO KLAIM CASH OFFLINE (tiap 15 detik) ──────────────────────────
Engine.every(15.0, function()
    if not Farm.claim.offline then return end
    local pending = Net.invoke("RF/AwayEarnings/PendingCheck")
    local amount = nil
    if type(pending) == "number" then
        amount = pending
    elseif type(pending) == "table" then
        amount = tonumber(pending.amount or pending.Amount)
    end
    if amount and amount > 0 then
        Net.invoke("RF/AwayEarnings/AskCollect")
        UI.toast("💵 Klaim Cash", "Cash offline $" .. fmtNum(amount) .. " berhasil diklaim!", 4)
    end
end)

--// ── loop 6: AUTO KLAIM REWARD INDEX (tiap 25 detik) ─────────────────────────
Engine.every(25.0, function()
    if not Farm.claim.index then return end
    Net.invoke("RF/Codex/AskRedeemAll")
    task.wait(0.2)
    Net.invoke("RF/Codex/AskRedeemLimitedEgg")
end)

--// ── loop 7: AUTO UPGRADE BASE (tiap 5 detik) ────────────────────────────────
Engine.every(5.0, function()
    if not Farm.growth.base then return end
    if not needVault() then return end
    local bases = basesData()
    if not bases then return end
    local level = Vault.baseLevel()
    local nxt = bases[level + 1]
    if not nxt and type(bases.GetByLevel) == "function" then
        nxt = safe(bases.GetByLevel, level + 1)
    end
    local cost = nxt and tonumber(nxt.Cost)
    if cost and Vault.money() >= cost then
        if Net.fire("RE/Homestead/AskBaseTierRaise") then
            UI.toast("🏠 Upgrade Base", "Base dinaikkan ke level " .. tostring(level + 1) .. "!", 4)
        end
    end
end)

--// ── loop 8: AUTO UPGRADE TREADMILL (tiap 5 detik) ───────────────────────────
Engine.every(5.0, function()
    if not Farm.growth.treadmill then return end
    Net.invoke("RF/Treadmill/AskTierRaise")
end)

--// ── loop 9: STATISTIK (tiap 1 detik) ────────────────────────────────────────
Engine.every(1.0, function()
    if not Board then return end
    local bagN, placedN, petN = 0, 0, 0
    if Vault.bound then
        for _ in pairs(Vault.bagEggs()) do bagN = bagN + 1 end
        for _ in pairs(Vault.placedEggs()) do placedN = placedN + 1 end
        for _ in pairs(Vault.pets()) do petN = petN + 1 end
    end
    safe(function()
        Board:Set("money",  { Value = "$" .. fmtNum(Vault.money()) })
        Board:Set("speed",  { Value = fmtNum(Vault.speedPower()) })
        Board:Set("bag",    { Value = tostring(bagN) })
        Board:Set("placed", { Value = tostring(placedN) })
        Board:Set("pets",   { Value = tostring(petN) })
        Board:Set("base",   { Value = "Lv " .. tostring(Vault.baseLevel()) })
    end)
    if StealBoard then
        safe(function()
            StealBoard:Set("stolen",     { Value = tostring(Heist.stolen) })
            StealBoard:Set("delivered",  { Value = tostring(Heist.delivered) })
            StealBoard:Set("carry",      { Value = Heist.carrying and "Membawa telur" or "Kosong" })
            -- hitung target hanya saat Auto Steal aktif (hemat invoke snapshot)
            StealBoard:Set("targets",    { Value = (Heist.on or Heist.busy)
                and tostring(#Prey.all()) or "-" })
            StealBoard:Set("stealstate", { Value = Heist.on and Heist.state or "Off" })
            StealBoard:Set("best",       { Value = Heist.best or "-" })
        end)
    end
end)

--// ── aksi manual (dipakai tombol UI) ─────────────────────────────────────────
local function placeAllNow()
    task.spawn(function()
        if not needVault() then return end
        local bag = Vault.bagEggs()
        local total = 0
        for _ in pairs(bag) do total = total + 1 end
        if total == 0 then
            UI.toast("🥚 Tempatkan", "Tidak ada telur di tas.", 4)
            return
        end
        local anchor = Home.anchor()
        if not anchor then
            UI.toast("🥚 Tempatkan", "Petak base belum ditemukan.", 4)
            return
        end
        local char = LocalPlayer.Character
        if char then
            safe(function() char:PivotTo(CFrame.new(anchor + Vector3.new(0, 8, 0))) end)
        end
        task.wait(0.3)
        local done = 0
        for uid in pairs(bag) do
            if Net.invoke("RF/EggWorld/AskPlaceEgg", uid) then
                done = done + 1
            end
            task.wait(0.35)
        end
        UI.toast("🥚 Tempatkan", string.format("Berhasil menempatkan %d/%d telur.", done, total), 5)
    end)
end

local function hatchAllNow()
    task.spawn(function()
        if not needVault() then return end
        local placed = Vault.placedEggs()
        local total, done = 0, 0
        for _ in pairs(placed) do total = total + 1 end
        if total == 0 then
            UI.toast("🐣 Penetasan", "Belum ada telur terpasang.", 4)
            return
        end
        for uid in pairs(placed) do
            local ok = Net.invoke("RF/EggWorld/AskHatch", uid)
            if ok ~= nil and ok ~= false then
                task.wait(0.35)
                Net.invoke("RF/EggWorld/AskFinishHatch", uid)
                done = done + 1
            end
            task.wait(0.25)
        end
        UI.toast("🐣 Penetasan", string.format("Menetaskan %d/%d telur (sisanya belum siap).", done, total), 5)
    end)
end

local function sellNow()
    task.spawn(function()
        if not needVault() then return end
        local pets = buildSellList(Vault.pets(), Farm.sell.petMax, Farm.sell.keepMutPet, Farm.sell.petBlack)
        local eggs = buildSellList(Vault.bagEggs(), Farm.sell.eggMax, Farm.sell.keepMutEgg, Farm.sell.eggBlack)
        if #pets > 0 then Net.fire("RE/PetSatchel/SellSelection", pets) end
        if #eggs > 0 then Net.fire("RE/PetSatchel/SellSelection", eggs) end
        UI.toast("💰 Jual Sekarang", string.format("Menjual %d pet & %d telur.", #pets, #eggs), 5)
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
    Farm.antiAFK = on
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
local Heist = {
    on = false,
    delivery = "Tween",           -- Tween | Instant Steps | Fast Tween
    speedPct = 100,               -- Delivery Speed 80-110% (mode Tween)
    steps = 3,                    -- Step Count 1-6 (mode Instant Steps)
    fastSpeed = 3300,             -- Fast Tween Speed 3000-4500 studs/dtk
    priority = "Highest Value",   -- Highest Value | Best Rarity | Biggest Weight | Lowest Value
    minRarity = "Any", minValue = 0,
    areas = {}, specific = {},
    missingIndex = false, dropSafe = false, agPanel = true,
    busy = false, carrying = false, carriedUid = nil, seenAt = 0,
    bad = {}, blocked = {},
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
-- pembawanya) -> model GUID-32 weld ke karakter -> Tool bernama uid.
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
        local isEgg = safe(function() return m:IsA("Model") and #m.Name == 32 end)
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
            if welded then return tostring(m.Name) end
        end
    end
    for _, t in ipairs(char:GetChildren()) do
        if safe(function() return t:IsA("Tool") end) then
            local nm = tostring(t.Name)
            local au = safe(function() return t:GetAttribute("Uid") end)
            if #nm == 32 then return nm end
            if type(au) == "string" and #au >= 8 then return au end
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

-- guard berjaga dekat posisi (radius 35 stud) sedang aktif?
local function guardAwakeNear(pos)
    local list = guardSnapshot()
    if type(list) ~= "table" or not pos then return nil end
    for _, inst in ipairs(list) do
        local gs = safe(function() return inst:GetAttribute("GuardState") end)
        if type(gs) == "string" and gs ~= "Sleeping" then
            local gp = safe(function()
                if inst:IsA("BasePart") then return inst.Position end
                if inst:IsA("Model") then return inst:GetPivot().Position end
            end)
            if gp and (gp - pos).Magnitude < 35 then
                return gs
            end
        end
    end
    return nil
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
    if p == "Lowest Value" then return -egg.value end
    return egg.value -- Highest Value (default)
end

local function pickTarget()
    local now = os.clock()
    local best, bestScore = nil, -math.huge
    for _, egg in ipairs(Prey.all()) do
        if (Heist.bad[egg.key] or 0) > now then
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
        -- cek Wrong Egg: telur lain nyasar ke tangan?
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
    elseif res == "gone" or res == "taken" then
        Heist.bad[egg.key] = os.clock() + 8
        Heist.state = "Target diambil orang lain — pilih target lain"
    else
        Heist.bad[egg.key] = os.clock() + 20
        Heist.state = "Telur tidak sampai ke tangan — pindah target"
    end
end

--// dispatcher: antar yang sedang dibawa ATAU cari target baru
Engine.every(0.4, function()
    if not Heist.on then return end
    if Heist.busy then return end
    if Heist.carrying then
        Heist.busy = true
        task.spawn(function()
            deliverEgg({ name = "?", uid = Heist.carriedUid, key = "F:" .. tostring(Heist.carriedUid) })
            Heist.busy = false
        end)
        return
    end
    local target = pickTarget()
    if target then
        Heist.busy = true
        task.spawn(function()
            stealOne(target)
            Heist.busy = false
        end)
    else
        local total = #Prey.all()
        if total == 0 then
            Heist.state = "Idle  |  belum ada telur terlihat"
        else
            Heist.state = "Idle  |  " .. total .. " telur terlihat, semua tercegat filter"
        end
    end
end)

--// aksi manual: curi satu kali sekarang (dipakai tombol UI)
function Heist.stealOnce()
    if Heist.busy then
        UI.toast("🥷 Auto Steal", "Mesin masih sibuk — tunggu sebentar.", 3)
        return
    end
    if Heist.carrying then
        UI.toast("🥷 Auto Steal", "Kamu sedang membawa telur — diantar dulu.", 3)
        Heist.busy = true
        task.spawn(function()
            deliverEgg({ name = "?", uid = Heist.carriedUid })
            Heist.busy = false
        end)
        return
    end
    local target = pickTarget()
    if not target then
        UI.toast("🥷 Auto Steal", "Tidak ada target yang lolos filter.", 4)
        return
    end
    Heist.busy = true
    task.spawn(function()
        stealOne(target)
        Heist.busy = false
    end)
end

--// chip anti-guard kanan-bawah (status guard sekitar) saat Auto Steal aktif
local GuardHud = { gui = nil }
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
            chip.Size = UDim2.new(0, 190, 0, 30)
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
            lbl.Text = "GUARD  |  memeriksa"
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
        local stateTxt
        if not root then
            stateTxt = "GUARD  |  karakter belum siap"
        else
            local awake = guardAwakeNear(root.Position)
            if awake then
                stateTxt = "GUARD  |  AKTIF di dekatmu!"
            elseif Heist.busy then
                stateTxt = "GUARD  |  aman — sedang bekerja"
            else
                stateTxt = "GUARD  |  aman"
            end
        end
        lbl.Text = stateTxt
    end)
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
--  BAGIAN 7 · THORUI — muat library dari GitHub lalu bangun UI ThorHub
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
    Title = "ThorHub ⚡ Auto Farm",
    Keybind = Enum.KeyCode.RightControl,
    Splash = true,
})
_G.__THORHUB_FARM_WINDOW = Window
_G.__THORHUB_FARM_UI = ThorUi

--// ─── TAB 1: PETERNAKAN ──────────────────────────────────────────────────────
local tab = Window:CreateTab({ Name = "Peternakan", Icon = "🥚" })

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

--// ── AUTO CURI TELUR (AUTO STEAL — tab Farm kode baru) ───────────────────────
tab:AddSection({ Name = "AUTO CURI TELUR (STEAL)", Collapsed = false })

local tglSteal = tab:AddToggle({
    Name = "Auto Steal",
    Description = "Curi telur area & telur base pemain lain, lalu antar pulang otomatis.",
    Default = false,
    Callback = function(v) Heist.on = v onTuned() end,
})
Store.track("steal.on", tglSteal)

local ddDelivery = tab:AddDropdown({
    Name = "Delivery (Mode Antar)",
    Values = { "Tween", "Instant Steps", "Fast Tween" },
    Default = "Tween",
    Description = "Tween: antar halus. Instant Steps: lompat bertahap. Fast Tween: tarik 3000-4500 studs/dtk.",
    Depends = { Element = tglSteal, Value = true },
    Callback = function(v) Heist.delivery = v onTuned() end,
})
Store.track("steal.delivery", ddDelivery)

local slSpeed = tab:AddSlider({
    Name = "Delivery Speed (Tween)",
    Min = 80, Max = 110, Default = 100, Increment = 1,
    Depends = { Element = ddDelivery, Value = "Tween" },
    Callback = function(v) Heist.speedPct = v onTuned() end,
})
Store.track("steal.speedPct", slSpeed)

local slSteps = tab:AddSlider({
    Name = "Step Count (Instant Steps)",
    Min = 1, Max = 6, Default = 3, Increment = 1,
    Depends = { Element = ddDelivery, Value = "Instant Steps" },
    Callback = function(v) Heist.steps = v onTuned() end,
})
Store.track("steal.steps", slSteps)

local slFast = tab:AddSlider({
    Name = "Fast Tween Speed (studs/dtk)",
    Min = 3000, Max = 4500, Default = 3300, Increment = 50,
    Depends = { Element = ddDelivery, Value = "Fast Tween" },
    Callback = function(v) Heist.fastSpeed = v onTuned() end,
})
Store.track("steal.fastSpeed", slFast)

local ddPrio = tab:AddDropdown({
    Name = "Steal Priority",
    Values = { "Highest Value", "Best Rarity", "Biggest Weight", "Lowest Value" },
    Default = "Highest Value",
    Depends = { Element = tglSteal, Value = true },
    Callback = function(v) Heist.priority = v onTuned() end,
})
Store.track("steal.priority", ddPrio)

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
    Name = "Min Steal Value ($/detik)",
    Min = 0, Max = 100000, Default = 0, Increment = 250,
    Depends = { Element = tglSteal, Value = true },
    Callback = function(v) Heist.minValue = v onTuned() end,
})
Store.track("steal.minValue", slStealVal)

local ddAreas = tab:AddDropdown({
    Name = "Target Areas",
    Values = areaNameList(),
    Multi = true, Search = true,
    Description = "Kosong = semua area. Telur base pemain lain selalu dikejar.",
    Depends = { Element = tglSteal, Value = true },
    Callback = function(list)
        Heist.areas = {}
        for _, name in ipairs(list or {}) do
            Heist.areas[name] = true
        end
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
        Heist.specific = {}
        for _, name in ipairs(list or {}) do
            Heist.specific[name] = true
        end
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
    Description = "Chip status guard di kanan-bawah saat Auto Steal aktif.",
    Default = true,
    Depends = { Element = tglSteal, Value = true },
    Callback = function(v) Heist.agPanel = v onTuned() end,
})
Store.track("steal.agPanel", tglAgPanel)

tab:AddButton({
    Name = "Curi Satu Telur Sekarang",
    Description = "Satu siklus curi-antar tanpa menyalakan Auto Steal.",
    Callback = function() Heist.stealOnce() end,
})

StealBoard = tab:AddCanvas({
    Name = "Hasil Pencurian",
    Widgets = {
        { Type = "Text", Name = "stolen",     Text = "Total Dicuri",     Value = "0" },
        { Type = "Text", Name = "delivered",  Text = "Tersampaikan",     Value = "0" },
        { Type = "Text", Name = "carry",      Text = "Tangan",           Value = "Kosong" },
        { Type = "Text", Name = "targets",    Text = "Target Terlihat",  Value = "0" },
        { Type = "Divider" },
        { Type = "Text", Name = "stealstate", Text = "Status Mesin",    Value = "Off" },
        { Type = "Text", Name = "best",       Text = "Curian Terbaik",  Value = "-" },
    },
})

tab:AddSection({ Name = "PENEMPATAN & PENETASAN", Collapsed = false })

local tglPlace = tab:AddToggle({
    Name = "Auto Tempatkan Telur",
    Description = "Pindahkan telur terbaik dari tas ke petak base secara otomatis.",
    Default = false,
    Callback = function(v) Farm.place.on = v onTuned() end,
})
Store.track("place.on", tglPlace)

local ddOrder = tab:AddDropdown({
    Name = "Prioritas Penempatan",
    Values = { "Nilai Tertinggi", "Ukuran Terbesar", "Ukuran Terkecil" },
    Default = "Nilai Tertinggi",
    Depends = { Element = tglPlace, Value = true },
    Callback = function(v) Farm.place.order = v onTuned() end,
})
Store.track("place.order", ddOrder)

local ddPlaceRar = tab:AddDropdown({
    Name = "Rarity Minimal",
    Values = RARITY_LIST,
    Default = "Common",
    Depends = { Element = tglPlace, Value = true },
    Callback = function(v) Farm.place.minRarity = v onTuned() end,
})
Store.track("place.minRarity", ddPlaceRar)

local slPlaceVal = tab:AddSlider({
    Name = "Nilai Minimal ($/detik)",
    Min = 0, Max = 100000, Default = 0, Increment = 250,
    Depends = { Element = tglPlace, Value = true },
    Callback = function(v) Farm.place.minValue = v onTuned() end,
})
Store.track("place.minValue", slPlaceVal)

local tglHatch = tab:AddToggle({
    Name = "Auto Tetaskan Telur",
    Description = "Tetaskan telur terpasang begitu siap (Hatch + Finish otomatis).",
    Default = false,
    Callback = function(v) Farm.hatch.on = v onTuned() end,
})
Store.track("hatch.on", tglHatch)

local ddHatchRar = tab:AddDropdown({
    Name = "Rarity Minimal (Tetaskan)",
    Values = RARITY_LIST,
    Default = "Common",
    Depends = { Element = tglHatch, Value = true },
    Callback = function(v) Farm.hatch.minRarity = v onTuned() end,
})
Store.track("hatch.minRarity", ddHatchRar)

local slHatchVal = tab:AddSlider({
    Name = "Nilai Minimal (Tetaskan)",
    Min = 0, Max = 100000, Default = 0, Increment = 250,
    Depends = { Element = tglHatch, Value = true },
    Callback = function(v) Farm.hatch.minValue = v onTuned() end,
})
Store.track("hatch.minValue", slHatchVal)

tab:AddButton({
    Name = "Tempatkan Semua Telur dari Tas",
    Description = "Antre seluruh telur di tas ke petak base (tanpa filter).",
    Callback = placeAllNow,
})

tab:AddButton({
    Name = "Tetaskan Semua Telur Siap",
    Description = "Coba tetaskan seluruh telur terpasang sekaligus.",
    Callback = hatchAllNow,
})

--// ── Penjualan ────────────────────────────────────────────────────────────────
tab:AddSection({ Name = "PENJUALAN OTOMATIS", Collapsed = false })

local tglSellPet = tab:AddToggle({
    Name = "Auto Jual Pet",
    Description = "Jual pet dengan rarity DI BAWAH batas; mutasi & daftar hitam dilindungi.",
    Default = false,
    Callback = function(v) Farm.sell.petOn = v onTuned() end,
})
Store.track("sell.petOn", tglSellPet)

local ddPetMax = tab:AddDropdown({
    Name = "Batas Rarity Pet",
    Values = RARITY_LIST,
    Default = "Rare",
    Description = "Pet dengan rarity di bawah ini yang dijual.",
    Depends = { Element = tglSellPet, Value = true },
    Callback = function(v) Farm.sell.petMax = v onTuned() end,
})
Store.track("sell.petMax", ddPetMax)

local tglKeepMutPet = tab:AddToggle({
    Name = "Simpan Pet Bermutasi",
    Default = true,
    Depends = { Element = tglSellPet, Value = true },
    Callback = function(v) Farm.sell.keepMutPet = v onTuned() end,
})
Store.track("sell.keepMutPet", tglKeepMutPet)

local ddPetBlack = tab:AddDropdown({
    Name = "Daftar Hitam Pet (jangan dijual)",
    Values = Atlas.petSpecies(),
    Multi = true, Search = true,
    Depends = { Element = tglSellPet, Value = true },
    Callback = function(list)
        Farm.sell.petBlack = {}
        for _, name in ipairs(list or {}) do
            Farm.sell.petBlack[name] = true
        end
        onTuned()
    end,
})
Store.track("sell.petBlack", ddPetBlack)

local tglSellEgg = tab:AddToggle({
    Name = "Auto Jual Telur di Tas",
    Description = "Jual telur cadangan di tas dengan aturan serupa.",
    Default = false,
    Callback = function(v) Farm.sell.eggOn = v onTuned() end,
})
Store.track("sell.eggOn", tglSellEgg)

local ddEggMax = tab:AddDropdown({
    Name = "Batas Rarity Telur",
    Values = RARITY_LIST,
    Default = "Uncommon",
    Description = "Telur dengan rarity di bawah ini yang dijual.",
    Depends = { Element = tglSellEgg, Value = true },
    Callback = function(v) Farm.sell.eggMax = v onTuned() end,
})
Store.track("sell.eggMax", ddEggMax)

local tglKeepMutEgg = tab:AddToggle({
    Name = "Simpan Telur Bermutasi",
    Default = true,
    Depends = { Element = tglSellEgg, Value = true },
    Callback = function(v) Farm.sell.keepMutEgg = v onTuned() end,
})
Store.track("sell.keepMutEgg", tglKeepMutEgg)

local ddEggBlack = tab:AddDropdown({
    Name = "Daftar Hitam Telur (jangan dijual)",
    Values = Atlas.eggSpecies(),
    Multi = true, Search = true,
    Depends = { Element = tglSellEgg, Value = true },
    Callback = function(list)
        Farm.sell.eggBlack = {}
        for _, name in ipairs(list or {}) do
            Farm.sell.eggBlack[name] = true
        end
        onTuned()
    end,
})
Store.track("sell.eggBlack", ddEggBlack)

local slSellVal = tab:AddSlider({
    Name = "Nilai Minimal Jual ($/detik)",
    Description = "Pet & telur bernilai di bawah ini tetap dijual; naikkan untuk hanya menjual yang jelek.",
    Min = 0, Max = 100000, Default = 0, Increment = 250,
    Callback = function(v) Farm.sell.minValue = v onTuned() end,
})
Store.track("sell.minValue", slSellVal)

tab:AddButton({
    Name = "Jual Semua Sekarang",
    Description = "Terapkan aturan jual sekali saja, seketika.",
    ConfirmText = "Yakin? Klik lagi!",
    Callback = sellNow,
})

--// ── Klaim & Peningkatan ──────────────────────────────────────────────────────
tab:AddSection({ Name = "KLAIM & PENINGKATAN", Collapsed = false })

local tglClaimOff = tab:AddToggle({
    Name = "Auto Klaim Cash Offline",
    Description = "Klaim AwayEarnings begitu ada saldo menunggu.",
    Default = false,
    Callback = function(v) Farm.claim.offline = v onTuned() end,
})
Store.track("claim.offline", tglClaimOff)

local tglClaimIdx = tab:AddToggle({
    Name = "Auto Klaim Reward Index",
    Description = "Tebus semua reward Codex + telur limited.",
    Default = false,
    Callback = function(v) Farm.claim.index = v onTuned() end,
})
Store.track("claim.index", tglClaimIdx)

local tglBase = tab:AddToggle({
    Name = "Auto Upgrade Base",
    Description = "Naikkan level base otomatis saat uang cukup.",
    Default = false,
    Callback = function(v) Farm.growth.base = v onTuned() end,
})
Store.track("growth.base", tglBase)

local tglTread = tab:AddToggle({
    Name = "Auto Upgrade Treadmill",
    Description = "Naikkan tier treadmill setiap 5 detik (server yang mengecek uang).",
    Default = false,
    Callback = function(v) Farm.growth.treadmill = v onTuned() end,
})
Store.track("growth.treadmill", tglTread)

local tglWear = tab:AddToggle({
    Name = "Auto Pakai Pet Terbaik",
    Description = "WearBest setiap 10 detik agar earnings maksimal.",
    Default = false,
    Callback = function(v) Farm.growth.wearBest = v onTuned() end,
})
Store.track("growth.wearBest", tglWear)

--// ── Statistik ────────────────────────────────────────────────────────────────
tab:AddSection({ Name = "STATISTIK LANGSUNG", Collapsed = false })

Board = tab:AddCanvas({
    Name = "Peternakan Saya",
    Widgets = {
        { Type = "Text", Name = "money",  Text = "Uang",            Value = "$0" },
        { Type = "Text", Name = "speed",  Text = "Speed Power",      Value = "0" },
        { Type = "Text", Name = "bag",    Text = "Telur di Tas",     Value = "0" },
        { Type = "Text", Name = "placed", Text = "Telur Terpasang", Value = "0" },
        { Type = "Text", Name = "pets",   Text = "Total Pet",        Value = "0" },
        { Type = "Divider" },
        { Type = "Text", Name = "base",   Text = "Level Base",      Value = "Lv 0" },
    },
})

--// ── Utilitas ─────────────────────────────────────────────────────────────────
tab:AddSection({ Name = "UTILITAS", Collapsed = false })

tab:AddButton({
    Name = "Teleport ke Base",
    Description = "Langsung muncul di tengah petak base.",
    Callback = teleportBase,
})

local tglAFK = tab:AddToggle({
    Name = "Anti AFK",
    Description = "Cegah kick otomatis saat farming sambil tidur.",
    Default = false,
    Callback = function(v) setAntiAFK(v) onTuned() end,
})
Store.track("antiafk", tglAFK)

--// ─── TAB 2: PENGATURAN ─────────────────────────────────────────────────────
local tabSet = Window:CreateTab({ Name = "Pengaturan", Icon = "⚙️" })

tabSet:AddSection({ Name = "KONFIGURASI", Collapsed = false })

local tglStore = tabSet:AddToggle({
    Name = "Simpan & Muat Otomatis",
    Description = "Semua pengaturan disimpan ke file dan dipulihkan saat script dijalankan lagi.",
    Default = false,
    Callback = function(v)
        Store.enabled = v
        if v then Store.queueSave() end
    end,
})
Store.track("store.enabled", tglStore)

local allToggles = {
    tglSteal, tglPlace, tglHatch, tglSellPet, tglSellEgg,
    tglClaimOff, tglClaimIdx, tglBase, tglTread, tglWear, tglAFK,
}

tabSet:AddButton({
    Name = "Simpan Sekarang",
    Description = "Tulis konfigurasi ke file seketika.",
    Callback = function()
        Store.save()
        UI.toast("💾 Konfigurasi", "Pengaturan berhasil disimpan.", 3)
    end,
})

tabSet:AddButton({
    Name = "Matikan Semua Fitur",
    Description = "Saklar darurat: semua auto langsung OFF.",
    ConfirmText = "Yakin matikan semua?",
    Callback = function()
        for _, elem in ipairs(allToggles) do
            safe(function() elem:Set(false) end)
        end
        UI.toast("🛑 ThorHub", "Semua fitur auto dimatikan.", 4)
    end,
})

tabSet:AddButton({
    Name = "Reset Konfigurasi",
    Description = "Hapus file konfigurasi dari perangkat.",
    ConfirmText = "Yakin hapus file?",
    Callback = function()
        Store.wipe()
        UI.toast("🗑️ Konfigurasi", "File konfigurasi dihapus.", 3)
    end,
})

tabSet:AddSection({ Name = "TENTANG", Collapsed = false })

tabSet:AddParagraph({
    Title = "ThorHub Auto Farm v" .. THORHUB_VERSION,
    Text = "Rewrite segar untuk game Steal an Egg — Auto Farm + Auto Steal.\n"
        .. "Auto Steal: curi telur area & base pemain lain (Delivery Tween / Instant Steps / Fast Tween), antar pulang + verifikasi verdict server.\n"
        .. "Mesin farm: tempatkan-tetaskan-jual-klaim-upgrade berjalan sebagai loop mandiri.\n"
        .. "UI dibangun oleh ThorUi (github.com/dwisetyabudi15581/ThorUi).",
})

tabSet:AddLabel({ Text = "Library UI : ThorUi v" .. tostring(ThorUi.Version) })
tabSet:AddLabel({ Text = "Toggle UI   : tekan RightControl (PC) / ketuk logo palu (Mobile)" })
tabSet:AddLabel({ Text = "Repositori : github.com/dwisetyabudi15581/StealAnEgg" })

--// ── isi daftar hitam spesies saat katalog game telat termuat ─────────────────
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
            end
            for _, name in ipairs(Atlas.eggSpecies()) do
                ddEggBlack:AddValue(name)
                ddStealEgg:AddValue(name)
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

print("[ThorHub] ⚡ Auto Farm v" .. THORHUB_VERSION .. " siap!")
print("[ThorHub] Library ThorUi v" .. tostring(ThorUi.Version))
print("[ThorHub] Replika data : " .. (Vault.bound and "TERIKAT" or "belum ketemu (menunggu game)"))
print("[ThorHub] Katalog aset : " .. (Atlas.dir and "TERIKAT" or "belum ketemu (nilai telur = 0)"))
print("[ThorHub] Remote game  : " .. (Net.ready() and "OK" or "GAGAL"))
print("[ThorHub] Auto Steal   : siap (snapshot RF + SmartPromptPart + verdict)")
UI.toast("⚡ ThorHub siap!", "Auto Farm v" .. THORHUB_VERSION .. " — Auto Steal kini tersedia di tab Peternakan.", 6)
