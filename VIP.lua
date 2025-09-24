--// Servicios
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- Cámara que “traspasa” paredes
player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam

--// Patterns y util
local timerPattern1, timerPattern2, numberPattern = "%d+m%s*%d+s", "%d+:%d+", "%d+%.?%d*"
local multipliers = {B=1_000_000_000,b=1_000_000_000,M=1_000_000,m=1_000_000,K=1_1000,k=1_000}
local plotsCache, lastPlotScan, PLOT_CACHE_TIME = {}, 0, 2
local pathAttempts = {
    {"Base","Spawn","Attachment","AnimalOverhead"},
    {"Spawn","Attachment","AnimalOverhead"},
    {"Attachment","AnimalOverhead"},
    {"AnimalOverhead"}
}

--// Estado global
local currentMarker = nil
local currentPlatform = nil
local platformState = "none" -- "none" | "moving" | "paused"
local followConn = nil
local risingHeight = 0
local raiseSpeed  = 8 -- Velocidad de subida reducida
local isSCPActive = false

-- Parâmetros para detener cuando la cabeza casi toque el techo
local HEAD_RAY_LENGTH = 20
local HEAD_CLEARANCE   = 1.6

--==================== GUI (paleta nueva) ====================--
local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotScannerGUI"
gui.ResetOnSpawn = false
gui.Parent = game.CoreGui

local toggleUI = Instance.new("TextButton", gui)
toggleUI.Name = "ToggleUI"
toggleUI.Size = UDim2.new(0, 44, 0, 44)
toggleUI.Position = UDim2.new(0, 12, 0, 12)
toggleUI.Text = "☰"
toggleUI.Font = Enum.Font.GothamBold
toggleUI.TextSize = 20
toggleUI.BackgroundColor3 = Color3.fromRGB(28, 33, 40)
toggleUI.TextColor3 = Color3.fromRGB(255, 255, 255)
local toggleUICorner = Instance.new("UICorner", toggleUI) toggleUICorner.CornerRadius = UDim.new(1,0)

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 260, 0, 180) -- Reducido a su tamaño original
frame.Position = UDim2.new(0, 64, 0, 64)
frame.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
local isMinimized = false
local frameCorner = Instance.new("UICorner", frame) frameCorner.CornerRadius = UDim.new(0, 14)

local border = Instance.new("Frame", frame)
border.Size = UDim2.new(1, 4, 1, 4)
border.Position = UDim2.new(0, -2, 0, -2)
border.BackgroundColor3 = Color3.fromRGB(64, 156, 255)
border.ZIndex = -1
local borderCorner = Instance.new("UICorner", border) borderCorner.CornerRadius = UDim.new(0, 16)
local borderGradient = Instance.new("UIGradient", border)
borderGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 220, 190)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(64,156,255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 90, 255))
}
borderGradient.Rotation = 35

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, -80, 0, 30)
title.Position = UDim2.new(0, 10, 0, 8)
title.Text = "Nico XIT - Hypersex"
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(240, 244, 248)
title.TextSize = 16
title.BackgroundTransparency = 1

local toggleBtn = Instance.new("TextButton", frame)
toggleBtn.Size = UDim2.new(0, 28, 0, 28)
toggleBtn.Position = UDim2.new(1, -66, 0, 6)
toggleBtn.Text = "−"
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 18
toggleBtn.BackgroundColor3 = Color3.fromRGB(46, 56, 66)
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.BorderSizePixel = 0
local toggleCorner = Instance.new("UICorner", toggleBtn) toggleCorner.CornerRadius = UDim.new(0, 12)

local close = Instance.new("TextButton", frame)
close.Size = UDim2.new(0, 28, 0, 28)
close.Position = UDim2.new(1, -34, 0, 6)
close.Text = "×"
close.Font = Enum.Font.GothamBold
close.TextSize = 18
close.BackgroundColor3 = Color3.fromRGB(230, 80, 98)
close.TextColor3 = Color3.fromRGB(255, 255, 255)
close.BorderSizePixel = 0
local closeCorner = Instance.new("UICorner", close) closeCorner.CornerRadius = UDim.new(0, 12)

