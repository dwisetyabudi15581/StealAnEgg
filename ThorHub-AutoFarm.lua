--[[ THORHUB - STEAL AN EGG | v3.3 (sync 1:1 dengan StealAnEggg — remote terverifikasi)
  Basis v3.2 + perbaikan sinkronisasi 1:1 ke mekanik script asli (Chilli/StealAnEggg):
  menu 8 tab 1:1 (Farm/Event/Admin Abuse/Player/Predictor/Server/Misc/Auto Hop),
  Steal Panel metode hijack HUD game, Delivery 3-mode, Instant Steal V3,
  ESP/Combat/Performance/Server, Auto Hop sync filter.
  v3.3 memulihkan remote & mekanik yang terverifikasi dari script asli:
  - serangan (bat/tool): RE/ToolTrigger/Trigger + RE/BatSwing/Trigger
  - Ghost Dog Quest: RF/GhostDogQuest/Talk/Dive/Cast/Collect/Claim/Surface
  - Ghouler vacuum: RE/GhostBoss/Suction; souls: RF/HalloweenDimension/AskTradeSouls
  - Island Wars: RF/IslandWars/Fetch + RE/IslandWars/Use/State/Moment
  - Capture The Egg: RE/EggCapture/StandingsRefreshed + scan egg event
  - Minigame Egg: scan model Minigame + StealPrompt (bukan atribut tebakan)
  - Egg/Rift Predictor: RF/LiveEvents/FetchRunning + RE/LiveEvents/Began/Ended
  - Fishing: RF/Fishing/Cast(luck) + Reel; claim cash: RF/AwayEarnings/PendingCheck
  - deteksi monster Halloween: nama asli (Candy Corn/Hollow Bat/Scarecrow/
    Chest Mimic/Pumpkin Golem/Soul Phantom) + cek Humanoid hidup
  - fix toggle mati: Steal Missing Halloween Index & Preview Card kini berfungsi
  - fix Anti Trap (kondisi selah false), hwplace kini place+hatch missing index
  Loader: loadstring(game:HttpGet("https://raw.githubusercontent.com/dwisetyabudi15581/StealAnEgg/main/ThorHub-Loader.lua"))()
]]

