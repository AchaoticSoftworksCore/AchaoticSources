local Neverzen = loadstring(game:HttpGet("https://raw.githubusercontent.com/AchaoticSoftworksCore/AchaoticAssets/refs/heads/main/UiLibrarys/Neverzen.luau"))()

local Services = {
    NZNotification = Neverzen:CreateNotifier(),
    RunService = game:GetService("RunService"),
    UserInputService = game:GetService("UserInputService"),
    Players = game:GetService("Players"),
    Workspace = game:GetService("Workspace"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    VirtualInputManager = game:GetService("VirtualInputManager"),
    Debris = game:GetService("Debris"),
    TweenService = game:GetService("TweenService")
}

Services.CurrentCamera = Services.Workspace.CurrentCamera
Services.ServerStatsItem = game:GetService("Stats").Network.ServerStatsItem
Services.SwordAPI = Services.ReplicatedStorage.Shared.SwordAPI

local Player = {
    LocalPlayer = Services.Players.LocalPlayer,
    Character = nil,
    Humanoid = nil,
    CurrentPlayerFPS = 0
}

local Connections = {
    NoRender = nil,
    MainConnection = nil
}

local Script = {
    Running = true,
    ExecutorParent = identifyexecutor()
}

Services.NZNotification.new('BB Achaotic', 'Attempting to Load Blade Ball, Running in ' .. Script.ExecutorParent .. '.', 5)

task.wait(math.random(0.1, 0.9))

local RemotesDATA = {
    ParryFunction = nil,
    RemotesCaptured = false,
    ParryHash = nil,
    ParryIndex = nil,
    Remotes = {}
}

local originalMetatables = {}

Services.NZNotification.new('BB Achaotic', 'New fetch patched using old fetch method.', 12)
Services.NZNotification.new('BB Achaotic', 'Please block once to capture', 20)

local function isValidRemoteArgs(args)
    return #args == 7 and type(args[2]) == "string" and type(args[3]) == "number" and typeof(args[4]) == "CFrame" and type(args[5]) == "table" and type(args[6]) == "table" and type(args[7]) == "boolean"
end

local function hookRemote(remote)
    if RemotesDATA.Remotes[remote] or originalMetatables[getmetatable(remote)] then return end
    originalMetatables[getmetatable(remote)] = true
    local meta = getrawmetatable(remote)
    setreadonly(meta, false)
    local oldIndex = meta.__index
    meta.__index = function(self, key)
        if key ~= "FireServer" or not self:IsA("RemoteEvent") then return oldIndex(self, key) end
        return function(_, ...)
            local args = {...}
            if isValidRemoteArgs(args) and not RemotesDATA.Remotes[self] then
                RemotesDATA.Remotes[self] = args
                RemotesDATA.ParryHash = args[2]
                RemotesDATA.ParryIndex = args[3]
                RemotesDATA.RemotesCaptured = true
            end
            return oldIndex(self, key)(_, unpack(args))
        end
    end
    setreadonly(meta, true)
end

for _, remote in pairs(Services.ReplicatedStorage:GetChildren()) do
    if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
        hookRemote(remote)
    end
end

Services.ReplicatedStorage.ChildAdded:Connect(function(child)
    if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
        hookRemote(child)
    end
end)

task.spawn(function()
    repeat task.wait() until RemotesDATA.RemotesCaptured
    Services.NZNotification.new('BB Achaotic', 'Successfully captured remotes', 5)
end)

local Balls = Services.Workspace:WaitForChild("Balls")
local Runtime = Services.Workspace:WaitForChild("Runtime")

local Parry = {
    SpeedDivisorMultiplier = 1.1,
    LastParry = os.clock(),
    Parried = false,
    AnimationDelay = 1,
    GrabParry = nil,
    AutoParryEnabled = false,
    AutoParryAnimationFix = false,
    AutoSpamParryEnabled = false,
    AutoSpamParryAnimationFix = false,
    AutoSpamParrySpamming = false,
    AutoSpamParryThreshold = 3,
    Parries = 0,
    ManualSpamParrySpamming = false,
    ManualSpamParryUI = false,
    ManualSpamParryKeybind = Enum.KeyCode.E,
    ManualSpamParryAnimationFix = false,
    lastParryTime = 0,
    TornadoTime = 0,
    SpammingMaxSpeed = 100,
    SpammingMode = "Advanced",
    SpamParryCooldownBypass = false,
    AdvancedSpammingDelayBypass = false,
    ParryMethod = "Blatant",
    ParryHashCheck = false,
    AnimationCache = {},
    SpamAnimationParries = 0,
    AnimationSpammingMode = false,
    LerpRadians = 0,
    LastWarping = tick(),
    PreviousVelocity = {},
    Curving = tick(),
    LastInput = nil
}

local Visuals = {
    VisualisersEnabled = false,
    VisualiserService = {},
    HitEffectEnabled = false,
    HitEffectService = {
        BallEffects = {}
    },
    VisualParts = {}
}

local Immortality = {
    Enabled = false,
    Rotate = false,
    Radius = 40,
    Height = 100
}

local Optimization = {
    NoRenderEnabled = false
}

local UI = {
    Window = Neverzen.new({
        Name = "BB Achaotic",
        Keybind = Enum.KeyCode.LeftControl,
        Scale = UDim2.new(0, 611, 0, 396),
        Resizable = true,
        Shadow = false,
        Acrylic = false
    }),
    ManualSpamParryToggle = nil,
    ScreenGui = nil,
    Handler = nil,
    SpamButton = nil
}

local ManualSpamParryUIService = {}

local function GetCharacter()
    return Player.LocalPlayer.Character
end

local function GetHumanoid()
    local character = GetCharacter()
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function StopAnimation(animationtrack)
    local StopFadeTime = animationtrack:GetAttribute("StopFadeTime")
    animationtrack:Stop(StopFadeTime)
end

local function PlayGrabAnimation(animationtrack)
    local PlayFadeTime = animationtrack:GetAttribute("PlayFadeTime")
    local PlayWeight = animationtrack:GetAttribute("PlayWeight")
    local PlaySpeed = animationtrack:GetAttribute("PlaySpeed")
    animationtrack:Play(PlayFadeTime, PlayWeight, PlaySpeed)
end

local function GetParryAnimation()
    local character = GetCharacter()
    if not character then return nil end
    
    local currentSword = character:GetAttribute("CurrentlyEquippedSword")
    if not currentSword then 
        return Services.SwordAPI.Collection.Default:FindFirstChild("GrabParry")
    end
    
    if Parry.AnimationCache[currentSword] then
        return Parry.AnimationCache[currentSword]
    end
    
    local success, swordData = pcall(function()
        return Services.ReplicatedStorage.Shared.ReplicatedInstances.Swords.GetSword:Invoke(currentSword)
    end)
    
    if not success or not swordData or type(swordData) ~= "table" then
        Parry.AnimationCache[currentSword] = Services.SwordAPI.Collection.Default:FindFirstChild("GrabParry")
        return Parry.AnimationCache[currentSword]
    end
    
    if not swordData.AnimationType or type(swordData.AnimationType) ~= "string" then
        Parry.AnimationCache[currentSword] = Services.SwordAPI.Collection.Default:FindFirstChild("GrabParry")
        return Parry.AnimationCache[currentSword]
    end
    
    local swordCollection = Services.SwordAPI.Collection
    for _, object in pairs(swordCollection:GetChildren()) do
        if object.Name == swordData.AnimationType then
            local animation = object:FindFirstChild("GrabParry") or object:FindFirstChild("Grab")
            if animation then
                Parry.AnimationCache[currentSword] = animation
                return animation
            end
        end
    end
    
    Parry.AnimationCache[currentSword] = Services.SwordAPI.Collection.Default:FindFirstChild("GrabParry")
    return Parry.AnimationCache[currentSword]
end

local lastplayedd = 0
local lastplayedds = 0
local bypasscd = false

local function PlayParry_Animation()
    if Parry.ParryMethod == "Legit" then return end
    local humanoid = GetHumanoid()
    if not humanoid then return end
    
    local animation = GetParryAnimation()
    if not animation then 
        animation = Services.SwordAPI.Collection.Default:FindFirstChild("GrabParry")
        if not animation then return end
    end
     
    for _, track in pairs(humanoid.Animator:GetPlayingAnimationTracks()) do
        if track.Name == "GrabParry" or track.Name == "Grab" then
            if not Parry.AnimationSpammingMode then
                track.TimePosition = 0
            end
            StopAnimation(track)
        elseif track.Name == "SuccessParry" or track.Name == "Success" then
            if Parry.AnimationSpammingMode then
                track.TimePosition = 0
            end
            StopAnimation(track)
        end
    end
    
    Parry.GrabParry = humanoid.Animator:LoadAnimation(animation)
    PlayGrabAnimation(Parry.GrabParry)
end

local function SpamParry_Animation()
  if (os.clock() - lastplayedd) >= (1/90) then
    lastplayedd = os.clock()
    if (os.clock() - lastplayedds) >= (Parry.AnimationSpammingMode and (1/60) or 0.1) or bypasscd then
        lastplayedds = os.clock()
        bypasscd = false
        PlayParry_Animation()
    end
  end
end

Services.UserInputService.InputBegan:Connect(function(input, gameProcessed)
    Parry.LastInput = input.UserInputType
end)

local function GetParry_Data()
    local Events = {}
    local Vector2_Mouse_Location
    
    local isMobile = Services.UserInputService.TouchEnabled and not Services.UserInputService.MouseEnabled
    local isRelevantInput = Parry.LastInput and (
        Parry.LastInput == Enum.UserInputType.MouseButton1 or 
        Parry.LastInput == Enum.UserInputType.MouseButton2 or 
        Parry.LastInput == Enum.UserInputType.Keyboard
    )
    
    if isRelevantInput and not isMobile then
        local Mouse_Location = Services.UserInputService:GetMouseLocation()
        Vector2_Mouse_Location = {Mouse_Location.X, Mouse_Location.Y}
    else
        local viewportSize = Services.CurrentCamera.ViewportSize
        Vector2_Mouse_Location = {viewportSize.X / 2, viewportSize.Y / 2}
    end
    
    local alivePlayers = Services.Workspace.Alive:GetChildren()
    for _, v in ipairs(alivePlayers) do
        if v ~= GetCharacter() and v.PrimaryPart then
            local screenPos, isOnScreen = Services.CurrentCamera:WorldToScreenPoint(v.PrimaryPart.Position)
            if isOnScreen then
                Events[tostring(v)] = screenPos
            end
        end
    end
    
    return {
        Services.CurrentCamera.CFrame,
        Events,
        Vector2_Mouse_Location
    }
end

local function FireParry()
    if Parry.ParryMethod == "Blatant" then
        local IsFakeHash = false
        local Remotes = RemotesDATA.Remotes
        if Parry.ParryHashCheck then
            for _, Args in pairs(Remotes) do
                if Args[1] == "PARRY_HASH_FAKE_1" or Args[1] == "_G" then
                    IsFakeHash = true
                    break
                end
            end
        end
        
        local ParryData = GetParry_Data()
        local ParryHash = RemotesDATA.ParryHash
        local ParryIndex = RemotesDATA.ParryIndex
        
        task.spawn(function()
            for Remote, Args in pairs(Remotes) do
                local Hash = IsFakeHash and nil or Args[1]
                local Arguments = {
                    Hash,
                    ParryHash,
                    ParryIndex,
                    ParryData[1],
                    ParryData[2],
                    ParryData[3]
                }
                
                local success, err = pcall(function()
                    Remote:FireServer(table.unpack(Arguments))
                end)
                
                if not success then
                    warn("Parry fire failed:", err)
                end
            end
        end)
    elseif Parry.ParryMethod == "Legit" then
        Services.VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, nil)
        Services.VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, nil)
    end
    
    if Parry.Parries > 7 then
        return false
    end
    
    Parry.Parries += 1
    task.delay(0.5, function()
        if Parry.Parries > 0 then
            Parry.Parries -= 1
        end
    end)
