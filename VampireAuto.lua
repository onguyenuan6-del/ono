-- ====================================================================
--   VAMPIRE OPTIMIZER V7.9.13 - FOG + ATMOSPHERE + HIDDEN LEGO
--   Paste this ONE file into the executor. Nothing else is needed (no URL, no outside app, no manual file):
--     * it saves its own copy to workspace/VampireOptimizer/main.lua
--     * when ANY teleport starts (lobby -> match, rejoin, server hop) it queues a small stub, like Cat Vape,
--       which loads that copy again in the next server.
--   Pressing X in the menu stops it for good (until you execute it again).
--   V7.9.2: Add local Full Bright toggle with automatic re-scan and original-lighting restore.
--   V7.9.5: Split Hidden Lego (circle-only float) from Start hidden (hide menu on startup/teleport).
--   V7.9.5: Move both menu controls to the top of the list so they are immediately visible.
--   Search/display fix: keep Graphics Quality and Toggle UI Hotkey visible near the top; search indexes button text.
--   Hotkey behavior: hide/show the menu and the entire floating button (logo + red circle).
--   V7.9.7: Fix Graphics Quality applying Level 21 when Keep max view distance is enabled; add engine readback status.
--   V7.9.6: Fog distance now also controls local Atmosphere Density/Haze and restores originals.
--   V7.9.0: Responsive UI for 7680x4320 through 256x144; wrap long descriptions, fit menu to viewport, detect listed display profiles.
--   V7.8.9: Add viewport resolution detection and adaptive low graphics quality (144p is a reference floor; no true render downscale API).
--   V7.8.8: Re-apply Fog when the game overwrites Lighting after teleport; retry Flat Plastic during map loading.
--   V7.8.7: Sửa cảnh báo "Cloud instance must exist under Terrain node" (không còn chuyển Clouds ra khỏi Terrain, chỉ tắt Enabled);
--           bớt log rác: DebugRay và tay/chân viewmodel không còn bị in / nhận nhầm là khối cầm tay; đồng bộ số phiên bản trên UI.
--   V7.8.6: "Ẩn texture" không còn làm mất dấu "?" / màu của Lucky Block (sảnh + trong trận), giống "Flat materials".
--           Bỏ cảnh báo GetJoints; log "not a block" không bị 3DClothing chiếm hết.
--   V7.8.5: Sửa khối cầm tay nhìn từ BÊN NGOÀI (góc nhìn thứ ba) bị đen: nhận cả khối nằm sâu dưới tay nhân vật
--           hoặc hàn vào tay từ ngoài model nhân vật; đổ lại màu gốc trước khi ẩn texture.
--   V7.8.4: Chỉ KHỐI cầm trên tay (wool, concrete, clay...) giữ màu gốc dạng nhựa một màu; kiếm/cuốc/hiệu ứng giữ như cũ.
--   V7.8.3: Khối/vật cầm trên tay giữ màu gốc (nhựa một màu) khi bật "Ẩn texture"; không đọc được màu thì giữ texture.
--   V7.8.2: Hotkey ẩn/hiện CẢ menu + Lego (script vẫn chạy). Nút - / click Lego chỉ ẩn menu.
--           ToggleKey lưu dạng string để persist đúng sau restart.
-- ====================================================================

