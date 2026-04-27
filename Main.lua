repeat task.wait() until game:IsLoaded()
pcall(function() setfpscap(999) end)
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService   = game:GetService("TweenService")
local SoundService   = game:GetService("SoundService")
local Lighting       = game:GetService("Lighting")
local HttpService    = game:GetService("HttpService")
local LocalPlayer    = Players.LocalPlayer
local VisualSetters = {}
local mobileButtonContainer
local apMain
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local NORMAL_SPEED = 60
local CARRY_SPEED  = 30
local LAGGER_SPEED = 15
local FOV_VALUE    = 70
local UI_SCALE     = isMobile and 0.65 or 1.0
local function getMobileOptimized(pcValue, mobileValue)
    return isMobile and mobileValue or pcValue
end
local lastNoclipUpdate = 0
RunService.Stepped:Connect(function()
    local now = tick()
    if now - lastNoclipUpdate < 0.1 then return end
    lastNoclipUpdate = now
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            for _, part in ipairs(p.Character:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end
end)
local speedToggled       = false
local fastestStealEnabled = false
local laggerToggled      = false
local autoBatToggled     = false
local hittingCooldown    = false
local fullAutoPlayEnabled = false
local fullAutoPlayConn = nil
local fullAutoPlayLeftEnabled = false
local fullAutoPlayRightEnabled = false
local fullAutoPlayLeftConn = nil
local fullAutoPlayRightConn = nil
local fullAutoLeftSetter = nil
local fullAutoRightSetter = nil
local brainrotReturnLeftEnabled  = false
local brainrotReturnRightEnabled = false
local brainrotReturnCooldown     = false
local lastKnownHealth            = 100
local G_myPlotSide               = nil
local G_myPlotName               = nil
local G_tpAutoEnabled            = false
local G_autoPlayAfterTP          = false
local G_countdownActive          = false
local ultraModeEnabled           = false
local autoSwingEnabled           = false
local noCamCollisionEnabled      = false
local noCamCollisionConn         = nil
local noCamParts                 = {}
local _antiLagDescConn           = nil
local lastBatSwing               = 0
local BAT_SWING_COOLDOWN         = 0.12
local SPAWN_DETECT_RADIUS        = 40
local COUNTDOWN_TARGET           = 4.9
local SPAWN_Z_RIGHT_THRESHOLD    = 60
local SPAWN_LEFT                 = Vector3.new(-466.429901, 0, 113.553757)
local SPAWN_RIGHT                = Vector3.new(-466.42984,  0, 6.55357218)
local AP_Offsets  = {{x=0,y=0,z=0},{x=0,y=0,z=0},{x=0,y=0,z=0},{x=0,y=0,z=0}}
local APR_Offsets = {{x=0,y=0,z=0},{x=0,y=0,z=0},{x=0,y=0,z=0},{x=0,y=0,z=0}}
local BR_L2 = Vector3.new(-475.5, -3.75, 100.5)
local BR_L3 = Vector3.new(-486.5, -3.75, 100.5)
local BR_R2 = Vector3.new(-475.50, -3.95, 17.55)
local BR_R3 = Vector3.new(-486.76, -3.95, 17.55)
local Keybinds = {
    AutoBat        = Enum.KeyCode.T,
    SpeedToggle    = Enum.KeyCode.Q,
    LaggerToggle   = Enum.KeyCode.R,
    InfiniteJump   = Enum.KeyCode.M,
    UIToggle       = Enum.KeyCode.U,
    DropBrainrot   = Enum.KeyCode.X,
    FloatToggle    = Enum.KeyCode.J,
    FullAutoLeft   = Enum.KeyCode.G,
    FullAutoRight  = Enum.KeyCode.H,
    TPDown         = Enum.KeyCode.F,
}
local isStealing     = false
local stealStartTime = nil
local StealData      = {}
local lastStealTick  = 0
local plotCache      = {}
local plotCacheTime  = {}
local cachedPrompts  = {}
local promptCacheTime= 0
local Settings = {
    AutoStealEnabled = false,
    StealRadius      = 20,
    StealDuration    = 0.1,
}
local Values = {
    STEAL_RADIUS         = 20,
    STEAL_DURATION       = 0.1,
    STEAL_COOLDOWN       = 0.1,
    PLOT_CACHE_DURATION  = 2,
    PROMPT_CACHE_REFRESH = 0.15,
    DEFAULT_GRAVITY      = 196.2,
    GalaxyGravityPercent = 70,
    HOP_POWER            = 35,
    HOP_COOLDOWN         = 0.08,
}
local function detectMyPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil, nil end
    local myName = LocalPlayer.DisplayName or LocalPlayer.Name
    for _, plot in ipairs(plots:GetChildren()) do
        local ok, result = pcall(function()
            local sign = plot:FindFirstChild("PlotSign"); if not sign then return nil end
            local sg = sign:FindFirstChild("SurfaceGui"); if not sg then return nil end
            local fr = sg:FindFirstChild("Frame"); if not fr then return nil end
            local tl = fr:FindFirstChild("TextLabel"); if not tl then return nil end
            if tl.Text:find(myName, 1, true) then
                local spawnObj = plot:FindFirstChild("Spawn")
                if spawnObj then
                    local z = spawnObj.CFrame.Position.Z
                    return z < SPAWN_Z_RIGHT_THRESHOLD and "left" or "right"
                end
            end
            return nil
        end)
        if ok and result then return result, plot.Name end
    end
    return nil, nil
end

local function refreshMyPlotSide()
    local side, plotName = detectMyPlot()
    G_myPlotSide = side; G_myPlotName = plotName
    return side
end

task.spawn(function()
    while true do
        task.wait(2)
        if G_tpAutoEnabled then refreshMyPlotSide() end
    end
end)

task.spawn(function()
    local plots = workspace:WaitForChild("Plots", 30); if not plots then return end
    local myName = LocalPlayer.DisplayName or LocalPlayer.Name
    local function watchPlot(plot)
        pcall(function()
            local tl = plot:WaitForChild("PlotSign",5):WaitForChild("SurfaceGui",5):WaitForChild("Frame",5):WaitForChild("TextLabel",5)
            if not tl then return end
            tl:GetPropertyChangedSignal("Text"):Connect(function() refreshMyPlotSide() end)
            if tl.Text:find(myName, 1, true) then refreshMyPlotSide() end
        end)
    end
    for _, plot in ipairs(plots:GetChildren()) do task.spawn(watchPlot, plot) end
    plots.ChildAdded:Connect(function(plot) task.spawn(watchPlot, plot) end)
end)
local function calculateFastestStealSpeed()
    local char = LocalPlayer.Character; if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return nil end
    
    local targetPos = nil
    if fullAutoPlayLeftEnabled then
        local pts = {FAP_L1, FAP_L2, FAP_L3, FAP_L4, FAP_L5}
        local phase = FAP_LeftPhase
        if type(phase) ~= "number" or phase < 1 then phase = 1 end
        if phase > 5 then phase = 5 end
        targetPos = pts[phase]
    elseif fullAutoPlayRightEnabled then
        local pts = {FAP_R1, FAP_R2, FAP_R3, FAP_R4, FAP_R5}
        local phase = FAP_RightPhase
        if type(phase) ~= "number" or phase < 1 then phase = 1 end
        if phase > 5 then phase = 5 end
        targetPos = pts[phase]
    else
        return nil
    end
    
    if not targetPos then return end
    
    local dist = Vector3.new(
        targetPos.X - hrp.Position.X,
        0,
        targetPos.Z - hrp.Position.Z
    ).Magnitude
    
    if dist < 0.1 then return end
    local TARGET_TIME = 1.65
    local requiredSpeed = dist / TARGET_TIME
    
    -- clamp to reasonable range
    requiredSpeed = math.clamp(requiredSpeed, 1, 9999)
    
    return requiredSpeed
end

RunService.Heartbeat:Connect(function()
    if not fastestStealEnabled then return end
    if not (fullAutoPlayLeftEnabled or fullAutoPlayRightEnabled) then return end
    local char = LocalPlayer.Character; if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    local md = hum.MoveDirection; if md.Magnitude == 0 then return end
    local spd = calculateFastestStealSpeed()
    if spd then
        hrp.AssemblyLinearVelocity = Vector3.new(md.X * spd, hrp.AssemblyLinearVelocity.Y, md.Z * spd)
    end
end)

local function syncStealSettings()
    Values.STEAL_RADIUS   = Settings.StealRadius
    Values.STEAL_DURATION = Settings.StealDuration
    Settings.StealRadius  = Values.STEAL_RADIUS
    Settings.StealDuration= Values.STEAL_DURATION
end
local STEAL_COOLDOWN       = Values.STEAL_COOLDOWN
local PLOT_CACHE_DURATION  = Values.PLOT_CACHE_DURATION
local PROMPT_CACHE_REFRESH = Values.PROMPT_CACHE_REFRESH
local Enabled = {
    AntiRagdoll  = false,
    AutoSteal    = false,
    InfiniteJump = false,
    ShinyGraphics= false,
    Optimizer    = false,
    Unwalk       = false,
    RemoveAccessories = false,
}
local Connections          = {}
local originalTransparency = {}
local savedAnimations      = {}
local xrayEnabled = false
local h, hrp, speedLbl
local progressConnection = nil
local gui, main
local speedSwBg, speedSwCircle
local laggerSwBg, laggerSwCircle
local batSwBg, batSwCircle
local waitingForKey = nil
local function getHRP()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end
local function isMyPlotByName(plotName)
    local currentTime = tick()
    if plotCache[plotName] and (currentTime - (plotCacheTime[plotName] or 0)) < PLOT_CACHE_DURATION then
        return plotCache[plotName]
    end
    local plots = workspace:FindFirstChild("Plots")
    if not plots then plotCache[plotName]=false; plotCacheTime[plotName]=currentTime; return false end
    local plot = plots:FindFirstChild(plotName)
    if not plot then plotCache[plotName]=false; plotCacheTime[plotName]=currentTime; return false end
    local sign = plot:FindFirstChild("PlotSign")
    if sign then
        local yourBase = sign:FindFirstChild("YourBase")
        if yourBase and yourBase:IsA("BillboardGui") then
            local result = yourBase.Enabled == true
            plotCache[plotName]=result; plotCacheTime[plotName]=currentTime
            return result
        end
    end
    plotCache[plotName]=false; plotCacheTime[plotName]=currentTime
    return false
end
local function findNearestPrompt()
    local char = LocalPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local currentTime = tick()
    if currentTime - promptCacheTime < PROMPT_CACHE_REFRESH and #cachedPrompts > 0 then
        local nearestPrompt, nearestDist, nearestName = nil, math.huge, nil
        for _, data in ipairs(cachedPrompts) do
            if data.spawn then
                local dist = (data.spawn.Position - root.Position).Magnitude
                if dist <= Settings.StealRadius and dist < nearestDist then
                    nearestPrompt = data.prompt; nearestDist = dist; nearestName = data.name
                end
            end
        end
        if nearestPrompt then return nearestPrompt, nearestDist, nearestName end
    end
    cachedPrompts = {}; promptCacheTime = currentTime
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    local nearestPrompt, nearestDist, nearestName = nil, math.huge, nil
    for _, plot in ipairs(plots:GetChildren()) do
        if isMyPlotByName(plot.Name) then continue end
        local podiums = plot:FindFirstChild("AnimalPodiums")
        if not podiums then continue end
        for _, podium in ipairs(podiums:GetChildren()) do
            pcall(function()
                local base  = podium:FindFirstChild("Base")
                local spawn = base and base:FindFirstChild("Spawn")
                if spawn then
                    local dist = (spawn.Position - root.Position).Magnitude
                    local att = spawn:FindFirstChild("PromptAttachment")
                    if att then
                        for _, ch in ipairs(att:GetChildren()) do
if ch:IsA("ProximityPrompt") and ch.Enabled and tostring(ch.ActionText or ""):lower():find("steal") then
                                table.insert(cachedPrompts, {prompt=ch, spawn=spawn, name=podium.Name})
                                if dist <= Settings.StealRadius and dist < nearestDist then
                                    nearestPrompt=ch; nearestDist=dist; nearestName=podium.Name
                                end
                                break
                            end
                        end
                    end
                end
            end)
        end
    end
    return nearestPrompt, nearestDist, nearestName
end
local ProgressLabel, ProgressPercentLabel, ProgressBarFill, RadiusInput, DurationInput
local function ResetProgressBar()
    if ProgressLabel        then ProgressLabel.Text = "READY" end
    if ProgressPercentLabel then ProgressPercentLabel.Text = "" end
    if ProgressBarFill      then ProgressBarFill.Size = UDim2.new(0,0,1,0) end
end
local function executeSteal(prompt, name)
    local currentTime = tick()
    if currentTime - lastStealTick < STEAL_COOLDOWN then return end
    if isStealing then return end
    if not StealData[prompt] then
StealData[prompt] = {hold={}, trigger={}, ready=true, useFallback=true}
StealData[prompt].useFallback = true
    end
    local data = StealData[prompt]
    if not data.ready then return end
    data.ready=false; isStealing=true; stealStartTime=currentTime; lastStealTick=currentTime
    if ProgressLabel then ProgressLabel.Text = name or "STEALING..." end
    if progressConnection then progressConnection:Disconnect() end
    progressConnection = RunService.Heartbeat:Connect(function()
        if not isStealing then progressConnection:Disconnect(); return end
        local prog = math.clamp((tick()-stealStartTime)/Settings.StealDuration, 0, 1)
        if ProgressBarFill      then ProgressBarFill.Size = UDim2.new(prog,0,1,0) end
        if ProgressPercentLabel then ProgressPercentLabel.Text = math.floor(prog*100).."%" end
    end)
task.spawn(function()
        local ok = false
        if fireproximityprompt and prompt and prompt.Parent then
            pcall(function()
                fireproximityprompt(prompt)
                ok = true
            end)
        end
        if not ok and prompt and prompt.Parent then
            pcall(function()
                prompt.HoldDuration = 0
                prompt:InputHoldBegin()
                prompt:InputHoldEnd()
                ok = true
            end)
        end
        task.wait(0.15)
        if progressConnection then progressConnection:Disconnect() end
        ResetProgressBar()
        task.wait(0.05)
        data.ready=true; isStealing=false
    end)
end
local function startAutoSteal()
    if Connections.autoSteal then return end
local lastAutoStealCheck = 0
    Connections.autoSteal = RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - lastAutoStealCheck < 0.05 then return end
        lastAutoStealCheck = now
        if not Enabled.AutoSteal or isStealing then return end  
        local p,_,n = findNearestPrompt()
        if p then
            local char = LocalPlayer.Character
            local hrpLocal = char and char:FindFirstChild("HumanoidRootPart")
            if hrpLocal then
                hrpLocal.AssemblyLinearVelocity = Vector3.new(0, hrpLocal.AssemblyLinearVelocity.Y, 0)
            end
            executeSteal(p,n)
        end
    end)
end
local function stopAutoSteal()
    if Connections.autoSteal then Connections.autoSteal:Disconnect(); Connections.autoSteal=nil end
    isStealing=false; lastStealTick=0
    plotCache={}; plotCacheTime={}; cachedPrompts={}
    ResetProgressBar()
end
local function startAntiRagdoll()
    if Connections.antiRagdoll then return end
    Connections.antiRagdoll = RunService.Heartbeat:Connect(function()
        if not Enabled.AntiRagdoll then return end
        local char = LocalPlayer.Character; if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if hum then
            local st = hum:GetState()
            if st==Enum.HumanoidStateType.Physics or st==Enum.HumanoidStateType.Ragdoll or st==Enum.HumanoidStateType.FallingDown then
                hum:ChangeState(Enum.HumanoidStateType.Running)
                workspace.CurrentCamera.CameraSubject = hum
                pcall(function()
                    local pm = LocalPlayer.PlayerScripts:FindFirstChild("PlayerModule")
                    if pm then require(pm:FindFirstChild("ControlModule")):Enable() end
                end)
                if root then root.Velocity=Vector3.new(0,0,0); root.RotVelocity=Vector3.new(0,0,0) end
            end
        end
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("Motor6D") and not obj.Enabled then obj.Enabled=true end
        end
    end)
end
local function stopAntiRagdoll()
    if Connections.antiRagdoll then Connections.antiRagdoll:Disconnect(); Connections.antiRagdoll=nil end
end
local IJ_JumpConn = nil
local IJ_FallConn = nil
local function startInfiniteJump()
    if IJ_JumpConn then IJ_JumpConn:Disconnect() end
    if IJ_FallConn then IJ_FallConn:Disconnect() end
    IJ_JumpConn = UserInputService.JumpRequest:Connect(function()
        if not Enabled.InfiniteJump then return end
        local char = LocalPlayer.Character; if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then root.Velocity = Vector3.new(root.Velocity.X, 55, root.Velocity.Z) end
    end)
    IJ_FallConn = RunService.Heartbeat:Connect(function()
        if not Enabled.InfiniteJump then return end
        local char = LocalPlayer.Character; if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if root and root.Velocity.Y < -120 then
            root.Velocity = Vector3.new(root.Velocity.X, -120, root.Velocity.Z)
        end
    end)
end
local function stopInfiniteJump()
    if IJ_JumpConn then IJ_JumpConn:Disconnect(); IJ_JumpConn = nil end
    if IJ_FallConn then IJ_FallConn:Disconnect(); IJ_FallConn = nil end
end
local function startUnwalk()
    local c = LocalPlayer.Character; if not c then return end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if hum then for _,t in ipairs(hum:GetPlayingAnimationTracks()) do t:Stop() end end
    local anim = c:FindFirstChild("Animate")
    if anim then savedAnimations.Animate=anim:Clone(); anim:Destroy() end
end
local function stopUnwalk()
    local c = LocalPlayer.Character
    if c and savedAnimations.Animate then savedAnimations.Animate:Clone().Parent=c; savedAnimations.Animate=nil end
end
local xrayDescendantConn = nil
local function isXrayTarget(obj)
    if not obj:IsA("BasePart") then return false end
    if not obj.Anchored then return false end
    local n = obj.Name:lower(); local pn = (obj.Parent and obj.Parent.Name:lower()) or ""
    return n:find("base") ~= nil or pn:find("base") ~= nil
end
local function applyXrayToPart(obj)
    pcall(function()
        if isXrayTarget(obj) and originalTransparency[obj] == nil then
            originalTransparency[obj] = obj.LocalTransparencyModifier
            obj.LocalTransparencyModifier = 0.85
        end
    end)
end
local function applyXrayToAll()
    pcall(function() for _, obj in ipairs(workspace:GetDescendants()) do applyXrayToPart(obj) end end)
end
local function startXrayWatcher()
    if xrayDescendantConn then return end
    xrayDescendantConn = workspace.DescendantAdded:Connect(function(obj)
        if not xrayEnabled then return end
        task.defer(function() if xrayEnabled then applyXrayToPart(obj) end end)
    end)
end
local function stopXrayWatcher()
    if xrayDescendantConn then xrayDescendantConn:Disconnect(); xrayDescendantConn=nil end
end
local _antiLagDescConn = nil
local ultraModeEnabled = false

local function applyAntiLag(ultra)
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 1e10
    Lighting.Brightness = 1
    Lighting.EnvironmentDiffuseScale = 0
    Lighting.EnvironmentSpecularScale = 0
    for _, e in pairs(Lighting:GetChildren()) do
        if e:IsA("BlurEffect") or e:IsA("SunRaysEffect") or e:IsA("ColorCorrectionEffect")
            or e:IsA("BloomEffect") or e:IsA("DepthOfFieldEffect") then e.Enabled = false end
    end
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.Material = Enum.Material.Plastic
            obj.Reflectance = 0
            if ultra then obj.CastShadow = false end
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            if ultra then obj:Destroy() else obj.Transparency = 1 end
        elseif ultra and (obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire")) then
            obj.Enabled = false
        end
    end
    if ultra then pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end) end
end
local function enableOptimizer()
    Enabled.Optimizer = true
    applyAntiLag(false)
    if _antiLagDescConn then _antiLagDescConn:Disconnect() end
    _antiLagDescConn = workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("BasePart") then obj.Material = Enum.Material.Plastic; obj.Reflectance = 0
        elseif obj:IsA("Decal") or obj:IsA("Texture") then obj.Transparency = 1 end
    end)
end
local function disableOptimizer()
    Enabled.Optimizer = false
    if _antiLagDescConn then _antiLagDescConn:Disconnect(); _antiLagDescConn = nil end
end
local function enableUltraMode()
    ultraModeEnabled = true
    applyAntiLag(true)
end
local function disableUltraMode()
    ultraModeEnabled = false
end
local removedAccessories = {}
local function removeAccessories()
    if Enabled.RemoveAccessories then
        local char = LocalPlayer.Character
        if not char then return end
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("Accessory") or obj:IsA("Hat") then
                if not removedAccessories[obj] then
                    removedAccessories[obj] = true
                    obj:Destroy()
                end
            end
        end
    end
end
local function startRemoveAccessories()
    Enabled.RemoveAccessories = true
    removeAccessories()
    if not Connections.removeAccessories then
        Connections.removeAccessories = LocalPlayer.CharacterAdded:Connect(function()
            task.wait(0.5)
            if Enabled.RemoveAccessories then removeAccessories() end
        end)
    end
end
local function stopRemoveAccessories()
    Enabled.RemoveAccessories = false
    if Connections.removeAccessories then
        Connections.removeAccessories:Disconnect()
        Connections.removeAccessories = nil
    end
    removedAccessories = {}