local statusFrame = Instance.new("Frame", frame)
statusFrame.Size = UDim2.new(1, -20, 0, 26)
statusFrame.Position = UDim2.new(0, 10, 0, 44)
statusFrame.BackgroundColor3 = Color3.fromRGB(24, 29, 36)
statusFrame.BorderSizePixel = 0
local statusCorner = Instance.new("UICorner", statusFrame) statusCorner.CornerRadius = UDim.new(0, 8)

local status = Instance.new("TextLabel", statusFrame)
status.Size = UDim2.new(1, -10, 1, 0)
status.Position = UDim2.new(0, 5, 0, 0)
status.Text = "Listo para buscar..."
status.Font = Enum.Font.Gotham
status.TextColor3 = Color3.fromRGB(185, 195, 205)
status.TextSize = 12
status.BackgroundTransparency = 1
status.TextXAlignment = Enum.TextXAlignment.Left

local btnMark = Instance.new("TextButton", frame)
btnMark.Size = UDim2.new(1, -20, 0, 42)
btnMark.Position = UDim2.new(0, 10, 0, 78)
btnMark.Text = "BUSCAR BRAINROTS"
btnMark.Font = Enum.Font.GothamBold
btnMark.TextSize = 13
btnMark.TextColor3 = Color3.new(1,1,1)
btnMark.BackgroundColor3 = Color3.fromRGB(64, 156, 255)
btnMark.BorderSizePixel = 0
local btnCorner = Instance.new("UICorner", btnMark) btnCorner.CornerRadius = UDim.new(0, 12)
local btnGradient = Instance.new("UIGradient", btnMark)
btnGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(64,156,255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 180, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(64,156,255))
}
btnGradient.Rotation = 90

local btnPlatform = Instance.new("TextButton", frame)
btnPlatform.Size = UDim2.new(1, -20, 0, 42)
btnPlatform.Position = UDim2.new(0, 10, 0, 126)
btnPlatform.Text = "CREAR PLATAFORMA"
btnPlatform.Font = Enum.Font.GothamBold
btnPlatform.TextSize = 13
btnPlatform.TextColor3 = Color3.new(1,1,1)
btnPlatform.BackgroundColor3 = Color3.fromRGB(0, 200, 175)
btnPlatform.BorderSizePixel = 0
local btnPlatformCorner = Instance.new("UICorner", btnPlatform) btnPlatformCorner.CornerRadius = UDim.new(0, 12)
local platformGradient = Instance.new("UIGradient", btnPlatform)
platformGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 220, 190)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 240, 205)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 220, 190))
}
platformGradient.Rotation = 90

local uiOpen = true
local function setUI(open) uiOpen = open; frame.Visible = open end
toggleUI.MouseButton1Click:Connect(function() setUI(not uiOpen) end)

local function toggleInterface()
    if isMinimized then
        frame:TweenSize(UDim2.new(0, 260, 0, 180), "Out", "Quart", 0.25, true)
        toggleBtn.Text = "−"
        statusFrame.Visible, btnMark.Visible, btnPlatform.Visible = true, true, true
        isMinimized = false
    else
        frame:TweenSize(UDim2.new(0, 260, 0, 44), "Out", "Quart", 0.25, true)
        toggleBtn.Text = "+"
        statusFrame.Visible, btnMark.Visible, btnPlatform.Visible = false, false, false
        isMinimized = true
    end
end
toggleBtn.MouseButton1Click:Connect(toggleInterface)

--==================== Lógica util (scanner) ====================--
local function updateStatusLabel(text)
    if status and status.Parent then status.Text = tostring(text) end
end

local function parseGeneration(generationText)
    if not generationText then return 0 end
    local textStr = tostring(generationText)
    if textStr:find(timerPattern1) or textStr:find(timerPattern2) then return 0 end
    local cleanText = textStr:gsub("[$,/s ]", "")
    local number = tonumber(cleanText:match(numberPattern))
    if not number then return 0 end
    for suffix, mult in pairs(multipliers) do
        if textStr:find(suffix) then return number * mult end
    end
    return number