local VAMPIRE_SOURCE = [==[
-- ====================================================================
--   VAMPIRE OPTIMIZER V7.9.13
--   V7.9.13: Graphics Quality has a scale selector: 1-21 (engine levels, default) or 1-10 (Roblox scale, mapped to Level01-Level21).
--   V7.9.12: Graphics Quality slider used Roblox's own 1-10 scale only.
--   V7.9.11: Removed the "Keep max view distance" feature (and its FRM FFlag code).
--   V7.9.7: Graphics Quality now always applies the selected Level 1-21; KeepFarView no longer forces Level 21.
--   V7.9.6: Fog distance controls legacy Fog and Atmosphere Density/Haze locally.
--   V7.9.5: Separate Hidden Lego (circle-only button) and Start hidden (menu starts closed).
--   V7.9.5: Put both controls first in the settings list; no search is needed.
--   Search/display fix: Toggle UI Hotkey is now registered near the top and remains searchable.
--   V7.8.2: Hotkey hides menu+Lego; custom vampire icon; ToggleKey JSON fix.
--   V7.8.1: Fixed Top Border rounded corner bug, changed floating icon to a Lego Brick.
-- ====================================================================

local MaterialService = game:GetService("MaterialService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer

-- Quản lý mọi kết nối để nút X có thể dừng script hoàn toàn.
local IsRunning = true
local Connections = {}
-- Stop a previous V7.x instance before taking a fresh graphics baseline.
pcall(function()
	local previous = shared.VampireOptimizerRuntime
	if type(previous) == "table" and type(previous.Stop) == "function" then previous.Stop() end
end)
pcall(function()
	if type(getgenv) == "function" then
		local env = getgenv()
		local previous = type(env) == "table" and env.VampireOptimizerRuntime or nil
		if type(previous) == "table" and type(previous.Stop) == "function" then previous.Stop() end
	end
end)
-- A fresh manual run clears the 'user pressed X' flag that stops the post-teleport bootstrap.
pcall(function() shared.VampireOptimizerDisabled = nil end)
pcall(function() if type(getgenv) == "function" then getgenv().VampireOptimizerDisabled = nil end end)
pcall(function()
	if type(isfile) == "function" and type(writefile) == "function" and isfile("VampireOptimizer/disabled.flag") then
		writefile("VampireOptimizer/disabled.flag", "0")
	end
end)
-- Set only by the post-teleport bootstrap. Read once and cleared so a later manual run opens the menu normally.
local IsReloadRun = false
pcall(function() if shared.VampireOptimizerReload == true then IsReloadRun = true end end)
pcall(function() if type(getgenv) == "function" and getgenv().VampireOptimizerReload == true then IsReloadRun = true end end)
pcall(function() shared.VampireOptimizerReload = nil end)
pcall(function() if type(getgenv) == "function" then getgenv().VampireOptimizerReload = nil end end)
local function Connect(signal, callback)
	local connection = signal:Connect(function(...)
		if IsRunning then
			return callback(...)
		end
	end)
	table.insert(Connections, connection)
	return connection
end

-- Fix: Tự động bỏ focus khỏi TextBox khi click ra ngoài để click đầu tiên luôn ăn
Connect(UserInputService.InputBegan, function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		local focused = UserInputService:GetFocusedTextBox()
		if focused then
			focused:ReleaseFocus()
		end
	end
end)

-- ==================== ĐA NGÔN NGỮ TỰ ĐỘNG THEO ROBLOX ====================
local function ReadLocale()
	local locale = nil
	pcall(function() locale = LocalPlayer.LocaleId end)
	if type(locale) ~= "string" or locale == "" then
		pcall(function() locale = LocalizationService.RobloxLocaleId end)
	end
	if type(locale) ~= "string" or locale == "" then locale = "en-us" end
	return string.lower(locale:gsub("_", "-"))
end


local Lang = {
	vi = {
		Title="VAMPIRE OPTIMIZER V7.9.13", Search="Tìm kiếm tính năng...", Restore="Khôi phục đồ họa gốc", Save="Lưu cấu hình",
		FlatPlastic="Làm phẳng vật liệu (Nhựa)", FlatPlasticDesc="Đổi bề mặt sang nhựa; bỏ qua khối Lucky",
		RemoveTextures="Ẩn Texture và Decal", RemoveTexturesDesc="Ẩn texture và decal trên bề mặt",
		RemoveShadows="Tắt bóng đổ", RemoveShadowsDesc="Tắt bóng của vật thể để giảm tải đồ họa",
		FullBrightTitle="Full Bright (tăng độ sáng màn hình)", FullBrightDesc="Tự quét và giữ môi trường sáng trên máy bạn; tắt để khôi phục ánh sáng ban đầu",
		FxScaleTitle="Giảm hiệu ứng (0% - 100%)", FxScaleDesc="0% = tắt; 50% = giảm một nửa; 100% = mặc định",
		RenderDistTitle="Fog / Atmosphere Distance", RenderDistDesc="200 = sương dày; 100000 = giảm sương. Không tăng tải map.",
        FogAtmosphereStatus="Đã phát hiện Atmosphere: %d | đang chỉnh Density/Haze", FogLegacyStatus="Không phát hiện Atmosphere | đang chỉnh Fog truyền thống",
		EngineQualityTitle="Chất lượng đồ họa", EngineQualityDesc="Level engine 1 - 21; 1 nhẹ nhất.", EngineQualityDesc10="Thang Roblox 1 - 10 (quy đổi Level01 - 21).",
		ResolutionTitle="Tự nhận diện độ phân giải / tối ưu đồ họa", ResolutionDesc="Nhận diện độ phân giải và tự co giãn giao diện từ 256×144 đến 7680×4320. Chỉ giảm Graphics Level, không ép độ phân giải render thật.", ResolutionStatus="Viewport: %dx%d | Màn hình: %s",
		LiteTerrain="Tối ưu địa hình", LiteTerrainDesc="Giảm sóng nước, phản xạ và cỏ trang trí",
		SkyTitle="Tùy chọn bầu trời", SkyDesc="Chuyển giữa bầu trời Galaxy và bầu trời gốc",
		SkyGalaxy="Bầu trời Galaxy", SkyDefault="Bầu trời gốc của game",
		RestoredSuccess="Đã khôi phục đồ họa gốc!", SavedSuccess="Đã lưu cấu hình!",
		AreaTitle="Kiểm tra mở rộng map (Client)", AreaDesc="Chỉ kiểm tra vật thể đã nhận; không thể ép server mở rộng Streaming",
		AreaStatus="Vật thể trong bán kính 512 studs: %s | RAM: %s", MonitorOn="THEO DÕI: BẬT", MonitorOff="THEO DÕI: TẮT", Scan="QUÉT NGAY",
		HairFlatTitle="Tóc nhựa một màu (tự bật)", HairFlatDesc="Biến tóc người chơi thành nhựa SmoothPlastic một màu. Chỉ thấy trên máy bạn.",
		StripClothingTitle="Xóa toàn bộ quần áo", StripClothingDesc="Gỡ classic + layered: áo, T-Shirt, áo khoác, quần, váy, giày... Chỉ thấy trên máy bạn.",
        HairColorTitle="Tóc một màu theo màu gốc", HairColorDesc="Đọc màu trung bình từ texture tóc gốc. Không đọc được màu thì tóc giữ texture.", HairRescan="QUÉT LẠI TÓC", HairRescanDone="Đã quét lại tóc.", HairRescanEnable="Hãy bật Tóc nhựa trước.", HairSolidOn="MỘT MÀU: BẬT", HairSolidOff="MỘT MÀU: TẮT", HairStats="Một màu: %s | Chỉ làm phẳng: %s | Đang xử lý: %s", 
        TeleportPersistTitle="Tự chạy lại sau khi chuyển server", TeleportPersistDesc="Tự lưu bản sao vào workspace, tự chạy lại sau MỌI lần teleport",
		AutoSaveTitle="Tự động lưu tùy chọn", AutoSaveDesc="Tự lưu sau khi thay đổi (cần executor hỗ trợ ghi file)",
		ServerHopTitle="Đổi server công khai ngẫu nhiên", ServerHopDesc="Gửi yêu cầu Roblox matchmaking vào một phiên công khai của game hiện tại.", ServerHopButton="ĐỔI SERVER", ServerHopCopy="SAO CHÉP LINK SERVER", ServerHopCooldown="Vui lòng đợi trước khi thử lại.", ServerHopCopied="Đã sao chép link server.", ServerHopCopyManual="Không có clipboard API; mở link thủ công.", 
        On="BẬT", Off="TẮT", WaitingCharacter="Đang chờ nhân vật...",
        HotkeyTitle="Phím tắt ẩn/hiện UI", HotkeyDesc="Dùng phím đã chọn để ẩn/hiện menu và toàn bộ nút nổi (logo + vòng tròn đỏ).", HotkeyNone="KHÔNG CÓ", HotkeyWaiting="ĐANG CHỜ PHÍM...", HotkeyClear="XÓA PHÍM",
        HiddenLegoTitle="Ẩn logo Lego (giữ vòng tròn đỏ)", HiddenLegoDesc="Ẩn biểu tượng ở giữa; vẫn giữ nút tròn đỏ để mở/đóng menu.",
        StartHiddenTitle="Ẩn menu khi khởi động", StartHiddenDesc="Khi chạy script hoặc vào server mới, menu tự ẩn; nút nổi chỉ hiện nếu tùy chọn Ẩn toàn bộ nút Lego đang tắt.",
        FloatSeeThroughTitle="Nút nổi xuyên thấu", FloatSeeThroughDesc="Nút tròn bóng mờ, vẫn nhìn thấy chữ và thông báo game phía sau",
        FloatDragHint="Kéo nút nổi để đổi vị trí (tự lưu, không vượt màn hình)",
	},
	en = {
		Title="VAMPIRE OPTIMIZER V7.9.13", Search="Search features...", Restore="Restore original graphics", Save="Save settings",
		FlatPlastic="Flat materials (Plastic)", FlatPlasticDesc="Convert surfaces to plastic; skips Lucky blocks",
		RemoveTextures="Hide textures and decals", RemoveTexturesDesc="Hide surface textures and decals",
		RemoveShadows="Disable shadows", RemoveShadowsDesc="Disable object shadows to reduce graphics load",
		FullBrightTitle="Full Bright (brighten your screen)", FullBrightDesc="Auto-scans and keeps your local scene bright; turn off to restore original lighting",
		FxScaleTitle="Effect reduction (0% - 100%)", FxScaleDesc="0% = off; 50% = half; 100% = default",
		RenderDistTitle="Fog / Atmosphere distance", RenderDistDesc="200 = heavy fog; 100000 = clearer. Does not increase map loading.",
        FogAtmosphereStatus="Atmosphere detected: %d | controlling Density/Haze", FogLegacyStatus="No Atmosphere detected | controlling legacy Fog",
		EngineQualityTitle="Graphics quality", EngineQualityDesc="Engine levels 1 - 21; 1 is lightest.", EngineQualityDesc10="Roblox scale 1 - 10 (mapped to Level01 - 21).",
		ResolutionTitle="Auto-detect resolution / optimize graphics", ResolutionDesc="Detects the viewport and scales the UI from 256×144 up to 7680×4320. Lowers Graphics Level only; it does not force render resolution.", ResolutionStatus="Viewport: %dx%d | Display: %s",
		LiteTerrain="Lite terrain", LiteTerrainDesc="Reduces water waves, reflections, and decorative grass",
		SkyTitle="Sky options", SkyDesc="Switch between Galaxy sky and the game's original sky",
		SkyGalaxy="Galaxy sky", SkyDefault="Game default sky",
		RestoredSuccess="Original graphics restored!", SavedSuccess="Settings saved!",
		AreaTitle="Map expansion check (Client)", AreaDesc="Checks objects already received; cannot force server Streaming expansion",
		AreaStatus="Objects within 512 studs: %s | RAM: %s", MonitorOn="MONITOR: ON", MonitorOff="MONITOR: OFF", Scan="SCAN NOW",
		HairFlatTitle="Solid plastic hair (auto enabled)", HairFlatDesc="Turns every visible player’s hair into one solid SmoothPlastic colour. Local only.",
		StripClothingTitle="Remove all clothing", StripClothingDesc="Strips classic + layered: shirts, T-shirts, jackets, pants, skirts, shoes... Local only.",
        HairColorTitle="Solid hair, original colour", HairColorDesc="Averages the colour of the original hair texture. If unknown, keeps texture.", HairRescan="RESCAN HAIR", HairRescanDone="Rescanned hair.", HairRescanEnable="Turn on Plastic hair first.", HairSolidOn="SOLID: ON", HairSolidOff="SOLID: OFF", HairStats="Solid: %s | Flattened only: %s | Working: %s", 
        TeleportPersistTitle="Re-run after server change", TeleportPersistDesc="Saves itself to workspace, re-runs after EVERY teleport",
		AutoSaveTitle="Auto-save settings", AutoSaveDesc="Saves after changes (requires executor file-write support)",
		ServerHopTitle="Random public server hop", ServerHopDesc="Ask Roblox matchmaking to place you in a public session of this experience.", ServerHopButton="HOP SERVER", ServerHopCopy="COPY SERVER LIST LINK", ServerHopCooldown="Please wait before trying again.", ServerHopCopied="Server list link copied.", ServerHopCopyManual="Clipboard API unavailable; open the link manually.", 
        On="ON", Off="OFF", WaitingCharacter="Waiting for character...",
        HotkeyTitle="Toggle UI Hotkey", HotkeyDesc="Use the selected key to hide/show the menu and the entire floating button (logo + red circle).", HotkeyNone="NONE", HotkeyWaiting="WAITING FOR KEY...", HotkeyClear="CLEAR KEY",
        HiddenLegoTitle="Hide Lego logo (keep red circle)", HiddenLegoDesc="Hide only the Lego logo in the center; keep the red circular button visible to open/close the menu.",
        StartHiddenTitle="Start hidden", StartHiddenDesc="Hide the menu at startup or after a server change; the floating button appears only when its hide option is OFF.",
        FloatSeeThroughTitle="See-through float button", FloatSeeThroughDesc="Soft circular translucent button; game text/notifications stay readable",
        FloatDragHint="Drag the float button to move it (auto-saved, stays on screen)",
	}
}

local FeatureTranslations = {
	vi = { JoinAutoTitle="Nhận diện và theo dõi người chơi" },
	en = { JoinAutoTitle="Detect and follow players" }
}
for locale, entries in pairs(FeatureTranslations) do
	if Lang[locale] then
		for key, value in pairs(entries) do Lang[locale][key] = value end
	end
end

local function ResolveLocaleCode()
	local raw = ReadLocale()
	local base = raw:match("^([a-z]+)") or "en"
	local code = base
	if base == "zh" then
		if raw:find("zh%-tw") or raw:find("zh%-hk") or raw:find("zh%-mo") then
			code = "zhTW"
		else
			code = "zhCN"
		end
	end
	if not Lang[code] then
		local coreLocale = string.lower((LocalizationService.RobloxLocaleId or "en-us"):gsub("_", "-"))
		local coreBase = coreLocale:match("^([a-z]+)") or "en"
		if coreBase == "zh" then
			code = (coreLocale:find("zh%-tw") or coreLocale:find("zh%-hk") or coreLocale:find("zh%-mo")) and "zhTW" or "zhCN"
		else
			code = coreBase
		end
	end
	if not Lang[code] then code = "en" end
	return code
end

local currentLocale = ResolveLocaleCode()
local LanguageRefreshers = {}

local function T(k)
	return (Lang[currentLocale] and Lang[currentLocale][k]) or Lang.en[k] or k
end

local function RegisterLangRefresh(fn)
	if type(fn) == "function" then
		table.insert(LanguageRefreshers, fn)
	end
end

local RefreshAllLanguage

-- ==================== BỘ LƯU TRỮ KHÔI PHỤC CHÍNH XÁC ====================
local Backup = {
	Lighting = {
		GlobalShadows = Lighting.GlobalShadows,
		FogStart = Lighting.FogStart,
		FogEnd = Lighting.FogEnd,
		FogColor = Lighting.FogColor,
		Brightness = Lighting.Brightness,
		ClockTime = Lighting.ClockTime,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		ExposureCompensation = Lighting.ExposureCompensation,
		EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
	},
	InitialEngineQuality = Enum.QualityLevel.Automatic,
	OriginalMaterials = {},
	OriginalMaterialVariants = {},
	OriginalTile = {},
	OriginalTextures = {},
	OriginalShadows = {},
	OriginalFx = {},
	OriginalHairParts = {},
	OriginalHairMeshes = {},
	OriginalHairSurface = {},
	OriginalSkies = {},
	OriginalAtmospheres = setmetatable({}, { __mode = "k" }),
	Terrain = {
		Decoration = false,
		WaterWaveSize = 0.15,
		WaterWaveSpeed = 10,
		WaterReflectance = 1,
		WaterTransparency = 1,
	}
}

pcall(function()
	Backup.InitialEngineQuality = settings().Rendering.QualityLevel
	if workspace.Terrain then
		Backup.Terrain.Decoration = workspace.Terrain.Decoration
		Backup.Terrain.WaterWaveSize = workspace.Terrain.WaterWaveSize
		Backup.Terrain.WaterWaveSpeed = workspace.Terrain.WaterWaveSpeed
		Backup.Terrain.WaterReflectance = workspace.Terrain.WaterReflectance
		Backup.Terrain.WaterTransparency = workspace.Terrain.WaterTransparency
	end
end)

local SkyFolder = Instance.new("Folder")
SkyFolder.Name = "VampireBackupSky"
pcall(function() SkyFolder.Parent = game:GetService("ReplicatedStorage") end)

for _, obj in ipairs(Lighting:GetChildren()) do
	if obj:IsA("Sky") or obj:IsA("Atmosphere") or obj:IsA("Clouds") then
		table.insert(Backup.OriginalSkies, obj)
	end
end

local PersistentEnv = shared
pcall(function()
	if type(getgenv) == "function" then
		local env = getgenv()
		if type(env) == "table" then PersistentEnv = env end
	end
end)

-- ==================== QUẢN LÝ CẤU HÌNH LƯU TRỮ ====================
local CONFIG_FILE = "VampireOptimizer_v7_8.json"
local LEGACY_CONFIG_FILES = { "VampireOptimizer_v7_3.json", "VampireOptimizer_v7_2.json", "VampireOptimizer_v7_1.json" }
local Config = {
	FlatPlastic = false,
	RemoveTextures = false,
	RemoveShadows = false,
	FullBright = false,
	FxScale = 100,
	RenderDistance = 100000,
	EngineQuality = 1,
	QualityMode = 21,
	AutoResolutionQuality = true,
	LiteTerrain = false,
	SkyMode = "Default",
	LiveMonitor = true,
	LiveMonitorSet = false,
	FlatHair = true,
	HairSolid = true,
	StripClothing = false,
	TeleportPersist = true,
	AutoSave = true,
	ReloadUrl = "",
    HiddenLego = false,  -- Ẩn logo, chỉ giữ nút tròn màu
    StartHidden = false, -- Ẩn menu lúc khởi động / sau teleport
    ConfigVersion = 2,
    ToggleKey = nil,     -- Mặc định không có phím tắt
    FloatSeeThrough = true, -- Nút nổi xuyên thấu mặc định bật
    FloatPosX = nil,     -- Vị trí X đã lưu (pixel từ mép trái)
    FloatPosY = nil,     -- Vị trí Y đã lưu (pixel từ mép trên)
}

-- V7.9.13: the Graphics Quality slider uses Roblox's own 1-10 scale (same as the in-game Esc menu).
-- Roblox maps those 10 steps onto its 21 engine levels (Enum.QualityLevel.Level01..Level21); this is the approximation used here.
local QualityMap = {}
function QualityMap.ToEngine(n)
	n = math.clamp(math.floor(tonumber(n) or 1), 1, 10)
	return math.clamp(math.floor(1 + (n - 1) * 20 / 9 + 0.5), 1, 21)
end
function QualityMap.ToClassic(engineLevel)
	local e = math.clamp(math.floor(tonumber(engineLevel) or 1), 1, 21)
	return math.clamp(math.floor(1 + (e - 1) * 9 / 20 + 0.5), 1, 10)
end

local function MergeConfigTable(data)
	if type(data) ~= "table" then return end
	-- V7.9.12 stored EngineQuality on a 1-10 scale (marked QualityScale = 10). Convert it back to engine levels (1-21)
	-- and keep that user on the 1-10 slider view.
	if tonumber(data.QualityScale) == 10 then
		if tonumber(data.EngineQuality) then data.EngineQuality = QualityMap.ToEngine(data.EngineQuality) end
		if data.QualityMode == nil then data.QualityMode = 10 end
		data.QualityScale = nil
	end
	local incomingVersion = tonumber(data.ConfigVersion) or 0
	for k, v in pairs(data) do Config[k] = v end
	-- Migrate older startup preference while keeping the floating red-circle button available.
	if incomingVersion < 2 then
		if data.HiddenLego == nil and data.StartHidden ~= nil then
			Config.HiddenLego = data.StartHidden == true
		end
		Config.StartHidden = false
	end
	Config.ConfigVersion = 2
end

local function StoreConfigInMemory()
	local snapshot = {}
	for k, v in pairs(Config) do snapshot[k] = v end
	if typeof(snapshot.ToggleKey) == "EnumItem" then
		snapshot.ToggleKey = snapshot.ToggleKey.Name
	elseif type(snapshot.ToggleKey) ~= "string" then
		snapshot.ToggleKey = nil
	end
	pcall(function() PersistentEnv.VampireOptimizerConfig = snapshot end)
	pcall(function() shared.VampireOptimizerConfig = snapshot end)
end

local function LoadConfig()
	pcall(function() MergeConfigTable(PersistentEnv.VampireOptimizerConfig) end)
	pcall(function() MergeConfigTable(shared.VampireOptimizerConfig) end)
	if type(readfile) ~= "function" or type(isfile) ~= "function" then return end
	local candidates = { CONFIG_FILE }
	for _, legacyName in ipairs(LEGACY_CONFIG_FILES) do table.insert(candidates, legacyName) end
	for _, fileName in ipairs(candidates) do
		local exists = false
		pcall(function() exists = isfile(fileName) end)
		if exists then
			local ok = pcall(function()
				local data = HttpService:JSONDecode(readfile(fileName))
				if type(data) == "table" then MergeConfigTable(data) end
			end)
			if ok then break end
		end
	end
end

local function SaveConfig()
	StoreConfigInMemory()
	if type(writefile) ~= "function" then return true, "memory only" end
	local ok, err = pcall(function()
		-- Enum.KeyCode cannot JSON-encode; store name string instead
		local snapshot = {}
		for k, v in pairs(Config) do snapshot[k] = v end
		if typeof(snapshot.ToggleKey) == "EnumItem" then
			snapshot.ToggleKey = snapshot.ToggleKey.Name
		elseif type(snapshot.ToggleKey) ~= "string" then
			snapshot.ToggleKey = nil
		end
		writefile(CONFIG_FILE, HttpService:JSONEncode(snapshot))
	end)
	return ok, err
end

local AutoSaveRevision = 0
local function QueueAutoSave()
	if not IsRunning then return end
	StoreConfigInMemory()
	if not Config.AutoSave then return end
	AutoSaveRevision += 1
	local revision = AutoSaveRevision
	task.delay(1.0, function()
		if IsRunning and Config.AutoSave and revision == AutoSaveRevision then
			SaveConfig()
		end
	end)
end

LoadConfig()

Config.FxScale = math.clamp(math.floor(tonumber(Config.FxScale) or 100), 0, 100)
Config.RenderDistance = math.clamp(math.floor(tonumber(Config.RenderDistance) or 100000), 200, 100000)
if tostring(Config.EngineQuality):upper() == "AUTO" then
	Config.EngineQuality = "AUTO"
else
	Config.EngineQuality = math.clamp(math.floor(tonumber(Config.EngineQuality) or 1), 1, 21)
end
Config.QualityMode = (tonumber(Config.QualityMode) == 10) and 10 or 21
Config.QualityScale = nil
Config.AutoResolutionQuality = Config.AutoResolutionQuality ~= false
Config.FlatPlastic = Config.FlatPlastic == true
Config.RemoveTextures = Config.RemoveTextures == true
Config.RemoveShadows = Config.RemoveShadows == true
Config.FullBright = Config.FullBright == true
Config.LiteTerrain = Config.LiteTerrain == true
Config.LiveMonitorSet = Config.LiveMonitorSet == true
if Config.LiveMonitorSet then Config.LiveMonitor = Config.LiveMonitor == true else Config.LiveMonitor = true end
Config.FlatHair = true
Config.HairSolid = Config.HairSolid ~= false
Config.StripClothing = Config.StripClothing == true
Config.TeleportPersist = Config.TeleportPersist ~= false
Config.ReloadUrl = (type(Config.ReloadUrl) == "string") and Config.ReloadUrl or ""
if Config.AutoSave == nil then Config.AutoSave = true else Config.AutoSave = Config.AutoSave == true end
Config.SkyMode = (Config.SkyMode == "Galaxy") and "Galaxy" or "Default"
Config.HiddenLego = Config.HiddenLego == true
Config.StartHidden = Config.StartHidden == true
Config.ConfigVersion = 2
Config.FloatSeeThrough = Config.FloatSeeThrough ~= false
do
	local fx = tonumber(Config.FloatPosX)
	local fy = tonumber(Config.FloatPosY)
	Config.FloatPosX = fx
	Config.FloatPosY = fy
end
-- ToggleKey: JSON stores string name; runtime uses Enum.KeyCode
do
	local key = Config.ToggleKey
	if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
		-- already good
	elseif type(key) == "string" and key ~= "" and key ~= "Unknown" then
		local ok, enumItem = pcall(function() return Enum.KeyCode[key] end)
		Config.ToggleKey = (ok and typeof(enumItem) == "EnumItem") and enumItem or nil
	else
		Config.ToggleKey = nil
	end
end

-- ==================== CÁC HÀM XỬ LÝ ĐỒ HỌA ====================
local function isLucky(obj)
	local cur = obj
	while cur and cur ~= workspace do
		if string.find(string.lower(cur.Name), "lucky") then return true end
		cur = cur.Parent
	end
	return false
end

local function isInCharacter(obj)
	local cur = obj
	while cur and cur ~= workspace do
		if cur:IsA("Model") and cur.Parent == workspace and Players:GetPlayerFromCharacter(cur) then
			return true
		end
		cur = cur.Parent
	end
	return false
end

-- Vật cầm trên tay (Tool trong nhân vật, Model gắn vào nhân vật, hoặc viewmodel trong Camera).
-- Chỉ dùng 1 biến local "Held" để không vượt giới hạn 200 local của Lua.
local Held = {}
do
	local BODY = {
		Head = true, Torso = true, HumanoidRootPart = true,
		["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true,
		UpperTorso = true, LowerTorso = true,
		LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
		RightUpperArm = true, RightLowerArm = true, RightHand = true,
		LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
		RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
	}
	-- Part nằm trong phạm vi "đang cầm":
	--   * viewmodel trong Camera (góc nhìn thứ nhất), hoặc
	--   * BẤT KỲ vật nào gắn vào nhân vật (góc nhìn thứ ba): Tool, Model, hoặc khối nằm sâu dưới tay
	--     (vd Character.RightHand.wool_blue.Handle). Bản cũ chỉ nhận Tool/Model nằm TRỰC TIẾP dưới nhân vật,
	--     nên khối nhìn từ bên ngoài bị bỏ sót: texture bị ẩn mà không đổ lại màu -> khối thành đen.
	local function InHeldScope(part)
		local cam = workspace.CurrentCamera
		local cur = part
		local underAccessory = false
		while cur and cur ~= workspace do
			if cam and cur == cam then return true end
			if cur:IsA("Accessory") then underAccessory = true end
			local parent = cur.Parent
			if parent and parent ~= workspace and parent:IsA("Model") and parent.Parent == workspace and Players:GetPlayerFromCharacter(parent) then
				-- cur là con trực tiếp của nhân vật
				if underAccessory then return false end -- tóc, mũ, kính, quần áo: không phải vật cầm
				if cur == part then return not BODY[cur.Name] end -- part gắn thẳng vào nhân vật
				return true -- Tool / Model / Folder / bộ phận cơ thể chứa part này
			end
			cur = parent
		end
		return false
	end

	-- Chỉ KHỐI (len/wool, bê tông, đất sét, kính...) mới được xử lý. Kiếm, cuốc, hiệu ứng... giữ nguyên.
	local BLOCK_HINTS = { "wool", "carpet", "concrete", "clay", "terracotta", "glass" }
	local function NameIsBlock(name)
		local n = (string.lower(name):gsub("[%s_%-]", ""))
		for _, h in ipairs(BLOCK_HINTS) do
			if string.find(n, h, 1, true) then return true end
		end
		return false
	end
	local function IsBlockPart(part)
		if BODY[part.Name] then return false end
		-- 1) Tên part hoặc tên Tool/Model chứa wool, concrete, clay...
		local cam = workspace.CurrentCamera
		local cur = part
		while cur and cur ~= workspace and cur ~= cam do
			if cur.Name == "DebugRay" then return false end
			if cur:IsA("Model") and Players:GetPlayerFromCharacter(cur) then break end
			if NameIsBlock(cur.Name) then return true end
			cur = cur.Parent
		end
		-- 2) Hoặc là một khối lập phương (Part thường, không mesh)
		if part.ClassName == "Part" and not part:FindFirstChildOfClass("SpecialMesh") then
			local s = part.Size
			local mx, mn = math.max(s.X, s.Y, s.Z), math.min(s.X, s.Y, s.Z)
			if mn > 0.4 and mx / mn <= 1.25 then return true end
		end
		return false
	end

	-- Khối nằm ngoài model nhân vật (vd Workspace.Items.wool_blue) nhưng được Weld/Motor6D vào tay nhân vật.
	local function WeldedToBody(part, depth, visited)
		if not part:IsDescendantOf(workspace) then return false end
		local ok, joints = pcall(function() return part:GetJoints() end)
		if not ok or type(joints) ~= "table" then return false end
		for _, j in ipairs(joints) do
			for _, side in ipairs({ "Part0", "Part1" }) do
				local other = nil
				pcall(function() other = j[side] end)
				if typeof(other) == "Instance" and other:IsA("BasePart") and not visited[other] then
					visited[other] = true
					if BODY[other.Name] and isInCharacter(other) then return true end
					if depth > 1 and not other.Anchored and WeldedToBody(other, depth - 1, visited) then return true end
				end
			end
		end
		return false
	end

	local Seen, SeenCount = {}, 0
	function Held.IsHeld(obj)
		if not obj then return false end
		local part = obj
		if not obj:IsA("BasePart") then part = obj.Parent end -- Texture / Decal / SurfaceAppearance / SpecialMesh
		if not part or not part:IsA("BasePart") then return false end
		if not InHeldScope(part) then
			-- Ngoài phạm vi: vẫn nhận nếu là KHỐI không neo đang hàn vào thân nhân vật.
			if part.Anchored or not IsBlockPart(part) then return false end
			return WeldedToBody(part, 2, { [part] = true })
		end
		if IsBlockPart(part) then return true end
		-- Ghi log 1 lần cho mỗi vật không phải khối để dễ kiểm tra nếu khối cầm tay không được nhận ra.
		if SeenCount < 40 then
			local key = part:GetFullName() .. "|" .. part.ClassName
			if string.find(key, "3DClothing", 1, true) or BODY[part.Name] then return false end
			if string.find(key, "DebugRay", 1, true) then return false end
			if not Seen[key] then
				Seen[key] = true
				SeenCount += 1
				print(string.format("[Vampire Optimizer] Held (not a block, left as is): %s (%s) size=%.1f,%.1f,%.1f",
					part:GetFullName(), part.ClassName, part.Size.X, part.Size.Y, part.Size.Z))
			end
		end
		return false
	end
end

-- Flat Plastic is applied in cancellable passes. Map parts can be created before their
-- MaterialVariant / final properties are assigned, especially while joining a new server.
local FlatPlasticRevision = 0

local function ApplyFlatMaterialVariant(v)
	if not v or not v:IsA("MaterialVariant") or isLucky(v) then return end
	if Backup.OriginalTile[v] == nil then Backup.OriginalTile[v] = v.StudsPerTile end
	pcall(function() v.StudsPerTile = 100000 end)
end

local function ApplyFlatPlasticPart(v)
	if not Config.FlatPlastic or not v or not v:IsA("BasePart") or not v.Parent then return end
	if isLucky(v) or isInCharacter(v) or Held.IsHeld(v) then return end
	local mv = ""
	pcall(function() mv = v.MaterialVariant end)
	-- Preserve custom variants; their tiling is handled by ApplyFlatMaterialVariant.
	if mv == nil or mv == "" then
		if Backup.OriginalMaterials[v] == nil then Backup.OriginalMaterials[v] = v.Material end
		if Backup.OriginalMaterialVariants[v] == nil then Backup.OriginalMaterialVariants[v] = mv end
		pcall(function() v.Material = Enum.Material.SmoothPlastic end)
	end
end

local function ApplyFlatPlasticPass(revision)
	if not IsRunning or revision ~= FlatPlasticRevision or not Config.FlatPlastic then return end
	local count = 0
	for _, v in ipairs(MaterialService:GetDescendants()) do
		if not IsRunning or revision ~= FlatPlasticRevision or not Config.FlatPlastic then return end
		if v:IsA("MaterialVariant") then ApplyFlatMaterialVariant(v) end
		count += 1
		if count % 1000 == 0 then task.wait() end
	end
	count = 0
	for _, v in ipairs(workspace:GetDescendants()) do
		if not IsRunning or revision ~= FlatPlasticRevision or not Config.FlatPlastic then return end
		if v:IsA("BasePart") then ApplyFlatPlasticPart(v) end
		count += 1
		if count % 1000 == 0 then task.wait() end
	end
end

local function SetFlatPlastic(enable)
	Config.FlatPlastic = enable == true
	FlatPlasticRevision += 1
	local revision = FlatPlasticRevision
	task.spawn(function()
		if Config.FlatPlastic then
			-- Re-scan while a destination server is finishing its map load.
			for pass, delaySeconds in ipairs({ 0, 0.6, 1.5 }) do
				if delaySeconds > 0 then task.wait(delaySeconds) end
				if not IsRunning or revision ~= FlatPlasticRevision or not Config.FlatPlastic then return end
				ApplyFlatPlasticPass(revision)
			end
		else
			-- Restore only while this disable request is still the latest toggle.
			local count = 0
			for part, mat in pairs(Backup.OriginalMaterials) do
				if not IsRunning or revision ~= FlatPlasticRevision or Config.FlatPlastic then return end
				if part and part.Parent then
					pcall(function()
						part.Material = mat
						local mv = Backup.OriginalMaterialVariants[part]
						if mv ~= nil then part.MaterialVariant = mv end
					end)
				end
				count += 1
				if count % 1000 == 0 then task.wait() end
			end
			count = 0
			for variant, tile in pairs(Backup.OriginalTile) do
				if not IsRunning or revision ~= FlatPlasticRevision or Config.FlatPlastic then return end
				if variant and variant.Parent then pcall(function() variant.StudsPerTile = tile end) end
				count += 1
				if count % 1000 == 0 then task.wait() end
			end
		end
		if revision == FlatPlasticRevision and Held.Refresh then Held.Refresh() end
	end)
	QueueAutoSave()
end

local function SetRemoveTextures(enable)
	Config.RemoveTextures = enable
	task.spawn(function()
		for _, v in ipairs(workspace:GetDescendants()) do
			if (v:IsA("Texture") or v:IsA("Decal")) and not isLucky(v) and not Held.IsHeld(v) then
				if enable then
					if Backup.OriginalTextures[v] == nil then Backup.OriginalTextures[v] = v.Transparency end
					v.Transparency = 1
				else
					local old = Backup.OriginalTextures[v]
					if old ~= nil and v and v.Parent then v.Transparency = old end
				end
			end
		end
		if Held.Refresh then Held.Refresh() end
	end)
	QueueAutoSave()
end

local function SetRemoveShadows(enable)
	Config.RemoveShadows = enable
	Lighting.GlobalShadows = enable and false or Backup.Lighting.GlobalShadows
	task.spawn(function()
		for _, v in ipairs(workspace:GetDescendants()) do
			if v:IsA("BasePart") then
				if enable then
					if Backup.OriginalShadows[v] == nil then Backup.OriginalShadows[v] = v.CastShadow end
					v.CastShadow = false
				else
					local old = Backup.OriginalShadows[v]
					if old ~= nil and v and v.Parent then v.CastShadow = old end
				end
			end
		end
	end)
	QueueAutoSave()
end

local function ApplyFxScale(pct)
	pct = math.clamp(pct, 0, 100)
	Config.FxScale = pct
	local f = pct / 100
	task.spawn(function()
		for _, v in ipairs(workspace:GetDescendants()) do
			if v:IsA("ParticleEmitter") then
				if Backup.OriginalFx[v] == nil then Backup.OriginalFx[v] = { Enabled = v.Enabled, Rate = v.Rate, Size = v.Size } end
				if pct == 0 then v.Enabled = false else
					v.Enabled = Backup.OriginalFx[v].Enabled
					v.Rate = Backup.OriginalFx[v].Rate * f
					v.Size = Backup.OriginalFx[v].Size
				end
			elseif v:IsA("Fire") or v:IsA("Smoke") then
				if Backup.OriginalFx[v] == nil then Backup.OriginalFx[v] = { Enabled = v.Enabled, Size = v.Size } end
				if pct == 0 then v.Enabled = false else
					v.Enabled = Backup.OriginalFx[v].Enabled
					v.Size = (pct == 100) and Backup.OriginalFx[v].Size or math.max(0.01, Backup.OriginalFx[v].Size * f)
				end
			elseif v:IsA("Light") then
				if Backup.OriginalFx[v] == nil then Backup.OriginalFx[v] = { Enabled = v.Enabled, Brightness = v.Brightness } end
				if pct == 0 then v.Enabled = false else
					v.Enabled = Backup.OriginalFx[v].Enabled
					v.Brightness = (pct == 100) and Backup.OriginalFx[v].Brightness or math.max(0, Backup.OriginalFx[v].Brightness * f)
				end
			elseif v:IsA("Beam") or v:IsA("Trail") then
				if Backup.OriginalFx[v] == nil then Backup.OriginalFx[v] = { Enabled = v.Enabled } end
				v.Enabled = (pct > 0) and Backup.OriginalFx[v].Enabled
			end
		end
	end)
	QueueAutoSave()
end

local FogApplyRevision = 0
local FogOverrideEnabled = true
-- Keep the Atmosphere helpers in one table to avoid increasing the chunk's local-register count.
local AtmosphereControl = {
	Hooks = setmetatable({}, { __mode = "k" }),
	Applying = false,
	RefreshStatus = nil,
}

AtmosphereControl.Capture = function(atmosphere)
	if not atmosphere or not atmosphere:IsA("Atmosphere") then return end
	if Backup.OriginalAtmospheres[atmosphere] ~= nil then return end
	local ok, state = pcall(function()
		return { Density = atmosphere.Density, Haze = atmosphere.Haze }
	end)
	if ok and state then Backup.OriginalAtmospheres[atmosphere] = state end
end

AtmosphereControl.Count = function()
	local count = 0
	for _, obj in ipairs(Lighting:GetDescendants()) do
		if obj:IsA("Atmosphere") then count += 1 end
	end
	return count
end

-- Atmosphere makes Lighting's legacy Fog properties inactive. Map the same
-- 200..100000 slider to Density/Haze so the control has a visible local effect.
-- Lower distance = stronger haze; higher distance = clearer atmosphere.
AtmosphereControl.Apply = function(dist)
	local strength = 1 - math.clamp((dist - 200) / 99800, 0, 1)
	local targetDensity = 0.50 * strength
	local targetHaze = 2.50 * strength
	local count = 0
	AtmosphereControl.Applying = true
	local ok = pcall(function()
		for _, obj in ipairs(Lighting:GetDescendants()) do
			if obj:IsA("Atmosphere") then
				AtmosphereControl.Capture(obj)
				pcall(function()
					obj.Density = targetDensity
					obj.Haze = targetHaze
				end)
				count += 1
			end
		end
	end)
	AtmosphereControl.Applying = false
	if not ok then return count end
	return count
end

AtmosphereControl.Restore = function()
	AtmosphereControl.Applying = true
	for atmosphere, state in pairs(Backup.OriginalAtmospheres) do
		if atmosphere and state then
			pcall(function()
				atmosphere.Density = state.Density
				atmosphere.Haze = state.Haze
			end)
		end
	end
	AtmosphereControl.Applying = false
end

local function ScheduleFogReapply()
	if not IsRunning or not FogOverrideEnabled then return end
	FogApplyRevision += 1
	local revision = FogApplyRevision
	task.delay(0.25, function()
		if not IsRunning or not FogOverrideEnabled or revision ~= FogApplyRevision then return end
		local dist = math.clamp(math.floor(tonumber(Config.RenderDistance) or 100000), 200, 100000)
		local targetEnd = dist + math.max(1000, math.floor(dist * 0.1))
		local needsApply = false
		local ok = pcall(function()
			needsApply = math.abs(Lighting.FogStart - dist) > 0.01
				or math.abs(Lighting.FogEnd - targetEnd) > 0.01
				or Lighting.FogColor ~= Backup.Lighting.FogColor
		end)
		if ok and needsApply then
			pcall(function()
				Lighting.FogStart = dist
				Lighting.FogEnd = targetEnd
				Lighting.FogColor = Backup.Lighting.FogColor
			end)
		end
		AtmosphereControl.Apply(dist)
		if AtmosphereControl.RefreshStatus then pcall(AtmosphereControl.RefreshStatus) end
	end)
end

AtmosphereControl.Hook = function(atmosphere)
	if not atmosphere or not atmosphere:IsA("Atmosphere") then return end
	AtmosphereControl.Capture(atmosphere)
	if AtmosphereControl.Hooks[atmosphere] then return end
	AtmosphereControl.Hooks[atmosphere] = true
	for _, property in ipairs({ "Density", "Haze" }) do
		Connect(atmosphere:GetPropertyChangedSignal(property), function()
			if not AtmosphereControl.Applying and FogOverrideEnabled then ScheduleFogReapply() end
		end)
	end
end

-- Capture existing Atmosphere objects and track objects inserted during map loads/teleports.
for _, obj in ipairs(Lighting:GetDescendants()) do
	if obj:IsA("Atmosphere") then AtmosphereControl.Hook(obj) end
end
Connect(Lighting.DescendantAdded, function(obj)
	if obj:IsA("Atmosphere") then
		-- Give the experience a moment to assign its initial Density/Haze after parenting.
		task.delay(0.10, function()
			if not IsRunning or not obj or not obj.Parent then return end
			AtmosphereControl.Hook(obj)
			ScheduleFogReapply()
			if AtmosphereControl.RefreshStatus then pcall(AtmosphereControl.RefreshStatus) end
		end)
	end
end)
Connect(Lighting.DescendantRemoving, function(obj)
	if obj:IsA("Atmosphere") and AtmosphereControl.RefreshStatus then
		task.defer(AtmosphereControl.RefreshStatus)
	end
end)

-- The experience may write its own fog values after the queued script starts in a new server.
Connect(Lighting:GetPropertyChangedSignal("FogStart"), ScheduleFogReapply)
Connect(Lighting:GetPropertyChangedSignal("FogEnd"), ScheduleFogReapply)
Connect(Lighting:GetPropertyChangedSignal("FogColor"), ScheduleFogReapply)

local function SetRenderDistance(dist)
	dist = math.clamp(math.floor(tonumber(dist) or 100000), 200, 100000)
	FogOverrideEnabled = true
	Config.RenderDistance = dist
	pcall(function()
		Lighting.FogStart = dist
		Lighting.FogEnd = dist + math.max(1000, math.floor(dist * 0.1))
		Lighting.FogColor = Backup.Lighting.FogColor
	end)
	AtmosphereControl.Apply(dist)
	if AtmosphereControl.RefreshStatus then pcall(AtmosphereControl.RefreshStatus) end
	QueueAutoSave()
end

-- Full Bright chỉ thay đổi Lighting ở client hiện tại. Các giá trị gốc được lưu
-- khi script khởi động để có thể khôi phục chính xác khi người dùng tắt tính năng.
local FullBrightRevision = 0
local FULL_BRIGHT_VALUES = {
	Brightness = 3,
	ClockTime = 14,
	Ambient = Color3.new(1, 1, 1),
	OutdoorAmbient = Color3.new(1, 1, 1),
	ExposureCompensation = 0.5,
}

local function ApplyFullBrightValues()
	if not IsRunning or not Config.FullBright then return end
	for property, value in pairs(FULL_BRIGHT_VALUES) do
		pcall(function() Lighting[property] = value end)
	end
end

local function RestoreFullBrightValues()
	for _, property in ipairs({ "Brightness", "ClockTime", "Ambient", "OutdoorAmbient", "ExposureCompensation" }) do
		local value = Backup.Lighting[property]
		if value ~= nil then pcall(function() Lighting[property] = value end) end
	end
end

local function ScheduleFullBrightReapply()
	if not IsRunning or not Config.FullBright then return end
	task.defer(ApplyFullBrightValues)
end

for _, property in ipairs({ "Brightness", "ClockTime", "Ambient", "OutdoorAmbient", "ExposureCompensation" }) do
	Connect(Lighting:GetPropertyChangedSignal(property), ScheduleFullBrightReapply)
end

local function SetFullBright(enable)
	Config.FullBright = enable == true
	FullBrightRevision += 1
	local revision = FullBrightRevision
	if Config.FullBright then
		ApplyFullBrightValues()
		task.spawn(function()
			while IsRunning and Config.FullBright and revision == FullBrightRevision do
				task.wait(2)
				if IsRunning and Config.FullBright and revision == FullBrightRevision then
					ApplyFullBrightValues()
				end
			end
		end)
	else
		RestoreFullBrightValues()
	end
	QueueAutoSave()
end

local EngineQualityStatusLabel = nil
local EngineQualityStatusText = "Waiting for quality selection"
local function UpdateEngineQualityStatus(message, applied)
	EngineQualityStatusText = tostring(message or "")
	if EngineQualityStatusLabel then
		EngineQualityStatusLabel.Text = EngineQualityStatusText
		EngineQualityStatusLabel.TextColor3 = applied and Color3.fromRGB(120, 220, 145) or Color3.fromRGB(235, 175, 105)
	end
end

local function SetEngineQualityLevel(lvl, preserveConfigured)
	if tostring(lvl):upper() == "AUTO" then
		if preserveConfigured ~= false then Config.EngineQuality = "AUTO" end
		local autoOk, autoErr = pcall(function()
			settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
		end)
		if autoOk then
			UpdateEngineQualityStatus("Requested: Automatic quality", true)
		else
			UpdateEngineQualityStatus("Could not enable Automatic: " .. tostring(autoErr), false)
		end
		Lighting.EnvironmentDiffuseScale = Backup.Lighting.EnvironmentDiffuseScale
		Lighting.EnvironmentSpecularScale = Backup.Lighting.EnvironmentSpecularScale
		QueueAutoSave()
		return
	end
	lvl = math.clamp(math.floor(tonumber(lvl) or 1), 1, 21)
	if preserveConfigured ~= false then Config.EngineQuality = lvl end

	local engineLevel = lvl
	local qualityName = string.format("Level%02d", engineLevel)
	local shownName = qualityName
	if Config.QualityMode == 10 then
		shownName = string.format("Graphics %d/10 (%s)", QualityMap.ToClassic(engineLevel), qualityName)
	end
	local qualityEnum = Enum.QualityLevel[qualityName]
	local setOk, setErr = false, "quality enum unavailable"
	if qualityEnum then
		setOk, setErr = pcall(function()
			settings().Rendering.QualityLevel = qualityEnum
		end)
	end

	local readOk, currentQuality = pcall(function()
		return settings().Rendering.QualityLevel
	end)
	local currentName = "unavailable"
	if readOk and currentQuality ~= nil then
		pcall(function() currentName = currentQuality.Name end)
		if currentName == "unavailable" then currentName = tostring(currentQuality) end
	end

	if setOk and readOk and currentName == qualityName then
		UpdateEngineQualityStatus("Applied to Roblox: " .. shownName, true)
	elseif setOk then
		UpdateEngineQualityStatus("Requested " .. shownName .. " | Roblox reports: " .. tostring(currentName), false)
	else
		UpdateEngineQualityStatus("Failed to apply " .. shownName .. ": " .. tostring(setErr), false)
	end

	if engineLevel <= 5 then
		Lighting.EnvironmentDiffuseScale = 0
		Lighting.EnvironmentSpecularScale = 0
	else
		Lighting.EnvironmentDiffuseScale = Backup.Lighting.EnvironmentDiffuseScale
		Lighting.EnvironmentSpecularScale = Backup.Lighting.EnvironmentSpecularScale
	end
	QueueAutoSave()
end

-- Resolution detection is based on the active 3D camera viewport, not the desktop's native panel resolution.
-- Roblox game scripts do not expose a supported API to force the client render target to 256x144 (144p).
local ResolutionLastApplied = nil
local function GetViewportResolution()
	local camera = workspace.CurrentCamera
	if not camera then return nil end
	local ok, size = pcall(function() return camera.ViewportSize end)
	if not ok or not size or size.X < 1 or size.Y < 1 then return nil end
	return math.floor(size.X + 0.5), math.floor(size.Y + 0.5)
end

-- Exact display profiles requested by the user. The duplicate 4096x2160 entry is intentionally stored once.
local ResolutionProfiles = {
	["7680x4320"] = "8K UHD",
	["5120x2880"] = "5K UHD",
	["4096x2160"] = "DCI 4K",
	["2560x1080"] = "Ultrawide 1080p",
	["3440x1440"] = "Ultrawide 1440p",
	["5120x1440"] = "Super Ultrawide 1440p",
	["7680x2160"] = "Super Ultrawide 2160p",
	["2560x1600"] = "WQXGA",
	["2560x1440"] = "QHD 1440p",
	["2048x1080"] = "2K DCI",
	["1920x1200"] = "WUXGA",
	["1920x1080"] = "Full HD 1080p",
	["1366x768"] = "HD+",
	["1280x720"] = "HD 720p",
	["854x480"] = "480p",
	["640x360"] = "360p",
	["320x240"] = "240p",
	["256x144"] = "144p",
}

local function GetResolutionTier(width, height)
	local exact = ResolutionProfiles[tostring(math.floor(width or 0)) .. "x" .. tostring(math.floor(height or 0))]
	if exact then return exact end
	local aspect = (height and height > 0) and ((width or 0) / height) or 1
	local suffix = aspect >= 2.1 and " Ultrawide" or ""
	if height >= 2160 then return "2160p+" .. suffix end
	if height >= 1440 then return "1440p" .. suffix end
	if height >= 1080 then return "1080p" .. suffix end
	if height >= 900 then return "900p" .. suffix end
	if height >= 720 then return "720p" .. suffix end
	if height >= 480 then return "480p" .. suffix end
	if height >= 360 then return "360p" .. suffix end
	if height >= 240 then return "240p" .. suffix end
	return "144p" .. suffix
end

local function GetAdaptiveQuality(height)
	local requested = 1
	if height >= 2160 then requested = 4
	elseif height >= 1440 then requested = 3
	elseif height >= 1080 then requested = 3
	elseif height >= 720 then requested = 2
	else requested = 1 end
	local saved = tonumber(Config.EngineQuality)
	if not saved then saved = 1 end
	-- Auto mode can only lower (or keep) the user's selected graphics level, never raise it.
	return math.clamp(math.min(saved, requested), 1, 21)
end

local function ApplyResolutionAutoQuality(force)
	if not IsRunning or not Config.AutoResolutionQuality then return end
	local width, height = GetViewportResolution()
	if not width then return end
	local quality = GetAdaptiveQuality(height)
	-- Apply only when the selected quality tier changes; window resizing won't spam settings writes.
	if not force and ResolutionLastApplied == quality then return end
	ResolutionLastApplied = quality
	SetEngineQualityLevel(quality, false)
end

local function SetLiteTerrain(enable)
	Config.LiteTerrain = enable
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if not terrain then QueueAutoSave(); return end
	task.spawn(function()
		pcall(function()
			if enable then
				terrain.Decoration = false
				terrain.WaterWaveSize = 0
				terrain.WaterWaveSpeed = 0
				terrain.WaterReflectance = 0
				terrain.WaterTransparency = 1
			else
				terrain.Decoration = Backup.Terrain.Decoration
				terrain.WaterWaveSize = Backup.Terrain.WaterWaveSize
				terrain.WaterWaveSpeed = Backup.Terrain.WaterWaveSpeed
				terrain.WaterReflectance = Backup.Terrain.WaterReflectance
				terrain.WaterTransparency = Backup.Terrain.WaterTransparency
			end
		end)
	end)
	QueueAutoSave()
end

-- ==================== TÓC SMOOTHPLASTIC ====================
local function IsHairAccessory(accessory)
    if not accessory or not accessory:IsA("Accessory") then return false end
    local isHair = false
    pcall(function() isHair = accessory.AccessoryType == Enum.AccessoryType.Hair end)
    if isHair then return true end
    local lowerName = string.lower(accessory.Name)
    return string.find(lowerName, "hair", 1, true) ~= nil or string.find(lowerName, "bang", 1, true) ~= nil
end

local function FindHairAccessory(obj)
    local current = obj
    while current and current ~= workspace do
        if current:IsA("Accessory") then
            local character = current.Parent
            local owningPlayer = nil
            while character and character ~= workspace do
                if character:IsA("Model") then
                    owningPlayer = Players:GetPlayerFromCharacter(character)
                    if owningPlayer then break end
                end
                character = character.Parent
            end
            if owningPlayer and IsHairAccessory(current) then return current end
            return nil
        end
        current = current.Parent
    end
    return nil
end

Backup.OriginalHairDecals = Backup.OriginalHairDecals or {}
local HairPartState = {}
local HairColorCache = {}
local HairColorInflight = {}

local HAIR_PLACEHOLDER_COLORS = { Color3.fromRGB(163, 162, 165), Color3.fromRGB(255, 255, 255) }
local function IsPlaceholderHairColor(color)
    for _, placeholder in ipairs(HAIR_PLACEHOLDER_COLORS) do
        if math.abs(color.R - placeholder.R) + math.abs(color.G - placeholder.G) + math.abs(color.B - placeholder.B) < 0.06 then return true end
    end
    return false
end

local function MultiplyColors(a, b)
    return Color3.new(a.R * b.R, a.G * b.G, a.B * b.B)
end

local function SampleTextureColor(textureId)
    if type(textureId) ~= "string" or textureId == "" then return nil end
    if HairColorCache[textureId] then return HairColorCache[textureId] end
    if HairColorInflight[textureId] then
        local waited = 0
        while HairColorInflight[textureId] and waited < 8 and IsRunning do
            task.wait(0.1)
            waited += 0.1
        end
        return HairColorCache[textureId]
    end
    HairColorInflight[textureId] = true
    local resultColor = nil
    pcall(function()
        local assetId = tonumber(string.match(textureId, "%d+"))
        local uri = assetId and ("rbxassetid://" .. tostring(assetId)) or textureId
        local content
        local okContent, built = pcall(function() return Content.fromUri(uri) end)
        if okContent then content = built elseif assetId then content = Content.fromAssetId(assetId) end
        if not content then return end

        local image = game:GetService("AssetService"):CreateEditableImageAsync(content)
        if not image then return end

        local width, height = 1, 1
        pcall(function()
            local size = image.Size
            width, height = math.max(1, math.floor(size.X)), math.max(1, math.floor(size.Y))
        end)
        if width * height > 1024 then
            local resized = pcall(function() image:Resize(Vector2.new(32, 32)) end)
            if resized then width, height = 32, 32 end
        end

        local step = math.max(1, math.floor(math.sqrt(width * height / 2048)))
        local r, g, b, weight = 0, 0, 0, 0
        local okBuffer, pixelBuffer = pcall(function() return image:ReadPixelsBuffer(Vector2.new(0, 0), Vector2.new(width, height)) end)
        if okBuffer and typeof(pixelBuffer) == "buffer" then
            for y = 0, height - 1, step do
                for x = 0, width - 1, step do
                    local offset = (y * width + x) * 4
                    local alpha = buffer.readu8(pixelBuffer, offset + 3)
                    if alpha > 40 then
                        r += buffer.readu8(pixelBuffer, offset) * alpha
                        g += buffer.readu8(pixelBuffer, offset + 1) * alpha
                        b += buffer.readu8(pixelBuffer, offset + 2) * alpha
                        weight += alpha
                    end
                end
            end
        else
            local okTable, pixels = pcall(function() return image:ReadPixels(Vector2.new(0, 0), Vector2.new(width, height)) end)
            if okTable and type(pixels) == "table" then
                for y = 0, height - 1, step do
                    for x = 0, width - 1, step do
                        local index = (y * width + x) * 4
                        local alpha = tonumber(pixels[index + 4]) or 0
                        if alpha > 0.16 then
                            r += (tonumber(pixels[index + 1]) or 0) * 255 * alpha
                            g += (tonumber(pixels[index + 2]) or 0) * 255 * alpha
                            b += (tonumber(pixels[index + 3]) or 0) * 255 * alpha
                            weight += alpha
                        end
                    end
                end
            end
        end
        pcall(function() image:Destroy() end)
        if weight > 0 then
            resultColor = Color3.fromRGB(
                math.clamp(math.floor(r / weight + 0.5), 0, 255),
                math.clamp(math.floor(g / weight + 0.5), 0, 255),
                math.clamp(math.floor(b / weight + 0.5), 0, 255)
            )
        end
    end)
    HairColorInflight[textureId] = nil
    if resultColor then HairColorCache[textureId] = resultColor end
    return resultColor
end

local function CollectHairTextureSources(part)
    local info = { textureIds = {}, surfaces = {}, meshes = {}, decals = {}, surfaceTint = nil }
    if part:IsA("MeshPart") then
        local id = ""
        pcall(function() id = part.TextureID end)
        if id ~= "" then table.insert(info.textureIds, id) end
    end
    for _, child in ipairs(part:GetChildren()) do
        if child:IsA("SurfaceAppearance") then
            table.insert(info.surfaces, child)
            local id = ""
            pcall(function() id = child.ColorMap end)
            if id ~= "" then table.insert(info.textureIds, 1, id) end
            pcall(function() if not IsPlaceholderHairColor(child.Color) then info.surfaceTint = child.Color end end)
        elseif child:IsA("SpecialMesh") then
            table.insert(info.meshes, child)
            local id = ""
            pcall(function() id = child.TextureId end)
            if id ~= "" then table.insert(info.textureIds, id) end
        elseif child:IsA("Texture") or child:IsA("Decal") then
            table.insert(info.decals, child)
            local id = ""
            pcall(function() id = child.Texture end)
            if id ~= "" then table.insert(info.textureIds, id) end
        end
    end
    return info
end

local function FlattenHairSurfaces(info)
    for _, surface in ipairs(info.surfaces) do
        if Backup.OriginalHairSurface[surface] == nil then
            local original = { Parent = surface.Parent, NormalMap = "", MetalnessMap = "", RoughnessMap = "" }
            pcall(function() original.NormalMap = surface.NormalMap end)
            pcall(function() original.MetalnessMap = surface.MetalnessMap end)
            pcall(function() original.RoughnessMap = surface.RoughnessMap end)
            Backup.OriginalHairSurface[surface] = original
        end
        pcall(function() surface.NormalMap = "" end)
        pcall(function() surface.MetalnessMap = "" end)
        pcall(function() surface.RoughnessMap = "" end)
    end
end

local function StripHairTextures(part, info, finalColor)
    if part:IsA("MeshPart") then pcall(function() part.TextureID = "" end) end
    for _, mesh in ipairs(info.meshes) do
        if Backup.OriginalHairMeshes[mesh] == nil then
            local original = { TextureId = "" }
            pcall(function() original.TextureId = mesh.TextureId end)
            Backup.OriginalHairMeshes[mesh] = original
        end
        pcall(function() mesh.TextureId = "" end)
    end
    for _, surface in ipairs(info.surfaces) do pcall(function() surface.Parent = nil end) end
    for _, decal in ipairs(info.decals) do
        if Backup.OriginalHairDecals[decal] == nil then Backup.OriginalHairDecals[decal] = decal.Transparency end
        pcall(function() decal.Transparency = 1 end)
    end
    pcall(function() part.Color = finalColor end)
end

local function ApplyFlatHairPart(part)
    if not Config.FlatHair or not part or not part:IsA("BasePart") then return end
    if HairPartState[part] then return end
    HairPartState[part] = "pending"

    if Backup.OriginalHairParts[part] == nil then
        local original = { Color = part.Color, Material = part.Material, Reflectance = part.Reflectance, MaterialVariant = "", TextureID = nil }
        pcall(function() original.MaterialVariant = part.MaterialVariant end)
        if part:IsA("MeshPart") then pcall(function() original.TextureID = part.TextureID end) end
        Backup.OriginalHairParts[part] = original
    end
    local original = Backup.OriginalHairParts[part]

    pcall(function()
        part.Material = Enum.Material.SmoothPlastic
        part.Reflectance = 0
        part.MaterialVariant = ""
    end)

    local info = CollectHairTextureSources(part)
    FlattenHairSurfaces(info)

    if not Config.HairSolid then
        HairPartState[part] = "flat"
        return
    end

    task.spawn(function()
        local sampled = nil
        for _, textureId in ipairs(info.textureIds) do
            sampled = SampleTextureColor(textureId)
            if sampled then break end
        end
        if not IsRunning or not Config.FlatHair or not Config.HairSolid or not part.Parent or HairPartState[part] ~= "pending" then
            if HairPartState[part] == "pending" then HairPartState[part] = nil end
            return
        end

        local tint = original.Color
        local tintIsReal = not IsPlaceholderHairColor(tint)
        local finalColor = nil
        if sampled then
            finalColor = sampled
            if tintIsReal then finalColor = MultiplyColors(finalColor, tint) end
            if info.surfaceTint then finalColor = MultiplyColors(finalColor, info.surfaceTint) end
        elseif tintIsReal then
            finalColor = tint
        end

        if finalColor then
            StripHairTextures(part, info, finalColor)
            HairPartState[part] = "solid"
        else
            HairPartState[part] = "flat"
        end
    end)
end

local function ApplyFlatHairAccessory(accessory)
    if not Config.FlatHair or not IsHairAccessory(accessory) or not accessory.Parent then return end
    for _, descendant in ipairs(accessory:GetDescendants()) do
        if descendant:IsA("BasePart") then ApplyFlatHairPart(descendant) end
    end
end

local function ApplyFlatHairObject(obj)
    if not Config.FlatHair or not obj then return end
    local accessory = FindHairAccessory(obj)
    if accessory then ApplyFlatHairAccessory(accessory) end
end

local function ApplyFlatHairToCharacter(character)
    if not character then return end
    for _, obj in ipairs(character:GetChildren()) do
        if IsHairAccessory(obj) then ApplyFlatHairAccessory(obj) end
    end
end

local function ApplyFlatHairToAllPlayers()
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then ApplyFlatHairToCharacter(player.Character) end
    end
end

local function RestoreHairAppearance()
    for obj, original in pairs(Backup.OriginalHairParts) do
        if obj and obj.Parent then
            pcall(function()
                obj.Color = original.Color
                obj.Material = original.Material
                obj.Reflectance = original.Reflectance
                obj.MaterialVariant = original.MaterialVariant
                if original.TextureID ~= nil and obj:IsA("MeshPart") then obj.TextureID = original.TextureID end
            end)
        end
    end
    for mesh, original in pairs(Backup.OriginalHairMeshes) do
        if mesh and mesh.Parent then pcall(function() mesh.TextureId = original.TextureId end) end
    end
    for surface, original in pairs(Backup.OriginalHairSurface) do
        pcall(function()
            if surface.Parent == nil and original.Parent and original.Parent.Parent then surface.Parent = original.Parent end
            surface.NormalMap = original.NormalMap
            surface.MetalnessMap = original.MetalnessMap
            surface.RoughnessMap = original.RoughnessMap
        end)
    end
    for decal, transparency in pairs(Backup.OriginalHairDecals) do
        if decal and decal.Parent then pcall(function() decal.Transparency = transparency end) end
    end
    Backup.OriginalHairParts = {}
    Backup.OriginalHairMeshes = {}
    Backup.OriginalHairSurface = {}
    Backup.OriginalHairDecals = {}
    HairPartState = {}
end

local function RescanHair()
    for part, state in pairs(HairPartState) do
        if state ~= "solid" then HairPartState[part] = nil end
    end
    ApplyFlatHairToAllPlayers()
end

local function GetHairStats()
    local solid, flat, pending = 0, 0, 0
    for part, state in pairs(HairPartState) do
        if part and part.Parent then
            if state == "solid" then solid += 1 elseif state == "flat" then flat += 1 else pending += 1 end
        end
    end
    return solid, flat, pending
end

local function SetFlatHair(enable)
    Config.FlatHair = enable == true
    if Config.FlatHair then ApplyFlatHairToAllPlayers() else RestoreHairAppearance() end
    QueueAutoSave()
end

-- ==================== KHỐI CẦM TRÊN TAY: NHỰA MỘT MÀU, GIỮ MÀU GỐC ====================
-- "Ẩn texture" làm mất lớp texture tạo màu (ví dụ len xanh -> xám). Với vật cầm trên tay, script
-- đọc màu trung bình của texture trước, tô part bằng màu đó, rồi mới ẩn texture. Không đọc được
-- màu thì GIỮ NGUYÊN texture (không bao giờ để khối bị xám).
do
	local function weak() return setmetatable({}, { __mode = "k" }) end
	local Original, Meshes, Surfaces, Decals, State = weak(), weak(), weak(), weak(), weak()
	local Printed = weak()
	local Epoch = 0

	-- Dự phòng cuối: đoán màu từ tên vật phẩm (vd "Blue Wool") khi không đọc được texture.
	local NAME_HINTS = { "wool", "carpet", "concrete", "clay", "glass", "block" }
	local NAME_COLORS = {
		{ "lightblue", Color3.fromRGB(80, 170, 255) }, { "lightgray", Color3.fromRGB(170, 170, 170) },
		{ "lightgrey", Color3.fromRGB(170, 170, 170) }, { "magenta", Color3.fromRGB(220, 50, 200) },
		{ "orange", Color3.fromRGB(255, 140, 20) }, { "yellow", Color3.fromRGB(250, 230, 20) },
		{ "purple", Color3.fromRGB(130, 40, 200) }, { "brown", Color3.fromRGB(120, 70, 30) },
		{ "white", Color3.fromRGB(240, 240, 240) }, { "black", Color3.fromRGB(25, 25, 25) },
		{ "green", Color3.fromRGB(30, 150, 40) }, { "lime", Color3.fromRGB(100, 230, 40) },
		{ "pink", Color3.fromRGB(255, 130, 180) }, { "cyan", Color3.fromRGB(20, 190, 200) },
		{ "gray", Color3.fromRGB(90, 90, 90) }, { "grey", Color3.fromRGB(90, 90, 90) },
		{ "blue", Color3.fromRGB(10, 30, 220) }, { "red", Color3.fromRGB(220, 30, 30) },
	}
	local function ColorFromName(part)
		local cam = workspace.CurrentCamera
		local cur = part
		while cur and cur ~= workspace and cur ~= cam do
			if cur:IsA("Model") and Players:GetPlayerFromCharacter(cur) then break end
			local n = (string.lower(cur.Name):gsub("[%s_%-]", ""))
			local hinted = false
			for _, h in ipairs(NAME_HINTS) do
				if string.find(n, h, 1, true) then hinted = true break end
			end
			if hinted then
				for _, e in ipairs(NAME_COLORS) do
					if string.find(n, e[1], 1, true) then return e[2] end
				end
			end
			cur = cur.Parent
		end
		return nil
	end

	local function Wanted() return Config.FlatPlastic or Config.RemoveTextures end

	local function Collect(part)
		local info = { sources = {}, decals = {}, meshes = {}, surfaces = {} }
		local function add(id, tint, usesPartColor)
			if type(id) == "string" and id ~= "" then
				table.insert(info.sources, { id = id, tint = tint, partColor = usesPartColor })
			end
		end
		if part:IsA("MeshPart") then
			local id = ""
			pcall(function() id = part.TextureID end)
			add(id, nil, true)
		end
		for _, child in ipairs(part:GetChildren()) do
			if child:IsA("SurfaceAppearance") then
				table.insert(info.surfaces, child)
				local id, tint = "", nil
				pcall(function() id = child.ColorMap end)
				pcall(function() if not IsPlaceholderHairColor(child.Color) then tint = child.Color end end)
				add(id, tint, false)
			elseif child:IsA("SpecialMesh") then
				table.insert(info.meshes, child)
				local id = ""
				pcall(function() id = child.TextureId end)
				add(id, nil, true)
			elseif child:IsA("Texture") or child:IsA("Decal") then
				table.insert(info.decals, child)
				local id, tint = "", nil
				pcall(function() id = child.Texture end)
				pcall(function() local c = child.Color3 if c.R + c.G + c.B < 2.94 then tint = c end end)
				add(id, tint, false)
			end
		end
		local mvName = ""
		pcall(function() mvName = part.MaterialVariant end)
		if mvName ~= "" then
			for _, mv in ipairs(MaterialService:GetDescendants()) do
				if mv:IsA("MaterialVariant") and mv.Name == mvName then
					local id = ""
					pcall(function() id = mv.ColorMap end)
					add(id, nil, true)
					break
				end
			end
		end
		return info
	end

	local function Hex(c)
		return string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
	end

	local function Apply(part)
		if not IsRunning or not Wanted() or not part or not part:IsA("BasePart") or not part.Parent then return end
		if State[part] then return end
		local epoch = Epoch
		State[part] = "pending"

		if Original[part] == nil then
			local o = { Color = part.Color, Material = part.Material, Reflectance = part.Reflectance, MaterialVariant = "", TextureID = nil }
			pcall(function() o.MaterialVariant = part.MaterialVariant end)
			if part:IsA("MeshPart") then pcall(function() o.TextureID = part.TextureID end) end
			Original[part] = o
		end
		local o = Original[part]
		local info = Collect(part)

		if Config.FlatPlastic then
			pcall(function()
				part.Material = Enum.Material.SmoothPlastic
				part.Reflectance = 0
			end)
		end
		-- Chỉ "Làm phẳng vật liệu" bật: texture vẫn hiện, màu giữ nguyên.
		if not Config.RemoveTextures then
			State[part] = "flat"
			return
		end

		task.spawn(function()
			local sampled, usedSrc = nil, nil
			for _, src in ipairs(info.sources) do
				sampled = SampleTextureColor(src.id)
				if sampled then usedSrc = src break end
			end
			if not IsRunning or epoch ~= Epoch or not part.Parent then return end

			local final, how = nil, ""
			if sampled then
				final, how = sampled, "texture"
				if usedSrc.tint then final = MultiplyColors(final, usedSrc.tint) end
				if usedSrc.partColor and not IsPlaceholderHairColor(o.Color) then final = MultiplyColors(final, o.Color) end
			elseif #info.sources == 0 and not IsPlaceholderHairColor(o.Color) then
				final, how = o.Color, "part colour"
			else
				final, how = ColorFromName(part), "name"
				if not final and not IsPlaceholderHairColor(o.Color) then final, how = o.Color, "part colour" end
			end

			if not Printed[part] then
				Printed[part] = true
				print(string.format("[Vampire Optimizer] Held item: %s (%s) textures=%d -> %s",
					part:GetFullName(), part.ClassName, #info.sources,
					final and (how .. " #" .. Hex(final)) or "no colour found, textures kept"))
			end

			if final then
				if part:IsA("MeshPart") then pcall(function() part.TextureID = "" end) end
				for _, m in ipairs(info.meshes) do
					if Meshes[m] == nil then pcall(function() Meshes[m] = m.TextureId end) end
					pcall(function() m.TextureId = "" end)
				end
				for _, s in ipairs(info.surfaces) do
					if Surfaces[s] == nil then Surfaces[s] = s.Parent end
					pcall(function() s.Parent = nil end)
				end
				for _, d in ipairs(info.decals) do
					if Decals[d] == nil then pcall(function() Decals[d] = Backup.OriginalTextures[d] or d.Transparency end) end
					pcall(function() d.Transparency = 1 end)
				end
				pcall(function()
					part.Color = final
					part.MaterialVariant = ""
				end)
				State[part] = "solid"
			else
				State[part] = "flat"
			end
		end)
	end

	local function Restore()
		Epoch += 1
		for part, o in pairs(Original) do
			if part and part.Parent then
				pcall(function()
					part.Color = o.Color
					part.Material = o.Material
					part.Reflectance = o.Reflectance
					part.MaterialVariant = o.MaterialVariant
					if o.TextureID ~= nil and part:IsA("MeshPart") then part.TextureID = o.TextureID end
				end)
			end
		end
		for m, id in pairs(Meshes) do
			if m and m.Parent then pcall(function() m.TextureId = id end) end
		end
		for s, parent in pairs(Surfaces) do
			pcall(function()
				if parent and parent.Parent and s.Parent == nil then s.Parent = parent end
			end)
		end
		for d, t in pairs(Decals) do
			if d and d.Parent then pcall(function() d.Transparency = t end) end
		end
		Original, Meshes, Surfaces, Decals, State = weak(), weak(), weak(), weak(), weak()
	end

	local function ScanAll()
		local cam = workspace.CurrentCamera
		if cam then
			for _, d in ipairs(cam:GetDescendants()) do
				if d:IsA("BasePart") and Held.IsHeld(d) then Apply(d) end
			end
		end
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			if character then
				for _, d in ipairs(character:GetDescendants()) do
					if d:IsA("BasePart") and Held.IsHeld(d) then Apply(d) end
				end
			end
		end
		-- Khối cầm tay nằm ngoài model nhân vật (hàn vào tay): quét workspace, nhường CPU để không giật.
		local scanEpoch = Epoch
		task.spawn(function()
			local n = 0
			for _, d in ipairs(workspace:GetDescendants()) do
				if d:IsA("BasePart") and not d.Anchored and Held.IsHeld(d) then Apply(d) end
				n += 1
				if n % 1500 == 0 then task.wait() end
				if not IsRunning or scanEpoch ~= Epoch then return end
			end
		end)
	end

	function Held.Refresh()
		Restore()
		if IsRunning and Wanted() then ScanAll() end
	end

	function Held.OnAdded(v)
		if not IsRunning or not Wanted() then return end
		if v:IsA("BasePart") then
			if Held.IsHeld(v) then Apply(v) end
		elseif v:IsA("JointInstance") or v:IsA("WeldConstraint") then
			task.delay(0.15, function()
				if not IsRunning or not v.Parent then return end
				for _, side in ipairs({ "Part0", "Part1" }) do
					local p = nil
					pcall(function() p = v[side] end)
					if typeof(p) == "Instance" and p:IsA("BasePart") and p.Parent and not State[p] and Held.IsHeld(p) then
						Apply(p)
					end
				end
			end)
		elseif v:IsA("Texture") or v:IsA("Decal") or v:IsA("SurfaceAppearance") or v:IsA("SpecialMesh") then
			local p = v.Parent
			if p and p:IsA("BasePart") and Held.IsHeld(p) then
				-- Texture đến sau part: xử lý lại part này.
				if State[p] == "solid" or State[p] == "flat" then State[p] = nil end
				task.delay(0.15, function()
					if IsRunning and p.Parent then Apply(p) end
				end)
			end
		end
	end
end

local function HookPlayerHair(player)
    local function onCharacter(character)
        task.defer(function()
            if IsRunning and Config.FlatHair and character and character.Parent then ApplyFlatHairToCharacter(character) end
        end)
    end
    if player.Character then onCharacter(player.Character) end
    Connect(player.CharacterAdded, onCharacter)
end
for _, player in ipairs(Players:GetPlayers()) do HookPlayerHair(player) end
Connect(Players.PlayerAdded, HookPlayerHair)

-- ==================== XÓA TOÀN BỘ QUẦN ÁO (Classic + Layered) ====================
Backup.OriginalClothing = Backup.OriginalClothing or {}
Backup.OriginalClothingParts = Backup.OriginalClothingParts or {}
Backup.OriginalClothingAccParent = Backup.OriginalClothingAccParent or {}

local CLOTHING_ACCESSORY_TYPES = {}
pcall(function()
	local types = {
		"TShirt", "Shirt", "Pants", "Jacket", "Sweater", "Shorts",
		"DressSkirt", "LeftShoe", "RightShoe", "TeeShirt",
	}
	for _, name in ipairs(types) do
		local ok, enumItem = pcall(function() return Enum.AccessoryType[name] end)
		if ok and enumItem then CLOTHING_ACCESSORY_TYPES[enumItem] = true end
	end
end)

local CLOTHING_NAME_KEYS = {
	"shirt", "tshirt", "t-shirt", "tee", "pant", "jacket", "sweater",
	"short", "dress", "skirt", "shoe", "boot", "sock", "clothing",
	"hoodie", "coat", "vest", "blouse", "jean", "trouser",
}

local function IsClassicClothing(obj)
	if not obj then return false end
	return obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic")
end

local function IsClothingAccessory(acc)
	if not acc or not acc:IsA("Accessory") then return false end
	-- Không đụng tóc / mặt / gear nếu không phải clothing type
	local ok, accType = pcall(function() return acc.AccessoryType end)
	if ok and accType ~= nil then
		if CLOTHING_ACCESSORY_TYPES[accType] then return true end
		-- Hair / Hat / Face / Neck... giữ nguyên
		pcall(function()
			if accType == Enum.AccessoryType.Hair or accType == Enum.AccessoryType.Hat
				or accType == Enum.AccessoryType.Face or accType == Enum.AccessoryType.Neck
				or accType == Enum.AccessoryType.Shoulder or accType == Enum.AccessoryType.Front
				or accType == Enum.AccessoryType.Back or accType == Enum.AccessoryType.Waist
				or accType == Enum.AccessoryType.Eyebrow or accType == Enum.AccessoryType.Eyelash then
				-- không phải quần áo
			end
		end)
		if CLOTHING_ACCESSORY_TYPES[accType] then return true end
		-- Unknown: thử theo tên
	end
	local lower = string.lower(acc.Name)
	for _, key in ipairs(CLOTHING_NAME_KEYS) do
		if string.find(lower, key, 1, true) then return true end
	end
	return false
end

local function IsRemovableClothing(obj)
	if not obj then return false end
	if IsClassicClothing(obj) then return true end
	if obj:IsA("Accessory") and IsClothingAccessory(obj) then return true end
	if obj:IsA("CharacterMesh") then return true end -- R6 clothing meshes
	return false
end

local function HideAccessoryVisual(acc)
	if Backup.OriginalClothingAccParent[acc] == nil then
		Backup.OriginalClothingAccParent[acc] = acc.Parent
	end
	for _, d in ipairs(acc:GetDescendants()) do
		if d:IsA("BasePart") then
			if Backup.OriginalClothingParts[d] == nil then
				Backup.OriginalClothingParts[d] = {
					Transparency = d.Transparency,
					LocalTransparencyModifier = (d.LocalTransparencyModifier or 0),
				}
			end
			pcall(function()
				d.Transparency = 1
				d.LocalTransparencyModifier = 1
			end)
		elseif d:IsA("Decal") or d:IsA("Texture") then
			if Backup.OriginalClothingParts[d] == nil then
				Backup.OriginalClothingParts[d] = { Transparency = d.Transparency }
			end
			pcall(function() d.Transparency = 1 end)
		elseif d:IsA("MeshPart") then
			if Backup.OriginalClothingParts[d] == nil then
				Backup.OriginalClothingParts[d] = {
					Transparency = d.Transparency,
					TextureID = d.TextureID,
				}
			end
			pcall(function()
				d.Transparency = 1
			end)
		end
	end
	-- Ẩn hẳn accessory khỏi character (local)
	pcall(function() acc.Parent = nil end)
end

local function StripClothingInstance(obj)
	if not Config.StripClothing or not obj then return end
	if not IsRemovableClothing(obj) then return end

	if obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") then
		if Backup.OriginalClothing[obj] ~= nil then
			if obj:IsA("Shirt") then pcall(function() obj.ShirtTemplate = "" end)
			elseif obj:IsA("Pants") then pcall(function() obj.PantsTemplate = "" end)
			elseif obj:IsA("ShirtGraphic") then pcall(function() obj.Graphic = "" end)
			end
			return
		end
		local original = {}
		if obj:IsA("Shirt") then
			pcall(function() original.ShirtTemplate = obj.ShirtTemplate end)
			pcall(function() obj.ShirtTemplate = "" end)
		elseif obj:IsA("Pants") then
			pcall(function() original.PantsTemplate = obj.PantsTemplate end)
			pcall(function() obj.PantsTemplate = "" end)
		elseif obj:IsA("ShirtGraphic") then
			pcall(function() original.Graphic = obj.Graphic end)
			pcall(function() obj.Graphic = "" end)
		end
		Backup.OriginalClothing[obj] = original
		return
	end

	if obj:IsA("Accessory") then
		HideAccessoryVisual(obj)
		return
	end

	if obj:IsA("CharacterMesh") then
		if Backup.OriginalClothing[obj] == nil then
			local original = { Parent = obj.Parent }
			pcall(function() original.MeshId = obj.MeshId end)
			pcall(function() original.OverlayTextureId = obj.OverlayTextureId end)
			Backup.OriginalClothing[obj] = original
		end
		pcall(function() obj.Parent = nil end)
	end
end

local function StripClothingOnCharacter(character)
	if not character then return end
	for _, obj in ipairs(character:GetChildren()) do
		StripClothingInstance(obj)
	end
	for _, obj in ipairs(character:GetDescendants()) do
		if IsClassicClothing(obj) or obj:IsA("CharacterMesh") then
			StripClothingInstance(obj)
		elseif obj:IsA("Accessory") then
			StripClothingInstance(obj)
		end
	end
end

local function StripClothingAllPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then StripClothingOnCharacter(player.Character) end
	end
end

local function RestoreClothingAppearance()
	for obj, original in pairs(Backup.OriginalClothing) do
		if obj then
			pcall(function()
				if obj:IsA("Shirt") and original.ShirtTemplate ~= nil then
					if original.Parent then obj.Parent = original.Parent end
					obj.ShirtTemplate = original.ShirtTemplate
				elseif obj:IsA("Pants") and original.PantsTemplate ~= nil then
					obj.PantsTemplate = original.PantsTemplate
				elseif obj:IsA("ShirtGraphic") and original.Graphic ~= nil then
					obj.Graphic = original.Graphic
				elseif obj:IsA("CharacterMesh") then
					if original.Parent and original.Parent.Parent then
						obj.Parent = original.Parent
					end
				end
			end)
		end
	end
	for part, original in pairs(Backup.OriginalClothingParts) do
		if part and part.Parent then
			pcall(function()
				if original.Transparency ~= nil then part.Transparency = original.Transparency end
				if original.LocalTransparencyModifier ~= nil then
					part.LocalTransparencyModifier = original.LocalTransparencyModifier
				end
				if original.TextureID ~= nil and part:IsA("MeshPart") then
					part.TextureID = original.TextureID
				end
			end)
		end
	end
	for acc, parent in pairs(Backup.OriginalClothingAccParent) do
		if acc and parent and parent.Parent then
			pcall(function() acc.Parent = parent end)
		end
	end
	Backup.OriginalClothing = {}
	Backup.OriginalClothingParts = {}
	Backup.OriginalClothingAccParent = {}
end

local function SetStripClothing(enable)
	Config.StripClothing = enable == true
	if Config.StripClothing then
		StripClothingAllPlayers()
	else
		RestoreClothingAppearance()
	end
	QueueAutoSave()
end

local function HookPlayerClothing(player)
	local function onCharacter(character)
		task.defer(function()
			if IsRunning and Config.StripClothing and character and character.Parent then
				StripClothingOnCharacter(character)
			end
		end)
		task.delay(0.5, function()
			if IsRunning and Config.StripClothing and character and character.Parent then
				StripClothingOnCharacter(character)
			end
		end)
		task.delay(2.0, function()
			if IsRunning and Config.StripClothing and character and character.Parent then
				StripClothingOnCharacter(character)
			end
		end)
		task.delay(5.0, function()
			if IsRunning and Config.StripClothing and character and character.Parent then
				StripClothingOnCharacter(character)
			end
		end)
	end
	if player.Character then onCharacter(player.Character) end
	Connect(player.CharacterAdded, onCharacter)
end
for _, player in ipairs(Players:GetPlayers()) do HookPlayerClothing(player) end
Connect(Players.PlayerAdded, HookPlayerClothing)



-- ==================== QUẢN LÝ BẦU TRỜI ====================
local customSkyInst = nil
local ApplySkyMode
local BuildSkyReport
do
	local SkyBackups = {}
	local HiddenSkyParts = {}
	local galaxyOn = false
	local reassertLogged = 0
	local lastPreloadInfo = "not run yet"
	local preloadPrinted = false

	local GALAXY_PROPS = {
		SkyboxBk = "rbxassetid://159454299",
		SkyboxFt = "rbxassetid://159454293",
		SkyboxLf = "rbxassetid://159454286",
		SkyboxRt = "rbxassetid://159454300",
		SkyboxUp = "rbxassetid://159454288",
		SkyboxDn = "rbxassetid://159454288",
		CelestialBodiesShown = true,
	}

	local function SkyClass(obj)
		if obj:IsA("Sky") then return "Sky" end
		if obj:IsA("Atmosphere") then return "Atmosphere" end
		if obj:IsA("Clouds") then return "Clouds" end
		return nil
	end

	local function StashGameSky(obj)
		if obj == customSkyInst then return end
		local class = SkyClass(obj)
		if not class then return end
		-- V7.8.7: Clouds KHONG duoc doi Parent (Roblox bao "Cloud instance must exist under Terrain node").
		-- Chi tat Enabled tai cho va nho gia tri goc de khoi phuc.
		if class == "Clouds" then
			for _, entry in ipairs(SkyBackups) do
				if entry.inst == obj then
					pcall(function() if obj.Enabled then obj.Enabled = false end end)
					return
				end
			end
			local wasEnabled = true
			pcall(function() wasEnabled = obj.Enabled end)
			table.insert(SkyBackups, { inst = obj, class = class, parent = obj.Parent, enabled = wasEnabled, soft = true })
			pcall(function() obj.Enabled = false end)
			return
		end
		for i = #SkyBackups, 1, -1 do
			if SkyBackups[i].inst == obj then table.remove(SkyBackups, i) end
		end
		table.insert(SkyBackups, { inst = obj, class = class, parent = obj.Parent })
		while #SkyBackups > 20 do table.remove(SkyBackups, 1) end
		pcall(function() obj.Parent = SkyFolder end)
	end

	local function RestoreGameSky()
		local restored = {}
		for i = #SkyBackups, 1, -1 do
			local entry = SkyBackups[i]
			if entry.soft then
				local inst, was = entry.inst, entry.enabled
				if inst and inst.Parent then pcall(function() inst.Enabled = was end) end
			elseif not restored[entry.class] and entry.inst and entry.inst.Parent == SkyFolder then
				restored[entry.class] = true
				local target = entry.parent
				if not target or not target.Parent then target = Lighting end
				pcall(function() entry.inst.Parent = target end)
			end
		end
		SkyBackups = {}
	end

	local function IsDomeShaped(part)
		local size = part.Size
		local smallest = math.min(size.X, size.Y, size.Z)
		local largest = math.max(size.X, size.Y, size.Z)
		if smallest >= 300 then return true end
		return largest >= 1000 and part.CanCollide == false
	end

	local function HasSkyName(part)
		local cur = part
		while cur and cur ~= workspace do
			local name = string.lower(cur.Name)
			if name:find("sky", 1, true) or name:find("dome", 1, true) or name:find("galaxy", 1, true) or name:find("cosmos", 1, true) then return true end
			cur = cur.Parent
		end
		return false
	end

	local function HideSkyPart(part)
		if HiddenSkyParts[part] ~= nil then return end
		HiddenSkyParts[part] = part.Transparency
		pcall(function() part.Transparency = 1 end)
	end

	local function UnhideSkyParts()
		for part, transparency in pairs(HiddenSkyParts) do
			if part and part.Parent then pcall(function() part.Transparency = transparency end) end
		end
		HiddenSkyParts = {}
	end

	local function ApplyGalaxyProps(sky)
		for name, value in pairs(GALAXY_PROPS) do
			local ok, current = pcall(function() return sky[name] end)
			if ok and current ~= value then
				pcall(function() sky[name] = value end)
				if reassertLogged < 3 then
					reassertLogged = reassertLogged + 1
					print("[Vampire Optimizer] Sky: game changed Galaxy property '" .. name .. "' -> restored")
				end
			end
		end
	end

	local function BuildGalaxySky()
		if customSkyInst and customSkyInst.Parent == Lighting then return end
		if customSkyInst then pcall(function() customSkyInst:Destroy() end) end
		local sky = Instance.new("Sky")
		sky.Name = "VampireGalaxySky"
		for name, value in pairs(GALAXY_PROPS) do sky[name] = value end
		sky.Parent = Lighting
		customSkyInst = sky
		for name in pairs(GALAXY_PROPS) do
			pcall(function()
				Connect(sky:GetPropertyChangedSignal(name), function()
					task.defer(function()
						if IsRunning and galaxyOn and sky == customSkyInst and sky.Parent then ApplyGalaxyProps(sky) end
					end)
				end)
			end)
		end
		task.spawn(function()
			local lines, failed = {}, 0
			pcall(function()
				game:GetService("ContentProvider"):PreloadAsync({ sky }, function(contentId, status)
					table.insert(lines, tostring(contentId) .. "=" .. tostring(status))
					if status ~= Enum.AssetFetchStatus.Success then failed = failed + 1 end
				end)
			end)
			lastPreloadInfo = string.format("failed=%d/%d %s", failed, #lines, table.concat(lines, " "))
			if failed > 0 or not preloadPrinted then
				preloadPrinted = true
				print("[Vampire Optimizer] Galaxy sky textures: " .. lastPreloadInfo)
			end
		end)
	end

	local function StashAllNow()
		for _, obj in ipairs(Lighting:GetChildren()) do StashGameSky(obj) end
		local terrain = workspace:FindFirstChildOfClass("Terrain")
		if terrain then
			for _, obj in ipairs(terrain:GetChildren()) do StashGameSky(obj) end
		end
	end

	local function PrintReport(tag, candidates)
		local stashed, hidden, hiddenNames = 0, 0, {}
		for _, entry in ipairs(SkyBackups) do
			if entry.inst and ((entry.soft and entry.inst.Parent) or entry.inst.Parent == SkyFolder) then stashed = stashed + 1 end
		end
		for part in pairs(HiddenSkyParts) do
			hidden = hidden + 1
			if #hiddenNames < 3 then table.insert(hiddenNames, part:GetFullName()) end
		end
		print(string.format("[Vampire Optimizer] Sky (%s): stashed=%d, hidden dome parts=%d%s", tag, stashed, hidden, #hiddenNames > 0 and (" [" .. table.concat(hiddenNames, " | ") .. "]") or ""))
		if candidates and #candidates > 0 then
			print("[Vampire Optimizer] Sky: big cube-like parts NOT hidden: " .. table.concat(candidates, " | "))
		end
	end

	local function ReadProp(inst, name)
		local ok, value = pcall(function() return inst[name] end)
		if ok then return tostring(value) end
		return "?"
	end

	BuildSkyReport = function()
		local lines = {}
		local function add(text) table.insert(lines, text) end
		add(string.format("== VAMPIRE SKY REPORT (V7.8.7) | mode=%s | galaxyOn=%s | placeId=%s ==", tostring(Config.SkyMode), tostring(galaxyOn), tostring(game.PlaceId)))
		add("Lighting: ClockTime=" .. ReadProp(Lighting, "ClockTime") .. ", Brightness=" .. ReadProp(Lighting, "Brightness"))
		add("-- Lighting children --")
		for _, child in ipairs(Lighting:GetChildren()) do add("  " .. child.ClassName .. " '" .. child.Name .. "'") end
		if customSkyInst then
			add("-- Galaxy sky --")
			add("  parent=" .. tostring(customSkyInst.Parent and customSkyInst.Parent.Name) .. " Bk=" .. ReadProp(customSkyInst, "SkyboxBk"))
		end
		add("Galaxy texture preload: " .. lastPreloadInfo)
		add("-- Stashed game sky objects --")
		for _, entry in ipairs(SkyBackups) do add("  " .. entry.class .. " '" .. entry.inst.Name .. "' inFolder=" .. tostring(entry.soft and "disabled-in-place" or (entry.inst.Parent == SkyFolder))) end
		add("-- Hidden sky parts --")
		for part in pairs(HiddenSkyParts) do add("  " .. part:GetFullName()) end
		add("-- Big parts (>= 800 studs) --")
		local count = 0
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("BasePart") then
				local size = d.Size
				if math.max(size.X, size.Y, size.Z) >= 800 then
					count = count + 1
					if count <= 12 then
						add(string.format("  %s %s size=%.0f,%.0f,%.0f transp=%s collide=%s hidden=%s", d.ClassName, d:GetFullName(), size.X, size.Y, size.Z, ReadProp(d, "Transparency"), ReadProp(d, "CanCollide"), tostring(HiddenSkyParts[d] ~= nil)))
					end
				end
			end
		end
		add("  total=" .. count)
		return table.concat(lines, "\n")
	end

	ApplySkyMode = function(mode)
		Config.SkyMode = mode
		QueueAutoSave()
		if mode == "Galaxy" then
			galaxyOn = true
			StashAllNow()
			BuildGalaxySky()
			if customSkyInst then ApplyGalaxyProps(customSkyInst) end
			local candidates = {}
			pcall(function()
				for _, d in ipairs(workspace:GetDescendants()) do
					if d:IsA("BasePart") and IsDomeShaped(d) then
						if HasSkyName(d) then HideSkyPart(d) elseif #candidates < 5 then table.insert(candidates, d:GetFullName()) end
					end
				end
			end)
			PrintReport("Galaxy", candidates)
		else
			galaxyOn = false
			if customSkyInst then
				pcall(function() customSkyInst:Destroy() end)
				customSkyInst = nil
			end
			RestoreGameSky()
			UnhideSkyParts()
		end
	end

	local function WatchContainer(container)
		if not container then return end
		Connect(container.ChildAdded, function(obj)
			if not galaxyOn or obj == customSkyInst or not SkyClass(obj) then return end
			task.defer(function()
				if IsRunning and galaxyOn and obj.Parent == container then StashGameSky(obj) end
			end)
		end)
	end
	WatchContainer(Lighting)
	WatchContainer(workspace:FindFirstChildOfClass("Terrain"))

	Connect(Lighting.ChildRemoved, function(obj)
		if not galaxyOn or obj ~= customSkyInst then return end
		task.delay(0.3, function()
			if IsRunning and galaxyOn and (not customSkyInst or customSkyInst.Parent ~= Lighting) then BuildGalaxySky() end
		end)
	end)

	Connect(workspace.DescendantAdded, function(obj)
		if not galaxyOn or not obj:IsA("BasePart") then return end
		task.defer(function()
			if IsRunning and galaxyOn and obj.Parent and IsDomeShaped(obj) and HasSkyName(obj) then HideSkyPart(obj) end
		end)
	end)

	task.spawn(function()
		while IsRunning do
			task.wait(1)
			if galaxyOn then
				pcall(function()
					StashAllNow()
					BuildGalaxySky()
					if customSkyInst then ApplyGalaxyProps(customSkyInst) end
				end)
			end
		end
	end)
end

local function RestoreAllGraphics()
	-- Restore mode must not be overridden by the Fog persistence watcher.
	FogOverrideEnabled = false
	FogApplyRevision += 1
	SetFlatPlastic(false)
	SetRemoveTextures(false)
	SetRemoveShadows(false)
	SetFlatHair(false)
	SetStripClothing(false)
	ApplyFxScale(100)
	SetFullBright(false)
	Config.RenderDistance = math.clamp(math.floor(Backup.Lighting.FogStart), 200, 100000)
	QueueAutoSave()
	SetLiteTerrain(false)
	ApplySkyMode("Default")
	AtmosphereControl.Restore()
	pcall(function() settings().Rendering.QualityLevel = Backup.InitialEngineQuality end)
	Lighting.GlobalShadows = Backup.Lighting.GlobalShadows
	Lighting.FogStart = Backup.Lighting.FogStart
	Lighting.FogEnd = Backup.Lighting.FogEnd
	Lighting.FogColor = Backup.Lighting.FogColor
	Lighting.EnvironmentDiffuseScale = Backup.Lighting.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = Backup.Lighting.EnvironmentSpecularScale
	local originalQualityLevel = nil
	pcall(function() originalQualityLevel = tonumber(Backup.InitialEngineQuality.Name:match("^Level(%d+)$")) end)
	Config.EngineQuality = originalQualityLevel or "AUTO"
	Config.RenderDistance = math.clamp(math.floor(Backup.Lighting.FogStart), 200, 100000)
end

-- ==================== GIAO DIỆN NGƯỜI DÙNG ====================
local ParentTarget = nil
pcall(function() if type(gethui) == "function" then ParentTarget = gethui() end end)
if not ParentTarget then pcall(function() ParentTarget = game:GetService("CoreGui") end) end
if not ParentTarget then ParentTarget = LocalPlayer:WaitForChild("PlayerGui") end

for _, oldName in ipairs({ "VampireOptimizer_GUI_V6_8", "VampireOptimizer_GUI_V7_2", "VampireOptimizer_GUI_V7_7", "VampireOptimizer_GUI_V7_8", "VampireOptimizer_GUI_V7_8_9", "VampireOptimizer_GUI_V7_9_0", "VampireOptimizer_Float_V7_2", "VampireOptimizer_Float_V7_7", "VampireOptimizer_Float_V7_8", "VampireOptimizer_Float_V7_8_9", "VampireOptimizer_Float_V7_9_0" }) do
	pcall(function()
		local old = ParentTarget:FindFirstChild(oldName)
		if old then old:Destroy() end
	end)
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VampireOptimizer_GUI_V7_9_1"
ScreenGui.DisplayOrder = 2147483000
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.Enabled = true
ScreenGui.Parent = ParentTarget

local ToggleGui = Instance.new("ScreenGui")
ToggleGui.Name = "VampireOptimizer_Float_V7_9_1"
ToggleGui.DisplayOrder = 2147483001
ToggleGui.IgnoreGuiInset = true
ToggleGui.ResetOnSpawn = false
ToggleGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ToggleGui.Enabled = true
ToggleGui.Parent = ParentTarget

-- Forward-declare (hotkey + float drag click need these early)
local SetMenuVisible
local isOpen = true

-- NÚT NỔI (biểu tượng Vampire + kéo thả + xuyên thấu)
local FLOAT_SIZE = 56
local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "FloatingVampireVectorIcon"
ToggleButton.Size = UDim2.new(0, FLOAT_SIZE, 0, FLOAT_SIZE)
ToggleButton.BackgroundColor3 = Color3.fromRGB(18, 4, 8)
ToggleButton.BackgroundTransparency = 0.25
ToggleButton.BorderSizePixel = 0
ToggleButton.Text = ""
ToggleButton.AutoButtonColor = false
ToggleButton.Active = true
ToggleButton.Selectable = true
ToggleButton.ZIndex = 1000
ToggleButton.Parent = ToggleGui

local TBCorner = Instance.new("UICorner")
TBCorner.CornerRadius = UDim.new(1, 0)
TBCorner.Parent = ToggleButton

local FloatStroke = Instance.new("UIStroke")
FloatStroke.Color = Color3.fromRGB(220, 40, 55)
FloatStroke.Thickness = 1.5
FloatStroke.Transparency = 0.35
FloatStroke.Parent = ToggleButton

local IconImage = Instance.new("ImageLabel")
IconImage.Name = "VampireIcon"
IconImage.Size = UDim2.new(1, -6, 1, -6)
IconImage.Position = UDim2.new(0, 3, 0, 3)
IconImage.BackgroundTransparency = 1
IconImage.BorderSizePixel = 0
IconImage.ScaleType = Enum.ScaleType.Fit
IconImage.ZIndex = 1001
IconImage.Active = false
IconImage.Parent = ToggleButton
Instance.new("UICorner", IconImage).CornerRadius = UDim.new(1, 0)

-- Soft glow ring (looks blurry / easy to spot)
local GlowRing = Instance.new("Frame")
GlowRing.Name = "SoftGlow"
GlowRing.Size = UDim2.new(1, 10, 1, 10)
GlowRing.Position = UDim2.new(0, -5, 0, -5)
GlowRing.BackgroundColor3 = Color3.fromRGB(200, 30, 45)
GlowRing.BackgroundTransparency = 0.75
GlowRing.BorderSizePixel = 0
GlowRing.ZIndex = 999
GlowRing.Active = false
GlowRing.Parent = ToggleButton
Instance.new("UICorner", GlowRing).CornerRadius = UDim.new(1, 0)

local function ResolveCustomIcon()
	local candidates = {
		"VampireOptimizer/icon.png",
		"VampireOptimizer\\icon.png",
		"./VampireOptimizer/icon.png",
	}
	local loaders = {}
	pcall(function() if type(getcustomasset) == "function" then table.insert(loaders, getcustomasset) end end)
	pcall(function() if type(getsynasset) == "function" then table.insert(loaders, getsynasset) end end)
	pcall(function() if type(syn) == "table" and type(syn.getcustomasset) == "function" then table.insert(loaders, syn.getcustomasset) end end)
	pcall(function() if type(fluxus) == "table" and type(fluxus.getcustomasset) == "function" then table.insert(loaders, fluxus.getcustomasset) end end)
	pcall(function()
		if type(getgenv) == "function" then
			local env = getgenv()
			if type(env) == "table" and type(env.getcustomasset) == "function" then table.insert(loaders, env.getcustomasset) end
		end
	end)
	for _, loader in ipairs(loaders) do
		for _, pathName in ipairs(candidates) do
			local ok, asset = pcall(loader, pathName)
			if ok and type(asset) == "string" and asset ~= "" then
				return asset
			end
		end
	end
	return nil
end

local iconAsset = ResolveCustomIcon()
local HasCustomIcon = iconAsset ~= nil
if HasCustomIcon then
	IconImage.Image = iconAsset
else
	IconImage.Image = ""
	ToggleButton.BackgroundColor3 = Color3.fromRGB(120, 10, 20)
	local diamond = Instance.new("Frame")
	diamond.Name = "FallbackDiamond"
	diamond.Size = UDim2.new(0, 28, 0, 28)
	diamond.Position = UDim2.new(0.5, -14, 0.5, -14)
	diamond.BackgroundColor3 = Color3.fromRGB(220, 30, 40)
	diamond.BorderSizePixel = 0
	diamond.Rotation = 45
	diamond.ZIndex = 1001
	diamond.Parent = ToggleButton
	Instance.new("UICorner", diamond).CornerRadius = UDim.new(0, 4)
	local hole = Instance.new("Frame")
	hole.Name = "FallbackHole"
	hole.Size = UDim2.new(0, 10, 0, 10)
	hole.Position = UDim2.new(0.5, -5, 0.5, -5)
	hole.BackgroundColor3 = Color3.fromRGB(10, 0, 0)
	hole.BorderSizePixel = 0
	hole.ZIndex = 1002
	hole.Parent = ToggleButton
	Instance.new("UICorner", hole).CornerRadius = UDim.new(0, 2)
end

local function ApplyFloatSeeThrough(enable)
	Config.FloatSeeThrough = enable == true
	-- HiddenLego hides only the center logo; keep the red circular button available.
	ToggleButton.Visible = true
	ToggleButton.Active = true
	ToggleButton.Selectable = true
	if enable then
		-- FloatSeeThrough changes the button style; HiddenLego controls only the center logo.
		ToggleButton.BackgroundColor3 = Color3.fromRGB(220, 25, 40)
		ToggleButton.BackgroundTransparency = 0.35
		FloatStroke.Color = Color3.fromRGB(255, 80, 90)
		FloatStroke.Transparency = 0.45
		GlowRing.BackgroundColor3 = Color3.fromRGB(220, 30, 45)
		GlowRing.BackgroundTransparency = 0.7
		GlowRing.Visible = true
		local showFloatLogo = not Config.HiddenLego
		IconImage.Visible = HasCustomIcon and showFloatLogo
		IconImage.ImageTransparency = (HasCustomIcon and showFloatLogo) and 0.18 or 1
		for _, child in ipairs(ToggleButton:GetChildren()) do
			if child.Name == "FallbackDiamond" or child.Name == "FallbackHole" then
				child.Visible = (not HasCustomIcon) and showFloatLogo
				child.BackgroundTransparency = 0.2
			end
		end
	else
		-- Solid background style; HiddenLego still hides only the center logo.
		ToggleButton.BackgroundColor3 = HasCustomIcon and Color3.fromRGB(18, 4, 8) or Color3.fromRGB(120, 10, 20)
		ToggleButton.BackgroundTransparency = HasCustomIcon and 0.15 or 0.05
		FloatStroke.Color = Color3.fromRGB(220, 40, 55)
		FloatStroke.Transparency = 0.2
		GlowRing.BackgroundTransparency = 0.7
		GlowRing.Visible = true
		local showFloatLogo = not Config.HiddenLego
		IconImage.Visible = HasCustomIcon and showFloatLogo
		IconImage.ImageTransparency = (HasCustomIcon and showFloatLogo) and 0 or 1
		for _, child in ipairs(ToggleButton:GetChildren()) do
			if child.Name == "FallbackDiamond" or child.Name == "FallbackHole" then
				child.Visible = (not HasCustomIcon) and showFloatLogo
				child.BackgroundTransparency = 0
			end
		end
	end
	QueueAutoSave()
end

local function ClampFloatPosition(x, y)
	local cam = workspace.CurrentCamera
	local vw = (cam and cam.ViewportSize.X) or 1920
	local vh = (cam and cam.ViewportSize.Y) or 1080
	local margin = 4
	x = math.clamp(math.floor(x + 0.5), margin, math.max(margin, vw - FLOAT_SIZE - margin))
	y = math.clamp(math.floor(y + 0.5), margin, math.max(margin, vh - FLOAT_SIZE - margin))
	return x, y
end

local function SetFloatPosition(x, y, save)
	x, y = ClampFloatPosition(x, y)
	ToggleButton.Position = UDim2.new(0, x, 0, y)
	if save then
		Config.FloatPosX = x
		Config.FloatPosY = y
		QueueAutoSave()
	end
end

local function RestoreFloatPosition()
	local x, y = Config.FloatPosX, Config.FloatPosY
	if type(x) == "number" and type(y) == "number" then
		SetFloatPosition(x, y, false)
	else
		-- mặc định: mép trái, giữa màn hình theo chiều dọc
		local cam = workspace.CurrentCamera
		local vh = (cam and cam.ViewportSize.Y) or 1080
		SetFloatPosition(15, math.floor(vh * 0.45), false)
	end
end

RestoreFloatPosition()
ApplyFloatSeeThrough(Config.FloatSeeThrough)
-- The red circular floating button remains visible; HiddenLego only hides its center logo.

-- Kéo thả chuẩn: dùng Position.Offset (cùng hệ với IgnoreGuiInset) + GetMouseLocation
-- để không bị lệch GuiInset (trước phải kéo tụt xuống mới đúng).
local dragging = false
local dragMoved = false
local grabOffset = nil
local originPos = nil
local startPointer = nil
local CLICK_THRESHOLD = 3 -- chỉ lọc rung tay, kéo bám ngay từ pixel đầu

local function GetPointer(input)
	-- Touch: theo điểm chạm. Chuột: GetMouseLocation khớp ScreenGui IgnoreGuiInset=true
	if input and input.UserInputType == Enum.UserInputType.Touch then
		return Vector2.new(input.Position.X, input.Position.Y)
	end
	local ok, mouse = pcall(function() return UserInputService:GetMouseLocation() end)
	if ok and typeof(mouse) == "Vector2" then
		return mouse
	end
	if input then
		return Vector2.new(input.Position.X, input.Position.Y)
	end
	return Vector2.zero
end

local function ButtonOffsetPos()
	-- Nguồn sự thật = Position offset ta đang set (tránh AbsolutePosition lệch inset)
	return Vector2.new(ToggleButton.Position.X.Offset, ToggleButton.Position.Y.Offset)
end

Connect(ToggleButton.InputBegan, function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local pointer = GetPointer(input)
	local btn = ButtonOffsetPos()
	dragging = true
	dragMoved = false
	-- Điểm chạm trên logo: bám đúng chỗ ngón/chuột đang giữ
	grabOffset = pointer - btn
	originPos = btn
	startPointer = pointer
end)

Connect(UserInputService.InputChanged, function(input)
	if not dragging or not grabOffset then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local pointer = GetPointer(input)
	-- Bám ngay, không chờ khoảng kéo
	SetFloatPosition(pointer.X - grabOffset.X, pointer.Y - grabOffset.Y, false)
	if startPointer and (pointer - startPointer).Magnitude >= CLICK_THRESHOLD then
		dragMoved = true
	end
end)

Connect(UserInputService.InputEnded, function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	if not dragging then return end
	if dragMoved then
		local btn = ButtonOffsetPos()
		SetFloatPosition(btn.X, btn.Y, true)
	else
		if originPos then
			SetFloatPosition(originPos.X, originPos.Y, false)
		end
		SetMenuVisible(not isOpen, false)
	end
	dragging = false
	dragMoved = false
	grabOffset = nil
	originPos = nil
	startPointer = nil
end)

-- Giữ nút trong màn hình khi resize / xoay thiết bị
pcall(function()
	local cam = workspace.CurrentCamera
	if cam then
		Connect(cam:GetPropertyChangedSignal("ViewportSize"), function()
			if not IsRunning then return end
			SetFloatPosition(ToggleButton.AbsolutePosition.X, ToggleButton.AbsolutePosition.Y, true)
		end)
	end
end)

-- KHUNG MENU CHÍNH (Đã sửa lỗi cắt viền)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainWindow"
MainFrame.Size = UDim2.new(0, 480, 0, 600)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Position = UDim2.fromScale(0.5, 0.5)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 6, 9)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = false -- Tắt tính năng này để không cắt viền UIStroke
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = false -- tránh flash menu sau TP; ApplyStartVisibility quyết định sau
MainFrame.Parent = ScreenGui

-- Scale the complete panel to fit the live Roblox viewport (including ultrawide / 4K / 5K / 8K / small displays).
-- The panel remains centered; on tiny 256x144 viewports it must shrink substantially to remain on-screen.
local MainFrameUIScale = Instance.new("UIScale")
MainFrameUIScale.Scale = 1
MainFrameUIScale.Parent = MainFrame

local function UpdateMainFrameResponsiveScale()
	local viewportWidth, viewportHeight = GetViewportResolution()
	if not viewportWidth or not viewportHeight then return end
	local availableWidth = math.max(1, viewportWidth - 24)
	local availableHeight = math.max(1, viewportHeight - 24)
	-- Scale type by pixel area: standard 1600x900 keeps the base layout; high-DPI displays get larger text/UI.
	local pixelAreaRatio = (viewportWidth * viewportHeight) / (1600 * 900)
	local preferredScale = math.clamp(math.sqrt(pixelAreaRatio), 0.55, 1.6)
	local fitScale = math.min(availableWidth / 480, availableHeight / 600)
	MainFrameUIScale.Scale = math.clamp(math.min(preferredScale, fitScale), 0.12, 1.6)
end

local function BindMainFrameResponsiveCamera()
	local camera = workspace.CurrentCamera
	if camera then
		Connect(camera:GetPropertyChangedSignal("ViewportSize"), UpdateMainFrameResponsiveScale)
	end
	UpdateMainFrameResponsiveScale()
end

Connect(workspace:GetPropertyChangedSignal("CurrentCamera"), BindMainFrameResponsiveCamera)
BindMainFrameResponsiveCamera()

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainBorder = Instance.new("UIStroke")
MainBorder.Color = Color3.fromRGB(190, 25, 40)
MainBorder.Thickness = 2
MainBorder.Parent = MainFrame

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 42)
TitleBar.BackgroundColor3 = Color3.fromRGB(28, 8, 12)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

-- Bo góc trên của TitleBar để khớp với MainFrame
local TitleCorner = Instance.new("UICorner")
TitleCorner.TopLeftRadius = UDim.new(0, 10)
TitleCorner.TopRightRadius = UDim.new(0, 10)
TitleCorner.BottomLeftRadius = UDim.new(0, 0)
TitleCorner.BottomRightRadius = UDim.new(0, 0)
TitleCorner.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -120, 1, 0)
TitleLabel.Position = UDim2.new(0, 15, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "❖ " .. T("Title")
TitleLabel.TextColor3 = Color3.fromRGB(255, 65, 80)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 15
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 32, 0, 32)
MinBtn.Position = UDim2.new(1, -72, 0, 5)
MinBtn.BackgroundColor3 = Color3.fromRGB(45, 12, 18)
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 18
MinBtn.ZIndex = 20
MinBtn.Parent = TitleBar
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -36, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(85, 15, 25)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.ZIndex = 20
CloseBtn.Parent = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(1, -20, 0, 32)
SearchBox.Position = UDim2.new(0, 10, 0, 48)
SearchBox.BackgroundColor3 = Color3.fromRGB(25, 10, 14)
SearchBox.Text = ""
SearchBox.PlaceholderText = T("Search")
SearchBox.PlaceholderColor3 = Color3.fromRGB(150, 80, 90)
SearchBox.TextColor3 = Color3.fromRGB(255, 230, 230)
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 13
SearchBox.ClearTextOnFocus = false
SearchBox.Parent = MainFrame
Instance.new("UICorner", SearchBox).CornerRadius = UDim.new(0, 6)

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -20, 1, -145)
Scroll.Position = UDim2.new(0, 10, 0, 88)
Scroll.BackgroundColor3 = Color3.fromRGB(18, 7, 10)
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 4
Scroll.ScrollBarImageColor3 = Color3.fromRGB(190, 25, 40)
Scroll.Parent = MainFrame

local UIList = Instance.new("UIListLayout")
UIList.Padding = UDim.new(0, 8)
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Parent = Scroll

local BottomBar = Instance.new("Frame")
BottomBar.Size = UDim2.new(1, -20, 0, 44)
BottomBar.Position = UDim2.new(0, 10, 1, -50)
BottomBar.BackgroundTransparency = 1
BottomBar.Parent = MainFrame

local RestoreBtn = Instance.new("TextButton")
RestoreBtn.Size = UDim2.new(0.55, -4, 1, 0)
RestoreBtn.BackgroundColor3 = Color3.fromRGB(65, 15, 22)
RestoreBtn.Text = T("Restore")
RestoreBtn.TextColor3 = Color3.fromRGB(255, 130, 140)
RestoreBtn.Font = Enum.Font.GothamBold
RestoreBtn.TextSize = 12
RestoreBtn.Parent = BottomBar
Instance.new("UICorner", RestoreBtn).CornerRadius = UDim.new(0, 6)

local SaveBtn = Instance.new("TextButton")
SaveBtn.Size = UDim2.new(0.45, -4, 1, 0)
SaveBtn.Position = UDim2.new(0.55, 4, 0, 0)
SaveBtn.BackgroundColor3 = Color3.fromRGB(145, 20, 35)
SaveBtn.Text = T("Save")
SaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SaveBtn.Font = Enum.Font.GothamBold
SaveBtn.TextSize = 13
SaveBtn.Parent = BottomBar
Instance.new("UICorner", SaveBtn).CornerRadius = UDim.new(0, 6)

local allCards = {}
local syncHotkey

local function CreateToggleCard(id, titleKey, descKey, defaultState, callback)
	local Card = Instance.new("Frame")
	-- Pin menu controls first; Graphics Quality uses LayoutOrder -1 just below them.
	if id == "StartHidden" then
		Card.LayoutOrder = -3
	elseif id == "HiddenLego" then
		Card.LayoutOrder = -2
	end
	Card.Name = id
	Card.Size = UDim2.new(1, -8, 0, 66)
	Card.BackgroundColor3 = Color3.fromRGB(26, 10, 14)
	Card.Parent = Scroll
	Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 6)

	local Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(1, -82, 0, 20)
	Label.Position = UDim2.new(0, 10, 0, 6)
	Label.BackgroundTransparency = 1
	Label.Text = T(titleKey)
	Label.TextColor3 = Color3.fromRGB(255, 215, 220)
	Label.Font = Enum.Font.GothamSemibold
	Label.TextSize = 13
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.TextTruncate = Enum.TextTruncate.AtEnd
	Label.Parent = Card

	local Sub = Instance.new("TextLabel")
	Sub.Size = UDim2.new(1, -82, 0, 34)
	Sub.Position = UDim2.new(0, 10, 0, 27)
	Sub.BackgroundTransparency = 1
	Sub.Text = T(descKey)
	Sub.TextColor3 = Color3.fromRGB(160, 100, 110)
	Sub.Font = Enum.Font.Gotham
	Sub.TextSize = 11
	Sub.TextWrapped = true
	Sub.TextXAlignment = Enum.TextXAlignment.Left
	Sub.TextYAlignment = Enum.TextYAlignment.Top
	Sub.Parent = Card

	local Toggle = Instance.new("TextButton")
	Toggle.Size = UDim2.new(0, 48, 0, 26)
	Toggle.Position = UDim2.new(1, -58, 0.5, -13)
	Toggle.BackgroundColor3 = defaultState and Color3.fromRGB(200, 25, 45) or Color3.fromRGB(50, 20, 25)
	Toggle.Text = defaultState and T("On") or T("Off")
	Toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
	Toggle.Font = Enum.Font.GothamBold
	Toggle.TextSize = 11
	Toggle.Parent = Card
	Instance.new("UICorner", Toggle).CornerRadius = UDim.new(0, 13)

	local state = defaultState
	Connect(Toggle.MouseButton1Down, function()
		state = not state
		Toggle.Text = state and T("On") or T("Off")
		TweenService:Create(Toggle, TweenInfo.new(0.2), { BackgroundColor3 = state and Color3.fromRGB(200, 25, 45) or Color3.fromRGB(50, 20, 25) }):Play()
		callback(state)
	end)

	RegisterLangRefresh(function()
		Label.Text = T(titleKey)
		Sub.Text = T(descKey)
		Toggle.Text = state and T("On") or T("Off")
		Card.Name = id .. " " .. T(titleKey)
	end)

	table.insert(allCards, Card)
	return function(newState)
		state = newState
		Toggle.Text = state and T("On") or T("Off")
		Toggle.BackgroundColor3 = state and Color3.fromRGB(200, 25, 45) or Color3.fromRGB(50, 20, 25)
	end