end

local function Get_Balls()
    local BallInstances = {}
    for _, Instance in pairs(Balls:GetChildren()) do
        if Instance:GetAttribute("realBall") then
            table.insert(BallInstances, Instance)
        end
    end
    return BallInstances
end

local function GetLinear_Interpolation(a, b, time_volume)
    return a + (b - a) * time_volume
end

local function IsBall_Curved(Ball)
    if not Ball then return false end
    
    local Zoomies = Ball:FindFirstChild("zoomies")
    if not Zoomies then return false end
    
    local Ping = Services.ServerStatsItem["Data Ping"]:GetValue()
    local Velocity = Zoomies.VectorVelocity
    local Ball_Direction = Velocity.Unit
    local playerPos = Player.LocalPlayer.Character.PrimaryPart.Position
    local ballPos = Ball.Position
    local Direction = (playerPos - ballPos).Unit
    local Dot = Direction:Dot(Ball_Direction)
    local Speed = Velocity.Magnitude
    local Speed_Threshold = math.min(Speed / 100, 40)
    local Angle_Threshold = 40 * math.max(Dot, 0)
    local Distance = (playerPos - ballPos).Magnitude
    local Reach_Time = Distance / Speed - (Ping / 1000)
    local Ball_Distance_Threshold = 15 - math.min(Distance / 1000, 15) + Speed_Threshold
    
    table.insert(Parry.PreviousVelocity, Velocity)
    if #Parry.PreviousVelocity > 4 then
        table.remove(Parry.PreviousVelocity, 1)
    end
    
    if Ball:FindFirstChild("AeroDynamicSlashVFX") then
        Services.Debris:AddItem(Ball.AeroDynamicSlashVFX, 0)
        Parry.TornadoTime = tick()
    end
    
    if Runtime:FindFirstChild("Tornado") then
        if (tick() - Parry.TornadoTime) < ((Runtime.Tornado:GetAttribute("TornadoTime") or 1) + 0.314159) then
            return true
        end
    end
    
    local Enough_Speed = Speed > 160
    if Enough_Speed and Reach_Time > (Ping / 10 + 0.03) then
        if Speed < 300 then
            Ball_Distance_Threshold = math.max(Ball_Distance_Threshold - 15, 15)
        elseif Speed <= 600 then
            Ball_Distance_Threshold = math.max(Ball_Distance_Threshold - 17, 17)
        elseif Speed <= 1000 then
            Ball_Distance_Threshold = math.max(Ball_Distance_Threshold - 19, 19)
        else
            Ball_Distance_Threshold = math.max(Ball_Distance_Threshold - 20, 20)
        end
    end
    
    if Distance < Ball_Distance_Threshold then return false end
    
    local adjustedReachTime = Reach_Time + 0.03
    if Speed < 300 then
        if (tick() - Parry.Curving) < (adjustedReachTime / 1.2) then return true end
    elseif Speed < 450 then
        if (tick() - Parry.Curving) < (adjustedReachTime / 1.21) then return true end
    elseif Speed < 600 then
        if (tick() - Parry.Curving) < (adjustedReachTime / 1.335) then return true end
    else
        if (tick() - Parry.Curving) < (adjustedReachTime / 1.5) then return true end
    end
    
    local Dot_Threshold = (0 - Ping / 1000)
    local Direction_Difference = (Ball_Direction - Velocity.Unit)
    local Direction_Similarity = Direction:Dot(Direction_Difference.Unit)
    local Dot_Difference = Dot - Direction_Similarity
    
    if Dot_Difference < Dot_Threshold then return true end
    
    local Clamped_Dot = math.clamp(Dot, -1, 1)
    local Radians = math.deg(math.asin(Clamped_Dot))
    Parry.LerpRadians = GetLinear_Interpolation(Parry.LerpRadians, Radians, 0.8)
    
    if Speed < 300 then
        if Parry.LerpRadians < 0.02 then
            Parry.LastWarping = tick()
        end
        if (tick() - Parry.LastWarping) < (adjustedReachTime / 1.19) then return true end
    else
        if Parry.LerpRadians < 0.018 then
            Parry.LastWarping = tick()
        end
        if (tick() - Parry.LastWarping) < (adjustedReachTime / 1.5) then return true end
    end
    
    if #Parry.PreviousVelocity == 4 then
        for i = 1, 2 do
            local prevDir = (Ball_Direction - Parry.PreviousVelocity[i].Unit).Unit
            local prevDot = Direction:Dot(prevDir)
            if (Dot - prevDot) < Dot_Threshold then return true end
        end
    end
    
    local backwardsCurveDetected = false
    local backwardsAngleThreshold = 60
    local horizDirection = Vector3.new(playerPos.X - ballPos.X, 0, playerPos.Z - ballPos.Z)
    if horizDirection.Magnitude > 0 then
        horizDirection = horizDirection.Unit
    end
    local awayFromPlayer = -horizDirection
    local horizBallDir = Vector3.new(Ball_Direction.X, 0, Ball_Direction.Z)
    if horizBallDir.Magnitude > 0 then
        horizBallDir = horizBallDir.Unit
        local backwardsAngle = math.deg(math.acos(math.clamp(awayFromPlayer:Dot(horizBallDir), -1, 1)))
        if backwardsAngle < backwardsAngleThreshold then
            backwardsCurveDetected = true
        end
    end
    
    return (Dot < Dot_Threshold) or backwardsCurveDetected
