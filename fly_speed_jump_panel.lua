-- LocalScript: Control Panel v4
-- Speed / Jump / Fly / Infinite Jump + Auto Fly khi hồi sinh + Phím tắt tùy chọn
-- + Đa ngôn ngữ (theo ngôn ngữ Roblox) + Tự lưu toàn bộ cài đặt
-- Đặt vào StarterPlayerScripts (khuyên dùng) hoặc StarterGui

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

---------------------------------------------------------------------
-- CẤU HÌNH
---------------------------------------------------------------------
local CONFIG = {
	DefaultFlySpeed = 50,
	MinFlySpeed = 5,
	MaxFlySpeed = 1000,
	MaxMultiplier = 100,        -- giới hạn hệ số Speed / Jump

	AutoFlyOnRespawn = true,    -- chết xong hồi sinh -> fly tự bật lại (nếu lúc chết đang fly)
	AlwaysFlyOnRespawn = false, -- true = hồi sinh LUÔN tự bật fly, dù trước đó không fly

	SettingsFile = "ControlPanel_Settings.json",
}

local PANEL_WIDTH = 320
local FULL_HEIGHT = 420
local HEADER_HEIGHT = 48

-- Vị trí mặc định của UI (theo tỉ lệ màn hình)
local DEFAULT_POS_X = 0.69 -- tâm UI theo chiều ngang
local DEFAULT_POS_Y = 0.26 -- cạnh trên UI theo chiều dọc

-- Các hành động có thể gán phím tắt (mặc định: KHÔNG gán phím nào)
local ACTIONS = {
	{ id = "Toggle",  icon = "✈", labelKey = "act_toggle", shortKey = "sh_toggle" },
	{ id = "Up",      icon = "⬆", labelKey = "act_up",     shortKey = "sh_up" },
	{ id = "Down",    icon = "⬇", labelKey = "act_down",   shortKey = "sh_down" },
	{ id = "InfJump", icon = "∞", labelKey = "act_inf",    shortKey = "sh_inf" },
}

---------------------------------------------------------------------
-- NGÔN NGỮ
-- Ngôn ngữ mặc định lấy theo cài đặt ngôn ngữ của Roblox
-- (LocalizationService.RobloxLocaleId, ví dụ "vi-vn" -> "vi").
-- Có thể chọn tay trong trang ⌨. Thiếu bản dịch thì dùng tiếng Anh.
---------------------------------------------------------------------
local LANG_ORDER = { "auto", "en", "vi", "es", "pt", "id", "fr", "de", "ru", "th", "zh", "ja", "ko" }

local LANG_NAMES = {
	en = "English", vi = "Tiếng Việt", es = "Español", pt = "Português",
	id = "Bahasa Indonesia", fr = "Français", de = "Deutsch", ru = "Русский",
	th = "ไทย", zh = "中文", ja = "日本語", ko = "한국어",
}