end

local function CreateHotkeyCard()
    local Card = Instance.new("Frame")
    Card.Name = "UI Hotkey Settings"
    Card.Size = UDim2.new(1, -8, 0, 70)
    Card.BackgroundColor3 = Color3.fromRGB(26, 10, 14)
    Card.Parent = Scroll
    Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 6)

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -130, 0, 20)
    Label.Position = UDim2.new(0, 10, 0, 6)
    Label.BackgroundTransparency = 1
    Label.Text = T("HotkeyTitle")
    Label.TextColor3 = Color3.fromRGB(255, 215, 220)
    Label.Font = Enum.Font.GothamSemibold
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Card

    local Sub = Instance.new("TextLabel")
    Sub.Size = UDim2.new(1, -130, 0, 18)
    Sub.Position = UDim2.new(0, 10, 0, 26)
    Sub.BackgroundTransparency = 1
    Sub.Text = T("HotkeyDesc")
    Sub.TextColor3 = Color3.fromRGB(160, 100, 110)
    Sub.Font = Enum.Font.Gotham
    Sub.TextSize = 11
    Sub.TextXAlignment = Enum.TextXAlignment.Left
    Sub.Parent = Card

    local KeyBtn = Instance.new("TextButton")
    KeyBtn.Size = UDim2.new(0, 100, 0, 26)
    KeyBtn.Position = UDim2.new(1, -110, 0.5, -13)
    KeyBtn.BackgroundColor3 = Color3.fromRGB(60, 20, 30)
    KeyBtn.Text = Config.ToggleKey and Config.ToggleKey.Name or T("HotkeyNone")
    KeyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    KeyBtn.Font = Enum.Font.GothamBold
    KeyBtn.TextSize = 11
    KeyBtn.Parent = Card
    Instance.new("UICorner", KeyBtn).CornerRadius = UDim.new(0, 5)

    local ClearBtn = Instance.new("TextButton")
    ClearBtn.Size = UDim2.new(0, 18, 0, 18)
    ClearBtn.Position = UDim2.new(1, -12, 0, 2)
    ClearBtn.BackgroundColor3 = Color3.fromRGB(85, 15, 25)
    ClearBtn.Text = "x"
    ClearBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ClearBtn.Font = Enum.Font.GothamBold
    ClearBtn.TextSize = 10
    ClearBtn.Parent = Card
    Instance.new("UICorner", ClearBtn).CornerRadius = UDim.new(1, 0)
    ClearBtn.Visible = Config.ToggleKey ~= nil

    local listening = false

    Connect(KeyBtn.MouseButton1Down, function()
        listening = true
        KeyBtn.Text = T("HotkeyWaiting")
        KeyBtn.BackgroundColor3 = Color3.fromRGB(145, 20, 35)
    end)

    Connect(ClearBtn.MouseButton1Down, function()
        Config.ToggleKey = nil
        listening = false
        KeyBtn.Text = T("HotkeyNone")
        KeyBtn.BackgroundColor3 = Color3.fromRGB(60, 20, 30)
        ClearBtn.Visible = false
        -- Khi xóa hotkey, không để nút nổi tiếp tục bị ẩn ngoài ý muốn.
        if Config.StartHidden and type(SetMenuVisible) == "function" then
            pcall(function() SetMenuVisible(false, false) end)
        end
        QueueAutoSave()
    end)

    Connect(UserInputService.InputBegan, function(input, gameProcessed)
        if gameProcessed then return end

        if listening then
            if input.KeyCode ~= Enum.KeyCode.Unknown then
                Config.ToggleKey = input.KeyCode
                listening = false
                KeyBtn.Text = input.KeyCode.Name
                KeyBtn.BackgroundColor3 = Color3.fromRGB(60, 20, 30)
                ClearBtn.Visible = true
                -- Start hidden + có hotkey: menu vẫn ẩn nhưng nút tròn màu luôn còn để bấm mở.
                if Config.StartHidden and type(SetMenuVisible) == "function" then
                    pcall(function() SetMenuVisible(false, false) end)
                end
                QueueAutoSave()
            end
            return
        end

        if Config.ToggleKey and input.KeyCode == Config.ToggleKey and not UserInputService:GetFocusedTextBox() then
            -- Hotkey hides the menu AND the complete floating button. Press it again to restore both.
            SetMenuVisible(not isOpen, true)
        end
    end)

    local function refreshHotkeyLang()
        Label.Text = T("HotkeyTitle")
        Sub.Text = T("HotkeyDesc")
        if not listening then
            KeyBtn.Text = Config.ToggleKey and Config.ToggleKey.Name or T("HotkeyNone")
        end
        ClearBtn.Text = "x"
    end
    RegisterLangRefresh(refreshHotkeyLang)
    table.insert(allCards, Card)
    return refreshHotkeyLang
