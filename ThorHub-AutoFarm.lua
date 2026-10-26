--═══════════════════════════════════════════════════════════════════════════════
--  ⚡ THORHUB — AUTO FARM · Steal an Egg
--  ──────────────────────────────────────────────────────────────────────────────
--  Versi      : 4.0  (rewrite segar — khusus Auto Farm, ditulis dari nol)
--  Library UI : ThorUi  (github.com/dwisetyabudi15581/ThorUi)
--  Platform   : PC & Mobile (drag bebas, keybind RightControl)
--
--  CARA PAKAI (executor):
--    loadstring(game:HttpGet("https://raw.githubusercontent.com/dwisetyabudi15581/StealAnEgg/main/ThorHub-AutoFarm.lua"))()
--
--  ISI FITUR (Auto Farm saja):
--    • Auto Tempatkan Telur   — telur terbaik dari tas dipindah ke petak base
--    • Auto Tetaskan Telur    — AskHatch + AskFinishHatch begitu telur siap
--    • Auto Jual Pet / Telur  — aturan batas rarity, nilai minimal, mutasi
--    • Auto Pakai Pet Terbaik — WearBest berkala
--    • Auto Klaim Cash Offline & Reward Index (Codex)
--    • Auto Upgrade Base & Treadmill saat uang cukup
--    • Statistik live, Teleport Base, Anti AFK, Simpan Konfigurasi
--═══════════════════════════════════════════════════════════════════════════════

local THORHUB_VERSION = "4.0"
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
    tglPlace, tglHatch, tglSellPet, tglSellEgg,
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
    Text = "Rewrite segar khusus Auto Farm untuk game Steal an Egg.\n"
        .. "Mesin farm: tempatkan-tetaskan-jual-klaim-upgrade berjalan sebagai loop mandiri dengan jeda masing-masing.\n"
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
UI.toast("⚡ ThorHub siap!", "Auto Farm v" .. THORHUB_VERSION .. " dimuat — aktifkan fitur di tab Peternakan.", 6)
