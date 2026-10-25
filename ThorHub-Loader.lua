--[[════════════════════════════════════════════════════════════════════════════
  ⚡ THORHUB LOADER — AUTO FARM | STEAL AN EGG (v2 — diagnostik jelas)
  ──────────────────────────────────────────────────────────────────────────
  Cara pakai (executor Roblox):
    loadstring(game:HttpGet("https://raw.githubusercontent.com/dwisetyabudi15581/StealAnEgg/main/ThorHub-Loader.lua"))()

  Apa yang dimuat:
    ThorHub-AutoFarm.lua v3.1 — rewrite persis kode baru StealAnEggg:
    menu 8 tab (Farm/Event/Admin Abuse/Player/Predictor/Server/Misc/Auto Hop),
    Steal Panel (hijack HUD game: tombol Pets + frame ActivePets), Delivery
    3-mode, Instant Steal V3, ESP/Combat/Performance/Server, Auto Hop.

  Loader tahan gangguan jaringan: 3x percobaan + mirror CDN jsDelivr
  + validasi isi SEBELUM eksekusi. Jika gagal, pesan error yang muncul
  adalah diagnosis sesungguhnya:
    - "download tidak lengkap (N bytes)" = file terpotong batas executor
    - "parse gagal (N bytes): <error Lua>" = error compile file (baris ke-N)
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
            if not string.find(body, "THORHUB-EOF", -60, true) then
                last = "download tidak lengkap — file terpotong (diterima "
                    .. #body .. " bytes, file utuh sekitar 347 ribu bytes)"
            else
                local chunk, err = loadstring(body)
                if chunk then
                    chunk()
                    return
                end
                last = "parse gagal (" .. #body .. " bytes): " .. tostring(err)
            end
        elseif ok and type(body) == "string" and #body > 0 then
            last = string.sub(body, 1, 120)
        else
            last = tostring(body)
        end
    end
    task.wait(0.6 * attempt)
end

warn("[ThorHub] Gagal memuat Auto Farm (cek koneksi/URL): " .. tostring(last))
