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
local getgenv = getgenv or function()
    return _G
end

local Library, Toggles, Options = loadstring(game:HttpGet(dec(encoded_lib1)))()
local SaveManager = loadstring(game:HttpGet(dec(encoded_lib2)))()
local ThemeManager = loadstring(game:HttpGet(dec(encoded_lib3)))()

if SaveManager and SaveManager.SetOptionsTEMP then
    SaveManager:SetOptionsTEMP(Options, Toggles)
end

if ThemeManager and ThemeManager.SetOptionsTEMP then
    ThemeManager:SetOptionsTEMP(Options, Toggles)
end

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
local AimbotAimBind = nil

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

local AntiAFK = {
    Enabled = false,
    HookWalkDummy = false,
    HookedWalkDummy = false,
}

local AntiAFKConnection = nil

local function TryHookWalkDummy()
    if AntiAFK.HookedWalkDummy then
        return true
    end

    local env = getgenv and getgenv() or _G
    local sc = (env and (env.setconstant or rawget(env, "setconstant"))) or setconstant
    if not sc then
        return false
    end

    local ok, module = pcall(function()
        return require(LocalPlayer.PlayerScripts.ClientMain.Replications.Workers.WalkDummy)
    end)
    if not ok or not module then
        return false
    end

    local hooked = pcall(function()
        sc(module, 34, function()
            RunService.Heartbeat:Wait()
        end)
    end)
    if hooked then
        AntiAFK.HookedWalkDummy = true
    end
    return hooked
end

local function SetAntiAFKEnabled(state)
    AntiAFK.Enabled = state

    if state and not AntiAFKConnection then
        AntiAFKConnection = AddConnection(LocalPlayer.Idled:Connect(function()
            local vu = nil
            pcall(function()
                vu = game:GetService("VirtualUser")
            end)
            if vu then
                pcall(function()
                    vu:CaptureController()
                    vu:ClickButton2(Vector2.new(0, 0))
                end)
            end
            if AntiAFK.HookWalkDummy then
                TryHookWalkDummy()
            end
        end))
        return
    end

    if (not state) and AntiAFKConnection then
        AntiAFKConnection:Disconnect()
        AntiAFKConnection = nil
    end
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
    OnlyVisible = false,
    ShowFOV = true,
    FOVColor = Color3.fromRGB(255, 255, 255),
    Key = Enum.UserInputType.MouseButton2,
    PreferredHitbox = "Head",
}

local AimbotState = {
    lockedTarget = nil,
}

local AimbotCache = {
    playerTargets = {},
    npcTargets = {},
    lastPlayerUpdate = 0,
    lastNPCUpdate = 0,
    playerUpdateInterval = 0.25,
    npcUpdateInterval = 2,
}

local FOVring = AddDrawing(Drawing.new("Circle"))
FOVring.Visible = false
FOVring.Thickness = 1.5
FOVring.Radius = Aimbot.FOV
FOVring.Transparency = 1
FOVring.Color = Aimbot.FOVColor
FOVring.Position = Camera.ViewportSize / 2