local STRINGS = {
	en = {
		title = "Control Panel", walk = "Walk Speed", jump = "Jump Power", flyspd = "Fly Speed",
		fly_on = "Enable Fly", fly_off = "Disable Fly", auto = "Auto Fly on respawn", inf = "Infinite Jump",
		on = "ON", off = "OFF", hint_none = "No hotkeys set • tap ⌨ to set",
		act_toggle = "Toggle Fly", act_up = "Fly up", act_down = "Fly down", act_inf = "Infinite Jump",
		sh_toggle = "Fly", sh_up = "Up", sh_down = "Down", sh_inf = "∞",
		keys_title = "Hotkeys & Language",
		keys_desc = "Tap a box, then press the key to assign. Tap again to cancel, ✕ to clear. Default: none.",
		not_set = "Not set", press = "Press key…", lang = "Language", lang_auto = "Auto (Roblox)",
		save_on = "Auto-save: ON", save_off = "Auto-save unavailable here. Settings last for this session only.",
		back = "Back",
	},
	vi = {
		title = "Bảng điều khiển", walk = "Tốc độ chạy (Walk Speed)", jump = "Sức nhảy (Jump Power)", flyspd = "Tốc độ bay (Fly Speed)",
		fly_on = "Bật Fly", fly_off = "Tắt Fly", auto = "Auto Fly khi hồi sinh", inf = "Nhảy vô hạn",
		on = "BẬT", off = "TẮT", hint_none = "Chưa gán phím tắt • bấm ⌨ để cài",
		act_toggle = "Bật / Tắt Fly", act_up = "Bay lên", act_down = "Bay xuống", act_inf = "Nhảy vô hạn",
		sh_toggle = "Fly", sh_up = "Lên", sh_down = "Xuống", sh_inf = "∞",
		keys_title = "Phím tắt & Ngôn ngữ",
		keys_desc = "Bấm vào ô rồi nhấn phím để gán. Bấm lại để hủy, ✕ để xoá. Mặc định: chưa gán.",
		not_set = "Chưa gán", press = "Nhấn phím…", lang = "Ngôn ngữ", lang_auto = "Tự động (Roblox)",
		save_on = "Tự động lưu: BẬT", save_off = "Không lưu được ở đây. Cài đặt chỉ giữ trong phiên này.",
		back = "Quay lại",
	},
	es = {
		title = "Panel de control", walk = "Velocidad al correr", jump = "Fuerza de salto", flyspd = "Velocidad de vuelo",
		fly_on = "Activar vuelo", fly_off = "Desactivar vuelo", auto = "Auto vuelo al reaparecer", inf = "Salto infinito",
		on = "ON", off = "OFF", hint_none = "Sin atajos • toca ⌨ para configurar",
		act_toggle = "Activar/Desactivar vuelo", act_up = "Volar arriba", act_down = "Volar abajo", act_inf = "Salto infinito",
		sh_toggle = "Vuelo", sh_up = "Subir", sh_down = "Bajar", sh_inf = "∞",
		keys_title = "Atajos e idioma",
		keys_desc = "Toca una casilla y pulsa la tecla a asignar. Toca de nuevo para cancelar, ✕ para borrar. Por defecto: ninguna.",
		not_set = "Sin asignar", press = "Pulsa tecla…", lang = "Idioma", lang_auto = "Auto (Roblox)",
		save_on = "Autoguardado: ON", save_off = "Autoguardado no disponible aquí. Los ajustes duran solo esta sesión.",
		back = "Volver",
	},
	pt = {
		title = "Painel de controle", walk = "Velocidade de corrida", jump = "Força do pulo", flyspd = "Velocidade de voo",
		fly_on = "Ativar voo", fly_off = "Desativar voo", auto = "Auto voo ao renascer", inf = "Pulo infinito",
		on = "ON", off = "OFF", hint_none = "Sem atalhos • toque em ⌨ para definir",
		act_toggle = "Ligar/Desligar voo", act_up = "Voar para cima", act_down = "Voar para baixo", act_inf = "Pulo infinito",
		sh_toggle = "Voo", sh_up = "Subir", sh_down = "Descer", sh_inf = "∞",
		keys_title = "Atalhos e idioma",
		keys_desc = "Toque numa caixa e pressione a tecla para atribuir. Toque de novo para cancelar, ✕ para limpar. Padrão: nenhuma.",
		not_set = "Não definido", press = "Pressione…", lang = "Idioma", lang_auto = "Auto (Roblox)",
		save_on = "Salvar automático: ON", save_off = "Salvamento automático indisponível aqui. Ajustes valem só nesta sessão.",
		back = "Voltar",
	},
	id = {
		title = "Panel kontrol", walk = "Kecepatan lari", jump = "Kekuatan lompat", flyspd = "Kecepatan terbang",
		fly_on = "Aktifkan terbang", fly_off = "Matikan terbang", auto = "Auto terbang saat respawn", inf = "Lompat tak terbatas",
		on = "ON", off = "OFF", hint_none = "Belum ada hotkey • ketuk ⌨ untuk atur",
		act_toggle = "Nyala/Mati terbang", act_up = "Terbang naik", act_down = "Terbang turun", act_inf = "Lompat tak terbatas",
		sh_toggle = "Terbang", sh_up = "Naik", sh_down = "Turun", sh_inf = "∞",
		keys_title = "Hotkey & Bahasa",
		keys_desc = "Ketuk kotak lalu tekan tombol yang ingin ditetapkan. Ketuk lagi untuk batal, ✕ untuk hapus. Default: kosong.",
		not_set = "Belum diatur", press = "Tekan tombol…", lang = "Bahasa", lang_auto = "Otomatis (Roblox)",
		save_on = "Simpan otomatis: ON", save_off = "Simpan otomatis tidak tersedia di sini. Pengaturan hanya berlaku di sesi ini.",
		back = "Kembali",
	},
	fr = {
		title = "Panneau de contrôle", walk = "Vitesse de course", jump = "Puissance de saut", flyspd = "Vitesse de vol",
		fly_on = "Activer le vol", fly_off = "Désactiver le vol", auto = "Auto-vol à la réapparition", inf = "Saut infini",
		on = "ON", off = "OFF", hint_none = "Aucun raccourci • touchez ⌨ pour régler",
		act_toggle = "Activer/Désactiver le vol", act_up = "Voler vers le haut", act_down = "Voler vers le bas", act_inf = "Saut infini",
		sh_toggle = "Vol", sh_up = "Haut", sh_down = "Bas", sh_inf = "∞",
		keys_title = "Raccourcis et langue",
		keys_desc = "Touchez une case puis appuyez sur la touche à assigner. Retouchez pour annuler, ✕ pour effacer. Par défaut : aucune.",
		not_set = "Non défini", press = "Appuyez…", lang = "Langue", lang_auto = "Auto (Roblox)",
		save_on = "Sauvegarde auto : ON", save_off = "Sauvegarde auto indisponible ici. Les réglages ne durent que cette session.",
		back = "Retour",
	},
	de = {
		title = "Steuerung", walk = "Laufgeschwindigkeit", jump = "Sprungkraft", flyspd = "Fluggeschwindigkeit",
		fly_on = "Fliegen aktivieren", fly_off = "Fliegen deaktivieren", auto = "Auto-Flug nach Respawn", inf = "Unendlicher Sprung",
		on = "AN", off = "AUS", hint_none = "Keine Hotkeys • ⌨ antippen zum Festlegen",
		act_toggle = "Fliegen an/aus", act_up = "Aufwärts fliegen", act_down = "Abwärts fliegen", act_inf = "Unendlicher Sprung",
		sh_toggle = "Flug", sh_up = "Hoch", sh_down = "Runter", sh_inf = "∞",
		keys_title = "Hotkeys & Sprache",
		keys_desc = "Feld antippen, dann die Taste drücken. Erneut antippen zum Abbrechen, ✕ zum Löschen. Standard: keine.",
		not_set = "Nicht belegt", press = "Taste drücken…", lang = "Sprache", lang_auto = "Auto (Roblox)",
		save_on = "Autospeichern: AN", save_off = "Autospeichern hier nicht verfügbar. Einstellungen gelten nur für diese Sitzung.",
		back = "Zurück",
	},
	ru = {
		title = "Панель управления", walk = "Скорость бега", jump = "Сила прыжка", flyspd = "Скорость полёта",
		fly_on = "Включить полёт", fly_off = "Выключить полёт", auto = "Автополёт после возрождения", inf = "Бесконечный прыжок",
		on = "ВКЛ", off = "ВЫКЛ", hint_none = "Нет горячих клавиш • нажмите ⌨",
		act_toggle = "Вкл/выкл полёт", act_up = "Лететь вверх", act_down = "Лететь вниз", act_inf = "Бесконечный прыжок",
		sh_toggle = "Полёт", sh_up = "Вверх", sh_down = "Вниз", sh_inf = "∞",
		keys_title = "Клавиши и язык",
		keys_desc = "Нажмите на поле, затем клавишу для назначения. Нажмите снова для отмены, ✕ для сброса. По умолчанию: нет.",
		not_set = "Не задано", press = "Нажмите…", lang = "Язык", lang_auto = "Авто (Roblox)",
		save_on = "Автосохранение: ВКЛ", save_off = "Автосохранение здесь недоступно. Настройки действуют только в этой сессии.",
		back = "Назад",
	},
	th = {
		title = "แผงควบคุม", walk = "ความเร็ววิ่ง", jump = "พลังกระโดด", flyspd = "ความเร็วบิน",
		fly_on = "เปิดการบิน", fly_off = "ปิดการบิน", auto = "บินอัตโนมัติเมื่อเกิดใหม่", inf = "กระโดดไม่จำกัด",
		on = "เปิด", off = "ปิด", hint_none = "ยังไม่ตั้งปุ่มลัด • แตะ ⌨ เพื่อตั้งค่า",
		act_toggle = "เปิด/ปิดการบิน", act_up = "บินขึ้น", act_down = "บินลง", act_inf = "กระโดดไม่จำกัด",
		sh_toggle = "บิน", sh_up = "ขึ้น", sh_down = "ลง", sh_inf = "∞",
		keys_title = "ปุ่มลัดและภาษา",
		keys_desc = "แตะช่อง แล้วกดปุ่มที่ต้องการ แตะอีกครั้งเพื่อยกเลิก ✕ เพื่อล้าง ค่าเริ่มต้น: ไม่มี",
		not_set = "ยังไม่ตั้ง", press = "กดปุ่ม…", lang = "ภาษา", lang_auto = "อัตโนมัติ (Roblox)",
		save_on = "บันทึกอัตโนมัติ: เปิด", save_off = "ไม่รองรับการบันทึกอัตโนมัติที่นี่ การตั้งค่าอยู่เฉพาะรอบนี้",
		back = "กลับ",
	},
	zh = {
		title = "控制面板", walk = "奔跑速度", jump = "跳跃力", flyspd = "飞行速度",
		fly_on = "开启飞行", fly_off = "关闭飞行", auto = "重生后自动飞行", inf = "无限跳跃",
		on = "开", off = "关", hint_none = "未设置快捷键 • 点击 ⌨ 设置",
		act_toggle = "开关飞行", act_up = "向上飞", act_down = "向下飞", act_inf = "无限跳跃",
		sh_toggle = "飞行", sh_up = "上", sh_down = "下", sh_inf = "∞",
		keys_title = "快捷键与语言",
		keys_desc = "点击方框，然后按下要绑定的按键。再次点击取消，✕ 清除。默认：无。",
		not_set = "未设置", press = "请按键…", lang = "语言", lang_auto = "自动 (Roblox)",
		save_on = "自动保存：开", save_off = "此环境不支持自动保存，设置仅在本次有效。",
		back = "返回",
	},
	ja = {
		title = "コントロールパネル", walk = "走る速度", jump = "ジャンプ力", flyspd = "飛行速度",
		fly_on = "飛行をオン", fly_off = "飛行をオフ", auto = "リスポーン後に自動飛行", inf = "無限ジャンプ",
		on = "オン", off = "オフ", hint_none = "ホットキー未設定 • ⌨ で設定",
		act_toggle = "飛行 オン/オフ", act_up = "上昇", act_down = "下降", act_inf = "無限ジャンプ",
		sh_toggle = "飛行", sh_up = "上", sh_down = "下", sh_inf = "∞",
		keys_title = "ホットキーと言語",
		keys_desc = "枠をタップしてキーを押すと割り当て。もう一度タップで取消、✕ で削除。初期状態：なし。",
		not_set = "未設定", press = "キーを押す…", lang = "言語", lang_auto = "自動 (Roblox)",
		save_on = "自動保存：オン", save_off = "この環境では自動保存できません。設定は今回のみ有効です。",
		back = "戻る",
	},
	ko = {
		title = "컨트롤 패널", walk = "달리기 속도", jump = "점프력", flyspd = "비행 속도",
		fly_on = "비행 켜기", fly_off = "비행 끄기", auto = "리스폰 후 자동 비행", inf = "무한 점프",
		on = "켜짐", off = "꺼짐", hint_none = "단축키 없음 • ⌨ 를 눌러 설정",
		act_toggle = "비행 켜기/끄기", act_up = "위로 비행", act_down = "아래로 비행", act_inf = "무한 점프",
		sh_toggle = "비행", sh_up = "위", sh_down = "아래", sh_inf = "∞",
		keys_title = "단축키 및 언어",
		keys_desc = "칸을 누른 뒤 지정할 키를 누르세요. 다시 누르면 취소, ✕ 는 삭제. 기본값: 없음.",
		not_set = "미설정", press = "키 입력…", lang = "언어", lang_auto = "자동 (Roblox)",
		save_on = "자동 저장: 켜짐", save_off = "이 환경에서는 자동 저장을 쓸 수 없습니다. 설정은 이번 세션에서만 유지됩니다.",
		back = "뒤로",
	},
}