end

local function CreateHairColorCard()
    local Card = Instance.new("Frame")
    Card.Name = "HairColor SolidPlastic KeepOriginalPalette"
    Card.Size = UDim2.new(1, -8, 0, 84)
    Card.BackgroundColor3 = Color3.fromRGB(26, 10, 14)
    Card.Parent = Scroll
    Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 6)

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -135, 0, 20)
    Label.Position = UDim2.new(0, 10, 0, 6)
    Label.BackgroundTransparency = 1
    Label.Text = T("HairColorTitle")
    Label.TextColor3 = Color3.fromRGB(255, 215, 220)
    Label.Font = Enum.Font.GothamSemibold
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Card

    local Sub = Instance.new("TextLabel")
    Sub.Size = UDim2.new(1, -140, 0, 36)
    Sub.Position = UDim2.new(0, 10, 0, 28)
    Sub.BackgroundTransparency = 1
    Sub.Text = T("HairColorDesc")
    Sub.TextColor3 = Color3.fromRGB(160, 100, 110)
    Sub.Font = Enum.Font.Gotham
    Sub.TextSize = 9
    Sub.TextWrapped = true
    Sub.TextXAlignment = Enum.TextXAlignment.Left
    Sub.TextYAlignment = Enum.TextYAlignment.Top
    Sub.Parent = Card

    local Stats = Instance.new("TextLabel")
    Stats.Size = UDim2.new(1, -20, 0, 14)
    Stats.Position = UDim2.new(0, 10, 1, -18)
    Stats.BackgroundTransparency = 1
    Stats.Text = ""
    Stats.TextColor3 = Color3.fromRGB(210, 180, 185)
    Stats.Font = Enum.Font.Gotham
    Stats.TextSize = 9
    Stats.TextXAlignment = Enum.TextXAlignment.Left
    Stats.Parent = Card

    local ScanButton = Instance.new("TextButton")
    ScanButton.Size = UDim2.new(0, 110, 0, 24)
    ScanButton.Position = UDim2.new(1, -120, 0, 5)
    ScanButton.BackgroundColor3 = Color3.fromRGB(145, 20, 35)
    ScanButton.Text = T("HairRescan")
    ScanButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ScanButton.Font = Enum.Font.GothamBold
    ScanButton.TextSize = 9
    ScanButton.Parent = Card
    Instance.new("UICorner", ScanButton).CornerRadius = UDim.new(0, 5)

    local SolidButton = Instance.new("TextButton")
    SolidButton.Size = UDim2.new(0, 110, 0, 24)
    SolidButton.Position = UDim2.new(1, -120, 0, 33)
    SolidButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    SolidButton.Font = Enum.Font.GothamBold
    SolidButton.TextSize = 9
    SolidButton.Parent = Card
    Instance.new("UICorner", SolidButton).CornerRadius = UDim.new(0, 5)

    local function RefreshSolidButton()
        SolidButton.Text = Config.HairSolid and T("HairSolidOn") or T("HairSolidOff")
        SolidButton.BackgroundColor3 = Config.HairSolid and Color3.fromRGB(200, 25, 45) or Color3.fromRGB(50, 20, 25)
    end
    local function RefreshStats()
        local solid, flat, pending = GetHairStats()
        Stats.Text = string.format(T("HairStats"), tostring(solid), tostring(flat), tostring(pending))
    end
    RefreshSolidButton()
    RefreshStats()

    local function ScheduleStats()
        for _, delaySeconds in ipairs({ 1.5, 4, 9 }) do
            task.delay(delaySeconds, function() if IsRunning and Card.Parent then RefreshStats() end end)
        end
    end

    Connect(ScanButton.MouseButton1Down, function()
        if not Config.FlatHair then Sub.Text = T("HairRescanEnable"); return end
        RescanHair()
        Sub.Text = T("HairRescanDone")
        RefreshStats()
        ScheduleStats()
    end)

    Connect(SolidButton.MouseButton1Down, function()
        Config.HairSolid = not Config.HairSolid
        RefreshSolidButton()
        if Config.FlatHair then
            RestoreHairAppearance()
            ApplyFlatHairToAllPlayers()
        end
        QueueAutoSave()
        RefreshStats()
        ScheduleStats()
    end)

    ScheduleStats()
    local function refreshHairColorLang()
        Label.Text = T("HairColorTitle")
        Sub.Text = T("HairColorDesc")
        ScanButton.Text = T("HairRescan")
        RefreshSolidButton()
        RefreshStats()
    end
    RegisterLangRefresh(refreshHairColorLang)
    table.insert(allCards, Card)
    return refreshHairColorLang