end

local function GetClosest_Player()
    local Max_Distance = math.huge
    local Found_Entity = nil
    local EntityDistance = nil
    
    for _, Entity in pairs(Services.Workspace.Alive:GetChildren()) do
        if tostring(Entity) ~= tostring(Player.LocalPlayer) then
            if Entity.PrimaryPart then
                local Distance = Player.LocalPlayer:DistanceFromCharacter(Entity.PrimaryPart.Position)
                if Distance < Max_Distance then
                    EntityDistance = Distance
                    Found_Entity = Entity
                end
            end
        end
    end
    
    return Found_Entity, EntityDistance
end

local function MainConnection()
    if Parry.AutoParryEnabled then
        local BallsList = Get_Balls()
        for _, Ball in pairs(BallsList) do
            if not Ball then return end
            
            local Zoomies = Ball:FindFirstChild("zoomies")
            if not Zoomies then return end
            
            Ball:GetAttributeChangedSignal("target"):Once(function()
                Parry.Parried = false
            end)
            
            if Parry.Parried then return end
            
            local Ball_Target = Ball:GetAttribute("target")
            local Velocity = Zoomies.VectorVelocity
            local Distance = (Player.LocalPlayer.Character.PrimaryPart.Position - Ball.Position).Magnitude - 5
            local Ping = Services.ServerStatsItem["Data Ping"]:GetValue() / 10
            local Ping_Threshold = math.clamp(Ping / 10, 5, 17)
            local Speed = Velocity.Magnitude * 1.5
            local cappedSpeedDiff = math.min(math.max(Speed - 9.5, 0), 650)
            local speed_divisor_base = 2.4 + cappedSpeedDiff * 0.002
            local speed_divisor = speed_divisor_base * Parry.SpeedDivisorMultiplier
            local Parry_Accuracy = Ping_Threshold + math.max(Speed / speed_divisor, 9.5) + (Distance / 75)
            local Curved = IsBall_Curved(Ball)
            
            if Ball:FindFirstChild("AeroDynamicSlashVFX") then
                Services.Debris:AddItem(Ball.AeroDynamicSlashVFX, 0)
                Parry.TornadoTime = tick()
            end
            
            if Runtime:FindFirstChild("Tornado") then
                if (tick() - Parry.TornadoTime) < (Runtime.Tornado:GetAttribute("TornadoTime") or 1) + 0.314159 then
                    return
                end
            end
            
            if Ball:FindFirstChild("ComboCounter") then return end
            
            local Singularity_Cape = Player.LocalPlayer.Character.PrimaryPart:FindFirstChild("SingularityCape")
            if Singularity_Cape then return end
            
            if Ball_Target == tostring(Player.LocalPlayer) and Distance <= Parry_Accuracy and not Curved then
                local Parry_Time = os.clock()
                local Time_View = Parry_Time - Parry.LastParry
                
                if Time_View > 0.1 and Parry.AutoParryAnimationFix then
                    PlayParry_Animation()
                end
                
                FireParry()
                Parry.LastParry = Parry_Time
                Parry.Parried = true
            end
            
            local Last_Parrys = tick()
            repeat
                Services.RunService.PreSimulation:Wait()
            until (os.clock() - Last_Parrys) >= 1 or not Parry.Parried
            
            Parry.Parried = false
        end
    end

    if Parry.AutoSpamParryEnabled then
        local BallsList = Get_Balls()
        for _, Ball in pairs(BallsList) do
            if not Ball or not Ball:FindFirstChild("zoomies") then 
                Parry.AutoSpamParrySpamming = false 
                return 
            end

            local Closest_Entity = GetClosest_Player()
            local Root = Player.LocalPlayer.Character and Player.LocalPlayer.Character.PrimaryPart
            
            if not Root then 
                Parry.AutoSpamParrySpamming = false 
                return
            end
            
            if not Closest_Entity or not Closest_Entity.PrimaryPart then 
                Parry.AutoSpamParrySpamming = false 
                return 
            end
            
            local Ping = Services.ServerStatsItem["Data Ping"]:GetValue()
            local PingFactor = Ping / 500
            local BallSpeed = Ball.AssemblyLinearVelocity.Magnitude
            
            local TargetCheck = 30.3
            if Ping <= 0 or Ping >= 130 then
                if Ping <= 131 or Ping >= 160 then
                    if Ping <= 161 or Ping >= 225 then
                        if Ping > 226 and Ping < 500 then
                            TargetCheck = math.clamp(math.floor(math.max(BallSpeed / 4 + PingFactor, 32.5)), 32.5, 80)
                        end
                    else
                        TargetCheck = math.clamp(math.floor(math.max(BallSpeed / 4.25 + PingFactor, 29.5)), 29.5, 70)
                    end
                else
                    TargetCheck = math.clamp(math.floor(math.max(BallSpeed / 4.65 + PingFactor, 27.25)), 27.25, 70)
                end
            else
                TargetCheck = math.clamp(math.floor(math.max(BallSpeed / 5 + PingFactor, 26)), 26, 70)
            end
            
            local RootPos = Root.Position
            local BallPos = Ball.Position
            local TargetPos = Closest_Entity.PrimaryPart.Position
            
            local DistToBall = (RootPos - BallPos).Magnitude
            local DistToTarget = (RootPos - TargetPos).Magnitude
            
            if DistToBall <= TargetCheck * 1.5 and DistToTarget <= TargetCheck then
                Parry.AutoSpamParrySpamming = true
            else
                Parry.AutoSpamParrySpamming = false
            end
        end
    else
        Parry.AutoSpamParrySpamming = false
    end