-- Lấy mã ngôn ngữ từ cài đặt Roblox ("vi-vn" -> "vi"); không hỗ trợ thì dùng "en"
local function detectRobloxLanguage()
	local id
	pcall(function() id = LocalizationService.RobloxLocaleId end)
	if type(id) ~= "string" or id == "" then
		pcall(function() id = player.LocaleId end)
	end
	if type(id) ~= "string" or id == "" then
		pcall(function() id = LocalizationService.SystemLocaleId end)
	end
	local lang = tostring(id or "en-us"):lower():match("^(%a+)") or "en"
	if STRINGS[lang] then
		return lang
	end
	return "en"
end

---------------------------------------------------------------------
-- TRẠNG THÁI
---------------------------------------------------------------------
local character, humanoid, rootPart

local defaultSpeed = 16
local defaultJumpPower = 50
local defaultJumpHeight = 7.2

local speedMultiplier = 1.0
local jumpMultiplier = 1.0
local currentFlySpeed = CONFIG.DefaultFlySpeed

local isFlying = false
local wasFlyingOnDeath = false
local autoFlyRespawn = CONFIG.AutoFlyOnRespawn
local infiniteJump = false
local upHeld, downHeld = false, false

local languageSetting = "auto" -- "auto" (theo Roblox) hoặc mã ngôn ngữ
local currentLang = "en"

-- Phím tắt: MẶC ĐỊNH KHÔNG CÓ PHÍM NÀO (bindings[id] = Enum.KeyCode hoặc nil)
local bindings = {}
local listeningAction = nil

local connections = {}     -- sống suốt vòng đời script
local charConnections = {} -- gắn với từng nhân vật

local function track(list, conn)
	table.insert(list, conn)
	return conn
end

local function disconnectAll(list)
	for i = #list, 1, -1 do
		list[i]:Disconnect()
		list[i] = nil
	end
end

---------------------------------------------------------------------
-- TỰ LƯU / TẢI CÀI ĐẶT
-- Roblox client thường không cho ghi file. Hàm readfile/writefile/isfile
-- chỉ có ở một số môi trường chạy script (executor). Nếu không có thì
-- script vẫn chạy bình thường, chỉ là không lưu được.
---------------------------------------------------------------------
local function lookup(name)
	local ok, value = pcall(function()
		return getfenv()[name]
	end)
	if ok and type(value) == "function" then
		return value
	end
	return nil
end

local fsWrite, fsRead, fsIsFile = lookup("writefile"), lookup("readfile"), lookup("isfile")
local canSave = (fsWrite ~= nil) and (fsRead ~= nil) and (fsIsFile ~= nil)

local function keyFromName(name)
	if type(name) ~= "string" then return nil end
	local ok, kc = pcall(function()
		return Enum.KeyCode[name]
	end)
	if ok and typeof(kc) == "EnumItem" and kc ~= Enum.KeyCode.Unknown then
		return kc
	end
	return nil
end

local function isValidLanguageSetting(value)
	return value == "auto" or (type(value) == "string" and STRINGS[value] ~= nil)
end

local function loadSettings()
	if not canSave then return nil end
	local ok, data = pcall(function()
		if not fsIsFile(CONFIG.SettingsFile) then return nil end
		return HttpService:JSONDecode(fsRead(CONFIG.SettingsFile))
	end)
	if ok and type(data) == "table" then
		return data
	end
	return nil
end

local function saveSettings()
	if not canSave then return end
	local keys = {}
	for _, a in ipairs(ACTIONS) do
		if bindings[a.id] then
			keys[a.id] = bindings[a.id].Name
		end
	end
	local data = {
		version = 4,
		speedMultiplier = speedMultiplier,
		jumpMultiplier = jumpMultiplier,
		flySpeed = currentFlySpeed,
		autoFlyRespawn = autoFlyRespawn,
		infiniteJump = infiniteJump,
		language = languageSetting,
		hotkeys = keys,
	}
	pcall(function()
		fsWrite(CONFIG.SettingsFile, HttpService:JSONEncode(data))
	end)
end

-- Gom nhiều thay đổi liên tiếp (bấm +/- nhanh) thành 1 lần ghi file
local saveToken = 0
local function scheduleSave()
	if not canSave then return end
	saveToken += 1
	local token = saveToken
	task.delay(0.4, function()
		if token == saveToken then
			saveSettings()
		end
	end)
end

