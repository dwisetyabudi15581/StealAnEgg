--═══════════════════════════════════════════════════════════════════════════════
--  ⚡ THORHUB — LOADER DIAGNOSTIK
--  ──────────────────────────────────────────────────────────────────────────────
--  Loader ini dipakai kalau link biasa error / tidak jelas penyebabnya.
--  Setiap langkah dicetak ke console executor, jadi kelihatan TEPAT di
--  mana kegagalannya (download? compile? eksekusi?).
--
--  CARA PAKAI (executor):
--    loadstring(game:HttpGet("https://raw.githubusercontent.com/dwisetyabudi15581/StealAnEgg/main/ThorHub-Loader.lua"))()
--═══════════════════════════════════════════════════════════════════════════════

local MAIN_URL = "https://raw.githubusercontent.com/dwisetyabudi15581/StealAnEgg/main/ThorHub-Farm.lua"

local function say(...)
	print("[ThorHub-Loader]", ...)
end

say("mulai — cek lingkungan executor...")

--// 1. cek fungsi compiler yang tersedia
local hasLoadstring = (type(loadstring) == "function")
local hasLoad       = (type(load) == "function")
say("loadstring:", tostring(hasLoadstring), "| load:", tostring(hasLoad))

if not hasLoadstring and not hasLoad then
	say("❌ ERROR: executor kamu TIDAK PUNYA loadstring/load.")
	say("   Solusi: aktifkan 'loadstring' di pengaturan executor,")
	say("   atau pakai executor lain (Delta/Codex/Wave/Solara dsb).")
	return
end

--// 2. download
say("mengunduh ThorHub-Farm.lua...")
local ok, src = pcall(function()
	return game:HttpGet(MAIN_URL)
end)

if not ok then
	say("❌ GAGAL DOWNLOAD:", tostring(src))
	say("   Cek: koneksi internet, link, atau coba lagi (GitHub kadang rewel).")
	return
end

if type(src) ~= "string" or #src < 1000 then
	say("❌ DOWNLOAD TIDAK VALID:", type(src) == "string" and (#src .. " byte — terlalu pendek") or type(src))
	return
end
say("download OK —", #src, "byte")

--// 3. compile
local fn, cerr
if hasLoadstring then
	fn, cerr = loadstring(src, "=ThorHub-Farm.lua")
end
if type(fn) ~= "function" and hasLoad then
	fn, cerr = load(src, "=ThorHub-Farm.lua")
end

if type(fn) ~= "function" then
	say("❌ GAGAL COMPILE:", tostring(cerr))
	say("   Executor tidak bisa compile script — kirim pesan error ini ke developer.")
	return
end
say("compile OK — menjalankan ThorHub...")

--// 4. eksekusi (error di dalam script tetap tertangkap & dicetak)
local okRun, rerr = pcall(fn)
if not okRun then
	say("❌ ERROR SAAT EKSEKUSI:", tostring(rerr))
	say("   Kirim pesan error ini + console lengkap ke developer.")
	return
end

say("✅ selesai tanpa error — kalau UI tidak muncul, cek console di atas.")
