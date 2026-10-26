--═══════════════════════════════════════════════════════════════════════════════
--  ⚡ THORHUB — LINK LAMA (auto-redirect)
--  ──────────────────────────────────────────────────────────────────────────────
--  File ini cuma PENERUS. Link lama yang kamu pakai sudah tidak dipakai lagi
--  (semua fitur pindah ke file baru: ThorHub-Farm.lua), tapi biar tidak
--  "HTTP 404" seperti di console executor, link lama tetap jalan otomatis.
--
--  LINK RESMI TERBARU (disarankan dipakai langsung):
--    loadstring(game:HttpGet("https://raw.githubusercontent.com/dwisetyabudi15581/StealAnEgg/main/ThorHub-Farm.lua"))()
--═══════════════════════════════════════════════════════════════════════════════

local NEW_URL = "https://raw.githubusercontent.com/dwisetyabudi15581/StealAnEgg/main/ThorHub-Farm.lua"

pcall(function()
	game:GetService("StarterGui"):SetCore("SendNotification", {
		Title = "ThorHub",
		Text = "Link lama terdeteksi - memuat versi terbaru (ThorHub-Farm)...",
		Duration = 6,
	})
end)
print("[ThorHub] Link lama -> redirect ke ThorHub-Farm.lua (versi terbaru)")

return loadstring(game:HttpGet(NEW_URL))()