end
local dropBrainrotActive = false
local DROP_ASCEND_DURATION = 0.2
local DROP_ASCEND_SPEED = 150
local setDropBrainrotVisual = nil
local function runDropBrainrot()
    if dropBrainrotActive then return end
    local char = LocalPlayer.Character; if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
    dropBrainrotActive = true
    local t0 = tick()
    local dc
    dc = RunService.Heartbeat:Connect(function()
        local r = char and char:FindFirstChild("HumanoidRootPart")
        if not r then
            dc:Disconnect(); dropBrainrotActive = false
            if setDropBrainrotVisual then setDropBrainrotVisual(false) end
            if dropMobileSetter then dropMobileSetter(false) end
            return
        end
        if tick() - t0 >= DROP_ASCEND_DURATION then
            dc:Disconnect()
            local rp = RaycastParams.new()
            rp.FilterDescendantsInstances = {char}
            rp.FilterType = Enum.RaycastFilterType.Exclude
            local rr = workspace:Raycast(r.Position, Vector3.new(0,-2000,0), rp)
            if rr then
                local hum2 = char:FindFirstChildOfClass("Humanoid")
                local off = (hum2 and hum2.HipHeight or 2) + (r.Size.Y/2)
                r.CFrame = CFrame.new(r.Position.X, rr.Position.Y+off, r.Position.Z)
                r.AssemblyLinearVelocity = Vector3.new(0,0,0)
            end
            dropBrainrotActive = false
            if setDropBrainrotVisual then setDropBrainrotVisual(false) end
            if dropMobileSetter then dropMobileSetter(false) end
            return
        end
        r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, DROP_ASCEND_SPEED, r.AssemblyLinearVelocity.Z)
    end)
end
local floatEnabled = false
local floatHeight  = 9.5
local function enableNoCameraCollision()
    noCamCollisionEnabled = true
    if noCamCollisionConn then noCamCollisionConn:Disconnect() end
    noCamCollisionConn = RunService.RenderStepped:Connect(function()
        if not noCamCollisionEnabled then return end
        local ch = LocalPlayer.Character; if not ch then return end
        local cam = workspace.CurrentCamera; if not cam then return end
        local hrp = ch:FindFirstChild("HumanoidRootPart"); if not hrp then return end
        local camPos  = cam.CFrame.Position
        local charPos = hrp.Position + Vector3.new(0, 1.5, 0)
        local toChar  = charPos - camPos
        local dist    = toChar.Magnitude
        if dist < 0.3 then return end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {ch}
        params.IgnoreWater = true
        local hit = {}
        local origin = camPos
        local remaining = toChar
        for _ = 1, 12 do
            if remaining.Magnitude < 0.2 then break end
            local res = workspace:Raycast(origin, remaining, params)
            if not res then break end
            local p = res.Instance
            if p and p:IsA("BasePart") and not p:IsDescendantOf(ch) then
                hit[p] = true
                if noCamParts[p] == nil then noCamParts[p] = p.LocalTransparencyModifier end
                p.LocalTransparencyModifier = 1
            end
            origin    = res.Position + remaining.Unit * 0.02
            remaining = charPos - origin
        end
        for p, orig in pairs(noCamParts) do
            if not hit[p] then
                pcall(function()
                    if p and p.Parent then p.LocalTransparencyModifier = orig end
                end)
                noCamParts[p] = nil
            end
        end
    end)
end

local function disableNoCameraCollision()
    noCamCollisionEnabled = false
    if noCamCollisionConn then noCamCollisionConn:Disconnect(); noCamCollisionConn = nil end
    for p, orig in pairs(noCamParts) do
        pcall(function() if p and p.Parent then p.LocalTransparencyModifier = orig end end)
    end
    noCamParts = {}
end
local function startFloat()
    if Connections.float then Connections.float:Disconnect() end
    Connections.float = RunService.Heartbeat:Connect(function()
        if not floatEnabled then return end
        local char = LocalPlayer.Character; if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
        local rp = RaycastParams.new()
        rp.FilterDescendantsInstances = {char}
        rp.FilterType = Enum.RaycastFilterType.Exclude
        local rr = workspace:Raycast(root.Position, Vector3.new(0,-200,0), rp)
        if rr then
            local diff = (rr.Position.Y + floatHeight) - root.Position.Y
            if math.abs(diff) > 0.3 then
                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, diff*15, root.AssemblyLinearVelocity.Z)
            else
                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
            end
        end
    end)
end
local function stopFloat()
    if Connections.float then Connections.float:Disconnect(); Connections.float = nil end
    local char = LocalPlayer.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z) end
    end
end
local animHeartbeatConn = nil
local originalAnims = nil
local harderHitAnimEnabled = false
local Anims = {
    idle1    = "rbxassetid://133806214992291",
    idle2    = "rbxassetid://94970088341563",
    walk     = "rbxassetid://707897309",
    run      = "rbxassetid://707861613",
    jump     = "rbxassetid://116936326516985",
    fall     = "rbxassetid://116936326516985",
    climb    = "rbxassetid://116936326516985",
    swim     = "rbxassetid://116936326516985",
    swimidle = "rbxassetid://116936326516985",
}
local function saveOriginalAnims(char)
    local animate = char:FindFirstChild("Animate"); if not animate then return end
    local function g(obj) return obj and obj.AnimationId or nil end
    originalAnims = {
        idle1    = g(animate.idle     and animate.idle.Animation1),
        idle2    = g(animate.idle     and animate.idle.Animation2),
        walk     = g(animate.walk     and animate.walk.WalkAnim),
        run      = g(animate.run      and animate.run.RunAnim),
        jump     = g(animate.jump     and animate.jump.JumpAnim),
        fall     = g(animate.fall     and animate.fall.FallAnim),
        climb    = g(animate.climb    and animate.climb.ClimbAnim),
        swim     = g(animate.swim     and animate.swim.Swim),
        swimidle = g(animate.swimidle and animate.swimidle.SwimIdle),
    }
end
local function applyAnimPack(char)
    local animate = char:FindFirstChild("Animate"); if not animate then return end
    local function s(obj, id) if obj then obj.AnimationId = id end end
    s(animate.idle     and animate.idle.Animation1,     Anims.idle1)
    s(animate.idle     and animate.idle.Animation2,     Anims.idle2)
    s(animate.walk     and animate.walk.WalkAnim,       Anims.walk)
    s(animate.run      and animate.run.RunAnim,         Anims.run)
    s(animate.jump     and animate.jump.JumpAnim,       Anims.jump)
    s(animate.fall     and animate.fall.FallAnim,       Anims.fall)
    s(animate.climb    and animate.climb.ClimbAnim,     Anims.climb)
    s(animate.swim     and animate.swim.Swim,           Anims.swim)
    s(animate.swimidle and animate.swimidle.SwimIdle,   Anims.swimidle)
end
local function restoreOriginalAnims(char)
    if not originalAnims then return end
    local animate = char:FindFirstChild("Animate"); if not animate then return end
    local function s(obj, id) if obj and id then obj.AnimationId = id end end
    s(animate.idle     and animate.idle.Animation1,     originalAnims.idle1)
    s(animate.idle     and animate.idle.Animation2,     originalAnims.idle2)
    s(animate.walk     and animate.walk.WalkAnim,       originalAnims.walk)
    s(animate.run      and animate.run.RunAnim,         originalAnims.run)
    s(animate.jump     and animate.jump.JumpAnim,       originalAnims.jump)
    s(animate.fall     and animate.fall.FallAnim,       originalAnims.fall)
    s(animate.climb    and animate.climb.ClimbAnim,     originalAnims.climb)
    s(animate.swim     and animate.swim.Swim,           originalAnims.swim)
    s(animate.swimidle and animate.swimidle.SwimIdle,   originalAnims.swimidle)
    local hum2 = char:FindFirstChildOfClass("Humanoid")
    if hum2 then for _, t in ipairs(hum2:GetPlayingAnimationTracks()) do t:Stop(0) end end
end
local function startHarderHitAnim()
    if animHeartbeatConn then animHeartbeatConn:Disconnect(); animHeartbeatConn = nil end
    local char = LocalPlayer.Character
    if char then
        saveOriginalAnims(char)
        applyAnimPack(char)
        local hum2 = char:FindFirstChildOfClass("Humanoid")
        if hum2 then for _, t in ipairs(hum2:GetPlayingAnimationTracks()) do t:Stop(0) end end
    end
    animHeartbeatConn = RunService.Heartbeat:Connect(function()
        if not harderHitAnimEnabled then return end
        local c = LocalPlayer.Character
        if c then applyAnimPack(c) end
    end)
end
local function stopHarderHitAnim()
    if animHeartbeatConn then animHeartbeatConn:Disconnect(); animHeartbeatConn = nil end
    local char = LocalPlayer.Character
    if char then restoreOriginalAnims(char) end
end
local MEDUSA_COOLDOWN = 25
local medusaLastUsed = 0
local medusaDebounce = false
local medusaCounterEnabled = false
local medusaAnchorConns = {}
local function findMedusa()
    local char = LocalPlayer.Character; if not char then return nil end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local tn = tool.Name:lower()
            if tn:find("medusa") or tn:find("head") or tn:find("stone") then return tool end
        end
    end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then
                local tn = tool.Name:lower()
                if tn:find("medusa") or tn:find("head") or tn:find("stone") then return tool end
            end
        end
    end
    return nil
end
local function useMedusaCounter()
    if medusaDebounce then return end
    if tick() - medusaLastUsed < MEDUSA_COOLDOWN then return end
    local char = LocalPlayer.Character; if not char then return end
    medusaDebounce = true
    local med = findMedusa()
    if not med then medusaDebounce = false; return end
    if med.Parent ~= char then
        local hum2 = char:FindFirstChildOfClass("Humanoid")
        if hum2 then hum2:EquipTool(med) end
    end
    pcall(function() med:Activate() end)
    medusaLastUsed = tick(); medusaDebounce = false
end
local function stopMedusaCounter()
    for _, c in pairs(medusaAnchorConns) do pcall(function() c:Disconnect() end) end
    medusaAnchorConns = {}
end
local function setupMedusaCounter(char)
    stopMedusaCounter(); if not char then return end
    local function onAnchorChanged(part)
        return part:GetPropertyChangedSignal("Anchored"):Connect(function()
            if medusaCounterEnabled and part.Anchored and part.Transparency == 1 then
                useMedusaCounter()
            end
        end)
    end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then table.insert(medusaAnchorConns, onAnchorChanged(part)) end
    end
    table.insert(medusaAnchorConns, char.DescendantAdded:Connect(function(part)
        if part:IsA("BasePart") then table.insert(medusaAnchorConns, onAnchorChanged(part)) end
    end))
end
local function doReturnTeleport(side)
    if brainrotReturnCooldown then return end
    brainrotReturnCooldown = true
    task.spawn(function()
        pcall(function()
            local c = LocalPlayer.Character
            if not c then return end
            local root = c:FindFirstChild("HumanoidRootPart")
            local hum = c:FindFirstChildOfClass("Humanoid")
            if not root then return end
            local rotation = (side == "right") and math.rad(180) or 0
            local step2 = (side == "right") and BR_R2 or BR_L2
            local step3 = (side == "right") and BR_R3 or BR_L3
            local function tp(pos)
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) * CFrame.Angles(0, rotation, 0)
                if hum then hum:ChangeState(Enum.HumanoidStateType.Running); hum:Move(Vector3.zero, false) end
                for _, obj in ipairs(c:GetDescendants()) do
                    if obj:IsA("Motor6D") and not obj.Enabled then obj.Enabled = true end
                end
            end
            tp(step2); task.wait(0.1); tp(step3)
        end)
        local _c = LocalPlayer.Character
        local _hum = _c and _c:FindFirstChildOfClass("Humanoid")
        if _hum then lastKnownHealth = _hum.Health end
        brainrotReturnCooldown = false
        if G_autoPlayAfterTP and G_myPlotSide then
            task.wait(0.3)
            local side = G_myPlotSide
            if fullAutoPlayLeftEnabled then stopFullAutoLeft(); fullAutoPlayLeftEnabled = false; if fullAutoLeftSetter then fullAutoLeftSetter(false) end end
            if fullAutoPlayRightEnabled then stopFullAutoRight(); fullAutoPlayRightEnabled = false; if fullAutoRightSetter then fullAutoRightSetter(false) end end
            task.wait(0.1)
            if side == "left" then
                fullAutoPlayLeftEnabled = true
                if fullAutoLeftSetter then fullAutoLeftSetter(true) end
                startFullAutoLeft()
                if VisualSetters.FullAuto then VisualSetters.FullAuto(true) end
            elseif side == "right" then
                fullAutoPlayRightEnabled = true
                if fullAutoRightSetter then fullAutoRightSetter(true) end
                startFullAutoRight()
                if VisualSetters.FullAuto then VisualSetters.FullAuto(true) end
            end
        end
    end)
end
--[[
RunService.Heartbeat:Connect(function()
    if not (brainrotReturnLeftEnabled or brainrotReturnRightEnabled) then return end
    if brainrotReturnCooldown then return end
    local char = LocalPlayer.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp.Anchored then lastKnownHealth = hum.Health; return end
    local currentHealth = hum.Health
    local wasHit = currentHealth < lastKnownHealth - 1
    local state = hum:GetState()
    local isRagdolled = (
        state == Enum.HumanoidStateType.Physics or
        state == Enum.HumanoidStateType.Ragdoll or
        state == Enum.HumanoidStateType.FallingDown
    )
    lastKnownHealth = currentHealth
    if not (wasHit or isRagdolled) then return end
    if brainrotReturnLeftEnabled then
        doReturnTeleport("left")
    elseif brainrotReturnRightEnabled then
        doReturnTeleport("right")
    end
end)
RunService.Heartbeat:Connect(function()
    if not G_tpAutoEnabled then return end
    if G_countdownActive then return end
    if brainrotReturnCooldown then return end
    local char = LocalPlayer.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp.Anchored then lastKnownHealth = hum.Health; return end
    local hp = hum.Health
    local st = hum:GetState()
    local rag = st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown
    local wasHit = hp < lastKnownHealth - 1; lastKnownHealth = hp
    if wasHit or rag then
        if fullAutoPlayLeftEnabled then stopFullAutoLeft(); fullAutoPlayLeftEnabled = false; if fullAutoLeftSetter then fullAutoLeftSetter(false) end end
        if fullAutoPlayRightEnabled then stopFullAutoRight(); fullAutoPlayRightEnabled = false; if fullAutoRightSetter then fullAutoRightSetter(false) end end
        G_autoPlayAfterTP = true
        local side = G_myPlotSide or refreshMyPlotSide()
        if side == "left" then doReturnTeleport("left")
        elseif side == "right" then doReturnTeleport("right") end
    end
end)
]]
RunService.Heartbeat:Connect(function()
    if not G_tpAutoEnabled then return end
    if brainrotReturnCooldown then return end
    if G_countdownActive then return end
    local char = LocalPlayer.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp.Anchored then lastKnownHealth = hum.Health; return end
    local hp = hum.Health
    local st = hum:GetState()
    local rag = st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown
    local wasHit = hp < lastKnownHealth - 1; lastKnownHealth = hp
    if not (wasHit or rag) then return end
    if fullAutoPlayLeftEnabled then stopFullAutoLeft(); fullAutoPlayLeftEnabled = false; if fullAutoLeftSetter then fullAutoLeftSetter(false) end end
    if fullAutoPlayRightEnabled then stopFullAutoRight(); fullAutoPlayRightEnabled = false; if fullAutoRightSetter then fullAutoRightSetter(false) end end
    local side = G_myPlotSide
    if side == "left" then doReturnTeleport("left")
    elseif side == "right" then doReturnTeleport("right") end
end)

local function monitorCountdown(snd)
    if snd.Name ~= "Countdown" or not snd:IsA("Sound") then return end
    local triggered, conn = false, nil
    G_countdownActive = true
    conn = RunService.Heartbeat:Connect(function()
        if not snd or not snd.Parent or not snd.Playing then
            G_countdownActive = false
            if conn then conn:Disconnect(); conn = nil end; return
        end
        local ct = snd.TimePosition
        if ct >= COUNTDOWN_TARGET and not triggered then
            triggered = true; G_countdownActive = false
            if conn then conn:Disconnect(); conn = nil end
            if not G_tpAutoEnabled then return end
            local side = G_myPlotSide
            if not side then return end
            -- stop current auto play
            if fullAutoPlayLeftEnabled then stopFullAutoLeft(); fullAutoPlayLeftEnabled = false; if fullAutoLeftSetter then fullAutoLeftSetter(false) end end
            if fullAutoPlayRightEnabled then stopFullAutoRight(); fullAutoPlayRightEnabled = false; if fullAutoRightSetter then fullAutoRightSetter(false) end end
            -- start opposite side
            task.wait(0.1)
            if side == "left" then
                fullAutoPlayRightEnabled = true
                if fullAutoRightSetter then fullAutoRightSetter(true) end
                startFullAutoRight()
                if VisualSetters.FullAuto then VisualSetters.FullAuto(true) end
            elseif side == "right" then
                fullAutoPlayLeftEnabled = true
                if fullAutoLeftSetter then fullAutoLeftSetter(true) end
                startFullAutoLeft()
                if VisualSetters.FullAuto then VisualSetters.FullAuto(true) end
            end
        end
        if ct > COUNTDOWN_TARGET + 2 then G_countdownActive = false; if conn then conn:Disconnect(); conn = nil end end
    end)
end

workspace.ChildAdded:Connect(function(child)
    if child.Name == "Countdown" and child:IsA("Sound") then monitorCountdown(child) end
end)
do local ex = workspace:FindFirstChild("Countdown"); if ex and ex:IsA("Sound") then monitorCountdown(ex) end end
-- ============================================================
-- FULL AUTO PLAY (replaced with Script 2 logic)
-- ============================================================
local FAP_L1 = Vector3.new(-476.48, -6.28, 92.73)
local FAP_L2 = Vector3.new(-482.85, -5.03, 93.13)
local FAP_L3 = Vector3.new(-475.68, -6.89, 92.76)
local FAP_L4 = Vector3.new(-476.50, -6.46, 27.58)
local FAP_L5 = Vector3.new(-482.42, -5.03, 27.84)
local FAP_R1 = Vector3.new(-476.16, -6.52, 25.62)
local FAP_R2 = Vector3.new(-483.06, -5.03, 27.51)
local FAP_R3 = Vector3.new(-476.21, -6.63, 27.46)
local FAP_R4 = Vector3.new(-476.66, -6.39, 92.44)
local FAP_R5 = Vector3.new(-481.94, -5.03, 92.42)
local FACE_FAP_L = Vector3.new(-482.25, -4.96, 92.09)
local FACE_FAP_R = Vector3.new(-482.06, -6.93, 35.47)

local FAP_LeftPhase  = 1
local FAP_RightPhase = 1
local function makeFullAutoPlay(getEnabled, setEnabled, getPhase, setPhase, getConn, setConn, getVisual, getMobSetter, p1, p2, p3, p4, p5, faceTgt)
    local pts = {p1, p2, p3, p4, p5}
    local function stop()
        local c = getConn(); if c then c:Disconnect(); setConn(nil) end
        setPhase(1)
        local char = LocalPlayer.Character
        if char then local hum2 = char:FindFirstChildOfClass("Humanoid"); if hum2 then hum2:Move(Vector3.zero, false) end end
    end
    local function start()
        stop(); setPhase(1)
        setConn(RunService.Heartbeat:Connect(function()
            if not getEnabled() then return end
            local char = LocalPlayer.Character; if not char then return end
            local rp = char:FindFirstChild("HumanoidRootPart")
            local hum2 = char:FindFirstChildOfClass("Humanoid")
            if not rp or not hum2 then return end
            local ph = getPhase()
            local tgt = pts[ph]
            local spd
            if fastestStealEnabled and ph >= 4 then
                -- only on return to base (phase 3,4,5)
                local dist = Vector3.new(tgt.X - rp.Position.X, 0, tgt.Z - rp.Position.Z).Magnitude
                if dist > 0.1 then
                    spd = math.clamp(dist / 1.653, 28, 29)
                else
                    spd = CARRY_SPEED
                end
            else
                spd = ph >= 3 and CARRY_SPEED or NORMAL_SPEED
            end
            if (Vector3.new(tgt.X, rp.Position.Y, tgt.Z) - rp.Position).Magnitude < 1 then
                if ph == 5 then
                    hum2:Move(Vector3.zero, false); rp.AssemblyLinearVelocity = Vector3.zero
                    setEnabled(false); stop()
                    local v = getVisual(); if v then v(false) end
                    local mv = getMobSetter(); if mv then mv(false) end
                    if faceTgt then
                        local dir = Vector3.new(faceTgt.X, rp.Position.Y, faceTgt.Z) - rp.Position
                        if dir.Magnitude > 0.01 then rp.CFrame = CFrame.new(rp.Position, rp.Position + dir.Unit) end
                    end
                    return
                elseif ph == 2 then
                    hum2:Move(Vector3.zero, false); rp.AssemblyLinearVelocity = Vector3.zero
                    task.wait(0.05); setPhase(3); return
                else
                    setPhase(ph + 1); return
                end
            end
            local d = tgt - rp.Position
            local mv = Vector3.new(d.X, 0, d.Z).Unit
            hum2:Move(mv, false); rp.AssemblyLinearVelocity = Vector3.new(mv.X * spd, rp.AssemblyLinearVelocity.Y, mv.Z * spd)
        end))
    end
    return start, stop
end

local startFullAutoLeft, stopFullAutoLeft = makeFullAutoPlay(
    function() return fullAutoPlayLeftEnabled end,
    function(v) fullAutoPlayLeftEnabled = v end,
    function() return FAP_LeftPhase end,
    function(v) FAP_LeftPhase = v end,
    function() return fullAutoPlayLeftConn end,
    function(v) fullAutoPlayLeftConn = v end,
    function() return fullAutoLeftSetter end,
    function() return nil end,
    FAP_L1, FAP_L2, FAP_L3, FAP_L4, FAP_L5, FACE_FAP_L
)

local startFullAutoRight, stopFullAutoRight = makeFullAutoPlay(
    function() return fullAutoPlayRightEnabled end,
    function(v) fullAutoPlayRightEnabled = v end,
    function() return FAP_RightPhase end,
    function(v) FAP_RightPhase = v end,
    function() return fullAutoPlayRightConn end,
    function(v) fullAutoPlayRightConn = v end,
    function() return fullAutoRightSetter end,
    function() return nil end,
    FAP_R1, FAP_R2, FAP_R3, FAP_R4, FAP_R5, FACE_FAP_R
)