if not game:IsLoaded() then
game.Loaded:Wait()
end
local Gill = (getgenv and getgenv()) or _G
if Gill.__THORHUB_AF_LOADED then
local old = Gill.__THORHUB_AF_DESTROY
if type(old) == "function" then pcall(old) end
end
if type(print) == "function" then
print("[ThorHub] v3.3 dimuat (sync 1:1 — remote & mekanik terverifikasi StealAnEggg)")
end
local Services = {}
local function S(name)
if not Services[name] then
Services[name] = game:GetService(name)
end
return Services[name]
end
local Players = S("Players")
local ReplicatedStorage = S("ReplicatedStorage")
local TweenService = S("TweenService")
local RunService = S("RunService")
local UserInputService = S("UserInputService")
local HttpService = S("HttpService")
local TeleportService = S("TeleportService")
local Stats = S("Stats")
local Lighting = S("Lighting")
local StarterGui = S("StarterGui")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
repeat LocalPlayer = Players.LocalPlayer task.wait(0.05) until LocalPlayer
end
local PLACE_ID = game.PlaceId
local JOB_ID = game.JobId
local SOURCE_URL = "https://raw.githubusercontent.com/dwisetyabudi15581/StealAnEgg/main/ThorHub-AutoFarm.lua"
local THORUI_URL = "https://raw.githubusercontent.com/dwisetyabudi15581/ThorUi/main/ThorUi.lua"
local function P(fn, ...)
local a, b = pcall(fn, ...)
if a then return b end
return nil
end
local function round(n, d)
local m = 10 ^ (d or 0)
return math.floor(n * m + 0.5) / m
end
local function fmtNum(n)
n = tonumber(n) or 0
local abs = math.abs(n)
if abs >= 1e12 then return round(n / 1e12, 2) .. "T" end
if abs >= 1e9 then return round(n / 1e9, 2) .. "B" end
if abs >= 1e6 then return round(n / 1e6, 2) .. "M" end
if abs >= 1e3 then return round(n / 1e3, 1) .. "K" end
return tostring(math.floor(n + 0.5))
end
local function lower(s) return type(s) == "string" and string.lower(s) or "" end
local function mirrorUrl(url)
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
local Repo = { Directory = nil, DirectoryOK = false, Mut = nil, Save = nil,
SaveOK = false, SaveGet = nil, SaveWatch = nil }
do
local function resolveDirectoryFrom(mod)
if type(mod) ~= "table" then return nil end
local t = mod.Assets
if type(t) == "table" then
if type(t.Directory) == "table" then
return t.Directory
end
end
if type(t) == "table" then
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
do
local m = P(function()
return require(ReplicatedStorage:WaitForChild("Shared", 5):WaitForChild("Modules", 3):WaitForChild("Mutations", 3))
end)
if type(m) == "table" and type(m.EarningsFor) == "function" then
Repo.Mut = m
end
end
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
if looksLikeSave(mod) then
return function() return mod end
end
for _, name in ipairs({"state", "data", "State", "Data", "save", "Save", "profile", "Profile"}) do
if looksLikeSave(mod[name]) then
return function() return mod[name] end
end
end
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
function Repo.Leader(name)
local ls = LocalPlayer:FindFirstChild("leaderstats")
if not ls then return nil end
local v = ls:FindFirstChild(name)
if v then return tonumber(v.Value) end
return nil
end
function Repo.Money() return Repo.Leader("Money") or 0 end
function Repo.SpeedPower() return Repo.Leader("Speed") or 0 end
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
function Repo.World()
return workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
end
function Repo.Areas()
local w = Repo.World()
return w and w:FindFirstChild("Areas")
end
function Repo.WorldEggs()
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
end
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
do
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
local indexMiss, indexAt = nil, 0
function Repo.OwnedSpecies()
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
local save = Repo.SaveData()
if type(save) == "table" and type(save.Index) == "table" then
for sp in pairs(save.Index) do indexMiss[sp] = nil end
end
return indexMiss[name] == true
end
local snapCache, snapAt = nil, -math.huge
local snapPending, snapFailed = false, 0
function Repo.FieldSnapshot(maxAge, force)
local now = os.clock()
if not force and snapCache and now - snapAt < (maxAge or 2) then
return snapCache
end
if snapPending then return snapCache end
if snapFailed >= 5 and snapCache and now - snapAt < 15 then
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
function Repo.CarryFieldEgg(uid)
local m = Repo.EggStateModule()
if m and type(m.CarryFieldEgg) == "function" and type(uid) == "string" and uid ~= "" then
local slot = string.match(uid, "_([%w ]+:Slot_%d+)$")
P(m.CarryFieldEgg, uid, slot)
return true
end
return false
end
function Repo.DropFieldEgg()
local m = Repo.EggStateModule()
if m and type(m.DropFieldEgg) == "function" then
P(m.DropFieldEgg, "PlayerRequest")
return true
end
return false
end
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
end
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
if Movement.IsRagged() then
Character.AntiRagdollOnce()
task.wait(0.15)
else
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
for _, t in ipairs(char:GetChildren()) do
if t:IsA("BasePart") and (t.Name:lower():find("trap") or t.Name:lower():find("snare")) then
pcall(function() t:Destroy() end)
end
end
end
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
local Scan = { cache = nil, at = 0 }
function Scan.Workspace()
local now = os.clock()
if not Scan.cache or now - Scan.at > 4 then
Scan.cache = workspace:GetDescendants()
Scan.at = now
end
return Scan.cache
end
local Labels = {}
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
-- DISPATCHER (single loop) — tanpa ini Tasks.Add tidak pernah dijalankan!
-- Satu koneksi Heartbeat menjalankan semua worker sesuai intervalnya;
-- tiap worker dibungkus pcall + flag busy supaya tidak tumpang tindih.
RunService.Heartbeat:Connect(function()
local now = os.clock()
for _, t in pairs(Tasks.byName) do
if not t.busy and now >= t.next then
t.next = now + t.interval
t.busy = true
task.spawn(function()
local ok, err = pcall(t.fn)
if not ok then
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
P(function()
if elem.__kind == "toggle" then elem:Set(false) end
end)
end
end
local EggState = {}
function EggState.OwnEggs()
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
local function renderOwnerUid(m)
for _, attr in ipairs({ "OwnerUid", "PlayerUid", "Owner" }) do
local v = m:GetAttribute(attr)
if v and tostring(v) ~= "" then return tostring(v) end
end
if #m.Name == 32 then return "" end
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
local function modelPos(m)
return P(function()
if m:IsA("Model") then return m:GetPivot().Position else return m.CFrame.Position end
end)
end
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
local function slotModelOf(uid)
return P(function()
return workspace:FindFirstChild(uid)
or (Repo.AreaSlots() and Repo.AreaSlots():FindFirstChild(uid))
or nil
end)
end
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
local Steal, stealFilterOk, isCarrying, firePromptInstance
do
Steal = {
on = false, areas = {}, minRarity = 0, minValue = 0, specific = {},
lock = nil,
pick = {},
missingIndex = false, dropSafe = false,
priority = "Highest Value",
delivery = "Tween",
carryK = 1.0,
instantSteps = 3,
pullSpeed = 3300,
adminSteal = false,
v3 = false,
hwInstant = true,
hwAuto = false,
agPanel = true,
busy = false, bad = {}, stolen = 0, best = nil, bestRank = -1,
history = {}, lastDeliver = 0, hwDelivered = 0,
blocked = {},
}
local function horizDist(a, b)
local dx, dz = (a.X or 0) - (b.X or 0), (a.Z or 0) - (b.Z or 0)
return math.sqrt(dx * dx + dz * dz)
end
local V3_ZONES = {
["Prehistoric"] = true, ["Cosmic"] = true, ["Cherry Blossom"] = true,
["Titan Temple"] = true, ["Light Dark"] = true, ["Enchanted Forest"] = true,
}
local function zoneKey(egg)
local z = tostring((egg and (egg.Area or egg.Zone)) or "")
if z == "CherryBlossom" then z = "Cherry Blossom" end
return z
end
local function v3ZoneOk(egg)
return V3_ZONES[zoneKey(egg)] == true
end
local function deliveryMode(egg)
if Steal.delivery == "Fast Tween"
or (egg.Kind == "Halloween" and Steal.hwInstant) then
return "Pull"
end
if Steal.delivery == "Instant Steps" then return "Steps" end
return "Normal"
end
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
if egg.Kind == "Base" then return true end
local area = tostring(egg.Area or egg.Zone or "")
if area ~= "" and Steal.areas[area] then return true end
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
stealFilterOk = function(egg)
if egg.Kind == "Halloween" and Steal.hwFilterHook then
local ok = Steal.hwFilterHook(egg)
if ok == false then return false end
end
if not stealAreaOk(egg) then return false end
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
local queue = {}
for _, key in ipairs(Steal.pick) do queue[#queue + 1] = key end
if Steal.lock then queue[#queue + 1] = Steal.lock end
for _, key in ipairs(queue) do
for _, egg in ipairs(targets) do
if egg.Key == key then return egg end
end
local idx = table.find(Steal.pick, key)
if idx then table.remove(Steal.pick, idx) end
if Steal.lock == key then Steal.lock = nil end
end
local best, bestScore = nil, -math.huge
local now = os.clock()
for _, egg in ipairs(targets) do
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
local carryState = { on = false, uid = nil, seenAt = 0 }
Steal.carryWatch = false
local function detectCarryNow()
local char = LocalPlayer.Character
if not char then return nil end
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
local held = Movement.MyHeldEggModel()
if held then return tostring(held.Name) end
if P(function() return workspace:GetAttribute("HalloweenCarrying") end) == true then
return "halloween"
end
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
if not (Steal.on or Steal.busy or carryState.on or Steal.carryWatch) then return end
local uid = detectCarryNow()
if uid then
carryState.on = true
carryState.uid = uid
carryState.seenAt = os.clock()
elseif carryState.on then
if os.clock() - carryState.seenAt > 0.8 then
carryState.on = false
carryState.uid = nil
end
end
end)
isCarrying = function()
return carryState.on == true
end
local function carryingUid()
return carryState.uid
end
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
task.wait(0.45)
end
Movement.FlyTo(target, function() return not isCarrying() or os.clock() > deadline end, 350)
end
local function deliverEgg(egg)
local claimed = Movement.Claim("steal")
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
Movement.CarryTo(goal, function() return not isCarrying() end, 60, Steal.carryK)
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
Tasks.Status("steal", "HOLD EGG  |  no base anchor, waiting")
task.wait(1.5)
Movement.Release("steal")
Steal.busy = false
return
end
local target = home
if typeof(home) == "Instance" and home:IsA("BasePart") then
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
Movement.CarryTo(target, function()
return not isCarrying()
end, 12, nil, Steal.pullSpeed)
elseif mode == "Steps" then
deliverSteps(target)
else
Movement.CarryTo(target, function()
return not isCarrying()
end, 45, Steal.carryK)
end
local verdictMark = Steal.lastDeliver or 0
local t = os.clock() + 8
while isCarrying() and os.clock() < t and Steal.lastDeliver <= verdictMark do
task.wait(0.1)
end
if isCarrying() and Steal.lastDeliver <= verdictMark then
local hum = Movement.Humanoid()
if hum then pcall(function() hum:UnequipTools() end) end
local t2 = os.clock() + 1.5
while isCarrying() and os.clock() < t2 do task.wait(0.1) end
end
if Steal.lastDeliver > verdictMark then
Tasks.Status("steal", "Delivered")
elseif not isCarrying() then
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
local function nearestCarryPrompt(egg, maxDist)
local pos = egg.Pos
if not pos then return nil end
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
local function approachStep(egg)
if Steal.delivery == "Fast Tween" then
return math.huge
end
if Steal.delivery == "Instant Steps" then return 60 end
return Steal.carryK * 40
end
firePromptInstance = function(prompt)
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
return "gone"
end
if m and modelAlive and weldCarrier(m) ~= nil then return "taken" end
local pos = egg.Pos
if m and modelAlive and not pos then pos = modelPos(m) end
if not pos then return "gone" end
local t = os.clock() + 1.5
local nextFire, misses = 0, 0
while os.clock() < t and not isCarrying() do
local root = Movement.Root()
if not root then return "fail" end
if Movement.IsRagged() then break end
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
local function stealPromptEgg(egg)
local model, prompt = egg.Model, egg.Prompt
local step = approachStep(egg)
local attempt = 0
while attempt < 3 and not isCarrying() do
attempt = attempt + 1
if not Movement.WaitUnragdoll(1.5) then
return "fail"
end
if not model.Parent or not prompt or not prompt.Parent then
return (model.Parent and "fail") or "gone"
end
local carrier = weldCarrier(model)
if carrier and carrier ~= LocalPlayer.Character then return "taken" end
local deadline = os.clock() + 3
while os.clock() < deadline do
local root = Movement.Root()
if not root then break end
if not model.Parent then break end
if Movement.IsRagged() then break end
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
local toStar = v3StarHandlerPresent()
local pos = toStar and v3StarHandlerStand() or v3AdminBeltStand()
if not v3Teleport(pos) then return false end
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
v3Teleport(pos + Vector3.new(0, 3, 0))
local prompt = egg.Prompt
if not prompt or not prompt.Parent then
if egg.Kind == "Field" then prompt = nearestCarryPrompt(egg) end
end
if prompt then
firePromptInstance(prompt)
elseif egg.Kind == "Field" then
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
return "ok"
end
task.wait(0.2)
end
Tasks.Status("steal", "Instant Steal V3  |  could not grab the egg")
return "fail"
end
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
Tasks.Status("steal", "Waiting for Auto Place")
Steal.busy = false
return
end
if Movement.ExitBeltIfAnchored() then
Tasks.Status("steal", "Getting off the treadmill first")
task.wait(0.2)
end
waitGuardSleep(egg)
local res
if Steal.adminSteal and v3ZoneOk(egg) then
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
do
local idx = table.find(Steal.pick, egg.Key)
if idx then table.remove(Steal.pick, idx) end
end
if res == "delivered" then
stealSuccess(egg)
Tasks.Status("steal", "Instant Steal V3  |  delivered")
Movement.Release("steal")
Steal.busy = false
elseif res == "ok" and isCarrying() then
local heldUid = carryingUid()
local wantUid = tostring(egg.Uid or "")
local wrong = heldUid ~= nil and wantUid ~= ""
and heldUid ~= wantUid and heldUid ~= "halloween"
if wrong then
local alt = heldEggEntry(heldUid)
if alt and stealFilterOk(alt) then
Tasks.Status("steal", "Holding another egg that still matches, delivering it")
stealSuccess(alt)
deliverEgg(alt)
return
end
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
Tasks.Status("steal", "Someone took the target egg, picking another one")
Movement.Release("steal")
Steal.busy = false
else
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
-- Auto Steal Halloween Eggs mandiri (toggle Event > Halloween Dimension):
-- saat Auto Steal utama OFF, egg Halloween tetap dicuri lewat jalur ini.
-- Pola asli: cari egg terdekat yang lolos filter, dekati, tembak prompt,
-- lalu antar ke SafeZone Halloween (via deliverEgg cabang Halloween).
Tasks.Add("hwsteal", 1.0, function()
Steal.carryWatch = Steal.hwAuto == true
if not Steal.hwAuto then return end
if Steal.on then return end
if Steal.busy then return end
local root = Movement.Root()
if not root then return end
local best, bd = nil, math.huge
for _, egg in ipairs(EggState.HalloweenEggs()) do
if stealFilterOk(egg) and egg.Pos then
local d = (egg.Pos - root.Position).Magnitude
if d < bd then best, bd = egg, d end
end
end
if not best then return end
Steal.busy = true
task.spawn(function()
local claimed = Movement.Claim("hwsteal")
Tasks.Status("hwsteal", "Stealing this Halloween egg next")
local model, prompt = best.Model, best.Prompt
local deadline = os.clock() + 30
while os.clock() < deadline and not isCarrying() do
local r2 = Movement.Root()
if not r2 then break end
if not model or not model.Parent then break end
local pos = P(function() return model:GetPivot().Position end)
if not pos then break end
local d = pos - r2.Position
local step = (Steal.hwInstant ~= false) and 60 or 40
if d.Magnitude < 5 then
if prompt and prompt.Parent then
P(function() firePromptInstance(prompt) end)
end
task.wait(0.1)
else
Movement.StepTo(pos + Vector3.new(0, 3, 0), step)
end
task.wait()
end
if isCarrying() then
stealSuccess(best)
deliverEgg(best)
else
Tasks.Status("hwsteal", "Halloween steal gagal")
if claimed then Movement.Release("hwsteal") end
Steal.busy = false
return
end
if claimed then Movement.Release("hwsteal") end
end)
end)
end
Repo.Connect("RE/EggWorld/FieldEggRedeemVerdict", function(data)
Steal.lastDeliver = os.clock()
if type(data) == "table" then
local name = tostring(data.AssetCategory or data.DisplayName or "Egg")
local _, num = Repo.RarityOf(name)
Webhook.Post("Egg Delivered", "**" .. name .. "** tiba di base", num, name)
end
end)
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
if Hatch.minRarity > 0 and num < Hatch.minRarity then
elseif Hatch.minValue > 0 and Repo.EggValue(e.AssetCategory, e.AssetScale, e.Mutations) < Hatch.minValue then
elseif next(Hatch.specific) ~= nil and not Hatch.specific[e.AssetCategory] then
elseif (Hatch.cooldown[uid] or 0) > os.clock() then
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
if key == "pet" and cfg.petKeepMut and #e.Mutations > 0 then
elseif key == "egg" and cfg.eggKeepMut and #e.Mutations > 0 then
elseif cfg[key .. "Black"][name] then
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
local Place = { on = false, rule = "Always", order = "Biggest Size", rarities = {},
specific = {}, minValue = 0, busy = false, placed = 0 }
function Place.Pick()
local best, bestKey = nil, -math.huge
for uid, e in pairs(EggState.InBagOwn()) do
local label, num = Repo.RarityOf(e.AssetCategory)
if next(Place.rarities) ~= nil and not Place.rarities[label] then
elseif next(Place.specific) ~= nil and not Place.specific[e.AssetCategory] then
elseif Place.minValue > 0 and Repo.EggValue(e.AssetCategory, e.AssetScale, e.Mutations) < Place.minValue then
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
local Mutate = { on = false, use = {}, minRarity = 0, minValue = 0, targets = {},
priority = "Highest Value", cooldown = {} }
function Mutate.Pick()
local best, bestKey = nil, -math.huge
for uid, e in pairs(EggState.OwnEggs()) do
if e.Placement ~= nil then
local label, num = Repo.RarityOf(e.AssetCategory)
if Mutate.minRarity > 0 and num < Mutate.minRarity then
elseif Mutate.minValue > 0 and Repo.EggValue(e.AssetCategory, e.AssetScale, e.Mutations) < Mutate.minValue then
elseif next(Mutate.targets) ~= nil and not Mutate.targets[e.AssetCategory] then
elseif (Mutate.cooldown[uid] or 0) > os.clock() then
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
local Fuse = { on = false, mode = "Lowest Rarity First", order = "Lowest To Highest",
maxRarity = 10, species = {}, skipMut = true, eject = true,
cooldown = 0, fused = 0 }
function Fuse.Candidates()
local groups = {}
for uid, e in pairs(EggState.OwnPets()) do
local label, num = Repo.RarityOf(e.Category)
if num <= Fuse.maxRarity then
if next(Fuse.species) ~= nil and not Fuse.species[e.Category] then
elseif Fuse.skipMut and #e.Mutations > 0 then
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
function Webhook.Post(event, message, rarityNum, eggName)
if Webhook.url == "" then return end
if not Webhook.events[event] then return end
if eggName and next(Webhook.specific or {}) ~= nil
and not Webhook.specific[eggName] then return end
if (tonumber(rarityNum) or 0) > 0 and Webhook.minRarity > 0 and rarityNum < Webhook.minRarity then return end
local content = message
if Webhook.everyone then content = "@everyone " .. message end
local payload = HttpService:JSONEncode({ content = content, username = "ThorHub", })
task.spawn(httpPost, Webhook.url, payload)
end
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
if entry.id then Repo.Invoke("RF/Butterflies/AskClaimNet", tostring(entry.id)) end
end
for i, e in ipairs(Butter.list) do
if e == entry then table.remove(Butter.list, i) break end
end
end
Tasks.Add("butterflies", 0.8, function()
if not Butter.on then return end
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
local MoveX = {
speed = false,
boost = 350,
infJump = false,
baseWalk = nil,
}
Tasks.Add("movespeed", 0.5, function()
if not MoveX.speed then
if MoveX.baseWalk then
local hum = Movement.Humanoid()
if hum and hum.WalkSpeed ~= MoveX.baseWalk then
P(function() hum.WalkSpeed = MoveX.baseWalk end)
end
end
return
end
local hum = Movement.Humanoid()
if not hum then return end
if not MoveX.baseWalk then
MoveX.baseWalk = tonumber(P(function() return hum.WalkSpeed end)) or 16
end
P(function() hum.WalkSpeed = MoveX.boost end)
end)
do
local jumpConn = nil
local function setInfJump(on)
if jumpConn then P(function() jumpConn:Disconnect() end) jumpConn = nil end
if not on then return end
jumpConn = P(function()
return UserInputService.JumpRequest:Connect(function()
local hum = Movement.Humanoid()
if hum then P(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end) end
end)
end)
end
MoveX.SetInfJump = setInfJump
end
local CharX = {
invis = false,
antiRag = false,
antiTrap = false,
prompts = false,
}
Tasks.Add("charx", 0.5, function()
if CharX.antiRag and Movement.IsRagged() then
Character.AntiRagdollOnce()
Tasks.Status("charx", "Anti Ragdoll  |  recovering")
end
if CharX.antiTrap then
local root = Movement.Root()
if root then
local pos = root.Position
for _, inst in ipairs(Scan.Workspace()) do
if inst:IsA("BasePart") then
local n = string.lower(inst.Name or "")
if (string.find(n, "trap", 1, true) or string.find(n, "snare", 1, true)) then
local rel = P(function() return (inst.Position - pos).Magnitude end)
if rel and rel < 12 then
P(function()
root.CFrame = root.CFrame + Vector3.new(0, 8, 0)
end)
Tasks.Status("charx", "Anti Trap  |  escaped")
break
end
end
end
end
end
end
end)
do
local lastPrompt = 0
Tasks.Add("prompts", 1.5, function()
if not CharX.prompts then return end
if os.clock() - lastPrompt < 2 then return end
lastPrompt = os.clock()
for _, inst in ipairs(Scan.Workspace()) do
if inst:IsA("ProximityPrompt") and inst.HoldDuration > 0 then
P(function() inst.HoldDuration = 0 end)
end
end
end)
end
local ESP = {
eggs = false,
fixed = false,
own = false,
others = false,
minRarity = 0,
minValue = 0,
info = {},
eggSize = 0.75,
guards = false,
guardSize = 0.75,
players = false,
playerInfo = { Name = true, Tool = true },
playerSize = 0.75,
invValues = false,
tags = {},
}
local ESP_RARITY_COLOR = {
[1] = Color3.fromRGB(196, 200, 210), [2] = Color3.fromRGB(94, 219, 132),
[3] = Color3.fromRGB(86, 156, 255), [4] = Color3.fromRGB(178, 102, 255),
[5] = Color3.fromRGB(255, 173, 51), [6] = Color3.fromRGB(255, 84, 112),
[7] = Color3.fromRGB(88, 116, 255), [8] = Color3.fromRGB(255, 214, 64),
[9] = Color3.fromRGB(120, 240, 220), [10] = Color3.fromRGB(255, 240, 130),
}
local function espTextForEgg(egg, isOther)
local parts = {}
if ESP.info.Name ~= false then parts[#parts + 1] = tostring(egg.Name) end
if ESP.info.Rarity then
parts[#parts + 1] = "[" .. tostring(egg.RarityLabel or "?") .. "]"
end
if ESP.info.Value then
parts[#parts + 1] = "$" .. fmtNum(egg.Value or 0) .. "/s"
end
if ESP.info.Mutations and type(egg.Mutations) == "table" and #egg.Mutations > 0 then
parts[#parts + 1] = table.concat(egg.Mutations, " ")
end
if isOther then parts[#parts + 1] = "@" .. tostring(egg.OwnerName or "?") end
if ESP.info.Distance and egg.Pos and Movement.Pos() then
parts[#parts + 1] = tostring(math.floor((egg.Pos - Movement.Pos()).Magnitude + 0.5)) .. "m"
end
if #parts == 0 then parts[1] = tostring(egg.Name or "?") end
return table.concat(parts, "  ")
end
local function espAttach(inst, text, color, scale, group)
if not inst or ESP.tags[inst] then return end
local bb = Instance.new("BillboardGui")
bb.Name = "ThorESP"
bb.AlwaysOnTop = true
bb.Adornee = inst
bb.Size = UDim2.new(0, 220, 0, 34)
bb.StudsOffset = Vector3.new(0, 4, 0)
bb.StudsOffsetWorldSpace = ESP.fixed and Vector3.new(0, 30, 0) or Vector3.new(0, 4, 0)
bb.MaxDistance = 2000
local lbl = Instance.new("TextLabel")
lbl.BackgroundTransparency = 1
lbl.Size = UDim2.new(1, 0, 1, 0)
lbl.Font = Enum.Font.GothamBold
lbl.TextSize = math.floor(14 * scale + 0.5)
lbl.TextColor3 = color or Color3.fromRGB(255, 255, 255)
lbl.TextStrokeTransparency = 0.3
lbl.Text = text
lbl.Parent = bb
bb.Parent = inst
ESP.tags[inst] = { gui = bb, label = lbl, group = group }
end
local function espDrop(inst)
local t = ESP.tags[inst]
if t then P(function() t.gui:Destroy() end) ESP.tags[inst] = nil end
end
local function espColor(egg)
return ESP_RARITY_COLOR[egg.RarityNum or 0] or Color3.fromRGB(255, 255, 255)
end
Tasks.Add("esp", 1.0, function()
local any = ESP.eggs or ESP.own or ESP.others or ESP.guards or ESP.players
if not any then
for inst in pairs(ESP.tags) do espDrop(inst) end
return
end
for inst, t in pairs(ESP.tags) do
local gone = not inst.Parent or (t.group == "eggs" and not ESP.eggs)
or (t.group == "own" and not ESP.own)
or (t.group == "others" and not ESP.others)
or (t.group == "guards" and not ESP.guards)
or (t.group == "players" and not ESP.players)
if gone then espDrop(inst) end
end
local seen = {}
if ESP.eggs then
for _, egg in ipairs(EggState.StealTargets()) do
local inst = egg.Model or egg.RenderRoot
if inst and inst.Parent and egg.Kind ~= "Base" then
local pass = (egg.RarityNum or 0) >= ESP.minRarity
and (ESP.minValue <= 0 or (egg.Value or 0) >= ESP.minValue)
if pass then
seen[inst] = true
local txt = espTextForEgg(egg, false)
local t = ESP.tags[inst]
if t then
P(function() t.label.Text = txt end)
else
espAttach(inst, txt, espColor(egg), ESP.eggSize, "eggs")
end
end
end
end
end
local renders = Repo.PlacedEggRenders()
if renders then
local myUid = tostring(LocalPlayer.UserId)
for _, m in ipairs(renders:GetChildren()) do
local isMine = string.find(m.Name, myUid, 1, true) ~= nil
local group = isMine and "own" or "others"
if ESP[group] and not seen[m] then
local cat = P(function() return m:GetAttribute("AssetCategory")
or m:GetAttribute("Category") end)
local label, num = Repo.RarityOf(cat or "")
local scale = tonumber(P(function() return m:GetAttribute("Scale") end)) or 1
local val = Repo.EggValue(cat or "", scale, {}) or 0
local pass = num >= ESP.minRarity
and (ESP.minValue <= 0 or val >= ESP.minValue)
if pass then
seen[m] = true
local egg = { Name = cat or m.Name, RarityLabel = label,
RarityNum = num, Value = val, Mutations = {}, Pos = nil }
local t = ESP.tags[m]
local txt = espTextForEgg(egg, not isMine)
if t then
P(function() t.label.Text = txt end)
else
espAttach(m, txt, espColor(egg), ESP.eggSize, group)
end
end
end
end
end
if ESP.guards then
local ga = Repo.GuardAreas()
if ga then
for _, g in ipairs(ga:GetChildren()) do
local base = g:IsA("Model") and (g:FindFirstChild("HumanoidRootPart") or g:FindFirstChildWhichIsA("BasePart")) or g
if base and base:IsA("BasePart") then
seen[base] = true
local txt = "GUARD  " .. tostring(g.Name)
local t = ESP.tags[base]
if t then
P(function() t.label.Text = txt end)
else
espAttach(base, txt, Color3.fromRGB(255, 92, 92), ESP.guardSize, "guards")
end
end
end
end
end
if ESP.players then
for _, plr in ipairs(Players:GetPlayers()) do
if plr ~= LocalPlayer then
local root = P(function() return plr.Character
and plr.Character:FindFirstChild("HumanoidRootPart") end)
if root and root.Parent then
seen[root] = true
local parts = {}
if ESP.playerInfo.Name then parts[#parts + 1] = tostring(plr.DisplayName) end
if ESP.playerInfo.Username then parts[#parts + 1] = "@" .. tostring(plr.Name) end
if ESP.playerInfo.Tool then
local tool = P(function()
local ch = plr.Character
return ch and ch:FindFirstChildOfClass("Tool")
end)
if tool then parts[#parts + 1] = tostring(tool.Name) end
end
if ESP.info.Distance and Movement.Pos() then
local pp = P(function() return root.Position end)
if pp then
parts[#parts + 1] = tostring(math.floor((pp - Movement.Pos()).Magnitude + 0.5)) .. "m"
end
end
local txt = #parts > 0 and table.concat(parts, "  ") or tostring(plr.Name)
local t = ESP.tags[root]
if t then
P(function() t.label.Text = txt end)
else
espAttach(root, txt, Color3.fromRGB(120, 220, 255), ESP.playerSize, "players")
end
end
end
end
end
end)
local Combat = {
mode = "Auto Hit Nearest Player",
target = nil,
aura = false,
chase = 400,
maxSpeed = 750,
lead = -275,
sweep = 60,
weapons = {},
swapT = 0.3,
swapT2 = 0.4,
lastTarget = nil,
}
local function combatToolOf(plr)
local ch = plr.Character
if not ch then return nil end
local tool = ch:FindFirstChildOfClass("Tool")
if tool then
local ok = P(function()
return tool:GetAttribute("ItemType") == "Weapon"
or tool:GetAttribute("BatControllerData") ~= nil
end)
if ok then return tool end
end
return nil
end
local function combatEquipWeapon(slot)
local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
if not bp then return false end
local wanted = {}
for i = 1, 2 do
local w = Combat.weapons[i]
if w and w ~= "" then wanted[#wanted + 1] = w end
end
local best, bestName = nil, nil
for _, t in ipairs(bp:GetChildren()) do
if t:IsA("Tool") then
local isW = P(function()
return t:GetAttribute("ItemType") == "Weapon"
or t:GetAttribute("BatControllerData") ~= nil
or t:GetAttribute("ToolController") == "Slap"
end)
if isW then
if table.find(wanted, t.Name) then
best, bestName = t, t.Name
break
end
if not best then best, bestName = t, t.Name end
end
end
end
if best then
local hum = Movement.Humanoid()
if hum then
P(function() hum:EquipTool(best) end)
return true, bestName
end
end
return false, nil
end
local function combatFindTarget()
local mode = Combat.mode
if mode == "Auto Hit Specific Player" and Combat.target and Combat.target ~= "" then
local plr = Players:FindFirstChild(Combat.target)
if plr then
local root = P(function() return plr.Character
and plr.Character:FindFirstChild("HumanoidRootPart") end)
if root then return plr, root end
end
return nil, nil
end
local best, bestD = nil, math.huge
local myPos = Movement.Pos()
if not myPos then return nil, nil end
for _, plr in ipairs(Players:GetPlayers()) do
if plr ~= LocalPlayer then
local root = P(function() return plr.Character
and plr.Character:FindFirstChild("HumanoidRootPart") end)
if root then
local pos = P(function() return root.Position end)
if pos then
local d = (pos - myPos).Magnitude
local hit = false
if mode == "Auto Hit Egg Holders" then
local carrying = P(function()
local ch = plr.Character
local tool = ch and ch:FindFirstChildOfClass("Tool")
return tool and (tool:GetAttribute("EggUid") ~= nil
or tool:GetAttribute("UID") ~= nil
or string.find(tool.Name, "Egg", 1, true) ~= nil)
end)
hit = carrying == true
else
hit = true
end
if hit and d < bestD then best, bestD = plr, d end
end
end
end
end
if best then
local root = P(function() return best.Character
and best.Character:FindFirstChild("HumanoidRootPart") end)
return best, root
end
return nil, nil
end
local combatLastSwing = 0
local function combatSwing()
local now = os.clock()
if now - combatLastSwing < 0.3 then return end
combatLastSwing = now
Repo.Fire("RE/BatSwing/Trigger")
Repo.Fire("RE/ToolTrigger/Trigger")
end
Tasks.Add("combat", 0.25, function()
if not Combat.on then return end
local plr, root = combatFindTarget()
if not (plr and root) then
Tasks.Status("combat", "Hit  |  no target")
return
end
Combat.lastTarget = plr.Name
Tasks.Status("combat", "Hit  |  " .. tostring(plr.DisplayName)
.. (Combat.aura and "  |  aura" or ""))
local myRoot = Movement.Root()
if not myRoot then return end
task.spawn(function()
local pos = P(function() return root.Position end)
if not pos then return end
if Combat.aura then
combatEquipWeapon()
for _, p2 in ipairs(Players:GetPlayers()) do
if p2 ~= LocalPlayer and p2.Character then
local h2 = P(function()
return p2.Character:FindFirstChild("HumanoidRootPart")
end)
if h2 then
local pp2 = P(function() return h2.Position end)
if pp2 and (pp2 - myRoot.Position).Magnitude <= (Combat.sweep or 60) then
combatSwing()
break
end
end
end
end
return
end
local vel = P(function() return root.AssemblyLinearVelocity end)
or Vector3.new(0, 0, 0)
local dir = Vector3.new(vel.X, 0, vel.Z)
if dir.Magnitude > 1 then dir = dir.Unit else dir = Vector3.new(0, 0, 1) end
local standPos = pos + dir * math.abs(Combat.lead)
local sway = math.sin(os.clock() * 2) * (Combat.sweep / 100) * 6
standPos = standPos + Vector3.new(dir.Z, 0, -dir.X) * sway
local d = (standPos - myRoot.Position).Magnitude
local step = math.min(Combat.chase * 0.25, Combat.maxSpeed * 0.25, math.max(d, 4))
if d > 3 then
local delta = standPos - myRoot.Position
if delta.Magnitude > 0.01 then
P(function()
myRoot.CFrame = CFrame.new(myRoot.Position + delta.Unit * step)
end)
end
end
Combat.swapClock = (Combat.swapClock or 0) + 0.25
local hold = (Combat.swapIdx == 2) and Combat.swapT2 or Combat.swapT
if Combat.swapClock >= hold then
Combat.swapClock = 0
Combat.swapIdx = (Combat.swapIdx == 2) and 1
or ((Combat.weapons[2] and Combat.weapons[2] ~= "") and 2 or 1)
combatEquipWeapon()
end
if d < (Combat.sweep or 60) * 0.35 + 8 then
combatSwing()
end
end)
end)
local Perf = {
cap = 240,
opt = false,
optMode = "Strong",
fpsHud = true,
fpsSize = 100,
no3d = false,
bg = "White",
hud = nil, frames = 0, t0 = nil,
}
local OPT_CLASSES = {
Balanced = { "ParticleEmitter", "Trail", "Beam" },
Strong = { "ParticleEmitter", "Trail", "Beam", "Fire", "Smoke", "Sparkles",
"Explosion", "PointLight", "SpotLight", "SurfaceLight" },
Max = { "ParticleEmitter", "Trail", "Beam", "Fire", "Smoke", "Sparkles",
"Explosion", "PointLight", "SpotLight", "SurfaceLight" },
}
local function perfApplyOptimizer()
local classes = OPT_CLASSES[Perf.optMode] or OPT_CLASSES.Strong
local classSet = {}
for _, c in ipairs(classes) do classSet[c] = true end
for _, inst in ipairs(Scan.Workspace()) do
if classSet[inst.ClassName] then
P(function()
if inst:IsA("Explosion") then inst.Visible = false else inst.Enabled = false end
end)
elseif Perf.optMode == "Max" and inst:IsA("Texture") then
P(function() inst.Enabled = false end)
end
end
end
local function perfBuildHud()
P(function()
if Perf.hud then Perf.hud:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "ThorPerfHud"
gui.ResetOnSpawn = false
gui.DisplayOrder = 90
local lbl = Instance.new("TextLabel")
lbl.BackgroundTransparency = 1
lbl.AnchorPoint = Vector2.new(0, 0)
lbl.Position = UDim2.new(0, 8, 0, 8)
lbl.Size = UDim2.new(0, 260, 0, 24)
lbl.Font = Enum.Font.GothamBold
lbl.TextSize = math.floor(15 * Perf.fpsSize / 100 + 0.5)
lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
lbl.TextStrokeTransparency = 0.4
lbl.TextXAlignment = Enum.TextXAlignment.Left
lbl.Text = "FPS -- | Ping --"
lbl.Parent = gui
gui.Parent = gethui and gethui() or LocalPlayer:FindFirstChild("PlayerGui")
Perf.hud = gui
end)
end
Tasks.Add("perf", 1.0, function()
Perf.frames = (Perf.frames or 0) + 1
if not Perf.t0 then Perf.t0 = os.clock() + 1 end
if Perf.hud and Perf.fpsHud then
if os.clock() >= Perf.t0 then
local fps = Perf.frames
Perf.frames = 0
Perf.t0 = os.clock() + 1
local ping = P(function() return LocalPlayer:GetNetworkPing() end) or 0
ping = math.floor(ping * 1000 + 0.5)
P(function()
local lbl = Perf.hud:FindFirstChildOfClass("TextLabel")
if lbl then
lbl.Text = "FPS " .. tostring(fps) .. " | Ping " .. tostring(ping) .. "ms"
end
end)
end
else
Perf.frames = 0
Perf.t0 = nil
end
end)
do
P(function()
RunService.RenderStepped:Connect(function()
Perf.frames = (Perf.frames or 0) + 1
end)
end)
local lastOpt = 0
Tasks.Add("perfopt", 4.0, function()
if Perf.opt and os.clock() - lastOpt > 10 then
lastOpt = os.clock()
task.spawn(perfApplyOptimizer)
end
end)
end
local function perfApplyCap()
local cap = Perf.cap
if Perf.no3d and cap > 40 then cap = 40 end
if setfpscap then P(setfpscap, cap) end
end
local function perfApply3d()
P(function() RunService:Set3dRenderingEnabled(not Perf.no3d) end)
local col = (Perf.bg == "White") and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
P(function()
Lighting.Ambient = col
Lighting.OutdoorAmbient = col
Lighting.Brightness = Perf.no3d and 0 or 1
end)
end
local AntiAfk = { on = true }
do
P(function()
LocalPlayer.Idled:Connect(function()
if not AntiAfk.on then return end
local VIM = S("VirtualInputManager")
task.spawn(function()
pcall(function()
VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
task.wait(0.05)
VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
end)
end)
end)
end)
end
local Capture = {
on = false,
take = false,
holdHeight = 45,
keepAway = 45,
holding = false,
busy = false,
controlling = false,
rank = nil,
seconds = nil,
}
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
local worldEggs = Repo.WorldEggs()
for _, m in ipairs(workspace:GetChildren()) do
if m:IsA("Model") and m ~= worldEggs then
local prompt = P(function()
return m:FindFirstChild("StealPrompt", true)
or m:FindFirstChildWhichIsA("ProximityPrompt", true)
end)
local isEvent = prompt and P(function()
return m:GetAttribute("EventEgg")
or m.Name:find("Event", 1, true)
or m.Name:find("Capture", 1, true)
end)
if prompt and isEvent and P(function() return prompt.Enabled end) then
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
Tasks.Status("capture", "Holding egg! Rank " .. tostring(Capture.rank or "-"))
local root = Movement.Root()
local char = LocalPlayer.Character
local carrying = char and P(function() return char:FindFirstChildOfClass("Tool") end)
if root and carrying then
local nearest, nd = nil, math.huge
for _, plr in ipairs(Players:GetPlayers()) do
if plr ~= LocalPlayer and plr.Character then
local hrp = P(function()
return plr.Character:FindFirstChild("HumanoidRootPart")
end)
if hrp then
local pp = P(function() return hrp.Position end)
if pp then
local d = (pp - root.Position).Magnitude
if d < nd then nearest, nd = pp, d end
end
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
Capture.holding = true
return
end
Capture.holding = false
if Movement.Owner and Movement.Owner ~= "capture" then return end
Capture.busy = true
task.spawn(function()
if Movement.Claim("capture") then
local egg = findEventEggModel()
if egg then
Tasks.Status("capture", "Event egg terlihat, menuju...")
local pos = P(function() return egg:GetPivot().Position end)
if pos then
Movement.FlyTo(pos, function()
return LocalPlayer.Character
and LocalPlayer.Character:FindFirstChildOfClass("Tool") ~= nil
end, 45)
local prompt = P(function()
return egg:FindFirstChild("StealPrompt", true)
or egg:FindFirstChildWhichIsA("ProximityPrompt", true)
end)
if prompt then P(function() firePromptInstance(prompt) end) end
end
elseif Capture.take then
local holder = findEventEggHolder()
if holder and holder.Character then
Tasks.Status("capture", "Rebut dari " .. tostring(holder.Name))
local hrp = P(function()
return holder.Character:FindFirstChild("HumanoidRootPart")
end)
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
local Minigame = { on = true, busy = false }
Tasks.Add("minigame", 1.2, function()
if not Minigame.on then return end
if Minigame.busy then return end
if Steal.on and Steal.busy then return end
if Movement.Owner and Movement.Owner ~= "minigame" then return end
local worldEggs = Repo.WorldEggs()
local root = Movement.Root()
if not root then return end
for _, m in ipairs(workspace:GetChildren()) do
if m:IsA("Model") and m ~= worldEggs then
local prompt = P(function() return m:FindFirstChild("StealPrompt", true) end)
local isMg = prompt and P(function()
return prompt:IsA("ProximityPrompt") and prompt.Enabled
and (m:GetAttribute("Minigame")
or m.Name:find("Minigame", 1, true))
end)
if prompt and isMg then
Minigame.busy = true
task.spawn(function()
if Movement.Claim("minigame") then
local pos = P(function() return m:GetPivot().Position end)
if pos then
Movement.FlyTo(pos, function()
return LocalPlayer.Character
and LocalPlayer.Character:FindFirstChildOfClass("Tool") ~= nil
end, 45)
P(function() firePromptInstance(prompt) end)
Tasks.Status("minigame", "Going for the minigame egg")
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
local CIW = { on = false, target = "Enemies And Base" }
Repo.Connect("RE/IslandWars/State", function(state)
if type(state) == "table" then
Tasks.Status("ciw", tostring(state.Status or "Island Wars aktif"))
end
end)
Repo.Connect("RE/IslandWars/Moment", function(moment)
if CIW.on and type(moment) == "table" then
local pos = moment.Position and Vector3.new(
tonumber(moment.Position.X) or 0,
tonumber(moment.Position.Y) or 0,
tonumber(moment.Position.Z) or 0)
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
Tasks.Add("ciw", 3.0, function()
if not CIW.on then return end
local state = Repo.Invoke("RF/IslandWars/Fetch")
if type(state) == "table" then
Tasks.Status("ciw", "Island Wars: " .. tostring(state.Status or state.Kind or "aktif")
.. (CIW.target and ("  |  " .. CIW.target) or ""))
else
Tasks.Status("ciw", "Waiting for Cursed Island Wars")
end
end)
local Hollow = { on = false, speed = 300, powerups = true }
Tasks.Add("hollow", 0.6, function()
if not Hollow.on then return end
local root = Movement.Root()
if not root then return end
local best, bestD = nil, math.huge
for _, inst in ipairs(Scan.Workspace()) do
local ok = P(function() return inst:IsA("BasePart")
and (string.find(inst.Name, "Checkpoint", 1, true)
or string.find(inst.Name, "Hollow", 1, true)) end)
if ok then
local pos = P(function() return inst.Position end)
if pos then
local d = (pos - root.Position).Magnitude
if d < bestD and d > 4 then best, bestD = pos, d end
end
end
end
if not best then Tasks.Status("hollow", "Waiting for The Hollow race") return end
local goal = best
if Hollow.powerups then
for _, inst in ipairs(Scan.Workspace()) do
local ok = P(function() return inst:IsA("BasePart")
and (string.find(inst.Name, "Power", 1, true)
or string.find(inst.Name, "Boost", 1, true)
or inst:GetAttribute("PowerUp") == true) end)
if ok then
local pos = P(function() return inst.Position end)
if pos then
local d = (pos - root.Position).Magnitude
if d < 60 and d < bestD then
goal, bestD = pos, d
Tasks.Status("hollow", "Racing  |  taking a power-up")
end
end
end
end
end
local delta = goal - root.Position
P(function()
root.CFrame = CFrame.new(root.Position + delta.Unit
* math.min(delta.Magnitude, Hollow.speed * 0.55))
end)
if goal == best then
Tasks.Status("hollow", "Racing at " .. Hollow.speed .. " st/s")
end
end)
local Express = {
on = false,
vacuum = true,
tp = true,
souls = false,
ghostTarget = "Rarest First",
speed = 300,
busy = false,
}
Repo.Connect("RE/TrainEvent/State", function(state)
if type(state) == "table" then
Tasks.Status("express", tostring(state.Status or state.Kind or "Train event"))
end
end)
local expressLastSwing = 0
Tasks.Add("express", 0.8, function()
if not Express.on then return end
local root = Movement.Root()
if not root then return end
local best, bestD = nil, math.huge
for _, inst in ipairs(Scan.Workspace()) do
local ok = P(function() return inst:IsA("Model")
and (string.find(inst.Name, "Ghost", 1, true)
or string.find(inst.Name, "Ghoul", 1, true)
or string.find(inst.Name, "Soul", 1, true)) end)
if ok then
local pos = P(function() return inst:GetPivot().Position end)
if pos then
local d = (pos - root.Position).Magnitude
if d < bestD and d > 5 then best, bestD = pos, d end
end
end
end
if not best then
local rail = P(function()
return workspace:FindFirstChild("BoardRailStart", true)
or workspace:FindFirstChild("ReturnRailStart", true)
end)
if rail then
local rPos = P(function()
if rail:IsA("Model") then return rail:GetPivot().Position else return rail.Position end
end)
if rPos then
Tasks.Status("express", "No ghosts  |  boarding the Phantom Express")
Movement.FlyTo(rPos, nil, 40)
P(function() Repo.Invoke("RF/TrainEvent/Action", "Board") end)
return
end
end
Tasks.Status("express", "No ghosts around the tracks") return
end
Tasks.Status("express", Express.vacuum and "Vacuuming ghosts" or "Chasing ghosts")
if Express.tp then
P(function() root.CFrame = CFrame.new(best + Vector3.new(0, 3, 0)) end)
else
local delta = best - root.Position
P(function()
root.CFrame = CFrame.new(root.Position + delta.Unit
* math.min(delta.Magnitude, Express.speed * 0.6))
end)
end
local now = os.clock()
if now - expressLastSwing >= 0.6 then
expressLastSwing = now
if Express.vacuum then
Repo.Fire("RE/GhostBoss/Suction")
end
Repo.Fire("RE/ToolTrigger/Trigger")
Repo.Fire("RE/BatSwing/Trigger")
end
if Express.souls then
local ok = Repo.Invoke("RF/HalloweenDimension/AskTradeSouls")
if ok == nil then
P(function() Repo.Fire("RE/HalloweenDimension/TradeSouls") end)
end
end
end)
local HwMon = {
on = false,
tp = true,
bloodOnly = false,
bloodAll = false,
kill = {},
order = "Closest",
weapons = {},
speed = 300,
}
local HW_MONSTERS = {
"Candy Corn (+12 Candy)", "Hollow Bat (+12 Candy)", "Scarecrow (+28 Candy)",
"Chest Mimic (+28 Candy)", "Pumpkin Golem (+65 Candy)", "Soul Phantom (+65 Candy)",
}
local HW_MON_PART = {
["Candy Corn (+12 Candy)"] = "CandyCorn", ["Hollow Bat (+12 Candy)"] = "Bat",
["Scarecrow (+28 Candy)"] = "Scarecrow", ["Chest Mimic (+28 Candy)"] = "Mimic",
["Pumpkin Golem (+65 Candy)"] = "Pumpkin", ["Soul Phantom (+65 Candy)"] = "Phantom",
}
local HW_MON_CANDY = {
["CandyCorn"] = 12, ["Bat"] = 12, ["Scarecrow"] = 28,
["Mimic"] = 28, ["Pumpkin"] = 65, ["Phantom"] = 65,
}
local Monsters_names = {
["Candy Corn"] = true, ["Hollow Bat"] = true,
["Scarecrow"] = true, ["Chest Mimic"] = true,
["Pumpkin Golem"] = true, ["Soul Phantom"] = true,
}
local hwMonLastSwing = 0
local function hwMonSwing()
local now = os.clock()
if now - hwMonLastSwing < 0.12 then return end
hwMonLastSwing = now
Repo.Fire("RE/ToolTrigger/Trigger")
Repo.Fire("RE/BatSwing/Trigger")
end
local function hwMonSelected(name)
if next(HwMon.kill) == nil then return true end
return HwMon.kill[name] == true
end
Tasks.Add("hwmon", 0.8, function()
if not HwMon.on then return end
local bm = P(function() return workspace:GetAttribute("BloodMoon") end)
if HwMon.bloodOnly and bm ~= true then
Tasks.Status("hwmon", "Waiting for blood moon")
return
end
local root = Movement.Root()
if not root then return end
local best, bestD = nil, math.huge
for _, inst in ipairs(Scan.Workspace()) do
local ok = P(function()
if not (inst:IsA("Model") and inst.Parent) then return false end
local n = inst.Name
if Monsters_names[n] == true then return true end
return n:find("Monster", 1, true) ~= nil
and inst:GetAttribute("MonsterSize") ~= nil
end)
if ok then
local nm = tostring(inst.Name)
local part = nil
for label, p in pairs(HW_MON_PART) do
if hwMonSelected(label) and string.find(nm, p, 1, true) then
part = p break
end
end
if part then
local hum = inst:FindFirstChildOfClass("Humanoid")
local hp = hum and P(function() return hum.Health end)
if hp and hp > 0 then
local pos = P(function() return inst:GetPivot().Position end)
if pos then
local d = (pos - root.Position).Magnitude
local k = d
if HwMon.order == "Most Tokens" then
k = -(HW_MON_CANDY[part] or 0) * 1e6 + d
end
if k < bestD then best, bestD = pos, k end
end
end
end
end
end
if not best then Tasks.Status("hwmon", "No selected monsters nearby") return end
Tasks.Status("hwmon", "Farming monsters" .. (bm and " | blood moon" or ""))
if HwMon.tp then
P(function() root.CFrame = CFrame.new(best + Vector3.new(0, 3, 0)) end)
else
local delta = best - root.Position
P(function()
root.CFrame = CFrame.new(root.Position + delta.Unit
* math.min(delta.Magnitude, HwMon.speed * 0.6))
end)
end
hwMonSwing()
end)
local HwPump = { on = true, tp = true, speed = 300 }
local PBoss = { on = false, dodge = true }
Tasks.Add("hwpump", 0.7, function()
if not (HwPump.on or PBoss.on) then return end
local pm = P(function() return workspace:GetAttribute("PumpkinMoon") end)
local boss = P(function() return workspace:GetAttribute("PumpkinBossActive") end)
if pm ~= true and boss ~= true then
Tasks.Status("hwpump", "Waiting for Pumpkin Moon")
return
end
local root = Movement.Root()
if not root then return end
if PBoss.on and boss == true then
local bPos = nil
for _, inst in ipairs(Scan.Workspace()) do
local ok = P(function() return inst:IsA("Model")
and string.find(inst.Name, "Boss", 1, true) end)
if ok then
bPos = P(function() return inst:GetPivot().Position end)
break
end
end
if bPos then
Tasks.Status("hwpump", "Pumpkin Boss  |  dodging")
local dir = (root.Position - bPos)
if dir.Magnitude < 20 and PBoss.dodge then
P(function()
root.CFrame = CFrame.new(root.Position + dir.Unit * 24 + Vector3.new(0, 6, 0))
end)
end
hwMonSwing()
return
end
end
if HwPump.on then
for _, inst in ipairs(Scan.Workspace()) do
local ok = P(function() return inst:IsA("BasePart")
and string.find(inst.Name, "Pumpkin", 1, true) end)
if ok then
local pos = P(function() return inst.Position end)
if pos then
local d = (pos - root.Position).Magnitude
if d < 400 then
if HwPump.tp then
P(function() root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) end)
else
local delta = pos - root.Position
P(function()
root.CFrame = CFrame.new(root.Position + delta.Unit
* math.min(delta.Magnitude, HwPump.speed * 0.6))
end)
end
P(function() Repo.Fire("RE/PumpkinBoss/Collect") end)
local pp = P(function() return inst:FindFirstChildOfClass("ProximityPrompt") end)
if pp then P(function() firePromptInstance(pp) end) end
Tasks.Status("hwpump", "Collecting pumpkins")
return
end
end
end
end
end
end)
local HwDog = { on = false }
local HwFish = { on = false, luck = "x1.5 Perfect", spot = "Default",
spots = {}, speed = 300, lastCast = 0 }
Tasks.Add("hwdog", 4.0, function()
if not HwDog.on then return end
local quest = P(function() return Repo.Invoke("RF/GhostDogQuest/Talk") end)
if type(quest) == "table" then
P(function() Repo.Invoke("RF/GhostDogQuest/Dive") end)
task.wait(0.3)
P(function() Repo.Invoke("RF/GhostDogQuest/Cast") end)
task.wait(0.5)
P(function() Repo.Invoke("RF/GhostDogQuest/Collect") end)
task.wait(0.3)
P(function() Repo.Invoke("RF/GhostDogQuest/Claim") end)
task.wait(0.2)
P(function() Repo.Invoke("RF/GhostDogQuest/Surface") end)
Tasks.Status("hwdog", "Ghost Dog quest progressing")
else
Tasks.Status("hwdog", "Ghost Dog quest: waiting/none available")
end
end)
local FISH_LUCK_DELAY = {
["x1.5 Perfect"] = 7, ["x1.2"] = 6, ["x1.1"] = 5, ["x1.0 Fastest"] = 3,
}
Tasks.Add("hwfish", 1.5, function()
if not HwFish.on then return end
local waitS = FISH_LUCK_DELAY[HwFish.luck] or 7
if os.clock() - HwFish.lastCast < waitS then return end
HwFish.lastCast = os.clock()
if HwFish.spot ~= "Default" then
local n = tonumber(string.match(HwFish.spot, "%d")) or 1
local saved = HwFish.spots[n]
if saved then
local root = Movement.Root()
if root then P(function() root.CFrame = CFrame.new(saved) end) end
end
end
task.spawn(function()
if Movement.Claim("fish") then
Tasks.Status("hwfish", "Casting (" .. HwFish.luck .. ")")
local ok = Repo.Invoke("RF/Fishing/Cast", HwFish.luck)
if ok == nil then ok = Repo.Invoke("RF/Fishing/Cast") end
if ok ~= nil then
task.wait(math.max(waitS - 1.5, 2))
Repo.Invoke("RF/Fishing/Reel")
else
Tasks.Status("hwfish", "Tidak bisa memancing di sini")
end
Movement.Release("fish")
end
end)
end)
local Rotation = { on = false, mode = "Timer", fishMin = 5, treadMin = 5,
phase = "fishing", swapAt = 0 }
Tasks.Add("rotation", 5.0, function()
if not Rotation.on then return end
local fishEl = Config.Elements["event/fishing"]
local treadEl = Config.Elements["farm/tread"]
if not (fishEl and treadEl) then return end
if Rotation.mode == "Timer" then
local now = os.clock()
if Rotation.swapAt == 0 then Rotation.swapAt = now + Rotation.fishMin * 60 end
if now >= Rotation.swapAt then
if Rotation.phase == "fishing" then
P(function() fishEl:Set(false, true) end)
P(function() treadEl:Set(true, true) end)
Rotation.phase = "treadmill"
Rotation.swapAt = now + Rotation.treadMin * 60
Tasks.Status("rotation", "Switched to treadmill")
else
P(function() treadEl:Set(false, true) end)
P(function() fishEl:Set(true, true) end)
Rotation.phase = "fishing"
Rotation.swapAt = now + Rotation.fishMin * 60
Tasks.Status("rotation", "Switched to fishing")
end
else
local left = math.max(0, Rotation.swapAt - now)
Tasks.Status("rotation", "Now: " .. Rotation.phase .. " | switch in "
.. tostring(math.floor(left / 60)) .. "m " .. tostring(math.floor(left % 60)) .. "s")
end
end
end)
local HWX = {
on = false,
instant = true,
holders = true,
index = true,
placeHatch = false,
buy = false,
eggs = {},
rarities = {},
minValue = 0,
}
Steal.hwFilterHook = function(egg)
if not HWX.on then return false end
if HWX.index and not Repo.IndexMissing(egg.Category or egg.Name or "") then return false end
local name = tostring(egg.Category or egg.Name or "")
if next(HWX.eggs) ~= nil and not HWX.eggs[name] then return false end
if next(HWX.rarities) ~= nil and not HWX.rarities[tostring(egg.RarityLabel or "")] then return false end
if HWX.minValue > 0 and (egg.Value or 0) < HWX.minValue then return false end
return true
end
Tasks.Add("hwbuy", 8.0, function()
if not HWX.buy then return end
if os.clock() < (HWX.buyCooldown or 0) then return end
local ok = Repo.Invoke("RF/HalloweenDimension/AskBuyEgg")
if ok then
HWX.buyCooldown = os.clock() + 5
Tasks.Status("hwbuy", "Halloween Dimension egg bought")
else
HWX.buyCooldown = os.clock() + 30
Tasks.Status("hwbuy", "Halloween egg buy: menunggu (cooldown)")
end
end)
Tasks.Add("hwplace", 8.0, function()
if not HWX.placeHatch then return end
local home = Repo.PenAnchor()
if not home then return end
for uid, e in pairs(EggState.InBagOwn()) do
local cat = e.AssetCategory or ""
if Repo.IndexMissing(cat) then
local placed = Repo.Invoke("RF/EggWorld/AskPlaceEgg", uid)
if placed then
task.wait(0.4)
local ok = Repo.Invoke("RF/EggWorld/AskHatch", uid)
if ok ~= nil and ok ~= false then
Repo.Invoke("RF/EggWorld/AskFinishHatch", uid)
Tasks.Status("hwplace", "Missing index egg placed & hatched: " .. cat)
return
end
end
end
end
end)
local FarmHud = {
on = false,
hideGame = true,
items = { Speed = true, Cash = true },
cards = 4,
size = 100,
image = "Egg Image",
gui = nil, panel = nil, labels = {},
}
local function farmHudBuild()
P(function()
if FarmHud.gui then FarmHud.gui:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "ThorFarmHud"
gui.ResetOnSpawn = false
gui.DisplayOrder = 60
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -12, 0.5, 0)
panel.Size = UDim2.new(0, math.floor(210 * FarmHud.size / 100), 0, 30)
panel.BackgroundColor3 = Color3.fromRGB(11, 14, 23)
panel.BackgroundTransparency = 0.25
panel.BorderSizePixel = 0
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = panel
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.Padding = UDim.new(0, 2)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = panel
FarmHud.labels = {}
for i, key in ipairs({ "Speed", "Cash", "Stolen", "Cards" }) do
local lbl = Instance.new("TextLabel")
lbl.BackgroundTransparency = 1
lbl.Size = UDim2.new(1, -8, 0, 22)
lbl.Font = Enum.Font.GothamBold
lbl.TextSize = math.floor(13 * FarmHud.size / 100 + 0.5)
lbl.TextColor3 = Color3.fromRGB(240, 244, 255)
lbl.TextXAlignment = Enum.TextXAlignment.Left
lbl.Text = ""
lbl.LayoutOrder = i
lbl.Parent = panel
FarmHud.labels[key] = lbl
end
gui.Parent = gethui and gethui() or LocalPlayer:FindFirstChild("PlayerGui")
FarmHud.gui = gui
FarmHud.panel = panel
panel.Active = true
local dragging, dragStart, startPos = false, nil, nil
panel.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1
or input.UserInputType == Enum.UserInputType.Touch then
dragging = true
dragStart = input.Position
startPos = panel.Position
end
end)
UserInputService.InputChanged:Connect(function(input)
if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
or input.UserInputType == Enum.UserInputType.Touch) then
local delta = input.Position - dragStart
P(function()
panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end)
end
end)
UserInputService.InputEnded:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1
or input.UserInputType == Enum.UserInputType.Touch then
dragging = false
end
end)
end)
end
Tasks.Add("farmhud", 1.0, function()
if not FarmHud.on then
if FarmHud.gui then
P(function() FarmHud.gui:Destroy() end)
FarmHud.gui = nil
end
return
end
if not FarmHud.gui then farmHudBuild() end
local labels = FarmHud.labels
if labels.Speed and FarmHud.items.Speed then
local sp = P(function()
return LocalPlayer:FindFirstChild("leaderstats")
and LocalPlayer.leaderstats:FindFirstChild("Speed")
end)
local v = sp and P(function() return sp.Value end) or nil
P(function() labels.Speed.Text = "Speed: " .. (v and fmtNum(v) or "--") end)
end
if labels.Cash and FarmHud.items.Cash then
local money = Repo.SaveData()
local cash = money and (tonumber(money.Money) or money.Money) or nil
P(function() labels.Cash.Text = "Cash: " .. (cash and ("$" .. fmtNum(cash)) or "--") end)
end
if labels.Stolen and FarmHud.items.Stolen then
P(function()
labels.Stolen.Text = "Stolen: " .. tostring(Steal.stolen)
.. "  |  best: " .. tostring(Steal.best and Steal.best.Name or "-")
end)
end
if labels.Cards and FarmHud.items.Cards then
local targets = EggState.StealTargets()
local sorted = {}
for _, t in ipairs(targets) do
if t.Kind ~= "Base" then sorted[#sorted + 1] = t end
end
table.sort(sorted, function(a, b) return (a.Value or 0) > (b.Value or 0) end)
local lines = {}
for i = 1, math.min(FarmHud.cards, #sorted) do
local t = sorted[i]
lines[#lines + 1] = tostring(t.Name) .. "  $" .. fmtNum(t.Value or 0) .. "/s"
end
P(function()
labels.Cards.Text = #lines > 0 and table.concat(lines, "\n") or "No eggs in sight"
end)
end
end)
local GuardPanel = { gui = nil }
Tasks.Add("guardpanel", 0.5, function()
local want = Steal.on and Steal.agPanel
if not want then
if GuardPanel.gui then
P(function() GuardPanel.gui:Destroy() end)
GuardPanel.gui = nil
end
return
end
if not GuardPanel.gui then
P(function()
local gui = Instance.new("ScreenGui")
gui.Name = "ThorGuardPanel"
gui.ResetOnSpawn = false
gui.DisplayOrder = 70
local chip = Instance.new("Frame")
chip.AnchorPoint = Vector2.new(1, 1)
chip.Position = UDim2.new(1, -10, 1, -10)
chip.Size = UDim2.new(0, 170, 0, 30)
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
gui.Parent = gethui and gethui() or LocalPlayer:FindFirstChild("PlayerGui")
GuardPanel.gui = gui
end)
end
local near = false
local myPos = Movement.Pos()
if myPos then
local ga = Repo.GuardAreas()
if ga then
for _, g in ipairs(ga:GetChildren()) do
local base = g:IsA("Model")
and (g:FindFirstChild("HumanoidRootPart") or g:FindFirstChildWhichIsA("BasePart"))
or g
if base and base:IsA("BasePart") then
local d = P(function() return (base.Position - myPos).Magnitude end)
if d and d < 120 then
near = true break
end
end
end
end
end
if GuardPanel.gui then
P(function()
local lbl = GuardPanel.gui:FindFirstChild("Lbl", true)
if lbl then
if near then
lbl.Text = "GUARD  |  nearby - careful"
lbl.TextColor3 = Color3.fromRGB(255, 120, 120)
else
lbl.Text = "GUARD  |  clear"
lbl.TextColor3 = Color3.fromRGB(120, 255, 160)
end
end
end)
end
end)
local Predictor = { sort = "Value", spotlight = true, list = {}, lastFetch = 0 }
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
local label, num = Repo.RarityOf(name)
Notify("🔮 Event mulai", name, 4)
if Predictor.spotlight then
local value = tonumber(ev.Value) or Repo.EggValue(name, 1) or 0
Notify("🔮 Preview Card", name .. "  [" .. tostring(label) .. "]  $"
.. fmtNum(value) .. "/s" .. (ev.TimeLeft and ("  |  " .. tostring(math.floor(ev.TimeLeft)) .. "s") or ""), 6)
end
Webhook.Post("Rare Spawn", "Event baru: **" .. name .. "**", num, name)
end
end)
Repo.Connect("RE/LiveEvents/Ended", function(ev)
Tasks.Wake("predictor")
end)
local function predictorSorted()
local list = {}
for _, egg in ipairs(EggState.FieldEggs()) do
list[#list + 1] = egg
end
local mode = Predictor.sort
table.sort(list, function(a, b)
if mode == "Rarity" then
if (a.RarityNum or 0) ~= (b.RarityNum or 0) then
return (a.RarityNum or 0) > (b.RarityNum or 0)
end
return (a.Value or 0) > (b.Value or 0)
elseif mode == "Time Left" then
return (a.TimeLeft or a.Time or 0) < (b.TimeLeft or b.Time or 0)
end
return (a.Value or 0) > (b.Value or 0)
end)
return list
end
Tasks.Add("predictor", 2.0, function()
Predictor.Fetch()
local rows = {}
if type(Predictor.list) == "table" then
for _, ev in pairs(Predictor.list) do
if type(ev) == "table" then
local name = tostring(ev.AssetCategory or ev.Name or ev.Type or "?")
local label, num = Repo.RarityOf(name)
local timeLeft = tonumber(ev.TimeLeft or ev.SecondsLeft or ev.timeLeft)
local value = tonumber(ev.Value) or Repo.EggValue(name, 1) or 0
rows[#rows + 1] = { Name = name, RarityLabel = label, RarityNum = num,
Value = value, TimeLeft = timeLeft }
end
end
end
table.sort(rows, function(a, b)
if Predictor.sort == "Rarity" then
if (a.RarityNum or 0) ~= (b.RarityNum or 0) then
return (a.RarityNum or 0) > (b.RarityNum or 0)
end
return (a.Value or 0) > (b.Value or 0)
elseif Predictor.sort == "Time Left" then
return (a.TimeLeft or math.huge) < (b.TimeLeft or math.huge)
end
return (a.Value or 0) > (b.Value or 0)
end)
if #rows > 0 then
local lines = {}
for i = 1, math.min(#rows, 15) do
local e = rows[i]
local extra = e.TimeLeft and ("  |  " .. tostring(math.floor(e.TimeLeft + 0.5)) .. "s") or ""
lines[#lines + 1] = tostring(i) .. ". " .. tostring(e.Name)
.. "  [" .. tostring(e.RarityLabel or "?") .. "]"
.. "  $" .. fmtNum(e.Value or 0) .. "/s" .. extra
end
Tasks.Status("predictor", table.concat(lines, "\n"))
return
end
local list = predictorSorted()
local lines = {}
for i = 1, math.min(#list, 15) do
local e = list[i]
local extra = ""
if e.TimeLeft or e.Time then
local t = tonumber(e.TimeLeft or e.Time) or 0
if t > 0 then
extra = "  |  " .. tostring(math.floor(t / 60 + 0.5)) .. "m left"
end
end
lines[#lines + 1] = tostring(i) .. ". " .. tostring(e.Name)
.. "  [" .. tostring(e.RarityLabel or "?") .. "]"
.. "  $" .. fmtNum(e.Value or 0) .. "/s" .. extra
end
local txt = #lines > 0 and table.concat(lines, "\n")
or "No field eggs right now"
Tasks.Status("predictor", txt)
end)
local FusePred = {}
Tasks.Add("fusepred", 4.0, function()
if not Fuse.on then
Tasks.Status("fusepred", "Turn on Auto Fuse Machine to preview")
return
end
local groups = Fuse.Candidates()
local n = 0
for _, g in pairs(groups) do n = n + 1 end
Tasks.Status("fusepred", n > 0
and (tostring(n) .. " species ready to fuse (Auto Fuse on)")
or "No species with 2+ copies yet")
end)
local ServerX = {
autoLoad = true,
autoRejoin = false,
hopMode = "Least Players",
}
function ServerX.Rejoin()
P(function()
TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end)
end
function ServerX.JoinJob(jobId)
jobId = tostring(jobId or ""):gsub("%s", "")
if jobId == "" then Notify("Server", "Isi Job ID dulu", 3) return end
Notify("Server", "Joining " .. jobId, 3)
P(function()
TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer)
end)
end
function ServerX.CopyJobId()
local id = tostring(game.JobId or "")
if setclipboard then
P(setclipboard, id)
Notify("Server", "Job ID disalin: " .. id, 4)
else
Notify("Server", "Job ID: " .. id, 6)
end
end
do
P(function()
LocalPlayer.OnTeleport:Connect(function(state)
if state == Enum.TeleportState.Failed and ServerX.autoRejoin then
task.wait(2)
ServerX.Rejoin()
end
end)
end)
end
local StealPanel
do
local function spSeq(points)
local kp = {}
for _, p in ipairs(points) do kp[#kp + 1] = ColorSequenceKeypoint.new(p[1], p[2]) end
return ColorSequence.new(kp)
end
local function spRGB(r, g, b) return Color3.fromRGB(r, g, b) end
local SP_Theme = {}
SP_Theme.Hud = { Color = spSeq({ {0, spRGB(0, 118, 255)}, {1, spRGB(72, 204, 255)} }), Rotation = -90,
Stroke = spRGB(0, 28, 76), Light = spRGB(172, 226, 255) }
SP_Theme.Steal = { Color = spSeq({ {0, spRGB(60, 255, 0)}, {1, spRGB(136, 255, 0)} }), Rotation = -90,
Stroke = spRGB(11, 72, 0), Light = spRGB(190, 255, 180) }
SP_Theme.Queued = { Color = spSeq({ {0, spRGB(118, 118, 132)}, {1, spRGB(172, 172, 186)} }), Rotation = -90,
Stroke = spRGB(28, 28, 34), Light = spRGB(214, 214, 226) }
SP_Theme.PriorityOn = { Color = spSeq({ {0, spRGB(255, 247, 0)}, {1, spRGB(255, 136, 0)} }), Rotation = 90,
Stroke = spRGB(0, 0, 0), Light = spRGB(132, 112, 0) }
SP_Theme.Cancel = { Color = spSeq({ {0, spRGB(214, 17, 17)}, {1, spRGB(253, 20, 20)} }), Rotation = -90,
Stroke = spRGB(72, 0, 0), Light = spRGB(255, 103, 103) }
SP_Theme.Toggle = { Color = spSeq({ {0, spRGB(132, 74, 255)}, {0.34, spRGB(178, 74, 255)},
{0.6, spRGB(255, 104, 206)}, {0.78, spRGB(255, 168, 232)}, {1, spRGB(146, 66, 255)} }),
Rotation = -115, Stroke = spRGB(44, 10, 80), Light = spRGB(226, 178, 255) }
local function spNew(class, props, parent)
local inst = Instance.new(class)
if props then
for k, v in pairs(props) do
P(function() inst[k] = v end)
end
end
if parent then P(function() inst.Parent = parent end) end
return inst
end
local function spRandName()
local ok, guid = pcall(function()
return HttpService:GenerateGUID(false):gsub('-', ''):sub(1, 14)
end)
if ok and guid then return guid end
return tostring(math.random(1e6, 9e6))
end
local function spRename(inst)
P(function()
inst.Name = spRandName()
for _, d in ipairs(inst:GetDescendants()) do d.Name = spRandName() end
end)
end
local function StealPanelSortTargets(targets, mode)
local sorted = {}
for _, t in ipairs(targets) do sorted[#sorted + 1] = t end
local m = mode or Steal.priority
table.sort(sorted, function(a, b)
local ka, kb
if m == "Best Rarity" then
ka, kb = a.RarityNum or 0, b.RarityNum or 0
elseif m == "Biggest Weight" then
ka, kb = a.Scale or 0, b.Scale or 0
elseif m == "Best Mutation" then
ka, kb = #a.Mutations or 0, #b.Mutations or 0
elseif m == "Lowest Value" then
return (a.Value or 0) < (b.Value or 0)
else
ka, kb = a.Value or 0, b.Value or 0
end
if ka ~= kb then return ka > kb end
return (a.Value or 0) > (b.Value or 0)
end)
return sorted
end
function Steal.Plan()
local out, seen = {}, {}
for _, key in ipairs(Steal.pick) do
if not seen[key] then seen[key] = true out[#out + 1] = key end
end
if Steal.on then
local targets = EggState.StealTargets()
local sorted = StealPanelSortTargets(targets, Steal.priority)
local added = 0
for _, egg in ipairs(sorted) do
if added >= 8 then break end
if egg.Kind ~= "Base" and not seen[egg.Key] and stealFilterOk(egg) then
seen[egg.Key] = true
out[#out + 1] = egg.Key
added = added + 1
end
end
end
return out
end
function Steal.Now(key)
if type(key) ~= "string" then return end
Steal.pick = { key }
Steal.lock = key
if not Steal.on then
Steal.on = true
local el = Config.Elements["farm/steal"]
if el and el.Set then P(function() el:Set(true, true) end) end
end
Tasks.Wake("steal")
end
function Steal.Prioritize(key)
if type(key) ~= "string" then return end
local idx = table.find(Steal.pick, key)
if idx then table.remove(Steal.pick, idx) end
table.insert(Steal.pick, 1, key)
Steal.lock = key
if not Steal.on then
Steal.on = true
local el = Config.Elements["farm/steal"]
if el and el.Set then P(function() el:Set(true, true) end) end
end
Tasks.Wake("steal")
end
function Steal.Cancel(key)
if type(key) ~= "string" then return end
local idx = table.find(Steal.pick, key)
if idx then table.remove(Steal.pick, idx) end
if Steal.lock == key then Steal.lock = nil end
end
function Steal.MoveInPlan(key, delta)
local plan = Steal.Plan()
local i = table.find(plan, key)
if not i then return end
local j = i + (delta or 0)
if j < 1 or j > #plan or not plan[j] then return end
plan[i], plan[j] = plan[j], plan[i]
local wasPick = {}
for _, k in ipairs(Steal.pick) do wasPick[k] = true end
Steal.pick = {}
for _, k in ipairs(plan) do
if wasPick[k] then Steal.pick[#Steal.pick + 1] = k end
end
end
local function spFindGameHud()
local pg = P(function() return LocalPlayer:FindFirstChildOfClass("PlayerGui") end)
if not pg then return nil end
local hud = P(function() return pg:FindFirstChild("HUD") end)
if not hud then return nil end
local gameHud = P(function() return hud:FindFirstChild("GameHUD") end)
local right = gameHud and P(function() return gameHud:FindFirstChild("RightButtons") end)
local eggs = right and P(function() return right:FindFirstChild("EggsButton") end)
local pets = right and P(function() return right:FindFirstChild("PetsButton") end)
local active = P(function() return pg:FindFirstChild("ActivePets") end)
local frame = active and P(function() return active:FindFirstChild("Frame") end)
if eggs and pets and frame then
return { PlayerGui = pg, RightButtons = right, Eggs = eggs, Pets = pets,
ActivePetsFrame = frame }
end
return nil
end
local function spClone(inst)
local ok, c = pcall(function() return inst:Clone() end)
if not (ok and typeof(c) == "Instance") then return nil end
P(function()
for _, d in ipairs(c:GetDescendants()) do
if d:IsA("LuaSourceContainer") then d:Destroy() end
end
end)
return c
end
StealPanel = {
gui = nil, panelGui = nil, root = nil, list = nil, rows = {},
btnGui = nil, btn = nil, hudConns = {},
open = false, built = false, animating = false,
filter = "All",
SORTS = { "Best Rarity", "Biggest Weight", "Best Mutation", "Highest Value", "Lowest Value" },
mode = "hijack",
cards = {}, sel = nil,
lblTitle = nil, lblSort = nil, btnClose = nil,
rowSteal = nil, rowHw = nil, rowFilter = nil,
}
local SP_BG = Color3.fromRGB(11, 14, 23)
local SP_CARD = Color3.fromRGB(21, 26, 41)
local SP_STROKE = Color3.fromRGB(45, 58, 88)
local SP_TEXT = Color3.fromRGB(240, 244, 255)
local SP_DIM = Color3.fromRGB(145, 155, 180)
local SP_GREEN = Color3.fromRGB(88, 255, 120)
local SP_RED = Color3.fromRGB(255, 92, 100)
local SP_GOLD = Color3.fromRGB(255, 200, 60)
local SP_PURPLE = Color3.fromRGB(178, 120, 255)
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
local function spClick()
P(function()
local snd = Instance.new("Sound")
snd.SoundId = "rbxassetid://100671636189844"
snd.Volume = 1.5
snd.PlaybackSpeed = 0.93 + math.random() * 0.13
snd.Parent = workspace
snd:Play()
game:GetService("Debris"):AddItem(snd, 3)
end)
end
function StealPanel.Destroy()
for _, c in ipairs(StealPanel.hudConns) do
P(function() c:Disconnect() end)
end
StealPanel.hudConns = {}
if StealPanel.panelGui then P(function() StealPanel.panelGui:Destroy() end) end
if StealPanel.btnGui then P(function() StealPanel.btnGui:Destroy() end) end
StealPanel.panelGui = nil
StealPanel.btnGui = nil
StealPanel.btn = nil
StealPanel.root = nil
StealPanel.list = nil
StealPanel.rows = {}
StealPanel.built = false
StealPanel.open = false
end
local function destroyOldPanels()
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
local n = tostring(d.Name)
if n == "ThorHubStealPanel" or n == "ThorSP" or n == "ThorSPBtn" then
P(function() d:Destroy() end)
end
end
end
end
local function spBuildRow(list, egg, rank, picked)
local rcol = spRarityColor(egg.RarityNum)
local row = spNew("TextButton", {
Size = UDim2.new(1, -6, 0, 46),
BackgroundColor3 = SP_CARD, BorderSizePixel = 0, Text = "",
AutoButtonColor = false, LayoutOrder = rank,
}, list)
spNew("UICorner", { CornerRadius = UDim.new(0, 6) }, row)
spNew("UIStroke", { Color = SP_STROKE, Thickness = 1 }, row)
local rankText = picked and ("#" .. tostring(rank)) or tostring(rank)
spNew("TextLabel", {
Size = UDim2.new(0, 26, 1, 0), Position = UDim2.new(0, 6, 0, 0),
BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11,
TextColor3 = picked and SP_GOLD or SP_DIM,
TextXAlignment = Enum.TextXAlignment.Left, Text = rankText,
}, row)
local iconBlock = spNew("Frame", {
Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(0, 34, 0, 8),
BackgroundColor3 = rcol, BorderSizePixel = 0,
}, row)
spNew("UICorner", { CornerRadius = UDim.new(0, 8) }, iconBlock)
local nameTxt = tostring(egg.Name or "?")
if egg.Kind == "Base" then nameTxt = nameTxt .. "  @" .. tostring(egg.OwnerName or "?") end
spNew("TextLabel", {
Size = UDim2.new(1, -236, 0, 22), Position = UDim2.new(0, 72, 0, 4),
BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13,
TextColor3 = SP_TEXT, TextXAlignment = Enum.TextXAlignment.Left,
TextTruncate = Enum.TextTruncate.AtEnd, Text = nameTxt,
}, row)
spNew("TextLabel", {
Size = UDim2.new(0, 74, 0, 22), Position = UDim2.new(1, -160, 0, 4),
BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12,
TextColor3 = SP_GREEN, TextXAlignment = Enum.TextXAlignment.Right,
Text = "$" .. fmtNum(egg.Value or 0) .. "/s",
}, row)
local dparts = { tostring(egg.RarityLabel or "?") }
if egg.Area and egg.Area ~= "" then dparts[#dparts + 1] = tostring(egg.Area) end
if type(egg.Mutations) == "table" and #egg.Mutations > 0 then
dparts[#dparts + 1] = table.concat(egg.Mutations, " ")
end
if egg.Pos and Movement.Pos() then
dparts[#dparts + 1] = tostring(math.floor((egg.Pos - Movement.Pos()).Magnitude + 0.5)) .. "m"
end
if egg.Kind == "Halloween" then dparts[1] = "Halloween" end
spNew("TextLabel", {
Size = UDim2.new(1, -236, 0, 16), Position = UDim2.new(0, 72, 0, 26),
BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 10,
TextColor3 = SP_DIM, TextXAlignment = Enum.TextXAlignment.Left,
TextTruncate = Enum.TextTruncate.AtEnd,
Text = table.concat(dparts, "  ·  "),
}, row)
local function actBtn(x, w, txt, col, cb)
local b = spNew("TextButton", {
Size = UDim2.new(0, w, 0, 24), Position = UDim2.new(1, x, 0, 11),
BackgroundColor3 = Color3.fromRGB(30, 36, 56), BorderSizePixel = 0,
Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = col, Text = txt,
}, row)
spNew("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
P(function() b.Activated:Connect(function() spClick() cb() end) end)
return b
end
local key = egg.Key
actBtn(-88, 22, "▲", picked and SP_GOLD or SP_DIM, function()
Steal.MoveInPlan(key, -1)
StealPanel.Refresh()
end)
actBtn(-64, 22, "▼", picked and SP_GOLD or SP_DIM, function()
Steal.MoveInPlan(key, 1)
StealPanel.Refresh()
end)
local starBtn = actBtn(-40, 22, "★", picked and SP_GOLD or SP_DIM, function()
if picked then
Steal.Cancel(key)
else
Steal.Prioritize(key)
end
StealPanel.Refresh()
end)
actBtn(-16, 22, "X", SP_RED, function()
Steal.Cancel(key)
StealPanel.Refresh()
end)
P(function()
row.Activated:Connect(function()
spClick()
Steal.Now(key)
Tasks.Status("steal", "Steal now: " .. tostring(egg.Name))
StealPanel.Refresh()
end)
end)
return { row = row, starBtn = starBtn, key = key }
end
function StealPanel.Refresh()
if not (StealPanel.list and StealPanel.open) then return end
for _, r in ipairs(StealPanel.rows) do
P(function() r.row:Destroy() end)
end
StealPanel.rows = {}
local targets = EggState.StealTargets()
local byKey = {}
for _, t in ipairs(targets) do byKey[t.Key] = t end
local ordered, seen = {}, {}
local plan = Steal.Plan()
local pickedSet = {}
for _, k in ipairs(Steal.pick) do pickedSet[k] = true end
for _, k in ipairs(plan) do
local egg = byKey[k]
if egg then
local show = true
if StealPanel.filter == "Halloween" then show = egg.Kind == "Halloween" end
if StealPanel.filter == "Field" then show = egg.Kind ~= "Halloween" and egg.Kind ~= "Base" end
if show then
seen[k] = true
ordered[#ordered + 1] = { egg = egg, picked = pickedSet[k] ~= nil }
end
end
end
if #ordered < 24 then
local sorted = StealPanelSortTargets(targets, Steal.priority)
for _, egg in ipairs(sorted) do
if #ordered >= 24 then break end
if not seen[egg.Key] then
local show = true
if StealPanel.filter == "Halloween" then show = egg.Kind == "Halloween" end
if StealPanel.filter == "Field" then show = egg.Kind ~= "Halloween" and egg.Kind ~= "Base" end
if show and egg.Kind ~= "Base" then
seen[egg.Key] = true
ordered[#ordered + 1] = { egg = egg, picked = false }
end
end
end
end
for i, item in ipairs(ordered) do
local r = spBuildRow(StealPanel.list, item.egg, i, item.picked)
StealPanel.rows[#StealPanel.rows + 1] = r
end
P(function()
local n = #StealPanel.rows
StealPanel.list.CanvasSize = UDim2.new(0, 0, 0, n * 52 + 6)
end)
if StealPanel.lblSort then
P(function() StealPanel.lblSort.Text = "Sort: " .. tostring(Steal.priority) end)
end
if StealPanel.rowSteal then
P(function()
StealPanel.rowSteal.Text = Steal.on and "Steal ✓" or "Steal"
StealPanel.rowSteal.BackgroundColor3 = Steal.on
and Color3.fromRGB(30, 120, 40) or Color3.fromRGB(30, 36, 56)
end)
end
if StealPanel.rowHw then
P(function()
StealPanel.rowHw.Text = HWX.on and "HW ✓" or "HW"
StealPanel.rowHw.BackgroundColor3 = HWX.on
and Color3.fromRGB(96, 52, 160) or Color3.fromRGB(30, 36, 56)
end)
end
if StealPanel.rowFilter then
P(function()
StealPanel.rowFilter.Text = StealPanel.filter == "All" and "All"
or (StealPanel.filter == "Halloween" and "Halloween" or "Field")
end)
end
end
function StealPanel.Show()
if not StealPanel.built then StealPanel.Build() end
if not StealPanel.root then return end
StealPanel.open = true
Config.Set("panel/open", true)
if type(Gill) == "table" then Gill.__THORHUB_PANEL_OPEN = true end
P(function()
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
Config.Set("panel/open", false)
if type(Gill) == "table" then Gill.__THORHUB_PANEL_OPEN = nil end
if not (StealPanel.root) then return end
P(function()
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
function StealPanel.Sync()
StealPanel.Refresh()
end
function StealPanel.Build()
StealPanel.Destroy()
destroyOldPanels()
local hud = spFindGameHud()
local btnGui = spNew("ScreenGui", {
ResetOnSpawn = false, DisplayOrder = 55, Name = spRandName(),
})
if gethui then
P(function() btnGui.Parent = gethui() end)
else
P(function() btnGui.Parent = LocalPlayer:FindFirstChildOfClass("PlayerGui") end)
end
StealPanel.btnGui = btnGui
local btn = nil
if hud then
local clone = spClone(hud.Pets)
if clone then
for _, d in ipairs(clone:GetChildren()) do
local n = tostring(d.Name)
if n == "Notification" or n == "ReadyNotification" or n == "NightImage"
or n == "NightText" or n == "ConsoleButton" or n == "Badge" then
P(function() d:Destroy() end)
end
end
P(function()
clone.Visible = true
clone.AnchorPoint = Vector2.new(0.5, 0.5)
clone.Parent = btnGui
end)
local lbl = P(function()
return clone:FindFirstChild("Label") or clone:FindFirstChildOfClass("TextLabel")
end)
if lbl then P(function() lbl.Text = "Steal" end) end
local grad = P(function() return clone:FindFirstChildOfClass("UIGradient") end)
if grad then
P(function()
grad.Color = SP_Theme.Toggle.Color
grad.Rotation = SP_Theme.Toggle.Rotation
end)
else
P(function()
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
P(function()
btn.Activated:Connect(function()
spClick()
StealPanel.Toggle()
end)
end)
if hud and StealPanel.mode == "hijack" then
local conn = P(function()
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
P(function()
btn.Position = UDim2.new(0.5, 0, 0, 80)
end)
end
local panelGui = spNew("ScreenGui", {
ResetOnSpawn = false, DisplayOrder = 56, Name = spRandName(), Enabled = false,
})
if gethui then
P(function() panelGui.Parent = gethui() end)
else
P(function() panelGui.Parent = LocalPlayer:FindFirstChildOfClass("PlayerGui") end)
end
StealPanel.panelGui = panelGui
local root, list, title, closeBtn
if hud then
local frame = spClone(hud.ActivePetsFrame)
if frame then
P(function() frame.Parent = panelGui end)
spRename(frame)
root = frame
StealPanel.origPos = P(function() return frame.Position end)
P(function()
for _, d in ipairs(frame:GetChildren()) do
local n = tostring(d.Name)
if n ~= "Header" and n ~= "ScrollingFrame" and n ~= "Close" then
d:Destroy()
end
end
end)
local header = P(function() return frame:FindFirstChild("Header")
or frame:FindFirstChildOfClass("Frame") end)
if header then
local lbl = P(function()
return header:FindFirstChild("Title")
or header:FindFirstChildOfClass("TextLabel")
end)
if lbl then
P(function() lbl.Text = "Steal Panel" end)
StealPanel.lblTitle = lbl
end
end
local close = P(function() return frame:FindFirstChild("Close") end)
if close then
local cl = P(function() return close:FindFirstChildOfClass("TextLabel")
or close:FindFirstChild("Label") end)
if cl then P(function() cl.Text = ">" end) end
P(function()
close.Activated:Connect(function()
spClick() StealPanel.Hide()
end)
end)
closeBtn = close
end
list = P(function() return frame:FindFirstChild("ScrollingFrame") end)
if list then
P(function()
for _, d in ipairs(list:GetChildren()) do
if d:IsA("GuiObject") then d:Destroy() end
end
end)
end
end
end
if not root then
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
local lbl = spNew("TextLabel", {
Size = UDim2.new(1, -80, 1, 0), Position = UDim2.new(0, 12, 0, 0),
BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 15,
TextColor3 = SP_TEXT, TextXAlignment = Enum.TextXAlignment.Left,
Text = "Steal Panel",
}, header)
StealPanel.lblTitle = lbl
closeBtn = spNew("TextButton", {
Size = UDim2.new(0, 30, 0, 26), Position = UDim2.new(1, -36, 0, 6),
BackgroundColor3 = Color3.fromRGB(30, 36, 56), Text = ">",
Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = SP_DIM,
BorderSizePixel = 0,
}, header)
spNew("UICorner", { CornerRadius = UDim.new(0, 6) }, closeBtn)
P(function()
closeBtn.Activated:Connect(function()
spClick() StealPanel.Hide()
end)
end)
end
StealPanel.root = root
local topRow = spNew("Frame", {
Size = UDim2.new(1, -16, 0, 30), Position = UDim2.new(0, 8, 0, 42),
BackgroundTransparency = 1,
}, root)
local topLayout = spNew("UIListLayout", {
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
P(function() b.Activated:Connect(function() spClick() cb() end) end)
return b
end
local sortBtn = topBtn(1, 118, "Sort: " .. tostring(Steal.priority), function()
local idx = table.find(StealPanel.SORTS, Steal.priority) or 4
local nxt = StealPanel.SORTS[idx % #StealPanel.SORTS + 1]
Steal.priority = nxt
local el = Config.Elements["farm/priority"]
if el and el.Set then P(function() el:Set(nxt, true) end) end
StealPanel.Refresh()
end)
StealPanel.lblSort = sortBtn
StealPanel.rowSteal = topBtn(2, 64, "Steal", function()
local el = Config.Elements["farm/steal"]
local newVal = not Steal.on
Steal.on = newVal
if el and el.Set then P(function() el:Set(newVal, true) end) end
if newVal then Tasks.Wake("steal") end
StealPanel.Refresh()
end)
StealPanel.rowHw = topBtn(3, 48, "HW", function()
local el = Config.Elements["admin/hwsteal"]
local newVal = not HWX.on
HWX.on = newVal
Steal.hwAuto = newVal
if el and el.Set then P(function() el:Set(newVal, true) end) end
StealPanel.Refresh()
end)
StealPanel.rowFilter = topBtn(4, 72, StealPanel.filter, function()
StealPanel.filter = (StealPanel.filter == "All" and "Halloween")
or (StealPanel.filter == "Halloween" and "Field") or "All"
StealPanel.Refresh()
end)
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
P(function()
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
end
Tasks.Add("stealpanel", 0.6, function()
if StealPanel.open then StealPanel.Refresh() end
end)
function StealPanel.Restore()
local saved = Config.Get("panel/open")
if saved == nil and type(Gill) == "table" then
saved = Gill.__THORHUB_PANEL_OPEN
end
if saved ~= false then
StealPanel.Show()
print("[ThorHub] 2 UI aktif: menu utama + Steal Panel (ala kode baru)")
end
end
ThorUI = nil
local THORUI_SRC = [==[
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local LocalPlayer = Players.LocalPlayer
local ThorUi = {
Version = "2.3.1",
}
local Theme = {
Background = Color3.fromRGB(11, 14, 23),
BackgroundAlt = Color3.fromRGB(16, 20, 32),
Card = Color3.fromRGB(21, 26, 41),
CardHover = Color3.fromRGB(28, 36, 56),
Track = Color3.fromRGB(36, 44, 66),
Accent = Color3.fromRGB(0, 195, 255),
AccentGold = Color3.fromRGB(255, 190, 0),
Text = Color3.fromRGB(240, 244, 255),
TextDim = Color3.fromRGB(145, 155, 180),
White = Color3.fromRGB(255, 255, 255),
Stroke = Color3.fromRGB(0, 150, 200),
StrokeDim = Color3.fromRGB(45, 58, 88),
Danger = Color3.fromRGB(255, 84, 84),
FontMain = Enum.Font.Gotham,
FontMedium = Enum.Font.GothamMedium,
FontBold = Enum.Font.GothamBold,
}
ThorUi.Theme = Theme
local TI_HOVER = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TI_SNAP = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TI_STRIKE = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TI_EXIT = TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
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
local function Create(className, props)
local inst = Instance.new(className)
if props then
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
local function ChevronIcon(parent, props)
props = props or {}
local px = props.Size or 12
local center = px * 0.5
local arm = math.max(6, px * 0.66)
local half = arm * 0.3536
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
local b1 = armFrame(-half, 45)
local b2 = armFrame(half, -45)
return box, b1, b2
end
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
local shine = Create("Frame", {
Position = UDim2.fromOffset(px(7) + 1, px(5)),
Size = UDim2.fromOffset(px(34) - 2, px(6)),
BackgroundColor3 = Theme.White,
BackgroundTransparency = 0.75,
BorderSizePixel = 0,
Parent = root,
})
Corner(shine, UDim.new(0, px(3)))
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
local handle = Create("Frame", {
Position = UDim2.fromOffset(px(20.5), px(21)),
Size = UDim2.fromOffset(px(7), px(23)),
BackgroundColor3 = Theme.White,
BorderSizePixel = 0,
Parent = root,
})
Corner(handle, UDim.new(0, px(3)))
Gradient(handle, Color3.fromRGB(147, 197, 253), Color3.fromRGB(37, 99, 235), 90)
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
local function Tween(registry, object, info, goal)
local tween = TweenService:Create(object, info, goal)
if registry then
registry:Track(tween)
end
tween:Play()
return tween
end
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
local function GetViewport()
local camera = workspace.CurrentCamera
if camera then
return camera.ViewportSize
end
return Vector2.new(1280, 720)
end
local function gestureInput(startInput, input)
if not startInput then
return false
end
if startInput.UserInputType == Enum.UserInputType.Touch then
return input == startInput
end
return input.UserInputType == Enum.UserInputType.MouseMovement
end
local function gestureEnded(startInput, input)
if startInput and startInput.UserInputType == Enum.UserInputType.Touch then
return input == startInput
end
return input.UserInputType == Enum.UserInputType.MouseButton1
end
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
local w = math.max(parent.AbsoluteSize.X - pad, 60)
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
scheduleFit(label, minH)
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
local StateClass = {}
StateClass.__index = StateClass
local function isThorState(v)
return type(v) == "table" and v._kind == "ThorState"
end
local DepRegistry = setmetatable({}, { __mode = "k" })
local AllGroups = {}
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
if visible and src._depSource and src._depVisible == false then
visible = false
end
el._depVisible = visible
local show = visible
if show and el.Section and el.Section.Collapsed then
show = false
end
if el.Instance then
el.Instance.Visible = show
end
evaluateDepsOf(el)
end
local function registerDependency(el, cfg)
if type(cfg) ~= "table" then
return
end
local src = cfg.Element or cfg.State or cfg.Source
if src == nil then
return
end
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
el:Set(true)
end
end
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
if self.Value == nil then
self.Value = sourceValue(target)
end
link._pushing = true
pushLink(link, self.Value)
link._pushing = false
return link
end
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
local _state = {
Gui = nil,
NotifyHolder = nil,
ToggleButton = nil,
TogglePulse = nil,
Logo = nil,
ToggleKey = Enum.KeyCode.RightControl,
ToggleVisible = true,
KeyConn = nil,
Windows = {},
Notifs = {},
Registry = Registry.new(),
SplashDone = false,
SplashActive = false,
}
local TOGGLE_SIZE = 48
local function ensureGui()
if _state.Gui and _state.Gui.Parent then
return _state.Gui
end
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
function ThorUi:Notify(cfg)
if not LocalPlayer then
warn("[ThorUi] Notify hanya bisa dipanggil dari client.")
return nil
end
cfg = cfg or {}
local holder = ensureNotifyHolder()
local container = Create("Frame", {
BackgroundTransparency = 1,
Size = UDim2.new(0, 300, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
LayoutOrder = #_state.Notifs + 1,
Parent = holder,
})
local notif = Create("CanvasGroup", {
Position = UDim2.new(1, 0, 0, 0),
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
GroupTransparency = 1,
BackgroundColor3 = Theme.BackgroundAlt,
BorderSizePixel = 0,
Parent = container,
})
Corner(notif, 10)
Stroke(notif, { Color = Theme.Stroke, Transparency = 0.3 })
local bar = Create("Frame", {
Size = UDim2.new(0, 3, 1, 0),
BackgroundColor3 = Theme.White,
BorderSizePixel = 0,
ZIndex = 3,
Parent = notif,
})
Corner(bar, UDim.new(1, 0))
Gradient(bar, Theme.AccentGold, Theme.Accent, 90)
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
if #_state.Notifs > 5 then
despawnNotification(_state.Notifs[1], true)
end
task.spawn(function()
RunService.RenderStepped:Wait()
RunService.RenderStepped:Wait()
if not container.Parent or entry.Dead then
return
end
Tween(_state.Registry, notif, TI_STRIKE, { Position = UDim2.new(0, 0, 0, 0) })
Tween(_state.Registry, notif, TI_SNAP, { GroupTransparency = 0 })
end)
entry.Task = task.delay((cfg.Duration or 4) + 0.45, function()
despawnNotification(entry, false)
end)
container.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1
or input.UserInputType == Enum.UserInputType.Touch then
despawnNotification(entry, false)
end
end)
return entry
end
local function toggleWindows()
if #_state.Windows == 0 then
return
end
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
_state.KeyConn = _state.Registry:Connect(UserInputService.InputBegan, function(input, processed)
if processed then
return
end
if input.KeyCode == _state.ToggleKey then
toggleWindows()
end
end)
end
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
AnchorPoint = Vector2.new(0.5, 0.5),
Position = UDim2.new(1, -16 - TOGGLE_SIZE * 0.5, 0.72, 0),
Size = UDim2.fromOffset(TOGGLE_SIZE, TOGGLE_SIZE),
BackgroundColor3 = Theme.White,
BorderSizePixel = 0,
Visible = _state.ToggleVisible,
Parent = gui,
})
Corner(btn, UDim.new(1, 0))
Gradient(btn, Theme.Card, Theme.BackgroundAlt, 45)
Stroke(btn, { Color = Theme.Accent, Thickness = 1.5, Transparency = 0.1 })
MakeLogo(btn, {
Size = 26,
AnchorPoint = Vector2.new(0.5, 0.5),
Position = UDim2.new(0.5, 0, 0.5, 0),
}, _state.Logo)
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
local dragging = false
local moved = false
local startInput = nil
local startVec = nil
local startOffset = nil
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
if not gestureInput(startInput, input) then
return
end
if startVec.X == 0 and startVec.Y == 0 and startVec.Z == 0 then
startVec = input.Position
end
local delta = input.Position - startVec
if math.abs(delta.X) > 6 or math.abs(delta.Y) > 6 then
if not moved then
moved = true
Tween(reg, scale, TI_HOVER, { Scale = 1.15 })
end
end
local vp = GetViewport()
local halfX = (btn.AbsoluteSize.X > 0 and btn.AbsoluteSize.X or TOGGLE_SIZE) * 0.5
local halfY = (btn.AbsoluteSize.Y > 0 and btn.AbsoluteSize.Y or TOGGLE_SIZE) * 0.5
local nx = math.clamp(startOffset.X + delta.X, 4 + halfX, math.max(4 + halfX, vp.X - halfX - 4))
local ny = math.clamp(startOffset.Y + delta.Y, 4 + halfY, math.max(4 + halfY, vp.Y - halfY - 4))
btn.Position = UDim2.new(0, math.floor(nx + 0.5), 0, math.floor(ny + 0.5))
end)
reg:Connect(UserInputService.InputEnded, function(input)
if not dragging then
return
end
if not gestureEnded(startInput, input) then
return
end
dragging = false
if moved then
Tween(reg, scale, TI_SNAP, { Scale = 1 })
else
popScale()
toggleWindows()
end
end)
_state.ToggleButton = btn
return btn
end
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
function ThorUi:SetTheme(patch)
if type(patch) == "table" then
for k, v in pairs(patch) do
Theme[k] = v
end
end
return Theme
end
function ThorUi:SetLogo(cfg)
_state.Logo = (type(cfg) == "table") and cfg or nil
return _state.Logo
end
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
reg:Connect(dock:GetPropertyChangedSignal("AbsoluteSize"), function()
local vp = GetViewport()
local p = dock.Position
local x = math.min(p.X.Offset, vp.X - 20)
local y = math.clamp(p.Y.Offset, 40, math.max(40, vp.Y - 40))
dock.Position = UDim2.new(0, x, 0, y)
end)
return dock
end
local function bindQuickButton(reg, btn, onTap)
local dragging = false
local moved = false
local startInput = nil
local startVec = nil
local startPos = nil
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
local circle = Create("Frame", {
Size = UDim2.fromOffset(88, 88),
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
BackgroundColor3 = Theme.White,
BorderSizePixel = 0,
Parent = barTrack,
})
Corner(barFill, UDim.new(1, 0))
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
Tween(reg, overlay, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0 })
Tween(reg, circleScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
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
local TabClass = {}
TabClass.__index = TabClass
function TabClass.new(window, cfg)
cfg = cfg or {}
local reg = Registry.new()
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
local indicator = Create("Frame", {
AnchorPoint = Vector2.new(0, 0.5),
Position = UDim2.new(0, 0, 0.5, 0),
Size = UDim2.new(0, 3, 0, 0),
BackgroundColor3 = Theme.White,
BorderSizePixel = 0,
Parent = btn,
})
Corner(indicator, UDim.new(1, 0))
Gradient(indicator, Theme.AccentGold, Theme.Accent, 90)
local icon = Create("TextLabel", {
BackgroundTransparency = 1,
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
Sections = {},
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
function TabClass:_track(element)
local tab = self
table.insert(tab.Elements, element)
tab:_own(element)
function element:Remove()
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
end
end
function TabClass:_own(element)
local sec = self._currentSection
if sec and sec.Members then
element.Section = sec
table.insert(sec.Members, element)
if sec.Collapsed and element.Instance then
element.Instance.Visible = false
end
end
end
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
if el.Section and el.Section.Collapsed then
visible = false
end
if el._depVisible == false then
visible = false
end
el.Instance.Visible = visible
end
end
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
TextSize = 12,
TextColor3 = Theme.TextDim,
TextWrapped = true,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
LayoutOrder = order,
Parent = card,
})
autoFitText(label, 14)
end
label.Visible = true
label.Text = tostring(text)
end
end
local CHILD_FACTORIES = {
Button = "AddButton",
Toggle = "AddToggle",
Slider = "AddSlider",
Dropdown = "AddDropdown",
TextInput = "AddTextInput",
Keybind = "AddKeybind",
ColorPicker = "AddColorPicker",
Label = "AddLabel",
Paragraph = "AddParagraph",
List = "AddList",
ModelView = "AddModelView",
Canvas = "AddCanvas",
}
local function normalizeChildKind(kind)
local k = tostring(kind or "")
k = k:gsub("^%l", string.upper)
return CHILD_FACTORIES[k] and k or nil
end
local function EnableChildren(tab, element, cfg, row, titleLabel, mode, yCenter)
element.Children = {}
local subHost = nil
local chevBtn = nil
local chevron, chevA, chevB = nil, nil, nil
local expanded = false
local function buildSubUI()
if subHost then
return
end
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
chevron.Rotation = -90
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
element.Registry:Connect(subHost:GetPropertyChangedSignal("AbsoluteContentSize"), function()
local lay = subHost:FindFirstChildOfClass("UIListLayout")
local h = lay and lay.AbsoluteContentSize.Y or 0
guide.Size = UDim2.fromOffset(2, math.max(0, h))
end)
end
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
p._currentSection = tab._currentSection
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
function TabClass:AddSlider(cfg)
cfg = cfg or {}
local reg = Registry.new()
local card, stroke = self:_card()
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
local setDesc = attachDescription(card, 2)
setDesc(cfg.Description)
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
BackgroundColor3 = Theme.White,
BorderSizePixel = 0,
Parent = track,
})
Corner(fill, UDim.new(1, 0))
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
local element
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
function TabClass:AddDropdown(cfg)
cfg = cfg or {}
local reg = Registry.new()
local card = self:_card()
local multi = cfg.Multi == true
local state = {
Value = multi and {} or nil,
Callback = cfg.Callback,
}
local element
local applyLabel = nil
if cfg.ApplyButton then
applyLabel = (cfg.ApplyButton == true) and "Apply"
or tostring(cfg.ApplyButton)
end
local applyMode = applyLabel ~= nil
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
BackgroundTransparency = 1,
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
local arrow, arrowA, arrowB = ChevronIcon(header, {
AnchorPoint = Vector2.new(1, 0.5),
Position = UDim2.new(1, -1, 0.5, 0),
Size = 10,
Color = Theme.TextDim,
})
local setDesc = attachDescription(card, 2)
setDesc(cfg.Description)
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
local function buildOptions(values)
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
Size = UDim2.new(1, 0, 0, 28),
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
SetValues = function(_, values)
local valid = {}
for _, v in ipairs(values or {}) do
valid[#valid + 1] = v
end
buildOptions(valid)
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
return
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
BackgroundTransparency = 1,
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
BackgroundTransparency = 1,
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
local setDesc = attachDescription(card, 2)
setDesc(cfg.Description)
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
local svBox = Create("Frame", {
Size = UDim2.new(1, 0, 0, 110),
BackgroundColor3 = Color3.fromHSV(state.H, 1, 1),
BorderSizePixel = 0,
ClipsDescendants = true,
Active = true,
LayoutOrder = 1,
Parent = panel,
})
Corner(svBox, 8)
local svStroke = Stroke(svBox, { Color = Theme.StrokeDim, Transparency = 0.3 })
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
local hueBar = Create("Frame", {
Size = UDim2.new(1, 0, 0, 14),
BackgroundColor3 = Theme.White,
BorderSizePixel = 0,
Active = true,
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
local chevron, chevA, chevB = ChevronIcon(row, {
AnchorPoint = Vector2.new(1, 0.5),
Position = UDim2.new(1, -3, 0.5, 0),
Size = 12,
Color = Theme.AccentGold,
})
local setDesc = attachDescription(holder, 2)
setDesc(cfg.Description)
local line = Create("Frame", {
BackgroundColor3 = Theme.White,
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
Members = {},
Collapsed = true,
}
local function applyVisibility()
local members = el.Members
for i = #members, 1, -1 do
local m = members[i]
if not m.Instance or not m.Instance.Parent then
table.remove(members, i)
else
m.Instance.Visible = not el.Collapsed
and m._depVisible ~= false
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
self._currentSection = el
table.insert(self.Sections, el)
if cfg.Collapsed == false then
el.Collapsed = false
else
el.Collapsed = true
chevron.Rotation = -90
end
return el
end
function TabClass:AddLabel(cfg)
cfg = cfg or {}
local lbl = Create("TextLabel", {
BackgroundTransparency = 1,
Size = UDim2.new(1, 0, 0, 14),
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
el.SetText = function(text)
lbl.Text = tostring(text)
end
function el:Remove()
if self.Instance and self.Instance.Parent then
self.Instance:Destroy()
end
end
self:_own(el)
return el
end
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
el.SetText = function(text)
body.Text = tostring(text)
end
function el:Remove()
if self.Instance and self.Instance.Parent then
self.Instance:Destroy()
end
end
self:_own(el)
return el
end
function TabClass:AddList(cfg)
cfg = cfg or {}
local reg = Registry.new()
local card = self:_card()
local element
local multi = cfg.Multi == true
local selected = {}
local itemRows = {}
local maxH = tonumber(cfg.MaxHeight) or 180
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
local gold = Color3.fromRGB(251, 191, 36)
local goldDeep = Color3.fromRGB(180, 83, 9)
local blue = Color3.fromRGB(37, 99, 235)
local blueLight = Color3.fromRGB(147, 197, 253)
part(Vector3.new(0.9, 1.5, 1.5), gold, Enum.Material.Metal, Vector3.new(0, 2.55, 0))
part(Vector3.new(0.5, 1.62, 1.62), gold, Enum.Material.Metal, Vector3.new(0, 2.55, 0))
part(Vector3.new(0.96, 0.18, 1.56), goldDeep, Enum.Material.Metal, Vector3.new(0, 3.22, 0))
part(Vector3.new(0.96, 0.18, 1.56), goldDeep, Enum.Material.Metal, Vector3.new(0, 1.88, 0))
part(Vector3.new(0.42, 1.9, 0.42), blue, Enum.Material.Metal, Vector3.new(0, 1.0, 0))
part(Vector3.new(0.5, 0.14, 0.5), blueLight, Enum.Material.Metal, Vector3.new(0, 1.85, 0))
part(Vector3.new(0.5, 0.14, 0.5), blueLight, Enum.Material.Metal, Vector3.new(0, 0.28, 0))
part(Vector3.new(0.56, 0.3, 0.56), gold, Enum.Material.Metal, Vector3.new(0, 0.06, 0))
return m
end
setModel(cfg.Model or buildDefaultMjolnir())
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
BackgroundColor3 = Theme.White,
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
local WindowClass = {}
WindowClass.__index = WindowClass
local SIDEBAR_W = 156
local SIDEBAR_MIN = 48
local HEADER_H = 46
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
local minSize = cfg.MinSize or Vector2.new(400, 250)
minSize = Vector2.new(
math.min(minSize.X, math.max(viewport.X - 56, 220)),
math.min(minSize.Y, math.max(viewport.Y - 56, 160))
)
local size = cfg.Size
if not size then
local w = math.min(440, viewport.X * 0.86, viewport.Y * 0.62)
local h = math.min(390, viewport.Y * 0.62, w * 1.15)
w = math.min(w, viewport.X - 24)
h = math.min(h, viewport.Y - 24)
size = UDim2.fromOffset(math.floor(w + 0.5), math.floor(h + 0.5))
end
local frame = Create("Frame", {
Name = "ThorUi_Window",
AnchorPoint = Vector2.new(0.5, 0.5),
Position = cfg.Position or UDim2.new(0.5, 0, 0.5, 0),
Size = size,
BackgroundColor3 = Theme.Background,
BorderSizePixel = 0,
ClipsDescendants = true,
Active = true,
Visible = false,
Parent = gui,
})
Corner(frame, 12)
Stroke(frame, { Color = Theme.Stroke, Thickness = 1, Transparency = 0.15 })
local sizeConstraint = Create("UISizeConstraint", { MinSize = minSize, Parent = frame })
local uiScale = Create("UIScale", { Parent = frame })
local sidebar = Create("Frame", {
Name = "Sidebar",
Size = UDim2.new(0, SIDEBAR_W, 1, 0),
BackgroundColor3 = Theme.White,
BorderSizePixel = 0,
Active = true,
Parent = frame,
})
Gradient(sidebar, Theme.BackgroundAlt, Theme.Background, 90)
local logoRow = Create("Frame", {
Name = "LogoRow",
Size = UDim2.new(1, 0, 0, 54),
BackgroundTransparency = 1,
Active = true,
Parent = sidebar,
})
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
local logoDivider = Create("Frame", {
Position = UDim2.new(0, 10, 0, 54),
Size = UDim2.new(1, -20, 0, 1),
BackgroundColor3 = Theme.Stroke,
BackgroundTransparency = 0.55,
BorderSizePixel = 0,
Parent = sidebar,
})
local tabList = Create("ScrollingFrame", {
Name = "TabList",
Position = UDim2.new(0, 0, 0, 62),
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
BackgroundColor3 = Theme.White,
BorderSizePixel = 0,
Parent = right,
})
Gradient(header, Theme.BackgroundAlt, Theme.Background, 90)
local dragStrip = Create("Frame", {
Name = "DragStrip",
Size = UDim2.new(1, 0, 1, 0),
BackgroundTransparency = 1,
Active = true,
Parent = header,
})
local searchWrap = Create("Frame", {
AnchorPoint = Vector2.new(0, 0.5),
Position = UDim2.new(0, 10, 0.5, 0),
Size = UDim2.new(1, -90, 0, 30),
BackgroundColor3 = Theme.Card,
BorderSizePixel = 0,
Active = true,
Parent = header,
})
Corner(searchWrap, 8)
local searchStroke = Stroke(searchWrap, { Color = Theme.StrokeDim, Transparency = 0.35 })
Create("TextLabel", {
BackgroundTransparency = 1,
Position = UDim2.new(0, 8, 0, 1),
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
Position = UDim2.new(0, 0, 0, 1),
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
local collapseBtn, collapseLabel = makeControl("—", -44, Theme.AccentGold, function()
Zap(reg, collapseBtn, Theme.AccentGold, 8)
self:SetCollapsed(not self.Collapsed)
end)
self.CollapseLabel = collapseLabel
local closeBtn = makeControl("✕", -6, Theme.Danger, function()
Zap(reg, closeBtn, Theme.Danger, 8)
self:Hide()
end)
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
local thunderLine = Create("Frame", {
Position = UDim2.new(0, 0, 0, HEADER_H),
Size = UDim2.new(1, 0, 0, 1),
BackgroundColor3 = Theme.White,
BorderSizePixel = 0,
ZIndex = 2,
Parent = right,
})
Gradient(thunderLine, Theme.AccentGold, Theme.Accent, 0, NumberSequence.new({
NumberSequenceKeypoint.new(0, 0),
NumberSequenceKeypoint.new(1, 0.9),
}))
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
reg:Connect(frame:GetPropertyChangedSignal("AbsoluteSize"), function()
self:_updateResponsive()
end)
table.insert(_state.Windows, self)
bindToggleKey(cfg.Keybind)
if cfg.ShowToggle ~= false then
_state.ToggleVisible = true
ensureToggleButton()
ThorUi:SetToggleVisible(true)
end
self:_updateResponsive()
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
tab.Indicator.Size = UDim2.new(0, 3, 0, 0)
Tween(self.Registry, tab.Indicator, TI_STRIKE, { Size = UDim2.new(0, 3, 0, 18) })
tab.Container.Position = UDim2.new(0, 0, 0, 8)
Tween(self.Registry, tab.Container, TI_SNAP, { Position = UDim2.new(0, 0, 0, 0) })
self.Content.CanvasPosition = Vector2.new(0, 0)
tab:ApplyFilter(self._searchQuery or "")
end
function WindowClass:Show()
self._closing = false
if self.Frame.Visible and (self.UiScale.Scale or 1) >= 0.99 then
return
end
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
if self._closing or not self.Frame.Visible then
self:Show()
else
self:Hide()
end
end
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
function WindowClass:_updateResponsive()
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
self.LogoMark.Position = narrow
and UDim2.new(0.5, 0, 0.5, 0)
or UDim2.new(0, 12 + (self._logoSize or 22) / 2, 0.5, 0)
self.VersionLabel.Visible = not narrow and not self.Collapsed
for _, t in ipairs(self.Tabs) do
t.Label.Visible = not narrow
t.Icon.Position = narrow
and UDim2.new(0.5, -9, 0, 1)
or UDim2.new(0, 10, 0, 1)
end
if self.Collapsed then
setSizeKeepTopLeft(self.Frame, Vector2.new(w, self.Frame.AbsoluteSize.Y))
end
end
function WindowClass:_applySearch(text)
self._searchQuery = tostring(text or "")
if self._activeTab then
self._activeTab:ApplyFilter(self._searchQuery)
end
end
function WindowClass:Confirm(cfg)
cfg = cfg or {}
local gui = self.Gui or self.Frame.Parent
if not gui then
return
end
local reg = Registry.new()
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
local vp = GetViewport()
local card = Create("CanvasGroup", {
AnchorPoint = Vector2.new(0.5, 0.5),
Position = UDim2.new(0.5, 0, 0.5, 0),
Size = UDim2.new(0, math.min(320, math.max(220, math.floor(vp.X - 30))), 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
BackgroundColor3 = Theme.BackgroundAlt,
BorderSizePixel = 0,
GroupTransparency = 1,
Active = true,
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
reg:Connect(bgBtn.Activated, function()
close(false)
end)
Tween(reg, bgBtn, TI_SNAP, { BackgroundTransparency = 0.45 })
Tween(reg, card, TI_SNAP, { GroupTransparency = 0 })
Tween(reg, cardScale, TI_STRIKE, { Scale = 1 })
end
function WindowClass:Destroy()
for _, o in ipairs(self._overlays) do
o.Reg:Clean()
if o.Overlay.Parent then
o.Overlay:Destroy()
end
end
self._overlays = {}
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
if #_state.Windows == 0 then
ThorUi:SetToggleVisible(false)
end
end
function ThorUi:Destroy()
local windows = {}
for _, w in ipairs(_state.Windows) do
table.insert(windows, w)
end
for _, w in ipairs(windows) do
w:Destroy()
end
local notifs = {}
for _, n in ipairs(_state.Notifs) do
table.insert(notifs, n)
end
for _, n in ipairs(notifs) do
despawnNotification(n, true)
end
_state.SplashActive = false
_state.Registry:Clean()
_state.KeyConn = nil
_state.TogglePulse = nil
if _state.Gui then
_state.Gui:Destroy()
end
_state.Gui = nil
_state.NotifyHolder = nil
_state.ToggleButton = nil
_state.QuickDock = nil
_state.Windows = {}
_state.Notifs = {}
end
return ThorUi

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
if type(warn) == "function" then
warn("[ThorHub] ThorUi versi lama terdeteksi: " .. tostring(ThorUI.Version))
end
end
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
matched = matched + 1
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
local pending = Repo.Invoke("RF/AwayEarnings/PendingCheck")
local has = (type(pending) == "number" and pending > 0)
or (type(pending) == "table" and pending.amount ~= nil)
if has then
local ok = Repo.Invoke("RF/AwayEarnings/AskCollect")
Tasks.Status("progress", ok and "Uang offline diklaim" or "Tidak ada uang offline")
else
Tasks.Status("progress", "Tidak ada uang offline menunggu")
end
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
local function mkStatus(tab, taskName, initial)
local e = tab:AddLabel({ Text = initial or "Idle" })
SetStatusOwner(taskName, {
SetText = function(_, text)
P(function() e:Set(text) end)
end,
})
return e
end
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
local eggSpecies, petSpecies = Repo.Species()
if #eggSpecies == 0 then eggSpecies = { "(data tidak tersedia)" } end
if #petSpecies == 0 then petSpecies = { "(data tidak tersedia)" } end
local rarityChoices = {}
do
table.insert(rarityChoices, "Off")
for _, r in ipairs(Repo.RarityOrder) do table.insert(rarityChoices, r) end
end
local areaNames = Repo.AreaNames()
local rarityAny = { "Any" }
for _, r in ipairs(Repo.RarityOrder) do table.insert(rarityAny, r) end
local function rarityNumAny(label)
if type(label) ~= "string" or label == "Any" then return 0 end
return Repo.Rarity[label] or 0
end
local MUT_DISPLAY = { "Fractured", "Scrambled", "Enchanted", "Nitro", "Spectral" }
local MUT_TO_ID = { Fractured = "Boss", Scrambled = "Scrambled",
Enchanted = "Enchanted", Nitro = "Nitro", Spectral = "Spectral" }
local BUTTER_LIST = { "Radiant Butterfly", "Amethyst Butterfly",
"Sapphire Butterfly", "Emerald Butterfly" }
local BUTTER_TO_ID = { ["Radiant Butterfly"] = "Golden", ["Amethyst Butterfly"] = "Purple",
["Sapphire Butterfly"] = "Blue", ["Emerald Butterfly"] = "Green" }
local HW_RARITIES = { "Epic", "Legendary", "Mythic", "Cosmic", "Secret", "Eternal", "Divine" }
local HW_MONS = { "Candy Corn (+12 Candy)", "Hollow Bat (+12 Candy)", "Scarecrow (+28 Candy)",
"Chest Mimic (+28 Candy)", "Pumpkin Golem (+65 Candy)", "Soul Phantom (+65 Candy)" }
local playerNames = {}
local function refreshPlayerNames()
playerNames = {}
for _, p in ipairs(Players:GetPlayers()) do
if p ~= LocalPlayer then table.insert(playerNames, tostring(p.Name)) end
end
if #playerNames == 0 then playerNames = { "(tidak ada pemain)" } end
end
refreshPlayerNames()
Tasks.Add("hwstatus", 2.0, function()
if not HWX.on then
Tasks.Status("hwstatus", "Off")
return
end
local eggs = EggState.HalloweenEggs()
local txt = tostring(#eggs) .. " Halloween egg(s) visible"
if HWX.holders then
for _, plr in ipairs(Players:GetPlayers()) do
if plr ~= LocalPlayer then
local tool = P(function()
local ch = plr.Character
return ch and ch:FindFirstChildOfClass("Tool")
end)
local hwUid = tool and P(function()
return tool:GetAttribute("HalloweenEggUid")
or tool:GetAttribute("EggUid") or tool:GetAttribute("UID")
end)
if hwUid then
txt = txt .. "  |  held by " .. tostring(plr.DisplayName)
if not Steal.busy then
local root = Movement.Root()
local tPos = root and P(function()
return plr.Character and plr.Character
:FindFirstChild("HumanoidRootPart").Position
end)
if root and tPos then
P(function() root.CFrame = CFrame.new(tPos + Vector3.new(0, 2, 0)) end)
local holderChar = plr.Character
local prompt = nil
for _, m in ipairs(workspace:GetChildren()) do
local isEggModel = P(function()
return m:IsA("Model") and #m.Name == 32 end)
if isEggModel and holderChar then
local welded = P(function()
for _, j in ipairs(m:GetDescendants()) do
if j:IsA("JointInstance") or j:IsA("WeldConstraint") or j:IsA("RigidConstraint") then
local p0, p1 = j.Part0, j.Part1
for _, part in ipairs({ p0, p1 }) do
if typeof(part) == "Instance" and part:IsDescendantOf(holderChar) then
return true
end
end
end
end
return false
end)
if welded then
prompt = P(function()
return m:FindFirstChild("StealPrompt", true)
or m:FindFirstChildOfClass("ProximityPrompt", true)
end)
break
end
end
end
if not prompt and tool then
prompt = P(function()
return tool:FindFirstChildOfClass("ProximityPrompt", true)
end)
end
if prompt then P(function() firePromptInstance(prompt) end) end
end
end
break
end
end
end
end
Tasks.Status("hwstatus", txt)
end)
Tasks.Add("prioqueue", 2.0, function()
local on = {}
local checks = {
{ "steal", function() return Steal.on end },
{ "mutate", function() return Mutate.on end },
{ "place", function() return Place.on end },
{ "hatch", function() return Hatch.on end },
{ "sell", function() return Sell.petOn or Sell.eggOn end },
{ "fuse", function() return Fuse.on end },
{ "favorite", function() return Fav.on end },
{ "shooting star", function() return Star.on end },
{ "butterflies", function() return Butter.on end },
{ "wisp", function() return Wisp.on end },
{ "banjo", function() return Banjo.on end },
{ "auto hop", function() return AutoHop.on end },
{ "treadmill", function() return Tread.on or Tread.upgrade end },
{ "progress", function()
return Progress.upBase or Progress.claimCash or Progress.claimIndex
or Progress.buyTrail end },
{ "capture", function() return Capture.on end },
{ "minigame", function() return Minigame.on end },
{ "hollow", function() return Hollow.on end },
{ "phantom express", function() return Express.on end },
{ "monsters", function() return HwMon.on end },
{ "pumpkin", function() return HwPump.on or PBoss.on end },
{ "ghost dog", function() return HwDog.on end },
{ "fishing", function() return HwFish.on end },
{ "rotation", function() return Rotation.on end },
{ "combat", function() return Combat.on end },
{ "island wars", function() return CIW.on end },
}
for _, c in ipairs(checks) do
local ok, active = pcall(c[2])
if ok and active then on[#on + 1] = c[1] end
end
Tasks.Status("prioqueue", #on > 0
and ("Active: " .. table.concat(on, ", "))
or ("Idle  |  " .. #checks .. " task slot"))
end)
Tasks.Add("invval", 3.0, function()
if not (ESP.invValues and Perf.hud) then return end
local total = 0
for _, e in pairs(EggState.OwnEggs()) do
total = total + (Repo.EggValue(e.AssetCategory, e.AssetScale or 1, e.Mutations or {}) or 0)
end
P(function()
local lbl = Perf.hud:FindFirstChildOfClass("TextLabel")
if lbl then
local base = string.gsub(lbl.Text, "  |  Inv .*", "")
lbl.Text = base .. "  |  Inv $" .. fmtNum(total) .. "/s"
end
end)
end)
local FarmTab = Window:CreateTab({ Name = "Farm", Icon = "⚡" })
mkSection(FarmTab, "Auto Steal")
mkToggle(FarmTab, "farm/steal", "Auto Steal", false, function(v)
Steal.on = v
Tasks.Wake("steal")
end)
local deliveryEl = mkDropdown(FarmTab, "farm/delivery", "Delivery",
{ "Tween", "Instant Steps", "Fast Tween" }, "Tween",
function(v) Steal.delivery = v end)
local delSpeedEl = mkSlider(FarmTab, "farm/delspeed", "Delivery Speed", 80, 110, 100, 1, "%",
function(v) Steal.carryK = v / 100 end)
local stepCountEl = mkSlider(FarmTab, "farm/steps", "Step Count", 1, 6, 3, 1, "",
function(v) Steal.instantSteps = v end)
local fastTweenEl = mkSlider(FarmTab, "farm/fasttween", "Fast Tween Speed", 3000, 4500, 3300, 50, "",
function(v) Steal.pullSpeed = v end)
P(function()
if delSpeedEl.SetDependency then
delSpeedEl:SetDependency({ Element = deliveryEl, Value = "Tween" })
stepCountEl:SetDependency({ Element = deliveryEl, Value = "Instant Steps" })
fastTweenEl:SetDependency({ Element = deliveryEl, Value = "Fast Tween" })
end
end)
mkMulti(FarmTab, "farm/areas", "Target Areas", areaNames, function(l) Steal.areas = listToSet(l) end, nil, areaNames)
mkDropdown(FarmTab, "farm/minrarity", "Min Rarity", rarityAny, "Any",
function(v) Steal.minRarity = rarityNumAny(v) end)
mkSlider(FarmTab, "farm/minvalue", "Min Steal Value", 0, 100000, 0, 500, "/s",
function(v) Steal.minValue = v end)
mkMulti(FarmTab, "farm/specific", "Target Specific Eggs", eggSpecies, function(l) Steal.specific = listToSet(l) end)
mkToggle(FarmTab, "farm/missing", "Steal Missing Index Eggs", false, function(v) Steal.missingIndex = v end)
mkToggle(FarmTab, "farm/dropsafe", "Drop Eggs At Safe Zone", false, function(v) Steal.dropSafe = v end)
mkToggle(FarmTab, "farm/agpanel", "Anti Guard Panel", true, function(v) Steal.agPanel = v end)
mkDropdown(FarmTab, "farm/priority", "Steal Priority",
{ "Best Rarity", "Biggest Weight", "Best Mutation", "Highest Value", "Lowest Value" },
"Highest Value", function(v) Steal.priority = v end)
mkSection(FarmTab, "Auto Progression")
mkToggle(FarmTab, "prog/buytrail", "Auto Buy Trail", false, function(v)
Progress.buyTrail = v Tasks.Wake("progress")
end)
mkToggle(FarmTab, "prog/upbase", "Auto Upgrade Base", false, function(v)
Progress.upBase = v Tasks.Wake("progress")
end)
mkToggle(FarmTab, "prog/uptread", "Auto Upgrade Treadmill", false, function(v)
Tread.upgrade = v Tasks.Wake("progress")
end)
mkToggle(FarmTab, "prog/claimcash", "Auto Claim Money", false, function(v)
Progress.claimCash = v Tasks.Wake("progress")
end)
mkToggle(FarmTab, "prog/claimindex", "Auto Claim Index", false, function(v)
Progress.claimIndex = v Tasks.Wake("progress")
end)
mkSection(FarmTab, "Auto Mutation")
mkToggle(FarmTab, "farm/mutate", "Auto Mutate", false, function(v) Mutate.on = v Tasks.Wake("mutate") end)
mkMulti(FarmTab, "farm/mutlist", "Mutations To Use", MUT_DISPLAY, function(l)
Mutate.use = {}
for _, disp in ipairs(l) do
local id = MUT_TO_ID[disp]
if id then Mutate.use[id] = true end
end
end, "Use items")
mkDropdown(FarmTab, "farm/mutrarity", "Mutate Min Rarity", rarityAny, "Any",
function(v) Mutate.minRarity = rarityNumAny(v) end,
"Only eggs of this rarity and above get mutated")
mkSlider(FarmTab, "farm/mutvalue", "Mutate Min Value", 0, 100000, 0, 500, "/s",
function(v) Mutate.minValue = v end, "Skip eggs worth less than this (0 = off)")
mkMulti(FarmTab, "farm/muttarget", "Mutate Target Eggs", eggSpecies, function(l) Mutate.targets = listToSet(l) end,
"Only mutate these eggs (empty = all)")
mkDropdown(FarmTab, "farm/mutprio", "Mutate Priority",
{ "Highest Value", "Best Rarity", "Biggest Size" }, "Highest Value",
function(v) Mutate.priority = v end, "Which egg gets mutated first")
mkStatus(FarmTab, "mutate", "Mutate Status  |  Off")
mkSection(FarmTab, "Auto Place Egg")
mkToggle(FarmTab, "farm/place", "Auto Place Egg", false, function(v) Place.on = v Tasks.Wake("place") end,
"Auto place")
mkDropdown(FarmTab, "farm/placerule", "Place Egg Rule",
{ "Always", "Steal Idle", "After Steal", "Night Only" }, "Always", function(v) Place.rule = v end,
"Place when")
mkDropdown(FarmTab, "farm/placeorder", "Place Egg Order",
{ "Biggest Size", "Highest Value", "Smallest Size" }, "Biggest Size", function(v) Place.order = v end,
"Place first")
mkMulti(FarmTab, "farm/placerarity", "Place Rarities", Repo.RarityOrder,
function(l) Place.rarities = listToSet(l) end, nil, Repo.RarityOrder)
mkMulti(FarmTab, "farm/placespecific", "Place Specific Eggs", eggSpecies, function(l) Place.specific = listToSet(l) end)
mkSlider(FarmTab, "farm/placevalue", "Min Place Value", 0, 100000, 0, 500, "/s", function(v) Place.minValue = v end)
mkStatus(FarmTab, "place", "Pen Status  |  Off")
mkSection(FarmTab, "Auto Treadmill")
mkToggle(FarmTab, "farm/tread", "Auto Treadmill", false, function(v) Tread.on = v Tasks.Wake("treadride") end)
mkSection(FarmTab, "Auto Hatch & Equip")
mkToggle(FarmTab, "farm/hatch", "Auto Hatch", false, function(v) Hatch.on = v Tasks.Wake("hatch") end)
mkDropdown(FarmTab, "farm/hatchrarity", "Hatch Min Rarity", rarityAny, "Any",
function(v) Hatch.minRarity = rarityNumAny(v) end)
mkSlider(FarmTab, "farm/hatchvalue", "Min Hatch Value", 0, 100000, 0, 500, "/s", function(v) Hatch.minValue = v end)
mkMulti(FarmTab, "farm/hatchlist", "Hatch Specific Eggs", eggSpecies, function(l) Hatch.specific = listToSet(l) end)
mkToggle(FarmTab, "farm/equipbest", "Auto Equip Best", false, function(v) Hatch.equipBest = v end,
"Equip best pets")
mkSection(FarmTab, "Auto Sell")
mkToggle(FarmTab, "farm/sellpet", "Auto Sell Pet", false, function(v) Sell.petOn = v Tasks.Wake("sell") end,
"Auto sell pets")
mkDropdown(FarmTab, "farm/sellpetmax", "Pet Max Rarity", rarityAny, "Epic",
function(v) Sell.petMax = rarityNumAny(v) end, "Sell rarities")
mkSlider(FarmTab, "farm/sellpetvalue", "Pet Sell Value", 0, 100000, 0, 500, "/s",
function(v) Sell.petValue = v end, "Only below")
mkToggle(FarmTab, "farm/keepmutpet", "Keep Mutated Pets", true, function(v) Sell.petKeepMut = v end)
mkMulti(FarmTab, "farm/blackpet", "Blacklist Sell Pets", petSpecies, function(l) Sell.petBlack = listToSet(l) end,
"Never sell")
mkButton(FarmTab, "Sell Pets Now", function() Sell.RunOnce() end)
mkToggle(FarmTab, "farm/sellegg", "Auto Sell Egg", false, function(v) Sell.eggOn = v Tasks.Wake("sell") end,
"Auto sell eggs")
mkDropdown(FarmTab, "farm/selleggmax", "Egg Max Rarity", rarityAny, "Epic",
function(v) Sell.eggMax = rarityNumAny(v) end, "Sell rarities")
mkSlider(FarmTab, "farm/selleggvalue", "Egg Sell Value", 0, 100000, 0, 500, "/s",
function(v) Sell.eggValue = v end, "Only below")
mkToggle(FarmTab, "farm/keepmutegg", "Keep Mutated Eggs", true, function(v) Sell.eggKeepMut = v end)
mkMulti(FarmTab, "farm/blackegg", "Blacklist Sell Eggs", eggSpecies, function(l) Sell.eggBlack = listToSet(l) end,
"Never sell")
mkButton(FarmTab, "Sell Eggs Now", function() Sell.RunOnce() end)
mkSection(FarmTab, "Auto Fuse Machine")
mkToggle(FarmTab, "farm/fuse", "Auto Fuse Machine", false, function(v) Fuse.on = v Tasks.Wake("fuse") end,
"Auto fuse")
mkDropdown(FarmTab, "farm/fusemode", "Fuse Priority Mode",
{ "Lowest Rarity First", "Highest Rarity First", "Most Copies First", "Lowest Value First" },
"Lowest Rarity First", function(v) Fuse.mode = v end, "Fuse first")
mkDropdown(FarmTab, "farm/fuseorder", "Pets To Use",
{ "Lowest To Highest", "Highest To Lowest" }, "Lowest To Highest", function(v) Fuse.order = v end,
"Use pets")
mkDropdown(FarmTab, "farm/fusemax", "Max Rarity to Fuse", rarityAny, "Divine",
function(v) Fuse.maxRarity = rarityNumAny(v) end, "Rarities")
mkMulti(FarmTab, "farm/fusespecies", "Specific Species to Fuse", petSpecies, function(l) Fuse.species = listToSet(l) end,
"Only these pets")
mkToggle(FarmTab, "farm/fuseskipmut", "Skip Mutated Pets", true, function(v) Fuse.skipMut = v end)
mkToggle(FarmTab, "farm/fuseeject", "Eject Incomplete Slots", true, function(v) Fuse.eject = v end,
"Eject odd pets")
mkStatus(FarmTab, "fuse", "Fuse Preview")
mkSection(FarmTab, "Auto Favorite")
mkToggle(FarmTab, "farm/fav", "Auto Favorite Pet", false, function(v) Fav.on = v Tasks.Wake("fav") end,
"Auto favorite")
mkDropdown(FarmTab, "farm/favrule", "Favorite Rule", { "Match Any", "Match All" }, "Match Any",
function(v) Fav.rule = v end, "Match")
mkDropdown(FarmTab, "farm/favrarity", "Favorite Min Rarity", rarityAny, "Any",
function(v) Fav.minRarity = rarityNumAny(v) end, "Rarities")
mkMulti(FarmTab, "farm/favmut", "Favorite Mutations",
{ "Any Mutation", "No Mutation", "Golden", "Silver", "Rainbow", "Sakura",
"GreatBloom", "Boss", "Monstrous", "Scrambled", "Enchanted", "Nitro", "Spectral" },
function(l) Fav.mutations = listToSet(l) end)
mkSlider(FarmTab, "farm/favvalue", "Min Favorite Value", 0, 100000, 0, 500, "/s", function(v) Fav.minValue = v end)
mkMulti(FarmTab, "farm/favspecies", "Always Favorite Species", petSpecies, function(l) Fav.species = listToSet(l) end,
"Always favorite")
mkToggle(FarmTab, "farm/favequip", "Auto Favorite Equipped", false, function(v) Fav.equipped = v end,
"Favorite equipped")
mkToggle(FarmTab, "farm/favunequip", "Auto Unfavorite Equipped", false, function(v) Fav.unfav = v end)
mkButton(FarmTab, "Favorite Pets Now", function() Fav.RunOnce(false) end)
mkButton(FarmTab, "Favorite Equipped Now", function() Fav.RunOnce(false) end)
mkButton(FarmTab, "Unfavorite Equipped Now", function() Fav.RunOnce(true) end)
mkStatus(FarmTab, "fav", "Favorite Preview")
mkSection(FarmTab, "Priority Rotation")
mkToggle(FarmTab, "rot/on", "Rotate Fishing And Treadmill", false, function(v)
Rotation.on = v
Rotation.swapAt = 0
Tasks.Wake("rotation")
end)
mkDropdown(FarmTab, "rot/mode", "Rotation Switch", { "Timer", "Every Day" }, "Timer",
function(v) Rotation.mode = v end)
mkSlider(FarmTab, "rot/fishmin", "Fishing Minutes", 1, 120, 5, 1, " min",
function(v) Rotation.fishMin = v end)
mkSlider(FarmTab, "rot/treadmin", "Treadmill Minutes", 1, 120, 5, 1, " min",
function(v) Rotation.treadMin = v end)
mkStatus(FarmTab, "rotation", "Rotation Status  |  Off")
mkSection(FarmTab, "Priority")
mkStatus(FarmTab, "prioqueue", "Task Queue  |  Idle")
local EventTab = Window:CreateTab({ Name = "Event", Icon = "🎃" })
mkSection(EventTab, "Pumpkin Boss")
mkStatus(EventTab, "hwpump", "Pumpkin Boss Status  |  Off")
mkToggle(EventTab, "event/pboss", "Auto Pumpkin Boss", false, function(v) PBoss.on = v end)
mkToggle(EventTab, "event/pdodge", "Auto Dodge Attacks", true, function(v) PBoss.dodge = v end)
mkSection(EventTab, "Halloween Dimension")
mkStatus(EventTab, "hwstatus", "Halloween Status  |  Off")
mkStatus(EventTab, "hwsteal", "Halloween Steal  |  Idle")
mkToggle(EventTab, "admin/hwsteal", "Auto Steal Halloween Eggs", false, function(v)
HWX.on = v
Steal.hwAuto = v
Tasks.Wake("hwsteal")
end)
mkToggle(EventTab, "event/hwinstant", "Instant Steal Halloween Eggs", true, function(v)
Steal.hwInstant = v
HWX.instant = v
end)
mkToggle(EventTab, "event/hwholders", "Take Halloween Eggs From Holders", true, function(v) HWX.holders = v end)
mkToggle(EventTab, "event/hwindex", "Steal Missing Halloween Index", true, function(v) HWX.index = v end)
mkToggle(EventTab, "event/hwplace", "Place And Hatch Missing Index Eggs", false, function(v) HWX.placeHatch = v end)
mkMulti(EventTab, "event/hweggs", "Halloween Eggs To Steal", eggSpecies, function(l) HWX.eggs = listToSet(l) end)
mkMulti(EventTab, "event/hwrarities", "Halloween Egg Rarities", HW_RARITIES, function(l) HWX.rarities = listToSet(l) end)
mkSlider(EventTab, "event/hwminval", "Min Value", 0, 100000, 0, 500, "/s", function(v) HWX.minValue = v end)
mkToggle(EventTab, "event/pumpkinmoon", "Auto Pumpkin Moon", true, function(v) HwPump.on = v end)
mkToggle(EventTab, "event/pumptp", "Teleport To Pumpkins", true, function(v) HwPump.tp = v end)
mkSlider(EventTab, "event/pumpspeed", "Walk Speed", 100, 1000, 300, 10, " st/s", function(v) HwPump.speed = v end)
mkToggle(EventTab, "event/hwbuy", "Auto Buy Halloween Dimension Egg", false, function(v) HWX.buy = v end)
mkSection(EventTab, "Halloween Monsters")
mkToggle(EventTab, "event/hwmon", "Auto Farm Monsters", false, function(v) HwMon.on = v end)
mkMulti(EventTab, "event/hwmonkill", "Monsters To Kill", HW_MONS, function(l) HwMon.kill = listToSet(l) end,
nil, HW_MONS)
mkDropdown(EventTab, "event/hwmonorder", "Monster Order", { "Closest", "Most Tokens" }, "Closest",
function(v) HwMon.order = v end)
mkMulti(EventTab, "event/hwmonweap", "Use Weapons", { "Best Bat" }, function(l) HwMon.weapons = listToSet(l) end)
mkSlider(EventTab, "event/hwmonspeed", "Walk Speed", 100, 1000, 300, 10, " st/s", function(v) HwMon.speed = v end)
mkToggle(EventTab, "event/hwmontp", "Teleport To Monsters", true, function(v) HwMon.tp = v end)
mkToggle(EventTab, "event/hwmonblood", "Only During Blood Moon", false, function(v) HwMon.bloodOnly = v end)
mkToggle(EventTab, "event/hwmonball", "Farm All Monsters In Blood Moon", false, function(v) HwMon.bloodAll = v end)
mkStatus(EventTab, "hwmon", "Monster Status  |  Off")
mkSection(EventTab, "Ghost Dog & Fishing")
mkStatus(EventTab, "hwdog", "Ghost Dog Status  |  Off")
mkToggle(EventTab, "event/hwdog", "Auto Ghost Dog Quest", false, function(v) HwDog.on = v end)
mkToggle(EventTab, "event/fishing", "Auto Fishing", false, function(v)
HwFish.on = v
Tasks.Wake("hwfish")
end)
mkDropdown(EventTab, "event/luck", "Cast Luck",
{ "x1.5 Perfect", "x1.2", "x1.1", "x1.0 Fastest" }, "x1.5 Perfect",
function(v) HwFish.luck = v end)
mkDropdown(EventTab, "event/spot", "Fishing Spot", { "Default", "Spot 1", "Spot 2", "Spot 3" }, "Default",
function(v) HwFish.spot = v end)
mkButton(EventTab, "Save Spot Here", function()
local pos = Movement.Pos()
if not pos then Notify("Fishing", "Tidak ada posisi", 3) return end
local n = tonumber(string.match(HwFish.spot or "Default", "%d")) or 1
HwFish.spots[n] = pos
Notify("Fishing", "Spot " .. n .. " disimpan di sini", 3)
end)
mkSlider(EventTab, "event/fishspeed", "Walk Speed", 100, 1000, 300, 10, " st/s", function(v) HwFish.speed = v end)
mkToggle(EventTab, "event/fishmon", "Farm Monsters While Fishing", false, function(v)
if v and not HwMon.on then
local el = Config.Elements["event/hwmon"]
if el and el.Set then P(function() el:Set(true, false) end) end
HwMon.on = true
end
end)
mkSection(EventTab, "Phantom Express")
mkStatus(EventTab, "express", "Phantom Express Status  |  Off")
mkToggle(EventTab, "event/express", "Auto Phantom Express", false, function(v) Express.on = v end)
mkToggle(EventTab, "event/vacuum", "Auto Vacuum Ghouler Boss", true, function(v) Express.vacuum = v end)
mkDropdown(EventTab, "event/ghosttarget", "Ghost Target", { "Rarest First", "Closest" }, "Rarest First",
function(v) Express.ghostTarget = v end)
mkMulti(EventTab, "event/expressweap", "Use Weapons", { "Best Bat" }, function(l) Express.weapons = listToSet(l) end)
mkSlider(EventTab, "event/expressspeed", "Walk Speed", 100, 1000, 300, 10, " st/s", function(v) Express.speed = v end)
mkToggle(EventTab, "event/ghosttp", "Teleport To Ghosts", true, function(v) Express.tp = v end)
mkToggle(EventTab, "event/souls", "Auto Trade Souls", false, function(v) Express.souls = v end)
mkSection(EventTab, "Shooting Star")
mkStatus(EventTab, "star", "Shooting Star Status  |  Off")
mkToggle(EventTab, "farm/star", "Auto Catch Shooting Star", false, function(v) Star.on = v Tasks.Wake("star") end)
mkSection(EventTab, "Butterfly Bloom")
mkToggle(EventTab, "farm/butter", "Auto Butterfly Bloom", false, function(v) Butter.on = v Tasks.Wake("butterflies") end)
mkDropdown(EventTab, "farm/buttermode", "Catch Mode",
{ "Stand", "Chase", "Circle", "Patrol" }, "Stand", function(v) Butter.mode = v end,
"Only for Chase mode")
mkDropdown(EventTab, "farm/butterprio", "Catch Priority", { "Rarest", "Nearest" }, "Rarest",
function(v) Butter.priority = v end, "Only for Chase mode")
mkMulti(EventTab, "farm/butterlist", "Catch Butterflies", BUTTER_LIST, function(l)
Butter.onlySet = {}
for _, disp in ipairs(l) do
local id = BUTTER_TO_ID[disp]
if id then Butter.onlySet[id] = true end
end
end, "Catch", BUTTER_LIST)
mkSlider(EventTab, "farm/butterspeed", "Tween Speed  ", 100, 600, 320, 10, "studs/s",
function(v) Butter.tweenSpeed = v end, "Catch speed")
mkToggle(EventTab, "farm/tradeup", "Auto Trade Up", false, function(v) Butter.tradeUp = v end)
mkMulti(EventTab, "farm/tiers", "Trade Up Tiers", BUTTER_LIST, function(l) Butter.tiers = listToSet(l) end,
"Trade")
mkToggle(EventTab, "farm/essence", "Smart Trade For Essence", false, function(v) Butter.essence = v end)
mkToggle(EventTab, "farm/craft", "Auto Craft Essence", false, function(v) Butter.craft = v end)
mkStatus(EventTab, "wisp", "Wisp Status  |  Off")
mkToggle(EventTab, "farm/wisp", "Auto Wisp", false, function(v) Wisp.on = v Tasks.Wake("wisp") end,
"Auto wisp quest")
mkToggle(EventTab, "farm/banjo", "Auto Banjo Cricket", false, function(v) Banjo.on = v end)
mkSection(EventTab, "The Hollow")
mkStatus(EventTab, "hollow", "The Hollow Status  |  Off")
mkToggle(EventTab, "event/hollow", "Auto Race The Hollow", false, function(v) Hollow.on = v end)
mkSlider(EventTab, "event/hollowspeed", "Hollow Race Speed", 140, 400, 300, 1, " st/s",
function(v) Hollow.speed = v end)
mkToggle(EventTab, "event/hollowpower", "Use Race Power-Ups", true, function(v) Hollow.powerups = v end)
local AdminTab = Window:CreateTab({ Name = "Admin Abuse", Icon = "🔨" })
mkSection(AdminTab, "Capture The Egg")
mkToggle(AdminTab, "admin/capture", "Auto Capture Event Egg", false, function(v) Capture.on = v end)
mkToggle(AdminTab, "admin/capturetake", "Take It From The Holder", false, function(v) Capture.take = v end)
mkSlider(AdminTab, "admin/captureheight", "Hold Height", 20, 120, 45, 1, "studs",
function(v) Capture.holdHeight = v end)
mkSlider(AdminTab, "admin/captureaway", "Keep Away Distance", 20, 150, 45, 1, "studs",
function(v) Capture.keepAway = v end)
mkStatus(AdminTab, "capture", "Capture Status  |  Off")
mkSection(AdminTab, "Admin Treadmill")
mkToggle(AdminTab, "farm/treadadmin", "Use Admin Treadmill", false, function(v) Tread.admin = v end,
"Admin treadmill")
mkSection(AdminTab, "Instant Steal V3")
P(function()
AdminTab:AddLabel({ Text = "Instant Steal V3 Note: Needs Admin Treadmill" })
end)
mkToggle(AdminTab, "admin/instantv3", "Use Instant Steal V3", true, function(v)
Steal.adminSteal = v
Steal.v3 = v
end)
mkSection(AdminTab, "Minigame Eggs")
mkToggle(AdminTab, "admin/minigame", "Auto Steal Minigame Egg", true, function(v) Minigame.on = v end,
"Red Light Green Light, T-Rex Run")
mkSection(AdminTab, "Cursed Island Wars")
mkStatus(AdminTab, "ciw", "Cursed Island Wars Status  |  Off")
mkToggle(AdminTab, "admin/ciw", "Auto Play Cursed Island Wars", false, function(v) CIW.on = v end)
mkDropdown(AdminTab, "admin/ciwtarget", "Island Wars Target",
{ "Enemies And Base", "Walls And Crystal" }, "Enemies And Base",
function(v) CIW.target = v end)
local PlayerTab = Window:CreateTab({ Name = "Player", Icon = "👤" })
mkSection(PlayerTab, "ESP")
mkToggle(PlayerTab, "player/espeggs", "ESP Eggs", false, function(v) ESP.eggs = v end, "Egg ESP")
mkToggle(PlayerTab, "player/espfixed", "ESP Fixed Size", false, function(v) ESP.fixed = v end, "Fixed size")
mkToggle(PlayerTab, "player/espown", "ESP Own Base Eggs", false, function(v) ESP.own = v end, "Pen egg ESP")
mkToggle(PlayerTab, "player/espothers", "ESP Other Base Eggs", false, function(v) ESP.others = v end, "Other pens ESP")
mkDropdown(PlayerTab, "player/espminrar", "ESP Min Rarity", rarityAny, "Any",
function(v) ESP.minRarity = rarityNumAny(v) end,
"Show eggs of the chosen rarity and every rarity above it")
mkMulti(PlayerTab, "player/espshow", "ESP Show Info",
{ "Name", "Rarity", "Value", "Mutations", "Distance" }, function(l) ESP.info = listToSet(l) end,
"Show", { "Name", "Rarity", "Value", "Mutations", "Distance" })
mkSlider(PlayerTab, "player/espminval", "Min ESP Value", 0, 100000, 0, 500, "/s",
function(v) ESP.minValue = v end, "Min value")
mkSlider(PlayerTab, "player/espeggsize", "ESP Egg Size", 50, 200, 75, 5, "%",
function(v) ESP.eggSize = v / 100 end)
mkToggle(PlayerTab, "player/espguards", "ESP Guards", false, function(v) ESP.guards = v end, "Guard ESP")
mkSlider(PlayerTab, "player/espguardsize", "ESP Guard Size", 50, 200, 75, 5, "%",
function(v) ESP.guardSize = v / 100 end)
mkToggle(PlayerTab, "player/espplayers", "ESP Players", false, function(v) ESP.players = v end, "Player ESP")
mkMulti(PlayerTab, "player/espplayerinfo", "ESP Player Info",
{ "Name", "Username", "Avatar", "Tool" }, function(l) ESP.playerInfo = listToSet(l) end,
"Show", { "Name", "Tool" })
mkSlider(PlayerTab, "player/espplayersize", "ESP Player Size", 50, 200, 75, 5, "%",
function(v) ESP.playerSize = v / 100 end)
mkToggle(PlayerTab, "player/invvalues", "Inventory Values", false, function(v) ESP.invValues = v end)
mkSection(PlayerTab, "Movement")
mkToggle(PlayerTab, "player/speed", "Speed Boost", false, function(v) MoveX.speed = v end)
mkSlider(PlayerTab, "player/boost", "Boost Speed", 20, 1000, 350, 5, "studs/s",
function(v) MoveX.boost = v end)
mkToggle(PlayerTab, "player/infjump", "Infinite Jump", false, function(v) MoveX.SetInfJump(v) end)
mkSection(PlayerTab, "Character")
mkToggle(PlayerTab, "player/invis", "Invisibility", false, function(v)
CharX.invis = v
Character.ApplyInvisibility(v)
end, "Invisible")
mkToggle(PlayerTab, "player/antirag", "Anti Ragdoll", false, function(v) CharX.antiRag = v end)
mkToggle(PlayerTab, "player/antitrap", "Anti Trap", false, function(v) CharX.antiTrap = v end,
"Ignore traps")
mkToggle(PlayerTab, "player/prompts", "Instant Prompts", false, function(v) CharX.prompts = v end)
mkSection(PlayerTab, "Combat")
mkStatus(PlayerTab, "combat", "Hit Status  |  Idle")
local function setCombatMode(modeName, ownKey)
Combat.on = true
Combat.mode = modeName
local all = { "player/hitnearest", "player/hotholders", "player/hitspecific" }
for _, k in ipairs(all) do
if k ~= ownKey then
local e = Config.Elements[k]
if e and e.Set then P(function() e:Set(false, false) end) end
end
end
end
mkToggle(PlayerTab, "player/hitnearest", "Auto Hit Nearest Player", false, function(v)
if v then setCombatMode("Auto Hit Nearest Player", "player/hitnearest") else Combat.on = false end
end, "Hit who")
mkToggle(PlayerTab, "player/hotholders", "Auto Hit Egg Holders", false, function(v)
if v then setCombatMode("Auto Hit Egg Holders", "player/hotholders") else Combat.on = false end
end, "Hit who")
mkToggle(PlayerTab, "player/hitspecific", "Auto Hit Specific Player", false, function(v)
if v then setCombatMode("Auto Hit Specific Player", "player/hitspecific") else Combat.on = false end
end, "Hit who")
mkDropdown(PlayerTab, "player/hitplayer", "Hit Player", playerNames, playerNames[1],
function(v) Combat.target = v end)
mkToggle(PlayerTab, "player/hitaura", "Hit Aura", false, function(v) Combat.aura = v end)
mkMulti(PlayerTab, "player/swapweap", "Swap Weapons", { "Best Bat" }, function(l)
Combat.weapons = {}
for i, w in ipairs(l) do
if i <= 2 then Combat.weapons[i] = w end
end
end, "Pick up to 2 weapons you own to switch between while hitting (empty = best bat only)")
mkSlider(PlayerTab, "player/weap1", "Weapon 1 Hold", 0.2, 1.5, 0.3, 0.01, "s",
function(v) Combat.swapT = v end)
mkSlider(PlayerTab, "player/weap2", "Weapon 2 Hold", 0.2, 1.5, 0.4, 0.01, "s",
function(v) Combat.swapT2 = v end)
P(function() PlayerTab:AddLabel({ Text = "Chase Settings" }) end)
mkSlider(PlayerTab, "player/chase", "Hit Tween Speed", 100, 1000, 400, 10, "studs/s",
function(v) Combat.chase = v end)
mkSlider(PlayerTab, "player/hitmax", "Hit Max Speed", 100, 1000, 750, 10, "studs/s",
function(v) Combat.maxSpeed = v end)
mkSlider(PlayerTab, "player/hitlead", "Hit Lead", -400, 100, -275, 1, "",
function(v) Combat.lead = v end,
"Stand further ahead of the target (+) or closer to them (-)")
mkSlider(PlayerTab, "player/hitsweep", "Hit Sweep", 0, 250, 60, 1, "%",
function(v) Combat.sweep = v end,
"How far you move back and forth in front of the target")
mkButton(PlayerTab, "Add/Remove Hits On Quick Bar 2", function()
P(function()
for _, keyName in ipairs({ "player/hitnearest", "player/hotholders", "player/hitspecific" }) do
local e = Config.Elements[keyName]
if e then
ThorUI:AddQuickAction({
Icon = "👊", Name = "Hit: " .. tostring(keyName),
Callback = function()
local cur = e.Get and e:Get()
if e.Set then P(function() e:Set(not cur, false) end) end
end,
})
end
end
Notify("Combat", "Toggles hit ditambahkan ke quick bar", 3)
end)
end, "Pin or unpin the hit toggles on Quick Bar 2")
local PredTab = Window:CreateTab({ Name = "Predictor", Icon = "🔮" })
mkSection(PredTab, "Discord Webhook")
mkInput(PredTab, "webhook/url", "Webhook URL", "https://discord.com/api/webhooks/...",
function(t) Webhook.url = tostring(t or "") end)
mkToggle(PredTab, "webhook/everyone", "Ping @everyone", false, function(v) Webhook.everyone = v end,
"Ping everyone")
mkMulti(PredTab, "webhook/notify", "Notify On",
{ "Egg Stolen", "Egg Fused", "Inventory Full" }, function(l)
local set = listToSet(l)
Webhook.events = {
["Egg Stolen"] = set["Egg Stolen"] or false,
["Egg Fused"] = set["Egg Fused"] or false,
["Inventory Full"] = set["Inventory Full"] or false,
}
end, "What to post", { "Egg Stolen", "Egg Fused", "Inventory Full" })
mkDropdown(PredTab, "webhook/minrar", "Webhook Min Rarity", rarityAny, "Any",
function(v) Webhook.minRarity = rarityNumAny(v) end, "Rarities")
mkSlider(PredTab, "webhook/minval", "Webhook Min Value", 0, 100000, 0, 500, "/s",
function(v) Webhook.minValue = v end,
"Only post eggs worth at least this. Drag or type 250k, 50m, 1.5b")
mkMulti(PredTab, "webhook/eggs", "Webhook Eggs", eggSpecies, function(l)
Webhook.specific = listToSet(l)
end, "Only post these eggs (empty = all)")
mkSection(PredTab, "Egg Predictor")
mkDropdown(PredTab, "pred/sort", "Sort By", { "Value", "Rarity", "Time Left" }, "Value",
function(v) Predictor.sort = v end, "Sort eggs")
mkToggle(PredTab, "pred/card", "Preview Card", true, function(v) Predictor.spotlight = v end)
mkStatus(PredTab, "predictor", "Egg Predictor  |  loading...")
mkSection(PredTab, "Fuse Predictor")
mkStatus(PredTab, "fusepred", "Fuse Predictor  |  loading...")
local ServerTab = Window:CreateTab({ Name = "Server", Icon = "🌐" })
mkSection(ServerTab, "Server")
mkButton(ServerTab, "Server Hop", function() AutoHop.HopNow("Server tab") end)
mkInput(ServerTab, "server/jobid", "Job ID", "tempel Job ID di sini...", function(t) end)
mkButton(ServerTab, "Join Job ID", function()
local el = Config.Elements["server/jobid"]
ServerX.JoinJob(el and el.Get and el:Get() or "")
end)
mkButton(ServerTab, "Copy Current Job ID", function() ServerX.CopyJobId() end)
mkButton(ServerTab, "Rejoin Server", function() ServerX.Rejoin() end)
mkToggle(ServerTab, "server/autoload", "Auto Load Script", true, function(v)
ServerX.autoLoad = v
end, "Join and stay")
mkDropdown(ServerTab, "server/hopmode", "Server Hop Mode",
{ "Least Players", "Most Players", "Random" }, "Least Players",
function(v) ServerX.hopMode = v end, "Hop to")
mkToggle(ServerTab, "server/rejoin", "Auto Rejoin When Disconnect", false, function(v)
ServerX.autoRejoin = v
end, "Rejoin on kick")
local MiscTab = Window:CreateTab({ Name = "Misc", Icon = "⚙️" })
mkSection(MiscTab, "Performance")
mkSlider(MiscTab, "misc/fpscap", "FPS Cap", 10, 1000, 240, 1, " FPS",
function(v)
Perf.cap = v
perfApplyCap()
end, "FPS cap")
mkToggle(MiscTab, "misc/optimizer", "Optimizer", false, function(v)
Perf.opt = v
if v then task.spawn(perfApplyOptimizer) end
end, "Low graphics")
mkDropdown(MiscTab, "misc/optmode", "Optimizer Mode", { "Balanced", "Strong", "Max" }, "Strong",
function(v)
Perf.optMode = v
if Perf.opt then task.spawn(perfApplyOptimizer) end
end)
mkToggle(MiscTab, "misc/fpshud", "FPS and Ping", true, function(v)
Perf.fpsHud = v
if v then perfBuildHud() end
end, "Show FPS and ping")
mkSlider(MiscTab, "misc/fpssize", "FPS and Ping Size", 60, 160, 100, 1, "%",
function(v)
Perf.fpsSize = v
perfBuildHud()
end)
mkToggle(MiscTab, "misc/no3d", "Disable 3D Render", false, function(v)
Perf.no3d = v
perfApply3d()
perfApplyCap()
end)
mkDropdown(MiscTab, "misc/bgcolor", "Background Color", { "White", "Black" }, "White",
function(v)
Perf.bg = v
perfApply3d()
end)
mkSection(MiscTab, "Utility")
mkToggle(MiscTab, "misc/antiafk", "Anti AFK", true, function(v) AntiAfk.on = v end)
mkSection(MiscTab, "Farm HUD")
mkToggle(MiscTab, "misc/farmhud", "Farm HUD", false, function(v)
FarmHud.on = v
Tasks.Wake("farmhud")
end, "Drag any panel to place it where you like")
mkToggle(MiscTab, "misc/hidegame", "Hide Game UI", true, function(v) FarmHud.hideGame = v end)
mkMulti(MiscTab, "misc/huditems", "HUD Items",
{ "Speed", "Cash", "Stolen", "Showcase" }, function(l)
FarmHud.items = listToSet(l)
end, nil, { "Speed", "Cash", "Stolen", "Showcase" })
mkSlider(MiscTab, "misc/cards", "Showcase Cards", 1, 6, 4, 1, "",
function(v) FarmHud.cards = v end)
mkSlider(MiscTab, "misc/hudsize", "HUD Size", 50, 120, 100, 1, "%",
function(v)
FarmHud.size = v
task.spawn(farmHudBuild)
end)
mkDropdown(MiscTab, "misc/cardimage", "Egg Card Image", { "Egg Image", "Pet Image" }, "Egg Image",
function(v) FarmHud.image = v end, "Picture used for the showcase cards")
local HopTab = Window:CreateTab({ Name = "Auto Hop", Icon = "🥚" })
mkSection(HopTab, "Egg Finder")
local hopSyncBusy = false
local function shallowEq(a, b)
if type(a) ~= "table" or type(b) ~= "table" then return a == b end
if #a ~= #b then return false end
for i = 1, #a do
if a[i] ~= b[i] then return false end
end
return true
end
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
"Steal Then Hop", function(v) AutoHop.mode = v end, "Hop when")
mkDropdown(HopTab, "hop/rarity", "Rarity To Wait For", rarityAny, "Cosmic",
function(v) AutoHop.waitRarity = v end, "Rare from")
mkToggle(HopTab, "hop/sync", "Sync With Auto Steal Filters", true, function(v)
AutoHop.sync = v
if v then
local pairsToSync = {
{ "hop/hminrar", "farm/minrarity" }, { "hop/hareas", "farm/areas" },
{ "hop/hspecific", "farm/specific" }, { "hop/hminval", "farm/minvalue" },
}
for _, p in ipairs(pairsToSync) do
local fromEl, toEl = Config.Elements[p[2]], Config.Elements[p[1]]
if fromEl and toEl and fromEl.Get then
hopSyncBusy = true
P(function() toEl:Set(fromEl:Get(), false) end)
hopSyncBusy = false
end
end
end
end, "Changing a filter here also changes it in Auto Steal, and back")
Tasks.Add("hopsync2", 2.0, function()
if not AutoHop.sync then return end
local pairsToSync = {
{ "hop/hminrar", "farm/minrarity" }, { "hop/hareas", "farm/areas" },
{ "hop/hspecific", "farm/specific" }, { "hop/hminval", "farm/minvalue" },
}
for _, p in ipairs(pairsToSync) do
local fromEl, toEl = Config.Elements[p[2]], Config.Elements[p[1]]
if fromEl and toEl and fromEl.Get and toEl.Get then
local v = fromEl:Get()
if v ~= nil and not shallowEq(toEl:Get(), v) then
hopSyncBusy = true
P(function() toEl:Set(v, false) end)
hopSyncBusy = false
end
end
end
end)
mkDropdown(HopTab, "hop/hminrar", "Min Rarity", rarityAny, "Any",
function(v)
if not hopSyncBusy and AutoHop.sync then
local el = Config.Elements["farm/minrarity"]
if el and el.Set then
hopSyncBusy = true
P(function() el:Set(v, false) end)
hopSyncBusy = false
end
end
Steal.minRarity = rarityNumAny(v)
end,
"Find eggs of the chosen rarity and every rarity above it")
mkMulti(HopTab, "hop/hareas", "Target Areas", areaNames, function(l)
if not hopSyncBusy and AutoHop.sync then
local el = Config.Elements["farm/areas"]
if el and el.Set then
hopSyncBusy = true
P(function() el:Set(l, false) end)
hopSyncBusy = false
end
end
Steal.areas = listToSet(l)
end, "Zones", areaNames)
mkMulti(HopTab, "hop/hspecific", "Target Specific Eggs", eggSpecies, function(l)
if not hopSyncBusy and AutoHop.sync then
local el = Config.Elements["farm/specific"]
if el and el.Set then
hopSyncBusy = true
P(function() el:Set(l, false) end)
hopSyncBusy = false
end
end
Steal.specific = listToSet(l)
end, "Only these eggs")
mkSlider(HopTab, "hop/hminval", "Min Value To Find", 0, 100000, 0, 500, "/s",
function(v)
if not hopSyncBusy and AutoHop.sync then
local el = Config.Elements["farm/minvalue"]
if el and el.Set then
hopSyncBusy = true
P(function() el:Set(v, false) end)
hopSyncBusy = false
end
end
Steal.minValue = v
end,
"Skip eggs worth less than this. Drag or type 250k, 50m, 1.5b")
mkSlider(HopTab, "hop/firstdelay", "First Hop Delay", 3, 10, 5, 0.5, "s",
function(v) AutoHop.firstDelay = v end,
"Wait after the script loads before the first hop")
P(function()
HopTab:AddParagraph({
Title = "Cara kerja Auto Hop",
Text = "Hop terus selama belum ada egg yang cocok filter (Until An Egg "
.. "Matches), pindah setelah berhasil mencuri (Steal Then Hop), atau "
.. "pindah begitu egg rarity+ terdeteksi (After A Rare Spawns). "
.. "Sync With Auto Steal Filters membuat filter di sini dan di "
.. "Farm > Auto Steal selalu sama. Status ON dipulihkan otomatis "
.. "setelah pindah server (Auto Load Script).",
})
end)
P(function()
FarmTab:AddParagraph({
Title = "ThorHub v3.3 — sync 1:1 kode baru",
Text = "Struktur menu & metode engine dipetakan 1:1 dari kode baru "
.. "Chilli Hub (SAE v172610): 8 tab, Delivery 3-mode (Tween / "
.. "Instant Steps / Fast Tween), Instant Steal V3 via Admin "
.. "Treadmill, tab Event lengkap, ESP/Combat, Predictor, dan "
.. "Steal Panel hijack HUD game (tombol toggle di kolom tombol "
.. "kanan game). Jangan jalankan bersama script hub lain. Log "
.. "ThorHub selalu berawalan [ThorHub].",
})
end)
Config.AutoSave = true
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
task.delay(1.2, function()
StealPanel.Restore()
end)
if type(Gill) == "table" and Gill.__THORHUB_AUTOHOP then
task.delay(1.5, function()
local el = Config.Elements["hop/on"]
if el and el.Set then
P(function() el:Set(true, false) end)
AutoHop.on = true
Tasks.Wake("autohop")
end
end)
end
if ServerX.autoLoad then
queueReload()
end
Tasks.Add("refp", 15.0, function()
refreshPlayerNames()
end)
LocalPlayer.CharacterAdded:Connect(function(char)
char:WaitForChild("Humanoid", 10)
task.wait(0.5)
Character.OnDeathReset()
end)
local function DestroyAll()
pcall(function() StealPanel.Destroy() end)
Character.ApplyInvisibility(false)
perfApply3d()
if setfpscap then pcall(setfpscap, 240) end
if ThorUI then P(function() ThorUI:Destroy() end) end
end
Gill.__THORHUB_AF_LOADED = true
Gill.__THORHUB_AF_DESTROY = DestroyAll
Notify("⚡ ThorHub", "v3.3 siap! Menu 8 tab + Steal Panel hijack HUD (remote sync 1:1).", 6)
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
print("[ThorHub] v3.3 menu siap. Buka/tutup: tombol petir melayang atau RightControl.")
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
-- THORHUB-EOF v3.3