-- Tải cài đặt đã lưu (nếu có)
local savedData = loadSettings()
if savedData then
	if type(savedData.speedMultiplier) == "number" then
		speedMultiplier = math.clamp(savedData.speedMultiplier, 0.1, CONFIG.MaxMultiplier)
	end
	if type(savedData.jumpMultiplier) == "number" then
		jumpMultiplier = math.clamp(savedData.jumpMultiplier, 0.1, CONFIG.MaxMultiplier)
	end
	if type(savedData.flySpeed) == "number" then
		currentFlySpeed = math.clamp(savedData.flySpeed, CONFIG.MinFlySpeed, CONFIG.MaxFlySpeed)
	end
	if type(savedData.autoFlyRespawn) == "boolean" then
		autoFlyRespawn = savedData.autoFlyRespawn
	end
	if type(savedData.infiniteJump) == "boolean" then
		infiniteJump = savedData.infiniteJump
	end
	if isValidLanguageSetting(savedData.language) then
		languageSetting = savedData.language
	end
	if type(savedData.hotkeys) == "table" then
		for _, a in ipairs(ACTIONS) do
			local kc = keyFromName(savedData.hotkeys[a.id])
			if kc then
				bindings[a.id] = kc
			end
		end
	end
end

---------------------------------------------------------------------
-- DỊCH VĂN BẢN
---------------------------------------------------------------------
local function resolveLanguage()
	if languageSetting == "auto" then
		return detectRobloxLanguage()
	end
	return languageSetting
end

currentLang = resolveLanguage()

local function T(key)
	local pack = STRINGS[currentLang]
	return (pack and pack[key]) or STRINGS.en[key] or key
end

local function nativeName(code)
	return LANG_NAMES[code] or code
end

-- Các nhãn tĩnh: tự cập nhật khi đổi ngôn ngữ
local staticTexts = {}

local function loc(obj, key, prefix)
	prefix = prefix or ""
	table.insert(staticTexts, { obj = obj, key = key, prefix = prefix })
	obj.Text = prefix .. T(key)
	return obj
end

local function applyStaticTexts()
	for _, entry in ipairs(staticTexts) do
		entry.obj.Text = entry.prefix .. T(entry.key)
	end
end

---------------------------------------------------------------------
-- 1. GIAO DIỆN (UI NEON)
---------------------------------------------------------------------
-- Xoá UI cũ nếu có (tránh bị nhân đôi khi script chạy lại / respawn)
local oldGui = playerGui:FindFirstChild("SpeedJumpFlyUI_Pro")
if oldGui then oldGui:Destroy() end

local function addCorner(obj, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = obj
	return c
end

-- Border: viền ôm theo khung nút (mặc định của TextButton là viền chữ)
local function addStroke(obj, color, thickness)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color
	s.Thickness = thickness or 1
	s.Parent = obj
	return s
end

local function makeLabel(parent, text, size, position, textSize, color, font)
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = color
	l.TextSize = textSize
	l.Font = font or Enum.Font.GothamBold
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function makeToggleButton(parent, yPos)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -30, 0, 34)
	b.Position = UDim2.new(0, 15, 0, yPos)
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.TextSize = 13
	b.TextWrapped = true
	b.Font = Enum.Font.GothamBold
	b.Parent = parent
	addCorner(b, UDim.new(0, 10))
	return b, addStroke(b, Color3.fromRGB(90, 90, 110), 1.5)
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SpeedJumpFlyUI_Pro"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Ưu tiên lớp hiển thị cao nhất cho bảng điều khiển.
-- DisplayOrder chỉ xếp lớp giữa các ScreenGui cùng hệ thống; nó không tự
-- vượt qua CoreGui của Roblox nếu vẫn parent vào PlayerGui.
local MAX_DISPLAY_ORDER = 2147483647
screenGui.DisplayOrder = MAX_DISPLAY_ORDER
screenGui.IgnoreGuiInset = true

-- Một số môi trường chạy script cung cấp gethui() để đặt giao diện vào
-- lớp GUI riêng của executor. Nếu không có, dùng PlayerGui tiêu chuẩn.
-- Lưu ý: gethui là API riêng của executor, không phải API Roblox chính thức.
local overlayParent = playerGui
local getHiddenUI = lookup("gethui") or lookup("get_hidden_gui") or lookup("gethiddengui")

if getHiddenUI then
    local ok, hiddenUI = pcall(getHiddenUI)
    if ok and typeof(hiddenUI) == "Instance" then
        overlayParent = hiddenUI
    end
end

screenGui.Parent = overlayParent

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.AnchorPoint = Vector2.new(0.5, 0)
mainFrame.Size = UDim2.new(0, PANEL_WIDTH, 0, FULL_HEIGHT)
mainFrame.Position = UDim2.fromScale(DEFAULT_POS_X, DEFAULT_POS_Y)
mainFrame.BackgroundColor3 = Color3.fromRGB(6, 12, 28)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui
addCorner(mainFrame, UDim.new(0, 18))
addStroke(mainFrame, Color3.fromRGB(0, 140, 255), 2.5)

-- Tự thu nhỏ UI cho vừa màn hình nhỏ / điện thoại
local uiScale = Instance.new("UIScale")
uiScale.Parent = mainFrame

local userMoved = false

local function placeDefault()
	if userMoved then return end
	local cam = workspace.CurrentCamera
	if not cam then return end
	local view = cam.ViewportSize
	if view.X <= 0 or view.Y <= 0 then return end

	local w = PANEL_WIDTH * uiScale.Scale
	local h = FULL_HEIGHT * uiScale.Scale
	local halfW = (w / 2 + 8) / view.X
	local x = math.clamp(DEFAULT_POS_X, halfW, 1 - halfW)
	local y = math.clamp(DEFAULT_POS_Y, 0, math.max(0, (view.Y - h - 8) / view.Y))
	mainFrame.Position = UDim2.fromScale(x, y)
end

local function fitToScreen()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local view = cam.ViewportSize
	uiScale.Scale = math.clamp(math.min((view.X - 16) / PANEL_WIDTH, (view.Y - 40) / FULL_HEIGHT), 0.5, 1)
	placeDefault()
end
fitToScreen()
if workspace.CurrentCamera then
	track(connections, workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen))
end

---------------------------------------------------------------------
-- HEADER
---------------------------------------------------------------------
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
header.BackgroundTransparency = 1
header.Parent = mainFrame

local titleLabel = makeLabel(header, "", UDim2.new(0, 190, 1, 0), UDim2.new(0, 16, 0, 0), 19, Color3.fromRGB(255, 255, 255))
titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
loc(titleLabel, "title", "⚡ ")

local function makeHeaderButton(text, xOffset, color, textSize)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 32, 0, 32)
	b.Position = UDim2.new(1, xOffset, 0.5, -16)
	b.BackgroundColor3 = color
	b.Text = text
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.TextSize = textSize
	b.Font = Enum.Font.GothamBold
	b.Parent = header
	addCorner(b, UDim.new(0, 8))
	return b
end

local btnKeys = makeHeaderButton("⌨", -116, Color3.fromRGB(10, 35, 80), 16)
local btnMinimize = makeHeaderButton("−", -78, Color3.fromRGB(10, 35, 80), 20)
local btnClose = makeHeaderButton("X", -40, Color3.fromRGB(180, 25, 35), 16)

---------------------------------------------------------------------
-- TRANG CHÍNH
---------------------------------------------------------------------
local contentFrame = Instance.new("Frame")
contentFrame.Name = "ContentFrame"
contentFrame.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT)
contentFrame.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