local function UpdateAimbotPlayerCache()
    if not ScriptEnabled then return end
    local newTargets = {}
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            if char then
                local humanoid = char:FindFirstChild("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    if Aimbot.TeamCheck and LocalPlayer.Team and player.Team == LocalPlayer.Team then
                    else
                        table.insert(newTargets, {char = char, humanoid = humanoid, isPlayer = true, player = player})
                    end
                end
            end
        end
    end
    
    AimbotCache.playerTargets = newTargets
    AimbotCache.lastPlayerUpdate = tick()
end

local function UpdateAimbotNPCCache()
    if not ScriptEnabled then return end
    local newTargets = {}

    for _, model in ipairs(workspace:GetDescendants()) do
        if model:IsA("Model") then
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                if not (model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")) then
                    continue
                end
                local isPlayerChar = false
                for _, player in ipairs(Players:GetPlayers()) do
                    if player.Character == model then
                        isPlayerChar = true
                        break
                    end
                end
                if not isPlayerChar then
                    table.insert(newTargets, {char = model, humanoid = humanoid, isPlayer = false})
                end
            end
        end
    end

    AimbotCache.npcTargets = newTargets
    AimbotCache.lastNPCUpdate = tick()
end

local AimbotHitboxNames = { "Head", "HumanoidRootPart", "UpperTorso", "LowerTorso", "Torso" }
local MaterialNames = {}
do
    MaterialNames = { "ForceField", "Foil", "Glass", "Ice", "Metal" }
end

local function IsPartVisible(targetCharacter, part)
    local cameraPos = Camera.CFrame.Position
    local direction = part.Position - cameraPos
    local distance = direction.Magnitude
    if distance <= 0 then
        return true
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    local myChar = LocalPlayer and LocalPlayer.Character or nil
    if myChar then
        params.FilterDescendantsInstances = { myChar }
    else
        params.FilterDescendantsInstances = {}
    end
    params.IgnoreWater = true

    local result = workspace:Raycast(cameraPos, direction, params)
    if not result then
        return true
    end

    if not result.Instance then
        return false
    end

    if not result.Instance:IsDescendantOf(targetCharacter) then
        return false
    end

    if result.Instance == part then
        return true
    end

    if part.Name == "Head" then
        return true
    end

    return false
end

local function FindCharacterPart(character, partName)
    if not character then
        return nil
    end
    local part = character:FindFirstChild(partName)
    if part and part:IsA("BasePart") then
        return part
    end
    part = character:FindFirstChild(partName, true)
    if part and part:IsA("BasePart") then
        return part
    end
    return nil
end

local function GetBestAimPartForCharacter(targetCharacter)
    local preferred = Aimbot.PreferredHitbox
    local center = Camera.ViewportSize / 2
    local preferredPart = preferred and FindCharacterPart(targetCharacter, preferred) or nil
    if preferredPart then
        local screenPos, onScreen = Camera:WorldToScreenPoint(preferredPart.Position)
        if onScreen and screenPos.Z > 0 then
            local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
            if screenDist <= Aimbot.FOV and ((not Aimbot.OnlyVisible) or IsPartVisible(targetCharacter, preferredPart)) then
                return preferredPart
            end
        end
    end

    local bestPart = nil
    local bestScore = math.huge

    for _, partName in ipairs(AimbotHitboxNames) do
        local part = FindCharacterPart(targetCharacter, partName)
        if part then
            local screenPos, onScreen = Camera:WorldToScreenPoint(part.Position)
            if onScreen and screenPos.Z > 0 then
                local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                if screenDist <= Aimbot.FOV and ((not Aimbot.OnlyVisible) or IsPartVisible(targetCharacter, part)) then
                    local score = screenDist
                    if partName == preferred then
                        score = score - 25
                    elseif partName == "Head" then
                        score = score - 8
                    end

                    if score < bestScore then
                        bestScore = score
                        bestPart = part
                    end
                end
            end
        end
    end

    return bestPart
end

local function GetBestTarget()
    local bestTarget = nil
    local bestPart = nil
    local bestScore = math.huge
    local preferred = Aimbot.PreferredHitbox
    local center = Camera.ViewportSize / 2

    for _, target in ipairs(AimbotCache.playerTargets) do
        local char = target.char
        local humanoid = target.humanoid
        if char and humanoid and humanoid.Health > 0 then
            local part = GetBestAimPartForCharacter(char)
            if part then
                local screenPos = Camera:WorldToScreenPoint(part.Position)
                local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                local score = screenDist
                if part.Name == preferred then
                    score = score - 35
                end

                if score < bestScore then
                    bestScore = score
                    bestTarget = target
                    bestPart = part
                end
            end
        end
    end

    if Aimbot.AimNPC then
        for _, target in ipairs(AimbotCache.npcTargets) do
            local char = target.char
            local humanoid = target.humanoid
            if char and humanoid and humanoid.Health > 0 then
                local part = GetBestAimPartForCharacter(char)
                if part then
                    local screenPos = Camera:WorldToScreenPoint(part.Position)
                    local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                    local score = screenDist
                    if part.Name == preferred then
                        score = score - 35
                    end

                    if score < bestScore then
                        bestScore = score
                        bestTarget = target
                        bestPart = part
                    end
                end
            end
        end
    end

    return bestTarget, bestPart
end

local function GetAimPartForTarget(target)
    if not target or not target.char or not target.humanoid then
        return nil
    end
    if target.humanoid.Health <= 0 then
        return nil
    end
    local part = GetBestAimPartForCharacter(target.char)
    if not part then
        return nil
    end
    local screenPos, onScreen = Camera:WorldToScreenPoint(part.Position)
    if not onScreen or screenPos.Z <= 0 then
        return nil
    end
    local center = Camera.ViewportSize / 2
    local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
    if screenDist > Aimbot.FOV then
        return nil
    end
    return part
end

UpdateAimbotPlayerCache()
UpdateAimbotNPCCache()

AddConnection(task.spawn(function()
    while ScriptEnabled do
        task.wait(0.1)
        if Aimbot.Enabled then
            local now = tick()
            if now - AimbotCache.lastPlayerUpdate >= AimbotCache.playerUpdateInterval then
                UpdateAimbotPlayerCache()
            end
            if Aimbot.AimNPC and (now - AimbotCache.lastNPCUpdate >= AimbotCache.npcUpdateInterval) then
                UpdateAimbotNPCCache()
            end
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
    
    local pressed
    if AimbotAimBind and AimbotAimBind.GetState then
        pressed = AimbotAimBind:GetState()
    else
        pressed = UserInputService:IsMouseButtonPressed(Aimbot.Key)
    end
    if pressed then
        local aimPart = GetAimPartForTarget(AimbotState.lockedTarget)
        if not aimPart then
            local bestTarget
            bestTarget, aimPart = GetBestTarget()
            AimbotState.lockedTarget = bestTarget
        end
        if aimPart then
            local newCF = CFrame.new(Camera.CFrame.Position, aimPart.Position)
            Camera.CFrame = Camera.CFrame:Lerp(newCF, Aimbot.Smoothing)
        end
    else
        AimbotState.lockedTarget = nil
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
    TeamColor = false,
    ApplyMaterial = true,
    Material = Enum.Material.ForceField,
    MaterialName = "ForceField",
}

local ChamsConnection = nil
local ChamsTracked = {}

local function ApplyChamsMaterial(character, color)
    local tracked = ChamsTracked[character]
    if not tracked then
        tracked = {}
        ChamsTracked[character] = tracked
    end

    for _, obj in ipairs(character:GetDescendants()) do
        if obj:IsA("BasePart") then
            local original = tracked[obj]
            if not original then
                tracked[obj] = {
                    Material = obj.Material,
                    Color = obj.Color,
                    LocalTransparencyModifier = obj.LocalTransparencyModifier,
                }
            end

            obj.Material = Chams.Material
            obj.Color = color
            obj.LocalTransparencyModifier = Chams.Transparency
        end
    end

    for part, original in pairs(tracked) do
        if not part or not part.Parent or not part:IsDescendantOf(character) then
            tracked[part] = nil
        end
    end
end

local function RestoreChamsMaterial(character)
    local tracked = ChamsTracked[character]
    if not tracked then
        return
    end

    for part, original in pairs(tracked) do
        if part and part.Parent then
            part.Material = original.Material
            part.Color = original.Color
            part.LocalTransparencyModifier = original.LocalTransparencyModifier
        end
    end

    ChamsTracked[character] = nil
end

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

    if Chams.ApplyMaterial then
        ApplyChamsMaterial(character, color)
    else
        RestoreChamsMaterial(character)
    end
end

local function RemoveChamsFromPlayer(plr)
    if plr == LocalPlayer then return end
    local character = plr.Character
    if character then
        local highlight = character:FindFirstChildOfClass("Highlight")
        if highlight then highlight:Destroy() end
        RestoreChamsMaterial(character)
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
    Enabled = false,
    Color = Color3.new(1, 1, 1),
}

local CustomTime = {
    Enabled = false,
    Time = 12,
}

local WorldLighting = {
    Original = nil,
    Connection = nil,
}

local function CaptureWorldOriginal()
    if WorldLighting.Original then
        return
    end

    WorldLighting.Original = {
        Brightness = Lighting.Brightness,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        GlobalShadows = Lighting.GlobalShadows,
        FogEnd = Lighting.FogEnd,
        ClockTime = Lighting.ClockTime,
        GeographicLatitude = Lighting.GeographicLatitude,
        Technology = Lighting.Technology,
    }
end

local function RestoreWorldOriginal()
    local original = WorldLighting.Original
    if not original then
        return
    end

    Lighting.Brightness = original.Brightness
    Lighting.Ambient = original.Ambient
    Lighting.OutdoorAmbient = original.OutdoorAmbient
    Lighting.GlobalShadows = original.GlobalShadows
    Lighting.FogEnd = original.FogEnd
    Lighting.ClockTime = original.ClockTime
    Lighting.GeographicLatitude = original.GeographicLatitude
    Lighting.Technology = original.Technology
end

local function ApplyWorldLighting()
    if not ScriptEnabled then
        return
    end

    CaptureWorldOriginal()
    RestoreWorldOriginal()

    if Fullbright.Enabled then
        Lighting.Brightness = 0
        Lighting.Ambient = Fullbright.Color
        Lighting.OutdoorAmbient = Fullbright.Color
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1e10
        Lighting.GeographicLatitude = 0
        Lighting.Technology = Enum.Technology.ShadowMap
    end

    if CustomTime.Enabled then
        Lighting.ClockTime = CustomTime.Time
    end
end

local function UpdateWorldLightingConnection()
    local shouldRun = Fullbright.Enabled or CustomTime.Enabled

    if shouldRun and not WorldLighting.Connection then
        WorldLighting.Connection = RunService.Heartbeat:Connect(ApplyWorldLighting)
        AddConnection(WorldLighting.Connection)
        ApplyWorldLighting()
        return
    end

    if (not shouldRun) and WorldLighting.Connection then
        WorldLighting.Connection:Disconnect()
        WorldLighting.Connection = nil
        RestoreWorldOriginal()
        WorldLighting.Original = nil
    end
end

local function SetFullbrightEnabled(state)
    Fullbright.Enabled = state
    UpdateWorldLightingConnection()
end

local function SetCustomTimeEnabled(state)
    CustomTime.Enabled = state
    UpdateWorldLightingConnection()
end

local function SetCustomTimeValue(value)
    CustomTime.Time = value
    if CustomTime.Enabled then
        ApplyWorldLighting()
    end
end

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HRP = Character:WaitForChild("HumanoidRootPart")

local Fly = {
    Enabled = false,
    Speed = 80,
    TeleportMode = true,
}

local flying = false
local speed = Fly.Speed
local keys = {
    W = false, A = false, S = false, D = false,
    Space = false, LeftShift = false,
}

local blueGhost = nil
local yellowGhost = nil
local lastTeleportPos = nil
local lastTeleportTick = 0
local flyBodyVelocity = nil
local flyBodyGyro = nil
local flyNoclipTracked = nil
local flyOriginalPlatformStand = nil
local flyOriginalAutoRotate = nil
local FlyToggleControl = nil
local FlyBind = nil
local FlyTeleportBind = nil
local FlyPlaceBind = nil
AimbotAimBind = nil
local UnloadBind = nil
local HitboxExpanderToggle = nil

local HitboxExpander = {
    Enabled = false,
    Scale = 1.5,
    Parts = { Head = true },
}

local HitboxExpanderPartNames = {
    "Head",
    "HumanoidRootPart",
    "UpperTorso",
    "LowerTorso",
    "Torso",
    "LeftUpperArm",
    "RightUpperArm",
    "LeftLowerArm",
    "RightLowerArm",
    "LeftHand",
    "RightHand",
    "LeftUpperLeg",
    "RightUpperLeg",
    "LeftLowerLeg",
    "RightLowerLeg",
    "LeftFoot",
    "RightFoot",
    "Left Arm",
    "Right Arm",
    "Left Leg",
    "Right Leg",
}

local HitboxTracked = {}
local HitboxExpanderConnection = nil

local function RestoreHitboxesForCharacter(character)
    local tracked = HitboxTracked[character]
    if not tracked then
        return
    end

    for part, original in pairs(tracked) do
        if part and part.Parent then
            part.Size = original.Size
            part.CanCollide = original.CanCollide
            part.CanTouch = original.CanTouch
            part.Massless = original.Massless
        end
    end

    HitboxTracked[character] = nil
end

local function ApplyHitboxesForCharacter(character)
    local tracked = HitboxTracked[character]
    if not tracked then
        tracked = {}
        HitboxTracked[character] = tracked
    end

    for _, partName in ipairs(HitboxExpanderPartNames) do
        local selected = HitboxExpander.Parts[partName] == true
        local part = character:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            if selected then
                local original = tracked[part]
                if not original then
                    tracked[part] = {
                        Size = part.Size,
                        CanCollide = part.CanCollide,
                        CanTouch = part.CanTouch,
                        Massless = part.Massless,
                    }
                    original = tracked[part]
                end

                part.Size = original.Size * HitboxExpander.Scale
                part.CanCollide = false
                part.CanTouch = false
                part.Massless = original.Massless
            else
                local original = tracked[part]
                if original then
                    part.Size = original.Size
                    part.CanCollide = original.CanCollide
                    part.CanTouch = original.CanTouch
                    part.Massless = original.Massless
                    tracked[part] = nil
                end
            end
        end
    end

    for part, original in pairs(tracked) do
        if not part or not part.Parent or not part:IsDescendantOf(character) then
            tracked[part] = nil
        end
    end

    if not next(tracked) then
        HitboxTracked[character] = nil
    end
end

local function UpdateHitboxExpander()
    if not ScriptEnabled then
        return
    end
    if not HitboxExpander.Enabled then
        return
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            if char then
                ApplyHitboxesForCharacter(char)
            end
        end
    end
end

local function SetHitboxExpanderEnabled(state)
    HitboxExpander.Enabled = state

    if state and not HitboxExpanderConnection then
        HitboxExpanderConnection = RunService.Heartbeat:Connect(UpdateHitboxExpander)
        AddConnection(HitboxExpanderConnection)
        UpdateHitboxExpander()
        return
    end

    if (not state) and HitboxExpanderConnection then
        HitboxExpanderConnection:Disconnect()
        HitboxExpanderConnection = nil
        local characters = {}
        for character, _ in pairs(HitboxTracked) do
            table.insert(characters, character)
        end
        for _, character in ipairs(characters) do
            if character then
                RestoreHitboxesForCharacter(character)
            end
        end
    end
end

local function SetHitboxExpanderScale(scale)
    HitboxExpander.Scale = scale
    if HitboxExpander.Enabled then
        UpdateHitboxExpander()
    end
end

local function SetHitboxExpanderParts(map)
    HitboxExpander.Parts = map or {}
    if HitboxExpander.Enabled then
        UpdateHitboxExpander()
    end
end

AddConnection(Players.PlayerRemoving:Connect(function(plr)
    if plr and plr.Character then
        RestoreHitboxesForCharacter(plr.Character)
    end
end))

local function GetBindValue(optionOrValue)
    if type(optionOrValue) == "table" and optionOrValue.Value ~= nil then
        return optionOrValue.Value
    end
    return optionOrValue
end

local function IsBindMatch(optionOrValue, input)
    local bind = GetBindValue(optionOrValue)
    if bind == nil or bind == "None" or bind == "NONE" then
        return false
    end

    if bind == "MB1" then
        return input.UserInputType == Enum.UserInputType.MouseButton1
    end
    if bind == "MB2" then
        return input.UserInputType == Enum.UserInputType.MouseButton2
    end
    if bind == "MB3" then
        return input.UserInputType == Enum.UserInputType.MouseButton3
    end
    if bind == "MB4" then
        return input.UserInputType == Enum.UserInputType.MouseButton4
    end
    if bind == "MB5" then
        return input.UserInputType == Enum.UserInputType.MouseButton5
    end

    return input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == bind
end

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

local function SetCharacterNoclipEnabled(state)
    if not Character then
        return
    end

    if state then
        if flyNoclipTracked then
            return
        end
        flyNoclipTracked = {}
        for _, obj in ipairs(Character:GetDescendants()) do
            if obj:IsA("BasePart") then
                flyNoclipTracked[obj] = {
                    CanCollide = obj.CanCollide,
                    CanTouch = obj.CanTouch,
                }
                obj.CanCollide = false
                obj.CanTouch = false
            end
        end
        return
    end

    if not flyNoclipTracked then
        return
    end
    for part, original in pairs(flyNoclipTracked) do
        if part and part.Parent then
            part.CanCollide = original.CanCollide
            part.CanTouch = original.CanTouch
        end
    end
    flyNoclipTracked = nil
end

local function SetupPhysicsFly()
    if not HRP then
        return
    end

    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    if flyBodyGyro then
        flyBodyGyro:Destroy()
        flyBodyGyro = nil
    end

    flyBodyVelocity = Instance.new("BodyVelocity")
    flyBodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    flyBodyVelocity.P = 12500
    flyBodyVelocity.Velocity = Vector3.zero
    flyBodyVelocity.Parent = HRP

    flyBodyGyro = Instance.new("BodyGyro")
    flyBodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    flyBodyGyro.P = 4500
    flyBodyGyro.CFrame = Camera.CFrame
    flyBodyGyro.Parent = HRP
end

local function TeardownPhysicsFly()
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    if flyBodyGyro then
        flyBodyGyro:Destroy()
        flyBodyGyro = nil
    end
end

local function TeleportCharacterTo(pos)
    if not Character or not HRP or not pos then
        return
    end
    HRP.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    HRP.AssemblyLinearVelocity = Vector3.zero
    HRP.AssemblyAngularVelocity = Vector3.zero
end

local function startFly()
    if flying then return end
    destroyGhosts()
    flying = true
    Fly.Enabled = true
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)

    if Fly.TeleportMode then
        blueGhost = createGhost("Blue", HRP.Position)
        HRP.Anchored = true
    else
        HRP.Anchored = false
        flyOriginalPlatformStand = Humanoid.PlatformStand
        flyOriginalAutoRotate = Humanoid.AutoRotate
        Humanoid.PlatformStand = true
        Humanoid.AutoRotate = false
        Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        SetupPhysicsFly()
        SetCharacterNoclipEnabled(true)
    end
end

local function stopFly(teleportToYellow)
    if not flying then return end
    destroyGhosts()
    HRP.Anchored = false
    TeardownPhysicsFly()
    SetCharacterNoclipEnabled(false)
    if flyOriginalPlatformStand ~= nil then
        Humanoid.PlatformStand = flyOriginalPlatformStand
        flyOriginalPlatformStand = nil
    else
        Humanoid.PlatformStand = false
    end
    if flyOriginalAutoRotate ~= nil then
        Humanoid.AutoRotate = flyOriginalAutoRotate
        flyOriginalAutoRotate = nil
    else
        Humanoid.AutoRotate = true
    end
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
    flying = false
    Fly.Enabled = false

    if teleportToYellow and lastTeleportPos then
        TeleportCharacterTo(lastTeleportPos)
    end
end

local function placeYellowGhostAtMouse(input)
    if not flying then return end
    if not Fly.TeleportMode then return end
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

AddConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not ScriptEnabled then return end
    if gameProcessed then return end

    if flying and IsBindMatch(Options and Options.FlyPlaceBind, input) then
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
    end
end))

