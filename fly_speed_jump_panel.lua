-- LocalScript: Đặt vào StarterGui hoặc StarterPlayerScripts trong Roblox Studio

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

---------------------------------------------------------------------
-- THIẾT LẬP MẶC ĐỊNH
---------------------------------------------------------------------
local defaultSpeed = 16
local defaultJumpPower = 50
local defaultJumpHeight = 7.2

local speedMultiplier = 1.0
local jumpMultiplier = 1.0
local currentFlySpeed = 50 -- Tốc độ bay mặc định

---------------------------------------------------------------------
-- 1. TẠO GIAO DIỆN (UI NEON)
---------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SpeedJumpFlyUI_Pro"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Khung chính (chiều cao 390 để đủ chỗ cho Walk, Jump, Fly Speed và Fly Toggle)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 320, 0, 390)
mainFrame.Position = UDim2.new(0.5, -160, 0.25, -195)
mainFrame.BackgroundColor3 = Color3.fromRGB(6, 12, 28)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 18)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Thickness = 2.5
mainStroke.Color = Color3.fromRGB(0, 140, 255)
mainStroke.Parent = mainFrame

---------------------------------------------------------------------
-- HEADER (Tiêu đề, Nút Ẩn, Nút Đóng)
---------------------------------------------------------------------
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 48)
header.BackgroundTransparency = 1
header.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 180, 1, 0)
titleLabel.Position = UDim2.new(0, 16, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "⚡ Control Panel"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 20
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

-- Nút Thu nhỏ (-)
local btnMinimize = Instance.new("TextButton")
btnMinimize.Size = UDim2.new(0, 32, 0, 32)
btnMinimize.Position = UDim2.new(1, -78, 0.5, -16)
btnMinimize.BackgroundColor3 = Color3.fromRGB(10, 35, 80)
btnMinimize.Text = "−"
btnMinimize.TextColor3 = Color3.fromRGB(255, 255, 255)
btnMinimize.TextSize = 20
btnMinimize.Font = Enum.Font.GothamBold
btnMinimize.Parent = header
Instance.new("UICorner", btnMinimize).CornerRadius = UDim.new(0, 8)

-- Nút Đóng Hẳn (X)
local btnClose = Instance.new("TextButton")
btnClose.Size = UDim2.new(0, 32, 0, 32)
btnClose.Position = UDim2.new(1, -40, 0.5, -16)
btnClose.BackgroundColor3 = Color3.fromRGB(180, 25, 35)
btnClose.Text = "X"
btnClose.TextColor3 = Color3.fromRGB(255, 255, 255)
btnClose.TextSize = 16
btnClose.Font = Enum.Font.GothamBold
btnClose.Parent = header
Instance.new("UICorner", btnClose).CornerRadius = UDim.new(0, 8)

---------------------------------------------------------------------
-- PHẦN NỘI DUNG (CONTENT FRAME)
---------------------------------------------------------------------
local contentFrame = Instance.new("Frame")
contentFrame.Name = "ContentFrame"
contentFrame.Size = UDim2.new(1, 0, 1, -48)
contentFrame.Position = UDim2.new(0, 0, 0, 48)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

-- Helper tạo hàng chỉnh số
local function createInputRow(labelText, colorTheme, yPos)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -30, 0, 18)
    label.Position = UDim2.new(0, 15, 0, yPos)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(200, 225, 255)
    label.TextSize = 13
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = contentFrame

    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -30, 0, 42)
    container.Position = UDim2.new(0, 15, 0, yPos + 22)
    container.BackgroundTransparency = 1
    container.Parent = contentFrame

    local btnMinus = Instance.new("TextButton")
    btnMinus.Size = UDim2.new(0, 44, 1, 0)
    btnMinus.Position = UDim2.new(0, 0, 0, 0)
    btnMinus.BackgroundColor3 = colorTheme
    btnMinus.Text = "−"
    btnMinus.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnMinus.TextSize = 24
    btnMinus.Font = Enum.Font.GothamBold
    btnMinus.Parent = container
    Instance.new("UICorner", btnMinus).CornerRadius = UDim.new(0, 8)

    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(1, -104, 1, 0)
    textBox.Position = UDim2.new(0, 52, 0, 0)
    textBox.BackgroundColor3 = Color3.fromRGB(3, 8, 20)
    textBox.TextColor3 = Color3.fromRGB(0, 220, 255)
    textBox.TextSize = 17
    textBox.Font = Enum.Font.GothamBlack
    textBox.ClearTextOnFocus = false
    textBox.Parent = container
    Instance.new("UICorner", textBox).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", textBox)
    stroke.Color = Color3.fromRGB(20, 60, 120)

    local btnPlus = Instance.new("TextButton")
    btnPlus.Size = UDim2.new(0, 44, 1, 0)
    btnPlus.Position = UDim2.new(1, -44, 0, 0)
    btnPlus.BackgroundColor3 = colorTheme
    btnPlus.Text = "+"
    btnPlus.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnPlus.TextSize = 24
    btnPlus.Font = Enum.Font.GothamBold
    btnPlus.Parent = container
    Instance.new("UICorner", btnPlus).CornerRadius = UDim.new(0, 8)

    return btnMinus, textBox, btnPlus