local function startFullAutoPlay() end
local function stopFullAutoPlay() end
-- ============================================================
-- END FULL AUTO PLAY
-- ============================================================
local SAFE_DELAY = 0.08
local function getBat()
    local char = LocalPlayer.Character; if not char then return nil end
    local tool = char:FindFirstChild("Bat"); if tool then return tool end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then tool=bp:FindFirstChild("Bat"); if tool then tool.Parent=char; return tool end end
    return nil
end
local function getClosestPlayer()
    local c = LocalPlayer.Character; if not c then return nil end
    local hrp = c:FindFirstChild("HumanoidRootPart"); if not hrp then return nil end
    local cp, cd = nil, math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local tr = p.Character:FindFirstChild("HumanoidRootPart")
            if tr then
                local d = (hrp.Position - tr.Position).Magnitude
                if d < cd then cd = d; cp = p end
            end
        end
    end
    return cp
end
local function findBat()
    local c = LocalPlayer.Character; if not c then return nil end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    local SlapList = {"Bat","Slap","Iron Slap","Gold Slap","Diamond Slap","Emerald Slap","Ruby Slap","Dark Matter Slap","Flame Slap","Nuclear Slap","Galaxy Slap","Glitched Slap"}
    for _, name in ipairs(SlapList) do
        local t = c:FindFirstChild(name) or (bp and bp:FindFirstChild(name))
        if t then return t end
    end
    for _, ch in ipairs(c:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end
    if bp then for _, ch in ipairs(bp:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end end
    return nil
end


local _batT = 0
RunService.Heartbeat:Connect(function()
    local now = tick()
    if autoBatToggled and now - _batT >= 1/30 then
        _batT = now
        local c = LocalPlayer.Character; if c then
            local hrp = c:FindFirstChild("HumanoidRootPart"); if hrp then
                local target = getClosestPlayer()
                if target and target.Character then
                    local tr = target.Character:FindFirstChild("HumanoidRootPart")
                    if tr then
                        local fp = tr.Position + tr.CFrame.LookVector * 1.5
                        local dir = (fp - hrp.Position).Unit
                        hrp.AssemblyLinearVelocity = Vector3.new(dir.X*56.5, dir.Y*56.5, dir.Z*56.5)
                    end
                end
            end
        end
    end
    if autoBatToggled then
        local c = LocalPlayer.Character; if c then
            local bat = findBat(); if bat then
                if bat.Parent ~= c then local hum2 = c:FindFirstChildOfClass("Humanoid"); if hum2 then hum2:EquipTool(bat) end end
                if now - lastBatSwing >= BAT_SWING_COOLDOWN then
                    lastBatSwing = now; pcall(function() bat:Activate() end)
                end
            end
        end
    end
end)
local function runTPDown()
    local wasFloating = floatEnabled
    if wasFloating then stopFloat() end
    task.spawn(function()
        pcall(function()
            local c = LocalPlayer.Character; if not c then return end
            local hrp = c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
            local hum = c:FindFirstChildOfClass("Humanoid"); if not hum then return end
            local rp = RaycastParams.new(); rp.FilterDescendantsInstances = {c}; rp.FilterType = Enum.RaycastFilterType.Exclude
            local hit = workspace:Raycast(hrp.Position, Vector3.new(0,-500,0), rp)
            if hit then
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                local hh = hum.HipHeight or 2
                local hy = hrp.Size.Y / 2
                hrp.CFrame = CFrame.new(hit.Position.X, hit.Position.Y + hh + hy + 0.1, hit.Position.Z)
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
        end)
        task.wait(0.1)
        if wasFloating then startFloat() end
        if VisualSetters and VisualSetters.TPDownReset then
            VisualSetters.TPDownReset()
        end
    end)
end
;(function()
local function applyFOV(value)
    FOV_VALUE=value
    local cam=workspace.CurrentCamera
    if cam then cam.FieldOfView=FOV_VALUE end
end
local uiScaleInstance=nil
local function applyUIScale(val)
    UI_SCALE = math.clamp(val, 0.5, 1.0)
    local function applyToFrame(frame)
        if not frame then return end
        local s = frame:FindFirstChildOfClass("UIScale")
        if not s then s = Instance.new("UIScale"); s.Parent = frame end
        s.Scale = UI_SCALE
    end
    local function doApply()
        applyToFrame(main)
        applyToFrame(mobileButtonContainer)
        applyToFrame(apMain)
    end
    if main then
        doApply()
    else
        task.spawn(function()
            repeat task.wait(0.05) until main and mobileButtonContainer and apMain
            doApply()
        end)
    end
end
local function saveConfig()
    local cfg={
        normalSpeed=NORMAL_SPEED, carrySpeed=CARRY_SPEED, laggerSpeed=LAGGER_SPEED,
        fovValue=FOV_VALUE, uiScalePercent=math.floor(UI_SCALE*100+0.5),
        autoBatKey=Keybinds.AutoBat.Name, speedToggleKey=Keybinds.SpeedToggle.Name,
        laggerToggleKey=Keybinds.LaggerToggle.Name,
        uiToggle=Keybinds.UIToggle.Name,
        infiniteJumpKey=Keybinds.InfiniteJump.Name,
        dropBrainrotKey=Keybinds.DropBrainrot.Name,
        floatToggleKey=Keybinds.FloatToggle.Name,
        autoStealEnabled=Enabled.AutoSteal,
        grabRadius=Settings.StealRadius,
        stealDuration=Settings.StealDuration,
        antiRagdoll=Enabled.AntiRagdoll, infiniteJump=Enabled.InfiniteJump,
        galaxyGravity=Values.GalaxyGravityPercent, hopPower=Values.HOP_POWER,
        optimizer=Enabled.Optimizer, unwalk=Enabled.Unwalk,
        removeAccessories=Enabled.RemoveAccessories,
        carryMode=speedToggled,
        brainrotReturnLeft=brainrotReturnLeftEnabled,
        brainrotReturnRight=brainrotReturnRightEnabled,
        laggerMode=laggerToggled,
        sideButtonsVisible=_G.FXSSideButtonsVisible,
        harderHitAnim=harderHitAnimEnabled,
        medusaCounter=medusaCounterEnabled,
        floatEnabled=floatEnabled,
        floatHeight=floatHeight,
        fullAutoLeftKey=Keybinds.FullAutoLeft.Name,
        fullAutoRightKey=Keybinds.FullAutoRight.Name,
        tpDownKey=Keybinds.TPDown.Name,
        fastestSteal=fastestStealEnabled,
        autoSwing=autoSwingEnabled,
        noCamCollision=noCamCollisionEnabled,
        ultraMode=ultraModeEnabled,
        tpAutoEnabled=G_tpAutoEnabled,
        autoPlayAfterTP=G_autoPlayAfterTP,
    }
    if writefile then pcall(function() writefile("FXSHubConfig.json",HttpService:JSONEncode(cfg)) end) end
end
task.spawn(function() while task.wait(5) do saveConfig() end end)
local function loadConfig()
    if not (isfile and isfile("FXSHubConfig.json")) then return end
    local ok,cfg=pcall(function() return HttpService:JSONDecode(readfile("FXSHubConfig.json")) end)
    if not ok or not cfg then return end
    if cfg.normalSpeed  then NORMAL_SPEED=cfg.normalSpeed end
    if cfg.carrySpeed   then CARRY_SPEED=cfg.carrySpeed   end
    if cfg.laggerSpeed  then LAGGER_SPEED=cfg.laggerSpeed end
    if cfg.fovValue     then FOV_VALUE=cfg.fovValue       end
    if cfg.uiScalePercent then
        local pct = math.clamp(cfg.uiScalePercent, 50, 100)
        UI_SCALE = pct / 100
        applyUIScale(UI_SCALE)
    elseif cfg.uiScale then
        UI_SCALE = math.clamp(cfg.uiScale, 0.5, 1.0)
        applyUIScale(UI_SCALE)
    end
    if cfg.autoBatKey   and Enum.KeyCode[cfg.autoBatKey]       then Keybinds.AutoBat=Enum.KeyCode[cfg.autoBatKey]       end
    if cfg.speedToggleKey and Enum.KeyCode[cfg.speedToggleKey] then Keybinds.SpeedToggle=Enum.KeyCode[cfg.speedToggleKey] end
    if cfg.laggerToggleKey and Enum.KeyCode[cfg.laggerToggleKey] then Keybinds.LaggerToggle=Enum.KeyCode[cfg.laggerToggleKey] end
    if cfg.infiniteJumpKey and Enum.KeyCode[cfg.infiniteJumpKey] then Keybinds.InfiniteJump=Enum.KeyCode[cfg.infiniteJumpKey] end
    if cfg.grabRadius   then Settings.StealRadius=cfg.grabRadius; Values.STEAL_RADIUS=cfg.grabRadius end
    if cfg.stealDuration then Settings.StealDuration=cfg.stealDuration; Values.STEAL_DURATION=cfg.stealDuration end
    if cfg.antiRagdoll  ~=nil then Enabled.AntiRagdoll=cfg.antiRagdoll   end
    if cfg.autoStealEnabled~=nil then Enabled.AutoSteal=cfg.autoStealEnabled; Settings.AutoStealEnabled=cfg.autoStealEnabled end
    if cfg.infiniteJump ~=nil then Enabled.InfiniteJump=cfg.infiniteJump  end
    if cfg.optimizer    ~=nil then Enabled.Optimizer=cfg.optimizer        end
    if cfg.unwalk       ~=nil then Enabled.Unwalk=cfg.unwalk              end
    if cfg.removeAccessories ~=nil then Enabled.RemoveAccessories=cfg.removeAccessories end
    if cfg.galaxyGravity then Values.GalaxyGravityPercent=cfg.galaxyGravity end
    if cfg.hopPower      then Values.HOP_POWER=cfg.hopPower                end
    if cfg.sideButtonsVisible~=nil then _G.FXSSideButtonsVisible=cfg.sideButtonsVisible end
    if cfg.carryMode~=nil then
        if cfg.dropBrainrotKey and Enum.KeyCode[cfg.dropBrainrotKey] then Keybinds.DropBrainrot=Enum.KeyCode[cfg.dropBrainrotKey] end
        if cfg.floatToggleKey and Enum.KeyCode[cfg.floatToggleKey] then Keybinds.FloatToggle=Enum.KeyCode[cfg.floatToggleKey] end
        if cfg.floatHeight then floatHeight=cfg.floatHeight end
        if cfg.floatEnabled~=nil then
            floatEnabled=cfg.floatEnabled
            task.defer(function()
                if floatEnabled then startFloat() end
            end)
        end
if cfg.fullAutoLeftKey and Enum.KeyCode[cfg.fullAutoLeftKey] then Keybinds.FullAutoLeft=Enum.KeyCode[cfg.fullAutoLeftKey] end
        if cfg.fullAutoRightKey and Enum.KeyCode[cfg.fullAutoRightKey] then Keybinds.FullAutoRight=Enum.KeyCode[cfg.fullAutoRightKey] end
        if cfg.tpDownKey and Enum.KeyCode[cfg.tpDownKey] then Keybinds.TPDown=Enum.KeyCode[cfg.tpDownKey] end
        if cfg.fastestSteal ~= nil then
            fastestStealEnabled = cfg.fastestSteal
            task.defer(function()
                if VisualSetters and VisualSetters.FastestSteal then VisualSetters.FastestSteal(fastestStealEnabled) end
            end)
        end
        if cfg.autoSwing ~= nil then
            autoSwingEnabled = cfg.autoSwing
            task.defer(function()
                if VisualSetters and VisualSetters.AutoSwing then VisualSetters.AutoSwing(autoSwingEnabled) end
            end)
        end
        if cfg.noCamCollision ~= nil then
            noCamCollisionEnabled = cfg.noCamCollision
            if noCamCollisionEnabled then enableNoCameraCollision() end
            task.defer(function()
                if VisualSetters and VisualSetters.NoCam then VisualSetters.NoCam(noCamCollisionEnabled) end
            end)
        end
        if cfg.ultraMode ~= nil then
            ultraModeEnabled = cfg.ultraMode
            if ultraModeEnabled then enableUltraMode() end
            task.defer(function()
                if VisualSetters and VisualSetters.UltraMode then VisualSetters.UltraMode(ultraModeEnabled) end
            end)
        end
        if cfg.tpAutoEnabled ~= nil then
            G_tpAutoEnabled = cfg.tpAutoEnabled
            if G_tpAutoEnabled then task.spawn(function() refreshMyPlotSide() end) end
            task.defer(function()
                if VisualSetters and VisualSetters.AutoTP then VisualSetters.AutoTP(G_tpAutoEnabled) end
            end)
        end
        if cfg.autoPlayAfterTP ~= nil then
            G_autoPlayAfterTP = cfg.autoPlayAfterTP
            task.defer(function()
                if VisualSetters and VisualSetters.APAfterTP then VisualSetters.APAfterTP(G_autoPlayAfterTP) end
            end)
        end
        if cfg.brainrotReturnLeft ~= nil then brainrotReturnLeftEnabled = cfg.brainrotReturnLeft end
        if cfg.brainrotReturnRight ~= nil then brainrotReturnRightEnabled = cfg.brainrotReturnRight end
        if cfg.harderHitAnim~=nil then
            harderHitAnimEnabled=cfg.harderHitAnim
            if harderHitAnimEnabled then
                task.spawn(function()
                    local timeout = tick() + 10
                    repeat task.wait(0.1) until (VisualSetters and VisualSetters.HarderHitAnim) or tick() > timeout
                    if VisualSetters and VisualSetters.HarderHitAnim then VisualSetters.HarderHitAnim(true) end
                    startHarderHitAnim()
                end)
            end
        end
        if cfg.medusaCounter~=nil then
            medusaCounterEnabled=cfg.medusaCounter
            if medusaCounterEnabled then
                task.spawn(function()
                    local timeout = tick() + 10
                    repeat task.wait(0.1) until (VisualSetters and VisualSetters.MedusaCounter) or tick() > timeout
                    if VisualSetters and VisualSetters.MedusaCounter then VisualSetters.MedusaCounter(true) end
                    setupMedusaCounter(LocalPlayer.Character)
                end)
            end
        end
        speedToggled=cfg.carryMode
        task.defer(function()
            if speedSwBg and speedSwCircle then
                speedSwBg.BackgroundColor3 = speedToggled and C_PURPLE or C_SW_OFF
                speedSwCircle.Position = speedToggled and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9)
            end
            if sideSetters and sideSetters.carrySetter then
                task.wait(0.1)
                if speedToggled then
                    local frame = allFrames[3]
                    if frame and frame.frame then frame.frame.BackgroundColor3 = Color3.fromRGB(20,70,180) end
                end
            end
        end)
    end
    if cfg.laggerMode~=nil then
        laggerToggled=cfg.laggerMode
        task.defer(function()
            if laggerSwBg and laggerSwCircle then
                laggerSwBg.BackgroundColor3 = laggerToggled and Color3.fromRGB(40,140,255) or Color3.fromRGB(50,55,65)
                laggerSwCircle.Position = laggerToggled and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9)
            end
            if sideSetters and sideSetters.laggerSetter then sideSetters.laggerSetter(laggerToggled) end
        end)
    end
end
loadConfig()
end)()
_G.FXSScaleCallbacks = _G.FXSScaleCallbacks or {}
_G.FXSSideButtonsVisible = true
_G.FXSSetSideButtonsVisible = nil
;(function()
local tweenCache = {}
local function getTween(obj, info, props)
    local key = tostring(obj)
    if tweenCache[key] then tweenCache[key]:Cancel() end
    tweenCache[key] = TweenService:Create(obj, info, props)
    return tweenCache[key]
end
local C_BG         = Color3.fromRGB(7, 9, 20)
local C_BG2        = Color3.fromRGB(13, 16, 34)
local C_CARD       = Color3.fromRGB(18, 22, 44)
local C_CARD2      = Color3.fromRGB(23, 28, 58)
local C_PURPLE     = Color3.fromRGB(170, 120, 255)
local C_PURPLE_DARK= Color3.fromRGB(88, 52, 170)
local C_CYAN       = Color3.fromRGB(90, 220, 255)
local C_PINK       = Color3.fromRGB(255, 110, 210)
local C_RED        = Color3.fromRGB(255, 90, 120)
local C_DIM        = Color3.fromRGB(160, 170, 210)
local C_SW_OFF     = Color3.fromRGB(38, 45, 76)
local C_WHITE      = Color3.fromRGB(245, 247, 255)
local C_GLASS      = Color3.fromRGB(255, 255, 255)
local lastTickTime=0
local tickSound=Instance.new("Sound")
tickSound.SoundId="rbxassetid://9119734881"; tickSound.Volume=0.12
tickSound.RollOffMaxDistance=0; tickSound.Parent=SoundService
local function playTick()
    local now=tick()
    if now-lastTickTime < 0.08 then return end
    lastTickTime=now
    tickSound.TimePosition=0
    tickSound:Play()
end local function addCorner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = obj
    return c
end

local function addStroke(obj, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = obj
    return s
end

local function addGradient(obj, c1, c2, rot)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, c1),
        ColorSequenceKeypoint.new(1, c2),
    })
    g.Rotation = rot or 90
    g.Parent = obj
    return g
end

local function addGlassShine(parent, radius)
    local shine = Instance.new("Frame")
    shine.Name = "GlassShine"
    shine.Size = UDim2.new(1, -2, 0.42, 0)
    shine.Position = UDim2.new(0, 1, 0, 1)
    shine.BackgroundColor3 = C_GLASS
    shine.BackgroundTransparency = 0.9
    shine.BorderSizePixel = 0
    shine.ZIndex = parent.ZIndex + 1
    shine.Parent = parent
    addCorner(shine, radius)
    addGradient(shine, Color3.fromRGB(255,255,255), Color3.fromRGB(255,255,255), 90)
    return shine
end

local function addGalaxyGlow(parent, z)
    local glow = Instance.new("ImageLabel")
    glow.Name = "GalaxyGlow"
    glow.AnchorPoint = Vector2.new(0.5, 0.5)
    glow.Position = UDim2.new(0.5, 0, 0.5, 0)
    glow.Size = UDim2.new(1, 120, 1, 120)
    glow.BackgroundTransparency = 1
    glow.Image = "rbxassetid://4996891970"
    glow.ImageTransparency = 0.82
    glow.ScaleType = Enum.ScaleType.Slice
    glow.SliceCenter = Rect.new(20,20,280,280)
    glow.ZIndex = z or 0
    glow.Parent = parent
    return glow
end

local function styleGlassCard(card, radius)
    card.BackgroundColor3 = C_CARD
    card.BorderSizePixel = 0
    addCorner(card, radius or 14)
    addGradient(card, C_CARD2, C_BG2, 135)
    addStroke(card, C_CYAN, 1.2, 0.72)
    addGlassShine(card, radius or 14)

    local inner = Instance.new("Frame")
    inner.Name = "InnerShade"
    inner.Size = UDim2.new(1, -2, 1, -2)
    inner.Position = UDim2.new(0, 1, 0, 1)
    inner.BackgroundColor3 = Color3.fromRGB(255,255,255)
    inner.BackgroundTransparency = 0.97
    inner.BorderSizePixel = 0
    inner.ZIndex = card.ZIndex
    inner.Parent = card
    addCorner(inner, math.max((radius or 14) - 1, 1))
end

local function styleGalaxyButton(btn, active)
    btn.BorderSizePixel = 0
    btn.TextColor3 = C_WHITE
    addCorner(btn, 10)
    local grad = addGradient(
        btn,
        active and C_PURPLE or C_BG2,
        active and C_CYAN or C_CARD,
        120
    )
    local st = addStroke(btn, active and C_CYAN or C_PURPLE, 1.1, active and 0.35 or 0.65)
    addGlassShine(btn, 10)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.16, Enum.EasingStyle.Quart), {
            BackgroundTransparency = 0.02
        }):Play()
        TweenService:Create(st, TweenInfo.new(0.16), {
            Transparency = active and 0.15 or 0.35
        }):Play()
    end)

    btn.MouseLeave:Connect(function()
        TweenService:Create(st, TweenInfo.new(0.16), {
            Transparency = active and 0.35 or 0.65
        }):Play()
    end)

    return grad, st
end
gui=Instance.new("ScreenGui")
gui.Name="FXSHubGUI"; gui.ResetOnSpawn=false; gui.DisplayOrder=10
gui.Parent=LocalPlayer:WaitForChild("PlayerGui")
local topBar = Instance.new("Frame")
topBar.Size = getMobileOptimized(UDim2.new(0,420,0,50),UDim2.new(0,280,0,40))
topBar.Position = getMobileOptimized(UDim2.new(0.5,-210,0,50),UDim2.new(0.5,-140,0,10))
topBar.BackgroundColor3 = C_BG
topBar.BorderSizePixel = 0
topBar.ZIndex = 100
topBar.Active = true
topBar.Parent = gui
styleGlassCard(topBar, 14)
topBar.BackgroundTransparency = 0.08
addGalaxyGlow(topBar, 0)
local fpsLabel = Instance.new("TextLabel", topBar)
fpsLabel.Size = getMobileOptimized(UDim2.new(0,80,1,0),UDim2.new(0,55,1,0))
fpsLabel.Position = getMobileOptimized(UDim2.new(0,15,0,0),UDim2.new(0,8,0,0))
fpsLabel.BackgroundTransparency = 1
fpsLabel.Text = "60 FPS"
fpsLabel.TextColor3 = C_PURPLE
fpsLabel.Font = Enum.Font.GothamBold
fpsLabel.TextSize = getMobileOptimized(13,9)
fpsLabel.TextXAlignment = Enum.TextXAlignment.Left
fpsLabel.ZIndex = 101
local titleLabel = Instance.new("TextLabel", topBar)
titleLabel.Size = getMobileOptimized(UDim2.new(0,200,0,22),UDim2.new(0,120,0,16))
titleLabel.Position = getMobileOptimized(UDim2.new(0.5,-100,0,6),UDim2.new(0.5,-60,0,4))
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "FXS Hub"
titleLabel.TextColor3 = C_WHITE
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextSize = getMobileOptimized(20,15)
titleLabel.TextXAlignment = Enum.TextXAlignment.Center
titleLabel.ZIndex = 101
local subLabel = Instance.new("TextLabel", topBar)
subLabel.Size = getMobileOptimized(UDim2.new(0,200,0,14),UDim2.new(0,120,0,10))
subLabel.Position = getMobileOptimized(UDim2.new(0.5,-100,0,28),UDim2.new(0.5,-60,0,20))
subLabel.BackgroundTransparency = 1
subLabel.Text = "discord.gg/ZuW2d7dd"
subLabel.TextColor3 = C_DIM
subLabel.TextTransparency = 0.2
subLabel.Font = Enum.Font.Gotham
subLabel.TextSize = getMobileOptimized(12,10)
subLabel.TextXAlignment = Enum.TextXAlignment.Center
subLabel.ZIndex = 101
local pingLabel = Instance.new("TextLabel", topBar)
pingLabel.Size = getMobileOptimized(UDim2.new(0,80,1,0),UDim2.new(0,55,1,0))
pingLabel.Position = getMobileOptimized(UDim2.new(1,-95,0,0),UDim2.new(1,-63,0,0))
pingLabel.BackgroundTransparency = 1
pingLabel.Text = "0 ms"
pingLabel.TextColor3 = C_PURPLE
pingLabel.Font = Enum.Font.GothamBold
pingLabel.TextSize = getMobileOptimized(13,9)
pingLabel.TextXAlignment = Enum.TextXAlignment.Right
pingLabel.ZIndex = 101
do
    local drag, ds, sp = false
    topBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            drag = true; ds = inp.Position; sp = topBar.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then drag = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if drag and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - ds
            topBar.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)
