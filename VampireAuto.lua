-- ====================================================================
--   VAMPIRE OPTIMIZER V7.7 - SELF-CONTAINED / AUTO RE-RUN AFTER TELEPORT
--   Paste this ONE file into the executor. Nothing else is needed (no URL, no outside app, no manual file):
--     * it saves its own copy to workspace/VampireOptimizer/main.lua
--     * when ANY teleport starts (lobby -> match, rejoin, server hop) it queues a small stub, like Cat Vape,
--       which loads that copy again in the next server.
--   Pressing X in the menu stops it for good (until you execute it again).
-- ====================================================================

local VAMPIRE_SOURCE = [==[
-- ====================================================================
--   VAMPIRE OPTIMIZER V7.7 - SOLID PLASTIC HAIR / TELEPORT PERSIST / PUBLIC SERVER HOP
--   V7.7: MONITOR button is a real OPTION again: default ON, but once you press it your choice (ON/OFF) is saved and kept after teleports/re-runs.
--         Galaxy sky prints/stores the texture preload status (console + COPY SKY REPORT) to find out whether the lobby sky textures fail to load.
--   V7.6: Map monitor is ALWAYS ON at start-up; Sky card has a COPY SKY REPORT button; flat non-collidable giant plates named sky/dome
--         (box-style skyboxes) are hidden too when Galaxy is selected.
--   V7.5: stronger Galaxy sky for lobbies that run their own sky code (e.g. a SkyboxController): guards the Galaxy textures against
--         being overwritten, hides huge dome-like sky parts (reversible), also stashes Terrain Clouds, 1s watchdog, prints a sky report.
--   V7.4: (1) Map check card is compact and auto-monitors (ON by default, no longer reset by re-runs/teleports);
--         (2) menu language follows Roblox live (no re-run needed);
--         (3) Galaxy/Default sky re-asserts itself when the game adds/removes Sky objects, restores the NEWEST game sky.
--   Auto applies saved client options; X restores graphics, disconnects events and destroys the GUI.
--   Visible players’ hair becomes ONE solid SmoothPlastic colour (texture stripped, colour sampled from the original); reversible. Falls back to flattening only when the colour cannot be read.
--   Self-installing teleport re-run (Cat/Vape-style, no outside app): the script saves its own copy to workspace/VampireOptimizer/main.lua, and LocalPlayer.OnTeleport -> queue_on_teleport re-runs it after ANY teleport (script hop or game-started, e.g. lobby -> match). Without a file API the whole source is embedded in the queued stub.
--   Removed player teleport/follow. Public server hop queries open public instances; client HTTP/teleport support can vary.
--   No private-server discovery, JobId scraping, or privacy bypass.
-- ====================================================================

local MaterialService = game:GetService("MaterialService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
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

-- ==================== ĐA NGÔN NGỮ TỰ ĐỘNG THEO ROBLOX ====================
-- Ưu tiên Player.LocaleId (ngôn ngữ tài khoản dùng cho nội dung trong trải nghiệm),
-- sau đó dùng LocalizationService.RobloxLocaleId (ngôn ngữ CoreGui).
local function ReadLocale()
	local locale = nil
	pcall(function() locale = LocalPlayer.LocaleId end)
	if type(locale) ~= "string" or locale == "" then
		pcall(function() locale = LocalizationService.RobloxLocaleId end)
	end
	if type(locale) ~= "string" or locale == "" then locale = "en-us" end
	return string.lower(locale:gsub("_", "-"))
end

local rawLocale = ReadLocale()
local localeBase = rawLocale:match("^([a-z]+)") or "en"
local currentLocale = localeBase
if localeBase == "zh" then
	if rawLocale:find("zh%-tw") or rawLocale:find("zh%-hk") or rawLocale:find("zh%-mo") then
		currentLocale = "zhTW"
	else
		currentLocale = "zhCN"
	end
end

local Lang = {
	vi = {
		Title="VAMPIRE OPTIMIZER V7.7", Search="Tìm kiếm tính năng...", Restore="Khôi phục đồ họa gốc", Save="Lưu cấu hình",
		FlatPlastic="Làm phẳng vật liệu (Nhựa)", FlatPlasticDesc="Đổi bề mặt sang nhựa; bỏ qua khối Lucky",
		RemoveTextures="Ẩn Texture và Decal", RemoveTexturesDesc="Ẩn texture và decal trên bề mặt",
		RemoveShadows="Tắt bóng đổ", RemoveShadowsDesc="Tắt bóng của vật thể để giảm tải đồ họa",
		FxScaleTitle="Giảm hiệu ứng (0% - 100%)", FxScaleDesc="0% = tắt; 50% = giảm một nửa; 100% = mặc định",
		RenderDistTitle="Khoảng sương mù", RenderDistDesc="Chỉ chỉnh Fog; không vượt giới hạn render hoặc Streaming của Roblox",
		EngineQualityTitle="Chất lượng đồ họa (Level 1 - 21)", EngineQualityDesc="Level 1 nhẹ nhất; tầm nhìn vẫn tối đa nếu bật Giữ tầm nhìn",
		LiteTerrain="Tối ưu địa hình", LiteTerrainDesc="Giảm sóng nước, phản xạ và cỏ trang trí",
		SkyTitle="Tùy chọn bầu trời", SkyDesc="Chuyển giữa bầu trời Galaxy và bầu trời gốc",
		SkyGalaxy="Bầu trời Galaxy", SkyDefault="Bầu trời gốc của game",
		RestoredSuccess="Đã khôi phục đồ họa gốc!", SavedSuccess="Đã lưu cấu hình!",
		AreaTitle="Kiểm tra mở rộng map (Client)", AreaDesc="Chỉ kiểm tra vật thể đã nhận; không thể ép server mở rộng Streaming",
		ExpansionScriptStatus="Mở rộng map do V6.5: KHÔNG — chỉ chỉnh đồ họa/Fog", ExpansionServerStatus="Streaming server: KHÔNG THỂ ĐỌC hoặc CHỈNH từ client", ExpansionHint="Mở Network Stats bằng Shift+F3; các bảng debug tùy phiên bản Roblox",
		AreaStatus="Vật thể trong bán kính 512 studs: %s | RAM: %s", MonitorOn="THEO DÕI: BẬT", MonitorOff="THEO DÕI: TẮT", Scan="QUÉT NGAY",
		HairFlatTitle="Tóc nhựa một màu (tự bật)", HairFlatDesc="Biến tóc người chơi thành nhựa SmoothPlastic một màu: xóa texture rồi tô màu lấy từ màu gốc của tóc. Chỉ thấy trên máy bạn; có thể khôi phục.",
        HairColorTitle="Tóc một màu theo màu gốc", HairColorDesc="Đọc màu trung bình từ texture tóc gốc (cần executor hỗ trợ EditableImage). Không đọc được màu thì tóc giữ texture nhưng vẫn được làm phẳng PBR.", HairRescan="QUÉT LẠI TÓC", HairRescanDone="Đã quét lại tóc của người chơi đang tải.", HairRescanEnable="Hãy bật Tóc nhựa trước khi quét lại.", HairSolidOn="MỘT MÀU: BẬT", HairSolidOff="MỘT MÀU: TẮT", HairStats="Một màu: %s | Chỉ làm phẳng: %s | Đang xử lý: %s", FarViewTitle="Giữ tầm nhìn tối đa (như FFlag)", FarViewDesc="Đồ họa theo Level đã chọn, tầm nhìn vẫn như Level 21 (cần setfflag)", TeleportPersistTitle="Tự chạy lại sau khi chuyển server", TeleportPersistDesc="Tự lưu bản sao vào workspace, tự chạy lại sau MỌI lần teleport (như Cat Vape)",
		AutoSaveTitle="Tự động lưu tùy chọn", AutoSaveDesc="Tự lưu sau khi thay đổi (cần executor hỗ trợ ghi file)",
		JoinPlayerTitle="Tham gia server người chơi", JoinPlayerDesc="Không thể tự tìm JobId từ client trong game người khác; dùng nút Join chính thức nếu người chơi cho phép",
		JoinPlayerStatus="Nhập username để tạo link hồ sơ; Roblox chỉ hiện Join nếu người đó cho phép.",
        JoinUsernamePlaceholder="Nhập username Roblox...", JoinLookup="TRA CỨU", JoinCopy="SAO CHÉP LINK", JoinEmpty="Hãy nhập username Roblox.", JoinLooking="Đang tìm tài khoản...", JoinFound="Đã tìm thấy UserId %s. Dùng Join Experience trên hồ sơ nếu được phép.", JoinFailed="Không tìm thấy username hoặc Roblox đang giới hạn tra cứu.", JoinCopied="Đã sao chép link hồ sơ. Mở link và chọn Join Experience nếu xuất hiện.", JoinCopyManual="Không có clipboard API. Chọn link bên dưới rồi Ctrl+C.", JoinSameServer="Người chơi này đang ở server hiện tại.", JoinNotCurrent="Chưa thấy người này trong server hiện tại; link hồ sơ đã sẵn sàng.",
        JoinAutoTitle="Nhận diện và theo dõi người chơi", JoinAutoDesc="Tự nhận diện game/người chơi trong server này; có nút TP đến hoặc theo dõi cục bộ.",
        JoinGameInfo="Game: %s\nBạn: %s (@%s) | PlaceId: %s", JoinPlayersTitle="Người chơi cùng server: %s", JoinRefresh="LÀM MỚI", JoinNoOtherPlayers="Chưa có người chơi khác trong server này.", JoinSelectHint="Chọn một người trong danh sách để xem hồ sơ Roblox.", JoinSelected="Đã chọn: %s (@%s) | UserId: %s", JoinCopySelected="SAO CHÉP HỒ SƠ", JoinProfileCopied="Đã sao chép link hồ sơ Roblox.", JoinGameLoading="Đang nhận diện tên game...", JoinSameServerNote="Người trong danh sách đã ở cùng server với bạn; đây không phải danh sách server khác.",
        TeleportToPlayer="TP ĐẾN NGƯỜI CHƠI", FollowStart="THEO DÕI: TẮT", FollowStop="DỪNG THEO DÕI", FollowStarted="Đang thử theo dõi %s trong server hiện tại.", FollowStopped="Đã dừng theo dõi.", TeleportAttempt="Đã gửi yêu cầu di chuyển cạnh người chơi. Server game có thể chặn hoặc hoàn tác.", FollowNeedsTarget="Hãy chọn một người chơi khác trong danh sách.", FollowSameServer="Chỉ dịch chuyển/theo dõi người đang ở cùng server; không chuyển sang server khác.",
		ServerHopTitle="Đổi server công khai ngẫu nhiên", ServerHopDesc="Gửi yêu cầu Roblox matchmaking vào một phiên công khai của game hiện tại. Roblox có thể chọn lại server hiện tại; không đảm bảo ngẫu nhiên.", ServerHopButton="ĐỔI SERVER", ServerHopCopy="SAO CHÉP LINK DANH SÁCH SERVER", ServerHopReady="Sẵn sàng yêu cầu Roblox tìm phiên công khai.", ServerHopStarting="Đã gửi yêu cầu chuyển phiên cho Roblox...", ServerHopFailed="Không thể bắt đầu chuyển server: %s", ServerHopFailedEvent="Roblox từ chối chuyển server: %s", ServerHopCooldown="Vui lòng đợi trước khi thử lại.", ServerHopCopied="Đã sao chép link danh sách server công khai.", ServerHopCopyManual="Không có clipboard API; mở link server list thủ công.", On="BẬT", Off="TẮT", WaitingCharacter="Đang chờ nhân vật...",
	},
	en = {
		Title="VAMPIRE OPTIMIZER V7.7", Search="Search features...", Restore="Restore original graphics", Save="Save settings",
		FlatPlastic="Flat materials (Plastic)", FlatPlasticDesc="Convert surfaces to plastic; skips Lucky blocks",
		RemoveTextures="Hide textures and decals", RemoveTexturesDesc="Hide surface textures and decals",
		RemoveShadows="Disable shadows", RemoveShadowsDesc="Disable object shadows to reduce graphics load",
		FxScaleTitle="Effect reduction (0% - 100%)", FxScaleDesc="0% = off; 50% = half; 100% = default",
		RenderDistTitle="Fog distance", RenderDistDesc="Changes fog only; cannot bypass Roblox render or Streaming limits",
		EngineQualityTitle="Graphics quality (Level 1 - 21)", EngineQualityDesc="Level 1 is lightest; view stays max if Keep view distance is on",
		LiteTerrain="Lite terrain", LiteTerrainDesc="Reduces water waves, reflections, and decorative grass",
		SkyTitle="Sky options", SkyDesc="Switch between Galaxy sky and the game's original sky",
		SkyGalaxy="Galaxy sky", SkyDefault="Game default sky",
		RestoredSuccess="Original graphics restored!", SavedSuccess="Settings saved!",
		AreaTitle="Map expansion check (Client)", AreaDesc="Checks objects already received; cannot force server Streaming expansion",
		ExpansionScriptStatus="Map expanded by V6.5: NO — graphics/Fog only", ExpansionServerStatus="Server Streaming: CANNOT READ or CHANGE from client", ExpansionHint="Open Network Stats with Shift+F3; debug panels vary by Roblox version",
		AreaStatus="Objects within 512 studs: %s | RAM: %s", MonitorOn="MONITOR: ON", MonitorOff="MONITOR: OFF", Scan="SCAN NOW",
		HairFlatTitle="Solid plastic hair (auto enabled)", HairFlatDesc="Turns every visible player’s hair into one solid SmoothPlastic colour: strips the texture and paints it with the hair’s original colour. Local only; reversible.",
        HairColorTitle="Solid hair, original colour", HairColorDesc="Averages the colour of the original hair texture (needs EditableImage support in your executor). If the colour cannot be read, the hair keeps its texture but is still flattened.", HairRescan="RESCAN HAIR", HairRescanDone="Rescanned hair for currently loaded players.", HairRescanEnable="Turn on Plastic hair before rescanning.", HairSolidOn="SOLID: ON", HairSolidOff="SOLID: OFF", HairStats="Solid: %s | Flattened only: %s | Working: %s", FarViewTitle="Keep max view distance (FFlag)", FarViewDesc="Visuals follow the chosen level, view stays at Level 21 (needs setfflag)", TeleportPersistTitle="Re-run after server change", TeleportPersistDesc="Saves itself to workspace, re-runs after EVERY teleport (like Cat Vape)",
		AutoSaveTitle="Auto-save settings", AutoSaveDesc="Saves after changes (requires executor file-write support)",
		JoinPlayerTitle="Join a player server", JoinPlayerDesc="A client script in someone else’s game cannot look up another player’s JobId; use Roblox’s official Join option when allowed",
		JoinPlayerStatus="Enter a username to make a profile link; Roblox shows Join only when that user allows it.",
        JoinUsernamePlaceholder="Enter Roblox username...", JoinLookup="LOOK UP", JoinCopy="COPY LINK", JoinEmpty="Enter a Roblox username first.", JoinLooking="Looking up account...", JoinFound="UserId %s found. Use Join Experience on the profile if available.", JoinFailed="Username not found or Roblox lookup is temporarily limited.", JoinCopied="Profile link copied. Open it and choose Join Experience if shown.", JoinCopyManual="Clipboard API unavailable. Select the link below and press Ctrl+C.", JoinSameServer="This player is already in your current server.", JoinNotCurrent="Player not found in this server; profile link is ready.",
        JoinAutoTitle="Detect and follow players", JoinAutoDesc="Detects the experience and players in this server; includes local TP/follow controls.",
        JoinGameInfo="Game: %s\nYou: %s (@%s) | PlaceId: %s", JoinPlayersTitle="Players in this server: %s", JoinRefresh="REFRESH", JoinNoOtherPlayers="No other players are in this server.", JoinSelectHint="Select a player from the list to view their Roblox profile.", JoinSelected="Selected: %s (@%s) | UserId: %s", JoinCopySelected="COPY PROFILE", JoinProfileCopied="Roblox profile link copied.", JoinGameLoading="Detecting experience name...", JoinSameServerNote="Players in this list are already in your current server; this is not a list of other servers.",
        TeleportToPlayer="TP TO PLAYER", FollowStart="FOLLOW: OFF", FollowStop="STOP FOLLOWING", FollowStarted="Trying to follow %s in this server.", FollowStopped="Follow stopped.", TeleportAttempt="Move request sent near the player. The game server may block or revert it.", FollowNeedsTarget="Select another player from this server first.", FollowSameServer="Teleport/follow works only for players in this same server; it does not switch servers.",
		ServerHopTitle="Random public server hop", ServerHopDesc="Ask Roblox matchmaking to place you in a public session of this experience. Roblox may choose the current server; a random/different server is not guaranteed.", ServerHopButton="HOP SERVER", ServerHopCopy="COPY PUBLIC SERVER LIST LINK", ServerHopReady="Ready to ask Roblox for a public session.", ServerHopStarting="Server-switch request sent to Roblox...", ServerHopFailed="Could not start server switch: %s", ServerHopFailedEvent="Roblox rejected the server switch: %s", ServerHopCooldown="Please wait before trying again.", ServerHopCopied="Public server list link copied.", ServerHopCopyManual="Clipboard API unavailable; open the server list link manually.", On="ON", Off="OFF", WaitingCharacter="Waiting for character...",
	},
	ar = {
		Title="VAMPIRE OPTIMIZER V7.7", Search="البحث عن الميزات...", Restore="استعادة الرسومات الأصلية", Save="حفظ الإعدادات",
		FlatPlastic="مواد مسطحة (بلاستيك)", FlatPlasticDesc="تحويل الأسطح إلى بلاستيك مع استثناء كتل Lucky",
		RemoveTextures="إخفاء الخامات والملصقات", RemoveTexturesDesc="إخفاء الخامات والملصقات السطحية",
		RemoveShadows="إيقاف الظلال", RemoveShadowsDesc="إيقاف ظلال العناصر لتقليل حمل الرسومات",
		FxScaleTitle="تقليل التأثيرات (0% - 100%)", FxScaleDesc="0% = إيقاف؛ 50% = النصف؛ 100% = الافتراضي",
		RenderDistTitle="مسافة الضباب", RenderDistDesc="يعدّل الضباب فقط ولا يتجاوز حدود العرض أو التحميل في Roblox",
		EngineQualityTitle="جودة الرسومات (المستوى 1 - 21)", EngineQualityDesc="المستوى 1 هو الأخف؛ المستويات الأعلى أجمل وأكثر استهلاكاً",
		LiteTerrain="تبسيط التضاريس", LiteTerrainDesc="تقليل موجات الماء والانعكاسات والعشب الزخرفي",
		SkyTitle="خيارات السماء", SkyDesc="التبديل بين سماء Galaxy والسماء الأصلية للعبة",
		SkyGalaxy="سماء Galaxy", SkyDefault="سماء اللعبة الأصلية",
		RestoredSuccess="تمت استعادة الرسومات الأصلية!", SavedSuccess="تم حفظ الإعدادات!",
		AreaTitle="فحص توسيع الخريطة (العميل)", AreaDesc="يفحص العناصر المستلمة فقط؛ لا يفرض توسيع البث من الخادم",
		ExpansionScriptStatus="توسيع الخريطة بواسطة V6.4: لا — الرسومات/الضباب فقط", ExpansionServerStatus="بث الخادم: لا يمكن قراءته أو تغييره من العميل", ExpansionHint="للتحقق: Shift+F3 ثم Shift+1 حتى لوحة Streaming",
		AreaStatus="العناصر ضمن 512 وحدة: %s | الذاكرة: %s", MonitorOn="المراقبة: تشغيل", MonitorOff="المراقبة: إيقاف", Scan="افحص الآن",
		On="تشغيل", Off="إيقاف", WaitingCharacter="بانتظار الشخصية...",
	},
	zhCN = {
		Title="VAMPIRE OPTIMIZER V7.7", Search="搜索功能...", Restore="恢复原始画质", Save="保存设置",
		FlatPlastic="平滑材质（塑料）", FlatPlasticDesc="将表面改为塑料材质，跳过 Lucky 方块",
		RemoveTextures="隐藏纹理和贴花", RemoveTexturesDesc="隐藏表面纹理与贴花",
		RemoveShadows="关闭阴影", RemoveShadowsDesc="关闭物体阴影以降低图形负载",
		FxScaleTitle="特效缩减（0% - 100%）", FxScaleDesc="0% = 关闭；50% = 减半；100% = 默认",
		RenderDistTitle="雾效距离", RenderDistDesc="仅调整雾效，无法绕过 Roblox 渲染或流式加载限制",
		EngineQualityTitle="画质等级（1 - 21）", EngineQualityDesc="等级 1 最轻；更高等级通常画面更好但更耗资源",
		LiteTerrain="精简地形", LiteTerrainDesc="减少水波、反射和装饰性草地",
		SkyTitle="天空选项", SkyDesc="在 Galaxy 星空和游戏原始天空之间切换",
		SkyGalaxy="Galaxy 星空", SkyDefault="游戏原始天空",
		RestoredSuccess="已恢复原始画质！", SavedSuccess="设置已保存！",
		AreaTitle="地图扩展检查（客户端）", AreaDesc="只检查客户端已收到的物体；不能强制服务器扩大流式加载",
		ExpansionScriptStatus="V6.4 扩展地图：否 — 仅调整画质/雾效", ExpansionServerStatus="服务器流式加载：客户端无法读取或修改", ExpansionHint="验证：Shift+F3，然后按 Shift+1 切换到 Streaming 面板",
		AreaStatus="512 单位范围内物体：%s | 内存：%s", MonitorOn="监视：开启", MonitorOff="监视：关闭", Scan="立即扫描",
		On="开启", Off="关闭", WaitingCharacter="正在等待角色...",
	},
	zhTW = {
		Title="VAMPIRE OPTIMIZER V7.7", Search="搜尋功能...", Restore="還原原始畫質", Save="儲存設定",
		FlatPlastic="平滑材質（塑膠）", FlatPlasticDesc="將表面改為塑膠材質，略過 Lucky 方塊",
		RemoveTextures="隱藏材質與貼花", RemoveTexturesDesc="隱藏表面材質與貼花",
		RemoveShadows="關閉陰影", RemoveShadowsDesc="關閉物件陰影以降低圖形負載",
		FxScaleTitle="特效縮減（0% - 100%）", FxScaleDesc="0% = 關閉；50% = 減半；100% = 預設",
		RenderDistTitle="霧效距離", RenderDistDesc="只調整霧效，無法略過 Roblox 渲染或串流載入限制",
		EngineQualityTitle="畫質等級（1 - 21）", EngineQualityDesc="等級 1 最輕；較高等級通常畫面較好但更耗資源",
		LiteTerrain="精簡地形", LiteTerrainDesc="減少水波、反射與裝飾草地",
		SkyTitle="天空選項", SkyDesc="切換 Galaxy 星空與遊戲原始天空",
		SkyGalaxy="Galaxy 星空", SkyDefault="遊戲原始天空",
		RestoredSuccess="已還原原始畫質！", SavedSuccess="設定已儲存！",
		AreaTitle="地圖擴展檢查（用戶端）", AreaDesc="只檢查用戶端已收到的物件；無法強制伺服器擴大串流",
		ExpansionScriptStatus="V6.4 擴展地圖：否 — 僅調整畫質/霧效", ExpansionServerStatus="伺服器串流：用戶端無法讀取或修改", ExpansionHint="驗證：Shift+F3，再按 Shift+1 切換至 Streaming 面板",
		AreaStatus="512 單位範圍內物件：%s | 記憶體：%s", MonitorOn="監視：開啟", MonitorOff="監視：關閉", Scan="立即掃描",
		On="開啟", Off="關閉", WaitingCharacter="正在等待角色...",
	},
	fr = {
		Title="VAMPIRE OPTIMIZER V7.7", Search="Rechercher une option...", Restore="Restaurer les graphismes", Save="Enregistrer",
		FlatPlastic="Matériaux plats (plastique)", FlatPlasticDesc="Passe les surfaces en plastique, sauf les blocs Lucky",
		RemoveTextures="Masquer textures et décalcomanies", RemoveTexturesDesc="Masque les textures et décalcomanies de surface",
		RemoveShadows="Désactiver les ombres", RemoveShadowsDesc="Désactive les ombres pour réduire la charge graphique",
		FxScaleTitle="Réduction des effets (0% - 100%)", FxScaleDesc="0% = arrêt ; 50% = moitié ; 100% = normal",
		RenderDistTitle="Distance du brouillard", RenderDistDesc="Modifie seulement le brouillard, sans dépasser les limites Roblox",
		EngineQualityTitle="Qualité graphique (niveau 1 - 21)", EngineQualityDesc="Le niveau 1 est le plus léger ; les niveaux supérieurs sont plus exigeants",
		LiteTerrain="Terrain simplifié", LiteTerrainDesc="Réduit les vagues, reflets et herbes décoratives",
		SkyTitle="Options du ciel", SkyDesc="Basculer entre le ciel Galaxy et le ciel d'origine",
		SkyGalaxy="Ciel Galaxy", SkyDefault="Ciel d'origine du jeu",
		RestoredSuccess="Graphismes d'origine restaurés !", SavedSuccess="Paramètres enregistrés !",
		AreaTitle="Vérifier l’extension de carte (client)", AreaDesc="Compte les objets reçus ; ne peut pas élargir le Streaming du serveur",
		ExpansionScriptStatus="Carte agrandie par V6.4 : NON — graphismes/brouillard uniquement", ExpansionServerStatus="Streaming serveur : lecture/modification impossible côté client", ExpansionHint="Vérifier : Shift+F3, puis Shift+1 jusqu’au panneau Streaming",
		AreaStatus="Objets à 512 studs : %s | RAM : %s", MonitorOn="SURVEILLANCE : OUI", MonitorOff="SURVEILLANCE : NON", Scan="SCANNER",
		On="OUI", Off="NON", WaitingCharacter="En attente du personnage...",
	},
	de = {
		Title="VAMPIRE OPTIMIZER V7.7", Search="Funktion suchen...", Restore="Originalgrafik wiederherstellen", Save="Einstellungen speichern",
		FlatPlastic="Flache Materialien (Plastik)", FlatPlasticDesc="Oberflächen auf Plastik setzen; Lucky-Blöcke auslassen",
		RemoveTextures="Texturen und Abziehbilder ausblenden", RemoveTexturesDesc="Oberflächen-Texturen und Decals ausblenden",
		RemoveShadows="Schatten deaktivieren", RemoveShadowsDesc="Objektschatten deaktivieren, um Grafiklast zu senken",
		FxScaleTitle="Effekte reduzieren (0% - 100%)", FxScaleDesc="0% = aus; 50% = halb; 100% = normal",
		RenderDistTitle="Nebelreichweite", RenderDistDesc="Ändert nur Nebel und umgeht keine Roblox-Render- oder Streaming-Grenzen",
		EngineQualityTitle="Grafikqualität (Stufe 1 - 21)", EngineQualityDesc="Stufe 1 ist am leichtesten; höhere Stufen benötigen mehr Leistung",
		LiteTerrain="Terrain optimieren", LiteTerrainDesc="Reduziert Wasserwellen, Spiegelungen und Ziergras",
		SkyTitle="Himmelsoptionen", SkyDesc="Zwischen Galaxy-Himmel und Spielhimmel wechseln",
		SkyGalaxy="Galaxy-Himmel", SkyDefault="Spielstandard-Himmel",
		RestoredSuccess="Originalgrafik wiederhergestellt!", SavedSuccess="Einstellungen gespeichert!",
		AreaTitle="Kartenerweiterung prüfen (Client)", AreaDesc="Zählt empfangene Objekte; kann Server-Streaming nicht erweitern",
		ExpansionScriptStatus="Karte durch V6.4 erweitert: NEIN — nur Grafik/Nebel", ExpansionServerStatus="Server-Streaming: clientseitig nicht lesbar/änderbar", ExpansionHint="Prüfen: Shift+F3, dann Shift+1 bis zum Streaming-Fenster",
		AreaStatus="Objekte im Umkreis von 512 Studs: %s | RAM: %s", MonitorOn="MONITOR: AN", MonitorOff="MONITOR: AUS", Scan="JETZT SCANNEN",
		On="AN", Off="AUS", WaitingCharacter="Warte auf Charakter...",
	},
	hi = {
		Title="VAMPIRE OPTIMIZER V7.7", Search="फीचर खोजें...", Restore="मूल ग्राफ़िक्स वापस लाएँ", Save="सेटिंग सहेजें",
		FlatPlastic="फ्लैट सामग्री (प्लास्टिक)", FlatPlasticDesc="सतहों को प्लास्टिक करें; Lucky ब्लॉक छोड़ें",
		RemoveTextures="टेक्सचर और डेकल छिपाएँ", RemoveTexturesDesc="सतह के टेक्सचर और डेकल छिपाएँ",
		RemoveShadows="छायाएँ बंद करें", RemoveShadowsDesc="ग्राफ़िक्स लोड कम करने के लिए वस्तुओं की छायाएँ बंद करें",
		FxScaleTitle="इफेक्ट कम करें (0% - 100%)", FxScaleDesc="0% = बंद; 50% = आधा; 100% = सामान्य",
		RenderDistTitle="कोहरे की दूरी", RenderDistDesc="केवल कोहरा बदलता है; Roblox की रेंडर या स्ट्रीमिंग सीमा नहीं हटाता",
		EngineQualityTitle="ग्राफ़िक्स गुणवत्ता (स्तर 1 - 21)", EngineQualityDesc="स्तर 1 सबसे हल्का; ऊँचे स्तर अधिक संसाधन लेते हैं",
		LiteTerrain="हल्का Terrain", LiteTerrainDesc="पानी की लहरें, प्रतिबिंब और सजावटी घास कम करें",
		SkyTitle="आकाश विकल्प", SkyDesc="Galaxy आकाश और गेम के मूल आकाश के बीच बदलें",
		SkyGalaxy="Galaxy आकाश", SkyDefault="गेम का मूल आकाश",
		RestoredSuccess="मूल ग्राफ़िक्स बहाल हुए!", SavedSuccess="सेटिंग सहेजी गई!",
		AreaTitle="मैप विस्तार जाँच (क्लाइंट)", AreaDesc="केवल प्राप्त ऑब्जेक्ट गिनता है; सर्वर Streaming नहीं बढ़ा सकता",
		ExpansionScriptStatus="V6.4 द्वारा मैप विस्तार: नहीं — केवल ग्राफ़िक्स/कोहरा", ExpansionServerStatus="सर्वर Streaming: क्लाइंट से पढ़ या बदल नहीं सकते", ExpansionHint="जाँच: Shift+F3, फिर Streaming पैनल तक Shift+1",
		AreaStatus="512 studs के भीतर वस्तुएँ: %s | RAM: %s", MonitorOn="मॉनिटर: चालू", MonitorOff="मॉनिटर: बंद", Scan="अभी स्कैन करें",
		On="चालू", Off="बंद", WaitingCharacter="कैरेक्टर की प्रतीक्षा...",
	},
	id = {
		Title="VAMPIRE OPTIMIZER V7.7", Search="Cari fitur...", Restore="Pulihkan grafis asli", Save="Simpan pengaturan",
		FlatPlastic="Material datar (Plastik)", FlatPlasticDesc="Ubah permukaan menjadi plastik; lewati blok Lucky",
		RemoveTextures="Sembunyikan tekstur dan decal", RemoveTexturesDesc="Sembunyikan tekstur dan decal permukaan",
		RemoveShadows="Matikan bayangan", RemoveShadowsDesc="Matikan bayangan objek untuk mengurangi beban grafis",
		FxScaleTitle="Kurangi efek (0% - 100%)", FxScaleDesc="0% = mati; 50% = setengah; 100% = normal",
		RenderDistTitle="Jarak kabut", RenderDistDesc="Hanya mengubah kabut; tidak melewati batas render atau Streaming Roblox",
		EngineQualityTitle="Kualitas grafis (Level 1 - 21)", EngineQualityDesc="Level 1 paling ringan; level lebih tinggi biasanya lebih berat",
		LiteTerrain="Terrain ringan", LiteTerrainDesc="Kurangi gelombang air, refleksi, dan rumput dekoratif",
		SkyTitle="Opsi langit", SkyDesc="Beralih antara langit Galaxy dan langit asli game",
		SkyGalaxy="Langit Galaxy", SkyDefault="Langit asli game",
		RestoredSuccess="Grafis asli dipulihkan!", SavedSuccess="Pengaturan disimpan!",
		AreaTitle="Periksa perluasan map (Klien)", AreaDesc="Menghitung objek yang diterima; tidak dapat memperluas Streaming server",
		ExpansionScriptStatus="Map diperluas oleh V6.4: TIDAK — hanya grafis/kabut", ExpansionServerStatus="Streaming server: tidak dapat dibaca/diubah dari klien", ExpansionHint="Periksa: Shift+F3, lalu Shift+1 hingga panel Streaming",
		AreaStatus="Objek dalam 512 studs: %s | RAM: %s", MonitorOn="MONITOR: AKTIF", MonitorOff="MONITOR: NONAKTIF", Scan="PINDAI SEKARANG",
		On="AKTIF", Off="NONAKTIF", WaitingCharacter="Menunggu karakter...",
	},
	it = {
		Title="VAMPIRE OPTIMIZER V7.7", Search="Cerca funzione...", Restore="Ripristina grafica originale", Save="Salva impostazioni",
		FlatPlastic="Materiali piatti (plastica)", FlatPlasticDesc="Imposta superfici in plastica; esclude i blocchi Lucky",
		RemoveTextures="Nascondi texture e decalcomanie", RemoveTexturesDesc="Nasconde texture e decalcomanie delle superfici",
		RemoveShadows="Disattiva ombre", RemoveShadowsDesc="Disattiva le ombre degli oggetti per ridurre il carico grafico",
		FxScaleTitle="Riduzione effetti (0% - 100%)", FxScaleDesc="0% = spenti; 50% = metà; 100% = normale",
		RenderDistTitle="Distanza nebbia", RenderDistDesc="Modifica solo la nebbia; non supera i limiti di rendering o Streaming",
		EngineQualityTitle="Qualità grafica (livello 1 - 21)", EngineQualityDesc="Il livello 1 è il più leggero; i livelli alti richiedono più risorse",
		LiteTerrain="Terrain leggero", LiteTerrainDesc="Riduce onde, riflessi e vegetazione decorativa",
		SkyTitle="Opzioni cielo", SkyDesc="Passa dal cielo Galaxy al cielo originale del gioco",
		SkyGalaxy="Cielo Galaxy", SkyDefault="Cielo originale del gioco",
		RestoredSuccess="Grafica originale ripristinata!", SavedSuccess="Impostazioni salvate!",
		AreaTitle="Controllo espansione mappa (client)", AreaDesc="Conta gli oggetti ricevuti; non può ampliare lo Streaming del server",
		ExpansionScriptStatus="Mappa ampliata da V6.5: NO — solo grafica/nebbia", ExpansionServerStatus="Streaming server: non leggibile/modificabile dal client", ExpansionHint="Verifica: Shift+F3, poi Shift+1 fino al pannello Streaming",
		AreaStatus="Oggetti entro 512 studs: %s | RAM: %s", MonitorOn="MONITOR: ATTIVO", MonitorOff="MONITOR: SPENTO", Scan="SCANSIONA ORA",
		On="ATTIVO", Off="SPENTO", WaitingCharacter="In attesa del personaggio...",
	},
	ja = {
		Title="VAMPIRE OPTIMIZER V7.7", Search="機能を検索...", Restore="元の画質に戻す", Save="設定を保存",
		FlatPlastic="フラット素材（プラスチック）", FlatPlasticDesc="表面をプラスチックに変更。Luckyブロックは除外",
		RemoveTextures="テクスチャとデカールを非表示", RemoveTexturesDesc="表面のテクスチャとデカールを非表示",
		RemoveShadows="影を無効化", RemoveShadowsDesc="オブジェクトの影を無効にして負荷を軽減",
		FxScaleTitle="エフェクト削減（0% - 100%）", FxScaleDesc="0% = オフ、50% = 半分、100% = 標準",
		RenderDistTitle="フォグ距離", RenderDistDesc="フォグのみ変更。Robloxの描画・ストリーミング制限は回避できません",
		EngineQualityTitle="画質（レベル1 - 21）", EngineQualityDesc="レベル1が最軽量。高いほど画質と負荷が増加します",
		LiteTerrain="地形を軽量化", LiteTerrainDesc="水の波、反射、装飾用の草を減らします",
		SkyTitle="空の設定", SkyDesc="Galaxyの空とゲーム本来の空を切り替えます",
		SkyGalaxy="Galaxyの空", SkyDefault="ゲーム本来の空",
		RestoredSuccess="元の画質に戻しました！", SavedSuccess="設定を保存しました！",
		AreaTitle="マップ拡張チェック（クライアント）", AreaDesc="受信済みオブジェクトを数えるだけで、サーバーのStreamingは拡張できません",
		ExpansionScriptStatus="V6.4によるマップ拡張：いいえ — 画質/霧のみ", ExpansionServerStatus="サーバーStreaming：クライアントから読み取り・変更不可", ExpansionHint="確認：Shift+F3、次にShift+1でStreamingパネルへ",
		AreaStatus="512 studs以内の物体：%s | RAM：%s", MonitorOn="監視：オン", MonitorOff="監視：オフ", Scan="今すぐスキャン",
		On="オン", Off="オフ", WaitingCharacter="キャラクターを待っています...",
	},
	ko = {
		Title="VAMPIRE OPTIMIZER V7.7", Search="기능 검색...", Restore="기본 그래픽 복원", Save="설정 저장",
		FlatPlastic="평면 재질(플라스틱)", FlatPlasticDesc="표면을 플라스틱으로 변경하고 Lucky 블록은 제외",
		RemoveTextures="텍스처 및 데칼 숨기기", RemoveTexturesDesc="표면 텍스처와 데칼 숨기기",
		RemoveShadows="그림자 끄기", RemoveShadowsDesc="그래픽 부하를 줄이기 위해 물체 그림자 끄기",
		FxScaleTitle="효과 감소 (0% - 100%)", FxScaleDesc="0% = 끔; 50% = 절반; 100% = 기본값",
		RenderDistTitle="안개 거리", RenderDistDesc="안개만 변경하며 Roblox 렌더링 또는 스트리밍 제한은 우회하지 못함",
		EngineQualityTitle="그래픽 품질 (레벨 1 - 21)", EngineQualityDesc="레벨 1이 가장 가벼우며 높은 레벨은 더 많은 자원을 사용",
		LiteTerrain="지형 간소화", LiteTerrainDesc="물결, 반사 및 장식용 잔디 감소",
		SkyTitle="하늘 옵션", SkyDesc="Galaxy 하늘과 게임 기본 하늘 전환",
		SkyGalaxy="Galaxy 하늘", SkyDefault="게임 기본 하늘",
		RestoredSuccess="기본 그래픽을 복원했습니다!", SavedSuccess="설정을 저장했습니다!",
		AreaTitle="맵 확장 확인 (클라이언트)", AreaDesc="받은 개체만 계산하며 서버 Streaming을 확장할 수 없습니다",
		ExpansionScriptStatus="V6.4의 맵 확장: 아니요 — 그래픽/안개만 변경", ExpansionServerStatus="서버 Streaming: 클라이언트에서 읽거나 변경할 수 없음", ExpansionHint="확인: Shift+F3, Shift+1을 눌러 Streaming 패널로 이동",
		AreaStatus="512 studs 내 물체: %s | RAM: %s", MonitorOn="모니터: 켬", MonitorOff="모니터: 끔", Scan="지금 스캔",
		On="켬", Off="끔", WaitingCharacter="캐릭터 대기 중...",
	},
	pl = {
		Title="VAMPIRE OPTIMIZER V7.7", Search="Szukaj funkcji...", Restore="Przywróć oryginalną grafikę", Save="Zapisz ustawienia",
		FlatPlastic="Płaskie materiały (plastik)", FlatPlasticDesc="Zmień powierzchnie na plastik; pomiń bloki Lucky",
		RemoveTextures="Ukryj tekstury i kalkomanie", RemoveTexturesDesc="Ukrywa tekstury i kalkomanie powierzchni",
		RemoveShadows="Wyłącz cienie", RemoveShadowsDesc="Wyłącza cienie obiektów, aby zmniejszyć obciążenie grafiki",
		FxScaleTitle="Redukcja efektów (0% - 100%)", FxScaleDesc="0% = wyłączone; 50% = połowa; 100% = normalnie",
		RenderDistTitle="Zasięg mgły", RenderDistDesc="Zmienia tylko mgłę; nie omija limitów renderowania ani Streaming Roblox",
		EngineQualityTitle="Jakość grafiki (poziom 1 - 21)", EngineQualityDesc="Poziom 1 jest najlżejszy; wyższe poziomy wymagają więcej zasobów",
		LiteTerrain="Lekki teren", LiteTerrainDesc="Ogranicza fale wody, odbicia i trawę dekoracyjną",
		SkyTitle="Opcje nieba", SkyDesc="Przełącz między niebem Galaxy a oryginalnym niebem gry",
		SkyGalaxy="Niebo Galaxy", SkyDefault="Oryginalne niebo gry",
		RestoredSuccess="Przywrócono oryginalną grafikę!", SavedSuccess="Zapisano ustawienia!",
		AreaTitle="Sprawdzenie rozszerzenia mapy (klient)", AreaDesc="Zlicza odebrane obiekty; nie rozszerza Streaming serwera",
		ExpansionScriptStatus="Mapa rozszerzona przez V6.4: NIE — tylko grafika/mgła", ExpansionServerStatus="Streaming serwera: klient nie może odczytać ani zmienić", ExpansionHint="Sprawdź: Shift+F3, potem Shift+1 do panelu Streaming",
		AreaStatus="Obiekty w promieniu 512 studs: %s | RAM: %s", MonitorOn="MONITOR: WŁ.", MonitorOff="MONITOR: WYŁ.", Scan="SKANUJ TERAZ",
		On="WŁ.", Off="WYŁ.", WaitingCharacter="Oczekiwanie na postać...",
	},
	pt = {
		Title="VAMPIRE OPTIMIZER V7.7", Search="Pesquisar recurso...", Restore="Restaurar gráficos originais", Save="Salvar configurações",
		FlatPlastic="Materiais planos (plástico)", FlatPlasticDesc="Transforma superfícies em plástico; ignora blocos Lucky",
		RemoveTextures="Ocultar texturas e decalques", RemoveTexturesDesc="Oculta texturas e decalques das superfícies",
		RemoveShadows="Desativar sombras", RemoveShadowsDesc="Desativa sombras dos objetos para reduzir a carga gráfica",
		FxScaleTitle="Redução de efeitos (0% - 100%)", FxScaleDesc="0% = desligado; 50% = metade; 100% = normal",
		RenderDistTitle="Distância da névoa", RenderDistDesc="Altera apenas a névoa; não ultrapassa limites de renderização ou Streaming",
		EngineQualityTitle="Qualidade gráfica (nível 1 - 21)", EngineQualityDesc="Nível 1 é o mais leve; níveis maiores exigem mais recursos",
		LiteTerrain="Terreno leve", LiteTerrainDesc="Reduz ondas, reflexos e grama decorativa",
		SkyTitle="Opções de céu", SkyDesc="Alterna entre o céu Galaxy e o céu original do jogo",
		SkyGalaxy="Céu Galaxy", SkyDefault="Céu original do jogo",
		RestoredSuccess="Gráficos originais restaurados!", SavedSuccess="Configurações salvas!",
		AreaTitle="Verificar expansão do mapa (cliente)", AreaDesc="Conta objetos recebidos; não amplia o Streaming do servidor",
		ExpansionScriptStatus="Mapa expandido pelo V6.4: NÃO — apenas gráficos/neblina", ExpansionServerStatus="Streaming do servidor: não pode ser lido ou alterado pelo cliente", ExpansionHint="Verifique: Shift+F3 e depois Shift+1 até o painel Streaming",
		AreaStatus="Objetos em 512 studs: %s | RAM: %s", MonitorOn="MONITOR: LIGADO", MonitorOff="MONITOR: DESLIGADO", Scan="ESCANEAR AGORA",
		On="LIGADO", Off="DESLIGADO", WaitingCharacter="Aguardando personagem...",
	},
	es = {
		Title="VAMPIRE OPTIMIZER V7.7", Search="Buscar función...", Restore="Restaurar gráficos originales", Save="Guardar ajustes",
		FlatPlastic="Materiales planos (plástico)", FlatPlasticDesc="Cambia las superficies a plástico; excluye bloques Lucky",
		RemoveTextures="Ocultar texturas y calcomanías", RemoveTexturesDesc="Oculta texturas y calcomanías de superficies",
		RemoveShadows="Desactivar sombras", RemoveShadowsDesc="Desactiva sombras de objetos para reducir la carga gráfica",
		FxScaleTitle="Reducción de efectos (0% - 100%)", FxScaleDesc="0% = apagado; 50% = mitad; 100% = normal",
		RenderDistTitle="Distancia de niebla", RenderDistDesc="Solo cambia la niebla; no supera los límites de renderizado o Streaming",
		EngineQualityTitle="Calidad gráfica (nivel 1 - 21)", EngineQualityDesc="El nivel 1 es el más ligero; los niveles altos consumen más recursos",
		LiteTerrain="Terreno ligero", LiteTerrainDesc="Reduce olas, reflejos y hierba decorativa",
		SkyTitle="Opciones de cielo", SkyDesc="Alterna entre el cielo Galaxy y el cielo original del juego",
		SkyGalaxy="Cielo Galaxy", SkyDefault="Cielo original del juego",
		RestoredSuccess="¡Gráficos originales restaurados!", SavedSuccess="¡Ajustes guardados!",
		AreaTitle="Comprobar expansión del mapa (cliente)", AreaDesc="Cuenta objetos recibidos; no puede ampliar el Streaming del servidor",
		ExpansionScriptStatus="Mapa ampliado por V6.5: NO — solo gráficos/niebla", ExpansionServerStatus="Streaming del servidor: el cliente no puede leerlo ni cambiarlo", ExpansionHint="Verifica: Shift+F3 y luego Shift+1 hasta el panel Streaming",
		AreaStatus="Objetos en 512 studs: %s | RAM: %s", MonitorOn="MONITOR: ACTIVADO", MonitorOff="MONITOR: DESACTIVADO", Scan="ESCANEAR AHORA",
		On="ACTIVADO", Off="DESACTIVADO", WaitingCharacter="Esperando al personaje...",
	},
	th = {
		Title="VAMPIRE OPTIMIZER V7.7", Search="ค้นหาฟีเจอร์...", Restore="คืนค่ากราฟิกเดิม", Save="บันทึกการตั้งค่า",
		FlatPlastic="วัสดุเรียบ (พลาสติก)", FlatPlasticDesc="เปลี่ยนพื้นผิวเป็นพลาสติก ยกเว้นบล็อก Lucky",
		RemoveTextures="ซ่อนพื้นผิวและ Decal", RemoveTexturesDesc="ซ่อนพื้นผิวและ Decal บนวัตถุ",
		RemoveShadows="ปิดเงา", RemoveShadowsDesc="ปิดเงาของวัตถุเพื่อลดภาระกราฟิก",
		FxScaleTitle="ลดเอฟเฟกต์ (0% - 100%)", FxScaleDesc="0% = ปิด; 50% = ครึ่งหนึ่ง; 100% = ปกติ",
		RenderDistTitle="ระยะหมอก", RenderDistDesc="ปรับเฉพาะหมอก ไม่สามารถข้ามขีดจำกัดการเรนเดอร์หรือ Streaming ของ Roblox",
		EngineQualityTitle="คุณภาพกราฟิก (Level 1 - 21)", EngineQualityDesc="Level 1 เบาที่สุด; ระดับสูงขึ้นใช้ทรัพยากรมากขึ้น",
		LiteTerrain="ลดรายละเอียดภูมิประเทศ", LiteTerrainDesc="ลดคลื่นน้ำ การสะท้อน และหญ้าตกแต่ง",
		SkyTitle="ตัวเลือกท้องฟ้า", SkyDesc="สลับระหว่างท้องฟ้า Galaxy และท้องฟ้าดั้งเดิมของเกม",
		SkyGalaxy="ท้องฟ้า Galaxy", SkyDefault="ท้องฟ้าดั้งเดิมของเกม",
		RestoredSuccess="คืนค่ากราฟิกเดิมแล้ว!", SavedSuccess="บันทึกการตั้งค่าแล้ว!",
		AreaTitle="ตรวจสอบการขยายแผนที่ (ไคลเอนต์)", AreaDesc="นับเฉพาะวัตถุที่ได้รับ ไม่สามารถขยาย Streaming ของเซิร์ฟเวอร์ได้",
		ExpansionScriptStatus="V6.4 ขยายแผนที่: ไม่ — ปรับเฉพาะภาพ/หมอก", ExpansionServerStatus="Streaming ของเซิร์ฟเวอร์: ไคลเอนต์อ่านหรือเปลี่ยนไม่ได้", ExpansionHint="ตรวจสอบ: Shift+F3 แล้วกด Shift+1 ไปยังแผง Streaming",
		AreaStatus="วัตถุในระยะ 512 studs: %s | RAM: %s", MonitorOn="ตรวจสอบ: เปิด", MonitorOff="ตรวจสอบ: ปิด", Scan="สแกนตอนนี้",
		On="เปิด", Off="ปิด", WaitingCharacter="กำลังรอตัวละคร...",
	},
	tr = {
		Title="VAMPIRE OPTIMIZER V7.7", Search="Özellik ara...", Restore="Orijinal grafikleri geri yükle", Save="Ayarları kaydet",
		FlatPlastic="Düz malzemeler (Plastik)", FlatPlasticDesc="Yüzeyleri plastiğe dönüştürür; Lucky bloklarını atlar",
		RemoveTextures="Dokuları ve çıkartmaları gizle", RemoveTexturesDesc="Yüzey dokularını ve çıkartmalarını gizler",
		RemoveShadows="Gölgeleri kapat", RemoveShadowsDesc="Grafik yükünü azaltmak için nesne gölgelerini kapatır",
		FxScaleTitle="Efekt azaltma (%0 - %100)", FxScaleDesc="%0 = kapalı; %50 = yarı; %100 = normal",
		RenderDistTitle="Sis mesafesi", RenderDistDesc="Yalnızca sisi değiştirir; Roblox çizim veya Streaming sınırlarını aşmaz",
		EngineQualityTitle="Grafik kalitesi (Seviye 1 - 21)", EngineQualityDesc="Seviye 1 en hafifidir; yüksek seviyeler daha fazla kaynak kullanır",
		LiteTerrain="Hafif arazi", LiteTerrainDesc="Su dalgalarını, yansımaları ve dekoratif çimleri azaltır",
		SkyTitle="Gökyüzü seçenekleri", SkyDesc="Galaxy gökyüzü ile oyunun orijinal gökyüzü arasında geçiş yapar",
		SkyGalaxy="Galaxy gökyüzü", SkyDefault="Oyunun varsayılan gökyüzü",
		RestoredSuccess="Orijinal grafikler geri yüklendi!", SavedSuccess="Ayarlar kaydedildi!",
		AreaTitle="Harita genişletme kontrolü (istemci)", AreaDesc="Alınan nesneleri sayar; sunucu Streaming alanını genişletemez",
		ExpansionScriptStatus="V6.4 haritayı genişletti: HAYIR — yalnızca grafik/sis", ExpansionServerStatus="Sunucu Streaming: istemciden okunamaz veya değiştirilemez", ExpansionHint="Kontrol: Shift+F3, ardından Streaming paneline gelene kadar Shift+1",
		AreaStatus="512 stud içindeki nesneler: %s | RAM: %s", MonitorOn="İZLEME: AÇIK", MonitorOff="İZLEME: KAPALI", Scan="ŞİMDİ TARA",
		On="AÇIK", Off="KAPALI", WaitingCharacter="Karakter bekleniyor...",
	},
}

-- Bổ sung bản dịch cho các thẻ mới V6.4 để menu tiếp tục theo ngôn ngữ Roblox.
local FeatureTranslations = {
	ar = { HairFlatTitle="شعر بلون موحد", HairFlatDesc="إزالة خامات ملحقات الشعر مع الاحتفاظ باللون الأصلي؛ قابل للاستعادة", AutoSaveTitle="حفظ الإعدادات تلقائياً", AutoSaveDesc="يحفظ بعد التغييرات ويتطلب دعم كتابة الملفات", JoinPlayerTitle="الانضمام إلى خادم لاعب", JoinPlayerDesc="لا يستطيع العميل معرفة JobId للاعب في تجربة شخص آخر؛ استخدم خيار الانضمام الرسمي عند السماح", JoinPlayerStatus="يتطلب صلاحية الخادم — الانضمام التلقائي غير متاح هنا" },
	zhCN = { HairFlatTitle="头发纯色化", HairFlatDesc="移除头发配件纹理并保留原色；可恢复", AutoSaveTitle="自动保存设置", AutoSaveDesc="更改后自动保存，需要执行环境支持写文件", JoinPlayerTitle="加入玩家所在服务器", JoinPlayerDesc="在他人的游戏中，客户端无法查询其他玩家的 JobId；允许时请使用 Roblox 官方加入选项", JoinPlayerStatus="需要服务器权限 — 当前客户端版本不支持自动加入" },
	zhTW = { HairFlatTitle="頭髮純色化", HairFlatDesc="移除頭髮配件貼圖並保留原色；可還原", AutoSaveTitle="自動儲存設定", AutoSaveDesc="變更後自動儲存，需要執行環境支援寫入檔案", JoinPlayerTitle="加入玩家所在伺服器", JoinPlayerDesc="在他人的遊戲中，用戶端無法查詢其他玩家的 JobId；允許時請使用 Roblox 官方加入選項", JoinPlayerStatus="需要伺服器權限 — 目前用戶端版本不支援自動加入" },
	fr = { HairFlatTitle="Cheveux en couleur unie", HairFlatDesc="Retire les textures des accessoires de cheveux en gardant leur couleur d’origine ; réversible", AutoSaveTitle="Enregistrement automatique", AutoSaveDesc="Enregistre après chaque modification ; nécessite l’accès d’écriture aux fichiers", JoinPlayerTitle="Rejoindre le serveur d’un joueur", JoinPlayerDesc="Un client dans l’expérience d’un autre ne peut pas récupérer le JobId ; utilisez l’option officielle Rejoindre si elle est autorisée", JoinPlayerStatus="Autorisation serveur requise — auto-connexion indisponible ici" },
	de = { HairFlatTitle="Haare einfarbig darstellen", HairFlatDesc="Entfernt Haar-Texturen und behält die Originalfarbe; wiederherstellbar", AutoSaveTitle="Einstellungen automatisch speichern", AutoSaveDesc="Speichert Änderungen automatisch; Dateischreibzugriff erforderlich", JoinPlayerTitle="Dem Server eines Spielers beitreten", JoinPlayerDesc="Ein Client in einem fremden Spiel kann die JobId nicht abrufen; nutze bei Freigabe die offizielle Roblox-Beitreten-Option", JoinPlayerStatus="Serverberechtigung erforderlich — automatischer Beitritt hier nicht verfügbar" },
	hi = { HairFlatTitle="बालों को एक रंग में दिखाएँ", HairFlatDesc="बालों के एक्सेसरी टेक्सचर हटाता है और मूल रंग रखता है; वापस किया जा सकता है", AutoSaveTitle="सेटिंग अपने आप सहेजें", AutoSaveDesc="बदलाव के बाद सहेजता है; फ़ाइल लिखने की सुविधा आवश्यक है", JoinPlayerTitle="खिलाड़ी के सर्वर में शामिल हों", JoinPlayerDesc="दूसरे के गेम में क्लाइंट किसी अन्य खिलाड़ी का JobId नहीं पा सकता; अनुमति होने पर Roblox का आधिकारिक Join विकल्प उपयोग करें", JoinPlayerStatus="सर्वर अनुमति आवश्यक — यहाँ ऑटो-जॉइन उपलब्ध नहीं" },
	id = { HairFlatTitle="Rambut warna polos", HairFlatDesc="Menghapus tekstur aksesori rambut sambil mempertahankan warna asli; bisa dipulihkan", AutoSaveTitle="Simpan pengaturan otomatis", AutoSaveDesc="Menyimpan setelah perubahan; perlu dukungan penulisan file", JoinPlayerTitle="Gabung ke server pemain", JoinPlayerDesc="Client di game milik orang lain tidak dapat mengambil JobId pemain lain; gunakan tombol Join resmi Roblox bila diizinkan", JoinPlayerStatus="Perlu izin server — gabung otomatis tidak tersedia di sini" },
	it = { HairFlatTitle="Capelli a tinta unita", HairFlatDesc="Rimuove le texture degli accessori capelli mantenendo il colore originale; reversibile", AutoSaveTitle="Salvataggio automatico", AutoSaveDesc="Salva dopo le modifiche; richiede il supporto alla scrittura dei file", JoinPlayerTitle="Entra nel server di un giocatore", JoinPlayerDesc="Un client nel gioco di altri non può recuperare il JobId; usa l’opzione ufficiale Join di Roblox se consentita", JoinPlayerStatus="Richiede permessi del server — accesso automatico non disponibile" },
	ja = { HairFlatTitle="髪を単色にする", HairFlatDesc="髪アクセサリーのテクスチャを外し、元の色を維持します。元に戻せます", AutoSaveTitle="設定を自動保存", AutoSaveDesc="変更後に自動保存します。ファイル書き込み機能が必要です", JoinPlayerTitle="プレイヤーのサーバーに参加", JoinPlayerDesc="他の人のゲーム内クライアントから相手のJobIdは取得できません。許可されている場合はRoblox公式の参加機能を使ってください", JoinPlayerStatus="サーバー権限が必要 — このクライアント版では自動参加できません" },
	ko = { HairFlatTitle="머리카락 단색으로 표시", HairFlatDesc="헤어 액세서리 텍스처를 제거하고 원래 색상을 유지합니다. 복원 가능", AutoSaveTitle="설정 자동 저장", AutoSaveDesc="변경 후 자동 저장합니다. 파일 쓰기 지원이 필요합니다", JoinPlayerTitle="플레이어 서버 참가", JoinPlayerDesc="다른 사람의 게임에서 클라이언트는 다른 플레이어의 JobId를 조회할 수 없습니다. 허용되면 Roblox 공식 참가 기능을 사용하세요", JoinPlayerStatus="서버 권한 필요 — 이 클라이언트 버전에서는 자동 참가 불가" },
	pl = { HairFlatTitle="Włosy w jednolitym kolorze", HairFlatDesc="Usuwa tekstury akcesoriów włosów, zachowując ich oryginalny kolor; można przywrócić", AutoSaveTitle="Automatyczny zapis ustawień", AutoSaveDesc="Zapisuje po zmianach; wymaga obsługi zapisu plików", JoinPlayerTitle="Dołącz do serwera gracza", JoinPlayerDesc="Klient w cudzej grze nie może odczytać JobId innego gracza; użyj oficjalnej opcji Dołącz, jeśli jest dostępna", JoinPlayerStatus="Wymagane uprawnienia serwera — automatyczne dołączanie niedostępne" },
	pt = { HairFlatTitle="Cabelo em cor sólida", HairFlatDesc="Remove texturas dos acessórios de cabelo e mantém a cor original; reversível", AutoSaveTitle="Salvar configurações automaticamente", AutoSaveDesc="Salva após alterações; requer suporte para gravar arquivos", JoinPlayerTitle="Entrar no servidor de um jogador", JoinPlayerDesc="Um cliente no jogo de outra pessoa não pode obter o JobId; use a opção oficial Entrar do Roblox quando permitida", JoinPlayerStatus="Permissão do servidor necessária — entrada automática indisponível" },
	es = { HairFlatTitle="Cabello de color uniforme", HairFlatDesc="Quita las texturas de los accesorios de cabello y conserva el color original; reversible", AutoSaveTitle="Guardar ajustes automáticamente", AutoSaveDesc="Guarda después de los cambios; requiere permiso para escribir archivos", JoinPlayerTitle="Unirse al servidor de un jugador", JoinPlayerDesc="Un cliente dentro del juego de otra persona no puede obtener el JobId; usa la opción oficial Unirse de Roblox si está permitida", JoinPlayerStatus="Se requiere permiso del servidor — unión automática no disponible" },
	th = { HairFlatTitle="ทำผมให้เป็นสีพื้น", HairFlatDesc="ลบพื้นผิวของเครื่องประดับผมและคงสีเดิมไว้ สามารถคืนค่าได้", AutoSaveTitle="บันทึกการตั้งค่าอัตโนมัติ", AutoSaveDesc="บันทึกหลังเปลี่ยนค่า ต้องรองรับการเขียนไฟล์", JoinPlayerTitle="เข้าร่วมเซิร์ฟเวอร์ของผู้เล่น", JoinPlayerDesc="ไคลเอนต์ในเกมของผู้อื่นไม่สามารถอ่าน JobId ของผู้เล่นอื่นได้ ให้ใช้ปุ่ม Join อย่างเป็นทางการของ Roblox เมื่อได้รับอนุญาต", JoinPlayerStatus="ต้องใช้สิทธิ์เซิร์ฟเวอร์ — รุ่นไคลเอนต์นี้เข้าร่วมอัตโนมัติไม่ได้" },
	tr = { HairFlatTitle="Saçı düz renge dönüştür", HairFlatDesc="Saç aksesuarı dokularını kaldırır ve özgün rengi korur; geri alınabilir", AutoSaveTitle="Ayarları otomatik kaydet", AutoSaveDesc="Değişikliklerden sonra kaydeder; dosya yazma desteği gerekir", JoinPlayerTitle="Oyuncunun sunucusuna katıl", JoinPlayerDesc="Başkasının oyunundaki istemci diğer oyuncunun JobId bilgisini alamaz; izin varsa Roblox'un resmi Katıl seçeneğini kullan", JoinPlayerStatus="Sunucu izni gerekli — otomatik katılma bu sürümde yok" },
}
for locale, entries in pairs(FeatureTranslations) do
	if Lang[locale] then
		for key, value in pairs(entries) do Lang[locale][key] = value end
	end
end

-- Nếu tài khoản dùng ngôn ngữ chưa có bản dịch trong script, thử ngôn ngữ CoreGui rồi mới về English.
if not Lang[currentLocale] then
	local coreLocale = string.lower((LocalizationService.RobloxLocaleId or "en-us"):gsub("_", "-"))
	local coreBase = coreLocale:match("^([a-z]+)") or "en"
	if coreBase == "zh" then
		currentLocale = (coreLocale:find("zh%-tw") or coreLocale:find("zh%-hk") or coreLocale:find("zh%-mo")) and "zhTW" or "zhCN"
	else
		currentLocale = coreBase
	end
end
if not Lang[currentLocale] then currentLocale = "en" end

local function T(k)
	return (Lang[currentLocale] and Lang[currentLocale][k]) or Lang.en[k] or k
end

-- ==================== BỘ LƯU TRỮ KHÔI PHỤC CHÍNH XÁC ====================
local Backup = {
	Lighting = {
		GlobalShadows = Lighting.GlobalShadows,
		FogStart = Lighting.FogStart,
		FogEnd = Lighting.FogEnd,
		FogColor = Lighting.FogColor,
		EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
	},
	InitialEngineQuality = Enum.QualityLevel.Automatic,
	OriginalMaterials = {},
	OriginalTile = {},
	OriginalTextures = {},
	OriginalShadows = {},
	OriginalFx = {},
	OriginalHairParts = {},
	OriginalHairMeshes = {},
	OriginalHairSurface = {},
	OriginalSkies = {},
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

-- Persistent executor environment. It preserves settings between reinjections even when file APIs are unavailable.
local PersistentEnv = shared
pcall(function()
	if type(getgenv) == "function" then
		local env = getgenv()
		if type(env) == "table" then PersistentEnv = env end
	end
end)

-- ==================== QUẢN LÝ CẤU HÌNH LƯU TRỮ ====================
local CONFIG_FILE = "VampireOptimizer_v7_3.json"
local LEGACY_CONFIG_FILES = { "VampireOptimizer_v7_2.json", "VampireOptimizer_v7_1.json", "VampireOptimizer_v7_0.json", "VampireOptimizer_v6_9.json", "VampireOptimizer_v6_8.json", "VampireOptimizer_v6_7.json", "VampireOptimizer_v6_6.json", "VampireOptimizer_v6_5.json", "VampireOptimizer_v6_4.json", "VampireOptimizer_v6_3.json", "VampireOptimizer_v6_2.json" }
local Config = {
	FlatPlastic = false,
	RemoveTextures = false,
	RemoveShadows = false,
	FxScale = 100,
	RenderDistance = 100000,
	EngineQuality = 1,
	LiteTerrain = false,
	SkyMode = "Default",
	LiveMonitor = true,
	LiveMonitorSet = false, -- true only after the user pressed the MONITOR button
	FlatHair = true,
	HairSolid = true,
	TeleportPersist = true,
	KeepFarView = true,
	AutoSave = true,
	ReloadUrl = "",
}

local function MergeConfigTable(data)
	if type(data) ~= "table" then return end
	for k, v in pairs(data) do Config[k] = v end
end

local function StoreConfigInMemory()
	local snapshot = {}
	for k, v in pairs(Config) do snapshot[k] = v end
	pcall(function() PersistentEnv.VampireOptimizerConfig = snapshot end)
	pcall(function() shared.VampireOptimizerConfig = snapshot end)
end

local function LoadConfig()
	-- Memory fallback first; file data, when available, is the durable source of truth.
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
		writefile(CONFIG_FILE, HttpService:JSONEncode(Config))
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

-- Chuẩn hóa dữ liệu config cũ/hỏng trước khi dùng cho các thanh trượt.
Config.FxScale = math.clamp(math.floor(tonumber(Config.FxScale) or 100), 0, 100)
Config.RenderDistance = math.clamp(math.floor(tonumber(Config.RenderDistance) or 100000), 200, 100000)
if tostring(Config.EngineQuality):upper() == "AUTO" then
	Config.EngineQuality = "AUTO"
else
	Config.EngineQuality = math.clamp(math.floor(tonumber(Config.EngineQuality) or 1), 1, 21)
end
Config.FlatPlastic = Config.FlatPlastic == true
Config.RemoveTextures = Config.RemoveTextures == true
Config.RemoveShadows = Config.RemoveShadows == true
Config.LiteTerrain = Config.LiteTerrain == true
Config.LiveMonitorSet = Config.LiveMonitorSet == true
-- V7.7: mặc định BẬT; chỉ khi bạn tự bấm nút MONITOR thì lựa chọn (BẬT/TẮT) mới được nhớ qua các lần chạy lại/teleport.
if Config.LiveMonitorSet then Config.LiveMonitor = Config.LiveMonitor == true else Config.LiveMonitor = true end
Config.FlatHair = true -- V7.3 starts with solid-colour SmoothPlastic hair enabled.
Config.HairSolid = Config.HairSolid ~= false
Config.TeleportPersist = Config.TeleportPersist ~= false
Config.KeepFarView = Config.KeepFarView ~= false
Config.ReloadUrl = (type(Config.ReloadUrl) == "string") and Config.ReloadUrl or ""
if Config.AutoSave == nil then Config.AutoSave = true else Config.AutoSave = Config.AutoSave == true end
Config.SkyMode = (Config.SkyMode == "Galaxy") and "Galaxy" or "Default"

-- ==================== CÁC HÀM XỬ LÝ ĐỒ HỌA ====================

local function isLucky(obj)
	local cur = obj
	while cur and cur ~= workspace do
		if string.find(string.lower(cur.Name), "lucky") then return true end
		cur = cur.Parent
	end
	return false
end

-- 1. Làm phẳng vật liệu (Nhựa)
local function SetFlatPlastic(enable)
	Config.FlatPlastic = enable
	if enable then
		for _, v in ipairs(MaterialService:GetDescendants()) do
			if v:IsA("MaterialVariant") and not isLucky(v) then
				if Backup.OriginalTile[v] == nil then Backup.OriginalTile[v] = v.StudsPerTile end
				pcall(function() v.StudsPerTile = 100000 end)
			end
		end
		for _, v in ipairs(workspace:GetDescendants()) do
			if v:IsA("BasePart") and not isLucky(v) and v.MaterialVariant == "" then
				if Backup.OriginalMaterials[v] == nil then Backup.OriginalMaterials[v] = v.Material end
				v.Material = Enum.Material.SmoothPlastic
			end
		end
	else
		for part, mat in pairs(Backup.OriginalMaterials) do
			if part and part.Parent then part.Material = mat end
		end
		for variant, tile in pairs(Backup.OriginalTile) do
			if variant and variant.Parent then variant.StudsPerTile = tile end
		end
	end
	QueueAutoSave()
end

-- 2. Xóa Texture & Decals
local function SetRemoveTextures(enable)
	Config.RemoveTextures = enable
	for _, v in ipairs(workspace:GetDescendants()) do
		if v:IsA("Texture") or v:IsA("Decal") then
			if enable then
				if Backup.OriginalTextures[v] == nil then Backup.OriginalTextures[v] = v.Transparency end
				v.Transparency = 1
			else
				local old = Backup.OriginalTextures[v]
				if old ~= nil and v and v.Parent then v.Transparency = old end
			end
		end
	end
	QueueAutoSave()
end

-- 3. Xóa bóng đổ
local function SetRemoveShadows(enable)
	Config.RemoveShadows = enable
	Lighting.GlobalShadows = enable and false or Backup.Lighting.GlobalShadows
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
	QueueAutoSave()
end

-- 4. Thanh trượt giảm hiệu ứng (0% - 100%)
local function ApplyFxScale(pct)
	pct = math.clamp(pct, 0, 100)
	Config.FxScale = pct
	local f = pct / 100

	for _, v in ipairs(workspace:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			if Backup.OriginalFx[v] == nil then
				Backup.OriginalFx[v] = { Enabled = v.Enabled, Rate = v.Rate, Size = v.Size }
			end
			if pct == 0 then
				v.Enabled = false
			else
				v.Enabled = Backup.OriginalFx[v].Enabled
				v.Rate = Backup.OriginalFx[v].Rate * f
				v.Size = Backup.OriginalFx[v].Size
			end
		elseif v:IsA("Fire") or v:IsA("Smoke") then
			if Backup.OriginalFx[v] == nil then
				Backup.OriginalFx[v] = { Enabled = v.Enabled, Size = v.Size }
			end
			if pct == 0 then
				v.Enabled = false
			else
				v.Enabled = Backup.OriginalFx[v].Enabled
				v.Size = (pct == 100) and Backup.OriginalFx[v].Size or math.max(0.01, Backup.OriginalFx[v].Size * f)
			end
		elseif v:IsA("Light") then
			if Backup.OriginalFx[v] == nil then
				Backup.OriginalFx[v] = { Enabled = v.Enabled, Brightness = v.Brightness }
			end
			if pct == 0 then
				v.Enabled = false
			else
				v.Enabled = Backup.OriginalFx[v].Enabled
				v.Brightness = (pct == 100) and Backup.OriginalFx[v].Brightness or math.max(0, Backup.OriginalFx[v].Brightness * f)
			end
		elseif v:IsA("Beam") or v:IsA("Trail") then
			if Backup.OriginalFx[v] == nil then Backup.OriginalFx[v] = { Enabled = v.Enabled } end
			v.Enabled = (pct > 0) and Backup.OriginalFx[v].Enabled
		end
	end
	QueueAutoSave()
end

-- 5. Giới hạn khoảng cách Render (Render Distance Limiter)
local function SetRenderDistance(dist)
	-- Đây là khoảng sương mù của Lighting, KHÔNG phải khoảng cách tải/render của engine.
	dist = math.clamp(math.floor(tonumber(dist) or 100000), 200, 100000)
	Config.RenderDistance = dist

	Lighting.FogStart = dist
	Lighting.FogEnd = dist + math.max(1000, math.floor(dist * 0.1))
	Lighting.FogColor = Backup.Lighting.FogColor
	QueueAutoSave()
end

-- 6. Cấp độ đồ họa. Giống FFlag DFIntDebugFRMQualityLevelOverride:
--    flag = độ đẹp/nặng của hình ảnh (FRM); khi flag bật, QualityLevel của Roblox chỉ còn quyết định TẦM NHÌN.
--    Nên chọn Level 1 = hình ảnh Level 1 + QualityLevel của Roblox ở 21 (tầm nhìn tối đa). Cần executor có setfflag.
--    Nếu executor không có/không nhận setfflag thì quay về cách cũ: QualityLevel = level đã chọn (tầm nhìn ngắn theo level đó).
local FrmFlag = { Name = "DFIntDebugFRMQualityLevelOverride", Original = nil, Applied = false, Current = nil, Warned = false }

function FrmFlag.Setter()
	local fn
	pcall(function() if type(setfflag) == "function" then fn = setfflag end end)
	if not fn then pcall(function() if type(set_fflag) == "function" then fn = set_fflag end end) end
	if not fn then pcall(function() if type(syn) == "table" and type(syn.setfflag) == "function" then fn = syn.setfflag end end) end
	if not fn then
		pcall(function()
			if type(getgenv) == "function" then
				local env = getgenv()
				if type(env) == "table" and type(env.setfflag) == "function" then fn = env.setfflag end
			end
		end)
	end
	return fn
end

function FrmFlag.Getter()
	local fn
	pcall(function() if type(getfflag) == "function" then fn = getfflag end end)
	if not fn then pcall(function() if type(get_fflag) == "function" then fn = get_fflag end end) end
	if not fn then pcall(function() if type(syn) == "table" and type(syn.getfflag) == "function" then fn = syn.getfflag end end) end
	return fn
end

function FrmFlag.Read()
	local getter = FrmFlag.Getter()
	if not getter then return nil end
	local ok, value = pcall(getter, FrmFlag.Name)
	if ok and value ~= nil and tostring(value) ~= "" then return tostring(value) end
	return nil
end

-- Returns true when the flag now holds `level`; false + reason otherwise.
function FrmFlag.Set(level)
	if FrmFlag.Applied and FrmFlag.Current == level then return true end
	local setter = FrmFlag.Setter()
	if not setter then return false, "executor has no setfflag" end
	if FrmFlag.Original == nil then
		pcall(function() FrmFlag.Original = PersistentEnv.VampireOptimizerFrmOriginal end)
		if FrmFlag.Original == nil then
			FrmFlag.Original = FrmFlag.Read() or "0"
			pcall(function() PersistentEnv.VampireOptimizerFrmOriginal = FrmFlag.Original end)
		end
	end
	local ok, err = pcall(setter, FrmFlag.Name, tostring(level))
	if not ok then return false, tostring(err) end
	local now = FrmFlag.Read()
	if now ~= nil and now ~= tostring(level) then return false, "executor ignored the value (reads back " .. now .. ")" end
	FrmFlag.Applied = true
	FrmFlag.Current = level
	return true
end

function FrmFlag.Restore()
	if not FrmFlag.Applied then return end
	local original = FrmFlag.Original or "0"
	FrmFlag.Applied = false
	FrmFlag.Current = nil
	FrmFlag.Original = nil
	local setter = FrmFlag.Setter()
	if setter then pcall(setter, FrmFlag.Name, tostring(original)) end
	pcall(function() PersistentEnv.VampireOptimizerFrmOriginal = nil end)
end

local function SetEngineQualityLevel(lvl)
	if tostring(lvl):upper() == "AUTO" then
		Config.EngineQuality = "AUTO"
		FrmFlag.Restore()
		pcall(function()
			settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
		end)
		Lighting.EnvironmentDiffuseScale = Backup.Lighting.EnvironmentDiffuseScale
		Lighting.EnvironmentSpecularScale = Backup.Lighting.EnvironmentSpecularScale
		QueueAutoSave()
		return
	end

	lvl = math.clamp(math.floor(tonumber(lvl) or 1), 1, 21)
	Config.EngineQuality = lvl

	local farView = false
	if Config.KeepFarView ~= false and lvl < 21 then
		local applied, why = FrmFlag.Set(lvl)
		farView = applied == true
		if not farView and not FrmFlag.Warned then
			FrmFlag.Warned = true
			warn("[Vampire Optimizer] " .. FrmFlag.Name .. " not applied (" .. tostring(why) .. "): view distance follows the chosen level")
		end
	else
		FrmFlag.Restore() -- level 21 already has full view distance; KeepFarView off = plain engine level
	end

	pcall(function()
		local engineLevel = farView and 21 or lvl -- with the flag on this slider is the render distance
		settings().Rendering.QualityLevel = Enum.QualityLevel[string.format("Level%02d", engineLevel)]
	end)

	-- Tối ưu thêm ánh sáng môi trường PBR
	if lvl <= 5 then
		Lighting.EnvironmentDiffuseScale = 0
		Lighting.EnvironmentSpecularScale = 0
	else
		Lighting.EnvironmentDiffuseScale = Backup.Lighting.EnvironmentDiffuseScale
		Lighting.EnvironmentSpecularScale = Backup.Lighting.EnvironmentSpecularScale
	end
	QueueAutoSave()
end

-- 7. Tối ưu địa hình
local function SetLiteTerrain(enable)
	Config.LiteTerrain = enable
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if not terrain then QueueAutoSave(); return end
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
	QueueAutoSave()
end

-- 8. TÓC SMOOTHPLASTIC, GIỮ NGUYÊN TOÀN BỘ MÀU/TEXTURE GỐC (CHỈ HIỂN THỊ TRÊN CLIENT)
-- Không gán một màu cố định, không xóa TextureID, SurfaceAppearance, Texture hoặc Decal.
-- Nhờ vậy tóc đen/vàng/đỏ/xanh/nhiều màu vẫn giữ hình thức màu gốc của từng người.
local function IsHairAccessory(accessory)
    if not accessory or not accessory:IsA("Accessory") then return false end
    local isHair = false
    pcall(function() isHair = accessory.AccessoryType == Enum.AccessoryType.Hair end)
    if isHair then return true end
    local lowerName = string.lower(accessory.Name)
    return string.find(lowerName, "hair", 1, true) ~= nil
        or string.find(lowerName, "bang", 1, true) ~= nil
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
            if owningPlayer and IsHairAccessory(current) then
                return current
            end
            return nil
        end
        current = current.Parent
    end
    return nil
end

-- ---------- V7.3 solid-colour plastic hair ----------
-- Pipeline per hair part:
--   1. immediately: SmoothPlastic, no reflectance, no PBR maps (normal / metalness / roughness)
--   2. asynchronously: find ONE colour (texture average x tint) and, if found, strip the texture so the hair is a single flat plastic colour
--   3. colour unknown: keep the texture (never invent a colour) and report the part as "flattened only"
Backup.OriginalHairDecals = Backup.OriginalHairDecals or {}
local HairPartState = {}     -- [part] = "pending" | "solid" | "flat"
local HairColorCache = {}    -- [textureId] = Color3 (successful samples only)
local HairColorInflight = {} -- [textureId] = true while downloading/reading

local HAIR_PLACEHOLDER_COLORS = { Color3.fromRGB(163, 162, 165), Color3.fromRGB(255, 255, 255) }
local function IsPlaceholderHairColor(color)
    for _, placeholder in ipairs(HAIR_PLACEHOLDER_COLORS) do
        if math.abs(color.R - placeholder.R) + math.abs(color.G - placeholder.G) + math.abs(color.B - placeholder.B) < 0.06 then
            return true
        end
    end
    return false
end

local function MultiplyColors(a, b)
    return Color3.new(a.R * b.R, a.G * b.G, a.B * b.B)
end

-- Average colour of a texture via EditableImage. Returns nil when the executor/experience does not allow it.
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
        if okContent then
            content = built
        elseif assetId then
            content = Content.fromAssetId(assetId)
        end
        if not content then return end

        local image = game:GetService("AssetService"):CreateEditableImageAsync(content)
        if not image then return end

        local width, height = 1, 1
        pcall(function()
            local size = image.Size
            width, height = math.max(1, math.floor(size.X)), math.max(1, math.floor(size.Y))
        end)
        if width * height > 1024 then
            -- Down-scaling first averages the pixels for us and keeps the read cheap.
            local resized = pcall(function() image:Resize(Vector2.new(32, 32)) end)
            if resized then width, height = 32, 32 end
        end

        local step = math.max(1, math.floor(math.sqrt(width * height / 2048)))
        local r, g, b, weight = 0, 0, 0, 0
        local okBuffer, pixelBuffer = pcall(function()
            return image:ReadPixelsBuffer(Vector2.new(0, 0), Vector2.new(width, height))
        end)
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
            local okTable, pixels = pcall(function()
                return image:ReadPixels(Vector2.new(0, 0), Vector2.new(width, height))
            end)
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

-- Everything on a part that can carry the hair's visible texture.
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
            pcall(function()
                if not IsPlaceholderHairColor(child.Color) then info.surfaceTint = child.Color end
            end)
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

-- Step 1 (instant): plastic look + strip PBR detail. Texture colour is still untouched here.
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

-- Step 2: swap the textured look for ONE flat colour.
local function StripHairTextures(part, info, finalColor)
    if part:IsA("MeshPart") then
        pcall(function() part.TextureID = "" end)
    end
    for _, mesh in ipairs(info.meshes) do
        if Backup.OriginalHairMeshes[mesh] == nil then
            local original = { TextureId = "" }
            pcall(function() original.TextureId = mesh.TextureId end)
            Backup.OriginalHairMeshes[mesh] = original
        end
        pcall(function() mesh.TextureId = "" end)
    end
    for _, surface in ipairs(info.surfaces) do
        pcall(function() surface.Parent = nil end) -- kept alive in Backup so it can be put back
    end
    for _, decal in ipairs(info.decals) do
        if Backup.OriginalHairDecals[decal] == nil then
            Backup.OriginalHairDecals[decal] = decal.Transparency
        end
        pcall(function() decal.Transparency = 1 end)
    end
    pcall(function() part.Color = finalColor end)
end

local function ApplyFlatHairPart(part)
    if not Config.FlatHair or not part or not part:IsA("BasePart") then return end
    if HairPartState[part] then return end
    HairPartState[part] = "pending"

    if Backup.OriginalHairParts[part] == nil then
        local original = {
            Color = part.Color,
            Material = part.Material,
            Reflectance = part.Reflectance,
            MaterialVariant = "",
            TextureID = nil,
        }
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
            finalColor = tint -- no readable texture, but the part itself carries the hair colour
        end

        if finalColor then
            StripHairTextures(part, info, finalColor)
            HairPartState[part] = "solid"
        else
            HairPartState[part] = "flat" -- colour unknown: keep the texture rather than invent a colour
        end
    end)
end

local function ApplyFlatHairAccessory(accessory)
    if not Config.FlatHair or not IsHairAccessory(accessory) or not accessory.Parent then return end
    for _, descendant in ipairs(accessory:GetDescendants()) do
        if descendant:IsA("BasePart") then
            ApplyFlatHairPart(descendant)
        end
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
        if IsHairAccessory(obj) then
            ApplyFlatHairAccessory(obj)
        end
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
        if mesh and mesh.Parent then
            pcall(function() mesh.TextureId = original.TextureId end)
        end
    end
    for surface, original in pairs(Backup.OriginalHairSurface) do
        pcall(function()
            if surface.Parent == nil and original.Parent and original.Parent.Parent then
                surface.Parent = original.Parent
            end
            surface.NormalMap = original.NormalMap
            surface.MetalnessMap = original.MetalnessMap
            surface.RoughnessMap = original.RoughnessMap
        end)
    end
    for decal, transparency in pairs(Backup.OriginalHairDecals) do
        if decal and decal.Parent then
            pcall(function() decal.Transparency = transparency end)
        end
    end
    Backup.OriginalHairParts = {}
    Backup.OriginalHairMeshes = {}
    Backup.OriginalHairSurface = {}
    Backup.OriginalHairDecals = {}
    HairPartState = {}
end

-- Retry parts that ended up "flat" or never finished; solid parts are left alone (their texture is already gone).
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
    if Config.FlatHair then
        ApplyFlatHairToAllPlayers()
    else
        RestoreHairAppearance()
    end
    QueueAutoSave()
end

-- Tự áp dụng cho nhân vật hiện tại, người mới vào, respawn và tóc được thêm/stream sau.
local function HookPlayerHair(player)
    local function onCharacter(character)
        task.defer(function()
            if IsRunning and Config.FlatHair and character and character.Parent then
                ApplyFlatHairToCharacter(character)
            end
        end)
    end
    if player.Character then onCharacter(player.Character) end
    Connect(player.CharacterAdded, onCharacter)
end
for _, player in ipairs(Players:GetPlayers()) do HookPlayerHair(player) end
Connect(Players.PlayerAdded, HookPlayerHair)

-- 9. Quản lý Bầu Trời (Galaxy Vũ Trụ & Sky Gốc)  -- V7.5
-- Dành cho sảnh có code bầu trời riêng (ví dụ SkyboxController):
--   * giữ nguyên texture Galaxy nếu game cố ghi đè lên Sky của mình;
--   * cất Sky/Atmosphere/Clouds mới của game (Lighting + Terrain), dựng lại Galaxy nếu bị xóa;
--   * ẩn các part KHỔNG LỒ hình khối (mái vòm) có tên chứa sky/dome/galaxy/cosmos — hoàn nguyên khi về Sky gốc;
--   * in báo cáo ngắn ra console để biết script đã cất/ẩn những gì.
local customSkyInst = nil
local ApplySkyMode -- gán bên dưới
local BuildSkyReport -- gán bên dưới (nút COPY SKY REPORT dùng)
do
	local SkyBackups = {}      -- { {inst=, class=, parent=}, ... } phần tử sau = mới hơn
	local HiddenSkyParts = {}  -- [part] = Transparency gốc
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
		SkyboxDn = "rbxassetid://159454288", -- dùng chung texture vũ trụ để bỏ viền xanh
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
		for i = #SkyBackups, 1, -1 do
			if SkyBackups[i].inst == obj then table.remove(SkyBackups, i) end
		end
		table.insert(SkyBackups, { inst = obj, class = class, parent = obj.Parent })
		while #SkyBackups > 20 do table.remove(SkyBackups, 1) end
		pcall(function() obj.Parent = SkyFolder end)
	end

	-- Chỉ trả về bản MỚI NHẤT của mỗi loại, về đúng chỗ cũ (Lighting hoặc Terrain).
	local function RestoreGameSky()
		local restored = {}
		for i = #SkyBackups, 1, -1 do
			local entry = SkyBackups[i]
			if not restored[entry.class] and entry.inst and entry.inst.Parent == SkyFolder then
				restored[entry.class] = true
				local target = entry.parent
				if not target or not target.Parent then target = Lighting end
				pcall(function() entry.inst.Parent = target end)
			end
		end
		SkyBackups = {}
	end

	-- Part bầu trời của game: (a) khối/mái vòm lớn ở CẢ BA chiều, hoặc (b) tấm phẳng khổng lồ KHÔNG va chạm (mặt của skybox dạng hộp).
	-- Sàn/tường thật có va chạm nên không dính. Chỉ bị ẩn khi tên mình/cha có từ khóa bầu trời (xem HasSkyName).
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
			if name:find("sky", 1, true) or name:find("dome", 1, true) or name:find("galaxy", 1, true) or name:find("cosmos", 1, true) then
				return true
			end
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
		-- Game ghi đè texture/thuộc tính của Sky Galaxy -> ghi lại ngay.
		for name in pairs(GALAXY_PROPS) do
			pcall(function()
				Connect(sky:GetPropertyChangedSignal(name), function()
					task.defer(function()
						if IsRunning and galaxyOn and sky == customSkyInst and sky.Parent then ApplyGalaxyProps(sky) end
					end)
				end)
			end)
		end
		-- Tải trước texture để tránh bầu trời đen lúc ảnh chưa tải xong.
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
			if entry.inst and entry.inst.Parent == SkyFolder then stashed = stashed + 1 end
		end
		for part in pairs(HiddenSkyParts) do
			hidden = hidden + 1
			if #hiddenNames < 3 then table.insert(hiddenNames, part:GetFullName()) end
		end
		print(string.format("[Vampire Optimizer] Sky (%s): stashed=%d, hidden dome parts=%d%s",
			tag, stashed, hidden, #hiddenNames > 0 and (" [" .. table.concat(hiddenNames, " | ") .. "]") or ""))
		if candidates and #candidates > 0 then
			print("[Vampire Optimizer] Sky: big cube-like parts NOT hidden (name has no sky/dome keyword): " .. table.concat(candidates, " | "))
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
		add(string.format("== VAMPIRE SKY REPORT (V7.6) | mode=%s | galaxyOn=%s | placeId=%s ==", tostring(Config.SkyMode), tostring(galaxyOn), tostring(game.PlaceId)))
		add("Lighting: ClockTime=" .. ReadProp(Lighting, "ClockTime") .. ", Brightness=" .. ReadProp(Lighting, "Brightness")
			.. ", Exposure=" .. ReadProp(Lighting, "ExposureCompensation") .. ", Technology=" .. ReadProp(Lighting, "Technology")
			.. ", Ambient=" .. ReadProp(Lighting, "Ambient") .. ", OutdoorAmbient=" .. ReadProp(Lighting, "OutdoorAmbient"))
		add("-- Lighting children --")
		for _, child in ipairs(Lighting:GetChildren()) do
			add("  " .. child.ClassName .. " '" .. child.Name .. "'")
		end
		if customSkyInst then
			add("-- Galaxy sky --")
			add("  parent=" .. tostring(customSkyInst.Parent and customSkyInst.Parent.Name) .. " Bk=" .. ReadProp(customSkyInst, "SkyboxBk")
				.. " Up=" .. ReadProp(customSkyInst, "SkyboxUp") .. " bodies=" .. ReadProp(customSkyInst, "CelestialBodiesShown")
				.. " stars=" .. ReadProp(customSkyInst, "StarCount"))
		end
		add("Galaxy texture preload: " .. lastPreloadInfo)
		add("-- Stashed game sky objects --")
		for _, entry in ipairs(SkyBackups) do
			add("  " .. entry.class .. " '" .. entry.inst.Name .. "' inFolder=" .. tostring(entry.inst.Parent == SkyFolder))
		end
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
						add(string.format("  %s %s size=%.0f,%.0f,%.0f transp=%s collide=%s hidden=%s", d.ClassName, d:GetFullName(),
							size.X, size.Y, size.Z, ReadProp(d, "Transparency"), ReadProp(d, "CanCollide"), tostring(HiddenSkyParts[d] ~= nil)))
					end
				end
			end
		end
		add("  total=" .. count)
		add("-- Camera children --")
		for _, child in ipairs(workspace.CurrentCamera:GetChildren()) do
			add("  " .. child.ClassName .. " '" .. child.Name .. "'")
		end
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
						if HasSkyName(d) then
							HideSkyPart(d)
						elseif #candidates < 5 then
							table.insert(candidates, d:GetFullName())
						end
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

	-- Game thêm Sky/Atmosphere/Clouds mới (Lighting hoặc Terrain) khi đang ở Galaxy -> cất đi.
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

	-- Game xóa Galaxy (ClearAllChildren trên Lighting...) -> dựng lại.
	Connect(Lighting.ChildRemoved, function(obj)
		if not galaxyOn or obj ~= customSkyInst then return end
		task.delay(0.3, function()
			if IsRunning and galaxyOn and (not customSkyInst or customSkyInst.Parent ~= Lighting) then
				BuildGalaxySky()
			end
		end)
	end)

	-- Part mái vòm mới xuất hiện (map/sảnh load muộn) -> ẩn nếu giống mái vòm bầu trời.
	Connect(workspace.DescendantAdded, function(obj)
		if not galaxyOn or not obj:IsA("BasePart") then return end
		task.defer(function()
			if IsRunning and galaxyOn and obj.Parent and IsDomeShaped(obj) and HasSkyName(obj) then HideSkyPart(obj) end
		end)
	end)

	-- Canh gác mỗi giây: Galaxy phải còn, đúng thuộc tính, không còn Sky game nào đè lên.
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

-- 10. Khôi Phục Toàn Bộ Đồ Họa Gốc 100%
local function RestoreAllGraphics()
	SetFlatPlastic(false)
	SetRemoveTextures(false)
	SetRemoveShadows(false)
	SetFlatHair(false)
	ApplyFxScale(100)
	SetRenderDistance(100000)
	SetLiteTerrain(false)
	ApplySkyMode("Default")

	FrmFlag.Restore()
	pcall(function()
		settings().Rendering.QualityLevel = Backup.InitialEngineQuality
	end)

	Lighting.GlobalShadows = Backup.Lighting.GlobalShadows
	Lighting.FogStart = Backup.Lighting.FogStart
	Lighting.FogEnd = Backup.Lighting.FogEnd
	Lighting.FogColor = Backup.Lighting.FogColor
	Lighting.EnvironmentDiffuseScale = Backup.Lighting.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = Backup.Lighting.EnvironmentSpecularScale

	local originalQualityLevel = nil
	pcall(function() originalQualityLevel = tonumber(Backup.InitialEngineQuality.Name:match("^Level(%d+)$")) end)
	Config.EngineQuality = originalQualityLevel or "AUTO"
	Config.RenderDistance = math.clamp(math.floor(Backup.Lighting.FogEnd), 200, 100000)
end

-- ==================== GIAO DIỆN NGƯỜI DÙNG (UI GOTHIC VAMPIRE) ====================

local ParentTarget = nil
pcall(function() if type(gethui) == "function" then ParentTarget = gethui() end end)
if not ParentTarget then pcall(function() ParentTarget = game:GetService("CoreGui") end) end
if not ParentTarget then ParentTarget = LocalPlayer:WaitForChild("PlayerGui") end

-- Clean up stale V6/V7 windows before creating a fresh pair.
for _, oldName in ipairs({
	"VampireOptimizer_GUI_V6_8", "VampireOptimizer_GUI_V7_2",
	"VampireOptimizer_Float_V7_2"
}) do
	pcall(function()
		local old = ParentTarget:FindFirstChild(oldName)
		if old then old:Destroy() end
	end)
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VampireOptimizer_GUI_V7_2"
ScreenGui.DisplayOrder = 2147483000
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.Enabled = true
ScreenGui.Parent = ParentTarget

-- The floating button lives in a separate, higher DisplayOrder ScreenGui.
-- It remains clickable even when the main window overlaps it.
local ToggleGui = Instance.new("ScreenGui")
ToggleGui.Name = "VampireOptimizer_Float_V7_2"
ToggleGui.DisplayOrder = 2147483001
ToggleGui.IgnoreGuiInset = true
ToggleGui.ResetOnSpawn = false
ToggleGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ToggleGui.Enabled = true
ToggleGui.Parent = ParentTarget

-- NÚT NỔI LUÔN HIỂN THỊ
local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "FloatingVampireVectorIcon"
ToggleButton.Size = UDim2.new(0, 52, 0, 52)
ToggleButton.Position = UDim2.new(0, 15, 0.45, 0)
ToggleButton.BackgroundColor3 = Color3.fromRGB(22, 5, 8)
ToggleButton.BorderColor3 = Color3.fromRGB(230, 25, 40)
ToggleButton.BorderSizePixel = 2
ToggleButton.Text = ""
ToggleButton.AutoButtonColor = false
ToggleButton.Active = true
ToggleButton.Selectable = true
ToggleButton.ZIndex = 1000
ToggleButton.Parent = ToggleGui

local TBCorner = Instance.new("UICorner")
TBCorner.CornerRadius = UDim.new(1, 0)
TBCorner.Parent = ToggleButton

local LogoOuter = Instance.new("Frame")
LogoOuter.Size = UDim2.new(0, 24, 0, 24)
LogoOuter.Position = UDim2.new(0.5, -12, 0.5, -10)
LogoOuter.BackgroundColor3 = Color3.fromRGB(220, 20, 35)
LogoOuter.Rotation = -15
LogoOuter.BorderSizePixel = 0
LogoOuter.ZIndex = 1001
LogoOuter.Parent = ToggleButton

local LogoCorner = Instance.new("UICorner")
LogoCorner.CornerRadius = UDim.new(0, 4)
LogoCorner.Parent = LogoOuter

local LogoInner = Instance.new("Frame")
LogoInner.Size = UDim2.new(0, 8, 0, 8)
LogoInner.Position = UDim2.new(0.5, -4, 0.5, -4)
LogoInner.BackgroundColor3 = Color3.fromRGB(22, 5, 8)
LogoInner.BorderSizePixel = 0
LogoInner.ZIndex = 1002
LogoInner.Parent = LogoOuter

local InnerCorner = Instance.new("UICorner")
InnerCorner.CornerRadius = UDim.new(0, 1)
InnerCorner.Parent = LogoInner

local CrownBadge = Instance.new("TextLabel")
CrownBadge.Size = UDim2.new(1, 0, 0, 14)
CrownBadge.Position = UDim2.new(0, 0, 0, 2)
CrownBadge.BackgroundTransparency = 1
CrownBadge.Text = "👑"
CrownBadge.TextSize = 10
CrownBadge.ZIndex = 1003
CrownBadge.Parent = ToggleButton

-- KHUNG MENU CHÍNH
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainWindow"
MainFrame.Size = UDim2.new(0, 440, 0, 550)
MainFrame.Position = UDim2.new(0.5, -220, 0.5, -275)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 6, 9)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Active = true
MainFrame.Draggable = false
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainBorder = Instance.new("UIStroke")
MainBorder.Color = Color3.fromRGB(190, 25, 40)
MainBorder.Thickness = 2
MainBorder.Parent = MainFrame

-- THANH TIÊU ĐỀ
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 42)
TitleBar.BackgroundColor3 = Color3.fromRGB(28, 8, 12)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -120, 1, 0)
TitleLabel.Position = UDim2.new(0, 15, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "❖ " .. T("Title")
MainFrame:SetAttribute("DetectedLocale", rawLocale)
MainFrame:SetAttribute("UILanguage", currentLocale)
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
MinBtn.Selectable = true
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
CloseBtn.Selectable = true
CloseBtn.Parent = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

-- THANH TÌM KIẾM (Đã sửa lỗi hiện chữ TextBox)
local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(1, -20, 0, 32)
SearchBox.Position = UDim2.new(0, 10, 0, 48)
SearchBox.BackgroundColor3 = Color3.fromRGB(25, 10, 14)
SearchBox.Text = "" -- Xóa sạch văn bản mặc định
SearchBox.PlaceholderText = T("Search")
SearchBox.PlaceholderColor3 = Color3.fromRGB(150, 80, 90)
SearchBox.TextColor3 = Color3.fromRGB(255, 230, 230)
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 13
SearchBox.ClearTextOnFocus = false
SearchBox.Parent = MainFrame
Instance.new("UICorner", SearchBox).CornerRadius = UDim.new(0, 6)

-- VÙNG CUỘN
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

-- KHU VỰC NÚT DƯỚI CÙNG
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

-- ==================== CÁC CARD TÍNH NĂNG ====================
local allCards = {}

local function CreateToggleCard(id, titleText, descText, defaultState, callback)
	local Card = Instance.new("Frame")
	Card.Name = id .. " " .. titleText
	Card.Size = UDim2.new(1, -8, 0, 52)
	Card.BackgroundColor3 = Color3.fromRGB(26, 10, 14)
	Card.Parent = Scroll
	Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 6)

	local Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(1, -70, 0, 20)
	Label.Position = UDim2.new(0, 10, 0, 6)
	Label.BackgroundTransparency = 1
	Label.Text = titleText
	Label.TextColor3 = Color3.fromRGB(255, 215, 220)
	Label.Font = Enum.Font.GothamSemibold
	Label.TextSize = 13
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = Card

	local Sub = Instance.new("TextLabel")
	Sub.Size = UDim2.new(1, -70, 0, 18)
	Sub.Position = UDim2.new(0, 10, 0, 26)
	Sub.BackgroundTransparency = 1
	Sub.Text = descText
	Sub.TextColor3 = Color3.fromRGB(160, 100, 110)
	Sub.Font = Enum.Font.Gotham
	Sub.TextSize = 11
	Sub.TextXAlignment = Enum.TextXAlignment.Left
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
	Connect(Toggle.Activated, function()
		state = not state
		Toggle.Text = state and T("On") or T("Off")
		TweenService:Create(Toggle, TweenInfo.new(0.2), {
			BackgroundColor3 = state and Color3.fromRGB(200, 25, 45) or Color3.fromRGB(50, 20, 25)
		}):Play()
		callback(state)
	end)

	table.insert(allCards, Card)
	return function(newState)
		state = newState
		Toggle.Text = state and T("On") or T("Off")
		Toggle.BackgroundColor3 = state and Color3.fromRGB(200, 25, 45) or Color3.fromRGB(50, 20, 25)
	end
end

-- THẺ TÓC MỘT MÀU THEO MÀU GỐC (V7.3)
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
            task.delay(delaySeconds, function()
                if IsRunning and Card.Parent then RefreshStats() end
            end)
        end
    end

    Connect(ScanButton.Activated, function()
        if not Config.FlatHair then
            Sub.Text = T("HairRescanEnable")
            return
        end
        RescanHair()
        Sub.Text = T("HairRescanDone")
        RefreshStats()
        ScheduleStats()
    end)

    Connect(SolidButton.Activated, function()
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

    -- Initial scan result shows up a few seconds after the script starts.
    ScheduleStats()

    table.insert(allCards, Card)
    return function()
        Label.Text = T("HairColorTitle")
        Sub.Text = T("HairColorDesc")
        ScanButton.Text = T("HairRescan")
        RefreshSolidButton()
        RefreshStats()
    end
end

-- THANH TRƯỢT GIẢM HIỆU ỨNG (0% - 100%)
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

	table.insert(allCards, Card)
	return function(newVal)
		ValInput.Text = tostring(newVal) .. "%"
		Fill.Size = UDim2.new(newVal / 100, 0, 1, 0)
		ApplyFxScale(newVal)
	end
end

-- THANH ĐIỀU CHỈNH KHOẢNG SƯƠNG MÙ (KHÔNG PHẢI ENGINE RENDER DISTANCE)
local function CreateRenderDistanceCard()
	local Card = Instance.new("Frame")
	Card.Name = "RenderDist " .. T("RenderDistTitle")
	Card.Size = UDim2.new(1, -8, 0, 75)
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
	SliderBar.Size = UDim2.new(1, -20, 0, 10)
	SliderBar.Position = UDim2.new(0, 10, 0, 48)
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

	table.insert(allCards, Card)
	return function(newVal, shouldApply)
		newVal = math.clamp(math.floor(tonumber(newVal) or 100000), 200, 100000)
		ValInput.Text = tostring(newVal)
		Fill.Size = UDim2.new((newVal - 200) / 99800, 0, 1, 0)
		if shouldApply ~= false then SetRenderDistance(newVal) end
	end
end

-- THANH CẤP ĐỘ ĐỒ HỌA STUDIO (LEVEL 1 -> 21) THAY THẾ CHO FFLAG
local function CreateEngineQualityCard()
	local Card = Instance.new("Frame")
	Card.Name = "EngineQuality " .. T("EngineQualityTitle")
	Card.Size = UDim2.new(1, -8, 0, 75)
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
	Sub.Size = UDim2.new(1, -70, 0, 16)
	Sub.Position = UDim2.new(0, 10, 0, 24)
	Sub.BackgroundTransparency = 1
	Sub.Text = T("EngineQualityDesc")
	Sub.TextColor3 = Color3.fromRGB(160, 100, 110)
	Sub.Font = Enum.Font.Gotham
	Sub.TextSize = 11
	Sub.TextXAlignment = Enum.TextXAlignment.Left
	Sub.Parent = Card

	local ValInput = Instance.new("TextBox")
	ValInput.Size = UDim2.new(0, 48, 0, 22)
	ValInput.Position = UDim2.new(1, -58, 0, 6)
	ValInput.BackgroundColor3 = Color3.fromRGB(40, 15, 20)
	ValInput.Text = tostring(Config.EngineQuality or 1)
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
	local frac = (qualityValue - 1) / 20
	Fill.Size = UDim2.new(math.clamp(frac, 0, 1), 0, 1, 0)
	Fill.BackgroundColor3 = Color3.fromRGB(215, 30, 50)
	Fill.BorderSizePixel = 0
	Fill.Parent = SliderBar
	Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)

	local isDragging = false
	local function UpdateQ(x)
		local barWidth = SliderBar.AbsoluteSize.X
		local pos = math.clamp(x - SliderBar.AbsolutePosition.X, 0, barWidth)
		local fraction = math.clamp(pos / barWidth, 0, 1)
		local val = math.clamp(math.round(1 + fraction * 20), 1, 21)
		Fill.Size = UDim2.new((val - 1) / 20, 0, 1, 0)
		ValInput.Text = tostring(val)
		SetEngineQualityLevel(val)
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
		local num = math.clamp(math.floor(tonumber(ValInput.Text) or 1), 1, 21)
		ValInput.Text = tostring(num)
		Fill.Size = UDim2.new((num - 1) / 20, 0, 1, 0)
		SetEngineQualityLevel(num)
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
		ValInput.Text = tostring(newVal)
		Fill.Size = UDim2.new((newVal - 1) / 20, 0, 1, 0)
		if shouldApply ~= false then SetEngineQualityLevel(newVal) end
	end
end

-- THẺ BẦU TRỜI: CHỈ CÒN GALAXY VŨ TRỤ VÀ SKY GỐC CỦA GAME (Đã bỏ hẳn Sky Xám)
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
	Connect(ReportBtn.Activated, function()
		local ok, text = pcall(BuildSkyReport)
		if not ok then text = "Sky report failed: " .. tostring(text) end
		print("[Vampire Optimizer]\n" .. text)
		local copied = false
		pcall(function()
			if setclipboard then setclipboard(text); copied = true
			elseif toclipboard then toclipboard(text); copied = true end
		end)
		ReportBtn.Text = copied and "COPIED - PASTE IT INTO THE CHAT" or "PRINTED TO CONSOLE (F9)"
		task.delay(2.5, function() if IsRunning and ReportBtn.Parent then ReportBtn.Text = "COPY SKY REPORT" end end)
	end)

	local function UpdateSkyButtons(selected)
		GalaxyBtn.BackgroundColor3 = (selected == "Galaxy") and Color3.fromRGB(190, 25, 45) or Color3.fromRGB(45, 15, 20)
		DefaultBtn.BackgroundColor3 = (selected == "Default") and Color3.fromRGB(190, 25, 45) or Color3.fromRGB(45, 15, 20)
		ApplySkyMode(selected)
	end

	Connect(GalaxyBtn.Activated, function() UpdateSkyButtons("Galaxy") end)
	Connect(DefaultBtn.Activated, function() UpdateSkyButtons("Default") end)

	table.insert(allCards, Card)
	return function() UpdateSkyButtons("Default") end
end

-- LƯU Ý: Không có nút TP theo server người chơi ở bản client-only.
-- Việc tìm JobId của người khác và chuyển server phải qua luồng Roblox/server được cấp quyền;
-- script client trong game của người khác không thể tự cấp quyền hoặc vượt cài đặt riêng tư.

-- ==================== KIỂM TRA MỞ RỘNG MAP / THEO DÕI VÙNG ĐÃ STREAM ====================
-- Trong game người khác, client không thể yêu cầu server tăng Streaming radius.
-- Card này báo rõ script không mở rộng Streaming; chỉ đếm BasePart đã có mặt ở client quanh nhân vật.
local AreaStatusLabel = nil
local AreaMonitorButton = nil
local AreaMonitorEnabled = Config.LiveMonitor

local function GetAreaSnapshot()
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil, nil, T("WaitingCharacter")
	end

	local count = nil
	local okCount, result = pcall(function()
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		overlap.FilterDescendantsInstances = { character }
		overlap.MaxParts = 2000
		return workspace:GetPartBoundsInRadius(root.Position, 512, overlap)
	end)
	if okCount and type(result) == "table" then
		count = #result
	end

	local memoryMB = nil
	pcall(function()
		memoryMB = game:GetService("Stats"):GetTotalMemoryUsageMb()
	end)
	return count, memoryMB, nil
end

local function RefreshAreaStatus()
	if not AreaStatusLabel or not AreaStatusLabel.Parent then return end
	local count, memoryMB, errText = GetAreaSnapshot()
	if errText then
		AreaStatusLabel.Text = errText
		return
	end

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

	Connect(AreaMonitorButton.Activated, function()
		AreaMonitorEnabled = not AreaMonitorEnabled
		Config.LiveMonitor = AreaMonitorEnabled
		Config.LiveMonitorSet = true
		QueueAutoSave()
		AreaMonitorButton.Text = AreaMonitorEnabled and T("MonitorOn") or T("MonitorOff")
		AreaMonitorButton.BackgroundColor3 = AreaMonitorEnabled and Color3.fromRGB(145, 20, 35) or Color3.fromRGB(50, 20, 25)
		if AreaMonitorEnabled then RefreshAreaStatus() end
	end)

	Connect(ScanButton.Activated, RefreshAreaStatus)
	table.insert(allCards, Card)
	return function() end
end

-- ==================== ĐĂNG KÝ VÀ KHỞI TẠO TẤT CẢ CÁC NÚT ====================

local syncPlast = CreateToggleCard("FlatPlastic", T("FlatPlastic"), T("FlatPlasticDesc"), Config.FlatPlastic, function(s) SetFlatPlastic(s) end)
local syncTex = CreateToggleCard("RemoveTextures", T("RemoveTextures"), T("RemoveTexturesDesc"), Config.RemoveTextures, function(s) SetRemoveTextures(s) end)
local syncShad = CreateToggleCard("RemoveShadows", T("RemoveShadows"), T("RemoveShadowsDesc"), Config.RemoveShadows, function(s) SetRemoveShadows(s) end)
local syncFx = CreateFxSliderCard()
local syncDist = CreateRenderDistanceCard()
local syncEng = CreateEngineQualityCard()
local syncFarView = CreateToggleCard("KeepFarView", T("FarViewTitle"), T("FarViewDesc"), Config.KeepFarView, function(s)
	Config.KeepFarView = s == true
	SetEngineQualityLevel(Config.EngineQuality)
end)
local syncTerr = CreateToggleCard("LiteTerrain", T("LiteTerrain"), T("LiteTerrainDesc"), Config.LiteTerrain, function(s) SetLiteTerrain(s) end)
local syncSky = CreateSkyCard()
local syncArea = CreateAreaMonitorCard()
local syncHair = CreateToggleCard("FlatHair", T("HairFlatTitle"), T("HairFlatDesc"), Config.FlatHair, function(s) SetFlatHair(s) end)
local syncHairColor = CreateHairColorCard()
local syncAutoSave = CreateToggleCard("AutoSave", T("AutoSaveTitle"), T("AutoSaveDesc"), Config.AutoSave, function(s)
	Config.AutoSave = s
	if s then QueueAutoSave() else SaveConfig() end
end)
local syncTeleportPersist = CreateToggleCard("TeleportPersist", T("TeleportPersistTitle"), T("TeleportPersistDesc"), Config.TeleportPersist, function(s)
	Config.TeleportPersist = s == true
	QueueAutoSave()
end)

-- ==================== RANDOM PUBLIC SERVER HOP ====================
-- Reads the public server directory and requests a different public instance.
-- TeleportToPlaceInstance is a legacy client API; Roblox may still reject a join.
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
			if (not statusCode or (statusCode >= 200 and statusCode < 300)) and type(response.Body) == "string" then
				return response.Body
			end
			return nil, "HTTP status " .. tostring(statusCode or "unknown")
		end
	end
	return nil, tostring(body or "HTTP request unavailable")
end

-- ---------- Re-run after teleport (self-installing, Cat/Vape-style) ----------
-- Cat Vape does not need an outside app: it writes its own files into the executor workspace, and when a teleport starts it
-- queues a tiny script that loads them again in the next server. This does the same:
--   1. Persist.Install() keeps a copy of THIS script at workspace/VampireOptimizer/main.lua (source text comes from the loader
--      at the top of the file, VampireOptimizerSource).
--   2. LocalPlayer.OnTeleport (fires for ANY teleport, including game-started ones such as lobby -> match) saves settings and
--      calls queue_on_teleport with a small stub that reads that copy back.
--   3. If the executor has no file API, the full source is embedded inside the queued stub instead.
-- Picking a NEW server is still done by FetchPublicServerCandidates() + TeleportToPlaceInstance (see the hop button).
local Persist = { Dir = "VampireOptimizer" }
Persist.Flag = Persist.Dir .. "/disabled.flag"
local RELOAD_FILE_NAME = Persist.Dir .. "/main.lua"
local TeleportQueued = false

function Persist.HasFiles()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

-- Full source text of this script, provided by the loader (nil when the raw, unwrapped file was executed).
function Persist.Source()
	local source
	pcall(function() source = PersistentEnv.VampireOptimizerSource end)
	if type(source) ~= "string" then pcall(function() source = shared.VampireOptimizerSource end) end
	if type(source) == "string" and #source > 1000 then return source end
	return nil
end

function Persist.EnsureDir()
	pcall(function()
		if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder(Persist.Dir) then
			makefolder(Persist.Dir)
		end
	end)
end

-- Writes/refreshes the workspace copy. Returns true when a readable copy exists afterwards.
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
	return false, source and "could not write the workspace copy" or "script source unavailable (run the single-file version)"
end

-- Lua long-bracket literal for arbitrary text (picks a level that does not clash with the text).
function Persist.LongString(text)
	local level = 2
	while text:find("]" .. string.rep("=", level) .. "]", 1, true) or text:find("[" .. string.rep("=", level) .. "[", 1, true) do
		level = level + 1
	end
	local eq = string.rep("=", level)
	return "[" .. eq .. "[\n" .. text .. "\n]" .. eq .. "]"
end

-- The script handed to queue_on_teleport. It runs in the NEXT server, so it must be fully self-contained.
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
pcall(function()
  if type(isfile) == "function" and type(readfile) == "function" and isfile(FLAG_FILE) and readfile(FLAG_FILE) == "1" then disabled = true end
end)
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
	pcall(SaveConfig) -- like vape:Save() right before queue_on_teleport: the next server starts with the newest settings
	local okJson, configJson = pcall(function() return HttpService:JSONEncode(Config) end)
	if not okJson then return false, "Could not encode saved settings" end
	local rawUrl = tostring(Config.ReloadUrl or ""):gsub("^%s*(.-)%s*$", "%1")
	local installed = Persist.Install()
	local embedded
	if not installed then
		embedded = Persist.Source() -- no usable workspace copy: carry the whole script inside the queued stub
		if not embedded and rawUrl == "" then
			return false, "No script source to re-run: execute the single-file VampireOptimizer script"
		end
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
	return string.format("%s | queue_on_teleport: %s | files: %s | http: %s | auto-run: %s | fflag: %s", name, yn(hasQueue), yn(hasFiles), yn(hasHttp), autoRun, yn(FrmFlag.Setter() ~= nil))
end
local ExecutorReport = DescribeExecutor()
pcall(function() print("[Vampire Optimizer] " .. ExecutorReport) end)

local TeleportWarned = false
Connect(LocalPlayer.OnTeleport, function(teleportState)
	if teleportState == Enum.TeleportState.Failed then
		TeleportQueued = false
		TeleportWarned = false
		return
	end
	local ok, message = QueueReinjectIfConfigured("OnTeleport")
	if not ok and Config.TeleportPersist ~= false and not TeleportWarned then
		TeleportWarned = true -- OnTeleport fires several times per teleport; warn once
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
    Desc.Text = "Tim server công khai khác của cùng game; có thể bị Roblox từ chối hoặc hết chỗ."
    Desc.TextColor3 = Color3.fromRGB(160, 100, 110)
    Desc.Font = Enum.Font.Gotham
    Desc.TextSize = 9
    Desc.TextWrapped = true
    Desc.TextXAlignment = Enum.TextXAlignment.Left
    Desc.Parent = Card

    local Info = Instance.new("TextLabel")
    Info.Size = UDim2.new(1, -20, 0, 18)
    Info.Position = UDim2.new(0, 10, 0, 65)
    Info.BackgroundTransparency = 1
    Info.Text = string.format("%s | PlaceId: %s", tostring(game.Name), tostring(game.PlaceId))
    Info.TextColor3 = Color3.fromRGB(210, 180, 185)
    Info.Font = Enum.Font.Gotham
    Info.TextSize = 9
    Info.TextXAlignment = Enum.TextXAlignment.Left
    Info.Parent = Card

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

    local ReloadUrlBox = Instance.new("TextBox")
    ReloadUrlBox.Size = UDim2.new(1, -20, 0, 20)
    ReloadUrlBox.Position = UDim2.new(0, 10, 0, 139)
    ReloadUrlBox.BackgroundColor3 = Color3.fromRGB(40, 15, 20)
    ReloadUrlBox.Text = Config.ReloadUrl
    ReloadUrlBox.PlaceholderText = "Raw Lua URL (optional) — empty = auto, uses workspace/" .. RELOAD_FILE_NAME
    ReloadUrlBox.PlaceholderColor3 = Color3.fromRGB(150, 90, 100)
    ReloadUrlBox.TextColor3 = Color3.fromRGB(215, 195, 200)
    ReloadUrlBox.Font = Enum.Font.Gotham
    ReloadUrlBox.TextSize = 8
    ReloadUrlBox.ClearTextOnFocus = false
    ReloadUrlBox.TextXAlignment = Enum.TextXAlignment.Left
    ReloadUrlBox.Parent = Card
    Instance.new("UICorner", ReloadUrlBox).CornerRadius = UDim.new(0, 4)

    local Status = Instance.new("TextLabel")
    Status.Size = UDim2.new(1, -20, 0, 15)
    Status.Position = UDim2.new(0, 10, 0, 163)
    Status.BackgroundTransparency = 1
    Status.Text = ExecutorReport
    Status.TextColor3 = Color3.fromRGB(190, 145, 150)
    Status.Font = Enum.Font.Gotham
    Status.TextSize = 8
    Status.TextXAlignment = Enum.TextXAlignment.Left
    Status.Parent = Card

    local busy = false
    local lastRequest = 0

    Connect(ReloadUrlBox.FocusLost, function()
        Config.ReloadUrl = ReloadUrlBox.Text:gsub("^%s*(.-)%s*$", "%1")
        QueueAutoSave()
    end)

    Connect(HopButton.Activated, function()
        if busy or (os.clock() - lastRequest) < 20 then
            Status.Text = T("ServerHopCooldown")
            return
        end
        busy = true
        lastRequest = os.clock()
        HopButton.Text = "..."
        Status.Text = "Đang tìm server công khai khác..."

        task.spawn(function()
            local candidates, fetchError = FetchPublicServerCandidates()
            if not IsRunning or not Card.Parent then return end
            if not candidates or #candidates == 0 then
                busy = false
                HopButton.Text = T("ServerHopButton")
                Status.Text = "Không tìm thấy server khác hoặc executor không đọc được danh sách: " .. tostring(fetchError or "empty list"):sub(1, 75)
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
            if queued then
                Status.Text = "Đã xếp tự chạy lại; đang chuyển server..."
            elseif Config.TeleportPersist ~= false then
                Status.Text = "Không đặt được tự chạy lại: " .. tostring(queueMessage):sub(1, 70)
            else
                Status.Text = "Đang chuyển server; sau khi vào hãy chạy lại script thủ công."
            end

            local teleportOk, teleportError = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, selected.id, LocalPlayer)
            end)
            if not teleportOk then
                busy = false
                TeleportQueued = false
                HopButton.Text = T("ServerHopButton")
                Status.Text = "Roblox từ chối chuyển server: " .. tostring(teleportError):sub(1, 80)
            end
        end)
    end)

    Connect(TeleportService.TeleportInitFailed, function(player, result, errorMessage)
        if player == LocalPlayer and Card.Parent then
            busy = false
            TeleportQueued = false
            HopButton.Text = T("ServerHopButton")
            Status.Text = "Chuyển server thất bại: " .. tostring(errorMessage or result):sub(1, 85)
        end
    end)

    Connect(CopyButton.Activated, function()
        local copied = false
        if type(setclipboard) == "function" then copied = pcall(setclipboard, serverListUrl) end
        if copied then
            Status.Text = T("ServerHopCopied")
        else
            ServerListBox:CaptureFocus()
            ServerListBox.CursorPosition = #ServerListBox.Text + 1
            Status.Text = T("ServerHopCopyManual")
        end
    end)

    table.insert(allCards, Card)
    return function() end
end
local syncServerHop = CreateServerHopCard()

local function UpdateCanvas()
	Scroll.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y + 15)
end
Connect(UIList:GetPropertyChangedSignal("AbsoluteContentSize"), UpdateCanvas)
task.defer(UpdateCanvas)

-- V7.4: Theo dõi tự động. Mặc định BẬT, quét mỗi 3 giây khi menu đang mở (1 giây một lần cho tới khi nhân vật xuất hiện).
-- Menu đang thu nhỏ/ẩn thì tạm dừng quét để không tốn CPU. Vòng lặp tự dừng khi bấm X.
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

-- TÌM KIẾM THEO TÊN
-- V7.4: tìm theo cả tên thẻ lẫn chữ đang hiển thị (nên vẫn đúng sau khi đổi ngôn ngữ); tìm văn bản thuần, không lỗi pattern.
local function CardSearchText(card)
	local parts = { card.Name }
	for _, d in ipairs(card:GetDescendants()) do
		if d:IsA("TextLabel") then table.insert(parts, d.Text) end
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

-- BẬT / TẮT MENU
local isOpen = true
local function SetMenuVisible(v)
	isOpen = (v == true)
	if ScreenGui then ScreenGui.Enabled = true end
	MainFrame.Visible = isOpen
	if ToggleGui then ToggleGui.Enabled = true end
	if ToggleButton then ToggleButton.Visible = true end
end

-- Nút X: khôi phục trạng thái ban đầu, ngắt mọi event, xóa GUI và dừng script.
local function Shutdown(byUser)
	if not IsRunning then return end
	IsRunning = false

	-- X = the user wants the script gone: stop the post-teleport bootstrap from reviving it.
	pcall(function() shared.VampireOptimizerDisabled = true end)
	pcall(function() PersistentEnv.VampireOptimizerDisabled = true end)
	if byUser == true then -- the flag file survives the server change, so a queued stub will not revive a script the user closed
		pcall(function()
			if type(writefile) == "function" then
				Persist.EnsureDir()
				writefile(Persist.Flag, "1")
			end
		end)
	end

	-- V7.4: vòng lặp Theo dõi tự dừng nhờ IsRunning = false. KHÔNG ghi LiveMonitor = false nữa
	-- (trước đây mỗi lần chạy lại script / sang map mới đều lưu Theo dõi = TẮT).
	pcall(SaveConfig)

	pcall(RestoreAllGraphics)

	for i = #Connections, 1, -1 do
		local connection = Connections[i]
		pcall(function() connection:Disconnect() end)
		Connections[i] = nil
	end

	pcall(function()
		if ScreenGui then ScreenGui:Destroy() end
	end)
	pcall(function()
		if ToggleGui then ToggleGui:Destroy() end
	end)
	pcall(function()
		local env = PersistentEnv
		if type(env.VampireOptimizerRuntime) == "table" then env.VampireOptimizerRuntime = nil end
		if type(shared.VampireOptimizerRuntime) == "table" then shared.VampireOptimizerRuntime = nil end
	end)
	pcall(function()
		if SkyFolder then SkyFolder:Destroy() end
	end)
end

Connect(ToggleButton.Activated, function() SetMenuVisible(not MainFrame.Visible) end)
Connect(MinBtn.Activated, function() SetMenuVisible(false) end)
Connect(CloseBtn.Activated, function() Shutdown(true) end)

-- NÚT KHÔI PHỤC TOÀN BỘ ĐỒ HỌA GỐC
Connect(RestoreBtn.Activated, function()
	RestoreAllGraphics()
	syncPlast(false)
	syncTex(false)
	syncShad(false)
	syncFx(100)
	syncDist(Config.RenderDistance, false)
	local originalQualityName = Backup.InitialEngineQuality.Name
	local originalQualityLevel = tonumber(originalQualityName:match("^Level(%d+)$"))
	if originalQualityLevel then
		syncEng(originalQualityLevel, false)
	else
		syncEng("AUTO", false)
	end
	syncTerr(false)
	syncSky()
	syncHair(false)
	syncHairColor()

	RestoreBtn.Text = T("RestoredSuccess")
	task.delay(1.5, function() if IsRunning and RestoreBtn.Parent then RestoreBtn.Text = T("Restore") end end)
end)

-- NÚT LƯU CẤU HÌNH
Connect(SaveBtn.Activated, function()
	local saved, saveDetail = SaveConfig()
	SaveBtn.Text = saved and ((saveDetail == "memory only") and "SAVED IN SESSION" or T("SavedSuccess")) or "SAVE FAILED"
	task.delay(1.5, function() if IsRunning and SaveBtn.Parent then SaveBtn.Text = T("Save") end end)
end)

-- THEO DÕI ĐỐI TƯỢNG MỚI XUẤT HIỆN
Connect(workspace.DescendantAdded, function(v)
	task.defer(function()
		if not IsRunning or not v or not v.Parent then return end

		if Config.FxScale < 100 then
			local f = Config.FxScale / 100
			if v:IsA("ParticleEmitter") then
				if Backup.OriginalFx[v] == nil then
					Backup.OriginalFx[v] = { Enabled = v.Enabled, Rate = v.Rate, Size = v.Size }
				end
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

		if Config.RemoveTextures and (v:IsA("Texture") or v:IsA("Decal")) then
			if Backup.OriginalTextures[v] == nil then Backup.OriginalTextures[v] = v.Transparency end
			v.Transparency = 1
		end
		if Config.RemoveShadows and v:IsA("BasePart") then
			if Backup.OriginalShadows[v] == nil then Backup.OriginalShadows[v] = v.CastShadow end
			v.CastShadow = false
		end
		if Config.FlatPlastic and v:IsA("BasePart") and not isLucky(v) and v.MaterialVariant == "" then
			if Backup.OriginalMaterials[v] == nil then Backup.OriginalMaterials[v] = v.Material end
			v.Material = Enum.Material.SmoothPlastic
		end
		if Config.FlatHair then ApplyFlatHairObject(v) end
	end)
end)

-- ==================== V7.4: ĐỔI NGÔN NGỮ TRỰC TIẾP THEO ROBLOX ====================
-- Trước đây ngôn ngữ chỉ đọc 1 lần lúc chạy script. Giờ: theo dõi LocaleId / RobloxLocaleId (sự kiện + kiểm tra mỗi 1 giây),
-- khi đổi thì dịch lại toàn bộ chữ trên menu ngay lập tức, không cần chạy lại script.
do
	local function ResolveLocaleCode(raw)
		raw = string.lower((tostring(raw or ""):gsub("_", "-")))
		local base = raw:match("^([a-z]+)")
		if not base then return nil end
		if base == "zh" then
			if raw:find("zh%-tw") or raw:find("zh%-hk") or raw:find("zh%-mo") then return "zhTW" end
			return "zhCN"
		end
		if Lang[base] then return base end
		return nil
	end

	local function ReadRaw(which)
		local value
		pcall(function()
			if which == 1 then value = LocalPlayer.LocaleId else value = LocalizationService.RobloxLocaleId end
		end)
		if type(value) == "string" and value ~= "" then return value end
		return nil
	end

	-- chữ đang hiển thị (ngôn ngữ cũ) -> khóa dịch
	local function BuildReverse(locale)
		local rev = {}
		local set = Lang[locale]
		for key, enText in pairs(Lang.en) do
			local text = (set and set[key]) or enText
			if type(text) == "string" and rev[text] == nil then rev[text] = key end
		end
		if set then
			for key, text in pairs(set) do
				if type(text) == "string" and rev[text] == nil then rev[text] = key end
			end
		end
		return rev
	end

	local function Retranslate(oldLocale)
		local rev = BuildReverse(oldLocale)
		local function walk(root)
			if not root then return end
			for _, inst in ipairs(root:GetDescendants()) do
				if inst:IsA("TextBox") then
					local key = rev[inst.PlaceholderText]
					if key then inst.PlaceholderText = T(key) end
				elseif inst:IsA("TextLabel") or inst:IsA("TextButton") then
					local key = rev[inst.Text]
					if key then inst.Text = T(key) end
				end
			end
		end
		walk(ScreenGui)
		walk(ToggleGui)
		TitleLabel.Text = "❖ " .. T("Title")
		pcall(function() MainFrame:SetAttribute("UILanguage", currentLocale) end)
		pcall(RefreshAreaStatus) -- dòng thống kê có số liệu nên dựng lại bằng ngôn ngữ mới
	end

	local lastPlayerLocale, lastCoreLocale = ReadRaw(1), ReadRaw(2)
	local function CheckLocale()
		local playerLocale, coreLocale = ReadRaw(1), ReadRaw(2)
		local chosen = nil
		if playerLocale ~= lastPlayerLocale then chosen = playerLocale
		elseif coreLocale ~= lastCoreLocale then chosen = coreLocale end
		lastPlayerLocale, lastCoreLocale = playerLocale, coreLocale
		if not chosen then return end
		local newLocale = ResolveLocaleCode(chosen)
		if not newLocale or newLocale == currentLocale then return end
		local oldLocale = currentLocale
		currentLocale = newLocale
		local ok, err = pcall(Retranslate, oldLocale)
		if not ok then warn("[Vampire Optimizer] Language switch failed: " .. tostring(err)) end
	end

	pcall(function() Connect(LocalPlayer:GetPropertyChangedSignal("LocaleId"), CheckLocale) end)
	pcall(function() Connect(LocalizationService:GetPropertyChangedSignal("RobloxLocaleId"), CheckLocale) end)
	task.spawn(function()
		while IsRunning do
			task.wait(1)
			if IsRunning then pcall(CheckLocale) end
		end
	end)
end

-- KHỞI CHẠY TOÀN BỘ CẤU HÌNH ĐÃ LƯU. Mỗi phần chạy trong pcall riêng để một lỗi không chặn các phần còn lại.
local function SafeApplySaved(label, callback)
	local ok, err = pcall(callback)
	if not ok then warn("[Vampire Optimizer] Apply " .. label .. " failed: " .. tostring(err)) end
end
Config.FlatHair = true -- auto-on by design
SafeApplySaved("FlatPlastic", function() SetFlatPlastic(Config.FlatPlastic) end)
SafeApplySaved("RemoveTextures", function() SetRemoveTextures(Config.RemoveTextures) end)
SafeApplySaved("RemoveShadows", function() SetRemoveShadows(Config.RemoveShadows) end)
SafeApplySaved("FxScale", function() ApplyFxScale(Config.FxScale) end)
SafeApplySaved("FogDistance", function() SetRenderDistance(Config.RenderDistance) end)
SafeApplySaved("EngineQuality", function() SetEngineQualityLevel(Config.EngineQuality) end)
SafeApplySaved("LiteTerrain", function() SetLiteTerrain(Config.LiteTerrain) end)
SafeApplySaved("FlatHair", function() SetFlatHair(true) end)
SafeApplySaved("SkyMode", function() ApplySkyMode(Config.SkyMode) end)
StoreConfigInMemory()
QueueAutoSave()
if IsReloadRun then pcall(SetMenuVisible, false) end -- silent re-run after a teleport; open it with the toggle button

-- Publish a safe stop handle so rerunning V7.3 first restores the previous session and disconnects it.
local RuntimeHandle = { Stop = Shutdown }
pcall(function() PersistentEnv.VampireOptimizerRuntime = RuntimeHandle end)
pcall(function() shared.VampireOptimizerRuntime = RuntimeHandle end)
]==]

do
	local env = shared
	pcall(function() if type(getgenv) == "function" then env = getgenv() end end)
	pcall(function() shared.VampireOptimizerSource = VAMPIRE_SOURCE end)
	pcall(function() env.VampireOptimizerSource = VAMPIRE_SOURCE end)
end

local chunk, compileError = loadstring(VAMPIRE_SOURCE, "VampireOptimizer")
if not chunk then
	warn("[Vampire Optimizer] compile error: " .. tostring(compileError))
	return
end
return chunk()