end

local function getTextFromObject(obj)
    if not obj then return nil end
    local ok, v = pcall(function() return obj.Text end)
    if ok and v then return tostring(v) end
    ok, v = pcall(function() return obj.Value end)
    if ok and v then return tostring(v) end
    ok, v = pcall(function() return tostring(obj) end)
    return ok and v or nil
end

local function findPlotsInWorkspace()
    local now = tick()
    if now - lastPlotScan < PLOT_CACHE_TIME and #plotsCache > 0 then return plotsCache end
    plotsCache, lastPlotScan = {}, now
    local playerPlot, plotsFolder = nil, workspace:FindFirstChild("Plots")
    if not plotsFolder then
        for _, child in pairs(workspace:GetChildren()) do
            if child.Name:lower():find("plot") then plotsFolder = child; break end
        end
    end
    if plotsFolder then
        for _, child in pairs(plotsFolder:GetChildren()) do
            local owner = child:FindFirstChild("Owner")
            if owner and owner.Value == player or child.Name == tostring(player.UserId) then
                playerPlot = child
            end
        end
        for _, child in pairs(plotsFolder:GetChildren()) do
            if child ~= playerPlot then table.insert(plotsCache, child) end
        end
    end
    return plotsCache
end

local function scanSinglePodium(plot, podiumNumber)
    local success, animalData = pcall(function()
        local animalPodiums = plot:FindFirstChild("AnimalPodiums")
        if not animalPodiums then
            for _, c in pairs(plot:GetChildren()) do
                local n = c.Name:lower()
                if n:find("podium") or n:find("animal") then animalPodiums = c; break end
            end
        end
        if not animalPodiums then return nil end
        local podium = animalPodiums:FindFirstChild(tostring(podiumNumber))
        if not podium then return nil end

        local animalOverhead
        for i=1,#pathAttempts do
            local cur, ok = podium, true
            for j=1,#pathAttempts[i] do
                cur = cur:FindFirstChild(pathAttempts[i][j])
                if not cur then ok=false break end
            end
            if ok then animalOverhead = cur break end
        end
        if not animalOverhead then return nil end

        local generation = animalOverhead:FindFirstChild("Generation")
        local displayName = animalOverhead:FindFirstChild("DisplayName")
        if not generation or not displayName then return nil end

        local generationValue = getTextFromObject(generation)
        local displayNameValue = getTextFromObject(displayName)
        if not generationValue or not displayNameValue then return nil end

        local coords
        local base = podium:FindFirstChild("Base")
        if base and base:IsA("BasePart") then
            coords = base.Position
        else
            for _, d in pairs(podium:GetDescendants()) do
                if d:IsA("BasePart") then coords = d.Position break end
            end
        end
        if not coords then return nil end

        return {
            generation = generationValue,
            displayName = displayNameValue,
            plotName = plot.Name,
            podiumNumber = podiumNumber,
            parsedValue = parseGeneration(generationValue),
            coordinates = coords,
            podium = podium
        }
    end)
    return success and animalData or nil
end

local function fastScan()
    local plots = findPlotsInWorkspace()
    if #plots == 0 then return nil end
    local best, bestVal = nil, 0
    for _, plot in ipairs(plots) do
        for podiumNumber = 1, 23 do
            local a = scanSinglePodium(plot, podiumNumber)
            if a and a.parsedValue > bestVal then best, bestVal = a, a.parsedValue end
        end
    end
    return best
end