local function createInputRow(labelKey, icon, colorTheme, yPos)
	local label = makeLabel(contentFrame, "", UDim2.new(1, -30, 0, 18), UDim2.new(0, 15, 0, yPos), 13, Color3.fromRGB(200, 225, 255))
	label.TextTruncate = Enum.TextTruncate.AtEnd
	loc(label, labelKey, icon .. " ")

	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, -30, 0, 42)
	container.Position = UDim2.new(0, 15, 0, yPos + 22)
	container.BackgroundTransparency = 1
	container.Parent = contentFrame

	local btnMinus = Instance.new("TextButton")
	btnMinus.Size = UDim2.new(0, 44, 1, 0)
	btnMinus.BackgroundColor3 = colorTheme
	btnMinus.Text = "−"
	btnMinus.TextColor3 = Color3.fromRGB(255, 255, 255)
	btnMinus.TextSize = 24
	btnMinus.Font = Enum.Font.GothamBold
	btnMinus.Parent = container
	addCorner(btnMinus, UDim.new(0, 8))

	local textBox = Instance.new("TextBox")
	textBox.Size = UDim2.new(1, -104, 1, 0)
	textBox.Position = UDim2.new(0, 52, 0, 0)
	textBox.BackgroundColor3 = Color3.fromRGB(3, 8, 20)
	textBox.TextColor3 = Color3.fromRGB(0, 220, 255)
	textBox.TextSize = 17
	textBox.Font = Enum.Font.GothamBlack
	textBox.ClearTextOnFocus = false
	textBox.Parent = container
	addCorner(textBox, UDim.new(0, 8))
	addStroke(textBox, Color3.fromRGB(20, 60, 120), 1)

	local btnPlus = Instance.new("TextButton")
	btnPlus.Size = UDim2.new(0, 44, 1, 0)
	btnPlus.Position = UDim2.new(1, -44, 0, 0)
	btnPlus.BackgroundColor3 = colorTheme
	btnPlus.Text = "+"
	btnPlus.TextColor3 = Color3.fromRGB(255, 255, 255)
	btnPlus.TextSize = 24
	btnPlus.Font = Enum.Font.GothamBold
	btnPlus.Parent = container
	addCorner(btnPlus, UDim.new(0, 8))

	return btnMinus, textBox, btnPlus
end

local btnSpeedMinus, speedInput, btnSpeedPlus = createInputRow("walk", "⚡", Color3.fromRGB(0, 110, 230), 2)
local btnJumpMinus, jumpInput, btnJumpPlus = createInputRow("jump", "🦘", Color3.fromRGB(140, 50, 220), 70)
local btnFlySpdMinus, flySpdInput, btnFlySpdPlus = createInputRow("flyspd", "🚀", Color3.fromRGB(220, 110, 20), 138)

-- Nút Bật/Tắt Fly
local btnFly = Instance.new("TextButton")
btnFly.Size = UDim2.new(1, -30, 0, 44)
btnFly.Position = UDim2.new(0, 15, 0, 210)
btnFly.BackgroundColor3 = Color3.fromRGB(4, 45, 26)
btnFly.TextColor3 = Color3.fromRGB(255, 255, 255)
btnFly.TextSize = 18
btnFly.Font = Enum.Font.GothamBold
btnFly.Parent = contentFrame
addCorner(btnFly, UDim.new(1, 0))
local flyStroke = addStroke(btnFly, Color3.fromRGB(0, 255, 130), 2)

-- Nút Auto Fly khi hồi sinh
local btnAuto, autoStroke = makeToggleButton(contentFrame, 262)

-- Nút Infinite Jump
local btnInf, infStroke = makeToggleButton(contentFrame, 302)

-- Dòng gợi ý phím tắt (tự đổi theo phím bạn đã gán)
local hintLabel = makeLabel(contentFrame, "", UDim2.new(1, -30, 0, 16), UDim2.new(0, 15, 0, 344), 11, Color3.fromRGB(120, 150, 190), Enum.Font.Gotham)
hintLabel.TextXAlignment = Enum.TextXAlignment.Center
hintLabel.TextTruncate = Enum.TextTruncate.AtEnd

---------------------------------------------------------------------
-- TRANG PHÍM TẮT & NGÔN NGỮ
---------------------------------------------------------------------
local keysPage = Instance.new("Frame")
keysPage.Name = "KeysPage"
keysPage.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT)
keysPage.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
keysPage.BackgroundTransparency = 1
keysPage.Visible = false
keysPage.Parent = mainFrame

local keysTitle = makeLabel(keysPage, "", UDim2.new(1, -30, 0, 20), UDim2.new(0, 15, 0, 4), 15, Color3.fromRGB(255, 255, 255))
loc(keysTitle, "keys_title", "⌨ ")

local keysDesc = makeLabel(keysPage, "", UDim2.new(1, -30, 0, 40), UDim2.new(0, 15, 0, 26), 11, Color3.fromRGB(140, 165, 205), Enum.Font.Gotham)
keysDesc.TextWrapped = true
keysDesc.TextYAlignment = Enum.TextYAlignment.Top
loc(keysDesc, "keys_desc")

local bindButtons, bindStrokes, clearButtons = {}, {}, {}

local function createKeyRow(action, yPos)
	local lbl = makeLabel(keysPage, "", UDim2.new(0, 124, 0, 34), UDim2.new(0, 15, 0, yPos), 12, Color3.fromRGB(200, 225, 255))
	lbl.TextWrapped = true
	loc(lbl, action.labelKey, action.icon .. " ")

	local btnBind = Instance.new("TextButton")
	btnBind.Size = UDim2.new(0, 114, 0, 34)
	btnBind.Position = UDim2.new(0, 145, 0, yPos)
	btnBind.TextColor3 = Color3.fromRGB(255, 255, 255)
	btnBind.TextSize = 13
	btnBind.TextTruncate = Enum.TextTruncate.AtEnd
	btnBind.Font = Enum.Font.GothamBold
	btnBind.Parent = keysPage
	addCorner(btnBind, UDim.new(0, 8))
	bindStrokes[action.id] = addStroke(btnBind, Color3.fromRGB(90, 90, 110), 1.5)
	bindButtons[action.id] = btnBind

	local btnClear = Instance.new("TextButton")
	btnClear.Size = UDim2.new(0, 40, 0, 34)
	btnClear.Position = UDim2.new(0, 265, 0, yPos)
	btnClear.BackgroundColor3 = Color3.fromRGB(110, 25, 35)
	btnClear.Text = "✕"
	btnClear.TextColor3 = Color3.fromRGB(255, 255, 255)
	btnClear.TextSize = 15
	btnClear.Font = Enum.Font.GothamBold
	btnClear.Parent = keysPage
	addCorner(btnClear, UDim.new(0, 8))
	clearButtons[action.id] = btnClear
end

for i, action in ipairs(ACTIONS) do
	createKeyRow(action, 70 + (i - 1) * 40)
end

-- Chọn ngôn ngữ: ‹ [tên] ›
local langLabel = makeLabel(keysPage, "", UDim2.new(1, -30, 0, 16), UDim2.new(0, 15, 0, 232), 12, Color3.fromRGB(200, 225, 255))
loc(langLabel, "lang", "🌐 ")

