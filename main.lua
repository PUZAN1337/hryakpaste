--mega b64 decode
local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function dec(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end
-- ===============================================

-- b64
local encoded_lib1 = "aHR0cHM6Ly9naXRodWIuY29tL3JuaXZhc291dGFtaW5hbGlsbWlubDBsLWxhbmcvaHJ5YWtwYXN0ZS9yYXcvcmVmcy9oZWFkcy9tYWluL2xpYnJhcnlfbWFpbi5sdWE="
local encoded_lib2 = "aHR0cHM6Ly9naXRodWIuY29tL3JuaXZhc291dGFtaW5hbGlsbWlubDBsLWxhbmcvaHJ5YWtwYXN0ZS9yYXcvcmVmcy9oZWFkcy9tYWluL2xpYnJhcnlfc2F2ZS5sdWE="
local encoded_lib3 = "aHR0cHM6Ly9naXRodWIuY29tL3JuaXZhc291dGFtaW5hbGlsbWlubDBsLWxhbmcvaHJ5YWtwYXN0ZS9yYXcvcmVmcy9oZWFkcy9tYWluL2xpYnJhcnlfdGhlbWUubHVh"

-- xru
local Library = loadstring(game:HttpGet(dec(encoded_lib1)))()
local SaveManager = loadstring(game:HttpGet(dec(encoded_lib2)))()
local ThemeManager = loadstring(game:HttpGet(dec(encoded_lib3)))()

-- end

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

local ScriptEnabled = true
local AllConnections = {}
local AllDrawings = {}
local AllHighlights = {}

local function AddConnection(conn)
    if conn then
        table.insert(AllConnections, conn)
    end
    return conn
end

local function AddDrawing(drawing)
    if drawing then
        table.insert(AllDrawings, drawing)
    end
    return drawing
end

local function AddHighlight(highlight)
    if highlight then
        table.insert(AllHighlights, highlight)
    end
    return highlight
end

local function AddColorPickerAlternative(groupbox, name, defaultColor, callback)
    local r, g, b = defaultColor.R * 255, defaultColor.G * 255, defaultColor.B * 255
    
    local rSlider = groupbox:AddSlider(name .. "_R", {
        Text = name .. " (Red)",
        Min = 0,
        Max = 255,
        Default = r,
        Rounding = 0,
        Callback = function(val)
            r = val
            callback(Color3.fromRGB(r, g, b))
        end
    })
    
    local gSlider = groupbox:AddSlider(name .. "_G", {
        Text = name .. " (Green)",
        Min = 0,
        Max = 255,
        Default = g,
        Rounding = 0,
        Callback = function(val)
            g = val
            callback(Color3.fromRGB(r, g, b))
        end
    })
    
    local bSlider = groupbox:AddSlider(name .. "_B", {
        Text = name .. " (Blue)",
        Min = 0,
        Max = 255,
        Default = b,
        Rounding = 0,
        Callback = function(val)
            b = val
            callback(Color3.fromRGB(r, g, b))
        end
    })
    
    return {
        SetValue = function(newColor)
            r, g, b = newColor.R * 255, newColor.G * 255, newColor.B * 255
            rSlider:SetValue(r)
            gSlider:SetValue(g)
            bSlider:SetValue(b)
        end
    }
end

local Aimbot = {
    Enabled = false,
    TeamCheck = true,
    FOV = 100,
    Smoothing = 0.1,
    AimNPC = true,
    ShowFOV = true,
    FOVColor = Color3.fromRGB(255, 128, 128),
    Key = Enum.UserInputType.MouseButton2
}

local AimbotCache = {
    targets = {},
    lastUpdate = 0,
    updateInterval = 1.8
}

local FOVring = AddDrawing(Drawing.new("Circle"))
FOVring.Visible = false
FOVring.Thickness = 1.5
FOVring.Radius = Aimbot.FOV
FOVring.Transparency = 1
FOVring.Color = Aimbot.FOVColor
FOVring.Position = Camera.ViewportSize / 2

local function UpdateAimbotCache()
    if not ScriptEnabled then return end
    local newTargets = {}
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            if char then
                local head = char:FindFirstChild("Head")
                local humanoid = char:FindFirstChild("Humanoid")
                if head and humanoid and humanoid.Health > 0 then
                    if Aimbot.TeamCheck and LocalPlayer.Team and player.Team == LocalPlayer.Team then
                    else
                        table.insert(newTargets, {char = char, head = head, pos = head.Position, isPlayer = true, player = player})
                    end
                end
            end
        end
    end
    
    if Aimbot.AimNPC then
        for _, head in ipairs(workspace:GetDescendants()) do
            if head:IsA("BasePart") and head.Name == "Head" then
                local char = head.Parent
                if char and char:FindFirstChild("Humanoid") then
                    local humanoid = char.Humanoid
                    if humanoid.Health > 0 then
                        local isPlayerChar = false
                        for _, player in ipairs(Players:GetPlayers()) do
                            if player.Character == char then
                                isPlayerChar = true
                                break
                            end
                        end
                        if not isPlayerChar then
                            table.insert(newTargets, {char = char, head = head, pos = head.Position, isPlayer = false})
                        end
                    end
                end
            end
        end
    end
    
    AimbotCache.targets = newTargets
    AimbotCache.lastUpdate = tick()
end

local function GetClosestTarget(origin, direction)
    local bestTarget = nil
    local bestDist = math.huge
    direction = direction.Unit
    
    for _, target in ipairs(AimbotCache.targets) do
        local toPoint = target.pos - origin
        local projection = toPoint:Dot(direction)
        if projection > 0 then
            local closestPoint = origin + direction * projection
            local dist = (target.pos - closestPoint).Magnitude
            if dist < bestDist then
                bestDist = dist
                bestTarget = target
            end
        end
    end
    
    return bestTarget
end

UpdateAimbotCache()

AddConnection(task.spawn(function()
    while ScriptEnabled do
        task.wait(AimbotCache.updateInterval)
        if Aimbot.Enabled then
            UpdateAimbotCache()
        end
    end
end))

local AimbotConnection = AddConnection(RunService.RenderStepped:Connect(function()
    if not ScriptEnabled then return end
    if not Aimbot.Enabled then
        FOVring.Visible = false
        return
    end
    
    FOVring.Visible = Aimbot.ShowFOV
    FOVring.Radius = Aimbot.FOV
    FOVring.Color = Aimbot.FOVColor
    FOVring.Position = Camera.ViewportSize / 2
    
    local pressed = UserInputService:IsMouseButtonPressed(Aimbot.Key)
    local center = Camera.ViewportSize / 2
    
    if pressed then
        local target = GetClosestTarget(Camera.CFrame.Position, Camera.CFrame.LookVector)
        if target and target.char and target.char:FindFirstChild("Head") then
            local headPos, onScreen = Camera:WorldToScreenPoint(target.char.Head.Position)
            if onScreen then
                local screenHead = Vector2.new(headPos.X, headPos.Y)
                if (screenHead - center).Magnitude <= Aimbot.FOV then
                    local newCF = CFrame.new(Camera.CFrame.Position, target.char.Head.Position)
                    Camera.CFrame = Camera.CFrame:Lerp(newCF, Aimbot.Smoothing)
                end
            end
        end
    end
end))

AddConnection(Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    FOVring.Position = Camera.ViewportSize / 2
end))