--==================== Marcador SIN cilindro ====================--
local function createMarker(position, animalData)
    if currentMarker then currentMarker:Destroy() currentMarker = nil end
    local markerModel = Instance.new("Model"); markerModel.Name = "BrainrotMarker"; markerModel.Parent = workspace

    local marker = Instance.new("Part")
    marker.Name = "MarkerCore"
    marker.Size = Vector3.new(0.1,0.1,0.1)
    marker.Position = position + Vector3.new(0,3,0)
    marker.Anchored = true
    marker.CanCollide = false
    marker.CanTouch = false
    marker.CanQuery = false
    marker.Transparency = 1
    marker.Parent = markerModel

    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Size = UDim2.new(12,0,6,0)
    billboardGui.StudsOffset = Vector3.new(0, 15, 0)
    billboardGui.Adornee = marker
    billboardGui.AlwaysOnTop = true
    billboardGui.Parent = marker

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1,0,1,0)
    bg.BackgroundColor3 = Color3.fromRGB(18,22,28)
    bg.BackgroundTransparency = 0.25
    bg.BorderSizePixel = 2
    bg.BorderColor3 = Color3.fromRGB(64,156,255)
    bg.Parent = billboardGui

    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1,0,0.3,0)
    text.Text = "BRAINROT MÁS VALIOSO"
    text.Font = Enum.Font.GothamBold
    text.TextScaled = true
    text.TextColor3 = Color3.fromRGB(255,255,255)
    text.BackgroundTransparency = 1
    text.Parent = bg

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1,0,0.3,0)
    info.Position = UDim2.new(0,0,0.3,0)
    info.Text = string.upper(animalData.displayName)
    info.Font = Enum.Font.GothamBold
    info.TextScaled = true
    info.TextColor3 = Color3.fromRGB(0,220,190)
    info.BackgroundTransparency = 1
    info.Parent = bg

    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(1,0,0.3,0)
    val.Position = UDim2.new(0,0,0.65,0)
    val.Text = "VALOR: " .. animalData.generation
    val.Font = Enum.Font.GothamBold
    val.TextScaled = true
    val.TextColor3 = Color3.fromRGB(255,215,0)
    val.BackgroundTransparency = 1
    val.Parent = bg

    local highlight = Instance.new("Highlight")
    highlight.FillTransparency = 1
    highlight.OutlineColor = Color3.fromRGB(64,156,255)
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = markerModel
    highlight.Adornee = marker

    currentMarker = markerModel
end

--==================== Plataforma (sube hasta PARAR) ====================--
local function cleanupPlatform()
    if followConn then followConn:Disconnect(); followConn = nil end
    if currentPlatform and currentPlatform.Parent then currentPlatform:Destroy() end
    currentPlatform = nil
end

local function pausePlatform()
    platformState = "paused"
    if followConn then followConn:Disconnect(); followConn = nil end
    local h = math.floor(risingHeight)
    if status and status.Parent then status.Text = ("Plataforma pausada · Altura %d st"):format(h) end
    btnPlatform.Text = "ELIMINAR PLATAFORMA"
end

local function deletePlatform()
    cleanupPlatform()
    platformState = "none"
    risingHeight = 0
    if status and status.Parent then status.Text = "Plataforma eliminada" end
    btnPlatform.Text = "CREAR PLATAFORMA"
end