end
local lastFrameTime = tick()
local fps = 60
local fpsUpdateTime = 0
RunService.RenderStepped:Connect(function()
    local currentTime = tick()
    fps = 1 / (currentTime - lastFrameTime)
    lastFrameTime = currentTime
    if currentTime - fpsUpdateTime >= 0.5 then
        fpsUpdateTime = currentTime
        fpsLabel.Text = string.format("%.0f", fps) .. " FPS"
        fpsLabel.TextColor3 = fps >= 50 and C_PURPLE or fps >= 30 and Color3.fromRGB(255, 180, 100) or C_RED
    end
end)
task.spawn(function()
    while task.wait(2) do
        local ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
        pingLabel.Text = string.format("%.0f", ping) .. " ms"
        pingLabel.TextColor3 = ping <= 100 and C_PURPLE or ping <= 200 and Color3.fromRGB(255, 180, 100) or C_RED
    end
end)
local BASE_W = getMobileOptimized(380, 300)
local BASE_H = getMobileOptimized(480, 400)
main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, BASE_W, 0, BASE_H)
main.Position = getMobileOptimized(UDim2.new(0,10,0,70),UDim2.new(0.5,-150,0,55))
main.BackgroundColor3 = C_BG
main.BorderSizePixel = 0
main.Active = true
main.ClipsDescendants = false
main.Parent = gui
styleGlassCard(main, 16)
main.BackgroundTransparency = 0.04
addGalaxyGlow(main, 0)

do
    local drag, ds, sp, dragConn = false
    main.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            drag = true; ds = inp.Position; sp = main.Position
            if dragConn then dragConn:Disconnect() end
            dragConn = inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then
                    drag = false
                    if dragConn then dragConn:Disconnect(); dragConn = nil end
                end
            end)
        end
    end)
    local lastDragUpdate = 0
    UserInputService.InputChanged:Connect(function(inp)
        if drag and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local now = tick()
            if now - lastDragUpdate < 0.016 then return end
            lastDragUpdate = now
            local d = inp.Position - ds
            main.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)
end
local header = Instance.new("Frame", main)
header.Size = UDim2.new(1, 0, 0, 85)
header.BackgroundColor3 = C_CARD2
header.BackgroundTransparency = 0.08
header.BorderSizePixel = 0
header.ZIndex = 3
addCorner(header, 16)
addGradient(header, Color3.fromRGB(24, 30, 62), Color3.fromRGB(10, 12, 28), 90)
addStroke(header, C_PURPLE, 1.2, 0.55)
addGlassShine(header, 16)
local headerFix = Instance.new("Frame", header)headerFix.BackgroundColor3 = C_CARD
headerFix.Size = UDim2.new(1, 0, 0, 12); headerFix.Position = UDim2.new(0, 0, 1, -12)
; headerFix.BorderSizePixel = 0; headerFix.ZIndex = 2
local headerTitle = Instance.new("TextLabel", header)
headerTitle.Size = UDim2.new(1, -100, 0, 30); headerTitle.Position = UDim2.new(0, 15, 0, 5)
headerTitle.BackgroundTransparency = 1; headerTitle.Text = "discord.gg/ZuW2d7dd"; headerTitle.TextColor3 = C_WHITE
headerTitle.Font = Enum.Font.GothamBold; headerTitle.TextSize = 16; headerTitle.TextXAlignment = Enum.TextXAlignment.Left; headerTitle.ZIndex = 4
local tabContainer = Instance.new("Frame", header)
tabContainer.Size = UDim2.new(1, -20, 0, 35); tabContainer.Position = UDim2.new(0, 10, 0, 40)
tabContainer.BackgroundTransparency = 1; tabContainer.ZIndex = 4
local tabLayout = Instance.new("UIListLayout", tabContainer)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Padding = UDim.new(0, 5)
local currentTab = "Combat"
local tabPages = {}
local function createTab(tabName, order)
    local tabBtn = Instance.new("TextButton", tabContainer)
    tabBtn.Size = UDim2.new(0, 85, 1, 0)
    tabBtn.BackgroundColor3 = currentTab == tabName and C_PURPLE or C_BG
    tabBtn.BorderSizePixel = 0; tabBtn.Text = tabName; tabBtn.TextColor3 = C_WHITE
    tabBtn.Font = Enum.Font.GothamBold; tabBtn.TextSize = 11; tabBtn.LayoutOrder = order; tabBtn.ZIndex = 5
    Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 6)
    tabBtn.MouseButton1Click:Connect(function()
        playTick()
        currentTab = tabName
        for _, btn in ipairs(tabContainer:GetChildren()) do
            if btn:IsA("TextButton") then
                TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = btn.Text == tabName and C_PURPLE or C_BG}):Play()
            end
        end
        for pageName, page in pairs(tabPages) do page.Visible = pageName == tabName end
    end)
    tabBtn.MouseEnter:Connect(function()
        if tabBtn.Text ~= currentTab then TweenService:Create(tabBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(25,25,35)}):Play() end
    end)
    tabBtn.MouseLeave:Connect(function()
        if tabBtn.Text ~= currentTab then TweenService:Create(tabBtn, TweenInfo.new(0.15), {BackgroundColor3 = C_BG}):Play() end
    end)
    return tabBtn
end
createTab("Combat", 1)
createTab("Movement", 2)
createTab("Visual", 3)
createTab("Auto", 4)
local closeBtn = Instance.new("TextButton", header)
closeBtn.Size = UDim2.new(0,35,0,35); closeBtn.Position = UDim2.new(1,-40,0,5)
closeBtn.BackgroundColor3 = C_RED; closeBtn.BorderSizePixel = 0
closeBtn.Text = "×"; closeBtn.TextColor3 = C_WHITE
closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 24; closeBtn.ZIndex = 8
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
local reopenBtn = Instance.new("TextButton", gui)
reopenBtn.Size = UDim2.new(0,45,0,45); reopenBtn.Position = UDim2.new(0,10,0,70)
reopenBtn.BackgroundColor3 = C_PURPLE; reopenBtn.BorderSizePixel = 0
reopenBtn.Text = "FXS"; reopenBtn.TextColor3 = C_WHITE
reopenBtn.Font = Enum.Font.GothamBlack; reopenBtn.TextSize = 16; reopenBtn.ZIndex = 20; reopenBtn.Visible = false
reopenBtn.Parent = gui
Instance.new("UICorner", reopenBtn).CornerRadius = UDim.new(0, 10)
closeBtn.MouseButton1Click:Connect(function()
    TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size=UDim2.new(0,0,0,0), Position=UDim2.new(0,10,0,70)}):Play()
    task.wait(0.25)
    main.Visible = false; reopenBtn.Visible = true
    TweenService:Create(reopenBtn, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size=UDim2.new(0,45,0,45)}):Play()
end)
reopenBtn.MouseButton1Click:Connect(function()
    TweenService:Create(reopenBtn, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size=UDim2.new(0,0,0,0)}):Play()
    task.wait(0.15)
    reopenBtn.Visible = false
    main.Size = UDim2.new(0,0,0,0); main.Position = UDim2.new(0,10,0,70); main.Visible = true
    TweenService:Create(main, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size=UDim2.new(0,BASE_W,0,BASE_H), Position=UDim2.new(0,10,0,70)}):Play()
end)
closeBtn.MouseEnter:Connect(function() playTick(); getTween(closeBtn, TweenInfo.new(0.15), {BackgroundColor3=Color3.fromRGB(255,80,100)}):Play() end)
closeBtn.MouseLeave:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3=C_RED}):Play() end)
local scroll = Instance.new("ScrollingFrame", main)
scroll.Size = UDim2.new(1,-20,1,-175); scroll.Position = UDim2.new(0,10,0,90)
scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0; scroll.ScrollBarThickness = 3
scroll.ScrollBarImageColor3 = C_PURPLE; scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new(0,0,0,0); scroll.ZIndex = 2; scroll.ScrollingEnabled = true
local KeybindDisplayLabels = {}
local waitingForKey = nil
local function createTabPage(tabName)
    local page = Instance.new("Frame", scroll)
    page.Size = UDim2.new(1, 0, 0, 0); page.AutomaticSize = Enum.AutomaticSize.Y
    page.BackgroundTransparency = 1; page.Visible = tabName == "Combat"; page.ZIndex = 2
    local pageLayout = Instance.new("UIListLayout", page)
    pageLayout.Padding = UDim.new(0, 8); pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabPages[tabName] = page
    return page
end
local combatPage = createTabPage("Combat")
local movementPage = createTabPage("Movement")
local visualPage = createTabPage("Visual")
local autoPage = createTabPage("Auto")
local function createSection(parent, text, order)
    local section = Instance.new("Frame", parent)
    section.Size = UDim2.new(1,0,0,30); section.BackgroundTransparency = 1; section.LayoutOrder = order; section.ZIndex = 3
    local label = Instance.new("TextLabel", section)
    label.Size = UDim2.new(1,0,1,0); label.BackgroundTransparency = 1; label.Text = text:upper()
    label.TextColor3 = C_PURPLE; label.Font = Enum.Font.GothamBold; label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left; label.ZIndex = 4
    local line = Instance.new("Frame", section)
    line.Size = UDim2.new(1,0,0,1); line.Position = UDim2.new(0,0,1,0)
    line.BackgroundColor3 = C_PURPLE; line.BackgroundTransparency = 0.7; line.BorderSizePixel = 0; line.ZIndex = 3
end
local function createToggle(parent, labelText, keybindName, enabledKey, defaultOn, order, onToggle)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(1,0,0,42); container.BackgroundColor3 = C_CARD
    container.BorderSizePixel = 0; container.LayoutOrder = order; container.ZIndex = 3
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 8)
    local containerStroke = Instance.new("UIStroke", container)
    containerStroke.Color = C_PURPLE; containerStroke.Thickness = 1; containerStroke.Transparency = 0.8
    local xOffset = 10
    local badge, badgeText
    if keybindName and keybindName ~= "" then
        badge = Instance.new("Frame", container)
        badge.Size = UDim2.new(0,28,0,20); badge.Position = UDim2.new(0,10,0.5,-10)
        badge.BackgroundColor3 = C_PURPLE; badge.BackgroundTransparency = 0.3; badge.BorderSizePixel = 0; badge.ZIndex = 5
        Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 6)
        badgeText = Instance.new("TextLabel", badge)
        badgeText.Size = UDim2.new(1,0,1,0); badgeText.BackgroundTransparency = 1
        badgeText.Text = Keybinds[keybindName] and Keybinds[keybindName].Name or keybindName
        badgeText.TextColor3 = C_WHITE; badgeText.Font = Enum.Font.GothamBold; badgeText.TextSize = 10; badgeText.ZIndex = 6
        KeybindDisplayLabels[keybindName] = badgeText
        xOffset = 45
    end
    local label = Instance.new("TextLabel", container)
    label.Size = UDim2.new(1,-120,1,0); label.Position = UDim2.new(0,xOffset,0,0)
    label.BackgroundTransparency = 1; label.Text = labelText; label.TextColor3 = C_WHITE
    label.Font = Enum.Font.GothamBold; label.TextSize = 13; label.TextXAlignment = Enum.TextXAlignment.Left; label.ZIndex = 5
    local switchBg = Instance.new("Frame", container)
    switchBg.Size = UDim2.new(0,48,0,24); switchBg.Position = UDim2.new(1,-58,0.5,-12)
    switchBg.BackgroundColor3 = defaultOn and C_PURPLE or C_SW_OFF; switchBg.BorderSizePixel = 0; switchBg.ZIndex = 5
    Instance.new("UICorner", switchBg).CornerRadius = UDim.new(1, 0)
    local switchCircle = Instance.new("Frame", switchBg)
    switchCircle.Size = UDim2.new(0,20,0,20)
    switchCircle.Position = defaultOn and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10)
    switchCircle.BackgroundColor3 = Color3.fromRGB(0,0,0); switchCircle.BorderSizePixel = 0; switchCircle.ZIndex = 6
    Instance.new("UICorner", switchCircle).CornerRadius = UDim.new(1, 0)
    local isOn = defaultOn
    local isHoldingForKeybind = false
    local holdStartTime = 0
    local function setVisual(state)
        isOn = state
        TweenService:Create(switchBg, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3 = isOn and C_PURPLE or C_SW_OFF}):Play()
        TweenService:Create(switchCircle, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Position = isOn and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10)}):Play()
    end
    if enabledKey then VisualSetters[enabledKey] = setVisual end
    local function startKeybindChange()
        if not keybindName or keybindName == "" or not badgeText then return end
        waitingForKey = keybindName
        badgeText.Text = "..."
        TweenService:Create(badge, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(255,180,100)}):Play()
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gpe)
            if waitingForKey ~= keybindName then conn:Disconnect(); return end
            local isKeyboard = input.UserInputType == Enum.UserInputType.Keyboard
            local isGamepad = input.UserInputType == Enum.UserInputType.Gamepad1 or input.UserInputType == Enum.UserInputType.Gamepad2
            if not (isKeyboard or isGamepad) then return end
            local kc = input.KeyCode
            if isKeyboard and kc == Enum.KeyCode.Escape then
                badgeText.Text = Keybinds[keybindName].Name
                TweenService:Create(badge, TweenInfo.new(0.15), {BackgroundColor3 = C_PURPLE, BackgroundTransparency = 0.3}):Play()
                waitingForKey = nil; conn:Disconnect(); return
            end
            if kc == Enum.KeyCode.Unknown then return end
            Keybinds[keybindName] = kc
            badgeText.Text = kc.Name
            TweenService:Create(badge, TweenInfo.new(0.15), {BackgroundColor3 = C_PURPLE, BackgroundTransparency = 0.3}):Play()
            waitingForKey = nil; conn:Disconnect()
        end)
    end
    local btn = Instance.new("TextButton", container)
    btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""; btn.ZIndex = 7
    btn.MouseButton1Click:Connect(function()
        if not isHoldingForKeybind then
            playTick(); isOn = not isOn; setVisual(isOn)
            if enabledKey then Enabled[enabledKey] = isOn end
            if onToggle then onToggle(isOn) end
        end
        isHoldingForKeybind = false; holdStartTime = 0
    end)
    btn.MouseButton2Click:Connect(function() playTick(); startKeybindChange() end)
    btn.MouseButton1Down:Connect(function()
        isHoldingForKeybind = false; holdStartTime = tick()
        task.delay(0.6, function()
            if holdStartTime > 0 and (tick() - holdStartTime) >= 0.6 then
                isHoldingForKeybind = true; playTick(); startKeybindChange()
            end
        end)
    end)
    btn.MouseButton1Up:Connect(function()
        if (tick() - holdStartTime) < 0.6 then holdStartTime = 0 end
    end)
    btn.MouseEnter:Connect(function()
        TweenService:Create(containerStroke, TweenInfo.new(0.15), {Transparency=0.3}):Play()
        TweenService:Create(container, TweenInfo.new(0.15), {BackgroundColor3=Color3.fromRGB(25,25,35)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(containerStroke, TweenInfo.new(0.15), {Transparency=0.8}):Play()
        TweenService:Create(container, TweenInfo.new(0.15), {BackgroundColor3=C_CARD}):Play()
    end)
    return setVisual, switchBg, switchCircle
end
local order = 0
local function O() order = order + 1; return order end
createSection(combatPage, "Speed & Combat", O())
createToggle(combatPage, "Anti Ragdoll", "", "AntiRagdoll", Enabled.AntiRagdoll, O(), function(s)
    if s then startAntiRagdoll() else stopAntiRagdoll() end
end)
local brSwBgL, brSwCircleL, brSwBgR, brSwCircleR
local brLeftVisual, _brSwBgL, _brSwCircleL = createToggle(combatPage, "Brainrot Return L", "", nil, false, O(), function(on)
    if on and brainrotReturnRightEnabled then
        brainrotReturnRightEnabled = false
        if brSwBgR and brSwCircleR then
            TweenService:Create(brSwBgR, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3=C_SW_OFF}):Play()
            TweenService:Create(brSwCircleR, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Position=UDim2.new(0,2,0.5,-10)}):Play()
        end
        if _G.FXSBRSetters and _G.FXSBRSetters.right then _G.FXSBRSetters.right(false) end
    end
    brainrotReturnLeftEnabled = on
    if _G.FXSBRSetters and _G.FXSBRSetters.left then _G.FXSBRSetters.left(on) end
end)
brSwBgL = _brSwBgL; brSwCircleL = _brSwCircleL
local brRightVisual, _brSwBgR, _brSwCircleR = createToggle(combatPage, "Brainrot Return R", "", nil, false, O(), function(on)
    if on and brainrotReturnLeftEnabled then
        brainrotReturnLeftEnabled = false
        if brSwBgL and brSwCircleL then
            TweenService:Create(brSwBgL, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3=C_SW_OFF}):Play()
            TweenService:Create(brSwCircleL, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Position=UDim2.new(0,2,0.5,-10)}):Play()
        end
        if _G.FXSBRSetters and _G.FXSBRSetters.left then _G.FXSBRSetters.left(false) end
    end
    brainrotReturnRightEnabled = on
    if _G.FXSBRSetters and _G.FXSBRSetters.right then _G.FXSBRSetters.right(on) end
end)
brSwBgR = _brSwBgR; brSwCircleR = _brSwCircleR
_G.FXSBRSetters = {left=brLeftVisual, right=brRightVisual}
local carryToggleCallback
local speedClk, _speedSwBg, _speedSwCircle = createToggle(combatPage, "Carry Mode", "SpeedToggle", nil, speedToggled, O(), function(on)
    if on and laggerToggled then
        laggerToggled = false
        if laggerSwBg and laggerSwCircle then
            TweenService:Create(laggerSwBg, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3=C_SW_OFF}):Play()
            TweenService:Create(laggerSwCircle, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Position=UDim2.new(0,2,0.5,-10)}):Play()
        end
        if laggerClk then laggerClk(false) end
        if sideSetters and sideSetters.laggerSetter then sideSetters.laggerSetter(false) end
    end
    speedToggled = on
    if sideSetters and sideSetters.carrySetter then sideSetters.carrySetter(on) end
end)
carryToggleCallback = _speedSwBg; speedSwBg = _speedSwBg; speedSwCircle = _speedSwCircle
local laggerToggleCallback
local laggerClk, _laggerSwBg, _laggerSwCircle = createToggle(combatPage, "Lagger Mode", "LaggerToggle", nil, laggerToggled, O(), function(on)
    if on and speedToggled then
        speedToggled = false
        if speedSwBg and speedSwCircle then
            TweenService:Create(speedSwBg, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3=C_SW_OFF}):Play()
            TweenService:Create(speedSwCircle, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Position=UDim2.new(0,2,0.5,-10)}):Play()
        end
        if speedClk then speedClk(false) end
        if sideSetters and sideSetters.carrySetter then sideSetters.carrySetter(false) end
    end
    laggerToggled = on
    if sideSetters and sideSetters.laggerSetter then sideSetters.laggerSetter(on) end
end)
laggerToggleCallback = _laggerSwBg; laggerSwBg = _laggerSwBg; laggerSwCircle = _laggerSwCircle
local batClk, _batSwBg, _batSwCircle = createToggle(combatPage, "Auto Bat", "AutoBat", nil, autoBatToggled, O(), function(on)
    autoBatToggled = on
    autoSwingEnabled = on
    if VisualSetters.AutoSwing then VisualSetters.AutoSwing(on) end
    if sideSetters and sideSetters.batSetter then sideSetters.batSetter(on) end
end)
local setHarderHitVisual, _, _ = createToggle(combatPage, "Harder Hit Anim", "", nil, false, O(), function(on)
    harderHitAnimEnabled = on
    if on then startHarderHitAnim() else stopHarderHitAnim() end
end)
VisualSetters.HarderHitAnim = setHarderHitVisual
local setMedusaVisual, _, _ = createToggle(combatPage, "Medusa Counter", "", nil, false, O(), function(on)
    medusaCounterEnabled = on
    if on then setupMedusaCounter(LocalPlayer.Character) else stopMedusaCounter() end
end)
local setAutoSwingVisual, _, _ = createToggle(combatPage, "Auto Swing", "", nil, false, O(), function(on)
    autoSwingEnabled = on
end)
local setFastestStealVisual, _, _ = createToggle(combatPage, "Fastest Steal Speed", "", nil, false, O(), function(on)
    fastestStealEnabled = on
end)
VisualSetters.FastestSteal = setFastestStealVisual
VisualSetters.AutoSwing = setAutoSwingVisual
VisualSetters.MedusaCounter = setMedusaVisual
batSwBg = _batSwBg; batSwCircle = _batSwCircle
order = 0
createSection(autoPage, "Auto Features", O())
local setTPAutoVisual, _, _ = createToggle(autoPage, "Auto TP", "", nil, false, O(), function(on)
    G_tpAutoEnabled = on
    if on then task.spawn(function() refreshMyPlotSide() end) end
end)
VisualSetters.AutoTP = setTPAutoVisual