end

-- 1. Hàng Tốc độ chạy (Walk Speed)
local btnSpeedMinus, speedInput, btnSpeedPlus = createInputRow("⚡ Tốc độ chạy (Walk Speed)", Color3.fromRGB(0, 110, 230), 4)

-- 2. Hàng Sức nhảy (Jump Power)
local btnJumpMinus, jumpInput, btnJumpPlus = createInputRow("🦘 Sức nhảy (Jump Power)", Color3.fromRGB(140, 50, 220), 76)

-- 3. Hàng Tốc độ bay (Fly Speed)
local btnFlySpdMinus, flySpdInput, btnFlySpdPlus = createInputRow("🚀 Tốc độ bay (Fly Speed)", Color3.fromRGB(220, 110, 20), 148)

-- 4. Nút Bật/Tắt Fly
local btnFly = Instance.new("TextButton")
btnFly.Size = UDim2.new(1, -30, 0, 46)
btnFly.Position = UDim2.new(0, 15, 0, 226)
btnFly.BackgroundColor3 = Color3.fromRGB(4, 45, 26)
btnFly.Text = "✈  Bật Fly"
btnFly.TextColor3 = Color3.fromRGB(255, 255, 255)
btnFly.TextSize = 18
btnFly.Font = Enum.Font.GothamBold
btnFly.Parent = contentFrame

local flyCorner = Instance.new("UICorner", btnFly)
flyCorner.CornerRadius = UDim.new(1, 0)

local flyStroke = Instance.new("UIStroke", btnFly)
flyStroke.Color = Color3.fromRGB(0, 255, 130)
flyStroke.Thickness = 2.0

---------------------------------------------------------------------
-- 2. LOGIC CẬP NHẬT GIÁ TRỊ & CHỐNG SÁT THƯƠNG RƠI
---------------------------------------------------------------------
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

-- Chống mất máu khi nhảy cao (Fall Damage Protection)
local stateConn
local function setupFallProtection(targetHumanoid)
    if stateConn then stateConn:Disconnect() end
    stateConn = targetHumanoid.StateChanged:Connect(function(oldState, newState)
        if newState == Enum.HumanoidStateType.Landed then
            if rootPart then
                -- Triệt tiêu lực rơi khi chạm đất để không bị tính sát thương rơi
                local currentVel = rootPart.AssemblyLinearVelocity
                rootPart.AssemblyLinearVelocity = Vector3.new(currentVel.X, 0, currentVel.Z)
            end
        end
    end)
end

-- Khởi tạo giá trị ban đầu cho UI
updateSpeedUI()
updateJumpUI()
updateFlySpeedUI()
if humanoid then setupFallProtection(humanoid) end

---------------------------------------------------------------------
-- SỰ KIỆN NHẬP DỮ LIỆU & NÚT BẤM
---------------------------------------------------------------------
-- WALK SPEED
speedInput.FocusLost:Connect(function()
    local cleanText = speedInput.Text:gsub("[^%d%.]", "")
    local num = tonumber(cleanText)
    if num and num > 0 then
        speedMultiplier = num
    end
    updateSpeedUI()
end)
btnSpeedPlus.MouseButton1Click:Connect(function()
    speedMultiplier = (speedMultiplier < 5) and (speedMultiplier + 0.5) or (speedMultiplier + 1.0)
    updateSpeedUI()
end)
btnSpeedMinus.MouseButton1Click:Connect(function()
    if speedMultiplier > 1 then
        speedMultiplier = (speedMultiplier <= 5) and (speedMultiplier - 0.5) or (speedMultiplier - 1.0)
    else
        speedMultiplier = math.max(0.1, speedMultiplier - 0.2)
    end
    updateSpeedUI()
end)

-- JUMP POWER
jumpInput.FocusLost:Connect(function()
    local cleanText = jumpInput.Text:gsub("[^%d%.]", "")
    local num = tonumber(cleanText)
    if num and num > 0 then
        jumpMultiplier = num
    end
    updateJumpUI()
end)
btnJumpPlus.MouseButton1Click:Connect(function()
    jumpMultiplier = (jumpMultiplier < 5) and (jumpMultiplier + 0.5) or (jumpMultiplier + 1.0)
    updateJumpUI()
end)
btnJumpMinus.MouseButton1Click:Connect(function()
    if jumpMultiplier > 1 then
        jumpMultiplier = (jumpMultiplier <= 5) and (jumpMultiplier - 0.5) or (jumpMultiplier - 1.0)
    else
        jumpMultiplier = math.max(0.1, jumpMultiplier - 0.2)
    end
    updateJumpUI()
end)