end

local function CreateFxSliderCard()
	local Card = Instance.new("Frame")
	Card.Name = "FxSlider " .. T("FxScaleTitle")
	Card.Size = UDim2.new(1, -8, 0, 75)
	Card.BackgroundColor3 = Color3.fromRGB(26, 10, 14)
	Card.Parent = Scroll
	Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 6)

	local Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(1, -70, 0, 20)
	Label.Position = UDim2.new(0, 10, 0, 6)
	Label.BackgroundTransparency = 1
	Label.Text = T("FxScaleTitle")
	Label.TextColor3 = Color3.fromRGB(255, 215, 220)
	Label.Font = Enum.Font.GothamSemibold
	Label.TextSize = 13
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = Card

	local Sub = Instance.new("TextLabel")
	Sub.Size = UDim2.new(1, -70, 0, 16)
	Sub.Position = UDim2.new(0, 10, 0, 24)
	Sub.BackgroundTransparency = 1
	Sub.Text = T("FxScaleDesc")
	Sub.TextColor3 = Color3.fromRGB(160, 100, 110)
	Sub.Font = Enum.Font.Gotham
	Sub.TextSize = 11
	Sub.TextXAlignment = Enum.TextXAlignment.Left
	Sub.Parent = Card

	local ValInput = Instance.new("TextBox")
	ValInput.Size = UDim2.new(0, 48, 0, 22)
	ValInput.Position = UDim2.new(1, -58, 0, 6)
	ValInput.BackgroundColor3 = Color3.fromRGB(40, 15, 20)
	ValInput.Text = tostring(Config.FxScale or 100) .. "%"
	ValInput.TextColor3 = Color3.fromRGB(255, 255, 255)
	ValInput.Font = Enum.Font.GothamBold
	ValInput.TextSize = 11
	ValInput.Parent = Card
	Instance.new("UICorner", ValInput).CornerRadius = UDim.new(0, 4)

	local SliderBar = Instance.new("TextButton")
	SliderBar.Size = UDim2.new(1, -20, 0, 10)
	SliderBar.Position = UDim2.new(0, 10, 0, 48)
	SliderBar.BackgroundColor3 = Color3.fromRGB(45, 16, 22)
	SliderBar.Text = ""
	SliderBar.AutoButtonColor = false
	SliderBar.Parent = Card
	Instance.new("UICorner", SliderBar).CornerRadius = UDim.new(1, 0)

	local Fill = Instance.new("Frame")
	Fill.Size = UDim2.new((Config.FxScale or 100) / 100, 0, 1, 0)
	Fill.BackgroundColor3 = Color3.fromRGB(215, 30, 50)
	Fill.BorderSizePixel = 0
	Fill.Parent = SliderBar
	Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)

	local isDragging = false
	local function UpdateVal(x)
		local barWidth = SliderBar.AbsoluteSize.X
		if barWidth <= 0 then return end
		local pos = math.clamp(x - SliderBar.AbsolutePosition.X, 0, barWidth)
		local frac = math.clamp(pos / barWidth, 0, 1)
		local val = math.round(frac * 100)
		Fill.Size = UDim2.new(frac, 0, 1, 0)
		ValInput.Text = tostring(val) .. "%"
		ApplyFxScale(val)
	end

	Connect(SliderBar.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = true
			UpdateVal(input.Position.X)
		end
	end)
	Connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = false
		end
	end)
	Connect(UserInputService.InputChanged, function(input)
		if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			UpdateVal(input.Position.X)
		end
	end)

	Connect(ValInput.FocusLost, function()
		local clean = ValInput.Text:gsub("%%", "")
		local num = math.clamp(tonumber(clean) or 100, 0, 100)
		ValInput.Text = tostring(num) .. "%"
		Fill.Size = UDim2.new(num / 100, 0, 1, 0)
		ApplyFxScale(num)
	end)

	RegisterLangRefresh(function()
		Label.Text = T("FxScaleTitle")
		Sub.Text = T("FxScaleDesc")
	end)
	table.insert(allCards, Card)
	return function(newVal)
		ValInput.Text = tostring(newVal) .. "%"
		Fill.Size = UDim2.new(newVal / 100, 0, 1, 0)
		ApplyFxScale(newVal)
	end