local Chams = {
    Enabled = false,
    Color = Color3.fromRGB(255, 0, 0),
    Transparency = 0.5,
    Wallhack = true,
    TeamColor = false
}

local ChamsConnection = nil

local function ApplyChamsToPlayer(plr)
    if not ScriptEnabled then return end
    if plr == LocalPlayer then return end
    local character = plr.Character
    if not character then return end

    local highlight = character:FindFirstChildOfClass("Highlight")
    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.Parent = character
        AddHighlight(highlight)
    end

    local color = Chams.Color
    if Chams.TeamColor and plr.Team then
        color = plr.Team.TeamColor.Color
    end
    
    highlight.FillColor = color
    highlight.FillTransparency = Chams.Transparency
    highlight.OutlineTransparency = 1
    highlight.DepthMode = Chams.Wallhack and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
end

local function RemoveChamsFromPlayer(plr)
    if plr == LocalPlayer then return end
    local character = plr.Character
    if character then
        local highlight = character:FindFirstChildOfClass("Highlight")
        if highlight then highlight:Destroy() end
    end
end

local function UpdateChams()
    for _, plr in ipairs(Players:GetPlayers()) do
        ApplyChamsToPlayer(plr)
    end
end

local function SetChamsEnabled(state)
    Chams.Enabled = state
    if state then
        if ChamsConnection then ChamsConnection:Disconnect() end
        ChamsConnection = RunService.RenderStepped:Connect(UpdateChams)
        AddConnection(ChamsConnection)
        UpdateChams()
    else
        if ChamsConnection then
            ChamsConnection:Disconnect()
            ChamsConnection = nil
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            RemoveChamsFromPlayer(plr)
        end
    end