end

Balls.ChildRemoved:Connect(function(Child)
    Parry.Parries = 0
    Parry.Parried = false
    Parry.SpamAnimationParries = 0
    Parry.AutoSpamParrySpamming = false
end)

local function MakeDraggable(Recv, update, speed)
    local dragToggle = nil
    local dragStart = nil
    local startPos = nil

    local function updateInput(input)
        local delta = input.Position - dragStart
        local position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        Services.TweenService:Create(update, TweenInfo.new(speed), {Position = position}):Play()
    end

    Recv.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then 
            dragToggle = true
            dragStart = input.Position
            startPos = update.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragToggle = false
                end
            end)
        end
    end)

    Services.UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if dragToggle then
                updateInput(input)
            end
        end
    end)
end

function Visuals.VisualiserService:Enabled(value)
    if value then
        for _, VisualPart in pairs(Visuals.VisualParts) do
            VisualPart.Transparency = 0
        end
    else
        for _, VisualPart in pairs(Visuals.VisualParts) do
            VisualPart.Transparency = 1
        end
    end
end

function Visuals.VisualiserService:SetColor(color)
    for _, Part in pairs(Visuals.VisualParts) do
        Part.Color = color
    end
end

function Visuals.VisualiserService:Update(ball, position, size)
    if not ball:FindFirstChild("VisualPart") then
        local NewPart = Instance.new("Part")
        NewPart.Name = "VisualPart"
        NewPart.Anchored = true
        NewPart.CanCollide = false
        NewPart.CastShadow = false
        NewPart.Shape = Enum.PartType.Ball
        NewPart.Transparency = Visuals.VisualisersEnabled and 0 or 1
        NewPart.Material = Enum.Material.ForceField
        NewPart.Color = Color3.fromRGB(255, 255, 255)
        NewPart.Parent = ball
        Visuals.VisualParts[ball] = NewPart
    end

    Visuals.VisualParts[ball].Position = position
    Visuals.VisualParts[ball].Size = Vector3.new(size, size, size)