end

local function CreateRenderDistanceCard()
	local Card = Instance.new("Frame")
	Card.Name = "RenderDist " .. T("RenderDistTitle")
	Card.Size = UDim2.new(1, -8, 0, 86)
	Card.BackgroundColor3 = Color3.fromRGB(26, 10, 14)
	Card.Parent = Scroll
	Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 6)

	local Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(1, -70, 0, 20)
	Label.Position = UDim2.new(0, 10, 0, 6)
	Label.BackgroundTransparency = 1
	Label.Text = T("RenderDistTitle")
	Label.TextColor3 = Color3.fromRGB(255, 215, 220)
	Label.Font = Enum.Font.GothamSemibold
	Label.TextSize = 13
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = Card

	local Sub = Instance.new("TextLabel")
	Sub.Size = UDim2.new(1, -70, 0, 16)
	Sub.Position = UDim2.new(0, 10, 0, 24)
	Sub.BackgroundTransparency = 1
	Sub.Text = T("RenderDistDesc")
	Sub.TextColor3 = Color3.fromRGB(160, 100, 110)
	Sub.Font = Enum.Font.Gotham
	Sub.TextSize = 11
	Sub.TextXAlignment = Enum.TextXAlignment.Left
	Sub.Parent = Card

	local Status = Instance.new("TextLabel")
	Status.Size = UDim2.new(1, -20, 0, 13)
	Status.Position = UDim2.new(0, 10, 0, 42)
	Status.BackgroundTransparency = 1
	Status.TextColor3 = Color3.fromRGB(190, 125, 135)
	Status.Font = Enum.Font.Gotham
	Status.TextSize = 10
	Status.TextXAlignment = Enum.TextXAlignment.Left
	Status.TextTruncate = Enum.TextTruncate.AtEnd
	Status.Parent = Card
	AtmosphereControl.RefreshStatus = function()
		local count = AtmosphereControl.Count()
		Status.Text = (count > 0) and string.format(T("FogAtmosphereStatus"), count) or T("FogLegacyStatus")
	end
	AtmosphereControl.RefreshStatus()

	local ValInput = Instance.new("TextBox")
	ValInput.Size = UDim2.new(0, 48, 0, 22)
	ValInput.Position = UDim2.new(1, -58, 0, 6)
	ValInput.BackgroundColor3 = Color3.fromRGB(40, 15, 20)
	ValInput.Text = tostring(Config.RenderDistance or 100000)
	ValInput.TextColor3 = Color3.fromRGB(255, 255, 255)
	ValInput.Font = Enum.Font.GothamBold
	ValInput.TextSize = 11
	ValInput.Parent = Card
	Instance.new("UICorner", ValInput).CornerRadius = UDim.new(0, 4)

	local SliderBar = Instance.new("TextButton")
	SliderBar.Size = UDim2.new(1, -20, 0, 9)
	SliderBar.Position = UDim2.new(0, 10, 0, 66)
	SliderBar.BackgroundColor3 = Color3.fromRGB(45, 16, 22)
	SliderBar.Text = ""
	SliderBar.AutoButtonColor = false
	SliderBar.Parent = Card
	Instance.new("UICorner", SliderBar).CornerRadius = UDim.new(1, 0)

	local Fill = Instance.new("Frame")
	local frac = ((Config.RenderDistance or 100000) - 200) / 99800
	Fill.Size = UDim2.new(math.clamp(frac, 0, 1), 0, 1, 0)
	Fill.BackgroundColor3 = Color3.fromRGB(215, 30, 50)
	Fill.BorderSizePixel = 0
	Fill.Parent = SliderBar
	Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)

	local isDragging = false
	local function UpdateDist(x)
		local barWidth = SliderBar.AbsoluteSize.X
		if barWidth <= 0 then return end
		local pos = math.clamp(x - SliderBar.AbsolutePosition.X, 0, barWidth)
		local fraction = math.clamp(pos / barWidth, 0, 1)
		local val = math.round(200 + fraction * 99800)
		Fill.Size = UDim2.new(fraction, 0, 1, 0)
		ValInput.Text = tostring(val)
		SetRenderDistance(val)
	end

	Connect(SliderBar.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = true
			UpdateDist(input.Position.X)
		end
	end)
	Connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = false
		end
	end)
	Connect(UserInputService.InputChanged, function(input)
		if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			UpdateDist(input.Position.X)
		end
	end)

	Connect(ValInput.FocusLost, function()
		local num = math.clamp(tonumber(ValInput.Text) or 100000, 200, 100000)
		ValInput.Text = tostring(num)
		Fill.Size = UDim2.new((num - 200) / 99800, 0, 1, 0)
		SetRenderDistance(num)
	end)

	RegisterLangRefresh(function()
		Label.Text = T("RenderDistTitle")
		Sub.Text = T("RenderDistDesc")
		if AtmosphereControl.RefreshStatus then AtmosphereControl.RefreshStatus() end
	end)
	table.insert(allCards, Card)
	return function(newVal, shouldApply)
		newVal = math.clamp(math.floor(tonumber(newVal) or 100000), 200, 100000)
		ValInput.Text = tostring(newVal)
		Fill.Size = UDim2.new((newVal - 200) / 99800, 0, 1, 0)
		if shouldApply ~= false then SetRenderDistance(newVal) end
	end
end

local function CreateEngineQualityCard()
	local Card = Instance.new("Frame")
	-- Keep Graphics Quality near the top so the scale selector is visible without searching.
	Card.LayoutOrder = -1
	Card.Name = "EngineQuality QualityScaleSelector 1-10 1-21 " .. T("EngineQualityTitle")
	Card.Size = UDim2.new(1, -8, 0, 82)
	Card.BackgroundColor3 = Color3.fromRGB(26, 10, 14)
	Card.Parent = Scroll
	Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 6)

	local Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(1, -70, 0, 20)
	Label.Position = UDim2.new(0, 10, 0, 6)
	Label.BackgroundTransparency = 1
	Label.Text = T("EngineQualityTitle")
	Label.TextColor3 = Color3.fromRGB(255, 215, 220)
	Label.Font = Enum.Font.GothamSemibold
	Label.TextSize = 13
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = Card

	local Sub = Instance.new("TextLabel")
	Sub.Size = UDim2.new(1, -125, 0, 16)
	Sub.Position = UDim2.new(0, 10, 0, 24)
	Sub.BackgroundTransparency = 1
	Sub.Text = T("EngineQualityDesc")
	Sub.TextColor3 = Color3.fromRGB(160, 100, 110)
	Sub.Font = Enum.Font.Gotham
	Sub.TextSize = 11
	Sub.TextXAlignment = Enum.TextXAlignment.Left
	Sub.TextTruncate = Enum.TextTruncate.AtEnd
	Sub.Parent = Card

	-- Slider view: Config.QualityMode 21 = engine levels 1-21, 10 = Roblox's own 1-10 scale (mapped onto the engine levels).
	-- Config.EngineQuality always stores the ENGINE level (1-21).
	local function ScaleMax() return (Config.QualityMode == 10) and 10 or 21 end
	local function ToDisplay(engineLevel)
		if Config.QualityMode == 10 then return QualityMap.ToClassic(engineLevel) end
		return math.clamp(math.floor(tonumber(engineLevel) or 1), 1, 21)
	end
	local function FromDisplay(v)
		v = math.clamp(math.floor(tonumber(v) or 1), 1, ScaleMax())
		if Config.QualityMode == 10 then return QualityMap.ToEngine(v) end
		return v
	end
	local function DisplayText()
		if tostring(Config.EngineQuality):upper() == "AUTO" then return "AUTO" end
		return tostring(ToDisplay(Config.EngineQuality or 1))
	end

	local ValInput = Instance.new("TextBox")
	ValInput.Size = UDim2.new(0, 48, 0, 22)
	ValInput.Position = UDim2.new(1, -58, 0, 6)
	ValInput.BackgroundColor3 = Color3.fromRGB(40, 15, 20)
	ValInput.Text = DisplayText()
	ValInput.TextColor3 = Color3.fromRGB(255, 255, 255)
	ValInput.Font = Enum.Font.GothamBold
	ValInput.TextSize = 11
	ValInput.Parent = Card
	Instance.new("UICorner", ValInput).CornerRadius = UDim.new(0, 4)

	local SliderBar = Instance.new("TextButton")
	SliderBar.Size = UDim2.new(1, -20, 0, 10)
	SliderBar.Position = UDim2.new(0, 10, 0, 48)
	SliderBar.BackgroundColor3 = Color3.fromRGB(45, 16, 22)
	SliderBar.Text = ""
	SliderBar.AutoButtonColor = false
	SliderBar.Parent = Card
	Instance.new("UICorner", SliderBar).CornerRadius = UDim.new(1, 0)

	local Fill = Instance.new("Frame")
	local qualityValue = tonumber(Config.EngineQuality) or 1
	local frac = (ToDisplay(qualityValue) - 1) / (ScaleMax() - 1)
	Fill.Size = UDim2.new(math.clamp(frac, 0, 1), 0, 1, 0)
	Fill.BackgroundColor3 = Color3.fromRGB(215, 30, 50)
	Fill.BorderSizePixel = 0
	Fill.Parent = SliderBar
	Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)

	local Status = Instance.new("TextLabel")
	Status.Size = UDim2.new(1, -20, 0, 13)
	Status.Position = UDim2.new(0, 10, 0, 64)
	Status.BackgroundTransparency = 1
	Status.Text = EngineQualityStatusText
	Status.TextColor3 = Color3.fromRGB(235, 175, 105)
	Status.Font = Enum.Font.GothamSemibold
	Status.TextSize = 9
	Status.TextXAlignment = Enum.TextXAlignment.Left
	Status.TextTruncate = Enum.TextTruncate.AtEnd
	Status.Parent = Card
	EngineQualityStatusLabel = Status

	local function MakeScaleButton(text, xOffset, width)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, width, 0, 16)
		b.Position = UDim2.new(1, xOffset, 0, 29)
		b.BackgroundColor3 = Color3.fromRGB(50, 20, 25)
		b.Text = text
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 10
		b.AutoButtonColor = false
		b.Parent = Card
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
		return b
	end
	local Btn10 = MakeScaleButton("1-10", -108, 46)
	local Btn21 = MakeScaleButton("1-21", -58, 48)

	local function PaintScaleButtons()
		local is10 = Config.QualityMode == 10
		Btn10.BackgroundColor3 = is10 and Color3.fromRGB(200, 25, 45) or Color3.fromRGB(50, 20, 25)
		Btn21.BackgroundColor3 = is10 and Color3.fromRGB(50, 20, 25) or Color3.fromRGB(200, 25, 45)
		Sub.Text = is10 and T("EngineQualityDesc10") or T("EngineQualityDesc")
	end
	local function RefreshDisplay()
		ValInput.Text = DisplayText()
		local v = tonumber(Config.EngineQuality)
		local f = v and ((ToDisplay(v) - 1) / (ScaleMax() - 1)) or 0
		Fill.Size = UDim2.new(math.clamp(f, 0, 1), 0, 1, 0)
	end
	local function SetScaleMode(mode)
		if Config.QualityMode == mode then return end
		Config.QualityMode = mode
		if mode == 10 and tonumber(Config.EngineQuality) then
			-- snap to the nearest Roblox 1-10 step so the number shown matches the engine level that is applied
			SetEngineQualityLevel(QualityMap.ToEngine(QualityMap.ToClassic(Config.EngineQuality)))
		end
		RefreshDisplay()
		PaintScaleButtons()
		QueueAutoSave()
	end
	PaintScaleButtons()
	Connect(Btn10.MouseButton1Down, function() SetScaleMode(10) end)
	Connect(Btn21.MouseButton1Down, function() SetScaleMode(21) end)

	local isDragging = false
	local function UpdateQ(x)
		local barWidth = SliderBar.AbsoluteSize.X
		if barWidth <= 0 then return end
		local pos = math.clamp(x - SliderBar.AbsolutePosition.X, 0, barWidth)
		local fraction = math.clamp(pos / barWidth, 0, 1)
		local maxV = ScaleMax()
		local val = math.clamp(math.round(1 + fraction * (maxV - 1)), 1, maxV)
		Fill.Size = UDim2.new((val - 1) / (maxV - 1), 0, 1, 0)
		ValInput.Text = tostring(val)
		SetEngineQualityLevel(FromDisplay(val))
	end

	Connect(SliderBar.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = true
			UpdateQ(input.Position.X)
		end
	end)
	Connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = false
		end
	end)
	Connect(UserInputService.InputChanged, function(input)
		if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			UpdateQ(input.Position.X)
		end
	end)

	Connect(ValInput.FocusLost, function()
		if string.upper(ValInput.Text) == "AUTO" then
			ValInput.Text = "AUTO"
			Fill.Size = UDim2.new(0, 0, 1, 0)
			SetEngineQualityLevel("AUTO")
			return
		end
		local num = math.clamp(math.floor(tonumber(ValInput.Text) or 1), 1, ScaleMax())
		ValInput.Text = tostring(num)
		Fill.Size = UDim2.new((num - 1) / (ScaleMax() - 1), 0, 1, 0)
		SetEngineQualityLevel(FromDisplay(num))
	end)

	RegisterLangRefresh(function()
		Label.Text = T("EngineQualityTitle")
		Card.Name = "EngineQuality QualityScaleSelector 1-10 1-21 " .. T("EngineQualityTitle")
		PaintScaleButtons()
		Status.Text = EngineQualityStatusText
	end)
	table.insert(allCards, Card)
	return function(newVal, shouldApply)
		if tostring(newVal):upper() == "AUTO" then
			ValInput.Text = "AUTO"
			Fill.Size = UDim2.new(0, 0, 1, 0)
			if shouldApply ~= false then SetEngineQualityLevel("AUTO") end
			return
		end
		newVal = math.clamp(math.floor(tonumber(newVal) or 1), 1, 21)
		ValInput.Text = tostring(ToDisplay(newVal))
		Fill.Size = UDim2.new((ToDisplay(newVal) - 1) / (ScaleMax() - 1), 0, 1, 0)
		if shouldApply ~= false then SetEngineQualityLevel(newVal) end
	end
