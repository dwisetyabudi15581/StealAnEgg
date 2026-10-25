--[[════════════════════════════════════════════════════════════════════════════
  ⚡ THORHUB LOADER — AUTO FARM | STEAL AN EGG
  ──────────────────────────────────────────────────────────────────────────
  Cara pakai (executor Roblox):
    loadstring(game:HttpGet("https://raw.githubusercontent.com/dwisetyabudi15581/StealAnEgg/main/ThorHub-Loader.lua"))()

  Apa yang dimuat:
    ThorHub-AutoFarm.lua — Auto Steal (V1/V2/V3) · Shooting Star ·
    Butterfly Bloom · Wisp & Banjo · Auto Mutation · Auto Place Egg ·
    Auto Treadmill · Auto Hatch & Equip · Auto Sell · Auto Fuse ·
    Auto Favorite. UI: ThorUi (floating ⚡ + keybind RightControl).

  Loader ini tahan gangguan jaringan: 3x percobaan + mirror CDN jsDelivr
  + validasi isi sebelum eksekusi (cegah "attempt to call a nil value"
  saat raw.githubusercontent sesaat balas 404/rate-limit).
════════════════════════════════════════════════════════════════════════════]]

local URLS = {
    "https://raw.githubusercontent.com/dwisetyabudi15581/StealAnEgg/main/ThorHub-AutoFarm.lua",
    "https://cdn.jsdelivr.net/gh/dwisetyabudi15581/StealAnEgg@main/ThorHub-AutoFarm.lua",
}

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local last = "no body"
for attempt = 1, 3 do
    for _, u in ipairs(URLS) do
        local ok, body = pcall(function() return game:HttpGet(u) end)
        if ok and type(body) == "string" and #body > 5000
            and not string.match(body, "^%s*[45]%d%d") then
            local chunk = loadstring(body)
            if chunk then
                chunk()
                return
            end
            last = "parse gagal: " .. string.sub(body, 1, 80)
        elseif ok and type(body) == "string" and #body > 0 then
            last = string.sub(body, 1, 120)
        else
            last = tostring(body)
        end
    end
    task.wait(0.6 * attempt)
end

warn("[ThorHub] Gagal memuat Auto Farm (cek koneksi/URL): " .. tostring(last))