end

AddConnection(Players.PlayerAdded:Connect(function(plr)
    if plr == LocalPlayer then return end
    plr.CharacterAdded:Connect(function(char)
        if Chams.Enabled and ScriptEnabled then
            task.wait(0.1)
            ApplyChamsToPlayer(plr)
        end
    end)
end))

local Fullbright = {
    Enabled = false
}

local OriginalLighting = nil
local FullbrightConnection = nil

local function ApplyFullbright()
    if not ScriptEnabled then return end
    if not Fullbright.Enabled then return end
    if not OriginalLighting then
        OriginalLighting = {
            Brightness = Lighting.Brightness,
            Ambient = Lighting.Ambient,
            OutdoorAmbient = Lighting.OutdoorAmbient,
            GlobalShadows = Lighting.GlobalShadows,
            FogEnd = Lighting.FogEnd,
            ClockTime = Lighting.ClockTime,
            GeographicLatitude = Lighting.GeographicLatitude,
            Technology = Lighting.Technology
        }
    end

    Lighting.Brightness = 0
    Lighting.Ambient = Color3.new(1, 1, 1)
    Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 1e10
    Lighting.ClockTime = 12
    Lighting.GeographicLatitude = 0
    Lighting.Technology = Enum.Technology.ShadowMap
end

local function SetFullbrightEnabled(state)
    Fullbright.Enabled = state
    
    if state then
        if not FullbrightConnection then
            FullbrightConnection = RunService.Heartbeat:Connect(ApplyFullbright)
            AddConnection(FullbrightConnection)
        end
        ApplyFullbright()
    else
        if FullbrightConnection then
            FullbrightConnection:Disconnect()
            FullbrightConnection = nil
        end
        if OriginalLighting then
            Lighting.Brightness = OriginalLighting.Brightness
            Lighting.Ambient = OriginalLighting.Ambient
            Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
            Lighting.GlobalShadows = OriginalLighting.GlobalShadows
            Lighting.FogEnd = OriginalLighting.FogEnd
            Lighting.ClockTime = OriginalLighting.ClockTime
            Lighting.GeographicLatitude = OriginalLighting.GeographicLatitude
            Lighting.Technology = OriginalLighting.Technology
        end
    end
end

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HRP = Character:WaitForChild("HumanoidRootPart")

local Fly = {
    Enabled = false,
    Speed = 80,
    Key = Enum.KeyCode.B
}

local flying = false
local speed = Fly.Speed
local keys = {
    W = false, A = false, S = false, D = false,
    Space = false, LeftShift = false,
    N = false
}