local setAPAfterTPVisual, _, _ = createToggle(autoPage, "Auto Play After TP", "", nil, false, O(), function(on)
    G_autoPlayAfterTP = on
end)
VisualSetters.APAfterTP = setAPAfterTPVisual

local setCountdownVisual, _, _ = createToggle(autoPage, "Auto Play After Countdown", "", nil, false, O(), function(on)
    if on then local ex = workspace:FindFirstChild("Countdown"); if ex and ex:IsA("Sound") then monitorCountdown(ex) end end
end)
VisualSetters.Countdown = setCountdownVisual
local autoStealContainer = Instance.new("Frame", autoPage)
autoStealContainer.Size = UDim2.new(1,0,0,42); autoStealContainer.BackgroundTransparency = 1
autoStealContainer.LayoutOrder = O(); autoStealContainer.ClipsDescendants = false; autoStealContainer.ZIndex = 3
local asRow = Instance.new("Frame", autoStealContainer)
asRow.Size = UDim2.new(1,0,0,42); asRow.BackgroundColor3 = C_CARD; asRow.BorderSizePixel = 0; asRow.ZIndex = 3
Instance.new("UICorner", asRow).CornerRadius = UDim.new(0, 8)
local asStroke = Instance.new("UIStroke", asRow)
asStroke.Color = C_PURPLE; asStroke.Thickness = 1; asStroke.Transparency = 0.8
local asLabel = Instance.new("TextLabel", asRow)
asLabel.Size = UDim2.new(1,-120,1,0); asLabel.Position = UDim2.new(0,10,0,0)
asLabel.BackgroundTransparency = 1; asLabel.Text = "Auto Steal"; asLabel.TextColor3 = C_WHITE
asLabel.Font = Enum.Font.GothamBold; asLabel.TextSize = 13; asLabel.TextXAlignment = Enum.TextXAlignment.Left; asLabel.ZIndex = 5
local asSwitchBg = Instance.new("Frame", asRow)
asSwitchBg.Size = UDim2.new(0,48,0,24); asSwitchBg.Position = UDim2.new(1,-58,0.5,-12)
asSwitchBg.BackgroundColor3 = Enabled.AutoSteal and C_PURPLE or C_SW_OFF; asSwitchBg.BorderSizePixel = 0; asSwitchBg.ZIndex = 5
Instance.new("UICorner", asSwitchBg).CornerRadius = UDim.new(1, 0)
local asSwitchCircle = Instance.new("Frame", asSwitchBg)
asSwitchCircle.Size = UDim2.new(0,20,0,20)
asSwitchCircle.Position = Enabled.AutoSteal and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10)
asSwitchCircle.BackgroundColor3 = Color3.fromRGB(0,0,0); asSwitchCircle.BorderSizePixel = 0; asSwitchCircle.ZIndex = 6
Instance.new("UICorner", asSwitchCircle).CornerRadius = UDim.new(1, 0)
local asDropdown = Instance.new("Frame", autoStealContainer)
asDropdown.Size = UDim2.new(1,0,0,0); asDropdown.Position = UDim2.new(0,0,0,47)
asDropdown.BackgroundColor3 = Color3.fromRGB(25,25,35); asDropdown.BorderSizePixel = 0
asDropdown.ClipsDescendants = true; asDropdown.Visible = false; asDropdown.ZIndex = 4
Instance.new("UICorner", asDropdown).CornerRadius = UDim.new(0, 8)
local asDropStroke = Instance.new("UIStroke", asDropdown)
asDropStroke.Color = C_PURPLE; asDropStroke.Thickness = 1; asDropStroke.Transparency = 0.8
local durationLabel = Instance.new("TextLabel", asDropdown)
durationLabel.Size = UDim2.new(0.5,-10,0,30); durationLabel.Position = UDim2.new(0,10,0,10)
durationLabel.BackgroundTransparency = 1; durationLabel.Text = "Steal Duration:"; durationLabel.TextColor3 = C_DIM
durationLabel.Font = Enum.Font.Gotham; durationLabel.TextSize = 12; durationLabel.TextXAlignment = Enum.TextXAlignment.Left; durationLabel.ZIndex = 5
DurationInput = Instance.new("TextBox", asDropdown)
DurationInput.Size = UDim2.new(0,60,0,26); DurationInput.Position = UDim2.new(1,-70,0,12)
DurationInput.BackgroundColor3 = C_CARD; DurationInput.BorderSizePixel = 0
DurationInput.Text = tostring(Settings.StealDuration); DurationInput.TextColor3 = C_WHITE
DurationInput.Font = Enum.Font.GothamBold; DurationInput.TextSize = 11; DurationInput.ZIndex = 5
Instance.new("UICorner", DurationInput).CornerRadius = UDim.new(0, 6)
local dStr = Instance.new("UIStroke", DurationInput)
dStr.Color = C_PURPLE; dStr.Thickness = 1; dStr.Transparency = 0.5
DurationInput.FocusLost:Connect(function()
    local n = tonumber(DurationInput.Text)
    if n then
        Settings.StealDuration = math.clamp(n, 0.05, 5)
        Values.STEAL_DURATION = Settings.StealDuration
        DurationInput.Text = string.format("%.2f", Settings.StealDuration)
    end
end)
local dropdownOpen = false
local inputHoldTime = 0
local isHolding = false
local function toggleDropdown()
    dropdownOpen = not dropdownOpen
    local targetHeight = dropdownOpen and 50 or 0
    asDropdown.Visible = true
    TweenService:Create(asDropdown, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Size=UDim2.new(1,0,0,targetHeight)}):Play()
    if not dropdownOpen then
        task.delay(0.2, function() if not dropdownOpen then asDropdown.Visible = false end end)
    end
    local totalHeight = dropdownOpen and 97 or 42
    TweenService:Create(autoStealContainer, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Size=UDim2.new(1,0,0,totalHeight)}):Play()
end
local asBtn = Instance.new("TextButton", asRow)
asBtn.Size = UDim2.new(1,0,1,0); asBtn.BackgroundTransparency = 1; asBtn.Text = ""; asBtn.ZIndex = 7
asBtn.MouseButton1Click:Connect(function()
    if not isHolding then
        playTick()
        Enabled.AutoSteal = not Enabled.AutoSteal; Settings.AutoStealEnabled = Enabled.AutoSteal
        TweenService:Create(asSwitchBg, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3 = Enabled.AutoSteal and C_PURPLE or C_SW_OFF}):Play()
        TweenService:Create(asSwitchCircle, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Position = Enabled.AutoSteal and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10)}):Play()
        if Enabled.AutoSteal then startAutoSteal() else stopAutoSteal() end
    end
    isHolding = false; inputHoldTime = 0
end)
asBtn.MouseButton2Click:Connect(function() playTick(); toggleDropdown() end)
asBtn.MouseButton1Down:Connect(function()
    isHolding = false; inputHoldTime = tick()
    task.delay(0.5, function()
        if inputHoldTime > 0 and (tick() - inputHoldTime) >= 0.5 then isHolding = true; playTick(); toggleDropdown() end
    end)
end)
asBtn.MouseButton1Up:Connect(function()
    if (tick() - inputHoldTime) < 0.5 then inputHoldTime = 0 end
end)
asBtn.MouseEnter:Connect(function()
    TweenService:Create(asStroke, TweenInfo.new(0.15), {Transparency=0.3}):Play()
    TweenService:Create(asRow, TweenInfo.new(0.15), {BackgroundColor3=Color3.fromRGB(25,25,35)}):Play()
end)
asBtn.MouseLeave:Connect(function()
    TweenService:Create(asStroke, TweenInfo.new(0.15), {Transparency=0.8}):Play()
    TweenService:Create(asRow, TweenInfo.new(0.15), {BackgroundColor3=C_CARD}):Play()
end)
order = 0
createSection(movementPage, "Movement", O())
createToggle(movementPage, "Infinite Jump", "", "InfiniteJump", Enabled.InfiniteJump, O(), function(s)
    if s then startInfiniteJump() else stopInfiniteJump() end
end)
createToggle(movementPage, "Unwalk", "", "Unwalk", Enabled.Unwalk, O(), function(s)
    if s then startUnwalk() else stopUnwalk() end
end)
local setFloatVisual, _, _ = createToggle(movementPage, "Float", "FloatToggle", nil, false, O(), function(on)
    floatEnabled = on
    if on then startFloat() else stopFloat() end
end)
local _dropVis, _, _ = createToggle(movementPage, "Drop Brainrot", "DropBrainrot", nil, false, O(), function(on)
    if on then task.spawn(runDropBrainrot) end
end)
setDropBrainrotVisual = _dropVis
local setTPDownVisual, tpDownSwBg, tpDownSwCircle = createToggle(movementPage, "TP Down", "", nil, false, O(), function(on)
    if on then runTPDown() end
end)
VisualSetters.TPDown = setTPDownVisual
VisualSetters.TPDownReset = function()
    -- fully reset visual AND internal state by tweening directly
    TweenService:Create(tpDownSwBg, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3 = C_SW_OFF}):Play()
    TweenService:Create(tpDownSwCircle, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Position = UDim2.new(0,2,0.5,-10)}):Play()
    -- also call setVisual so internal isOn is false
    setTPDownVisual(false)
end
local setNoCamVisual, _, _ = createToggle(movementPage, "No Cam Collision", "", nil, false, O(), function(on)
    noCamCollisionEnabled = on
    if on then enableNoCameraCollision() else disableNoCameraCollision() end
end)
VisualSetters.NoCam = setNoCamVisual
createSection(movementPage, "Float Settings", O())
local function createFloatHeightInput(parent, order)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(1,0,0,42); container.BackgroundColor3 = C_CARD
    container.BorderSizePixel = 0; container.LayoutOrder = order; container.ZIndex = 3
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", container)
    stroke.Color = C_PURPLE; stroke.Thickness = 1; stroke.Transparency = 0.8
    local label = Instance.new("TextLabel", container)
    label.Size = UDim2.new(0.5,-10,1,0); label.Position = UDim2.new(0,10,0,0)
    label.BackgroundTransparency = 1; label.Text = "Float Height"; label.TextColor3 = C_WHITE
    label.Font = Enum.Font.GothamBold; label.TextSize = 13; label.TextXAlignment = Enum.TextXAlignment.Left; label.ZIndex = 4
    local input = Instance.new("TextBox", container)
    input.Size = UDim2.new(0,70,0,26); input.Position = UDim2.new(1,-80,0.5,-13)
    input.BackgroundColor3 = C_CARD; input.BorderSizePixel = 0; input.Text = tostring(floatHeight)
    input.TextColor3 = C_WHITE; input.Font = Enum.Font.GothamBold; input.TextSize = 11; input.ZIndex = 4
    Instance.new("UICorner", input).CornerRadius = UDim.new(0, 6)
    local inputStroke = Instance.new("UIStroke", input)
    inputStroke.Color = C_PURPLE; inputStroke.Thickness = 1; inputStroke.Transparency = 0.5
    input.FocusLost:Connect(function()
        local n = tonumber(input.Text)
        if n then floatHeight = math.clamp(n, 1, 100); input.Text = tostring(floatHeight)
        else input.Text = tostring(floatHeight) end
    end)
end
createFloatHeightInput(movementPage, O())
createSection(movementPage, "Speed Settings", O())
local function createSpeedInput(parent, labelText, defaultValue, variableName, order)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(1,0,0,42); container.BackgroundColor3 = C_CARD
    container.BorderSizePixel = 0; container.LayoutOrder = order; container.ZIndex = 3
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", container)
    stroke.Color = C_PURPLE; stroke.Thickness = 1; stroke.Transparency = 0.8
    local label = Instance.new("TextLabel", container)
    label.Size = UDim2.new(0.5,-10,1,0); label.Position = UDim2.new(0,10,0,0)
    label.BackgroundTransparency = 1; label.Text = labelText; label.TextColor3 = C_WHITE
    label.Font = Enum.Font.GothamBold; label.TextSize = 13; label.TextXAlignment = Enum.TextXAlignment.Left; label.ZIndex = 4
    local input = Instance.new("TextBox", container)
    input.Size = UDim2.new(0,70,0,26); input.Position = UDim2.new(1,-80,0.5,-13)
    input.BackgroundColor3 = C_CARD; input.BorderSizePixel = 0; input.Text = tostring(defaultValue)
    input.TextColor3 = C_WHITE; input.Font = Enum.Font.GothamBold; input.TextSize = 11; input.ZIndex = 4
    Instance.new("UICorner", input).CornerRadius = UDim.new(0, 6)
    local inputStroke = Instance.new("UIStroke", input)
    inputStroke.Color = C_PURPLE; inputStroke.Thickness = 1; inputStroke.Transparency = 0.5
    input.FocusLost:Connect(function()
        local n = tonumber(input.Text)
        if n then
            n = math.clamp(math.floor(n * 10) / 10, 1, 9999)
            if variableName == "NORMAL" then NORMAL_SPEED = n
            elseif variableName == "CARRY" then CARRY_SPEED = n
            elseif variableName == "LAGGER" then LAGGER_SPEED = n end
            input.Text = string.format("%.1f", n)
        else
            if variableName == "NORMAL" then input.Text = tostring(NORMAL_SPEED)
            elseif variableName == "CARRY" then input.Text = tostring(CARRY_SPEED)
            elseif variableName == "LAGGER" then input.Text = tostring(LAGGER_SPEED) end
        end
    end)
end
createSpeedInput(movementPage, "Normal Speed", NORMAL_SPEED, "NORMAL", O())
createSpeedInput(movementPage, "Carry Speed", CARRY_SPEED, "CARRY", O())
createSpeedInput(movementPage, "Lagger Speed", LAGGER_SPEED, "LAGGER", O())
order = 0
createSection(visualPage, "Visual", O())
createToggle(visualPage, "Anti Lag", "", "Optimizer", Enabled.Optimizer, O(), function(s)
    if s then enableOptimizer() else disableOptimizer() end
end)
local setUltraVisual, _, _ = createToggle(visualPage, "Ultra Mode", "", nil, false, O(), function(s)
    ultraModeEnabled = s
    if s then enableUltraMode() else disableUltraMode() end
end)
createToggle(visualPage, "Remove Accessories", "", "RemoveAccessories", Enabled.RemoveAccessories, O(), function(s)
    if s then startRemoveAccessories() else stopRemoveAccessories() end
end)
createSection(visualPage, "GUI Scale", O())
createSection(visualPage, "Config", O())
do
    local container = Instance.new("Frame", visualPage)
    container.Size = UDim2.new(1,0,0,42); container.BackgroundColor3 = C_CARD
    container.BorderSizePixel = 0; container.LayoutOrder = O(); container.ZIndex = 3
    Instance.new("UICorner", container).CornerRadius = UDim.new(0,8)
    local containerStroke = Instance.new("UIStroke", container)
    containerStroke.Color = C_PURPLE; containerStroke.Thickness = 1; containerStroke.Transparency = 0.8
    local label = Instance.new("TextLabel", container)
    label.Size = UDim2.new(1,-120,1,0); label.Position = UDim2.new(0,10,0,0)
    label.BackgroundTransparency = 1; label.Text = "Reset Config"
    label.TextColor3 = C_WHITE; label.Font = Enum.Font.GothamBold
    label.TextSize = 13; label.TextXAlignment = Enum.TextXAlignment.Left; label.ZIndex = 4
    local resetBtn = Instance.new("TextButton", container)
    resetBtn.Size = UDim2.new(0,70,0,28); resetBtn.Position = UDim2.new(1,-80,0.5,-14)
    resetBtn.BackgroundColor3 = C_RED; resetBtn.BorderSizePixel = 0
    resetBtn.Text = "RESET"; resetBtn.TextColor3 = C_WHITE
    resetBtn.Font = Enum.Font.GothamBold; resetBtn.TextSize = 11; resetBtn.ZIndex = 5
    Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0,6)
    local confirmed = false
    local confirmTimer = nil
    resetBtn.MouseButton1Click:Connect(function()
        if not confirmed then
            confirmed = true
            resetBtn.Text = "SURE?"
            resetBtn.BackgroundColor3 = Color3.fromRGB(255,140,0)
            if confirmTimer then task.cancel(confirmTimer) end
            confirmTimer = task.delay(2, function()
                confirmed = false
                resetBtn.Text = "RESET"
                resetBtn.BackgroundColor3 = C_RED
            end)
        else
            confirmed = false
            if confirmTimer then task.cancel(confirmTimer) end
            resetBtn.Text = "RESET"
            resetBtn.BackgroundColor3 = C_RED
            if writefile then
                pcall(function() writefile("FXSHubConfig.json", "{}") end)
            end
            resetBtn.Text = "DONE!"
            resetBtn.BackgroundColor3 = Color3.fromRGB(50,180,50)
            task.delay(1.5, function()
                resetBtn.Text = "RESET"
                resetBtn.BackgroundColor3 = C_RED
            end)
        end
    end)
    resetBtn.MouseEnter:Connect(function()
        TweenService:Create(containerStroke, TweenInfo.new(0.15), {Transparency=0.3}):Play()
    end)
    resetBtn.MouseLeave:Connect(function()
        TweenService:Create(containerStroke, TweenInfo.new(0.15), {Transparency=0.8}):Play()
    end)
end
local function createGUIScaleRow(parent, order)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(1,0,0,42); container.BackgroundColor3 = C_CARD
    container.BorderSizePixel = 0; container.LayoutOrder = order; container.ZIndex = 3
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 8)
    local cStroke = Instance.new("UIStroke", container)
    cStroke.Color = C_PURPLE; cStroke.Thickness = 1; cStroke.Transparency = 0.8
    local label = Instance.new("TextLabel", container)
    label.Size = UDim2.new(0,90,1,0); label.Position = UDim2.new(0,10,0,0)
    label.BackgroundTransparency = 1; label.Text = "GUI Scale"; label.TextColor3 = C_WHITE
    label.Font = Enum.Font.GothamBold; label.TextSize = 13; label.TextXAlignment = Enum.TextXAlignment.Left; label.ZIndex = 4
    local leftArrow = Instance.new("TextButton", container)
    leftArrow.Size = UDim2.new(0,26,0,26); leftArrow.Position = UDim2.new(1,-120,0.5,-13)
    leftArrow.BackgroundColor3 = Color3.fromRGB(30,30,42); leftArrow.BorderSizePixel = 0
    leftArrow.Text = "◀"; leftArrow.TextColor3 = C_PURPLE; leftArrow.Font = Enum.Font.GothamBold; leftArrow.TextSize = 12; leftArrow.ZIndex = 5
    Instance.new("UICorner", leftArrow).CornerRadius = UDim.new(0, 6)
    local laStroke = Instance.new("UIStroke", leftArrow)
    laStroke.Color = C_PURPLE; laStroke.Thickness = 1; laStroke.Transparency = 0.5
    local valueBox = Instance.new("TextBox", container)
    valueBox.Size = UDim2.new(0,50,0,26); valueBox.Position = UDim2.new(1,-90,0.5,-13)
    valueBox.BackgroundColor3 = C_BG; valueBox.BorderSizePixel = 0
    valueBox.Text = tostring(math.floor(UI_SCALE*100+0.5)); valueBox.TextColor3 = C_WHITE
    valueBox.Font = Enum.Font.GothamBlack; valueBox.TextSize = 13; valueBox.TextXAlignment = Enum.TextXAlignment.Center; valueBox.ZIndex = 5
    Instance.new("UICorner", valueBox).CornerRadius = UDim.new(0, 6)
    local vbStroke = Instance.new("UIStroke", valueBox)
    vbStroke.Color = C_PURPLE; vbStroke.Thickness = 1; vbStroke.Transparency = 0.4
    local rightArrow = Instance.new("TextButton", container)
    rightArrow.Size = UDim2.new(0,26,0,26); rightArrow.Position = UDim2.new(1,-36,0.5,-13)
    rightArrow.BackgroundColor3 = Color3.fromRGB(30,30,42); rightArrow.BorderSizePixel = 0
    rightArrow.Text = "▶"; rightArrow.TextColor3 = C_PURPLE; rightArrow.Font = Enum.Font.GothamBold; rightArrow.TextSize = 12; rightArrow.ZIndex = 5
    Instance.new("UICorner", rightArrow).CornerRadius = UDim.new(0, 6)
    local raStroke = Instance.new("UIStroke", rightArrow)
    raStroke.Color = C_PURPLE; raStroke.Thickness = 1; raStroke.Transparency = 0.5
    local function getOrCreateScale(guiFrame)
        local existing = guiFrame:FindFirstChildOfClass("UIScale")
        if existing then return existing end
        local s = Instance.new("UIScale"); s.Scale = UI_SCALE; s.Parent = guiFrame; return s
    end
    local function applyScaleToAll(pct)
        pct = math.clamp(pct, 50, 100); UI_SCALE = pct / 100; valueBox.Text = tostring(pct)
        if main then TweenService:Create(getOrCreateScale(main), TweenInfo.new(0.18, Enum.EasingStyle.Quint), {Scale=UI_SCALE}):Play() end
        if mobileButtonContainer then TweenService:Create(getOrCreateScale(mobileButtonContainer), TweenInfo.new(0.18, Enum.EasingStyle.Quint), {Scale=UI_SCALE}):Play() end
        if apMain then TweenService:Create(getOrCreateScale(apMain), TweenInfo.new(0.18, Enum.EasingStyle.Quint), {Scale=UI_SCALE}):Play() end
        TweenService:Create(vbStroke, TweenInfo.new(0.1), {Transparency=0}):Play()
        task.delay(0.3, function() TweenService:Create(vbStroke, TweenInfo.new(0.2), {Transparency=0.4}):Play() end)
    end
    local function getCurrentPct() return math.clamp(math.floor(UI_SCALE*100+0.5), 50, 100) end
    leftArrow.MouseButton1Click:Connect(function() playTick(); applyScaleToAll(math.max(50, getCurrentPct()-5)) end)
    rightArrow.MouseButton1Click:Connect(function() playTick(); applyScaleToAll(math.min(100, getCurrentPct()+5)) end)
    valueBox.FocusLost:Connect(function()
        local n = tonumber(valueBox.Text)
        if n then applyScaleToAll(math.clamp(math.floor((n/5)+0.5)*5, 50, 100))
        else valueBox.Text = tostring(getCurrentPct()) end
    end)
    leftArrow.MouseEnter:Connect(function() TweenService:Create(leftArrow, TweenInfo.new(0.12), {BackgroundColor3=Color3.fromRGB(50,40,70)}):Play(); TweenService:Create(laStroke, TweenInfo.new(0.12), {Transparency=0}):Play() end)
    leftArrow.MouseLeave:Connect(function() TweenService:Create(leftArrow, TweenInfo.new(0.12), {BackgroundColor3=Color3.fromRGB(30,30,42)}):Play(); TweenService:Create(laStroke, TweenInfo.new(0.12), {Transparency=0.5}):Play() end)
    rightArrow.MouseEnter:Connect(function() TweenService:Create(rightArrow, TweenInfo.new(0.12), {BackgroundColor3=Color3.fromRGB(50,40,70)}):Play(); TweenService:Create(raStroke, TweenInfo.new(0.12), {Transparency=0}):Play() end)
    rightArrow.MouseLeave:Connect(function() TweenService:Create(rightArrow, TweenInfo.new(0.12), {BackgroundColor3=Color3.fromRGB(30,30,42)}):Play(); TweenService:Create(raStroke, TweenInfo.new(0.12), {Transparency=0.5}):Play() end)
    task.defer(function() valueBox.Text = tostring(math.clamp(math.floor(UI_SCALE*100+0.5), 50, 100)) end)