-- FLY SPEED (Nhập số bất kỳ)
flySpdInput.FocusLost:Connect(function()
    local cleanText = flySpdInput.Text:gsub("[^%d%.]", "")
    local num = tonumber(cleanText)
    if num and num > 0 then
        currentFlySpeed = math.clamp(num, 5, 1000) -- Giới hạn an toàn từ 5 đến 1000
    end
    updateFlySpeedUI()
end)
btnFlySpdPlus.MouseButton1Click:Connect(function()
    currentFlySpeed = currentFlySpeed + 15
    updateFlySpeedUI()
end)
btnFlySpdMinus.MouseButton1Click:Connect(function()
    currentFlySpeed = math.max(5, currentFlySpeed - 15)
    updateFlySpeedUI()
end)

-- Khi hồi sinh nhân vật
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
    
    setupFallProtection(humanoid)
    task.wait(0.1)
    updateSpeedUI()
    updateJumpUI()
end)

---------------------------------------------------------------------
-- 3. LOGIC FLY
---------------------------------------------------------------------
local isFlying = false
local bodyVelocity, bodyGyro

local function startFly()
    if not character or not rootPart or not humanoid then return end
    isFlying = true
    
    btnFly.Text = "✈  Tắt Fly"
    btnFly.BackgroundColor3 = Color3.fromRGB(60, 15, 20)
    flyStroke.Color = Color3.fromRGB(255, 60, 80)
    
    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bodyVelocity.Parent = rootPart
    
    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    bodyGyro.CFrame = rootPart.CFrame
    bodyGyro.Parent = rootPart
    
    humanoid.PlatformStand = true
end

local function stopFly()
    isFlying = false
    
    if btnFly and btnFly.Parent then
        btnFly.Text = "✈  Bật Fly"
        btnFly.BackgroundColor3 = Color3.fromRGB(4, 45, 26)
        flyStroke.Color = Color3.fromRGB(0, 255, 130)
    end
    
    if bodyVelocity then bodyVelocity:Destroy(); bodyVelocity = nil end
    if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end
    
    if character and rootPart and humanoid then
        rootPart.AssemblyLinearVelocity = Vector3.zero
        rootPart.AssemblyAngularVelocity = Vector3.zero
        
        local camLook = workspace.CurrentCamera.CFrame.LookVector
        local flatLook = Vector3.new(camLook.X, 0, camLook.Z).Unit
        if flatLook.Magnitude > 0 then
            rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + flatLook)
        end
        
        humanoid.PlatformStand = false
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        task.defer(function()
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Running)
            end
        end)
    end
end

btnFly.MouseButton1Click:Connect(function()
    if isFlying then stopFly() else startFly() end
end)

local stepConn = RunService.Stepped:Connect(function()
    if isFlying and character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

local renderConn = RunService.RenderStepped:Connect(function()
    if isFlying and rootPart and humanoid and bodyGyro and bodyVelocity then
        local cam = workspace.CurrentCamera
        local moveDir = humanoid.MoveDirection
        
        bodyGyro.CFrame = cam.CFrame
        
        if moveDir.Magnitude > 0 then
            local camCFrame = cam.CFrame
            local flatLook = Vector3.new(camCFrame.LookVector.X, 0, camCFrame.LookVector.Z).Unit
            local flatRight = Vector3.new(camCFrame.RightVector.X, 0, camCFrame.RightVector.Z).Unit
            
            local forwardDot = moveDir:Dot(flatLook)
            local rightDot = moveDir:Dot(flatRight)
            
            local flyDirection = (camCFrame.LookVector * forwardDot + camCFrame.RightVector * rightDot)
            if flyDirection.Magnitude > 0 then
                flyDirection = flyDirection.Unit
            end
            
            -- Tốc độ bay áp dụng trực tiếp theo currentFlySpeed đã nhập
            bodyVelocity.Velocity = flyDirection * currentFlySpeed
        else
            bodyVelocity.Velocity = Vector3.zero
        end
    end
end)

---------------------------------------------------------------------
-- 4. THU NHỎ & ĐÓNG (X)
---------------------------------------------------------------------
local isMinimized = false

btnMinimize.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        contentFrame.Visible = false
        mainFrame:TweenSize(UDim2.new(0, 320, 0, 48), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
        btnMinimize.Text = "＋"
    else
        mainFrame:TweenSize(UDim2.new(0, 320, 0, 390), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true, function()
            contentFrame.Visible = true
        end)
        btnMinimize.Text = "−"
    end
end)

btnClose.MouseButton1Click:Connect(function()
    stopFly()
    
    if humanoid then
        humanoid.WalkSpeed = defaultSpeed
        if humanoid.UseJumpPower then
            humanoid.JumpPower = defaultJumpPower
        else
            humanoid.JumpHeight = defaultJumpHeight
        end
    end
    
    if stepConn then stepConn:Disconnect() end
    if renderConn then renderConn:Disconnect() end
    if stateConn then stateConn:Disconnect() end
    
    screenGui:Destroy()
end)

---------------------------------------------------------------------
-- 5. KÉO THẢ GIAO DIỆN
---------------------------------------------------------------------
local dragging, dragInput, dragStart, startPos

local function update(input)
    local delta = input.Position - dragStart
    mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

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

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)