end

function Visuals.HitEffectService:Emit(ball, position)
    if not Visuals.HitEffectService.BallEffects[ball] then
        local HitEffect = Instance.new("Attachment")
        local Arcs = Instance.new("ParticleEmitter")

        HitEffect.Name = "HitEffect"
        HitEffect.Parent = ball
        Arcs.Enabled = false
        Arcs.RotSpeed = NumberRange.new(250)
        Arcs.VelocitySpread = -360
        Arcs.Texture = "rbxassetid://8084911316"
        Arcs.ZOffset = 1
        Arcs.LightEmission = 1
        Arcs.Rotation = NumberRange.new(-360, 360)
        Arcs.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1, 0),
            NumberSequenceKeypoint.new(0.25, 0, 0),
            NumberSequenceKeypoint.new(0.75, 0, 0),
            NumberSequenceKeypoint.new(1, 1, 0)
        })
        Arcs.Name = "Arcs"
        Arcs.Lifetime = NumberRange.new(1)
        Arcs.Speed = NumberRange.new(math.random(1, 3))
        Arcs.SpreadAngle = Vector2.new(-360, 360)
        Arcs.Rate = 0
        Arcs.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
        Arcs.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 10, 0),
            NumberSequenceKeypoint.new(1, 10, 0)
        })

        Arcs.Parent = HitEffect
        Visuals.HitEffectService.BallEffects[ball] = HitEffect
    end

    local BallEffect = Visuals.HitEffectService.BallEffects[ball].Arcs
    BallEffect:Emit(1)
end

function ManualSpamParryUIService:Visible(value)
    UI.ScreenGui.Enabled = value
end

function ManualSpamParryUIService:SetColor(value)
    if value then
        UI.SpamButton.BackgroundColor3 = Color3.new(0, 1, 0)
        UI.SpamButton.UIStroke.Color = Color3.new(0, 1, 0)
        UI.SpamButton.Text = "ACTIVE"
    else
        UI.SpamButton.BackgroundColor3 = Color3.new(1, 0, 0)
        UI.SpamButton.UIStroke.Color = Color3.new(1, 0, 0)
        UI.SpamButton.Text = "SPAM"
    end
end