end
createGUIScaleRow(visualPage, O())
local userInfoBar = Instance.new("Frame", main)
userInfoBar.Size = UDim2.new(1,-20,0,70); userInfoBar.Position = UDim2.new(0,10,1,-80)
userInfoBar.BackgroundColor3 = C_CARD; userInfoBar.BorderSizePixel = 0; userInfoBar.ZIndex = 3
Instance.new("UICorner", userInfoBar).CornerRadius = UDim.new(0, 8)
local userStroke = Instance.new("UIStroke", userInfoBar)
userStroke.Color = C_PURPLE; userStroke.Thickness = 1; userStroke.Transparency = 0.8
local avatarImg = Instance.new("ImageLabel", userInfoBar)
avatarImg.Size = UDim2.new(0,50,0,50); avatarImg.Position = UDim2.new(0,10,0.5,-25)
avatarImg.BackgroundColor3 = C_BG; avatarImg.BorderSizePixel = 0
avatarImg.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="..LocalPlayer.UserId.."&width=150&height=150&format=png"
avatarImg.ZIndex = 4
Instance.new("UICorner", avatarImg).CornerRadius = UDim.new(1, 0)
local avatarStroke = Instance.new("UIStroke", avatarImg)
avatarStroke.Color = C_PURPLE; avatarStroke.Thickness = 2
local usernameLabel = Instance.new("TextLabel", userInfoBar)
usernameLabel.Size = UDim2.new(1,-140,0,22); usernameLabel.Position = UDim2.new(0,70,0,12)
usernameLabel.BackgroundTransparency = 1; usernameLabel.Text = LocalPlayer.Name; usernameLabel.TextColor3 = C_WHITE
usernameLabel.Font = Enum.Font.GothamBlack; usernameLabel.TextSize = 14; usernameLabel.TextXAlignment = Enum.TextXAlignment.Left
usernameLabel.TextTruncate = Enum.TextTruncate.AtEnd; usernameLabel.ZIndex = 4
local buyerBadge = Instance.new("Frame", userInfoBar)
buyerBadge.Size = UDim2.new(0,90,0,20); buyerBadge.Position = UDim2.new(0,70,0,38)
buyerBadge.BackgroundColor3 = C_BG; buyerBadge.BorderSizePixel = 0; buyerBadge.ZIndex = 4
Instance.new("UICorner", buyerBadge).CornerRadius = UDim.new(0, 10)
local badgeStroke = Instance.new("UIStroke", buyerBadge)
badgeStroke.Color = C_WHITE; badgeStroke.Thickness = 1
local whiteCircle = Instance.new("Frame", buyerBadge)
whiteCircle.Size = UDim2.new(0,8,0,8); whiteCircle.Position = UDim2.new(0,6,0.5,-4)
whiteCircle.BackgroundColor3 = C_WHITE; whiteCircle.BorderSizePixel = 0; whiteCircle.ZIndex = 5
Instance.new("UICorner", whiteCircle).CornerRadius = UDim.new(1, 0)
local badgeText = Instance.new("TextLabel", buyerBadge)
badgeText.Size = UDim2.new(1,-20,1,0); badgeText.Position = UDim2.new(0,18,0,0)
badgeText.BackgroundTransparency = 1; badgeText.Text = "FXS Buyer"; badgeText.TextColor3 = C_WHITE
badgeText.Font = Enum.Font.GothamBold; badgeText.TextSize = 10; badgeText.TextXAlignment = Enum.TextXAlignment.Left; badgeText.ZIndex = 5
local progressBar = Instance.new("Frame", gui)
progressBar.Size = isMobile and UDim2.new(0,280,0,55) or UDim2.new(0,500,0,65)
progressBar.Position = isMobile and UDim2.new(0.5,-140,1,-65) or UDim2.new(0.5,-250,1,-80)
progressBar.BackgroundColor3 = C_BG; progressBar.BorderSizePixel = 0; progressBar.Active = true; progressBar.ZIndex = 50
Instance.new("UICorner", progressBar).CornerRadius = UDim.new(0, 8)
local pbStroke = Instance.new("UIStroke", progressBar)
pbStroke.Color = C_PURPLE; pbStroke.Thickness = 1.5
do
    local drag, ds, sp = false
    progressBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            drag = true; ds = inp.Position; sp = progressBar.Position
            inp.Changed:Connect(function() if inp.UserInputState == Enum.UserInputState.End then drag = false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if drag and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - ds
            progressBar.Position = UDim2.new(sp.X.Scale, sp.X.Offset+d.X, sp.Y.Scale, sp.Y.Offset+d.Y)
        end
    end)
end
ProgressLabel = Instance.new("TextLabel", progressBar)
ProgressLabel.Size = UDim2.new(0.4,0,0,18); ProgressLabel.Position = UDim2.new(0,10,0,8)
ProgressLabel.BackgroundTransparency = 1; ProgressLabel.Text = "READY"; ProgressLabel.TextColor3 = C_PURPLE
ProgressLabel.Font = Enum.Font.GothamBlack; ProgressLabel.TextSize = isMobile and 10 or 13
ProgressLabel.TextXAlignment = Enum.TextXAlignment.Left; ProgressLabel.ZIndex = 51
ProgressPercentLabel = Instance.new("TextLabel", progressBar)
ProgressPercentLabel.Size = UDim2.new(1,-10,0,18); ProgressPercentLabel.Position = UDim2.new(0,0,0,8)
ProgressPercentLabel.BackgroundTransparency = 1; ProgressPercentLabel.Text = ""; ProgressPercentLabel.TextColor3 = C_WHITE
ProgressPercentLabel.Font = Enum.Font.GothamBlack; ProgressPercentLabel.TextSize = isMobile and 11 or 14
ProgressPercentLabel.TextXAlignment = Enum.TextXAlignment.Right; ProgressPercentLabel.ZIndex = 51
local radLbl = Instance.new("TextLabel", progressBar)
radLbl.Size = UDim2.new(0,50,0,14); radLbl.Position = UDim2.new(0,10,0,30)
radLbl.BackgroundTransparency = 1; radLbl.Text = "Radius:"; radLbl.TextColor3 = C_DIM
radLbl.Font = Enum.Font.Gotham; radLbl.TextSize = isMobile and 8 or 10; radLbl.TextXAlignment = Enum.TextXAlignment.Left; radLbl.ZIndex = 51
RadiusInput = Instance.new("TextBox", progressBar)
RadiusInput.Size = UDim2.new(0,50,0,20); RadiusInput.Position = UDim2.new(0,60,0,28)
RadiusInput.BackgroundColor3 = C_CARD; RadiusInput.BorderSizePixel = 0; RadiusInput.Text = tostring(Settings.StealRadius)
RadiusInput.TextColor3 = C_WHITE; RadiusInput.Font = Enum.Font.GothamBold; RadiusInput.TextSize = 10; RadiusInput.ZIndex = 51
Instance.new("UICorner", RadiusInput).CornerRadius = UDim.new(0, 5)
local rStr = Instance.new("UIStroke", RadiusInput)
rStr.Color = C_PURPLE; rStr.Thickness = 1; rStr.Transparency = 0.5
RadiusInput.FocusLost:Connect(function()
    local n = tonumber(RadiusInput.Text)
    if n then
        Settings.StealRadius = math.clamp(math.floor(n), 1, 500)
        Values.STEAL_RADIUS = Settings.StealRadius
        RadiusInput.Text = tostring(Settings.StealRadius)
        cachedPrompts = {}; promptCacheTime = 0
    end
end)
local pTrack = Instance.new("Frame", progressBar)
pTrack.Size = UDim2.new(1,-240,0,20); pTrack.Position = UDim2.new(0,120,0,28)
pTrack.BackgroundColor3 = C_SW_OFF; pTrack.BorderSizePixel = 0; pTrack.ZIndex = 50
Instance.new("UICorner", pTrack).CornerRadius = UDim.new(0, 5)
ProgressBarFill = Instance.new("Frame", pTrack)
ProgressBarFill.Size = UDim2.new(0,0,1,0); ProgressBarFill.BackgroundColor3 = C_PURPLE
ProgressBarFill.BorderSizePixel = 0; ProgressBarFill.ZIndex = 51
Instance.new("UICorner", ProgressBarFill).CornerRadius = UDim.new(0, 5)
local function handleKeybindAction(kc)
    if waitingForKey then return end
    if kc == Keybinds.UIToggle then
        main.Visible = not main.Visible
        if reopenBtn then reopenBtn.Visible = not main.Visible end
    end
    if kc == Keybinds.LaggerToggle then
        laggerToggled = not laggerToggled
        if laggerToggled and speedToggled then
            speedToggled = false
            if speedSwBg and speedSwCircle then
                TweenService:Create(speedSwBg, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3=C_SW_OFF}):Play()
                TweenService:Create(speedSwCircle, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Position=UDim2.new(0,2,0.5,-10)}):Play()
            end
            if sideSetters and sideSetters.carrySetter then sideSetters.carrySetter(false) end
        end
        if laggerSwBg and laggerSwCircle then
            TweenService:Create(laggerSwBg, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3=laggerToggled and C_PURPLE or C_SW_OFF}):Play()
            TweenService:Create(laggerSwCircle, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Position=laggerToggled and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10)}):Play()
        end
        if sideSetters and sideSetters.laggerSetter then sideSetters.laggerSetter(laggerToggled) end
    end
    if kc == Keybinds.SpeedToggle then
        speedToggled = not speedToggled
        if speedToggled and laggerToggled then
            laggerToggled = false
            if laggerSwBg and laggerSwCircle then
                TweenService:Create(laggerSwBg, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3=C_SW_OFF}):Play()
                TweenService:Create(laggerSwCircle, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Position=UDim2.new(0,2,0.5,-10)}):Play()
            end
            if sideSetters and sideSetters.laggerSetter then sideSetters.laggerSetter(false) end
        end
        if speedSwBg and speedSwCircle then
            TweenService:Create(speedSwBg, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3=speedToggled and C_PURPLE or C_SW_OFF}):Play()
            TweenService:Create(speedSwCircle, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Position=speedToggled and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10)}):Play()
        end
        if sideSetters and sideSetters.carrySetter then sideSetters.carrySetter(speedToggled) end
    end
    if kc == Keybinds.AutoBat then
        autoBatToggled = not autoBatToggled
        if batSwBg and batSwCircle then
            TweenService:Create(batSwBg, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3=autoBatToggled and C_PURPLE or C_SW_OFF}):Play()
            TweenService:Create(batSwCircle, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Position=autoBatToggled and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10)}):Play()
        end
    end
    if kc == Keybinds.InfiniteJump then
        Enabled.InfiniteJump = not Enabled.InfiniteJump
        if VisualSetters.InfiniteJump then VisualSetters.InfiniteJump(Enabled.InfiniteJump) end
        if Enabled.InfiniteJump then startInfiniteJump() else stopInfiniteJump() end
    end
    if kc == Keybinds.DropBrainrot then
        if setDropBrainrotVisual then setDropBrainrotVisual(true) end
        if dropMobileSetter then dropMobileSetter(true) end
        task.spawn(runDropBrainrot)
    end
    if kc == Keybinds.FloatToggle then
        floatEnabled = not floatEnabled
        if setFloatVisual then setFloatVisual(floatEnabled) end
        if floatEnabled then startFloat() else stopFloat() end
    end
    if kc == Keybinds.FullAutoLeft then
        fullAutoPlayLeftEnabled = not fullAutoPlayLeftEnabled
        if fullAutoLeftSetter then fullAutoLeftSetter(fullAutoPlayLeftEnabled) end
        if fullAutoPlayLeftEnabled then startFullAutoLeft() else stopFullAutoLeft() end
    end
    if kc == Keybinds.TPDown then
        runTPDown()
    end
end

local CONTROLLER_MAP = {
    [Enum.KeyCode.ButtonA]      = Keybinds.DropBrainrot,
    [Enum.KeyCode.ButtonB]      = Keybinds.FloatToggle,
    [Enum.KeyCode.ButtonX]      = Keybinds.FullAutoLeft,
    [Enum.KeyCode.ButtonY]      = Keybinds.AutoBat,
    [Enum.KeyCode.ButtonL1]     = Keybinds.SpeedToggle,
    [Enum.KeyCode.ButtonR1]     = Keybinds.LaggerToggle,
    [Enum.KeyCode.ButtonL2]     = Keybinds.TPDown,
    [Enum.KeyCode.ButtonR2]     = Keybinds.InfiniteJump,
    [Enum.KeyCode.ButtonStart]  = Keybinds.UIToggle,
    [Enum.KeyCode.DPadUp]       = Keybinds.FullAutoLeft,
    [Enum.KeyCode.DPadDown]     = Keybinds.TPDown,
    [Enum.KeyCode.DPadLeft]     = Keybinds.AutoBat,
    [Enum.KeyCode.DPadRight]    = Keybinds.SpeedToggle,
}

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        handleKeybindAction(input.KeyCode)
        --if input.KeyCode == Enum.KeyCode.Space then GX.spaceHeld = true end
    elseif input.UserInputType == Enum.UserInputType.Gamepad1 or input.UserInputType == Enum.UserInputType.Gamepad2 then
        local mapped = CONTROLLER_MAP[input.KeyCode]
        if mapped then
            handleKeybindAction(mapped)
        else
            handleKeybindAction(input.KeyCode)
        end
    end
end)

RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character; if not char then return end
    local localH = char:FindFirstChildOfClass("Humanoid")
    local localHRP = char:FindFirstChild("HumanoidRootPart")
    if not localH or not localHRP then return end
    h = localH; hrp = localHRP
    local md = localH.MoveDirection
    local spd = laggerToggled and LAGGER_SPEED or (speedToggled and CARRY_SPEED or NORMAL_SPEED)
    if md.Magnitude > 0 then
        localHRP.AssemblyLinearVelocity = Vector3.new(md.X*spd, localHRP.AssemblyLinearVelocity.Y, md.Z*spd)
    end
    if speedLbl then
        speedLbl.Text = "Speed: " .. string.format("%.1f", Vector3.new(localHRP.AssemblyLinearVelocity.X, 0, localHRP.AssemblyLinearVelocity.Z).Magnitude)
    end
end)
task.spawn(function()
    task.wait(2)
    if Enabled.AutoSteal then startAutoSteal() end
    if Enabled.AntiRagdoll then startAntiRagdoll() end
    if Enabled.InfiniteJump then
        if VisualSetters.InfiniteJump then VisualSetters.InfiniteJump(true) end
        startInfiniteJump()
    end
    if Enabled.Unwalk then startUnwalk() end
    if Enabled.Optimizer then enableOptimizer() end
    if ultraModeEnabled then enableUltraMode() end
    if Enabled.RemoveAccessories then startRemoveAccessories() end
    local cam = workspace.CurrentCamera
    if cam then cam.FieldOfView = FOV_VALUE end
end)
local function setupChar(char)
    h = char:WaitForChild("Humanoid")
    hrp = char:WaitForChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    lastKnownHealth = h and h.Health or 100
    if medusaCounterEnabled then setupMedusaCounter(char) end
    if harderHitAnimEnabled then task.wait(0.3); saveOriginalAnims(char); applyAnimPack(char) end
    if head then
        local bb = Instance.new("BillboardGui", head)
        bb.Size = UDim2.new(0,160,0,28); bb.StudsOffset = Vector3.new(0,3,0); bb.AlwaysOnTop = true
        speedLbl = Instance.new("TextLabel", bb)
        speedLbl.Size = UDim2.new(1,0,1,0); speedLbl.BackgroundTransparency = 1
        speedLbl.TextColor3 = C_PURPLE; speedLbl.Font = Enum.Font.GothamBold; speedLbl.TextScaled = true
    end
end
LocalPlayer.CharacterAdded:Connect(setupChar)
if LocalPlayer.Character then setupChar(LocalPlayer.Character) end
mobileButtonContainer = Instance.new("Frame", gui)
mobileButtonContainer.Size = UDim2.new(0,160,0,290)
mobileButtonContainer.Position = UDim2.new(1,-170,0.5,-107)
mobileButtonContainer.BackgroundColor3 = C_BG; mobileButtonContainer.BackgroundTransparency = 0.3
mobileButtonContainer.BorderSizePixel = 0; mobileButtonContainer.Active = true; mobileButtonContainer.ZIndex = 100
Instance.new("UICorner", mobileButtonContainer).CornerRadius = UDim.new(0, 12)
local containerStroke = Instance.new("UIStroke", mobileButtonContainer)
containerStroke.Color = C_PURPLE; containerStroke.Thickness = 2; containerStroke.Transparency = 0.5
do
    local drag, ds, sp = false
    mobileButtonContainer.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            drag = true; ds = inp.Position; sp = mobileButtonContainer.Position
            inp.Changed:Connect(function() if inp.UserInputState == Enum.UserInputState.End then drag = false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if drag and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - ds
            mobileButtonContainer.Position = UDim2.new(sp.X.Scale, sp.X.Offset+d.X, sp.Y.Scale, sp.Y.Offset+d.Y)
        end
    end)
end
local function createMobileButton(text, row, col, callback)
    local btn = Instance.new("TextButton", mobileButtonContainer)
    btn.Size = UDim2.new(0,70,0,65)
    btn.Position = UDim2.new(0,(col-1)*80+5,0,(row-1)*70+5)
    btn.BackgroundColor3 = C_CARD; btn.BorderSizePixel = 0; btn.Text = ""; btn.ZIndex = 101
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    local btnStroke = Instance.new("UIStroke", btn)
    btnStroke.Color = C_PURPLE; btnStroke.Thickness = 2; btnStroke.Transparency = 0.5
    local label = Instance.new("TextLabel", btn)
    label.Size = UDim2.new(1,0,0,25); label.Position = UDim2.new(0,0,0,8)
    label.BackgroundTransparency = 1; label.Text = text; label.TextColor3 = C_WHITE
    label.Font = Enum.Font.GothamBlack; label.TextSize = 11; label.ZIndex = 102
    local modeText = Instance.new("TextLabel", btn)
    modeText.Size = UDim2.new(1,0,0,12); modeText.Position = UDim2.new(0,0,0,30)
    modeText.BackgroundTransparency = 1; modeText.Text = "MODE"; modeText.TextColor3 = C_DIM
    modeText.Font = Enum.Font.GothamBold; modeText.TextSize = 8; modeText.ZIndex = 102
    local circle = Instance.new("Frame", btn)
    circle.Size = UDim2.new(0,14,0,14); circle.Position = UDim2.new(0.5,-7,1,-18)
    circle.BackgroundColor3 = C_BG; circle.BorderSizePixel = 0; circle.ZIndex = 102
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)
    local circleStroke = Instance.new("UIStroke", circle)
    circleStroke.Color = C_WHITE; circleStroke.Thickness = 2
    local circleFill = Instance.new("Frame", circle)
    circleFill.Size = UDim2.new(0,0,0,0); circleFill.Position = UDim2.new(0.5,0,0.5,0)
    circleFill.AnchorPoint = Vector2.new(0.5,0.5); circleFill.BackgroundColor3 = C_WHITE
    circleFill.BorderSizePixel = 0; circleFill.ZIndex = 103
    Instance.new("UICorner", circleFill).CornerRadius = UDim.new(1, 0)
    local isActive = false
    local function setVisual(state)
        isActive = state
        TweenService:Create(circleFill, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Size=isActive and UDim2.new(1,-4,1,-4) or UDim2.new(0,0,0,0)}):Play()
        TweenService:Create(btnStroke, TweenInfo.new(0.2), {Transparency=isActive and 0 or 0.5}):Play()
    end
    btn.MouseButton1Click:Connect(function()
        playTick(); isActive = not isActive; setVisual(isActive)
        if callback then callback(isActive) end
    end)
    btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3=Color3.fromRGB(25,25,35)}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3=C_CARD}):Play() end)
    return setVisual
end
local batSetter = createMobileButton("BAT", 1, 1, function(on)
    autoBatToggled = on
    if batSwBg and batSwCircle then
        TweenService:Create(batSwBg, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3=on and C_PURPLE or C_SW_OFF}):Play()
        TweenService:Create(batSwCircle, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Position=on and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10)}):Play()
    end
