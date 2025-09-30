-- ================== CONFIG FIREBASE (TU PROYECTO) ==================
local PROJECT_ID = "keyyyvalidator"
local API_KEY    = "AIzaSyBfaE6s4Xf5kb4JqRkelHpnifW8-DoOgQA"
-- ===================================================================

--==================== HTTP helper ====================--
local HttpService = game:GetService("HttpService")
local http
if syn and syn.request then http = syn.request
elseif request then http = request
elseif http_request then http = http_request
elseif http and http.request then http = http.request
else error("No hay función HTTP disponible en este ejecutor.") end

--==================== Fecha utils (ISO -> Unix robusto) ====================--
local function utcOffsetSeconds()
    local now = os.time()
    local lt = os.date("*t", now)
    local ut = os.date("!*t", now)
    lt.isdst = false; ut.isdst = false
    return os.difftime(os.time(lt), os.time(ut))
end
local __TZ = utcOffsetSeconds()

local function isoToUnix(iso) -- "YYYY-MM-DDTHH:MM:SS(.ms)Z"
    local y,m,d,H,M,S = string.match(iso, "^(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)")
    if not (y and m and d and H and M and S) then return nil end
    y,m,d,H,M,S = tonumber(y),tonumber(m),tonumber(d),tonumber(H),tonumber(M),tonumber(S)
    -- os.time usa hora local; restamos offset para UTC real
    local local_ts = os.time({year=y, month=m, day=d, hour=H, min=M, sec=S, isdst=false})
    if not local_ts then return nil end
    return local_ts - __TZ
end

--==================== Validación contra Firestore ====================--
local function validateKeyByDocId(code)
    if not code or code == "" then
        return false, "missing_code"
    end
    local url = "https://firestore.googleapis.com/v1/projects/"
        .. PROJECT_ID .. "/databases/(default)/documents/keys/"
        .. HttpService:UrlEncode(code) .. "?key=" .. API_KEY

    local ok, resp = pcall(function()
        return http({ Url = url, Method = "GET" })
    end)
    if not ok or not resp then
        return false, "network_error"
    end

    if resp.StatusCode and resp.StatusCode ~= 200 then
        if resp.StatusCode == 404 then
            return false, "not_found"
        else
            return false, "http_".. tostring(resp.StatusCode)
        end
    end

    local okj, data = pcall(function()
        return HttpService:JSONDecode(resp.Body)
    end)
    if not okj or not data.fields then
        return false, "not_found"
    end

    local f = data.fields
    local isActive  = f.is_active and f.is_active.booleanValue
    local expiryISO = f.expiry_date and f.expiry_date.timestampValue

    if not isActive then return false, "inactive" end
    if not expiryISO then return false, "no_expiry_date" end

    local expUnix = isoToUnix(expiryISO)
    if not expUnix then return false, "bad_expiry_format" end
    if os.time() >= expUnix then return false, "expired" end

    return true, { expiresAt = expiryISO, ttl = (expUnix - os.time()) }
end

--==================== TU SCRIPT (con validación primero) ====================--
--// Servicios
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage") -- Añadido para Desync

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-------------------- Estado de validación ------------------
local __KEY_VALIDATED__ = false

--==================== GUI (MISMA PALETA Y DISEÑO TUYO) ====================--
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
frame.Size = UDim2.new(0, 260, 0, 228)
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
status.Text = "Validá tu key para comenzar…"
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

local btnDesync = Instance.new("TextButton", frame)
btnDesync.Size = UDim2.new(1, -20, 0, 42)
btnDesync.Position = UDim2.new(0, 10, 0, 174)
btnDesync.Text = "ACTIVAR DESYNC"
btnDesync.Font = Enum.Font.GothamBold
btnDesync.TextSize = 13
btnDesync.TextColor3 = Color3.new(1,1,1)
btnDesync.BackgroundColor3 = Color3.fromRGB(140, 90, 220)
btnDesync.BorderSizePixel = 0
local btnDesyncCorner = Instance.new("UICorner", btnDesync) btnDesyncCorner.CornerRadius = UDim.new(0, 12)
local desyncGradient = Instance.new("UIGradient", btnDesync)
desyncGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 90, 220)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(160, 110, 240)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 90, 220))
}
desyncGradient.Rotation = 90

-- ---------- VALIDACIÓN UI (MISMO FRAME, MISMOS COLORES) ----------
local valBox = Instance.new("TextBox", frame)
valBox.Size = UDim2.new(1, -20, 0, 30)
valBox.Position = UDim2.new(0, 10, 0, 44)
valBox.PlaceholderText = "Escribe tu key (ID del doc en /keys)"
valBox.Text = ""
valBox.TextSize = 16
valBox.BackgroundColor3 = Color3.fromRGB(40,40,46)
valBox.TextColor3 = Color3.new(1,1,1)