local blueGhost = nil
local yellowGhost = nil
local lastTeleportPos = nil
local teleportCoroutine = nil

local function createGhost(colorName, position)
    if colorName ~= "Blue" and colorName ~= "Yellow" then return nil end
    local part = Instance.new("Part")
    part.Size = Vector3.new(2, 2, 2)
    part.Shape = Enum.PartType.Ball
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 0.5
    part.Material = Enum.Material.Neon
    part.BrickColor = colorName == "Blue" and BrickColor.new("Bright blue") or BrickColor.new("Bright yellow")
    part.Position = position
    part.Parent = workspace
    return part
end

local function destroyGhosts()
    if blueGhost then blueGhost:Destroy(); blueGhost = nil end
    if yellowGhost then yellowGhost:Destroy(); yellowGhost = nil end
end

local function teleportToPosition(pos)
    if not Character or not HRP then return end
    if flying then
        flying = false
        Fly.Enabled = false
        HRP.Anchored = false
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        destroyGhosts()
    end
    HRP.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    HRP.Velocity = Vector3.zero
end

local function startFly()
    if flying then return end
    destroyGhosts()
    blueGhost = createGhost("Blue", HRP.Position)
    flying = true
    Fly.Enabled = true
    HRP.Anchored = true
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
end

local function stopFly(teleportToYellow)
    if not flying then return end
    if teleportToYellow and lastTeleportPos then
        teleportToPosition(lastTeleportPos)
    end
    destroyGhosts()
    HRP.Anchored = false
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
    flying = false
    Fly.Enabled = false
end

local function placeYellowGhostAtMouse(input)
    if not flying then return end
    local camera = Camera
    local mousePos = input.Position
    local ray = camera:ScreenPointToRay(mousePos.X, mousePos.Y)
    local direction = ray.Direction * 1000
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {Character}
    local hit = workspace:Raycast(ray.Origin, direction, params)
    local targetPos = hit and hit.Position or (ray.Origin + direction)
    lastTeleportPos = targetPos
    if yellowGhost then yellowGhost:Destroy() end
    yellowGhost = createGhost("Yellow", targetPos)
end

local function startTeleportLoop()
    if teleportCoroutine then return end
    teleportCoroutine = task.spawn(function()
        while keys.N and ScriptEnabled do
            if lastTeleportPos then
                teleportToPosition(lastTeleportPos)
            end
            task.wait(0.1)
        end
        teleportCoroutine = nil
    end)
end

AddConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not ScriptEnabled then return end
    if gameProcessed then return end

    if input.KeyCode == Fly.Key then
        if not flying then
            startFly()
        else
            stopFly(true)
        end
    elseif input.KeyCode == Enum.KeyCode.N then
        keys.N = true
        startTeleportLoop()
    elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
        placeYellowGhostAtMouse(input)
    elseif input.KeyCode == Enum.KeyCode.W then keys.W = true
    elseif input.KeyCode == Enum.KeyCode.A then keys.A = true
    elseif input.KeyCode == Enum.KeyCode.S then keys.S = true
    elseif input.KeyCode == Enum.KeyCode.D then keys.D = true
    elseif input.KeyCode == Enum.KeyCode.Space then keys.Space = true
    elseif input.KeyCode == Enum.KeyCode.LeftShift then keys.LeftShift = true
    end
end))

AddConnection(UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if not ScriptEnabled then return end
    if input.KeyCode == Enum.KeyCode.W then keys.W = false
    elseif input.KeyCode == Enum.KeyCode.A then keys.A = false
    elseif input.KeyCode == Enum.KeyCode.S then keys.S = false
    elseif input.KeyCode == Enum.KeyCode.D then keys.D = false
    elseif input.KeyCode == Enum.KeyCode.Space then keys.Space = false
    elseif input.KeyCode == Enum.KeyCode.LeftShift then keys.LeftShift = false
    elseif input.KeyCode == Enum.KeyCode.N then keys.N = false
    end
end))