end)
local carrySetter = createMobileButton("CARRY", 1, 2, function(on)
    if on and laggerToggled then
        laggerToggled = false
        if laggerSwBg and laggerSwCircle then
            TweenService:Create(laggerSwBg, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3=C_SW_OFF}):Play()
            TweenService:Create(laggerSwCircle, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Position=UDim2.new(0,2,0.5,-10)}):Play()
        end
        if laggerSetter then laggerSetter(false) end
    end
    speedToggled = on
    if speedSwBg and speedSwCircle then
        TweenService:Create(speedSwBg, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3=on and C_PURPLE or C_SW_OFF}):Play()
        TweenService:Create(speedSwCircle, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Position=on and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10)}):Play()
    end
end)
local floatMobileSetter = createMobileButton("FLOAT", 2, 2, function(on)
    floatEnabled = on
    if on then startFloat() else stopFloat() end
end)
local dropMobileSetter = createMobileButton("DROP", 4, 1, function(on)
    if on then
        if setDropBrainrotVisual then setDropBrainrotVisual(true) end
        task.spawn(runDropBrainrot)
    end
end)
fullAutoLeftSetter = createMobileButton("FULL\nAUTO L", 3, 1, function(on)
    fullAutoPlayLeftEnabled = on
    if on then startFullAutoLeft() else stopFullAutoLeft() end
end)
fullAutoRightSetter = createMobileButton("FULL\nAUTO R", 3, 2, function(on)
    fullAutoPlayRightEnabled = on
    if on then startFullAutoRight() else stopFullAutoRight() end
end)
local laggerSetter = createMobileButton("LAG", 2, 1, function(on)
    if on and speedToggled then
        speedToggled = false
        if speedSwBg and speedSwCircle then
            TweenService:Create(speedSwBg, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3=C_SW_OFF}):Play()
            TweenService:Create(speedSwCircle, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Position=UDim2.new(0,2,0.5,-10)}):Play()
        end
        if carrySetter then carrySetter(false) end
    end
    laggerToggled = on
    if laggerSwBg and laggerSwCircle then
        TweenService:Create(laggerSwBg, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3=on and C_PURPLE or C_SW_OFF}):Play()
        TweenService:Create(laggerSwCircle, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Position=on and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10)}):Play()
    end
end)
sideSetters = {batSetter=batSetter, carrySetter=carrySetter, laggerSetter=laggerSetter}
task.spawn(function()
    task.wait(1)
    batSetter(autoBatToggled)
    carrySetter(speedToggled)
    laggerSetter(laggerToggled)
    floatMobileSetter(floatEnabled)
end)
print("✓ FXS Hub - Clean Purple/Red UI loaded")
end)()
;(function()
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local HttpService=game:GetService("HttpService")
local LocalPlayer=Players.LocalPlayer
local AP_NORMAL_SPEED = 60
local AP_Keybinds = {
    AutoLeft=Enum.KeyCode.Z,AutoRight=Enum.KeyCode.C,UIToggle=Enum.KeyCode.P,
    FullAutoLeft=Enum.KeyCode.G,FullAutoRight=Enum.KeyCode.H,
}
local SAVE_FILE = "AutoPlayConfig.json"
local function apSaveConfig()
    pcall(function()
        if not writefile then return end
        writefile(SAVE_FILE, HttpService:JSONEncode({
            speed=AP_NORMAL_SPEED,
            autoLeft=AP_Keybinds.AutoLeft.Name,autoRight=AP_Keybinds.AutoRight.Name,
            uiToggle=AP_Keybinds.UIToggle.Name,fullAutoLeft=AP_Keybinds.FullAutoLeft.Name,
            fullAutoRight=AP_Keybinds.FullAutoRight.Name,
        }))
    end)
end
local function apLoadConfig()
    pcall(function()
        if not (isfile and isfile(SAVE_FILE)) then return end
        local ok,cfg=pcall(function() return HttpService:JSONDecode(readfile(SAVE_FILE)) end)
        if not ok or not cfg then return end
        if cfg.speed then AP_NORMAL_SPEED=math.clamp(tonumber(cfg.speed) or 60,1,9999) end
        if cfg.autoLeft     and Enum.KeyCode[cfg.autoLeft]     then AP_Keybinds.AutoLeft=Enum.KeyCode[cfg.autoLeft]         end
        if cfg.autoRight    and Enum.KeyCode[cfg.autoRight]    then AP_Keybinds.AutoRight=Enum.KeyCode[cfg.autoRight]       end
        if cfg.uiToggle     and Enum.KeyCode[cfg.uiToggle]     then AP_Keybinds.UIToggle=Enum.KeyCode[cfg.uiToggle]         end
        if cfg.fullAutoLeft and Enum.KeyCode[cfg.fullAutoLeft] then AP_Keybinds.FullAutoLeft=Enum.KeyCode[cfg.fullAutoLeft] end
        if cfg.fullAutoRight and Enum.KeyCode[cfg.fullAutoRight] then AP_Keybinds.FullAutoRight=Enum.KeyCode[cfg.fullAutoRight] end
    end)
end
apLoadConfig()
local AP_L1=Vector3.new(-476.48,-6.28,92.73)
local AP_L2=Vector3.new(-483.12,-4.95,94.80)
local AP_R1=Vector3.new(-476.16,-6.52,25.62)
local AP_R2=Vector3.new(-483.06,-5.03,25.48)
local AP_LeftOn=false
local AP_RightOn=false
local AP_LeftConn=nil
local AP_RightConn=nil
local AP_LeftPhase=1
local AP_RightPhase=1
local AP_WaitingForKey=nil
local AP_SetLeftVisual=nil
local AP_SetRightVisual=nil
local AP_C_BG=Color3.fromRGB(15,15,20)
local AP_C_CARD=Color3.fromRGB(20,20,28)
local AP_C_PURPLE=Color3.fromRGB(147,112,219)
local AP_C_RED=Color3.fromRGB(220,60,85)
local AP_C_DIM=Color3.fromRGB(140,140,150)
local AP_C_SW_OFF=Color3.fromRGB(40,40,50)
local AP_C_WHITE=Color3.fromRGB(255,255,255)
local function apGetKeyDisplayName(kc)
    local name=kc.Name
    local gpMap={ButtonA="A",ButtonB="B",ButtonX="X",ButtonY="Y",ButtonL1="L1",ButtonL2="L2",ButtonL3="L3",ButtonR1="R1",ButtonR2="R2",ButtonR3="R3",ButtonStart="Start",ButtonSelect="Select",DPadLeft="D←",DPadRight="D→",DPadUp="D↑",DPadDown="D↓",ButtonSquare="□",ButtonTriangle="△",ButtonCircle="○",ButtonCross="✕"}
    return gpMap[name] or name
end
RunService.RenderStepped:Connect(function()
    local char=LocalPlayer.Character; if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart")
    local hum=char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    local md=hum.MoveDirection
    if md.Magnitude>0 then
        hrp.AssemblyLinearVelocity=Vector3.new(md.X*AP_NORMAL_SPEED,hrp.AssemblyLinearVelocity.Y,md.Z*AP_NORMAL_SPEED)
    end
end)
local function AP_FaceSouth()
    local c=LocalPlayer.Character; if not c then return end
    local rp=c:FindFirstChild("HumanoidRootPart"); if not rp then return end
    rp.CFrame=CFrame.new(rp.Position)*CFrame.Angles(0,0,0)
    local cam=workspace.CurrentCamera
    if cam then local cp=rp.Position; cam.CFrame=CFrame.new(cp.X,cp.Y+5,cp.Z-12)*CFrame.Angles(math.rad(-15),0,0) end
end
local function AP_FaceNorth()
    local c=LocalPlayer.Character; if not c then return end
    local rp=c:FindFirstChild("HumanoidRootPart"); if not rp then return end
    rp.CFrame=CFrame.new(rp.Position)*CFrame.Angles(0,math.rad(180),0)
    local cam=workspace.CurrentCamera
    if cam then local cp=rp.Position; cam.CFrame=CFrame.new(cp.X,cp.Y+2,cp.Z+12)*CFrame.Angles(0,math.rad(180),0) end
end
local function AP_StartLeft()
    if AP_LeftConn then AP_LeftConn:Disconnect() end
    AP_LeftPhase=1
    AP_LeftConn=RunService.Heartbeat:Connect(function()
        if not AP_LeftOn then return end
        local c=LocalPlayer.Character; if not c then return end
        local rp=c:FindFirstChild("HumanoidRootPart")
        local hum=c:FindFirstChildOfClass("Humanoid")
        if not rp or not hum then return end
        local spd=AP_NORMAL_SPEED
        if AP_LeftPhase==1 then
            local tgt=Vector3.new(AP_L1.X,rp.Position.Y,AP_L1.Z)
            if (tgt-rp.Position).Magnitude<1 then
                AP_LeftPhase=2
                local d=AP_L2-rp.Position; local mv=Vector3.new(d.X,0,d.Z).Unit
                hum:Move(mv,false); rp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,rp.AssemblyLinearVelocity.Y,mv.Z*spd); return
            end
            local d=AP_L1-rp.Position; local mv=Vector3.new(d.X,0,d.Z).Unit
            hum:Move(mv,false); rp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,rp.AssemblyLinearVelocity.Y,mv.Z*spd)
        elseif AP_LeftPhase==2 then
            local tgt=Vector3.new(AP_L2.X,rp.Position.Y,AP_L2.Z)
            if (tgt-rp.Position).Magnitude<1 then
                hum:Move(Vector3.zero,false); rp.AssemblyLinearVelocity=Vector3.zero
                AP_LeftOn=false
                if AP_LeftConn then AP_LeftConn:Disconnect(); AP_LeftConn=nil end
                AP_LeftPhase=1
                if AP_SetLeftVisual then AP_SetLeftVisual(false) end
                AP_FaceSouth(); return
            end
            local d=AP_L2-rp.Position; local mv=Vector3.new(d.X,0,d.Z).Unit
            hum:Move(mv,false); rp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,rp.AssemblyLinearVelocity.Y,mv.Z*spd)
        end
    end)
end
local function AP_StopLeft()
    if AP_LeftConn then AP_LeftConn:Disconnect(); AP_LeftConn=nil end
    AP_LeftPhase=1
    local c=LocalPlayer.Character
    if c then local hum=c:FindFirstChildOfClass("Humanoid"); if hum then hum:Move(Vector3.zero,false) end end
end
local function AP_StartRight()
    if AP_RightConn then AP_RightConn:Disconnect() end
    AP_RightPhase=1
    AP_RightConn=RunService.Heartbeat:Connect(function()
        if not AP_RightOn then return end
        local c=LocalPlayer.Character; if not c then return end
        local rp=c:FindFirstChild("HumanoidRootPart")
        local hum=c:FindFirstChildOfClass("Humanoid")
        if not rp or not hum then return end
        local spd=AP_NORMAL_SPEED
        if AP_RightPhase==1 then
            local tgt=Vector3.new(AP_R1.X,rp.Position.Y,AP_R1.Z)
            if (tgt-rp.Position).Magnitude<1 then
                AP_RightPhase=2
                local d=AP_R2-rp.Position; local mv=Vector3.new(d.X,0,d.Z).Unit
                hum:Move(mv,false); rp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,rp.AssemblyLinearVelocity.Y,mv.Z*spd); return
            end
            local d=AP_R1-rp.Position; local mv=Vector3.new(d.X,0,d.Z).Unit
            hum:Move(mv,false); rp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,rp.AssemblyLinearVelocity.Y,mv.Z*spd)
        elseif AP_RightPhase==2 then
            local tgt=Vector3.new(AP_R2.X,rp.Position.Y,AP_R2.Z)
            if (tgt-rp.Position).Magnitude<1 then
                hum:Move(Vector3.zero,false); rp.AssemblyLinearVelocity=Vector3.zero
                AP_RightOn=false
                if AP_RightConn then AP_RightConn:Disconnect(); AP_RightConn=nil end
                AP_RightPhase=1
                if AP_SetRightVisual then AP_SetRightVisual(false) end
                AP_FaceNorth(); return
            end
            local d=AP_R2-rp.Position; local mv=Vector3.new(d.X,0,d.Z).Unit
            hum:Move(mv,false); rp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,rp.AssemblyLinearVelocity.Y,mv.Z*spd)
        end
    end)
end
local function AP_StopRight()
    if AP_RightConn then AP_RightConn:Disconnect(); AP_RightConn=nil end
    AP_RightPhase=1
    local c=LocalPlayer.Character
    if c then local hum=c:FindFirstChildOfClass("Humanoid"); if hum then hum:Move(Vector3.zero,false) end end
end
local apGui=Instance.new("ScreenGui")
apGui.Name="AutoPlayGUI"; apGui.ResetOnSpawn=false; apGui.DisplayOrder=10
apGui.Parent=LocalPlayer:WaitForChild("PlayerGui")
apMain=Instance.new("Frame")
apMain.Name="Main"
apMain.Size=getMobileOptimized(UDim2.new(0,320,0,440),UDim2.new(0,280,0,380))
apMain.Position=getMobileOptimized(UDim2.new(0.5,-160,0.5,-220),UDim2.new(0.5,-140,0.5,-190))
apMain.BackgroundColor3=AP_C_BG; apMain.BackgroundTransparency=0
apMain.BorderSizePixel=0; apMain.Active=true; apMain.ClipsDescendants=true
apMain.Parent=apGui
Instance.new("UICorner",apMain).CornerRadius=UDim.new(0,12)
local apStroke=Instance.new("UIStroke",apMain); apStroke.Color=AP_C_PURPLE; apStroke.Thickness=1.5
do
    local drag=false; local ds,sp
    apMain.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
            drag=true; ds=inp.Position; sp=apMain.Position
            inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then drag=false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if drag and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then
            local d=inp.Position-ds
            apMain.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
        end
    end)
end
local apHeader=Instance.new("Frame",apMain)
apHeader.Size=UDim2.new(1,0,0,45); apHeader.BackgroundColor3=AP_C_CARD
apHeader.BorderSizePixel=0; apHeader.ZIndex=4
Instance.new("UICorner",apHeader).CornerRadius=UDim.new(0,12)
local apHFix=Instance.new("Frame",apHeader); apHFix.Size=UDim2.new(1,0,0,12); apHFix.Position=UDim2.new(0,0,1,-12)
apHFix.BackgroundColor3=AP_C_CARD; apHFix.BorderSizePixel=0; apHFix.ZIndex=3
local apTitle=Instance.new("TextLabel",apHeader)
apTitle.Size=UDim2.new(1,-100,1,0); apTitle.Position=UDim2.new(0,15,0,0)
apTitle.BackgroundTransparency=1; apTitle.Text="discord.gg/ZuW2d7dd"; apTitle.TextColor3=AP_C_WHITE
apTitle.Font=Enum.Font.GothamBold; apTitle.TextSize=16; apTitle.TextXAlignment=Enum.TextXAlignment.Left; apTitle.ZIndex=6
local apClose=Instance.new("TextButton",apHeader)
apClose.Size=UDim2.new(0,35,0,35); apClose.Position=UDim2.new(1,-40,0,5)
apClose.BackgroundColor3=AP_C_RED; apClose.BorderSizePixel=0
apClose.Text="×"; apClose.TextColor3=AP_C_WHITE
apClose.Font=Enum.Font.GothamBold; apClose.TextSize=24; apClose.ZIndex=8
Instance.new("UICorner",apClose).CornerRadius=UDim.new(0,8)
local apReopenBtn=Instance.new("TextButton",apGui)
apReopenBtn.Size=getMobileOptimized(UDim2.new(0,45,0,45),UDim2.new(0,40,0,40))
apReopenBtn.Position=getMobileOptimized(UDim2.new(0.5,-22.5,0.5,-22.5),UDim2.new(0.5,-20,0.5,-20))
apReopenBtn.BackgroundColor3=AP_C_PURPLE; apReopenBtn.BackgroundTransparency=0
apReopenBtn.BorderSizePixel=0; apReopenBtn.Text="AP"; apReopenBtn.TextColor3=AP_C_WHITE
apReopenBtn.Font=Enum.Font.GothamBlack; apReopenBtn.TextSize=14; apReopenBtn.ZIndex=20; apReopenBtn.Visible=false
Instance.new("UICorner",apReopenBtn).CornerRadius=UDim.new(0,10)
apClose.MouseButton1Click:Connect(function() apMain.Visible=false; apReopenBtn.Visible=true end)
apReopenBtn.MouseButton1Click:Connect(function() apMain.Visible=true; apReopenBtn.Visible=false end)
apClose.MouseEnter:Connect(function() TweenService:Create(apClose,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(255,80,100)}):Play() end)
apClose.MouseLeave:Connect(function() TweenService:Create(apClose,TweenInfo.new(0.15),{BackgroundColor3=AP_C_RED}):Play() end)
apReopenBtn.MouseEnter:Connect(function() TweenService:Create(apReopenBtn,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(106,76,170)}):Play() end)
apReopenBtn.MouseLeave:Connect(function() TweenService:Create(apReopenBtn,TweenInfo.new(0.15),{BackgroundColor3=AP_C_PURPLE}):Play() end)
local function apFlashSaved()
    apSavedLbl.TextTransparency=0
    task.delay(1.2,function() TweenService:Create(apSavedLbl,TweenInfo.new(0.5),{TextTransparency=1}):Play() end)
end
local apScroll=Instance.new("ScrollingFrame",apMain)
apScroll.Size=UDim2.new(1,-20,1,-55); apScroll.Position=UDim2.new(0,10,0,50)
apScroll.BackgroundTransparency=1; apScroll.BorderSizePixel=0; apScroll.ScrollBarThickness=3
apScroll.ScrollBarImageColor3=AP_C_PURPLE; apScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
apScroll.CanvasSize=UDim2.new(0,0,0,0); apScroll.ZIndex=2; apScroll.ScrollingEnabled=true
local apVstack=Instance.new("Frame",apScroll)
apVstack.Size=UDim2.new(1,0,0,0); apVstack.AutomaticSize=Enum.AutomaticSize.Y
apVstack.BackgroundTransparency=1; apVstack.BorderSizePixel=0
local apLayout=Instance.new("UIListLayout",apVstack)
apLayout.SortOrder=Enum.SortOrder.LayoutOrder; apLayout.Padding=UDim.new(0,0)
local apOrder=0
local function APO() apOrder=apOrder+1; return apOrder end
local function apSectionLbl(txt)
    local f=Instance.new("Frame",apVstack)
    f.Size=UDim2.new(1,0,0,30); f.BackgroundTransparency=1; f.BorderSizePixel=0; f.LayoutOrder=APO()
    local l=Instance.new("TextLabel",f)
    l.Size=UDim2.new(1,0,1,0); l.BackgroundTransparency=1; l.Text=txt:upper()
    l.TextColor3=AP_C_PURPLE; l.Font=Enum.Font.GothamBold; l.TextSize=11
    l.TextXAlignment=Enum.TextXAlignment.Left; l.ZIndex=4
    local line=Instance.new("Frame",f)
    line.Size=UDim2.new(1,0,0,1); line.Position=UDim2.new(0,0,1,0)
    line.BackgroundColor3=AP_C_PURPLE; line.BackgroundTransparency=0.7; line.BorderSizePixel=0; line.ZIndex=3
end
local function apMakeToggleRow(keybindName,labelTxt,onToggle)
    local container=Instance.new("Frame",apVstack)
    container.Size=UDim2.new(1,0,0,42); container.BackgroundColor3=AP_C_CARD
    container.BorderSizePixel=0; container.LayoutOrder=APO(); container.ZIndex=3
    Instance.new("UICorner",container).CornerRadius=UDim.new(0,8)
    local containerStroke=Instance.new("UIStroke",container)
    containerStroke.Color=AP_C_PURPLE; containerStroke.Thickness=1; containerStroke.Transparency=0.8
    local kbBox=Instance.new("Frame",container)
    kbBox.Size=UDim2.new(0,28,0,20); kbBox.Position=UDim2.new(0,10,0.5,-10)
    kbBox.BackgroundColor3=AP_C_PURPLE; kbBox.BackgroundTransparency=0.3; kbBox.BorderSizePixel=0; kbBox.ZIndex=5
    Instance.new("UICorner",kbBox).CornerRadius=UDim.new(0,6)
    local kbTxt=Instance.new("TextLabel",kbBox)
    kbTxt.Size=UDim2.new(1,0,1,0); kbTxt.BackgroundTransparency=1
    kbTxt.Text=apGetKeyDisplayName(AP_Keybinds[keybindName])
    kbTxt.TextColor3=AP_C_WHITE; kbTxt.Font=Enum.Font.GothamBold; kbTxt.TextSize=10
    kbTxt.TextXAlignment=Enum.TextXAlignment.Center; kbTxt.ZIndex=6
    local nameLbl=Instance.new("TextLabel",container)
    nameLbl.Size=UDim2.new(1,-120,1,0); nameLbl.Position=UDim2.new(0,45,0,0)
    nameLbl.BackgroundTransparency=1; nameLbl.Text=labelTxt; nameLbl.TextColor3=AP_C_WHITE
    nameLbl.Font=Enum.Font.GothamBold; nameLbl.TextSize=13; nameLbl.TextXAlignment=Enum.TextXAlignment.Left; nameLbl.ZIndex=5
    local swBg=Instance.new("Frame",container)
    swBg.Size=UDim2.new(0,48,0,24); swBg.Position=UDim2.new(1,-58,0.5,-12)
    swBg.BackgroundColor3=AP_C_SW_OFF; swBg.BorderSizePixel=0; swBg.ZIndex=5
    Instance.new("UICorner",swBg).CornerRadius=UDim.new(1,0)
    local swCircle=Instance.new("Frame",swBg)
    swCircle.Size=UDim2.new(0,20,0,20); swCircle.Position=UDim2.new(0,2,0.5,-10)
    swCircle.BackgroundColor3=Color3.fromRGB(0,0,0); swCircle.BorderSizePixel=0; swCircle.ZIndex=6
    Instance.new("UICorner",swCircle).CornerRadius=UDim.new(1,0)
    local isOn=false
    local function setVisual(state)
        isOn=state
        TweenService:Create(swBg,TweenInfo.new(0.2,Enum.EasingStyle.Quint),{BackgroundColor3=isOn and AP_C_PURPLE or AP_C_SW_OFF}):Play()
        TweenService:Create(swCircle,TweenInfo.new(0.2,Enum.EasingStyle.Back),{Position=isOn and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10)}):Play()
    end
    local isHolding=false
    local holdStartTime=0
    local function startKeybindChange()
        AP_WaitingForKey=kbBox; kbTxt.Text="..."
        TweenService:Create(kbBox,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(255,180,100),BackgroundTransparency=0}):Play()
        local conn
        conn=UserInputService.InputBegan:Connect(function(inp,gpe)
            if AP_WaitingForKey~=kbBox then conn:Disconnect(); return end
            local isKeyboard=inp.UserInputType==Enum.UserInputType.Keyboard
            local isGamepad=inp.UserInputType==Enum.UserInputType.Gamepad1 or inp.UserInputType==Enum.UserInputType.Gamepad2
            if not (isKeyboard or isGamepad) then return end
            local kc=inp.KeyCode
            if isKeyboard and kc==Enum.KeyCode.Escape then
                kbTxt.Text=apGetKeyDisplayName(AP_Keybinds[keybindName])
                TweenService:Create(kbBox,TweenInfo.new(0.15),{BackgroundColor3=AP_C_PURPLE,BackgroundTransparency=0.3}):Play()
                AP_WaitingForKey=nil; conn:Disconnect(); return
            end
            if kc==Enum.KeyCode.Unknown then return end
            AP_Keybinds[keybindName]=kc
            if Keybinds and Keybinds[keybindName] then Keybinds[keybindName]=kc end
            kbTxt.Text=apGetKeyDisplayName(kc)
            TweenService:Create(kbBox,TweenInfo.new(0.15),{BackgroundColor3=AP_C_PURPLE,BackgroundTransparency=0.3}):Play()
            AP_WaitingForKey=nil; conn:Disconnect()
            apSaveConfig()
        end)
    end
    local clk=Instance.new("TextButton",container)
    clk.Size=UDim2.new(1,0,1,0); clk.BackgroundTransparency=1; clk.Text=""; clk.ZIndex=7
    clk.MouseButton1Click:Connect(function()
        if not isHolding then isOn=not isOn; setVisual(isOn); if onToggle then onToggle(isOn) end end
        isHolding=false; holdStartTime=0
    end)
    clk.MouseButton2Click:Connect(function() startKeybindChange() end)
    clk.MouseButton1Down:Connect(function()
        isHolding=false; holdStartTime=tick()
        task.delay(0.6,function()
            if holdStartTime>0 and (tick()-holdStartTime)>=0.6 then isHolding=true; startKeybindChange() end
        end)
    end)
    clk.MouseButton1Up:Connect(function()
        if (tick()-holdStartTime)<0.6 then holdStartTime=0 end
    end)
    clk.MouseEnter:Connect(function()
        TweenService:Create(containerStroke,TweenInfo.new(0.15),{Transparency=0.3}):Play()
        TweenService:Create(container,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(25,25,35)}):Play()
    end)
    clk.MouseLeave:Connect(function()
        TweenService:Create(containerStroke,TweenInfo.new(0.15),{Transparency=0.8}):Play()
        TweenService:Create(container,TweenInfo.new(0.15),{BackgroundColor3=AP_C_CARD}):Play()
    end)
    return setVisual,kbTxt