end

local function CreateResolutionCard()
	local Card = Instance.new("Frame")
	Card.Name = "ResolutionAutoDetect"
	Card.Size = UDim2.new(1, -8, 0, 78)
	Card.BackgroundColor3 = Color3.fromRGB(26, 10, 14)
	Card.Parent = Scroll
	Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 6)

	local Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(1, -70, 0, 20)
	Label.Position = UDim2.new(0, 10, 0, 6)
	Label.BackgroundTransparency = 1
	Label.Text = T("ResolutionTitle")
	Label.TextColor3 = Color3.fromRGB(255, 215, 220)
	Label.Font = Enum.Font.GothamSemibold
	Label.TextSize = 13
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = Card

	local Sub = Instance.new("TextLabel")
	Sub.Size = UDim2.new(1, -70, 0, 28)
	Sub.Position = UDim2.new(0, 10, 0, 26)
	Sub.BackgroundTransparency = 1
	Sub.Text = T("ResolutionDesc")
	Sub.TextColor3 = Color3.fromRGB(160, 100, 110)
	Sub.Font = Enum.Font.Gotham
	Sub.TextSize = 9
	Sub.TextWrapped = true
	Sub.TextXAlignment = Enum.TextXAlignment.Left
	Sub.TextYAlignment = Enum.TextYAlignment.Top
	Sub.Parent = Card

	local Status = Instance.new("TextLabel")
	Status.Size = UDim2.new(1, -20, 0, 15)
	Status.Position = UDim2.new(0, 10, 1, -18)
	Status.BackgroundTransparency = 1
	Status.Text = "Viewport: detecting..."
	Status.TextColor3 = Color3.fromRGB(220, 190, 195)
	Status.Font = Enum.Font.GothamSemibold
	Status.TextSize = 10
	Status.TextXAlignment = Enum.TextXAlignment.Left
	Status.Parent = Card

	local Toggle = Instance.new("TextButton")
	Toggle.Size = UDim2.new(0, 48, 0, 26)
	Toggle.Position = UDim2.new(1, -58, 0.5, -13)
	Toggle.BackgroundColor3 = Config.AutoResolutionQuality and Color3.fromRGB(200, 25, 45) or Color3.fromRGB(50, 20, 25)
	Toggle.Text = Config.AutoResolutionQuality and T("On") or T("Off")
	Toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
	Toggle.Font = Enum.Font.GothamBold
	Toggle.TextSize = 11
	Toggle.Parent = Card
	Instance.new("UICorner", Toggle).CornerRadius = UDim.new(0, 13)

	local function UpdateStatus()
		local width, height = GetViewportResolution()
		if width then
			Status.Text = string.format(T("ResolutionStatus"), width, height, GetResolutionTier(width, height))
		else
			Status.Text = "Viewport: detecting..."
		end
	end

	local function UpdateToggle()
		Toggle.Text = Config.AutoResolutionQuality and T("On") or T("Off")
		Toggle.BackgroundColor3 = Config.AutoResolutionQuality and Color3.fromRGB(200, 25, 45) or Color3.fromRGB(50, 20, 25)
	end

	Connect(Toggle.MouseButton1Down, function()
		Config.AutoResolutionQuality = not Config.AutoResolutionQuality
		if Config.AutoResolutionQuality then
			ResolutionLastApplied = nil
			ApplyResolutionAutoQuality(true)
		else
			-- Restore the manually selected level when automatic mode is turned off.
			SetEngineQualityLevel(Config.EngineQuality, false)
		end
		UpdateToggle()
		QueueAutoSave()
	end)

	local function BindCamera()
		local camera = workspace.CurrentCamera
		if camera then
			Connect(camera:GetPropertyChangedSignal("ViewportSize"), function()
				UpdateStatus()
				ResolutionLastApplied = nil
				ApplyResolutionAutoQuality()
			end)
		end
		UpdateStatus()
		ResolutionLastApplied = nil
		ApplyResolutionAutoQuality()
	end

	Connect(workspace:GetPropertyChangedSignal("CurrentCamera"), BindCamera)
	BindCamera()
	RegisterLangRefresh(function()
		Label.Text = T("ResolutionTitle")
		Sub.Text = T("ResolutionDesc")
		UpdateStatus()
		UpdateToggle()
	end)
	table.insert(allCards, Card)
	return UpdateStatus
end

local function CreateSkyCard()
	local Card = Instance.new("Frame")
	Card.Name = "SkyControl " .. T("SkyTitle")
	Card.Size = UDim2.new(1, -8, 0, 102)
	Card.BackgroundColor3 = Color3.fromRGB(26, 10, 14)
	Card.Parent = Scroll
	Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 6)

	local Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(1, -20, 0, 20)
	Label.Position = UDim2.new(0, 10, 0, 6)
	Label.BackgroundTransparency = 1
	Label.Text = T("SkyTitle")
	Label.TextColor3 = Color3.fromRGB(255, 215, 220)
	Label.Font = Enum.Font.GothamSemibold
	Label.TextSize = 13
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = Card

	local Sub = Instance.new("TextLabel")
	Sub.Size = UDim2.new(1, -20, 0, 16)
	Sub.Position = UDim2.new(0, 10, 0, 24)
	Sub.BackgroundTransparency = 1
	Sub.Text = T("SkyDesc")
	Sub.TextColor3 = Color3.fromRGB(160, 100, 110)
	Sub.Font = Enum.Font.Gotham
	Sub.TextSize = 11
	Sub.TextXAlignment = Enum.TextXAlignment.Left
	Sub.Parent = Card

	local GalaxyBtn = Instance.new("TextButton")
	GalaxyBtn.Size = UDim2.new(0.48, -4, 0, 24)
	GalaxyBtn.Position = UDim2.new(0, 10, 0, 44)
	GalaxyBtn.BackgroundColor3 = (Config.SkyMode == "Galaxy") and Color3.fromRGB(190, 25, 45) or Color3.fromRGB(45, 15, 20)
	GalaxyBtn.Text = T("SkyGalaxy")
	GalaxyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	GalaxyBtn.Font = Enum.Font.GothamBold
	GalaxyBtn.TextSize = 11
	GalaxyBtn.Parent = Card
	Instance.new("UICorner", GalaxyBtn).CornerRadius = UDim.new(0, 5)

	local DefaultBtn = Instance.new("TextButton")
	DefaultBtn.Size = UDim2.new(0.48, -4, 0, 24)
	DefaultBtn.Position = UDim2.new(0.52, 0, 0, 44)
	DefaultBtn.BackgroundColor3 = (Config.SkyMode == "Default") and Color3.fromRGB(190, 25, 45) or Color3.fromRGB(45, 15, 20)
	DefaultBtn.Text = T("SkyDefault")
	DefaultBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	DefaultBtn.Font = Enum.Font.GothamBold
	DefaultBtn.TextSize = 11
	DefaultBtn.Parent = Card
	Instance.new("UICorner", DefaultBtn).CornerRadius = UDim.new(0, 5)

	local ReportBtn = Instance.new("TextButton")
	ReportBtn.Size = UDim2.new(1, -20, 0, 22)
	ReportBtn.Position = UDim2.new(0, 10, 0, 74)
	ReportBtn.BackgroundColor3 = Color3.fromRGB(75, 18, 28)
	ReportBtn.Text = "COPY SKY REPORT"
	ReportBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	ReportBtn.Font = Enum.Font.GothamBold
	ReportBtn.TextSize = 10
	ReportBtn.Parent = Card
	Instance.new("UICorner", ReportBtn).CornerRadius = UDim.new(0, 5)
	Connect(ReportBtn.MouseButton1Down, function()
		local ok, text = pcall(BuildSkyReport)
		if not ok then text = "Sky report failed: " .. tostring(text) end
		print("[Vampire Optimizer]\n" .. text)
		local copied = false
		pcall(function()
			if setclipboard then setclipboard(text); copied = true elseif toclipboard then toclipboard(text); copied = true end
		end)
		ReportBtn.Text = copied and "COPIED" or "PRINTED TO CONSOLE (F9)"
		task.delay(2.5, function() if IsRunning and ReportBtn.Parent then ReportBtn.Text = "COPY SKY REPORT" end end)
	end)

	local function UpdateSkyButtons(selected)
		GalaxyBtn.BackgroundColor3 = (selected == "Galaxy") and Color3.fromRGB(190, 25, 45) or Color3.fromRGB(45, 15, 20)
		DefaultBtn.BackgroundColor3 = (selected == "Default") and Color3.fromRGB(190, 25, 45) or Color3.fromRGB(45, 15, 20)
		ApplySkyMode(selected)
	end

	Connect(GalaxyBtn.MouseButton1Down, function() UpdateSkyButtons("Galaxy") end)
	Connect(DefaultBtn.MouseButton1Down, function() UpdateSkyButtons("Default") end)

	RegisterLangRefresh(function()
		Label.Text = T("SkyTitle")
		Sub.Text = T("SkyDesc")
		GalaxyBtn.Text = T("SkyGalaxy")
		DefaultBtn.Text = T("SkyDefault")
	end)
	table.insert(allCards, Card)
	return function() UpdateSkyButtons("Default") end
end

local AreaStatusLabel = nil
local AreaMonitorButton = nil
local AreaMonitorEnabled = Config.LiveMonitor

local function GetAreaSnapshot()
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return nil, nil, T("WaitingCharacter") end

	local count = nil
	local okCount, result = pcall(function()
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		overlap.FilterDescendantsInstances = { character }
		overlap.MaxParts = 2000
		return workspace:GetPartBoundsInRadius(root.Position, 512, overlap)
	end)
	if okCount and type(result) == "table" then count = #result end

	local memoryMB = nil
	pcall(function() memoryMB = game:GetService("Stats"):GetTotalMemoryUsageMb() end)
	return count, memoryMB, nil
end

local function RefreshAreaStatus()
	if not AreaStatusLabel or not AreaStatusLabel.Parent then return end
	local count, memoryMB, errText = GetAreaSnapshot()
	if errText then AreaStatusLabel.Text = errText; return end
	local partText = count and (count >= 2000 and "2000+" or tostring(count)) or "N/A"
	local memoryText = memoryMB and string.format("%.0f MB", memoryMB) or "N/A"
	AreaStatusLabel.Text = string.format(T("AreaStatus"), partText, memoryText)
end

local function CreateAreaMonitorCard()
	local Card = Instance.new("Frame")
	Card.Name = "MapExpansionCheck " .. T("AreaTitle")
	Card.Size = UDim2.new(1, -8, 0, 104)
	Card.BackgroundColor3 = Color3.fromRGB(26, 10, 14)
	Card.Parent = Scroll
	Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 6)

	local Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(1, -20, 0, 20)
	Label.Position = UDim2.new(0, 10, 0, 6)
	Label.BackgroundTransparency = 1
	Label.Text = T("AreaTitle")
	Label.TextColor3 = Color3.fromRGB(255, 215, 220)
	Label.Font = Enum.Font.GothamSemibold
	Label.TextSize = 13
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = Card

	local Sub = Instance.new("TextLabel")
	Sub.Size = UDim2.new(1, -20, 0, 16)
	Sub.Position = UDim2.new(0, 10, 0, 26)
	Sub.BackgroundTransparency = 1
	Sub.Text = T("AreaDesc")
	Sub.TextColor3 = Color3.fromRGB(160, 100, 110)
	Sub.Font = Enum.Font.Gotham
	Sub.TextSize = 9
	Sub.TextXAlignment = Enum.TextXAlignment.Left
	Sub.TextTruncate = Enum.TextTruncate.AtEnd
	Sub.Parent = Card

	AreaStatusLabel = Instance.new("TextLabel")
	AreaStatusLabel.Size = UDim2.new(1, -20, 0, 18)
	AreaStatusLabel.Position = UDim2.new(0, 10, 0, 46)
	AreaStatusLabel.BackgroundTransparency = 1
	AreaStatusLabel.Text = T("WaitingCharacter")
	AreaStatusLabel.TextColor3 = Color3.fromRGB(205, 170, 175)
	AreaStatusLabel.Font = Enum.Font.Gotham
	AreaStatusLabel.TextSize = 11
	AreaStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
	AreaStatusLabel.TextTruncate = Enum.TextTruncate.AtEnd
	AreaStatusLabel.Parent = Card

	AreaMonitorButton = Instance.new("TextButton")
	AreaMonitorButton.Size = UDim2.new(0.48, -6, 0, 25)
	AreaMonitorButton.Position = UDim2.new(0, 10, 0, 72)
	AreaMonitorButton.BackgroundColor3 = AreaMonitorEnabled and Color3.fromRGB(145, 20, 35) or Color3.fromRGB(50, 20, 25)
	AreaMonitorButton.Text = AreaMonitorEnabled and T("MonitorOn") or T("MonitorOff")
	AreaMonitorButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	AreaMonitorButton.Font = Enum.Font.GothamBold
	AreaMonitorButton.TextSize = 9
	AreaMonitorButton.Parent = Card
	Instance.new("UICorner", AreaMonitorButton).CornerRadius = UDim.new(0, 5)

	local ScanButton = Instance.new("TextButton")
	ScanButton.Size = UDim2.new(0.48, -6, 0, 25)
	ScanButton.Position = UDim2.new(0.52, 0, 0, 72)
	ScanButton.BackgroundColor3 = Color3.fromRGB(75, 18, 28)
	ScanButton.Text = T("Scan")
	ScanButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	ScanButton.Font = Enum.Font.GothamBold
	ScanButton.TextSize = 9
	ScanButton.Parent = Card
	Instance.new("UICorner", ScanButton).CornerRadius = UDim.new(0, 5)

	Connect(AreaMonitorButton.MouseButton1Down, function()
		AreaMonitorEnabled = not AreaMonitorEnabled
		Config.LiveMonitor = AreaMonitorEnabled
		Config.LiveMonitorSet = true
		QueueAutoSave()
		AreaMonitorButton.Text = AreaMonitorEnabled and T("MonitorOn") or T("MonitorOff")
		AreaMonitorButton.BackgroundColor3 = AreaMonitorEnabled and Color3.fromRGB(145, 20, 35) or Color3.fromRGB(50, 20, 25)
		if AreaMonitorEnabled then RefreshAreaStatus() end
	end)

	Connect(ScanButton.MouseButton1Down, RefreshAreaStatus)
	RegisterLangRefresh(function()
		Label.Text = T("AreaTitle")
		Sub.Text = T("AreaDesc")
		AreaMonitorButton.Text = AreaMonitorEnabled and T("MonitorOn") or T("MonitorOff")
		ScanButton.Text = T("Scan")
		RefreshAreaStatus()
	end)
	table.insert(allCards, Card)
	return function() end
end

-- ==================== ĐĂNG KÝ CÁC NÚT ====================

-- Keep menu controls at the top so they are visible without using Search.
local syncStartHidden = CreateToggleCard("StartHidden", "StartHiddenTitle", "StartHiddenDesc", Config.StartHidden, function(s)
    Config.StartHidden = (s == true)
    -- ON closes the menu but leaves the floating button visible.
    if type(SetMenuVisible) == "function" then
        if Config.StartHidden then
            pcall(function() SetMenuVisible(false, false) end)
        else
            pcall(function() SetMenuVisible(true, false) end)
        end
    end
    QueueAutoSave()
end)
local syncHiddenLego = CreateToggleCard("HiddenLego", "HiddenLegoTitle", "HiddenLegoDesc", Config.HiddenLego, function(s)
    Config.HiddenLego = (s == true)
    ApplyFloatSeeThrough(Config.FloatSeeThrough)
    QueueAutoSave()
end)

-- Keep Toggle UI Hotkey beside the other menu controls so it is visible immediately,
-- without scrolling or searching. CardSearchText also indexes its title and key button.
syncHotkey = CreateHotkeyCard()

local syncPlast = CreateToggleCard("FlatPlastic", "FlatPlastic", "FlatPlasticDesc", Config.FlatPlastic, function(s) SetFlatPlastic(s) end)
local syncTex = CreateToggleCard("RemoveTextures", "RemoveTextures", "RemoveTexturesDesc", Config.RemoveTextures, function(s) SetRemoveTextures(s) end)
local syncShad = CreateToggleCard("RemoveShadows", "RemoveShadows", "RemoveShadowsDesc", Config.RemoveShadows, function(s) SetRemoveShadows(s) end)
local syncFullBright = CreateToggleCard("FullBright", "FullBrightTitle", "FullBrightDesc", Config.FullBright, function(s) SetFullBright(s) end)
local syncFx = CreateFxSliderCard()
local syncDist = CreateRenderDistanceCard()
local syncEng = CreateEngineQualityCard()
local syncResolution = CreateResolutionCard()
local syncTerr = CreateToggleCard("LiteTerrain", "LiteTerrain", "LiteTerrainDesc", Config.LiteTerrain, function(s) SetLiteTerrain(s) end)
local syncSky = CreateSkyCard()
local syncArea = CreateAreaMonitorCard()
local syncHair = CreateToggleCard("FlatHair", "HairFlatTitle", "HairFlatDesc", Config.FlatHair, function(s) SetFlatHair(s) end)
local syncStripClothing = CreateToggleCard("StripClothing", "StripClothingTitle", "StripClothingDesc", Config.StripClothing, function(s) SetStripClothing(s) end)
local syncHairColor = CreateHairColorCard()
local syncAutoSave = CreateToggleCard("AutoSave", "AutoSaveTitle", "AutoSaveDesc", Config.AutoSave, function(s)
	Config.AutoSave = s
	if s then QueueAutoSave() else SaveConfig() end
end)
local syncTeleportPersist = CreateToggleCard("TeleportPersist", "TeleportPersistTitle", "TeleportPersistDesc", Config.TeleportPersist, function(s)
	Config.TeleportPersist = s == true
	QueueAutoSave()
end)

local syncFloatSeeThrough = CreateToggleCard("FloatSeeThrough", "FloatSeeThroughTitle", "FloatSeeThroughDesc", Config.FloatSeeThrough, function(s)
    ApplyFloatSeeThrough(s)
end)

-- ==================== SERVER HOP & PERSIST ====================
local function ResolveQueueOnTeleport()
	local candidates = {}
	pcall(function() if type(queue_on_teleport) == "function" then table.insert(candidates, queue_on_teleport) end end)
	pcall(function() if type(queueonteleport) == "function" then table.insert(candidates, queueonteleport) end end)
	pcall(function() if type(syn) == "table" and type(syn.queue_on_teleport) == "function" then table.insert(candidates, syn.queue_on_teleport) end end)
	pcall(function() if type(fluxus) == "table" and type(fluxus.queue_on_teleport) == "function" then table.insert(candidates, fluxus.queue_on_teleport) end end)
	pcall(function()
		if type(getgenv) == "function" then
			local env = getgenv()
			if type(env) == "table" then
				for _, key in ipairs({ "queue_on_teleport", "queueonteleport" }) do
					if type(env[key]) == "function" then table.insert(candidates, env[key]); break end
				end
			end
		end
	end)
	return candidates[1]
end

local function ExecutorHttpGet(url)
	local ok, body = pcall(function() return game:HttpGet(url, true) end)
	if ok and type(body) == "string" and body ~= "" then return body end
	local requestFn
	pcall(function() requestFn = request or http_request end)
	if not requestFn then pcall(function() requestFn = syn and syn.request end) end
	if type(requestFn) == "function" then
		local reqOk, response = pcall(requestFn, { Url = url, Method = "GET" })
		if reqOk and type(response) == "table" then
			local statusCode = tonumber(response.StatusCode or response.Status)
			if (not statusCode or (statusCode >= 200 and statusCode < 300)) and type(response.Body) == "string" then return response.Body end
			return nil, "HTTP status " .. tostring(statusCode or "unknown")
		end
	end
	return nil, tostring(body or "HTTP request unavailable")
end

local Persist = { Dir = "VampireOptimizer" }
Persist.Flag = Persist.Dir .. "/disabled.flag"
local RELOAD_FILE_NAME = Persist.Dir .. "/main.lua"
local TeleportQueued = false

function Persist.HasFiles()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

function Persist.Source()
	local source
	pcall(function() source = PersistentEnv.VampireOptimizerSource end)
	if type(source) ~= "string" then pcall(function() source = shared.VampireOptimizerSource end) end
	if type(source) == "string" and #source > 1000 then return source end
	return nil
end

function Persist.EnsureDir()
	pcall(function()
		if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder(Persist.Dir) then makefolder(Persist.Dir) end
	end)
end

function Persist.Install()
	if not Persist.HasFiles() then return false, "executor has no file API" end
	Persist.EnsureDir()
	local source = Persist.Source()
	local current
	pcall(function() if isfile(RELOAD_FILE_NAME) then current = readfile(RELOAD_FILE_NAME) end end)
	if source and current ~= source then
		local ok, err = pcall(writefile, RELOAD_FILE_NAME, source)
		if not ok then return false, tostring(err) end
		pcall(function() if isfile(RELOAD_FILE_NAME) then current = readfile(RELOAD_FILE_NAME) end end)
	end
	if type(current) == "string" and #current > 1000 then return true end
	return false, source and "could not write the workspace copy" or "script source unavailable"
end

function Persist.LongString(text)
	local level = 2
	while text:find("]" .. string.rep("=", level) .. "]", 1, true) or text:find("[" .. string.rep("=", level) .. "[", 1, true) do level = level + 1 end
	local eq = string.rep("=", level)
	return "[" .. eq .. "[\n" .. text .. "\n]" .. eq .. "]"
end