AddConnection(RunService.RenderStepped:Connect(function()
    if not ScriptEnabled then return end
    if flying and HRP then
        local moveDirection = Vector3.new(0, 0, 0)
        local lookVector = Camera.CFrame.LookVector
        local rightVector = Camera.CFrame.RightVector

        if keys.W then moveDirection = moveDirection + lookVector end
        if keys.S then moveDirection = moveDirection - lookVector end
        if keys.A then moveDirection = moveDirection - rightVector end
        if keys.D then moveDirection = moveDirection + rightVector end
        if keys.Space then moveDirection = moveDirection + Vector3.new(0, 1, 0) end
        if keys.LeftShift then moveDirection = moveDirection - Vector3.new(0, 1, 0) end

        if moveDirection.Magnitude > 0 then
            moveDirection = moveDirection.Unit
            HRP.CFrame = HRP.CFrame + moveDirection * Fly.Speed * RunService.RenderStepped:Wait()
        end
    end
end))

AddConnection(LocalPlayer.CharacterAdded:Connect(function(newCharacter)
    Character = newCharacter
    Humanoid = Character:WaitForChild("Humanoid")
    HRP = Character:WaitForChild("HumanoidRootPart")
    flying = false
    Fly.Enabled = false
    destroyGhosts()
    if teleportCoroutine then
        keys.N = false
        teleportCoroutine = nil
    end
end))

local Window = Library:CreateWindow({
    Title = "HRYAK.HACK",
    Center = true,
    AutoShow = true,
    ToggleKey = Enum.KeyCode.Insert
})

local AimbotTab = Window:AddTab("Aimbot")

local AimbotMain = AimbotTab:AddGroupbox({
    Name = "Main",
    Side = 1
})

AimbotMain:AddToggle("AimbotEnabled", {
    Text = "Enabled",
    Default = false,
    Callback = function(value)
        Aimbot.Enabled = value
        if value then
            UpdateAimbotCache()
        end
    end
})

AimbotMain:AddToggle("AimbotTeamCheck", {
    Text = "Team Check",
    Default = true,
    Callback = function(value)
        Aimbot.TeamCheck = value
    end
})

AimbotMain:AddToggle("AimbotNPC", {
    Text = "Aim at NPCs",
    Default = true,
    Callback = function(value)
        Aimbot.AimNPC = value
    end
})

AimbotMain:AddToggle("AimbotShowFOV", {
    Text = "Show FOV Circle",
    Default = true,
    Callback = function(value)
        Aimbot.ShowFOV = value
    end
})

local AimbotSettings = AimbotTab:AddGroupbox({
    Name = "Settings",
    Side = 2
})

AimbotSettings:AddSlider("AimbotFOV", {
    Text = "FOV",
    Min = 10,
    Max = 500,
    Default = 100,
    Rounding = 0,
    Callback = function(value)
        Aimbot.FOV = value
    end
})

AimbotSettings:AddSlider("AimbotSmoothing", {
    Text = "Smoothing",
    Min = 0.01,
    Max = 1,
    Default = 0.1,
    Rounding = 2,
    Callback = function(value)
        Aimbot.Smoothing = value
    end
})

AddColorPickerAlternative(AimbotSettings, "FOV Color", Aimbot.FOVColor, function(value)
    Aimbot.FOVColor = value
end)

local VisualsTab = Window:AddTab("Visuals")

local ChamsGroup = VisualsTab:AddGroupbox({
    Name = "Chams",
    Side = 1
})

ChamsGroup:AddToggle("ChamsEnabled", {
    Text = "Enabled",
    Default = false,
    Callback = function(value)
        SetChamsEnabled(value)
    end
})

ChamsGroup:AddToggle("ChamsWallhack", {
    Text = "Wallhack",
    Default = true,
    Callback = function(value)
        Chams.Wallhack = value
    end
})