end
local function apMakeKeybindRow(lbl,keybindName,kbBadgeRef)
    local wrap=Instance.new("Frame",apVstack)
    wrap.Size=UDim2.new(1,0,0,42); wrap.BackgroundColor3=AP_C_CARD; wrap.BorderSizePixel=0; wrap.ZIndex=3; wrap.LayoutOrder=APO()
    Instance.new("UICorner",wrap).CornerRadius=UDim.new(0,8)
    local wrapStroke=Instance.new("UIStroke",wrap)
    wrapStroke.Color=AP_C_PURPLE; wrapStroke.Thickness=1; wrapStroke.Transparency=0.8
    local lbTxt=Instance.new("TextLabel",wrap)
    lbTxt.Size=UDim2.new(0.5,0,1,0); lbTxt.Position=UDim2.new(0,10,0,0); lbTxt.BackgroundTransparency=1
    lbTxt.Text=lbl; lbTxt.TextColor3=AP_C_WHITE; lbTxt.Font=Enum.Font.GothamBold; lbTxt.TextSize=13
    lbTxt.TextXAlignment=Enum.TextXAlignment.Left; lbTxt.ZIndex=4
    local kbBtn=Instance.new("TextButton",wrap)
    kbBtn.Size=UDim2.new(0,70,0,26); kbBtn.Position=UDim2.new(1,-80,0.5,-13); kbBtn.BackgroundColor3=AP_C_CARD
    kbBtn.BorderSizePixel=0; kbBtn.Text=apGetKeyDisplayName(AP_Keybinds[keybindName]); kbBtn.TextColor3=AP_C_PURPLE
    kbBtn.Font=Enum.Font.GothamBold; kbBtn.TextSize=11; kbBtn.ZIndex=4
    Instance.new("UICorner",kbBtn).CornerRadius=UDim.new(0,6)
    local ks=Instance.new("UIStroke",kbBtn); ks.Color=AP_C_PURPLE; ks.Thickness=1; ks.Transparency=0.5
    kbBtn.MouseButton1Click:Connect(function()
        if AP_WaitingForKey==kbBtn then
            AP_WaitingForKey=nil; kbBtn.Text=apGetKeyDisplayName(AP_Keybinds[keybindName]); kbBtn.TextColor3=AP_C_PURPLE
            TweenService:Create(ks,TweenInfo.new(0.15),{Transparency=0.5}):Play(); return
        end
        if AP_WaitingForKey then AP_WaitingForKey.TextColor3=AP_C_PURPLE end
        AP_WaitingForKey=kbBtn; kbBtn.Text="..."; kbBtn.TextColor3=AP_C_WHITE
        TweenService:Create(ks,TweenInfo.new(0.15),{Transparency=0}):Play()
    end)
    UserInputService.InputBegan:Connect(function(inp,gpe)
        if AP_WaitingForKey~=kbBtn then return end
        local isKeyboard=inp.UserInputType==Enum.UserInputType.Keyboard
        local isGamepad=inp.UserInputType==Enum.UserInputType.Gamepad1 or inp.UserInputType==Enum.UserInputType.Gamepad2
        if not (isKeyboard or isGamepad) then return end
        local kc=inp.KeyCode
        if isKeyboard and kc==Enum.KeyCode.Escape then
            kbBtn.Text=apGetKeyDisplayName(AP_Keybinds[keybindName]); kbBtn.TextColor3=AP_C_PURPLE
            TweenService:Create(ks,TweenInfo.new(0.15),{Transparency=0.5}):Play(); AP_WaitingForKey=nil; return
        end
        if kc==Enum.KeyCode.Unknown then return end
        AP_Keybinds[keybindName]=kc
        kbBtn.Text=apGetKeyDisplayName(kc); kbBtn.TextColor3=AP_C_PURPLE
        TweenService:Create(ks,TweenInfo.new(0.15),{Transparency=0.5}):Play(); AP_WaitingForKey=nil
        if kbBadgeRef then kbBadgeRef.Text=apGetKeyDisplayName(kc) end
        apSaveConfig()
    end)
end
local function apMakeInputBox(lbl,defaultTxt,onDone)
    local wrap=Instance.new("Frame",apVstack)
    wrap.Size=UDim2.new(1,0,0,42); wrap.BackgroundColor3=AP_C_CARD; wrap.BorderSizePixel=0; wrap.ZIndex=3; wrap.LayoutOrder=APO()
    Instance.new("UICorner",wrap).CornerRadius=UDim.new(0,8)
    local wrapStroke=Instance.new("UIStroke",wrap)
    wrapStroke.Color=AP_C_PURPLE; wrapStroke.Thickness=1; wrapStroke.Transparency=0.8
    local lbTxt=Instance.new("TextLabel",wrap)
    lbTxt.Size=UDim2.new(0.5,0,1,0); lbTxt.Position=UDim2.new(0,10,0,0); lbTxt.BackgroundTransparency=1
    lbTxt.Text=lbl; lbTxt.TextColor3=AP_C_WHITE; lbTxt.Font=Enum.Font.GothamBold; lbTxt.TextSize=13
    lbTxt.TextXAlignment=Enum.TextXAlignment.Left; lbTxt.ZIndex=4
    local box=Instance.new("TextBox",wrap)
    box.Size=UDim2.new(0,70,0,26); box.Position=UDim2.new(1,-80,0.5,-13); box.BackgroundColor3=AP_C_CARD
    box.BorderSizePixel=0; box.Text=defaultTxt; box.TextColor3=AP_C_WHITE; box.Font=Enum.Font.GothamBold
    box.TextSize=11; box.ClearTextOnFocus=false; box.ZIndex=4
    Instance.new("UICorner",box).CornerRadius=UDim.new(0,6)
    local bs=Instance.new("UIStroke",box); bs.Color=AP_C_PURPLE; bs.Thickness=1; bs.Transparency=0.5
    box.Focused:Connect(function() TweenService:Create(bs,TweenInfo.new(0.15),{Transparency=0}):Play() end)
    box.FocusLost:Connect(function()
        TweenService:Create(bs,TweenInfo.new(0.15),{Transparency=0.5}):Play()
        if onDone then onDone(box.Text,box) end
    end)
    return box
end
apSectionLbl("Full Auto Play")
local fullAutoLeftVisual,fullAutoLeftKbTxt=apMakeToggleRow("FullAutoLeft","Full Auto Left",function(on)
    fullAutoPlayLeftEnabled=on
    if on then startFullAutoLeft() else stopFullAutoLeft() end
end)
fullAutoLeftSetter=fullAutoLeftVisual
local fullAutoRightVisual,fullAutoRightKbTxt=apMakeToggleRow("FullAutoRight","Full Auto Right",function(on)
    fullAutoPlayRightEnabled=on
    if on then startFullAutoRight() else stopFullAutoRight() end
end)
fullAutoRightSetter=fullAutoRightVisual
apSectionLbl("Auto Play")
local leftVisual,leftKbTxt=apMakeToggleRow("AutoLeft","Auto Left",function(on)
    AP_LeftOn=on
    if on then AP_StartLeft() else AP_StopLeft() end
end)
AP_SetLeftVisual=leftVisual
local rightVisual,rightKbTxt=apMakeToggleRow("AutoRight","Auto Right",function(on)
    AP_RightOn=on
    if on then AP_StartRight() else AP_StopRight() end
end)
AP_SetRightVisual=rightVisual
apSectionLbl("Speed Settings")
apMakeInputBox("Speed",tostring(AP_NORMAL_SPEED),function(v,box)
    local n=tonumber(v)
    if n then AP_NORMAL_SPEED=math.clamp(n,1,9999); box.Text=tostring(AP_NORMAL_SPEED); apSaveConfig(); apFlashSaved()
    else box.Text=tostring(AP_NORMAL_SPEED) end
end)
apSectionLbl("Keybinds")
apMakeKeybindRow("Full Auto Left","FullAutoLeft",fullAutoLeftKbTxt)
apMakeKeybindRow("Full Auto Right","FullAutoRight",fullAutoRightKbTxt)
apMakeKeybindRow("Auto Left","AutoLeft",leftKbTxt)
apMakeKeybindRow("Auto Right","AutoRight",rightKbTxt)
local function apHandleInput(kc)
    if AP_WaitingForKey then return end
    if kc==AP_Keybinds.UIToggle then apMain.Visible=not apMain.Visible; apReopenBtn.Visible=not apMain.Visible end
    if kc==AP_Keybinds.AutoLeft then AP_LeftOn=not AP_LeftOn; leftVisual(AP_LeftOn); if AP_LeftOn then AP_StartLeft() else AP_StopLeft() end end
    if kc==AP_Keybinds.AutoRight then AP_RightOn=not AP_RightOn; rightVisual(AP_RightOn); if AP_RightOn then AP_StartRight() else AP_StopRight() end end
end
UserInputService.InputBegan:Connect(function(input,gpe)
    if gpe then return end
    if input.UserInputType==Enum.UserInputType.Keyboard
    or input.UserInputType==Enum.UserInputType.Gamepad1
    or input.UserInputType==Enum.UserInputType.Gamepad2 then
        apHandleInput(input.KeyCode)
    end
end)
print("✓ Auto Play GUI loaded - Z = Auto Left | C = Auto Right | P = Toggle UI | Controller supported")
end)()
;(function()
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local Lighting=game:GetService("Lighting")
local Workspace=game:GetService("Workspace")
local LocalPlayer=Players.LocalPlayer
local FXS_BG=Color3.fromRGB(15,15,20)
local FXS_CARD=Color3.fromRGB(20,20,28)
local FXS_PURPLE=Color3.fromRGB(147,112,219)
local FXS_WHITE=Color3.fromRGB(255,255,255)
local FXS_RED=Color3.fromRGB(220,60,85)
local FXS_SW_OFF=Color3.fromRGB(40,40,50)
local antiLagActive=false
local removeAccessoriesActive=false
local descendantConnection=nil
local accessoryConnection=nil
local function processDescendant(obj)
    if (obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire")) then obj.Enabled=false end
    if (obj:IsA("Decal") or obj:IsA("Texture")) then obj.Transparency=1 end
    if obj:IsA("BasePart") then obj.Material=Enum.Material.Plastic; obj.Reflectance=0; obj.CastShadow=false end
    if (removeAccessoriesActive and obj:IsA("Accessory")) then obj:Destroy() end
end
local function optimizeLighting()
    Lighting.GlobalShadows=false; Lighting.FogEnd=9000000488; Lighting.Brightness=1
    Lighting.EnvironmentDiffuseScale=0; Lighting.EnvironmentSpecularScale=0
    for _,effect in pairs(Lighting:GetChildren()) do
        if (effect:IsA("BlurEffect") or effect:IsA("SunRaysEffect") or effect:IsA("ColorCorrectionEffect") or effect:IsA("BloomEffect") or effect:IsA("DepthOfFieldEffect")) then
            effect.Enabled=false
        end
    end
    for _,obj in pairs(Workspace:GetDescendants()) do processDescendant(obj) end
end
local function enableAntiLag()
    if antiLagActive then return end
    antiLagActive=true
    RunService:Set3dRenderingEnabled(true)
    settings().Rendering.QualityLevel=Enum.QualityLevel.Level01
    optimizeLighting()
    descendantConnection=Workspace.DescendantAdded:Connect(processDescendant)
end
local function disableAntiLag()
    antiLagActive=false
    if descendantConnection then descendantConnection:Disconnect(); descendantConnection=nil end
end
local function removeAllAccessories()
    for _,player in pairs(Players:GetPlayers()) do
        if player.Character then
            for _,obj in ipairs(player.Character:GetDescendants()) do
                if obj:IsA("Accessory") or obj:IsA("Hat") then obj:Destroy() end
            end
        end
    end
end
local function enableRemoveAccessories()
    removeAccessoriesActive=true
    removeAllAccessories()
    if not accessoryConnection then
        accessoryConnection=Players.PlayerAdded:Connect(function(player)
            player.CharacterAdded:Connect(function(char)
                task.wait(0.5)
                if removeAccessoriesActive then
                    for _,obj in ipairs(char:GetDescendants()) do
                        if obj:IsA("Accessory") or obj:IsA("Hat") then obj:Destroy() end
                    end
                end
            end)
        end)
    end
    descendantConnection=Workspace.DescendantAdded:Connect(function(obj)
        if removeAccessoriesActive and (obj:IsA("Accessory") or obj:IsA("Hat")) then obj:Destroy() end
    end)
end
local function disableRemoveAccessories()
    removeAccessoriesActive=false
    if accessoryConnection then accessoryConnection:Disconnect(); accessoryConnection=nil end
end
pcall(function() game.CoreGui:FindFirstChild("FXSAntiLagGUI"):Destroy() end)
local alGui=Instance.new("ScreenGui")
alGui.Name="FXSAntiLagGUI"; alGui.ResetOnSpawn=false; alGui.DisplayOrder=11
alGui.Parent=LocalPlayer:WaitForChild("PlayerGui")
local alMain=Instance.new("Frame")
alMain.Size=getMobileOptimized(UDim2.new(0,220,0,125),UDim2.new(0,200,0,110))
alMain.Position=getMobileOptimized(UDim2.new(0.02,0,0.3,0),UDim2.new(0.02,0,0.35,0))
alMain.BackgroundColor3=FXS_BG; alMain.BorderSizePixel=0; alMain.Active=true
alMain.ClipsDescendants=true; alMain.Parent=alGui
Instance.new("UICorner",alMain).CornerRadius=UDim.new(0,12)
local alStroke=Instance.new("UIStroke",alMain)
alStroke.Color=FXS_PURPLE; alStroke.Thickness=1.5
do
    local drag,ds,sp=false
    alMain.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
            drag=true; ds=inp.Position; sp=alMain.Position
            inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then drag=false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if drag and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then
            local d=inp.Position-ds
            alMain.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
        end
    end)
end
local alTitle=Instance.new("TextLabel",alMain)
alTitle.Size=UDim2.new(1,-60,0,25); alTitle.Position=UDim2.new(0,10,0,5)
alTitle.BackgroundTransparency=1; alTitle.Text="FXS ANTI LAG"; alTitle.TextColor3=FXS_PURPLE
alTitle.Font=Enum.Font.GothamBlack; alTitle.TextSize=getMobileOptimized(14,12); alTitle.TextXAlignment=Enum.TextXAlignment.Left
local alClose=Instance.new("TextButton",alMain)
alClose.Size=UDim2.new(0,30,0,30); alClose.Position=UDim2.new(1,-35,0,2)
alClose.BackgroundColor3=FXS_RED; alClose.BorderSizePixel=0
alClose.Text="×"; alClose.TextColor3=FXS_WHITE; alClose.Font=Enum.Font.GothamBold; alClose.TextSize=20; alClose.ZIndex=5
Instance.new("UICorner",alClose).CornerRadius=UDim.new(0,8)
local function createToggle(yPos,labelText,callback)
    local container=Instance.new("Frame",alMain)
    container.Size=UDim2.new(1,-20,0,32); container.Position=UDim2.new(0,10,0,yPos)
    container.BackgroundColor3=FXS_CARD; container.BorderSizePixel=0; container.ZIndex=3
    Instance.new("UICorner",container).CornerRadius=UDim.new(0,6)
    local stroke=Instance.new("UIStroke",container)
    stroke.Color=FXS_PURPLE; stroke.Thickness=1; stroke.Transparency=0.8
    local label=Instance.new("TextLabel",container)
    label.Size=UDim2.new(1,-70,1,0); label.Position=UDim2.new(0,8,0,0)
    label.BackgroundTransparency=1; label.Text=labelText; label.TextColor3=FXS_WHITE
    label.Font=Enum.Font.GothamBold; label.TextSize=getMobileOptimized(12,10); label.TextXAlignment=Enum.TextXAlignment.Left; label.ZIndex=4
    local switchBg=Instance.new("Frame",container)
    switchBg.Size=UDim2.new(0,40,0,20); switchBg.Position=UDim2.new(1,-48,0.5,-10)
    switchBg.BackgroundColor3=FXS_SW_OFF; switchBg.BorderSizePixel=0; switchBg.ZIndex=4
    Instance.new("UICorner",switchBg).CornerRadius=UDim.new(1,0)
    local switchCircle=Instance.new("Frame",switchBg)
    switchCircle.Size=UDim2.new(0,16,0,16); switchCircle.Position=UDim2.new(0,2,0.5,-8)
    switchCircle.BackgroundColor3=Color3.fromRGB(0,0,0); switchCircle.BorderSizePixel=0; switchCircle.ZIndex=5
    Instance.new("UICorner",switchCircle).CornerRadius=UDim.new(1,0)
    local isOn=false
    local btn=Instance.new("TextButton",container)
    btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""; btn.ZIndex=6
    btn.MouseButton1Click:Connect(function()
        isOn=not isOn
        TweenService:Create(switchBg,TweenInfo.new(0.2,Enum.EasingStyle.Quint),{BackgroundColor3=isOn and FXS_PURPLE or FXS_SW_OFF}):Play()
        TweenService:Create(switchCircle,TweenInfo.new(0.2,Enum.EasingStyle.Back),{Position=isOn and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)}):Play()
        if callback then callback(isOn) end
    end)
    btn.MouseEnter:Connect(function()
        TweenService:Create(stroke,TweenInfo.new(0.15),{Transparency=0.3}):Play()
        TweenService:Create(container,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(25,25,35)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(stroke,TweenInfo.new(0.15),{Transparency=0.8}):Play()
        TweenService:Create(container,TweenInfo.new(0.15),{BackgroundColor3=FXS_CARD}):Play()
    end)
end
createToggle(35,"Anti Lag",function(on) if on then enableAntiLag() else disableAntiLag() end end)
createToggle(72,"Remove Accessories",function(on) if on then enableRemoveAccessories() else disableRemoveAccessories() end end)
local alReopenBtn=Instance.new("TextButton",alGui)
alReopenBtn.Size=UDim2.new(0,40,0,40)
alReopenBtn.Position=getMobileOptimized(UDim2.new(0.02,0,0.3,0),UDim2.new(0.02,0,0.35,0))
alReopenBtn.BackgroundColor3=FXS_PURPLE; alReopenBtn.BorderSizePixel=0
alReopenBtn.Text="AL"; alReopenBtn.TextColor3=FXS_WHITE
alReopenBtn.Font=Enum.Font.GothamBlack; alReopenBtn.TextSize=14; alReopenBtn.Visible=false; alReopenBtn.ZIndex=20
Instance.new("UICorner",alReopenBtn).CornerRadius=UDim.new(0,10)
alClose.MouseButton1Click:Connect(function() alMain.Visible=false; alReopenBtn.Visible=true end)
alReopenBtn.MouseButton1Click:Connect(function() alMain.Visible=true; alReopenBtn.Visible=false end)
alClose.MouseEnter:Connect(function() TweenService:Create(alClose,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(255,80,100)}):Play() end)
alClose.MouseLeave:Connect(function() TweenService:Create(alClose,TweenInfo.new(0.15),{BackgroundColor3=FXS_RED}):Play() end)
print("✅ FXS ANTI LAG GUI LOADED")
end)()