local valBtn = Instance.new("TextButton", frame)
valBtn.Size = UDim2.new(0, 110, 0, 30)
valBtn.Position = UDim2.new(0, 10, 0, 80)
valBtn.Text = "Validar"
valBtn.TextSize = 16
valBtn.BackgroundColor3 = Color3.fromRGB(64, 156, 255)
valBtn.TextColor3 = Color3.new(1,1,1)

local valStatus = Instance.new("TextLabel", frame)
valStatus.Size = UDim2.new(1, -130, 0, 30)
valStatus.Position = UDim2.new(0, 130, 0, 80)
valStatus.BackgroundTransparency = 1
valStatus.Text = ""
valStatus.TextSize = 14
valStatus.TextColor3 = Color3.new(1,1,1)
valStatus.TextXAlignment = Enum.TextXAlignment.Left

-- Al inicio: ocultamos tus controles funcionales (sólo se ve validación)
statusFrame.Visible = false
btnMark.Visible = false
btnPlatform.Visible = false
btnDesync.Visible = false

--==================== LÓGICA TUYA (NO SE EJECUTA HASTA VALIDAR) ====================--

-- Cámara invisicam SOLO tras validación
local function enableInvisicam()
    player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
end

-- Patterns y util
local timerPattern1, timerPattern2, numberPattern = "%d+m%s*%d+s", "%d+:%d+", "%d+%.?%d*"
local multipliers = {B=1_000_000_000,b=1_000_000_000,M=1_000_000,m=1_000_000,K=1_000,k=1_000}
local plotsCache, lastPlotScan, PLOT_CACHE_TIME = {}, 0, 2
local pathAttempts = {
    {"Base","Spawn","Attachment","AnimalOverhead"},
    {"Spawn","Attachment","AnimalOverhead"},
    {"Attachment","AnimalOverhead"},
    {"AnimalOverhead"}
}

-- Estado global de tu script
local currentMarker = nil
local currentPlatform = nil
local platformState = "none" -- "none" | "moving" | "paused"
local followConn = nil
local risingHeight = 0
local raiseSpeed  = 8
local isSCPActive = false

-- Parámetros techo
local HEAD_RAY_LENGTH = 20
local HEAD_CLEARANCE   = 1.6

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

--==================== Marcador ====================--
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

--==================== Plataforma ====================--
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

        local alpha = math.clamp((tick() - t0)/dur, 0, 1)
        local eased = easeOutCubic(alpha)
        risingHeight += dt * 8

        local baseY = startY + (15 * eased)
        local targetPos = Vector3.new(hrpNow.Position.X, baseY - 3 + risingHeight, hrpNow.Position.Z)
        currentPlatform.Position = currentPlatform.Position:Lerp(targetPos, 0.2)

        -- Detener antes del techo
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

--==================== SCP Effects ====================--
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
            p.CharacterAdded:Connect(function(char) addSCPEffect(char) end)
        end
    end
end

--==================== Desync ====================--
local desyncActive = false

local function enableMobileDesync()
    local success, err = pcall(function()
        local backpack = player:WaitForChild("Backpack")
        local char = player.Character or player.CharacterAdded:Wait()
        local humanoid = char:WaitForChild("Humanoid")

        local packages = ReplicatedStorage:WaitForChild("Packages", 5)
        if not packages then warn("❌ Packages no encontrado") return false end

        local netFolder = packages:WaitForChild("Net", 5)
        if not netFolder then warn("❌ Net folder no encontrado") return false end

        local useItemRemote = netFolder:WaitForChild("RE/UseItem", 5)
        local teleportRemote = netFolder:WaitForChild("RE/QuantumCloner/OnTeleport", 5)
        if not useItemRemote or not teleportRemote then warn("❌ Remotos no encontrados") return false end

        local toolNames = {"Quantum Cloner", "Brainrot", "brainrot"}
        local tool
        for _, toolName in ipairs(toolNames) do
            tool = backpack:FindFirstChild(toolName) or char:FindFirstChild(toolName)
            if tool then break end
        end
        if not tool then
            for _, item in ipairs(backpack:GetChildren()) do
                if item:IsA("Tool") then tool=item break end
            end
        end

        if tool and tool.Parent==backpack then
            humanoid:EquipTool(tool)
            task.wait(0.5)
        end

        if setfflag then setfflag("WorldStepMax", "-9999999999") end
        task.wait(0.2)
        useItemRemote:FireServer()
        task.wait(1)
        teleportRemote:FireServer()
        task.wait(2)
        if setfflag then setfflag("WorldStepMax", "-1") end
        updateStatusLabel("✅ Desync activado!")
        return true
    end)
    if not success then
        warn("❌ Error al activar desync: " .. tostring(err))
        updateStatusLabel("❌ Error al activar desync.")
        return false
    end
    return success