ChamsGroup:AddToggle("ChamsTeamColor", {
    Text = "Use Team Color",
    Default = false,
    Callback = function(value)
        Chams.TeamColor = value
    end
})

ChamsGroup:AddSlider("ChamsTransparency", {
    Text = "Transparency",
    Min = 0,
    Max = 1,
    Default = 0.5,
    Rounding = 2,
    Callback = function(value)
        Chams.Transparency = value
    end
})

AddColorPickerAlternative(ChamsGroup, "Chams Color", Chams.Color, function(value)
    Chams.Color = value
end)

local WorldGroup = VisualsTab:AddGroupbox({
    Name = "World",
    Side = 2
})

WorldGroup:AddToggle("FullbrightEnabled", {
    Text = "Fullbright",
    Default = false,
    Callback = function(value)
        SetFullbrightEnabled(value)
    end
})

local MiscTab = Window:AddTab("Misc")

local FlyGroup = MiscTab:AddGroupbox({
    Name = "puzo exploit",
    Side = 1
})

FlyGroup:AddToggle("puzo exploit", {
    Text = "Enabled (Press B)",
    Default = false,
    Callback = function(value)
        if value then
            startFly()
        else
            stopFly(true)
        end
    end
})

FlyGroup:AddSlider("FlySpeed", {
    Text = "Speed",
    Min = 10,
    Max = 200,
    Default = 80,
    Rounding = 0,
    Callback = function(value)
        Fly.Speed = value
    end
})

local SettingsTab = Window:AddTab("Settings")

local UnloadGroup = SettingsTab:AddGroupbox({
    Name = "Script Control",
    Side = 1
})

UnloadGroup:AddButton("Unload Script", function()
    ScriptEnabled = false
    Aimbot.Enabled = false
    FOVring:Remove()
    SetChamsEnabled(false)
    for _, highlight in ipairs(AllHighlights) do
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
    end
    SetFullbrightEnabled(false)
    flying = false
    Fly.Enabled = false
    if HRP then HRP.Anchored = false end
    if Humanoid then
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
    end
    destroyGhosts()
    if teleportCoroutine then
        keys.N = false
        teleportCoroutine = nil
    end
    for _, conn in ipairs(AllConnections) do
        if conn then pcall(function() conn:Disconnect() end) end
    end
    for _, drawing in ipairs(AllDrawings) do
        if drawing then pcall(function() drawing:Remove() end) end
    end
    if Library and Library.ScreenGui then
        Library.ScreenGui:Destroy()
    end
    table.clear(AllConnections)
    table.clear(AllDrawings)
    table.clear(AllHighlights)
    getgenv().Toggles = nil
    getgenv().Options = nil
end)

UnloadGroup:AddLabel("Hotkey: Delete to unload")

SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"MenuKeybind"})
SaveManager:SetFolder("PuzoExploit/config")
SaveManager:BuildConfigSection(SettingsTab)
SaveManager:LoadAutoloadConfig()

ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("PuzoExploit/theme")
ThemeManager:ApplyToTab(SettingsTab)

AddConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.Delete then
        if Library and Library.ScreenGui then
            Library.ScreenGui:Destroy()
        end
        ScriptEnabled = false
        Aimbot.Enabled = false
        FOVring:Remove()
        SetChamsEnabled(false)
        SetFullbrightEnabled(false)
        flying = false
        Fly.Enabled = false
        if HRP then HRP.Anchored = false end
        destroyGhosts()
        if teleportCoroutine then
            keys.N = false
            teleportCoroutine = nil
        end
        for _, conn in ipairs(AllConnections) do
            if conn then pcall(function() conn:Disconnect() end) end
        end
        for _, drawing in ipairs(AllDrawings) do
            if drawing then pcall(function() drawing:Remove() end) end
        end
    end
end))