local function makeArrowButton(text, position)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 40, 0, 34)
	b.Position = position
	b.BackgroundColor3 = Color3.fromRGB(10, 35, 80)
	b.Text = text
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.TextSize = 20
	b.Font = Enum.Font.GothamBold
	b.Parent = keysPage
	addCorner(b, UDim.new(0, 8))
	return b
end

local btnLangPrev = makeArrowButton("‹", UDim2.new(0, 15, 0, 250))
local btnLangNext = makeArrowButton("›", UDim2.new(1, -55, 0, 250))

local btnLangName = Instance.new("TextButton")
btnLangName.Size = UDim2.new(1, -122, 0, 34)
btnLangName.Position = UDim2.new(0, 61, 0, 250)
btnLangName.BackgroundColor3 = Color3.fromRGB(8, 50, 80)
btnLangName.TextColor3 = Color3.fromRGB(255, 255, 255)
btnLangName.TextSize = 12
btnLangName.TextWrapped = true
btnLangName.Font = Enum.Font.GothamBold
btnLangName.Parent = keysPage
addCorner(btnLangName, UDim.new(0, 8))
addStroke(btnLangName, Color3.fromRGB(0, 200, 255), 1.5)

local saveStatusLabel = makeLabel(keysPage, "", UDim2.new(1, -30, 0, 28), UDim2.new(0, 15, 0, 290), 11, Color3.fromRGB(140, 165, 205), Enum.Font.Gotham)
saveStatusLabel.TextWrapped = true
saveStatusLabel.TextYAlignment = Enum.TextYAlignment.Top

local btnBack = Instance.new("TextButton")
btnBack.Size = UDim2.new(1, -30, 0, 38)
btnBack.Position = UDim2.new(0, 15, 0, 324)
btnBack.BackgroundColor3 = Color3.fromRGB(10, 35, 80)
btnBack.TextColor3 = Color3.fromRGB(255, 255, 255)
btnBack.TextSize = 15
btnBack.Font = Enum.Font.GothamBold
btnBack.Parent = keysPage
addCorner(btnBack, UDim.new(0, 10))
addStroke(btnBack, Color3.fromRGB(0, 140, 255), 1.5)
loc(btnBack, "back", "←  ")

---------------------------------------------------------------------
-- 2. LOGIC SPEED / JUMP / INFINITE JUMP + CẬP NHẬT UI
---------------------------------------------------------------------
local function parseNumber(text)
	local clean = text:gsub("[^%d%.]", "")
	return tonumber(clean)
end

-- Bước tăng/giảm: 0.5 khi <= 5, 1.0 khi lớn hơn
local function stepValue(v, dir)
	local step = ((dir > 0 and v < 5) or (dir < 0 and v <= 5)) and 0.5 or 1
	v = v + step * dir
	v = math.floor(v * 10 + 0.5) / 10
	return math.clamp(v, 0.1, CONFIG.MaxMultiplier)
end

-- Đọc giá trị mặc định thật của game thay vì gán cứng
local function captureDefaults()
	if not humanoid then return end
	if humanoid.WalkSpeed > 0 then
		defaultSpeed = humanoid.WalkSpeed
	end
	if humanoid.UseJumpPower then
		if humanoid.JumpPower > 0 then defaultJumpPower = humanoid.JumpPower end
	else
		if humanoid.JumpHeight > 0 then defaultJumpHeight = humanoid.JumpHeight end
	end
end

local function updateSpeedUI()
	speedInput.Text = string.format("%.1fx", speedMultiplier)
	if humanoid then
		humanoid.WalkSpeed = defaultSpeed * speedMultiplier
	end
end

local function updateJumpUI()
	jumpInput.Text = string.format("%.1fx", jumpMultiplier)
	if humanoid then
		if humanoid.UseJumpPower then
			humanoid.JumpPower = defaultJumpPower * jumpMultiplier
		else
			humanoid.JumpHeight = defaultJumpHeight * jumpMultiplier
		end
	end
end

local function updateFlySpeedUI()
	flySpdInput.Text = tostring(math.round(currentFlySpeed))
end

local function updateAutoUI()
	local state = T(autoFlyRespawn and "on" or "off")
	btnAuto.Text = "🔁 " .. T("auto") .. ": " .. state
	if autoFlyRespawn then
		btnAuto.BackgroundColor3 = Color3.fromRGB(8, 50, 80)
		autoStroke.Color = Color3.fromRGB(0, 200, 255)
	else
		btnAuto.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
		autoStroke.Color = Color3.fromRGB(90, 90, 110)
	end
end

local function updateInfJumpUI()
	local state = T(infiniteJump and "on" or "off")
	btnInf.Text = "∞ " .. T("inf") .. ": " .. state
	if infiniteJump then
		btnInf.BackgroundColor3 = Color3.fromRGB(50, 20, 90)
		infStroke.Color = Color3.fromRGB(170, 90, 255)
	else
		btnInf.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
		infStroke.Color = Color3.fromRGB(90, 90, 110)
	end
end

local function toggleInfJump()
	infiniteJump = not infiniteJump
	updateInfJumpUI()
	scheduleSave()
end

local function setFlyUI(active)
	if not (btnFly and btnFly.Parent) then return end
	if active then
		btnFly.Text = "✈  " .. T("fly_off")
		btnFly.BackgroundColor3 = Color3.fromRGB(60, 15, 20)
		flyStroke.Color = Color3.fromRGB(255, 60, 80)
	else
		btnFly.Text = "✈  " .. T("fly_on")
		btnFly.BackgroundColor3 = Color3.fromRGB(4, 45, 26)
		flyStroke.Color = Color3.fromRGB(0, 255, 130)
	end
end

-- Giảm lực rơi khi chạm đất (chỉ phía client, game tính sát thương ở server thì có thể vẫn mất máu)
local function setupFallProtection()
	track(charConnections, humanoid.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Landed and rootPart then
			local v = rootPart.AssemblyLinearVelocity
			rootPart.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
		end
	end))
end

---------------------------------------------------------------------
-- 3. LOGIC PHÍM TẮT & NGÔN NGỮ
---------------------------------------------------------------------
-- "LeftShift" -> "L-Shift" cho gọn
local function displayKey(keyCode)
	local name = keyCode.Name
	local rest = name:match("^Left(%u%a+)$")
	if rest then return "L-" .. rest end
	rest = name:match("^Right(%u%a+)$")
	if rest then return "R-" .. rest end
	return name
end

local function updateHint()
	local parts = {}
	for _, a in ipairs(ACTIONS) do
		if bindings[a.id] then
			table.insert(parts, string.format("[%s] %s", displayKey(bindings[a.id]), T(a.shortKey)))
		end
	end
	if #parts > 0 then
		hintLabel.Text = table.concat(parts, "  •  ")
	else
		hintLabel.Text = T("hint_none")
	end
end

local function refreshBindUI()
	for _, a in ipairs(ACTIONS) do
		local btn = bindButtons[a.id]
		local stroke = bindStrokes[a.id]
		if listeningAction == a.id then
			btn.Text = "⌨ " .. T("press")
			btn.BackgroundColor3 = Color3.fromRGB(70, 55, 10)
			stroke.Color = Color3.fromRGB(255, 200, 0)
		elseif bindings[a.id] then
			btn.Text = displayKey(bindings[a.id])
			btn.BackgroundColor3 = Color3.fromRGB(8, 50, 80)
			stroke.Color = Color3.fromRGB(0, 200, 255)
		else
			btn.Text = T("not_set")
			btn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
			stroke.Color = Color3.fromRGB(90, 90, 110)
		end
	end
	updateHint()