AddConnection(RunService.RenderStepped:Connect(function(dt)
    if not ScriptEnabled then return end
    if FlyToggleControl and FlyBind and FlyBind.GetState and FlyBind.Mode == "Hold" then
        local desired = FlyBind:GetState()
        if desired ~= FlyToggleControl.Value then
            FlyToggleControl:SetValue(desired)
        end
    end

    if flying and Fly.TeleportMode and FlyTeleportBind and FlyTeleportBind.GetState and FlyTeleportBind:GetState() and lastTeleportPos then
        local now = tick()
        if now - lastTeleportTick >= 0.1 then
            lastTeleportTick = now
            TeleportCharacterTo(lastTeleportPos)
        end
    end

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

        if blueGhost then
            blueGhost.Position = HRP.Position
        end

        if moveDirection.Magnitude > 0 then
            moveDirection = moveDirection.Unit
        end

        if Fly.TeleportMode then
            if moveDirection.Magnitude > 0 then
                HRP.CFrame = HRP.CFrame + (moveDirection * Fly.Speed * dt)
            end
        else
            if flyBodyGyro then
                flyBodyGyro.CFrame = Camera.CFrame
            end
            if flyBodyVelocity then
                flyBodyVelocity.Velocity = moveDirection * Fly.Speed
            end
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
    TeardownPhysicsFly()
    flyNoclipTracked = nil
    flyOriginalPlatformStand = nil
    flyOriginalAutoRotate = nil
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
            UpdateAimbotPlayerCache()
            if Aimbot.AimNPC then
                UpdateAimbotNPCCache()
            end
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

AimbotMain:AddToggle("AimbotOnlyVisible", {
    Text = "Only if visible",
    Default = false,
    Callback = function(value)
        Aimbot.OnlyVisible = value
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

AimbotSettings:AddDropdown("AimbotHitbox", {
    Text = "Preferred Hitbox",
    Values = AimbotHitboxNames,
    Default = Aimbot.PreferredHitbox,
    Callback = function(value)
        Aimbot.PreferredHitbox = value
    end
})

AimbotSettings:AddLabel("Aim bind"):AddBinder("AimbotAimBind", {
    Text = "Aimbot Aim",
    Default = "MB2",
    Mode = "Hold",
})
AimbotAimBind = Options and Options.AimbotAimBind or nil

AimbotSettings:AddLabel("FOV Color"):AddColorPicker("AimbotFOVColor", {
    Default = Aimbot.FOVColor,
    Title = "FOV Color",
    Callback = function(value)
        Aimbot.FOVColor = value
    end
})

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

ChamsGroup:AddLabel("Chams Color"):AddColorPicker("ChamsColor", {
    Default = Chams.Color,
    Title = "Chams Color",
    Callback = function(value)
        Chams.Color = value
    end
})

ChamsGroup:AddToggle("ChamsApplyMaterial", {
    Text = "Apply Material",
    Default = true,
    Callback = function(value)
        Chams.ApplyMaterial = value
        if not value then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    RestoreChamsMaterial(plr.Character)
                end
            end
        end
    end
})

ChamsGroup:AddDropdown("ChamsMaterial", {
    Text = "Material",
    Values = MaterialNames,
    Default = Chams.MaterialName,
    Callback = function(value)
        Chams.MaterialName = value
        Chams.Material = Enum.Material[value]
    end
})

local WorldGroup = VisualsTab:AddGroupbox({
    Name = "World",
    Side = 2
})

local FullbrightToggle = WorldGroup:AddToggle("FullbrightEnabled", {
    Text = "Fullbright",
    Default = false,
    Callback = function(value)
        SetFullbrightEnabled(value)
    end
})

FullbrightToggle:AddColorPicker("FullbrightColor", {
    Default = Fullbright.Color,
    Title = "Fullbright Color",
    Callback = function(value)
        Fullbright.Color = value
        if Fullbright.Enabled then
            ApplyWorldLighting()
        end
    end
})

WorldGroup:AddToggle("CustomTimeEnabled", {
    Text = "Custom Time",
    Default = false,
    Callback = function(value)
        SetCustomTimeEnabled(value)
    end
})

WorldGroup:AddSlider("CustomTime", {
    Text = "Time",
    Min = 0,
    Max = 24,
    Default = 12,
    Rounding = 2,
    Callback = function(value)
        SetCustomTimeValue(value)
    end
})

local MiscTab = Window:AddTab("Misc")

local FlyGroup = MiscTab:AddGroupbox({
    Name = "puzo exploit",
    Side = 1
})

FlyToggleControl = FlyGroup:AddToggle("puzo exploit", {
    Text = "Enabled",
    Default = false,
    Callback = function(value)
        if value then
            startFly()
        else
            stopFly(true)
        end

        if FlyBind and FlyBind.Mode == "Toggle" and FlyBind.Update then
            FlyBind.Toggled = value
            FlyBind:Update()
        end
    end
})

FlyToggleControl:AddBinder("FlyBind", {
    Text = "Fly",
    Default = "B",
    Mode = "Toggle",
    Callback = function(state)
        if FlyToggleControl then
            FlyToggleControl:SetValue(state)
        end
    end
})
FlyBind = Options and Options.FlyBind or nil

FlyGroup:AddLabel("Teleport bind"):AddBinder("FlyTeleportBind", {
    Text = "Teleport",
    Default = "N",
    Mode = "Hold",
})
FlyTeleportBind = Options and Options.FlyTeleportBind or nil

FlyGroup:AddLabel("Place marker bind"):AddBinder("FlyPlaceBind", {
    Text = "Place marker",
    Default = "MB3",
    Mode = "Hold",
})
FlyPlaceBind = Options and Options.FlyPlaceBind or nil

FlyGroup:AddToggle("FlyTeleportMode", {
    Text = "Teleport Fly (Anchored)",
    Default = true,
    Callback = function(value)
        Fly.TeleportMode = value
        if flying then
            stopFly(false)
            startFly()
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

local AntiAFKGroup = MiscTab:AddGroupbox({
    Name = "Anti AFK",
    Side = 1
})

AntiAFKGroup:AddToggle("AntiAFKEnabled", {
    Text = "Enabled",
    Default = false,
    Callback = function(value)
        SetAntiAFKEnabled(value)
    end
})

AntiAFKGroup:AddToggle("AntiAFKHookWalkDummy", {
    Text = "Hook WalkDummy",
    Default = false,
    Callback = function(value)
        AntiAFK.HookWalkDummy = value
        if value and AntiAFK.Enabled then
            TryHookWalkDummy()
        end
    end
})

local HitboxGroup = MiscTab:AddGroupbox({
    Name = "Hitbox Expander",
    Side = 2
})

HitboxGroup:AddToggle("HitboxExpanderEnabled", {
    Text = "Enabled",
    Default = false,
    Callback = function(value)
        SetHitboxExpanderEnabled(value)
    end
})

HitboxGroup:AddSlider("HitboxExpanderScale", {
    Text = "Scale",
    Min = 1,
    Max = 5,
    Default = 1.5,
    Rounding = 2,
    Callback = function(value)
        SetHitboxExpanderScale(value)
    end
})

HitboxGroup:AddDropdown("HitboxExpanderParts", {
    Text = "Hitboxes",
    Values = HitboxExpanderPartNames,
    Default = { "Head" },
    Multi = true,
    Callback = function(value)
        SetHitboxExpanderParts(value)
    end
})

local SettingsTab = Window:AddTab("Settings")

local UnloadGroup = SettingsTab:AddGroupbox({
    Name = "Script Control",
    Side = 1
})

local function UnloadScript()
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
    SetCustomTimeEnabled(false)
    SetHitboxExpanderEnabled(false)
    flying = false
    Fly.Enabled = false
    if HRP then HRP.Anchored = false end
    if Humanoid then
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
    end
    destroyGhosts()
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
    pcall(function()
        getgenv().Toggles = nil
        getgenv().Options = nil
    end)
end

UnloadGroup:AddButton("Unload Script", UnloadScript)

UnloadGroup:AddLabel("Unload bind"):AddBinder("UnloadBind", {
    Text = "Unload",
    Default = "Delete",
    Modes = { "Toggle" },
    Mode = "Toggle",
    Callback = function(state)
        if not state then
            return
        end

        UnloadScript()

        local opt = Options and Options.UnloadBind
        if opt then
            opt.Toggled = false
            opt:Update()
        end
    end
})
UnloadBind = Options and Options.UnloadBind or nil

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
    if gameProcessed then
        return
    end
    if UnloadBind then
        return
    end
    if input.KeyCode == Enum.KeyCode.Delete then
        UnloadScript()
    end
end))
--xru