do
    UI.Window:AddLabel('General')

    local CombatTab = UI.Window:AddTab({
        Name = "Combat",
        Icon = "swords"
    })

    local VisualTab = UI.Window:AddTab({
        Name = "Visuals",
        Icon = "box"
    })

    local AutoParrySection = CombatTab:AddSection({
        Name = "Auto Parry",
        Position = "left"
    })

    local AutoSpamParrySection = CombatTab:AddSection({
        Name = "Auto Spam Parry [BETA]",
        Position = "right"
    })

    local ManualSpamParrySection = CombatTab:AddSection({
        Name = "Manual Spam Parry",
        Position = "right"
    })

    do
        AutoParrySection:AddToggle({
            Name = 'Enabled',
            Default = false,
            Callback = function(value)
                Parry.AutoParryEnabled = value
            end,
        })

        AutoParrySection:AddSlider({
            Name = "Accuracy",
            Min = 0,
            Max = 100,
            Round = 1,
            Default = 100,
            Type = "%",
            Callback = function(value)
                Parry.SpeedDivisorMultiplier = 0.7 + (value - 0.8) * (0.35 / 99)
            end,
        })

        AutoParrySection:AddToggle({
            Name = 'Animation Fix',
            Default = false,
            Callback = function(value)
                Parry.AutoParryAnimationFix = value
            end,
        })
    end
    
    do
        AutoSpamParrySection:AddToggle({
            Name = 'Enabled',
            Default = false,
            Callback = function(value)
                Parry.AutoSpamParryEnabled = value
            end,
        })
        
        AutoSpamParrySection:AddToggle({
            Name = 'Animation Fix',
            Default = false,
            Callback = function(value)
                Parry.AutoSpamParryAnimationFix = value
            end,
        })
    end 
    
    do
        UI.ManualSpamParryToggle = ManualSpamParrySection:AddToggle({
            Name = 'Spam',
            Default = false,
            Callback = function(value)
                Parry.ManualSpamParrySpamming = value
                ManualSpamParryUIService:SetColor(value)
            end,
        })

        ManualSpamParrySection:AddToggle({
            Name = 'UI',
            Default = false,
            Callback = function(value)
                Parry.ManualSpamParryUI = value
                ManualSpamParryUIService:Visible(value)
            end,
        })

        ManualSpamParrySection:AddKeybind({
            Name = "Keybind",
            Default = "E",
            Callback = function(key)
                Parry.ManualSpamParryKeybind = key
            end,
        })

        ManualSpamParrySection:AddToggle({
            Name = 'Animation Fix',
            Default = false,
            Callback = function(value)
                Parry.ManualSpamParryAnimationFix = value
            end,
        })
    end

    local VisualiserSection = VisualTab:AddSection({
        Name = "Visualiser",
        Position = "left"
    })

    VisualiserSection:AddToggle({
        Name = 'Enabled',
        Default = false,
        Callback = function(value)
            Visuals.VisualisersEnabled = value
            Visuals.VisualiserService:Enabled(value)
        end,
    })

    local EffectSection = VisualTab:AddSection({
        Name = "Effects",
        Position = "right"
    })

    EffectSection:AddToggle({
        Name = 'Hit Effect',
        Default = false,
        Callback = function(value)
            Visuals.HitEffectEnabled = value
        end,
    })

    UI.Window:AddLabel('Miscellaneous')

    local ExclusiveTab = UI.Window:AddTab({
        Name = "Exclusive",
        Icon = "layers"
    })

    local AnimationDisablerSection = ExclusiveTab:AddSection({
        Name = "Animation Disabler",
        Position = "left"
    })

    AnimationDisablerSection:AddToggle({
        Name = 'Disable Parry Animation',
        Default = false,
        Callback = function(value)
            for _, v in pairs(Services.SwordAPI.Collection:GetDescendants()) do
                if v.Name == "SuccessParry" then
                    v:SetAttribute("SuccessParry", not value)
                end
            end
        end,
    })

    AnimationDisablerSection:AddToggle({
        Name = 'Disable Grab Animation',
        Default = false,
        Callback = function(value)
            for _, v in pairs(Services.SwordAPI.Collection:GetDescendants()) do
                if v.Name == "GrabParry" then
                    v:SetAttribute("GrabParry", not value)
                end
            end
        end,
    })

    local ImmortalitySection = ExclusiveTab:AddSection({
        Name = "Immortality",
        Position = "right"
    })

    ImmortalitySection:AddToggle({
        Name = 'Enabled',
        Default = false,
        Callback = function(value)
            Immortality.Enabled = value
        end,
    })

    ImmortalitySection:AddToggle({
        Name = 'Rotate',
        Default = false,
        Callback = function(value)
            Immortality.Rotate = value
        end,
    })

    ImmortalitySection:AddSlider({
        Name = "Radius",
        Min = 0,
        Max = 100,
        Round = 1,
        Default = 40,
        Type = "studs",
        Callback = function(value)
            Immortality.Radius = value
        end,
    })

    ImmortalitySection:AddSlider({
        Name = "Height",
        Min = 0,
        Max = 100,
        Round = 1,
        Default = 100,
        Type = "studs",
        Callback = function(value)
            Immortality.Height = value
        end,
    })

    local OpitimizationSection = ExclusiveTab:AddSection({
        Name = "Optimization",
        Position = "left"
    })

    OpitimizationSection:AddToggle({
        Name = 'No Render',
        Default = false,
        Callback = function(value)
            Optimization.NoRenderEnabled = value
        end,
    })

    local SettingsTab = UI.Window:AddTab({
        Name = "Settings",
        Icon = "settings"
    })

    local SpammingSection = SettingsTab:AddSection({
        Name = "Spamming",
        Position = "left"
    })

    SpammingSection:AddDropdown({
        Name = "Mode",
        Default = "Advanced",
        Values = {"Default", "Advanced"},
        Callback = function(value)
            Parry.SpammingMode = value
        end,
    })

    SpammingSection:AddDivider({
        Color = Color3.fromRGB(50, 50, 50),
        Height = 2
    })

    SpammingSection:AddSlider({
        Name = "Max Speed",
        Min = 50,
        Max = 120,
        Round = 1,
        Default = Parry.SpammingMaxSpeed,
        Type = "parries",
        Callback = function(value)
            Parry.SpammingMaxSpeed = value
        end,
    })

    SpammingSection:AddToggle({
        Name = 'Bypass Delay',
        Default = false,
        Callback = function(value)
            Parry.AdvancedSpammingDelayBypass = value
        end,
    })

    SpammingSection:AddToggle({
        Name = 'Reset After Parry',
        Default = false,
        Callback = function(value)
            Parry.SpamParryCooldownBypass = value
        end,
    })

    local ParrySystemSection = SettingsTab:AddSection({
        Name = "Parry System",
        Position = "right"
    })

    ParrySystemSection:AddDropdown({
        Name = "Method",
        Default = Parry.ParryMethod,
        Values = {"Legit", "Blatant"},
        Callback = function(value)
            Parry.ParryMethod = value
        end,
    })

    ParrySystemSection:AddDivider({
        Color = Color3.fromRGB(50, 50, 50),
        Height = 2
    })

    ParrySystemSection:AddToggle({
        Name = 'Hash Check',
        Default = Parry.ParryHashCheck,
        Callback = function(value)
            Parry.ParryHashCheck = value
        end,
    })
end