function Persist.BuildStub(embeddedSource, rawUrl, configJson)
	local header = string.format("local MAIN_FILE, FLAG_FILE, RELOAD_URL, CONFIG_JSON = %q, %q, %q, %q", RELOAD_FILE_NAME, Persist.Flag, rawUrl, configJson)
	local embedded = "local EMBEDDED = " .. (embeddedSource and Persist.LongString(embeddedSource) or "nil")
	local body = [[
if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
while not Players.LocalPlayer do task.wait() end
task.wait(1.5)
local env = shared
pcall(function() if type(getgenv) == "function" then env = getgenv() end end)
if shared.VampireOptimizerDisabled or env.VampireOptimizerDisabled then return end
local disabled = false
pcall(function() if type(isfile) == "function" and type(readfile) == "function" and isfile(FLAG_FILE) and readfile(FLAG_FILE) == "1" then disabled = true end end)
if disabled then return end
pcall(function()
  local cfg = game:GetService("HttpService"):JSONDecode(CONFIG_JSON)
  shared.VampireOptimizerConfig = cfg
  env.VampireOptimizerConfig = cfg
end)
local source
if RELOAD_URL ~= "" then
  local ok, body = pcall(function() return game:HttpGet(RELOAD_URL, true) end)
  if ok and type(body) == "string" and #body > 1000 then source = body end
end
if not source and type(isfile) == "function" and type(readfile) == "function" then
  local ok, body = pcall(function() if isfile(MAIN_FILE) then return readfile(MAIN_FILE) end end)
  if ok and type(body) == "string" and #body > 1000 then source = body end
end
if not source and EMBEDDED then source = EMBEDDED end
if not source then warn("[Vampire Optimizer] No reload source available after teleport") return end
local chunk, compileError = loadstring(source, "VampireOptimizer")
if not chunk then warn("[Vampire Optimizer] " .. tostring(compileError)) return end
shared.VampireOptimizerReload = true
pcall(function() env.VampireOptimizerReload = true end)
pcall(function() shared.VampireOptimizerSource = source end)
pcall(function() env.VampireOptimizerSource = source end)
local ran, runError = pcall(chunk)
if not ran then warn("[Vampire Optimizer] " .. tostring(runError)) end
]]
	return header .. "\n" .. embedded .. "\n" .. body
end

local function QueueReinjectIfConfigured(reason)
	if Config.TeleportPersist == false then return false, "Re-run after teleport is OFF" end
	if TeleportQueued then return true, "already queued" end
	local queueFn = ResolveQueueOnTeleport()
	if type(queueFn) ~= "function" then return false, "Executor has no queue_on_teleport" end
	pcall(SaveConfig)
	local okJson, configJson = pcall(function() return HttpService:JSONEncode(Config) end)
	if not okJson then return false, "Could not encode saved settings" end
	local rawUrl = tostring(Config.ReloadUrl or ""):gsub("^%s*(.-)%s*$", "%1")
	local installed = Persist.Install()
	local embedded
	if not installed then
		embedded = Persist.Source()
		if not embedded and rawUrl == "" then return false, "No script source to re-run" end
	end
	local queued, queueErr = pcall(queueFn, Persist.BuildStub(embedded, rawUrl, configJson))
	if not queued then return false, tostring(queueErr) end
	TeleportQueued = true
	return true, reason or "queued"
end

local function DescribeExecutor()
	local name = "unknown executor"
	pcall(function() if type(identifyexecutor) == "function" then name = tostring((identifyexecutor())) end end)
	local function yn(value) return value and "OK" or "NO" end
	local hasQueue = type(ResolveQueueOnTeleport()) == "function"
	local hasFiles = Persist.HasFiles()
	local hasHttp = type(request) == "function" or type(http_request) == "function"
	pcall(function() if type(game.HttpGet) == "function" then hasHttp = true end end)
	local autoRun = "OFF"
	if Config.TeleportPersist ~= false then
		if Persist.Install() then autoRun = "FILE" elseif Persist.Source() then autoRun = "EMBED" else autoRun = "NO" end
	end
	return string.format("%s | queue_on_teleport: %s | files: %s | http: %s | auto-run: %s", name, yn(hasQueue), yn(hasFiles), yn(hasHttp), autoRun)
end
local ExecutorReport = DescribeExecutor()

local TeleportWarned = false
Connect(LocalPlayer.OnTeleport, function(teleportState)
	if teleportState == Enum.TeleportState.Failed then
		TeleportQueued = false
		TeleportWarned = false
		return
	end
	local ok, message = QueueReinjectIfConfigured("OnTeleport")
	if not ok and Config.TeleportPersist ~= false and not TeleportWarned then
		TeleportWarned = true
		warn("[Vampire Optimizer] " .. tostring(message))
	end
end)

local function FetchPublicServerCandidates()
	local baseUrl = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true"
	local results, seen = {}, {}
	local cursor = nil
	for page = 1, 3 do
		local url = baseUrl
		if cursor and cursor ~= "" then
			local encodedCursor = cursor
			pcall(function() encodedCursor = HttpService:UrlEncode(cursor) end)
			url = url .. "&cursor=" .. encodedCursor
		end
		local body, httpErr = ExecutorHttpGet(url)
		if not body then return nil, httpErr end
		local decodedOk, payload = pcall(function() return HttpService:JSONDecode(body) end)
		if not decodedOk or type(payload) ~= "table" then return nil, "Roblox returned invalid server-list JSON" end
		if type(payload.data) == "table" then
			for _, server in ipairs(payload.data) do
				local id = server.id
				local playing = tonumber(server.playing) or 0
				local maxPlayers = tonumber(server.maxPlayers) or 0
				if type(id) == "string" and id ~= "" and id ~= game.JobId and maxPlayers > 0 and playing < maxPlayers and not seen[id] then
					seen[id] = true
					table.insert(results, { id = id, playing = playing, maxPlayers = maxPlayers })
				end
			end
		end
		cursor = payload.nextPageCursor
		if #results >= 15 or type(cursor) ~= "string" or cursor == "" then break end
	end
	return results
end

local function CreateServerHopCard()
    local Card = Instance.new("Frame")
    Card.Name = "RandomPublicServerHop " .. T("ServerHopTitle")
    Card.Size = UDim2.new(1, -8, 0, 184)
    Card.BackgroundColor3 = Color3.fromRGB(26, 10, 14)
    Card.Parent = Scroll
    Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 6)

    local serverListUrl = "https://www.roblox.com/games/" .. tostring(game.PlaceId) .. "/servers"

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -20, 0, 20)
    Label.Position = UDim2.new(0, 10, 0, 6)
    Label.BackgroundTransparency = 1
    Label.Text = T("ServerHopTitle")
    Label.TextColor3 = Color3.fromRGB(255, 215, 220)
    Label.Font = Enum.Font.GothamSemibold
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Card

    local Desc = Instance.new("TextLabel")
    Desc.Size = UDim2.new(1, -20, 0, 35)
    Desc.Position = UDim2.new(0, 10, 0, 28)
    Desc.BackgroundTransparency = 1
    Desc.Text = T("ServerHopDesc")
    Desc.TextColor3 = Color3.fromRGB(160, 100, 110)
    Desc.Font = Enum.Font.Gotham
    Desc.TextSize = 9
    Desc.TextWrapped = true
    Desc.TextXAlignment = Enum.TextXAlignment.Left
    Desc.Parent = Card

    local HopButton = Instance.new("TextButton")
    HopButton.Size = UDim2.new(0.48, -5, 0, 27)
    HopButton.Position = UDim2.new(0, 10, 0, 86)
    HopButton.BackgroundColor3 = Color3.fromRGB(145, 20, 35)
    HopButton.Text = T("ServerHopButton")
    HopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    HopButton.Font = Enum.Font.GothamBold
    HopButton.TextSize = 9
    HopButton.Parent = Card
    Instance.new("UICorner", HopButton).CornerRadius = UDim.new(0, 5)

    local CopyButton = Instance.new("TextButton")
    CopyButton.Size = UDim2.new(0.52, -5, 0, 27)
    CopyButton.Position = UDim2.new(0.48, 5, 0, 86)
    CopyButton.BackgroundColor3 = Color3.fromRGB(65, 18, 27)
    CopyButton.Text = T("ServerHopCopy")
    CopyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CopyButton.Font = Enum.Font.GothamBold
    CopyButton.TextSize = 8
    CopyButton.Parent = Card
    Instance.new("UICorner", CopyButton).CornerRadius = UDim.new(0, 5)

    local ServerListBox = Instance.new("TextBox")
    ServerListBox.Size = UDim2.new(1, -20, 0, 20)
    ServerListBox.Position = UDim2.new(0, 10, 0, 116)
    ServerListBox.BackgroundColor3 = Color3.fromRGB(40, 15, 20)
    ServerListBox.Text = serverListUrl
    ServerListBox.TextColor3 = Color3.fromRGB(215, 195, 200)
    ServerListBox.Font = Enum.Font.Gotham
    ServerListBox.TextSize = 8
    ServerListBox.ClearTextOnFocus = false
    ServerListBox.TextXAlignment = Enum.TextXAlignment.Left
    ServerListBox.Parent = Card
    Instance.new("UICorner", ServerListBox).CornerRadius = UDim.new(0, 4)

    local Status = Instance.new("TextLabel")
    Status.Size = UDim2.new(1, -20, 0, 15)
    Status.Position = UDim2.new(0, 10, 0, 140)
    Status.BackgroundTransparency = 1
    Status.Text = ExecutorReport
    Status.TextColor3 = Color3.fromRGB(190, 145, 150)
    Status.Font = Enum.Font.Gotham
    Status.TextSize = 8
    Status.TextXAlignment = Enum.TextXAlignment.Left
    Status.TextTruncate = Enum.TextTruncate.AtEnd
    Status.Parent = Card

    local busy = false
    local lastRequest = 0

    Connect(HopButton.MouseButton1Down, function()
        if busy or (os.clock() - lastRequest) < 20 then
            Status.Text = T("ServerHopCooldown")
            return
        end
        busy = true
        lastRequest = os.clock()
        HopButton.Text = "..."
        Status.Text = "Đang tìm server..."

        task.spawn(function()
            local candidates, fetchError = FetchPublicServerCandidates()
            if not IsRunning or not Card.Parent then return end
            if not candidates or #candidates == 0 then
                busy = false
                HopButton.Text = T("ServerHopButton")
                Status.Text = "Lỗi: " .. tostring(fetchError or "empty list"):sub(1, 60)
                return
            end

            local visited = shared.VampireOptimizerVisitedServers
            if type(visited) ~= "table" then visited = {}; shared.VampireOptimizerVisitedServers = visited end
            local placeKey = tostring(game.PlaceId)
            if type(visited[placeKey]) ~= "table" then visited[placeKey] = {} end
            local placeVisited = visited[placeKey]
            local unvisited = {}
            for _, candidate in ipairs(candidates) do
                if not placeVisited[candidate.id] then table.insert(unvisited, candidate) end
            end
            if #unvisited == 0 then
                visited[placeKey] = {}
                placeVisited = visited[placeKey]
                unvisited = candidates
            end

            local selected = unvisited[math.random(1, #unvisited)]
            placeVisited[selected.id] = true
            local queued, queueMessage = QueueReinjectIfConfigured("hop")
            if queued then Status.Text = "Đã xếp tự chạy lại..." elseif Config.TeleportPersist ~= false then Status.Text = "Lỗi queue: " .. tostring(queueMessage):sub(1, 50) else Status.Text = "Đang chuyển server..." end

            local teleportOk, teleportError = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, selected.id, LocalPlayer)
            end)
            if not teleportOk then
                busy = false
                TeleportQueued = false
                HopButton.Text = T("ServerHopButton")
                Status.Text = "Từ chối: " .. tostring(teleportError):sub(1, 60)
            end
        end)
    end)

    Connect(TeleportService.TeleportInitFailed, function(player, result, errorMessage)
        if player == LocalPlayer and Card.Parent then
            busy = false
            TeleportQueued = false
            HopButton.Text = T("ServerHopButton")
            Status.Text = "Thất bại: " .. tostring(errorMessage or result):sub(1, 60)
        end
    end)

    Connect(CopyButton.MouseButton1Down, function()
        local copied = false
        if type(setclipboard) == "function" then copied = pcall(setclipboard, serverListUrl) end
        if copied then Status.Text = T("ServerHopCopied") else Status.Text = T("ServerHopCopyManual") end
    end)

    RegisterLangRefresh(function()
        Label.Text = T("ServerHopTitle")
        Desc.Text = T("ServerHopDesc")
        HopButton.Text = T("ServerHopButton")
        CopyButton.Text = T("ServerHopCopy")
    end)
    table.insert(allCards, Card)
    return function() end
end
local syncServerHop = CreateServerHopCard()

-- ==================== TỰ CẬP NHẬT NGÔN NGỮ KHI ĐỔI TRONG ROBLOX ====================
RefreshAllLanguage = function()
	local nextLocale = ResolveLocaleCode()
	currentLocale = nextLocale
	pcall(function()
		if TitleLabel then TitleLabel.Text = "❖ " .. T("Title") end
		if SearchBox then SearchBox.PlaceholderText = T("Search") end
		if RestoreBtn then RestoreBtn.Text = T("Restore") end
		if SaveBtn then SaveBtn.Text = T("Save") end
	end)
	for _, fn in ipairs(LanguageRefreshers) do
		pcall(fn)
	end
end

RegisterLangRefresh(function() end) -- no-op keeps table non-empty

-- Theo dõi LocaleId / RobloxLocaleId thay đổi
pcall(function()
	Connect(LocalPlayer:GetPropertyChangedSignal("LocaleId"), function()
		task.defer(RefreshAllLanguage)
	end)
end)
pcall(function()
	Connect(LocalizationService:GetPropertyChangedSignal("RobloxLocaleId"), function()
		task.defer(RefreshAllLanguage)
	end)
end)
-- Dự phòng: kiểm tra định kỳ (một số client không fire signal)
task.spawn(function()
	local last = currentLocale
	while IsRunning do
		task.wait(2)
		local now = ResolveLocaleCode()
		if now ~= last then
			last = now
			RefreshAllLanguage()
		end
	end
end)


local function UpdateCanvas()
	Scroll.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y + 15)
end
Connect(UIList:GetPropertyChangedSignal("AbsoluteContentSize"), UpdateCanvas)
task.defer(UpdateCanvas)

task.spawn(function()
	while IsRunning do
		if AreaMonitorEnabled and MainFrame.Visible then
			pcall(RefreshAreaStatus)
			local character = LocalPlayer.Character
			local hasRoot = character and character:FindFirstChild("HumanoidRootPart")
			task.wait(hasRoot and 3 or 1)
		else
			task.wait(1)
		end
	end
end)

local function CardSearchText(card)
	-- Include button/input text too: scale buttons (1-10 / 1-21) are TextButtons,
	-- so the old TextLabel-only search could not find the selector by its own labels.
	local parts = { card.Name }
	for _, d in ipairs(card:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
			table.insert(parts, d.Text)
		end
	end
	return string.lower(table.concat(parts, " "))
end
Connect(SearchBox:GetPropertyChangedSignal("Text"), function()
	local q = string.lower(SearchBox.Text)
	for _, card in ipairs(allCards) do
		card.Visible = (q == "") or (string.find(CardSearchText(card), q, 1, true) ~= nil)
	end
	UpdateCanvas()
end)

-- Keep the red circular button visible; HiddenLego only hides the center logo.
-- hideFloat is used only by menu visibility behavior.
SetMenuVisible = function(v, hideFloat)
	isOpen = (v == true)
	if ScreenGui then ScreenGui.Enabled = true end
	if MainFrame then MainFrame.Visible = isOpen end
	if ToggleGui then
		pcall(function() ToggleGui.Parent = ParentTarget end)
		ToggleGui.Enabled = true
		if ToggleButton then
			local showFloatButton = not (hideFloat and not isOpen)
			ToggleButton.Visible = showFloatButton
			ToggleButton.Active = showFloatButton
			ToggleButton.Selectable = showFloatButton
		end
	end
end

local function Shutdown(byUser)
	if not IsRunning then return end
	IsRunning = false

	pcall(function() shared.VampireOptimizerDisabled = true end)
	pcall(function() PersistentEnv.VampireOptimizerDisabled = true end)
	if byUser == true then
		pcall(function()
			if type(writefile) == "function" then
				Persist.EnsureDir()
				writefile(Persist.Flag, "1")
			end
		end)
	end

	pcall(SaveConfig)
	pcall(RestoreAllGraphics)

	for i = #Connections, 1, -1 do
		local connection = Connections[i]
		pcall(function() connection:Disconnect() end)
		Connections[i] = nil
	end

	pcall(function() if ScreenGui then ScreenGui:Destroy() end end)
	pcall(function() if ToggleGui then ToggleGui:Destroy() end end)
	pcall(function()
		local env = PersistentEnv
		if type(env.VampireOptimizerRuntime) == "table" then env.VampireOptimizerRuntime = nil end
		if type(shared.VampireOptimizerRuntime) == "table" then shared.VampireOptimizerRuntime = nil end
	end)
	pcall(function() if SkyFolder then SkyFolder:Destroy() end end)
end

-- ToggleButton click is handled in drag InputEnded (distinguishes click vs drag)
Connect(MinBtn.MouseButton1Down, function() SetMenuVisible(false, false) end)
Connect(CloseBtn.MouseButton1Down, function() Shutdown(true) end)

Connect(RestoreBtn.MouseButton1Down, function()
	RestoreAllGraphics()
	syncPlast(false)
	syncTex(false)
	syncShad(false)
	syncFullBright(false)
	syncFx(100)
	syncDist(Config.RenderDistance, false)
	local originalQualityName = Backup.InitialEngineQuality.Name
	local originalQualityLevel = tonumber(originalQualityName:match("^Level(%d+)$"))
	if originalQualityLevel then syncEng(originalQualityLevel, false) else syncEng("AUTO", false) end
	syncTerr(false)
	syncSky()
	syncHair(false)
	syncStripClothing(false)
	syncHairColor()

	RestoreBtn.Text = T("RestoredSuccess")
	task.delay(1.5, function() if IsRunning and RestoreBtn.Parent then RestoreBtn.Text = T("Restore") end end)
end)

Connect(SaveBtn.MouseButton1Down, function()
	local saved, saveDetail = SaveConfig()
	SaveBtn.Text = saved and ((saveDetail == "memory only") and "SAVED IN SESSION" or T("SavedSuccess")) or "SAVE FAILED"
	task.delay(1.5, function() if IsRunning and SaveBtn.Parent then SaveBtn.Text = T("Save") end end)
end)

Connect(workspace.DescendantAdded, function(v)
	task.defer(function()
		if not IsRunning or not v or not v.Parent then return end
		if Config.FxScale < 100 then
			local f = Config.FxScale / 100
			if v:IsA("ParticleEmitter") then
				if Backup.OriginalFx[v] == nil then Backup.OriginalFx[v] = { Enabled = v.Enabled, Rate = v.Rate, Size = v.Size } end
				if Config.FxScale == 0 then v.Enabled = false else
					v.Enabled = Backup.OriginalFx[v].Enabled
					v.Rate = Backup.OriginalFx[v].Rate * f
				end
			elseif v:IsA("Fire") or v:IsA("Smoke") then
				if Backup.OriginalFx[v] == nil then Backup.OriginalFx[v] = { Enabled = v.Enabled, Size = v.Size } end
				if Config.FxScale == 0 then v.Enabled = false else
					v.Enabled = Backup.OriginalFx[v].Enabled
					v.Size = math.max(0.01, Backup.OriginalFx[v].Size * f)
				end
			elseif v:IsA("Light") then
				if Backup.OriginalFx[v] == nil then Backup.OriginalFx[v] = { Enabled = v.Enabled, Brightness = v.Brightness } end
				if Config.FxScale == 0 then v.Enabled = false else
					v.Enabled = Backup.OriginalFx[v].Enabled
					v.Brightness = math.max(0, Backup.OriginalFx[v].Brightness * f)
				end
			elseif v:IsA("Beam") or v:IsA("Trail") then
				if Backup.OriginalFx[v] == nil then Backup.OriginalFx[v] = { Enabled = v.Enabled } end
				v.Enabled = (Config.FxScale > 0) and Backup.OriginalFx[v].Enabled
			end
		end
		if Config.RemoveTextures and (v:IsA("Texture") or v:IsA("Decal")) and not isLucky(v) and not Held.IsHeld(v) then
			if Backup.OriginalTextures[v] == nil then Backup.OriginalTextures[v] = v.Transparency end
			v.Transparency = 1
		end
		if Config.RemoveShadows and v:IsA("BasePart") then
			if Backup.OriginalShadows[v] == nil then Backup.OriginalShadows[v] = v.CastShadow end
			v.CastShadow = false
		end
		if Config.FlatPlastic and v:IsA("BasePart") then
			ApplyFlatPlasticPart(v)
			-- Some experiences assign MaterialVariant shortly after parenting the part.
			task.delay(0.25, function()
				if IsRunning and Config.FlatPlastic and v and v.Parent then ApplyFlatPlasticPart(v) end
			end)
		end
		if Config.FlatHair then ApplyFlatHairObject(v) end
		if Held.OnAdded then Held.OnAdded(v) end
		if Config.StripClothing and IsRemovableClothing(v) then StripClothingInstance(v) end
	end)
end)

Connect(MaterialService.DescendantAdded, function(v)
	if not v:IsA("MaterialVariant") then return end
	task.defer(function()
		if IsRunning and Config.FlatPlastic and v and v.Parent then ApplyFlatMaterialVariant(v) end
	end)
end)

local function SafeApplySaved(label, callback)
	local ok, err = pcall(callback)
	if not ok then warn("[Vampire Optimizer] Apply " .. label .. " failed: " .. tostring(err)) end
end
Config.FlatHair = true
SafeApplySaved("FlatPlastic", function() SetFlatPlastic(Config.FlatPlastic) end)
SafeApplySaved("RemoveTextures", function() SetRemoveTextures(Config.RemoveTextures) end)
SafeApplySaved("RemoveShadows", function() SetRemoveShadows(Config.RemoveShadows) end)
SafeApplySaved("FullBright", function() SetFullBright(Config.FullBright) end)
SafeApplySaved("FxScale", function() ApplyFxScale(Config.FxScale) end)
SafeApplySaved("FogDistance", function() SetRenderDistance(Config.RenderDistance) end)
task.delay(1.0, ScheduleFogReapply)
task.delay(3.0, ScheduleFogReapply)
SafeApplySaved("EngineQuality", function() SetEngineQualityLevel(Config.EngineQuality) end)
task.defer(function() ApplyResolutionAutoQuality(true) end)
SafeApplySaved("LiteTerrain", function() SetLiteTerrain(Config.LiteTerrain) end)
SafeApplySaved("FlatHair", function() SetFlatHair(true) end)
SafeApplySaved("StripClothing", function() SetStripClothing(Config.StripClothing) end)
SafeApplySaved("SkyMode", function() ApplySkyMode(Config.SkyMode) end)
StoreConfigInMemory()
QueueAutoSave()

-- Khi khởi động / vào server mới: StartHidden quyết định menu có tự ẩn hay không.
-- HiddenLego chỉ ẩn logo ở giữa; nút tròn màu đỏ luôn được giữ lại.
local function ApplyStartVisibility()
	if Config.StartHidden then
		pcall(function() SetMenuVisible(false, false) end)
	else
		pcall(function() SetMenuVisible(true, false) end)
	end
end
ApplyStartVisibility()

local RuntimeHandle = { Stop = Shutdown }
pcall(function() PersistentEnv.VampireOptimizerRuntime = RuntimeHandle end)
pcall(function() shared.VampireOptimizerRuntime = RuntimeHandle end)
]==]

-- Embedded floating icon (vampire Roblox logo 128x128 PNG, base64)
local ICON_B64 = [[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]]

do
	local env = shared
	pcall(function() if type(getgenv) == "function" then env = getgenv() end end)
	pcall(function() shared.VampireOptimizerSource = VAMPIRE_SOURCE end)
	pcall(function() env.VampireOptimizerSource = VAMPIRE_SOURCE end)

	-- Write icon to executor workspace so getcustomasset can load it
	pcall(function()
		if type(makefolder) == "function" and type(isfolder) == "function" then
			if not isfolder("VampireOptimizer") then makefolder("VampireOptimizer") end
		end
		if type(writefile) == "function" and type(base64decode) == "function" then
			writefile("VampireOptimizer/icon.png", base64decode(ICON_B64))
		elseif type(writefile) == "function" and type(crypt) == "table" and type(crypt.base64decode) == "function" then
			writefile("VampireOptimizer/icon.png", crypt.base64decode(ICON_B64))
		elseif type(writefile) == "function" and type(base64) == "table" and type(base64.decode) == "function" then
			writefile("VampireOptimizer/icon.png", base64.decode(ICON_B64))
		elseif type(writefile) == "function" then
			-- Fallback pure Lua base64 decode
			local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
			local data = ICON_B64:gsub('[^'..b..'=]', '')
			local decoded = data:gsub('.', function(x)
				if x == '=' then return '' end
				local r, f = '', (b:find(x) - 1)
				for i = 6, 1, -1 do r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0') end
				return r
			end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
				if #x ~= 8 then return '' end
				local c = 0
				for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2^(8 - i) or 0) end
				return string.char(c)
			end)
			writefile("VampireOptimizer/icon.png", decoded)
		end
	end)
end

local chunk, compileError = loadstring(VAMPIRE_SOURCE, "VampireOptimizer")
if not chunk then
	warn("[Vampire Optimizer] compile error: " .. tostring(compileError))
	return
end
return chunk()