end

local function stopListening()
	if listeningAction then
		listeningAction = nil
		refreshBindUI()
	end
end

local function startListening(id)
	listeningAction = id
	refreshBindUI()
end

local function assignKey(id, keyCode)
	-- Một phím chỉ dùng cho một hành động
	for _, a in ipairs(ACTIONS) do
		if a.id ~= id and bindings[a.id] == keyCode then
			bindings[a.id] = nil
		end
	end
	bindings[id] = keyCode
	upHeld, downHeld = false, false
	listeningAction = nil
	refreshBindUI()
	scheduleSave()
end

local function clearKey(id)
	bindings[id] = nil
	upHeld, downHeld = false, false
	listeningAction = nil
	refreshBindUI()
	scheduleSave()
end

local function updateSaveStatus()
	if canSave then
		saveStatusLabel.Text = "💾 " .. T("save_on") .. "  (" .. CONFIG.SettingsFile .. ")"
	else
		saveStatusLabel.Text = "💾 " .. T("save_off")
	end
end

local function updateLangUI()
	if languageSetting == "auto" then
		btnLangName.Text = T("lang_auto") .. " · " .. nativeName(currentLang)
	else
		btnLangName.Text = nativeName(languageSetting)
	end
end

-- Áp dụng ngôn ngữ cho toàn bộ UI
local function applyLanguage()
	currentLang = resolveLanguage()
	applyStaticTexts()
	setFlyUI(isFlying)
	updateAutoUI()
	updateInfJumpUI()
	refreshBindUI()
	updateSaveStatus()
	updateLangUI()
end

local function cycleLanguage(dir)
	local index = table.find(LANG_ORDER, languageSetting) or 1
	index = ((index - 1 + dir) % #LANG_ORDER) + 1
	languageSetting = LANG_ORDER[index]
	applyLanguage()
	scheduleSave()
end

---------------------------------------------------------------------
-- 4. LOGIC FLY
---------------------------------------------------------------------
local flyAttachment, linearVelocity, alignOrientation
local savedCollide = {}

local function startFly()
	if isFlying then return end
	if not (character and rootPart and humanoid) or humanoid.Health <= 0 then return end
	isFlying = true
	setFlyUI(true)

	flyAttachment = Instance.new("Attachment")
	flyAttachment.Name = "FlyAttachment"
	flyAttachment.Parent = rootPart

	linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Attachment0 = flyAttachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	linearVelocity.MaxForce = math.huge
	linearVelocity.VectorVelocity = Vector3.zero
	linearVelocity.Parent = rootPart

	alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = flyAttachment
	alignOrientation.RigidityEnabled = true
	alignOrientation.CFrame = rootPart.CFrame
	alignOrientation.Parent = rootPart

	humanoid.PlatformStand = true
end

-- died = true: nhân vật đã chết, chỉ dọn dẹp, không cần dựng lại tư thế đứng
local function stopFly(died)
	if not isFlying then return end
	isFlying = false
	setFlyUI(false)

	if linearVelocity then linearVelocity:Destroy(); linearVelocity = nil end
	if alignOrientation then alignOrientation:Destroy(); alignOrientation = nil end
	if flyAttachment then flyAttachment:Destroy(); flyAttachment = nil end

	-- Trả lại va chạm như cũ
	for part in pairs(savedCollide) do
		if part.Parent then
			part.CanCollide = true
		end
	end
	table.clear(savedCollide)

	if died or not (character and rootPart and humanoid) then return end

	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero

	local look = workspace.CurrentCamera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.001 then
		rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + flat.Unit)
	end

	humanoid.PlatformStand = false
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	task.defer(function()
		if humanoid and humanoid.Health > 0 then
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end
	end)
end

local function toggleFly()
	if isFlying then stopFly() else startFly() end
end

-- Hướng bay: joystick/WASD theo camera (có cả góc nhìn lên/xuống) + phím lên/xuống (nếu đã gán)
local function getFlyDirection(cam)
	local dir = Vector3.zero
	local moveDir = humanoid.MoveDirection

	if moveDir.Magnitude > 0 then
		local look = cam.CFrame.LookVector
		local right = cam.CFrame.RightVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		local flatRight = Vector3.new(right.X, 0, right.Z)

		local fwd = flatLook.Magnitude > 0.001 and moveDir:Dot(flatLook.Unit) or 0
		local side = flatRight.Magnitude > 0.001 and moveDir:Dot(flatRight.Unit) or 0
		dir = look * fwd + right * side
	end

	if upHeld then dir += Vector3.yAxis end
	if downHeld then dir -= Vector3.yAxis end

	if dir.Magnitude > 0.001 then
		return dir.Unit
	end
	return Vector3.zero
end

-- Xuyên tường khi bay
track(connections, RunService.Stepped:Connect(function()
	if not isFlying or not character then return end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.CanCollide then
			savedCollide[part] = true
			part.CanCollide = false
		end
	end
end))

track(connections, RunService.RenderStepped:Connect(function()
	if not isFlying or not rootPart or not humanoid or not linearVelocity or not alignOrientation then return end
	local cam = workspace.CurrentCamera
	alignOrientation.CFrame = cam.CFrame
	linearVelocity.VectorVelocity = getFlyDirection(cam) * currentFlySpeed
end))

-- Infinite Jump: mỗi lần yêu cầu nhảy (Space / nút nhảy trên điện thoại) đều nhảy được
track(connections, UserInputService.JumpRequest:Connect(function()
	if infiniteJump and not isFlying and humanoid and humanoid.Health > 0 then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end))

-- Nhận phím: vừa dùng để gán phím tắt, vừa để kích hoạt phím tắt đã gán
track(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- Đang chờ gán phím
	if listeningAction then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.Escape then
				stopListening()
			elseif input.KeyCode ~= Enum.KeyCode.Unknown then
				assignKey(listeningAction, input.KeyCode)
			end
		end
		return
	end

	if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end

	local kc = input.KeyCode
	if bindings.Toggle and kc == bindings.Toggle then
		toggleFly()
	elseif bindings.Up and kc == bindings.Up then
		upHeld = true
	elseif bindings.Down and kc == bindings.Down then
		downHeld = true
	elseif bindings.InfJump and kc == bindings.InfJump then
		toggleInfJump()
	end
end))

track(connections, UserInputService.InputEnded:Connect(function(input)
	if bindings.Up and input.KeyCode == bindings.Up then
		upHeld = false
	elseif bindings.Down and input.KeyCode == bindings.Down then
		downHeld = false
	end
end))