do
    UI.ScreenGui = Instance.new("ScreenGui")
    UI.ScreenGui.Name = "ScreenGui"
    UI.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    UI.ScreenGui.ResetOnSpawn = false
    UI.ScreenGui.Enabled = false
    UI.ScreenGui.Parent = Services.Players.LocalPlayer:WaitForChild("PlayerGui")

    UI.Handler = Instance.new("CanvasGroup")
    UI.Handler.Name = "Handler"
    UI.Handler.Position = UDim2.new(0.5, 0, 0.5, 0)
    UI.Handler.Size = UDim2.new(0, 200, 0, 125)
    UI.Handler.BackgroundColor3 = Color3.new(1, 1, 1)
    UI.Handler.BackgroundTransparency = 1
    UI.Handler.BorderSizePixel = 0
    UI.Handler.BorderColor3 = Color3.new(0, 0, 0)
    UI.Handler.AnchorPoint = Vector2.new(0.5, 0.5)
    UI.Handler.Transparency = 1
    UI.Handler.Parent = UI.ScreenGui

    local HeadFrame = Instance.new("Frame")
    HeadFrame.Name = "HeadFrame"
    HeadFrame.Position = UDim2.new(0.5, 0, 0.1, 0)
    HeadFrame.Size = UDim2.new(1, 0, 1, -100)
    HeadFrame.BackgroundColor3 = Color3.new(0.0470588, 0.0470588, 0.0470588)
    HeadFrame.BackgroundTransparency = 0.1
    HeadFrame.BorderSizePixel = 0
    HeadFrame.BorderColor3 = Color3.new(0, 0, 0)
    HeadFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    HeadFrame.Transparency = 0.1
    HeadFrame.Parent = UI.Handler

    local HeadLabel = Instance.new("TextLabel")
    HeadLabel.Name = "HeadLabel"
    HeadLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
    HeadLabel.Size = UDim2.new(1, -10, 1, -10)
    HeadLabel.BackgroundColor3 = Color3.new(1, 1, 1)
    HeadLabel.BackgroundTransparency = 1
    HeadLabel.BorderSizePixel = 0
    HeadLabel.BorderColor3 = Color3.new(0, 0, 0)
    HeadLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    HeadLabel.Text = "BB Achaotic"
    HeadLabel.TextColor3 = Color3.new(0.819608, 0.819608, 0.819608)
    HeadLabel.TextSize = 14
    HeadLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    HeadLabel.TextScaled = true
    HeadLabel.TextWrapped = true
    HeadLabel.TextXAlignment = Enum.TextXAlignment.Left
    HeadLabel.Parent = HeadFrame

    local UICorner = Instance.new("UICorner")
    UICorner.Name = "UICorner"
    UICorner.CornerRadius = UDim.new(0, 4)
    UICorner.Parent = UI.Handler

    local ButtonFrame = Instance.new("Frame")
    ButtonFrame.Name = "ButtonFrame"
    ButtonFrame.Position = UDim2.new(0.5, 0, 0.6, 0)
    ButtonFrame.Size = UDim2.new(1, 0, 1, -25)
    ButtonFrame.BackgroundColor3 = Color3.new(0.0784314, 0.0784314, 0.0784314)
    ButtonFrame.BackgroundTransparency = 0.1
    ButtonFrame.BorderSizePixel = 0
    ButtonFrame.BorderColor3 = Color3.new(0, 0, 0)
    ButtonFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    ButtonFrame.Transparency = 0.1
    ButtonFrame.Parent = UI.Handler

    UI.SpamButton = Instance.new("TextButton")
    UI.SpamButton.Name = "SpamButton"
    UI.SpamButton.Position = UDim2.new(0.5, 0, 0.5, 0)
    UI.SpamButton.Size = UDim2.new(1, -15, 1, -15)
    UI.SpamButton.BackgroundColor3 = Color3.new(1, 0, 0)
    UI.SpamButton.BackgroundTransparency = 0.75
    UI.SpamButton.BorderSizePixel = 0
    UI.SpamButton.BorderColor3 = Color3.new(0, 0, 0)
    UI.SpamButton.AnchorPoint = Vector2.new(0.5, 0.5)
    UI.SpamButton.TextTransparency = 0.25
    UI.SpamButton.Text = "SPAM"
    UI.SpamButton.TextColor3 = Color3.new(1, 1, 1)
    UI.SpamButton.TextSize = 25
    UI.SpamButton.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    UI.SpamButton.Parent = ButtonFrame

    local UICorner2 = Instance.new("UICorner")
    UICorner2.Name = "UICorner"
    UICorner2.CornerRadius = UDim.new(0, 2)
    UICorner2.Parent = UI.SpamButton

    local UIStroke = Instance.new("UIStroke")
    UIStroke.Name = "UIStroke"
    UIStroke.Color = Color3.new(1, 0, 0)
    UIStroke.Transparency = 0.5
    UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    UIStroke.Parent = UI.SpamButton

    local UIStroke2 = Instance.new("UIStroke")
    UIStroke2.Name = "UIStroke"
    UIStroke2.Color = Color3.new(0, 0.0980392, 0.133333)
    UIStroke2.Transparency = 0.850
    UIStroke2.Parent = UI.Handler

    local function ToggleSpam()
        Parry.ManualSpamParrySpamming = not Parry.ManualSpamParrySpamming
        UI.ManualSpamParryToggle:SetValue(Parry.ManualSpamParrySpamming)
        ManualSpamParryUIService:SetColor(Parry.ManualSpamParrySpamming)
    end
    
    UI.SpamButton.MouseButton1Click:Connect(ToggleSpam)
    MakeDraggable(UI.Handler, UI.Handler, 0.2)
end

Services.UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if not input.UserInputType == Enum.UserInputType.Keyboard then return end
    if input.KeyCode == Parry.ManualSpamParryKeybind then
        Parry.ManualSpamParrySpamming = not Parry.ManualSpamParrySpamming
        UI.ManualSpamParryToggle:SetValue(Parry.ManualSpamParrySpamming)
    end
end)