local function startPlatform()
    local char = player.Character
    if not char then if status then status.Text="No hay personaje" end return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then if status then status.Text="Sin HumanoidRootPart" end return end

    local platform = Instance.new("Part")
    platform.Name = "ElevatorPlatform"
    platform.Size = Vector3.new(8, 1, 8)
    platform.Anchored = true
    platform.CanCollide = true
    platform.Material = Enum.Material.Neon
    platform.Color = Color3.fromRGB(0, 220, 190)
    platform.Transparency = 0.22
    platform.CFrame = hrp.CFrame * CFrame.new(0, -3, 0)
    platform.Parent = workspace

    currentPlatform = platform
    platformState = "moving"
    risingHeight = 0
    btnPlatform.Text = "PARAR PLATAFORMA"
    if status then status.Text = "Subiendo... toca PARAR para detener" end

    local t0, dur = tick(), 0.8
    local startY = platform.Position.Y
    local function easeOutCubic(a) return 1 - (1 - a)^3 end

    followConn = RunService.Heartbeat:Connect(function(dt)
        if not currentPlatform or not currentPlatform.Parent then deletePlatform(); return end
        local c = player.Character
        if not c or not c.Parent then deletePlatform(); return end
        local hrpNow = c:FindFirstChild("HumanoidRootPart")
        if not hrpNow then deletePlatform(); return end

        -- Movimiento normal
        local alpha = math.clamp((tick() - t0)/dur, 0, 1)
        local eased = easeOutCubic(alpha)
        risingHeight += dt * raiseSpeed

        local baseY = startY + (15 * eased)
        local targetPos = Vector3.new(
            hrpNow.Position.X,
            baseY - 3 + risingHeight,
            hrpNow.Position.Z
        )
        currentPlatform.Position = currentPlatform.Position:Lerp(targetPos, 0.2)

        -- === DETENCIÓN: cabeza casi pegada al techo, pero con más margen ===
        local head = c:FindFirstChild("Head") or hrpNow
        local half = (head.Size and head.Size.Y/2) or 1
        local origin = Vector3.new(head.Position.X, head.Position.Y + half + 0.05, head.Position.Z)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {currentPlatform, c}
        local result = workspace:Raycast(origin, Vector3.new(0, HEAD_RAY_LENGTH, 0), params)

        if result and result.Instance and result.Instance.CanCollide then
            if result.Distance <= HEAD_CLEARANCE then
                pausePlatform()
                if status then status.Text = "Plataforma detenida antes del techo" end
                return
            end
        end
    end)
end

--==================== Lógica SCP ====================--
local function addSCPEffect(character)
    if not character or not character.Parent then return end
    local scpTag = "SCPEffectTag"
    if character:FindFirstChild(scpTag) then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = scpTag
    highlight.FillTransparency = 1
    highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
    highlight.OutlineTransparency = 0.5
    highlight.Parent = character
    highlight.Adornee = character
end

local function removeSCPEffect(character)
    if not character or not character.Parent then return end
    local scpEffect = character:FindFirstChild("SCPEffectTag")
    if scpEffect then scpEffect:Destroy() end
end

local function cleanupSCPEffects()
    local playersList = Players:GetPlayers()
    for _, p in ipairs(playersList) do
        if p ~= player then
            removeSCPEffect(p.Character)
        end
    end
end

local function startSCPEffects()
    updateStatusLabel("SCP activado: marcando jugadores...")
    local playersList = Players:GetPlayers()
    for _, p in ipairs(playersList) do
        if p ~= player then
            addSCPEffect(p.Character)
            -- Asegura que los efectos se apliquen a los nuevos jugadores que se unan
            p.CharacterAdded:Connect(function(char) addSCPEffect(char) end)
        end
    end
end

--==================== Scanner principal ====================--
local function markBestBrainrot()
    if status then status.Text = "Buscando brainrots..." end
    local best = fastScan()
    if not best then if status then status.Text = "No se encontraron brainrots" end return end
    if status then status.Text = "Brainrot: " .. best.displayName end
    createMarker(best.coordinates, best)
    if status then status.Text = "Marcado: " .. best.displayName .. " (" .. best.generation .. ")" end
end

--==================== Handlers ====================--
btnMark.MouseButton1Click:Connect(markBestBrainrot)
btnPlatform.MouseButton1Click:Connect(function()
    if platformState == "none" then
        startPlatform()
    elseif platformState == "moving" then
        pausePlatform()
    elseif platformState == "paused" then
        deletePlatform()
    end
end)

close.MouseButton1Click:Connect(function()
    if currentMarker then currentMarker:Destroy(); currentMarker = nil end
    deletePlatform()
    cleanupSCPEffects() -- Desactiva el SCP al cerrar
    gui:Destroy()
end)

-- Iniciar el efecto SCP automáticamente al cargar el script
startSCPEffects()
print("Brainrot Scanner: HEAD_CLEARANCE=1.6 (para no chocar), SCP activado automáticamente.")

---
-- Fix para el problema del Brainrot
-- Detecta si el personaje se reinicia y reactiva la plataforma si está activa
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    -- Si la plataforma estaba activa, la reinicia
    if platformState ~= "none" then
        deletePlatform() -- Limpia la plataforma anterior
        startPlatform()  -- Inicia una nueva
    end
end)