---------------------------------------------------------------------
-- 5. XỬ LÝ CHẾT / HỒI SINH (AUTO FLY)
---------------------------------------------------------------------
local function onCharacterAdded(newChar)
	-- Nhớ trạng thái fly của nhân vật cũ rồi dọn dẹp
	local wasFlying = wasFlyingOnDeath or isFlying
	if isFlying then stopFly(true) end
	wasFlyingOnDeath = false
	disconnectAll(charConnections)

	character = newChar
	humanoid = newChar:WaitForChild("Humanoid")
	rootPart = newChar:WaitForChild("HumanoidRootPart")

	captureDefaults()
	setupFallProtection()

	-- Chết: gỡ lực bay để xác rơi tự nhiên, nhớ là đang fly
	track(charConnections, humanoid.Died:Connect(function()
		wasFlyingOnDeath = isFlying
		if isFlying then stopFly(true) end
	end))

	task.wait(0.1)
	if character ~= newChar then return end
	updateSpeedUI()
	updateJumpUI()

	-- Tự động bật fly lại sau khi hồi sinh
	if autoFlyRespawn and (wasFlying or CONFIG.AlwaysFlyOnRespawn) then
		task.wait(0.25) -- chờ game dịch chuyển nhân vật về điểm spawn xong
		if character == newChar and humanoid.Health > 0 then
			startFly()
		end
	end
end

track(connections, player.CharacterAdded:Connect(onCharacterAdded))
if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end

-- Đổi ngôn ngữ Roblox khi đang chơi -> UI đổi theo (nếu đang để "Tự động")
pcall(function()
	track(connections, LocalizationService:GetPropertyChangedSignal("RobloxLocaleId"):Connect(function()
		if languageSetting == "auto" then
			applyLanguage()
		end
	end))
end)

---------------------------------------------------------------------
-- 6. SỰ KIỆN NÚT BẤM & Ô NHẬP
---------------------------------------------------------------------
updateSpeedUI()
updateJumpUI()
updateFlySpeedUI()
applyLanguage() -- điền toàn bộ chữ: nút Fly, Auto, Infinite Jump, phím tắt, ngôn ngữ...

-- Tạo file cài đặt lần đầu (nếu môi trường hỗ trợ và chưa có file)
if canSave and not savedData then
	saveSettings()
end

-- Walk Speed
speedInput.FocusLost:Connect(function()
	local num = parseNumber(speedInput.Text)
	if num and num > 0 then
		speedMultiplier = math.clamp(num, 0.1, CONFIG.MaxMultiplier)
	end
	updateSpeedUI()
	scheduleSave()
end)
btnSpeedPlus.MouseButton1Click:Connect(function()
	speedMultiplier = stepValue(speedMultiplier, 1)
	updateSpeedUI()
	scheduleSave()
end)
btnSpeedMinus.MouseButton1Click:Connect(function()
	speedMultiplier = stepValue(speedMultiplier, -1)
	updateSpeedUI()
	scheduleSave()
end)

-- Jump Power
jumpInput.FocusLost:Connect(function()
	local num = parseNumber(jumpInput.Text)
	if num and num > 0 then
		jumpMultiplier = math.clamp(num, 0.1, CONFIG.MaxMultiplier)
	end
	updateJumpUI()
	scheduleSave()
end)
btnJumpPlus.MouseButton1Click:Connect(function()
	jumpMultiplier = stepValue(jumpMultiplier, 1)
	updateJumpUI()
	scheduleSave()
end)
btnJumpMinus.MouseButton1Click:Connect(function()
	jumpMultiplier = stepValue(jumpMultiplier, -1)
	updateJumpUI()
	scheduleSave()
end)

-- Fly Speed (bước nhảy tăng dần theo tốc độ hiện tại)
local function flyStep()
	if currentFlySpeed >= 200 then return 50 end
	if currentFlySpeed >= 100 then return 25 end
	return 10
end

flySpdInput.FocusLost:Connect(function()
	local num = parseNumber(flySpdInput.Text)
	if num and num > 0 then
		currentFlySpeed = math.clamp(num, CONFIG.MinFlySpeed, CONFIG.MaxFlySpeed)
	end
	updateFlySpeedUI()
	scheduleSave()
end)
btnFlySpdPlus.MouseButton1Click:Connect(function()
	currentFlySpeed = math.min(CONFIG.MaxFlySpeed, currentFlySpeed + flyStep())
	updateFlySpeedUI()
	scheduleSave()
end)
btnFlySpdMinus.MouseButton1Click:Connect(function()
	currentFlySpeed = math.max(CONFIG.MinFlySpeed, currentFlySpeed - flyStep())
	updateFlySpeedUI()
	scheduleSave()
end)

btnFly.MouseButton1Click:Connect(toggleFly)

btnAuto.MouseButton1Click:Connect(function()
	autoFlyRespawn = not autoFlyRespawn
	updateAutoUI()
	scheduleSave()
end)

btnInf.MouseButton1Click:Connect(toggleInfJump)

-- Trang phím tắt & ngôn ngữ
for _, a in ipairs(ACTIONS) do
	bindButtons[a.id].MouseButton1Click:Connect(function()
		if listeningAction == a.id then
			stopListening()
		else
			startListening(a.id)
		end
	end)
	clearButtons[a.id].MouseButton1Click:Connect(function()
		clearKey(a.id)
	end)
end

btnLangPrev.MouseButton1Click:Connect(function() cycleLanguage(-1) end)
btnLangNext.MouseButton1Click:Connect(function() cycleLanguage(1) end)
btnLangName.MouseButton1Click:Connect(function() cycleLanguage(1) end)

---------------------------------------------------------------------
-- 7. CHUYỂN TRANG, THU NHỎ & ĐÓNG (X)
---------------------------------------------------------------------
local isMinimized = false
local currentPage = "main"

local function showPage(name)
	currentPage = name
	contentFrame.Visible = (name == "main") and not isMinimized
	keysPage.Visible = (name == "keys") and not isMinimized
	if name ~= "keys" or isMinimized then
		stopListening()
	end
end

btnKeys.MouseButton1Click:Connect(function()
	showPage(currentPage == "keys" and "main" or "keys")
end)

btnBack.MouseButton1Click:Connect(function()
	showPage("main")
end)

btnMinimize.MouseButton1Click:Connect(function()
	isMinimized = not isMinimized
	if isMinimized then
		showPage(currentPage) -- ẩn cả hai trang
		mainFrame:TweenSize(UDim2.new(0, PANEL_WIDTH, 0, HEADER_HEIGHT), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
		btnMinimize.Text = "＋"
	else
		mainFrame:TweenSize(UDim2.new(0, PANEL_WIDTH, 0, FULL_HEIGHT), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true, function()
			showPage(currentPage)
		end)
		btnMinimize.Text = "−"
	end
end)

btnClose.MouseButton1Click:Connect(function()
	saveSettings()
	stopFly()

	if humanoid then
		humanoid.WalkSpeed = defaultSpeed
		if humanoid.UseJumpPower then
			humanoid.JumpPower = defaultJumpPower
		else
			humanoid.JumpHeight = defaultJumpHeight
		end
	end

	disconnectAll(connections)
	disconnectAll(charConnections)
	screenGui:Destroy()
end)

---------------------------------------------------------------------
-- 8. KÉO THẢ GIAO DIỆN
---------------------------------------------------------------------
local dragging, dragInput, dragStart, startPos

header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = mainFrame.Position

		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

header.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

track(connections, UserInputService.InputChanged:Connect(function(input)
	if dragging and input == dragInput then
		userMoved = true
		local delta = (input.Position - dragStart) / uiScale.Scale
		mainFrame.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end))