do
    local function RandomNumberRange(a)
        return math.random(-a * 90000009292929399949949496000, a * -1e9) / 5e8
    end

    local ForceSpeed = 3000

    local DesyncTypes = {}
    local CurrentRotation = 0

    Services.RunService.Stepped:Connect(function()
        if Immortality.Enabled and Player.LocalPlayer.Character and Player.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            pcall(function()
                Player.LocalPlayer.Character.HumanoidRootPart:SetNetworkOwner(Player.LocalPlayer)
            end)
        end
    end)

    Services.RunService.Heartbeat:Connect(function()
        if Immortality.Enabled and Player.LocalPlayer.Character and Player.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            CurrentRotation = Immortality.Rotate and (CurrentRotation + 15) % 360 or 0
            DesyncTypes[1] = Player.LocalPlayer.Character.HumanoidRootPart.CFrame
            DesyncTypes[2] = Player.LocalPlayer.Character.HumanoidRootPart.AssemblyLinearVelocity

            local SpoofThis = Player.LocalPlayer.Character.HumanoidRootPart.CFrame * CFrame.Angles(0, math.rad(CurrentRotation), 0) + Vector3.new(0, Immortality.Height, 0)
            local horizontalOscillation = math.sin(tick() * 30) * Immortality.Radius
            local verticalOscillation = math.cos(tick() * 60) * Immortality.Height
            SpoofThis = SpoofThis * CFrame.new(horizontalOscillation, verticalOscillation, 0) * CFrame.Angles(
                math.rad(RandomNumberRange(ForceSpeed)),
                math.rad(RandomNumberRange(ForceSpeed)),
                0
            )

            Player.LocalPlayer.Character.HumanoidRootPart.CFrame = SpoofThis
            Player.LocalPlayer.Character.HumanoidRootPart.AssemblyLinearVelocity = DesyncTypes[2] + Vector3.new(
                math.cos(tick() * 8) * ForceSpeed,
                math.cos(tick() * 8) * ForceSpeed,
                0
            )

            Services.RunService.RenderStepped:Wait()

            Player.LocalPlayer.Character.HumanoidRootPart.CFrame = DesyncTypes[1]
            Player.LocalPlayer.Character.HumanoidRootPart.AssemblyLinearVelocity = DesyncTypes[2]
        end
    end)

    local oldIndex
    oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
        if Immortality.Enabled and not checkcaller() then
            if key == "CFrame" and Player.LocalPlayer.Character and Player.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                if self == Player.LocalPlayer.Character.HumanoidRootPart then
                    return DesyncTypes[1] or CFrame.new()
                elseif self == Player.LocalPlayer.Character:FindFirstChild("Head") then
                    return DesyncTypes[1] and DesyncTypes[1] + Vector3.new(0, Player.LocalPlayer.Character.HumanoidRootPart.Size / 2 + 0.5, 0) or CFrame.new()
                end
            end
        end
        return oldIndex(self, key)
    end))
end

local SpamCooldownBypass = false

local function RequestAdvancedParry()
    if not Parry.SpammingMode == "Advanced" then return end
    if Parry.AutoSpamParrySpamming or Parry.ManualSpamParrySpamming then
        local currentTime = tick()
        if currentTime - Parry.lastParryTime >= (1 / Parry.SpammingMaxSpeed) or SpamCooldownBypass or Parry.AdvancedSpammingDelayBypass then
            FireParry()
            Parry.lastParryTime = currentTime
            SpamCooldownBypass = false
            if (Parry.AutoSpamParryAnimationFix and Parry.AutoSpamParrySpamming) or (Parry.ManualSpamParryAnimationFix and Parry.ManualSpamParrySpamming) then
                SpamParry_Animation()
            end
        end
    end
end

Runtime.ChildAdded:Connect(function(Value)
    if not Optimization.NoRenderEnabled then return end
    Services.Debris:AddItem(Value, 0)
end)

local lastmainconnection = tick()
local connections = {}

local function SimulationRepeat(deltaTime)
    if not Script.Running then
        for _, connection in pairs(connections) do
            connection:Disconnect()
        end
        return
    end
    
    Parry.AnimationSpammingMode = Parry.SpamAnimationParries > 1
    
    local currentTime = tick()
    if currentTime - lastmainconnection >= 0.0075 then
        lastmainconnection = currentTime
        MainConnection()
    end
    
    if Visuals.VisualisersEnabled then
        local BallsList = Get_Balls()
        for _, Ball in pairs(BallsList) do
            if Ball then
                local Velocity = Ball.AssemblyLinearVelocity
                local Speed = Velocity.Magnitude
                local Size = math.clamp(Speed / 5, 3.5, 500)
                Visuals.VisualiserService:Update(Ball, Ball.Position, Size)
            end
        end
    end
    
    if type(deltaTime) == "number" then
        Player.CurrentPlayerFPS = 1 / deltaTime
    end
end

Services.ReplicatedStorage.Remotes.ParrySuccess.OnClientEvent:Connect(function()
    if Parry.SpamParryCooldownBypass then
        SpamCooldownBypass = true
    end
    
    if Parry.SpamAnimationParries < 5 then
        Parry.SpamAnimationParries += 1
        task.delay(0.15, function()
            if Parry.SpamAnimationParries > 0 then
                Parry.SpamAnimationParries -= 1
            end
        end)
    end
    
    bypasscd = true
    local humanoid = GetHumanoid()
    if humanoid and (Parry.AutoSpamParryAnimationFix and Parry.AutoSpamParrySpamming) or (Parry.ManualSpamParryAnimationFix and Parry.ManualSpamParrySpamming) or (Parry.AutoParryAnimationFix and Parry.AutoParryEnabled) then
        for _, track in pairs(humanoid.Animator:GetPlayingAnimationTracks()) do
            if track.Name == "GrabParry" or track.Name == "Grab" then
                if not Parry.AnimationSpammingMode then
                    track.TimePosition = 0
                end
                StopAnimation(track)
            end
        end
    end
    
    if Visuals.HitEffectEnabled then
        for _, Ball in pairs(Get_Balls()) do
            Visuals.HitEffectService:Emit(Ball, Ball.Position)
        end
    end
end)

local function DefaultParryRequest()
    if Parry.SpammingMode == "Default" then
        if Parry.AutoSpamParrySpamming or Parry.ManualSpamParrySpamming then
            FireParry()
            if (Parry.AutoSpamParryAnimationFix and Parry.AutoSpamParrySpamming) or (Parry.ManualSpamParryAnimationFix and Parry.ManualSpamParrySpamming) then
                SpamParry_Animation()
            end
        end
    end
end

Services.RunService.PreSimulation:Connect(SimulationRepeat) 

Services.RunService:BindToRenderStep("Critical120Hz", Enum.RenderPriority.First.Value, DefaultParryRequest)
Services.RunService.Stepped:Connect(SimulationRepeat)

Services.ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent:Connect(RequestAdvancedParry)
Services.ReplicatedStorage.Remotes.ParryAttemptAll.OnClientEvent:Connect(RequestAdvancedParry)
Services.RunService.PreRender:Connect(RequestAdvancedParry)

coroutine.create(function()
    for _ = 1, math.huge do
        RequestAdvancedParry()
        task.wait()
    end
end)

Services.NZNotification.new('BB Achaotic', 'Loaded Blade Ball Successfully.', 10)