end

local function disableMobileDesync()
    pcall(function()
        if setfflag then setfflag("WorldStepMax", "-1") end
        updateStatusLabel("❌ Desync desactivado.")
    end)
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

--==================== Handlers (protegidos por validación) ====================--
btnMark.MouseButton1Click:Connect(function()
    if not __KEY_VALIDATED__ then return end
    markBestBrainrot()
end)

btnPlatform.MouseButton1Click:Connect(function()
    if not __KEY_VALIDATED__ then return end
    if platformState == "none" then
        startPlatform()
    elseif platformState == "moving" then
        pausePlatform()
    elseif platformState == "paused" then
        deletePlatform()
    end
end)

btnDesync.MouseButton1Click:Connect(function()
    if not __KEY_VALIDATED__ then return end
    desyncActive = not desyncActive
    if desyncActive then
        local success = enableMobileDesync()
        if success then
            btnDesync.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
            btnDesync.Text = "DESYNC ACTIVADO"
            desyncGradient.Enabled = false
        else
            desyncActive = false
            btnDesync.BackgroundColor3 = Color3.fromRGB(140, 90, 220)
            btnDesync.Text = "ACTIVAR DESYNC"
            desyncGradient.Enabled = true
        end
    else
        disableMobileDesync()
        btnDesync.BackgroundColor3 = Color3.fromRGB(140, 90, 220)
        btnDesync.Text = "ACTIVAR DESYNC"
        desyncGradient.Enabled = true
    end
end)

local uiOpen = true
local function setUI(open) uiOpen = open; frame.Visible = open end
toggleUI.MouseButton1Click:Connect(function() setUI(not uiOpen) end)

local function toggleInterface()
    if isMinimized then
        frame:TweenSize(UDim2.new(0, 260, 0, 228), "Out", "Quart", 0.25, true)
        toggleBtn.Text = "−"
        if __KEY_VALIDATED__ then
            statusFrame.Visible, btnMark.Visible, btnPlatform.Visible, btnDesync.Visible = true, true, true, true
        else
            -- en modo no validado, solo validación visible
            statusFrame.Visible = false
        end
    else
        frame:TweenSize(UDim2.new(0, 260, 0, 44), "Out", "Quart", 0.25, true)
        toggleBtn.Text = "+"
        statusFrame.Visible, btnMark.Visible, btnPlatform.Visible, btnDesync.Visible = false, false, false, false
    end
    isMinimized = not isMinimized
end
toggleBtn.MouseButton1Click:Connect(toggleInterface)

close.MouseButton1Click:Connect(function()
    if currentMarker then currentMarker:Destroy(); currentMarker = nil end
    deletePlatform()
    cleanupSCPEffects()
    disableMobileDesync()
    gui:Destroy()
end)

--==================== VALIDACIÓN: habilita todo al aprobar ====================--
local reasons = {
    missing_code   = "Escribe una key.",
    network_error  = "Error de red.",
    bad_json       = "Respuesta inválida.",
    not_found      = "Key no encontrada.",
    inactive       = "Key inactiva.",
    no_expiry_date = "Key sin fecha.",
    expired        = "Key expirada.",
    bad_expiry_format = "Fecha inválida."
}

valBtn.MouseButton1Click:Connect(function()
    valStatus.Text = "Validando..."
    local ok, info = validateKeyByDocId((valBox.Text or ""):gsub("^%s+",""):gsub("%s+$",""))
    if ok then
        __KEY_VALIDATED__ = true
        -- Ocultar controles de validación
        valBox:Destroy(); valBtn:Destroy(); valStatus:Destroy()
        -- Mostrar tus controles
        statusFrame.Visible = true
        btnMark.Visible = true
        btnPlatform.Visible = true
        btnDesync.Visible = true
        status.Text = "Listo para buscar..."
        -- Activar cámara y SCP recién ahora
        enableInvisicam()
        startSCPEffects()
        print(">>> HABILITADO. Key válida. Expira:", info.expiresAt, "TTL(s):", info.ttl)
    else
        valStatus.Text = "❌ ".. (reasons[info] or tostring(info))
    end
end)

--==================== Reset de personaje (mantener estados) ====================--
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    if not __KEY_VALIDATED__ then
        -- sin validación, nada que reactivar
        return
    end
    -- si la plataforma estaba activa, se gestiona
    if platformState ~= "none" then
        deletePlatform()
        startPlatform()
    end
    if desyncActive then
        desyncActive = false
        disableMobileDesync()
        btnDesync.BackgroundColor3 = Color3.fromRGB(140, 90, 220)
        btnDesync.Text = "ACTIVAR DESYNC"
        desyncGradient.Enabled = true
    end
end)
