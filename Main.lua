repeat task.wait() until game:IsLoaded()
pcall(function() setfpscap(999) end)
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local SoundService     = game:GetService("SoundService")
local Lighting         = game:GetService("Lighting")
local HttpService      = game:GetService("HttpService")
local Stats            = game:GetService("Stats")
local LocalPlayer      = Players.LocalPlayer
local VisualSetters    = {}
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
local speedToggled             = false
local fastestStealEnabled      = false
local laggerToggled            = false
local autoBatToggled           = false
local fullAutoPlayLeftEnabled  = false
local fullAutoPlayRightEnabled = false
local fullAutoPlayLeftConn     = nil
local fullAutoPlayRightConn    = nil
local fullAutoLeftSetter       = nil
local fullAutoRightSetter      = nil
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
local COUNTDOWN_TARGET           = 4.9
local SPAWN_Z_RIGHT_THRESHOLD    = 60
local BR_L2 = Vector3.new(-475.5,  -3.75, 100.5)
local BR_L3 = Vector3.new(-486.5,  -3.75, 100.5)
local BR_R2 = Vector3.new(-475.50, -3.95,  17.55)
local BR_R3 = Vector3.new(-486.76, -3.95,  17.55)
local Keybinds = {
	AutoBat       = Enum.KeyCode.E,
	SpeedToggle   = Enum.KeyCode.Q,
	LaggerToggle  = Enum.KeyCode.R,
	InfiniteJump  = Enum.KeyCode.M,
	UIToggle      = Enum.KeyCode.U,
	DropBrainrot  = Enum.KeyCode.X,
	FloatToggle   = Enum.KeyCode.J,
	FullAutoLeft  = Enum.KeyCode.G,
	FullAutoRight = Enum.KeyCode.H,
	TPDown        = Enum.KeyCode.F,
}
local isStealing      = false
local stealStartTime  = nil
local StealData       = {}
local lastStealTick   = 0
local plotCache       = {}
local plotCacheTime   = {}
local cachedPrompts   = {}
local promptCacheTime = 0
local Settings = { AutoStealEnabled=false, StealRadius=20, StealDuration=0.25 }
local Values   = {
	STEAL_RADIUS=20, STEAL_DURATION=0.2, STEAL_COOLDOWN=0.1,
	PLOT_CACHE_DURATION=2, PROMPT_CACHE_REFRESH=0.15,
}
local STEAL_COOLDOWN       = Values.STEAL_COOLDOWN
local PLOT_CACHE_DURATION  = Values.PLOT_CACHE_DURATION
local PROMPT_CACHE_REFRESH = Values.PROMPT_CACHE_REFRESH
local Enabled = {
	AntiRagdoll=false, AutoSteal=false, InfiniteJump=false,
	Optimizer=false, Unwalk=false, RemoveAccessories=false,
}
local Connections     = {}
local savedAnimations = {}
local h, hrp, speedLbl
local progressConnection = nil
local gui, main
local speedSwBg, speedSwCircle
local laggerSwBg, laggerSwCircle
local batSwBg, batSwCircle
local waitingForKeySW = nil
local sideSetters     = {}
local ProgressLabel, ProgressPercentLabel, ProgressBarFill, RadiusInput, DurationInput
-- ============================================================
-- PLOT DETECTION (original K7 logic)
-- ============================================================
local function detectMyPlot()
	local plots = workspace:FindFirstChild("Plots"); if not plots then return nil,nil end
	local myName = LocalPlayer.DisplayName or LocalPlayer.Name
	for _,plot in ipairs(plots:GetChildren()) do
		local ok,result = pcall(function()
			local sign=plot:FindFirstChild("PlotSign"); if not sign then return nil end
			local sg=sign:FindFirstChild("SurfaceGui"); if not sg then return nil end
			local fr=sg:FindFirstChild("Frame"); if not fr then return nil end
			local tl=fr:FindFirstChild("TextLabel"); if not tl then return nil end
			if tl.Text:find(myName,1,true) then
				local spawnObj=plot:FindFirstChild("Spawn")
				if spawnObj then local z=spawnObj.CFrame.Position.Z; return z<SPAWN_Z_RIGHT_THRESHOLD and "left" or "right" end
			end
			return nil
		end)
		if ok and result then return result,plot.Name end
	end
	return nil,nil
end
local function refreshMyPlotSide()
	local side,plotName=detectMyPlot(); G_myPlotSide=side; G_myPlotName=plotName; return side
end
task.spawn(function() while true do task.wait(2); if G_tpAutoEnabled then refreshMyPlotSide() end end end)
task.spawn(function()
	local plots=workspace:WaitForChild("Plots",30); if not plots then return end
	local myName=LocalPlayer.DisplayName or LocalPlayer.Name
	local function watchPlot(plot)
		pcall(function()
			local tl=plot:WaitForChild("PlotSign",5):WaitForChild("SurfaceGui",5):WaitForChild("Frame",5):WaitForChild("TextLabel",5)
			if not tl then return end
			tl:GetPropertyChangedSignal("Text"):Connect(function() refreshMyPlotSide() end)
			if tl.Text:find(myName,1,true) then refreshMyPlotSide() end
		end)
	end
	for _,plot in ipairs(plots:GetChildren()) do task.spawn(watchPlot,plot) end
	plots.ChildAdded:Connect(function(plot) task.spawn(watchPlot,plot) end)
end)
-- ============================================================
-- FASTEST STEAL SPEED (original K7 logic)
-- ============================================================
local function calculateFastestStealSpeed()
	local char=LocalPlayer.Character; if not char then return nil end
	local hrpL=char:FindFirstChild("HumanoidRootPart"); if not hrpL then return nil end
	local targetPos=nil
	if fullAutoPlayLeftEnabled then
		local pts={FAP_L1,FAP_L2,FAP_L3,FAP_L4,FAP_L5}
		local phase=FAP_LeftPhase; if type(phase)~="number" or phase<1 then phase=1 end
		if phase>5 then phase=5 end; targetPos=pts[phase]
	elseif fullAutoPlayRightEnabled then
		local pts={FAP_R1,FAP_R2,FAP_R3,FAP_R4,FAP_R5}
		local phase=FAP_RightPhase; if type(phase)~="number" or phase<1 then phase=1 end
		if phase>5 then phase=5 end; targetPos=pts[phase]
	else return nil end
	if not targetPos then return end
	local dist=Vector3.new(targetPos.X-hrpL.Position.X,0,targetPos.Z-hrpL.Position.Z).Magnitude
	if dist<0.1 then return end
	return math.clamp(dist/1.65,1,9999)
end
RunService.Heartbeat:Connect(function()
	if not fastestStealEnabled then return end
	if not (fullAutoPlayLeftEnabled or fullAutoPlayRightEnabled) then return end
	local char=LocalPlayer.Character; if not char then return end
	local hrpL=char:FindFirstChild("HumanoidRootPart"); if not hrpL then return end
	local hum=char:FindFirstChildOfClass("Humanoid"); if not hum then return end
	local md=hum.MoveDirection; if md.Magnitude==0 then return end
	local spd=calculateFastestStealSpeed()
	if spd then hrpL.AssemblyLinearVelocity=Vector3.new(md.X*spd,hrpL.AssemblyLinearVelocity.Y,md.Z*spd) end
end)
-- ============================================================
-- STEAL SYSTEM (original K7 logic)
-- ============================================================
local function isMyPlotByName(plotName)
	local currentTime=tick()
	if plotCache[plotName] and (currentTime-(plotCacheTime[plotName] or 0))<PLOT_CACHE_DURATION then return plotCache[plotName] end
	local plots=workspace:FindFirstChild("Plots")
	if not plots then plotCache[plotName]=false;plotCacheTime[plotName]=currentTime;return false end
	local plot=plots:FindFirstChild(plotName)
	if not plot then plotCache[plotName]=false;plotCacheTime[plotName]=currentTime;return false end
	local sign=plot:FindFirstChild("PlotSign")
	if sign then local yourBase=sign:FindFirstChild("YourBase"); if yourBase and yourBase:IsA("BillboardGui") then local result=yourBase.Enabled==true; plotCache[plotName]=result;plotCacheTime[plotName]=currentTime;return result end end
	plotCache[plotName]=false;plotCacheTime[plotName]=currentTime;return false
end
local function findNearestPrompt()
	local char=LocalPlayer.Character; if not char then return nil end
	local root=char:FindFirstChild("HumanoidRootPart"); if not root then return nil end
	local currentTime=tick()
	if currentTime-promptCacheTime<PROMPT_CACHE_REFRESH and #cachedPrompts>0 then
		local np,nd,nn=nil,math.huge,nil
		for _,data in ipairs(cachedPrompts) do if data.spawn then local dist=(data.spawn.Position-root.Position).Magnitude; if dist<=Settings.StealRadius and dist<nd then np=data.prompt;nd=dist;nn=data.name end end end
		if np then return np,nd,nn end
	end
	cachedPrompts={};promptCacheTime=currentTime
	local plots=workspace:FindFirstChild("Plots"); if not plots then return nil end
	local np,nd,nn=nil,math.huge,nil
	for _,plot in ipairs(plots:GetChildren()) do
		if isMyPlotByName(plot.Name) then continue end
		local podiums=plot:FindFirstChild("AnimalPodiums"); if not podiums then continue end
		for _,podium in ipairs(podiums:GetChildren()) do
			pcall(function()
				local base=podium:FindFirstChild("Base"); local spawn=base and base:FindFirstChild("Spawn")
				if spawn then
					local dist=(spawn.Position-root.Position).Magnitude
					local att=spawn:FindFirstChild("PromptAttachment")
					if att then for _,ch in ipairs(att:GetChildren()) do if ch:IsA("ProximityPrompt") then table.insert(cachedPrompts,{prompt=ch,spawn=spawn,name=podium.Name}); if dist<=Settings.StealRadius and dist<nd then np=ch;nd=dist;nn=podium.Name end; break end end end
				end
			end)
		end
	end
	return np,nd,nn
end
local function ResetProgressBar()
	if ProgressLabel then ProgressLabel.Text="READY" end
	if ProgressPercentLabel then ProgressPercentLabel.Text="" end
	if ProgressBarFill then ProgressBarFill.Size=UDim2.new(0,0,1,0) end
end
local function executeSteal(prompt,name)
	local currentTime=tick()
	if currentTime-lastStealTick<STEAL_COOLDOWN then return end
	if isStealing then return end
	if not StealData[prompt] then
		StealData[prompt]={hold={},trigger={},ready=true}
		pcall(function()
			if getconnections then
				for _,c in ipairs(getconnections(prompt.PromptButtonHoldBegan)) do if c.Function then table.insert(StealData[prompt].hold,c.Function) end end
				for _,c in ipairs(getconnections(prompt.Triggered)) do if c.Function then table.insert(StealData[prompt].trigger,c.Function) end end
			else StealData[prompt].useFallback=true end
		end)
	end
	local data=StealData[prompt]; if not data.ready then return end
	data.ready=false;isStealing=true;stealStartTime=currentTime;lastStealTick=currentTime
	if ProgressLabel then ProgressLabel.Text=name or "STEALING..." end
	if progressConnection then progressConnection:Disconnect() end
	progressConnection=RunService.Heartbeat:Connect(function()
		if not isStealing then progressConnection:Disconnect();return end
		local prog=math.clamp((tick()-stealStartTime)/Settings.StealDuration,0,1)
		if ProgressBarFill then ProgressBarFill.Size=UDim2.new(prog,0,1,0) end
		if ProgressPercentLabel then ProgressPercentLabel.Text=math.floor(prog*100).."%" end
	end)
	task.spawn(function()
		local ok=false
		pcall(function() if not data.useFallback then for _,f in ipairs(data.hold) do task.spawn(f) end; task.wait(Settings.StealDuration); for _,f in ipairs(data.trigger) do task.spawn(f) end; ok=true end end)
		if not ok and fireproximityprompt then pcall(function() fireproximityprompt(prompt);ok=true end) end
		if not ok then pcall(function() prompt:InputHoldBegin();task.wait(Settings.StealDuration);prompt:InputHoldEnd();ok=true end) end
		task.wait(Settings.StealDuration*0.3)
		if progressConnection then progressConnection:Disconnect() end
		ResetProgressBar();task.wait(0.05);data.ready=true;isStealing=false
	end)
end
local function startAutoSteal()
	if Connections.autoSteal then return end
	Connections.autoSteal=RunService.Heartbeat:Connect(function()
		if not Enabled.AutoSteal or isStealing then return end
		local p,_,n=findNearestPrompt()
		if p then
			local char=LocalPlayer.Character; local hrpLocal=char and char:FindFirstChild("HumanoidRootPart")
			if hrpLocal then hrpLocal.AssemblyLinearVelocity=Vector3.new(0,hrpLocal.AssemblyLinearVelocity.Y,0) end
			executeSteal(p,n)
		end
	end)
end
local function stopAutoSteal()
	if Connections.autoSteal then Connections.autoSteal:Disconnect();Connections.autoSteal=nil end
	isStealing=false;lastStealTick=0;plotCache={};plotCacheTime={};cachedPrompts={};ResetProgressBar()
end
-- ============================================================
-- ANTI-RAGDOLL v1 (new implementation)
-- ============================================================
local antiRagdollMode    = nil
local ragdollConnections = {}
local cachedCharData     = {}
local isBoosting         = false
local AR_BOOST_SPEED     = 400
local AR_DEFAULT_SPEED   = 16
local function arCacheCharacterData()
	local char=LocalPlayer.Character; if not char then return false end
	local hum=char:FindFirstChildOfClass("Humanoid"); local root=char:FindFirstChild("HumanoidRootPart")
	if not hum or not root then return false end
	cachedCharData={character=char,humanoid=hum,root=root}; return true
end
local function arDisconnectAll()
	for _,conn in ipairs(ragdollConnections) do pcall(function() conn:Disconnect() end) end
	ragdollConnections={}
end
local function arIsRagdolled()
	if not cachedCharData.humanoid then return false end
	local state=cachedCharData.humanoid:GetState()
	if state==Enum.HumanoidStateType.Physics or state==Enum.HumanoidStateType.Ragdoll or state==Enum.HumanoidStateType.FallingDown then return true end
	local endTime=LocalPlayer:GetAttribute("RagdollEndTime")
	if endTime and (endTime-workspace:GetServerTimeNow())>0 then return true end
	return false
end
local function arForceExit()
	if not cachedCharData.humanoid or not cachedCharData.root then return end
	pcall(function() LocalPlayer:SetAttribute("RagdollEndTime",workspace:GetServerTimeNow()) end)
	for _,d in ipairs(cachedCharData.character:GetDescendants()) do
		if d:IsA("BallSocketConstraint") or (d:IsA("Attachment") and d.Name:find("RagdollAttachment")) then d:Destroy() end
	end
	if not isBoosting then isBoosting=true; cachedCharData.humanoid.WalkSpeed=AR_BOOST_SPEED end
	if cachedCharData.humanoid.Health>0 then cachedCharData.humanoid:ChangeState(Enum.HumanoidStateType.Running) end
	cachedCharData.root.Anchored=false
end
local function arHeartbeatLoop()
	while antiRagdollMode=="v1" do
		task.wait()
		if not Enabled.AntiRagdoll then break end
		local ragdolled=arIsRagdolled()
		if ragdolled then arForceExit()
		elseif isBoosting and not ragdolled then
			isBoosting=false; if cachedCharData.humanoid then cachedCharData.humanoid.WalkSpeed=AR_DEFAULT_SPEED end
		end
	end
end
local function startAntiRagdoll()
	if antiRagdollMode=="v1" then return end
	if not arCacheCharacterData() then return end
	antiRagdollMode="v1"
	local camConn=RunService.RenderStepped:Connect(function()
		local cam=workspace.CurrentCamera; if cam and cachedCharData.humanoid then cam.CameraSubject=cachedCharData.humanoid end
	end)
	table.insert(ragdollConnections,camConn)
	local respawnConn=LocalPlayer.CharacterAdded:Connect(function() isBoosting=false; task.wait(0.5); arCacheCharacterData() end)
	table.insert(ragdollConnections,respawnConn)
	task.spawn(arHeartbeatLoop)
end
local function stopAntiRagdoll()
	antiRagdollMode=nil
	if isBoosting and cachedCharData.humanoid then cachedCharData.humanoid.WalkSpeed=AR_DEFAULT_SPEED end
	isBoosting=false; arDisconnectAll(); cachedCharData={}
end
-- ============================================================
-- MOVEMENT FEATURES (original K7 logic)
-- ============================================================
local IJ_JumpConn=nil; local IJ_FallConn=nil
local function startInfiniteJump()
	if IJ_JumpConn then IJ_JumpConn:Disconnect() end; if IJ_FallConn then IJ_FallConn:Disconnect() end
	IJ_JumpConn=UserInputService.JumpRequest:Connect(function()
		if not Enabled.InfiniteJump then return end; local char=LocalPlayer.Character; if not char then return end
		local root=char:FindFirstChild("HumanoidRootPart"); if root then root.Velocity=Vector3.new(root.Velocity.X,55,root.Velocity.Z) end
	end)
	IJ_FallConn=RunService.Heartbeat:Connect(function()
		if not Enabled.InfiniteJump then return end; local char=LocalPlayer.Character; if not char then return end
		local root=char:FindFirstChild("HumanoidRootPart"); if root and root.Velocity.Y<-120 then root.Velocity=Vector3.new(root.Velocity.X,-120,root.Velocity.Z) end
	end)
end
local function stopInfiniteJump()
	if IJ_JumpConn then IJ_JumpConn:Disconnect();IJ_JumpConn=nil end
	if IJ_FallConn then IJ_FallConn:Disconnect();IJ_FallConn=nil end
end
local function startUnwalk()
	local c=LocalPlayer.Character; if not c then return end
	local hum=c:FindFirstChildOfClass("Humanoid"); if hum then for _,t in ipairs(hum:GetPlayingAnimationTracks()) do t:Stop() end end
	local anim=c:FindFirstChild("Animate"); if anim then savedAnimations.Animate=anim:Clone();anim:Destroy() end
end
local function stopUnwalk()
	local c=LocalPlayer.Character; if c and savedAnimations.Animate then savedAnimations.Animate:Clone().Parent=c;savedAnimations.Animate=nil end
end
local floatEnabled=false; local floatHeight=9.5
local function startFloat()
	if Connections.float then Connections.float:Disconnect() end
	Connections.float=RunService.Heartbeat:Connect(function()
		if not floatEnabled then return end
		local char=LocalPlayer.Character; if not char then return end
		local root=char:FindFirstChild("HumanoidRootPart"); if not root then return end
		local rp=RaycastParams.new(); rp.FilterDescendantsInstances={char};rp.FilterType=Enum.RaycastFilterType.Exclude
		local rr=workspace:Raycast(root.Position,Vector3.new(0,-200,0),rp)
		if rr then
			local diff=(rr.Position.Y+floatHeight)-root.Position.Y
			if math.abs(diff)>0.3 then root.AssemblyLinearVelocity=Vector3.new(root.AssemblyLinearVelocity.X,diff*15,root.AssemblyLinearVelocity.Z)
			else root.AssemblyLinearVelocity=Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z) end
		end
	end)
end
local function stopFloat()
	if Connections.float then Connections.float:Disconnect();Connections.float=nil end
	local char=LocalPlayer.Character; if char then local root=char:FindFirstChild("HumanoidRootPart"); if root then root.AssemblyLinearVelocity=Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z) end end
end
local function enableNoCameraCollision()
	noCamCollisionEnabled=true; if noCamCollisionConn then noCamCollisionConn:Disconnect() end
	noCamCollisionConn=RunService.RenderStepped:Connect(function()
		if not noCamCollisionEnabled then return end
		local ch=LocalPlayer.Character; if not ch then return end
		local cam=workspace.CurrentCamera; if not cam then return end
		local hrp2=ch:FindFirstChild("HumanoidRootPart"); if not hrp2 then return end
		local camPos=cam.CFrame.Position; local charPos=hrp2.Position+Vector3.new(0,1.5,0)
		local toChar=charPos-camPos; local dist=toChar.Magnitude; if dist<0.3 then return end
		local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={ch};params.IgnoreWater=true
		local hit={}; local origin=camPos; local remaining=toChar
		for _=1,12 do
			if remaining.Magnitude<0.2 then break end
			local res=workspace:Raycast(origin,remaining,params); if not res then break end
			local p=res.Instance
			if p and p:IsA("BasePart") and not p:IsDescendantOf(ch) then hit[p]=true; if noCamParts[p]==nil then noCamParts[p]=p.LocalTransparencyModifier end;p.LocalTransparencyModifier=1 end
			origin=res.Position+remaining.Unit*0.02;remaining=charPos-origin
		end
		for p,orig in pairs(noCamParts) do if not hit[p] then pcall(function() if p and p.Parent then p.LocalTransparencyModifier=orig end end);noCamParts[p]=nil end end
	end)
end
local function disableNoCameraCollision()
	noCamCollisionEnabled=false; if noCamCollisionConn then noCamCollisionConn:Disconnect();noCamCollisionConn=nil end
	for p,orig in pairs(noCamParts) do pcall(function() if p and p.Parent then p.LocalTransparencyModifier=orig end end) end; noCamParts={}
end
local dropBrainrotActive=false; local DROP_ASCEND_DURATION=0.2; local DROP_ASCEND_SPEED=150
local setDropBrainrotVisual=nil; local dropMobileSetter=nil
local function runDropBrainrot()
	if dropBrainrotActive then return end
	local char=LocalPlayer.Character; if not char then return end
	local root=char:FindFirstChild("HumanoidRootPart"); if not root then return end
	dropBrainrotActive=true; local t0=tick(); local dc
	dc=RunService.Heartbeat:Connect(function()
		local r=char and char:FindFirstChild("HumanoidRootPart")
		if not r then dc:Disconnect();dropBrainrotActive=false; if setDropBrainrotVisual then setDropBrainrotVisual(false) end; if dropMobileSetter then dropMobileSetter(false) end;return end
		if tick()-t0>=DROP_ASCEND_DURATION then
			dc:Disconnect()
			local rp=RaycastParams.new();rp.FilterDescendantsInstances={char};rp.FilterType=Enum.RaycastFilterType.Exclude
			local rr=workspace:Raycast(r.Position,Vector3.new(0,-2000,0),rp)
			if rr then local hum2=char:FindFirstChildOfClass("Humanoid"); local off=(hum2 and hum2.HipHeight or 2)+(r.Size.Y/2); r.CFrame=CFrame.new(r.Position.X,rr.Position.Y+off,r.Position.Z);r.AssemblyLinearVelocity=Vector3.new(0,0,0) end
			dropBrainrotActive=false; if setDropBrainrotVisual then setDropBrainrotVisual(false) end; if dropMobileSetter then dropMobileSetter(false) end;return
		end
		r.AssemblyLinearVelocity=Vector3.new(r.AssemblyLinearVelocity.X,DROP_ASCEND_SPEED,r.AssemblyLinearVelocity.Z)
	end)
end
local function runTPDown()
	local wasFloating=floatEnabled; if wasFloating then stopFloat() end
	task.spawn(function()
		pcall(function()
			local c=LocalPlayer.Character; if not c then return end
			local h2=c:FindFirstChild("HumanoidRootPart"); if not h2 then return end
			local hum=c:FindFirstChildOfClass("Humanoid"); if not hum then return end
			local rp=RaycastParams.new();rp.FilterDescendantsInstances={c};rp.FilterType=Enum.RaycastFilterType.Exclude
			local hit=workspace:Raycast(h2.Position,Vector3.new(0,-500,0),rp)
			if hit then h2.AssemblyLinearVelocity=Vector3.zero;h2.AssemblyAngularVelocity=Vector3.zero; h2.CFrame=CFrame.new(hit.Position.X,hit.Position.Y+(hum.HipHeight or 2)+(h2.Size.Y/2)+0.1,hit.Position.Z);h2.AssemblyLinearVelocity=Vector3.zero end
		end)
		task.wait(0.1); if wasFloating then startFloat() end
		if VisualSetters and VisualSetters.TPDownReset then VisualSetters.TPDownReset() end
	end)
end
-- ============================================================
-- VISUAL / OPTIMIZATION (original K7 logic)
-- ============================================================
local function applyAntiLag(ultra)
	Lighting.GlobalShadows=false;Lighting.FogEnd=1e10;Lighting.Brightness=1;Lighting.EnvironmentDiffuseScale=0;Lighting.EnvironmentSpecularScale=0
	for _,e in pairs(Lighting:GetChildren()) do if e:IsA("BlurEffect") or e:IsA("SunRaysEffect") or e:IsA("ColorCorrectionEffect") or e:IsA("BloomEffect") or e:IsA("DepthOfFieldEffect") then e.Enabled=false end end
	for _,obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") then obj.Material=Enum.Material.Plastic;obj.Reflectance=0; if ultra then obj.CastShadow=false end
		elseif obj:IsA("Decal") or obj:IsA("Texture") then if ultra then obj:Destroy() else obj.Transparency=1 end
		elseif ultra and (obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire")) then obj.Enabled=false end
	end
	if ultra then pcall(function() settings().Rendering.QualityLevel=Enum.QualityLevel.Level01 end) end
end
local function enableOptimizer()
	Enabled.Optimizer=true;applyAntiLag(false)
	if _antiLagDescConn then _antiLagDescConn:Disconnect() end
	_antiLagDescConn=workspace.DescendantAdded:Connect(function(obj)
		if obj:IsA("BasePart") then obj.Material=Enum.Material.Plastic;obj.Reflectance=0
		elseif obj:IsA("Decal") or obj:IsA("Texture") then obj.Transparency=1 end
	end)
end
local function disableOptimizer()
	Enabled.Optimizer=false; if _antiLagDescConn then _antiLagDescConn:Disconnect();_antiLagDescConn=nil end
end
local function enableUltraMode() ultraModeEnabled=true;applyAntiLag(true) end
local function disableUltraMode() ultraModeEnabled=false end
local removedAccessories={}
local function removeAccessories()
	if Enabled.RemoveAccessories then
		local char=LocalPlayer.Character; if not char then return end
		for _,obj in ipairs(char:GetDescendants()) do if obj:IsA("Accessory") or obj:IsA("Hat") then if not removedAccessories[obj] then removedAccessories[obj]=true;obj:Destroy() end end end
	end
end
local function startRemoveAccessories()
	Enabled.RemoveAccessories=true;removeAccessories()
	if not Connections.removeAccessories then Connections.removeAccessories=LocalPlayer.CharacterAdded:Connect(function() task.wait(0.5); if Enabled.RemoveAccessories then removeAccessories() end end) end
end
local function stopRemoveAccessories()
	Enabled.RemoveAccessories=false; if Connections.removeAccessories then Connections.removeAccessories:Disconnect();Connections.removeAccessories=nil end; removedAccessories={}
end
-- ============================================================
-- ANIMATION PACK (original K7 logic)
-- ============================================================
local animHeartbeatConn=nil; local originalAnims=nil; local harderHitAnimEnabled=false
local Anims={idle1="rbxassetid://133806214992291",idle2="rbxassetid://94970088341563",walk="rbxassetid://707897309",run="rbxassetid://707861613",jump="rbxassetid://116936326516985",fall="rbxassetid://116936326516985",climb="rbxassetid://116936326516985",swim="rbxassetid://116936326516985",swimidle="rbxassetid://116936326516985"}
local function saveOriginalAnims(char)
	local animate=char:FindFirstChild("Animate"); if not animate then return end
	local function g(obj) return obj and obj.AnimationId or nil end
	originalAnims={idle1=g(animate.idle and animate.idle.Animation1),idle2=g(animate.idle and animate.idle.Animation2),walk=g(animate.walk and animate.walk.WalkAnim),run=g(animate.run and animate.run.RunAnim),jump=g(animate.jump and animate.jump.JumpAnim),fall=g(animate.fall and animate.fall.FallAnim),climb=g(animate.climb and animate.climb.ClimbAnim),swim=g(animate.swim and animate.swim.Swim),swimidle=g(animate.swimidle and animate.swimidle.SwimIdle)}
end
local function applyAnimPack(char)
	local animate=char:FindFirstChild("Animate"); if not animate then return end
	local function s(obj,id) if obj then obj.AnimationId=id end end
	s(animate.idle and animate.idle.Animation1,Anims.idle1);s(animate.idle and animate.idle.Animation2,Anims.idle2);s(animate.walk and animate.walk.WalkAnim,Anims.walk);s(animate.run and animate.run.RunAnim,Anims.run);s(animate.jump and animate.jump.JumpAnim,Anims.jump);s(animate.fall and animate.fall.FallAnim,Anims.fall);s(animate.climb and animate.climb.ClimbAnim,Anims.climb);s(animate.swim and animate.swim.Swim,Anims.swim);s(animate.swimidle and animate.swimidle.SwimIdle,Anims.swimidle)
end
local function restoreOriginalAnims(char)
	if not originalAnims then return end
	local animate=char:FindFirstChild("Animate"); if not animate then return end
	local function s(obj,id) if obj and id then obj.AnimationId=id end end
	s(animate.idle and animate.idle.Animation1,originalAnims.idle1);s(animate.idle and animate.idle.Animation2,originalAnims.idle2);s(animate.walk and animate.walk.WalkAnim,originalAnims.walk);s(animate.run and animate.run.RunAnim,originalAnims.run);s(animate.jump and animate.jump.JumpAnim,originalAnims.jump);s(animate.fall and animate.fall.FallAnim,originalAnims.fall);s(animate.climb and animate.climb.ClimbAnim,originalAnims.climb);s(animate.swim and animate.swim.Swim,originalAnims.swim);s(animate.swimidle and animate.swimidle.SwimIdle,originalAnims.swimidle)
	local hum2=char:FindFirstChildOfClass("Humanoid"); if hum2 then for _,t in ipairs(hum2:GetPlayingAnimationTracks()) do t:Stop(0) end end
end
local function startHarderHitAnim()
	if animHeartbeatConn then animHeartbeatConn:Disconnect();animHeartbeatConn=nil end
	local char=LocalPlayer.Character
	if char then saveOriginalAnims(char);applyAnimPack(char); local hum2=char:FindFirstChildOfClass("Humanoid"); if hum2 then for _,t in ipairs(hum2:GetPlayingAnimationTracks()) do t:Stop(0) end end end
	animHeartbeatConn=RunService.Heartbeat:Connect(function() if not harderHitAnimEnabled then return end; local c=LocalPlayer.Character; if c then applyAnimPack(c) end end)
end
local function stopHarderHitAnim()
	if animHeartbeatConn then animHeartbeatConn:Disconnect();animHeartbeatConn=nil end; local char=LocalPlayer.Character; if char then restoreOriginalAnims(char) end
end
-- ============================================================
-- MEDUSA COUNTER (original K7 logic)
-- ============================================================
local MEDUSA_COOLDOWN=25; local medusaLastUsed=0; local medusaDebounce=false
local medusaCounterEnabled=false; local medusaAnchorConns={}
local function findMedusa()
	local char=LocalPlayer.Character; if not char then return nil end
	for _,tool in ipairs(char:GetChildren()) do if tool:IsA("Tool") then local tn=tool.Name:lower(); if tn:find("medusa") or tn:find("head") or tn:find("stone") then return tool end end end
	local bp=LocalPlayer:FindFirstChild("Backpack"); if bp then for _,tool in ipairs(bp:GetChildren()) do if tool:IsA("Tool") then local tn=tool.Name:lower(); if tn:find("medusa") or tn:find("head") or tn:find("stone") then return tool end end end end
	return nil
end
local function useMedusaCounter()
	if medusaDebounce or tick()-medusaLastUsed<MEDUSA_COOLDOWN then return end
	local char=LocalPlayer.Character; if not char then return end
	medusaDebounce=true; local med=findMedusa(); if not med then medusaDebounce=false;return end
	if med.Parent~=char then local hum2=char:FindFirstChildOfClass("Humanoid"); if hum2 then hum2:EquipTool(med) end end
	pcall(function() med:Activate() end); medusaLastUsed=tick(); medusaDebounce=false
end
local function stopMedusaCounter()
	for _,c in pairs(medusaAnchorConns) do pcall(function() c:Disconnect() end) end; medusaAnchorConns={}
end
local function setupMedusaCounter(char)
	stopMedusaCounter(); if not char then return end
	local function onAnchorChanged(part)
		return part:GetPropertyChangedSignal("Anchored"):Connect(function()
			if medusaCounterEnabled and part.Anchored and part.Transparency==1 then useMedusaCounter() end
		end)
	end
	for _,part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then table.insert(medusaAnchorConns,onAnchorChanged(part)) end end
	table.insert(medusaAnchorConns,char.DescendantAdded:Connect(function(part) if part:IsA("BasePart") then table.insert(medusaAnchorConns,onAnchorChanged(part)) end end))
end
-- ============================================================
-- BRAINROT RETURN + AUTO TP (original K7 logic)
-- ============================================================
local function doReturnTeleport(side)
	if brainrotReturnCooldown then return end
	brainrotReturnCooldown=true
	task.spawn(function()
		pcall(function()
			local c=LocalPlayer.Character; if not c then return end
			local root=c:FindFirstChild("HumanoidRootPart"); local hum=c:FindFirstChildOfClass("Humanoid"); if not root then return end
			local rotation=(side=="right") and math.rad(180) or 0
			local step2=(side=="right") and BR_R2 or BR_L2; local step3=(side=="right") and BR_R3 or BR_L3
			local function tp(pos)
				root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero
				root.CFrame=CFrame.new(pos+Vector3.new(0,3,0))*CFrame.Angles(0,rotation,0)
				if hum then hum:ChangeState(Enum.HumanoidStateType.Running);hum:Move(Vector3.zero,false) end
				for _,obj in ipairs(c:GetDescendants()) do if obj:IsA("Motor6D") and not obj.Enabled then obj.Enabled=true end end
			end
			tp(step2);task.wait(0.1);tp(step3)
		end)
		local _c=LocalPlayer.Character; local _hum=_c and _c:FindFirstChildOfClass("Humanoid")
		if _hum then lastKnownHealth=_hum.Health end
		brainrotReturnCooldown=false
		if G_autoPlayAfterTP and G_myPlotSide then
			task.wait(0.3); local side2=G_myPlotSide
			if fullAutoPlayLeftEnabled then stopFullAutoLeft();fullAutoPlayLeftEnabled=false; if fullAutoLeftSetter then fullAutoLeftSetter(false) end end
			if fullAutoPlayRightEnabled then stopFullAutoRight();fullAutoPlayRightEnabled=false; if fullAutoRightSetter then fullAutoRightSetter(false) end end
			task.wait(0.1)
			if side2=="left" then fullAutoPlayLeftEnabled=true; if fullAutoLeftSetter then fullAutoLeftSetter(true) end;startFullAutoLeft()
			elseif side2=="right" then fullAutoPlayRightEnabled=true; if fullAutoRightSetter then fullAutoRightSetter(true) end;startFullAutoRight() end
		end
	end)
end
RunService.Heartbeat:Connect(function()
	if not G_tpAutoEnabled then return end; if brainrotReturnCooldown then return end; if G_countdownActive then return end
	local char=LocalPlayer.Character; if not char then return end
	local hum=char:FindFirstChildOfClass("Humanoid"); if not hum then return end
	local hrp2=char:FindFirstChild("HumanoidRootPart")
	if hrp2 and hrp2.Anchored then lastKnownHealth=hum.Health;return end
	local hp=hum.Health; local st=hum:GetState()
	local rag=st==Enum.HumanoidStateType.Physics or st==Enum.HumanoidStateType.Ragdoll or st==Enum.HumanoidStateType.FallingDown
	local wasHit=hp<lastKnownHealth-1; lastKnownHealth=hp
	if not (wasHit or rag) then return end
	if fullAutoPlayLeftEnabled then stopFullAutoLeft();fullAutoPlayLeftEnabled=false; if fullAutoLeftSetter then fullAutoLeftSetter(false) end end
	if fullAutoPlayRightEnabled then stopFullAutoRight();fullAutoPlayRightEnabled=false; if fullAutoRightSetter then fullAutoRightSetter(false) end end
	local side=G_myPlotSide
	if side=="left" then doReturnTeleport("left") elseif side=="right" then doReturnTeleport("right") end
end)
-- ============================================================
-- COUNTDOWN + FULL AUTO PLAY (original K7 logic)
-- ============================================================
local function monitorCountdown(snd)
	if snd.Name~="Countdown" or not snd:IsA("Sound") then return end
	local triggered,conn=false,nil; G_countdownActive=true
	conn=RunService.Heartbeat:Connect(function()
		if not snd or not snd.Parent or not snd.Playing then G_countdownActive=false; if conn then conn:Disconnect();conn=nil end;return end
		local ct=snd.TimePosition
		if ct>=COUNTDOWN_TARGET and not triggered then
			triggered=true;G_countdownActive=false; if conn then conn:Disconnect();conn=nil end
			if not G_tpAutoEnabled then return end; local side=G_myPlotSide; if not side then return end
			if fullAutoPlayLeftEnabled then stopFullAutoLeft();fullAutoPlayLeftEnabled=false; if fullAutoLeftSetter then fullAutoLeftSetter(false) end end
			if fullAutoPlayRightEnabled then stopFullAutoRight();fullAutoPlayRightEnabled=false; if fullAutoRightSetter then fullAutoRightSetter(false) end end
			task.wait(0.1)
			if side=="left" then fullAutoPlayRightEnabled=true; if fullAutoRightSetter then fullAutoRightSetter(true) end;startFullAutoRight()
			elseif side=="right" then fullAutoPlayLeftEnabled=true; if fullAutoLeftSetter then fullAutoLeftSetter(true) end;startFullAutoLeft() end
		end
		if ct>COUNTDOWN_TARGET+2 then G_countdownActive=false; if conn then conn:Disconnect();conn=nil end end
	end)
end
workspace.ChildAdded:Connect(function(child) if child.Name=="Countdown" and child:IsA("Sound") then monitorCountdown(child) end end)
do local ex=workspace:FindFirstChild("Countdown"); if ex and ex:IsA("Sound") then monitorCountdown(ex) end end
local FAP_L1=Vector3.new(-476.48,-6.28,92.73); local FAP_L2=Vector3.new(-482.85,-5.03,93.13); local FAP_L3=Vector3.new(-475.68,-6.89,92.76); local FAP_L4=Vector3.new(-476.50,-6.46,27.58); local FAP_L5=Vector3.new(-482.42,-5.03,27.84)
local FAP_R1=Vector3.new(-476.16,-6.52,25.62); local FAP_R2=Vector3.new(-483.06,-5.03,27.51); local FAP_R3=Vector3.new(-476.21,-6.63,27.46); local FAP_R4=Vector3.new(-476.66,-6.39,92.44); local FAP_R5=Vector3.new(-481.94,-5.03,92.42)
local FACE_FAP_L=Vector3.new(-482.25,-4.96,92.09); local FACE_FAP_R=Vector3.new(-482.06,-6.93,35.47)
local FAP_LeftPhase=1; local FAP_RightPhase=1
local function makeFullAutoPlay(getEnabled,setEnabled,getPhase,setPhase,getConn,setConn,getVisual,getMobSetter,p1,p2,p3,p4,p5,faceTgt)
	local pts={p1,p2,p3,p4,p5}
	local function stop() local c=getConn(); if c then c:Disconnect();setConn(nil) end;setPhase(1); local char=LocalPlayer.Character; if char then local hum2=char:FindFirstChildOfClass("Humanoid"); if hum2 then hum2:Move(Vector3.zero,false) end end end
	local function start()
		stop();setPhase(1)
		setConn(RunService.Heartbeat:Connect(function()
			if not getEnabled() then return end
			local char=LocalPlayer.Character; if not char then return end
			local rp=char:FindFirstChild("HumanoidRootPart"); local hum2=char:FindFirstChildOfClass("Humanoid"); if not rp or not hum2 then return end
			local ph=getPhase(); local tgt=pts[ph]; local spd
			if fastestStealEnabled and ph>=4 then local dist=Vector3.new(tgt.X-rp.Position.X,0,tgt.Z-rp.Position.Z).Magnitude; if dist>0.1 then spd=math.clamp(dist/1.653,28,29) else spd=CARRY_SPEED end
			else spd=ph>=3 and CARRY_SPEED or NORMAL_SPEED end
			if (Vector3.new(tgt.X,rp.Position.Y,tgt.Z)-rp.Position).Magnitude<1 then
				if ph==5 then hum2:Move(Vector3.zero,false);rp.AssemblyLinearVelocity=Vector3.zero;setEnabled(false);stop(); local v=getVisual(); if v then v(false) end; local mv=getMobSetter(); if mv then mv(false) end
					if faceTgt then local dir=Vector3.new(faceTgt.X,rp.Position.Y,faceTgt.Z)-rp.Position; if dir.Magnitude>0.01 then rp.CFrame=CFrame.new(rp.Position,rp.Position+dir.Unit) end end;return
				elseif ph==2 then hum2:Move(Vector3.zero,false);rp.AssemblyLinearVelocity=Vector3.zero;task.wait(0.05);setPhase(3);return
				else setPhase(ph+1);return end
			end
			local d=tgt-rp.Position; local mv=Vector3.new(d.X,0,d.Z).Unit
			hum2:Move(mv,false);rp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,rp.AssemblyLinearVelocity.Y,mv.Z*spd)
		end))
	end
	return start,stop
end
local startFullAutoLeft,stopFullAutoLeft=makeFullAutoPlay(function() return fullAutoPlayLeftEnabled end,function(v) fullAutoPlayLeftEnabled=v end,function() return FAP_LeftPhase end,function(v) FAP_LeftPhase=v end,function() return fullAutoPlayLeftConn end,function(v) fullAutoPlayLeftConn=v end,function() return fullAutoLeftSetter end,function() return nil end,FAP_L1,FAP_L2,FAP_L3,FAP_L4,FAP_L5,FACE_FAP_L)
local startFullAutoRight,stopFullAutoRight=makeFullAutoPlay(function() return fullAutoPlayRightEnabled end,function(v) fullAutoPlayRightEnabled=v end,function() return FAP_RightPhase end,function(v) FAP_RightPhase=v end,function() return fullAutoPlayRightConn end,function(v) fullAutoPlayRightConn=v end,function() return fullAutoRightSetter end,function() return nil end,FAP_R1,FAP_R2,FAP_R3,FAP_R4,FAP_R5,FACE_FAP_R)
-- ============================================================
-- BAT SYSTEM (original K7 logic)
-- ============================================================
local function findBat()
	local c=LocalPlayer.Character; if not c then return nil end
	local bp=LocalPlayer:FindFirstChildOfClass("Backpack")
	local SlapList={"Bat","Slap","Iron Slap","Gold Slap","Diamond Slap","Emerald Slap","Ruby Slap","Dark Matter Slap","Flame Slap","Nuclear Slap","Galaxy Slap","Glitched Slap"}
	for _,name in ipairs(SlapList) do local t=c:FindFirstChild(name) or (bp and bp:FindFirstChild(name)); if t then return t end end
	for _,ch in ipairs(c:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end
	if bp then for _,ch in ipairs(bp:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end end
	return nil
end
local function getClosestPlayer()
	local c=LocalPlayer.Character; if not c then return nil end
	local h2=c:FindFirstChild("HumanoidRootPart"); if not h2 then return nil end
	local cp,cd=nil,math.huge
	for _,p in pairs(Players:GetPlayers()) do if p~=LocalPlayer and p.Character then local tr=p.Character:FindFirstChild("HumanoidRootPart"); if tr then local d=(h2.Position-tr.Position).Magnitude; if d<cd then cd=d;cp=p end end end end
	return cp
end
local _batT=0
RunService.Heartbeat:Connect(function()
	local now=tick()
	if autoBatToggled and now-_batT>=1/30 then
		_batT=now; local c=LocalPlayer.Character; if c then local h2=c:FindFirstChild("HumanoidRootPart"); if h2 then local target=getClosestPlayer(); if target and target.Character then local tr=target.Character:FindFirstChild("HumanoidRootPart"); if tr then local fp=tr.Position+tr.CFrame.LookVector*1.5; local dir=(fp-h2.Position).Unit;h2.AssemblyLinearVelocity=Vector3.new(dir.X*56.5,dir.Y*56.5,dir.Z*56.5) end end end end
	end
	if autoBatToggled then
		local c=LocalPlayer.Character; if c then local bat=findBat(); if bat then if bat.Parent~=c then local hum2=c:FindFirstChildOfClass("Humanoid"); if hum2 then hum2:EquipTool(bat) end end; if now-lastBatSwing>=BAT_SWING_COOLDOWN then lastBatSwing=now;pcall(function() bat:Activate() end) end end end
	end
end)
-- ============================================================
-- CONFIG SAVE / LOAD (original K7 logic)
-- ============================================================
local function saveConfig()
	local cfg={normalSpeed=NORMAL_SPEED,carrySpeed=CARRY_SPEED,laggerSpeed=LAGGER_SPEED,fovValue=FOV_VALUE,autoBatKey=Keybinds.AutoBat.Name,speedToggleKey=Keybinds.SpeedToggle.Name,laggerToggleKey=Keybinds.LaggerToggle.Name,uiToggle=Keybinds.UIToggle.Name,infiniteJumpKey=Keybinds.InfiniteJump.Name,dropBrainrotKey=Keybinds.DropBrainrot.Name,floatToggleKey=Keybinds.FloatToggle.Name,autoStealEnabled=Enabled.AutoSteal,grabRadius=Settings.StealRadius,stealDuration=Settings.StealDuration,antiRagdoll=Enabled.AntiRagdoll,infiniteJump=Enabled.InfiniteJump,optimizer=Enabled.Optimizer,unwalk=Enabled.Unwalk,removeAccessories=Enabled.RemoveAccessories,carryMode=speedToggled,laggerMode=laggerToggled,floatEnabled=floatEnabled,floatHeight=floatHeight,fullAutoLeftKey=Keybinds.FullAutoLeft.Name,fullAutoRightKey=Keybinds.FullAutoRight.Name,tpDownKey=Keybinds.TPDown.Name,fastestSteal=fastestStealEnabled,autoSwing=autoSwingEnabled,noCamCollision=noCamCollisionEnabled,ultraMode=ultraModeEnabled,tpAutoEnabled=G_tpAutoEnabled,autoPlayAfterTP=G_autoPlayAfterTP,harderHitAnim=harderHitAnimEnabled,medusaCounter=medusaCounterEnabled,brainrotReturnLeft=brainrotReturnLeftEnabled,brainrotReturnRight=brainrotReturnRightEnabled}
	if writefile then pcall(function() writefile("K7HubConfig.json",HttpService:JSONEncode(cfg)) end) end
end
task.spawn(function() while task.wait(5) do saveConfig() end end)
local function loadConfig()
	if not (isfile and isfile("K7HubConfig.json")) then return end
	local ok,cfg=pcall(function() return HttpService:JSONDecode(readfile("K7HubConfig.json")) end)
	if not ok or not cfg then return end
	if cfg.normalSpeed then NORMAL_SPEED=cfg.normalSpeed end; if cfg.carrySpeed then CARRY_SPEED=cfg.carrySpeed end; if cfg.laggerSpeed then LAGGER_SPEED=cfg.laggerSpeed end; if cfg.fovValue then FOV_VALUE=cfg.fovValue end
	if cfg.autoBatKey and Enum.KeyCode[cfg.autoBatKey] then Keybinds.AutoBat=Enum.KeyCode[cfg.autoBatKey] end
	if cfg.speedToggleKey and Enum.KeyCode[cfg.speedToggleKey] then Keybinds.SpeedToggle=Enum.KeyCode[cfg.speedToggleKey] end
	if cfg.laggerToggleKey and Enum.KeyCode[cfg.laggerToggleKey] then Keybinds.LaggerToggle=Enum.KeyCode[cfg.laggerToggleKey] end
	if cfg.infiniteJumpKey and Enum.KeyCode[cfg.infiniteJumpKey] then Keybinds.InfiniteJump=Enum.KeyCode[cfg.infiniteJumpKey] end
	if cfg.dropBrainrotKey and Enum.KeyCode[cfg.dropBrainrotKey] then Keybinds.DropBrainrot=Enum.KeyCode[cfg.dropBrainrotKey] end
	if cfg.floatToggleKey and Enum.KeyCode[cfg.floatToggleKey] then Keybinds.FloatToggle=Enum.KeyCode[cfg.floatToggleKey] end
	if cfg.fullAutoLeftKey and Enum.KeyCode[cfg.fullAutoLeftKey] then Keybinds.FullAutoLeft=Enum.KeyCode[cfg.fullAutoLeftKey] end
	if cfg.fullAutoRightKey and Enum.KeyCode[cfg.fullAutoRightKey] then Keybinds.FullAutoRight=Enum.KeyCode[cfg.fullAutoRightKey] end
	if cfg.tpDownKey and Enum.KeyCode[cfg.tpDownKey] then Keybinds.TPDown=Enum.KeyCode[cfg.tpDownKey] end
	if cfg.grabRadius then Settings.StealRadius=cfg.grabRadius;Values.STEAL_RADIUS=cfg.grabRadius end
	if cfg.stealDuration then Settings.StealDuration=cfg.stealDuration;Values.STEAL_DURATION=cfg.stealDuration end
	if cfg.antiRagdoll~=nil then Enabled.AntiRagdoll=cfg.antiRagdoll end
	if cfg.autoStealEnabled~=nil then Enabled.AutoSteal=cfg.autoStealEnabled;Settings.AutoStealEnabled=cfg.autoStealEnabled end
	if cfg.infiniteJump~=nil then Enabled.InfiniteJump=cfg.infiniteJump end
	if cfg.optimizer~=nil then Enabled.Optimizer=cfg.optimizer end
	if cfg.unwalk~=nil then Enabled.Unwalk=cfg.unwalk end
	if cfg.removeAccessories~=nil then Enabled.RemoveAccessories=cfg.removeAccessories end
	if cfg.floatHeight then floatHeight=cfg.floatHeight end
	if cfg.floatEnabled~=nil then floatEnabled=cfg.floatEnabled; task.defer(function() if floatEnabled then startFloat() end end) end
	if cfg.fastestSteal~=nil then fastestStealEnabled=cfg.fastestSteal end
	if cfg.autoSwing~=nil then autoSwingEnabled=cfg.autoSwing end
	if cfg.noCamCollision~=nil then noCamCollisionEnabled=cfg.noCamCollision; if noCamCollisionEnabled then enableNoCameraCollision() end end
	if cfg.ultraMode~=nil then ultraModeEnabled=cfg.ultraMode; if ultraModeEnabled then enableUltraMode() end end
	if cfg.tpAutoEnabled~=nil then G_tpAutoEnabled=cfg.tpAutoEnabled; if G_tpAutoEnabled then task.spawn(function() refreshMyPlotSide() end) end end
	if cfg.autoPlayAfterTP~=nil then G_autoPlayAfterTP=cfg.autoPlayAfterTP end
	if cfg.brainrotReturnLeft~=nil then brainrotReturnLeftEnabled=cfg.brainrotReturnLeft end
	if cfg.brainrotReturnRight~=nil then brainrotReturnRightEnabled=cfg.brainrotReturnRight end
	if cfg.harderHitAnim~=nil then harderHitAnimEnabled=cfg.harderHitAnim; if harderHitAnimEnabled then task.spawn(function() task.wait(3); startHarderHitAnim() end) end end
	if cfg.medusaCounter~=nil then medusaCounterEnabled=cfg.medusaCounter; if medusaCounterEnabled then task.spawn(function() task.wait(3); setupMedusaCounter(LocalPlayer.Character) end) end end
	if cfg.carryMode~=nil then speedToggled=cfg.carryMode end
	if cfg.laggerMode~=nil then laggerToggled=cfg.laggerMode end
end
loadConfig()
-- ============================================================
-- SWEETY HUB VOID BLUE GUI
-- ============================================================
local function _buildGUI()
-- VOID BLUE PALETTE
local SB   = Color3.fromRGB(8,10,18)
local SC   = Color3.fromRGB(12,15,28)
local SCH  = Color3.fromRGB(16,20,38)
local SH   = Color3.fromRGB(6,8,14)
local SA   = Color3.fromRGB(60,140,255)
local SAD  = Color3.fromRGB(20,50,120)
local SS   = Color3.fromRGB(40,80,180)
local SSD  = Color3.fromRGB(20,35,80)
local ST   = Color3.fromRGB(220,235,255)
local SM   = Color3.fromRGB(100,120,170)
local SDM  = Color3.fromRGB(50,65,110)
local SOFF = Color3.fromRGB(18,22,45)
local SRED = Color3.fromRGB(220,30,30)
local SW   = Color3.fromRGB(255,255,255)
local SMINT= Color3.fromRGB(60,255,160)
local SAMB = Color3.fromRGB(255,190,60)
local SCYAN= Color3.fromRGB(60,210,255)
local TIF  = TweenInfo.new(0.12,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
local function tw(o,i,p) TweenService:Create(o,i,p):Play() end

-- destroy old gui if re-exec
local old=LocalPlayer.PlayerGui:FindFirstChild("SweetyK7Hub"); if old then old:Destroy() end
gui=Instance.new("ScreenGui"); gui.Name="SweetyK7Hub"; gui.ResetOnSpawn=false
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.DisplayOrder=99; gui.IgnoreGuiInset=true
gui.Parent=LocalPlayer.PlayerGui

-- HUD
local HUD=Instance.new("Frame",gui); HUD.Size=UDim2.new(0,200,0,28); HUD.Position=UDim2.new(0.5,-100,0,8)
HUD.BackgroundColor3=Color3.fromRGB(4,6,14); HUD.BackgroundTransparency=0.1; HUD.BorderSizePixel=0; HUD.ZIndex=20
Instance.new("UICorner",HUD).CornerRadius=UDim.new(0,10)
local hudSt=Instance.new("UIStroke",HUD); hudSt.Color=SS; hudSt.Thickness=1; hudSt.Transparency=0.3
local fpsPill=Instance.new("Frame",HUD); fpsPill.Size=UDim2.new(0,88,0,20); fpsPill.Position=UDim2.new(0,6,0.5,-10); fpsPill.BackgroundColor3=SAD; fpsPill.BorderSizePixel=0; Instance.new("UICorner",fpsPill).CornerRadius=UDim.new(0,6)
local fpsTag=Instance.new("TextLabel",fpsPill); fpsTag.Size=UDim2.new(0,28,1,0); fpsTag.BackgroundTransparency=1; fpsTag.Text="FPS"; fpsTag.TextSize=9; fpsTag.Font=Enum.Font.GothamBold; fpsTag.TextColor3=SA
local fpsLbl=Instance.new("TextLabel",fpsPill); fpsLbl.Size=UDim2.new(1,-28,1,0); fpsLbl.Position=UDim2.new(0,28,0,0); fpsLbl.BackgroundTransparency=1; fpsLbl.Text="--"; fpsLbl.Font=Enum.Font.GothamBold; fpsLbl.TextSize=11; fpsLbl.TextColor3=ST; fpsLbl.TextXAlignment=Enum.TextXAlignment.Left
local divH=Instance.new("Frame",HUD); divH.Size=UDim2.new(0,1,0,16); divH.Position=UDim2.new(0.5,0,0.5,-8); divH.BackgroundColor3=SSD; divH.BorderSizePixel=0
local pingPill=Instance.new("Frame",HUD); pingPill.Size=UDim2.new(0,88,0,20); pingPill.Position=UDim2.new(1,-94,0.5,-10); pingPill.BackgroundColor3=SAD; pingPill.BorderSizePixel=0; Instance.new("UICorner",pingPill).CornerRadius=UDim.new(0,6)
local pingTag=Instance.new("TextLabel",pingPill); pingTag.Size=UDim2.new(0,28,1,0); pingTag.BackgroundTransparency=1; pingTag.Text="MS"; pingTag.TextSize=9; pingTag.Font=Enum.Font.GothamBold; pingTag.TextColor3=SA
local pingLbl=Instance.new("TextLabel",pingPill); pingLbl.Size=UDim2.new(1,-28,1,0); pingLbl.Position=UDim2.new(0,28,0,0); pingLbl.BackgroundTransparency=1; pingLbl.Text="--"; pingLbl.Font=Enum.Font.GothamBold; pingLbl.TextSize=11; pingLbl.TextColor3=ST; pingLbl.TextXAlignment=Enum.TextXAlignment.Left
local fpsAcc=0; local fpsT=0
RunService.Heartbeat:Connect(function(dt)
	fpsT=fpsT+dt; fpsAcc=fpsAcc+1
	if fpsT>=0.5 then
		local f=math.round(fpsAcc/fpsT); fpsLbl.Text=f.." FPS"; fpsLbl.TextColor3=f>=50 and SMINT or (f>=30 and SAMB or SRED); fpsT=0; fpsAcc=0
	end
	pcall(function() local ping=math.round(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()); pingLbl.Text=ping.." ms"; pingLbl.TextColor3=ping<=80 and SMINT or (ping<=150 and SAMB or SRED) end)
end)

-- LOADING SCREEN (void blue, clean card, NO circle glow, NO grid)
local Loader=Instance.new("Frame",gui); Loader.Size=UDim2.new(1,0,1,0); Loader.BackgroundColor3=Color3.fromRGB(3,5,12); Loader.BorderSizePixel=0; Loader.ZIndex=50
local LoadCard=Instance.new("Frame",Loader); LoadCard.Size=UDim2.new(0,400,0,220); LoadCard.Position=UDim2.new(0.5,-200,0.5,-110); LoadCard.BackgroundColor3=Color3.fromRGB(7,10,22); LoadCard.BorderSizePixel=0; LoadCard.ZIndex=51; Instance.new("UICorner",LoadCard).CornerRadius=UDim.new(0,18)
local cSt=Instance.new("UIStroke",LoadCard); cSt.Color=SA; cSt.Thickness=1.5; cSt.Transparency=0.3
local topStripe=Instance.new("Frame",LoadCard); topStripe.Size=UDim2.new(1,0,0,3); topStripe.BackgroundColor3=SA; topStripe.BorderSizePixel=0; topStripe.ZIndex=53; Instance.new("UICorner",topStripe).CornerRadius=UDim.new(0,18)
local tsg=Instance.new("UIGradient",topStripe); tsg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(30,80,200)),ColorSequenceKeypoint.new(0.5,SA),ColorSequenceKeypoint.new(1,Color3.fromRGB(120,200,255))})
local iconBg=Instance.new("Frame",LoadCard); iconBg.Size=UDim2.new(0,56,0,56); iconBg.Position=UDim2.new(0.5,-28,0,18); iconBg.BackgroundColor3=SAD; iconBg.BorderSizePixel=0; iconBg.ZIndex=53; Instance.new("UICorner",iconBg).CornerRadius=UDim.new(1,0)
local iconRing=Instance.new("UIStroke",iconBg); iconRing.Color=SA; iconRing.Thickness=2; iconRing.Transparency=0.1
local iconLbl=Instance.new("TextLabel",iconBg); iconLbl.Size=UDim2.new(1,0,1,0); iconLbl.BackgroundTransparency=1; iconLbl.Text="K7"; iconLbl.TextSize=22; iconLbl.Font=Enum.Font.GothamBlack; iconLbl.TextColor3=SA; iconLbl.ZIndex=54
local lbTitle=Instance.new("TextLabel",LoadCard); lbTitle.Size=UDim2.new(1,-20,0,36); lbTitle.Position=UDim2.new(0,10,0,82); lbTitle.BackgroundTransparency=1; lbTitle.Text="K7 HUB"; lbTitle.TextSize=28; lbTitle.Font=Enum.Font.GothamBlack; lbTitle.TextColor3=ST; lbTitle.ZIndex=52
local lbDiv=Instance.new("Frame",LoadCard); lbDiv.Size=UDim2.new(0,180,0,2); lbDiv.Position=UDim2.new(0.5,-90,0,122); lbDiv.BackgroundColor3=SA; lbDiv.BorderSizePixel=0; lbDiv.ZIndex=53; Instance.new("UICorner",lbDiv).CornerRadius=UDim.new(1,0)
local divGrad=Instance.new("UIGradient",lbDiv); divGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(20,60,180)),ColorSequenceKeypoint.new(1,SA)})
local lbSub=Instance.new("TextLabel",LoadCard); lbSub.Size=UDim2.new(1,-20,0,16); lbSub.Position=UDim2.new(0,10,0,130); lbSub.BackgroundTransparency=1; lbSub.Text="Steal a Brainrot  |  discord.gg/XuKmRwXc4w"; lbSub.TextSize=10; lbSub.Font=Enum.Font.GothamMedium; lbSub.TextColor3=Color3.fromRGB(80,110,180); lbSub.ZIndex=52
local barTrack=Instance.new("Frame",LoadCard); barTrack.Size=UDim2.new(0,320,0,5); barTrack.Position=UDim2.new(0.5,-160,0,162); barTrack.BackgroundColor3=Color3.fromRGB(12,18,40); barTrack.BorderSizePixel=0; barTrack.ZIndex=52; Instance.new("UICorner",barTrack).CornerRadius=UDim.new(1,0)
local barFill=Instance.new("Frame",barTrack); barFill.Size=UDim2.new(0,0,1,0); barFill.BackgroundColor3=SA; barFill.BorderSizePixel=0; barFill.ZIndex=53; Instance.new("UICorner",barFill).CornerRadius=UDim.new(1,0)
local bfg=Instance.new("UIGradient",barFill); bfg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(30,80,200)),ColorSequenceKeypoint.new(0.6,SA),ColorSequenceKeypoint.new(1,Color3.fromRGB(120,200,255))})
local loadSt=Instance.new("TextLabel",LoadCard); loadSt.Size=UDim2.new(1,-20,0,14); loadSt.Position=UDim2.new(0,10,0,178); loadSt.BackgroundTransparency=1; loadSt.TextSize=10; loadSt.Font=Enum.Font.GothamMedium; loadSt.TextColor3=Color3.fromRGB(50,80,140); loadSt.ZIndex=52; loadSt.Text="Initializing..."
TweenService:Create(barFill,TweenInfo.new(2.0,Enum.EasingStyle.Quart,Enum.EasingDirection.InOut),{Size=UDim2.new(1,0,1,0)}):Play()
local loadMsgs={"Initializing features...","Loading keybinds...","Preparing auto steal...","Anti-ragdoll ready...","Almost done!"}; local loadMsgI=1
task.spawn(function() while Loader and Loader.Parent do task.wait(0.4); loadMsgI=loadMsgI%#loadMsgs+1; pcall(function() loadSt.Text=loadMsgs[loadMsgI] end) end end)
task.delay(2.2,function()
	tw(LoadCard,TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{BackgroundTransparency=1})
	tw(Loader,TweenInfo.new(0.45,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{BackgroundTransparency=1})
	task.wait(0.5); if Loader and Loader.Parent then Loader:Destroy() end
end)

-- MAIN PANEL
local Shadow=Instance.new("Frame",gui); Shadow.Size=UDim2.new(0,292,0,10); Shadow.Position=UDim2.new(0.5,-146,0.5,-280)
Shadow.BackgroundColor3=SA; Shadow.BackgroundTransparency=1; Shadow.BorderSizePixel=0; Shadow.AutomaticSize=Enum.AutomaticSize.Y
Instance.new("UICorner",Shadow).CornerRadius=UDim.new(0,20)
main=Instance.new("Frame",Shadow); main.Size=UDim2.new(0,284,0,0); main.Position=UDim2.new(0,4,0,4)
main.BackgroundColor3=SB; main.BackgroundTransparency=1; main.BorderSizePixel=0; main.ClipsDescendants=true; main.AutomaticSize=Enum.AutomaticSize.Y
Instance.new("UICorner",main).CornerRadius=UDim.new(0,16)
local PStroke=Instance.new("UIStroke",main); PStroke.Color=SS; PStroke.Thickness=1.5; PStroke.Transparency=0.25

-- HEADER
local Header=Instance.new("Frame",main); Header.Size=UDim2.new(1,0,0,54); Header.BackgroundColor3=SH; Header.BorderSizePixel=0
Instance.new("UICorner",Header).CornerRadius=UDim.new(0,16)
local hFix=Instance.new("Frame",Header); hFix.Size=UDim2.new(1,0,0,16); hFix.Position=UDim2.new(0,0,1,-16); hFix.BackgroundColor3=SH; hFix.BorderSizePixel=0
local hIco=Instance.new("TextLabel",Header); hIco.Size=UDim2.new(0,32,0,32); hIco.Position=UDim2.new(0,12,0.5,-16); hIco.BackgroundColor3=SAD; hIco.BorderSizePixel=0; hIco.Text="K7"; hIco.TextSize=13; hIco.Font=Enum.Font.GothamBlack; hIco.TextColor3=SA; Instance.new("UICorner",hIco).CornerRadius=UDim.new(0,8)
local hTL=Instance.new("TextLabel",Header); hTL.Size=UDim2.new(0,160,0,20); hTL.Position=UDim2.new(0,52,0,8); hTL.BackgroundTransparency=1; hTL.Text="K7 HUB"; hTL.TextSize=15; hTL.Font=Enum.Font.GothamBlack; hTL.TextColor3=SW; hTL.TextXAlignment=Enum.TextXAlignment.Left
local hSL=Instance.new("TextLabel",Header); hSL.Size=UDim2.new(0,200,0,13); hSL.Position=UDim2.new(0,52,0,29); hSL.BackgroundTransparency=1; hSL.Text="discord.gg/XuKmRwXc4w"; hSL.TextSize=9; hSL.Font=Enum.Font.GothamMedium; hSL.TextColor3=SM; hSL.TextXAlignment=Enum.TextXAlignment.Left
local hChev=Instance.new("TextButton",Header); hChev.Size=UDim2.new(0,28,0,28); hChev.Position=UDim2.new(1,-34,0.5,-14); hChev.BackgroundColor3=SAD; hChev.BorderSizePixel=0; hChev.Text="v"; hChev.TextSize=11; hChev.Font=Enum.Font.GothamBold; hChev.TextColor3=SM; hChev.AutoButtonColor=false; hChev.ZIndex=10; Instance.new("UICorner",hChev).CornerRadius=UDim.new(0,6)
local hLine=Instance.new("Frame",Header); hLine.Size=UDim2.new(0.9,0,0,1); hLine.Position=UDim2.new(0.05,0,1,-1); hLine.BackgroundColor3=SSD; hLine.BorderSizePixel=0; Instance.new("UICorner",hLine).CornerRadius=UDim.new(1,0)

local isMin=false; local TabBar,ContentWrap
local function setMin(m)
	isMin=m; hChev.Text=m and "^" or "v"
	if TabBar then TabBar.Visible=not m end
	if ContentWrap then ContentWrap.Visible=not m end
	if m then
		main.AutomaticSize=Enum.AutomaticSize.None; Shadow.AutomaticSize=Enum.AutomaticSize.None
		tw(main,TIF,{Size=UDim2.new(0,284,0,54)}); tw(Shadow,TIF,{Size=UDim2.new(0,292,0,62)})
	else
		tw(main,TIF,{Size=UDim2.new(0,284,0,0)})
		task.delay(0.15,function() main.AutomaticSize=Enum.AutomaticSize.Y; Shadow.AutomaticSize=Enum.AutomaticSize.Y end)
	end
end
hChev.MouseButton1Click:Connect(function() setMin(not isMin) end)
do
	local drag=false; local ds,ss
	Header.InputBegan:Connect(function(inp)
		if inp.UserInputType==Enum.UserInputType.MouseButton1 then
			local mp=inp.Position; local cp=hChev.AbsolutePosition; local cs=hChev.AbsoluteSize
			if mp.X>=cp.X and mp.X<=cp.X+cs.X and mp.Y>=cp.Y and mp.Y<=cp.Y+cs.Y then return end
			drag=true; ds=inp.Position; ss=Shadow.Position
			inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then drag=false end end)
		end
	end)
	UserInputService.InputChanged:Connect(function(inp)
		if drag and inp.UserInputType==Enum.UserInputType.MouseMovement then
			local d=inp.Position-ds; Shadow.Position=UDim2.new(ss.X.Scale,ss.X.Offset+d.X,ss.Y.Scale,ss.Y.Offset+d.Y)
		end
	end)
end
local reopenBtn=Instance.new("TextButton",gui); reopenBtn.Size=UDim2.new(0,45,0,45); reopenBtn.Position=UDim2.new(0,10,0,50)
reopenBtn.BackgroundColor3=SA; reopenBtn.BorderSizePixel=0; reopenBtn.Text="K7"; reopenBtn.TextColor3=SW; reopenBtn.Font=Enum.Font.GothamBlack; reopenBtn.TextSize=14; reopenBtn.ZIndex=20; reopenBtn.Visible=false; Instance.new("UICorner",reopenBtn).CornerRadius=UDim.new(0,10)
reopenBtn.MouseButton1Click:Connect(function() Shadow.Visible=true; reopenBtn.Visible=false end)

-- TAB BAR
TabBar=Instance.new("Frame",main); TabBar.Size=UDim2.new(1,0,0,34); TabBar.Position=UDim2.new(0,0,0,54); TabBar.BackgroundColor3=SH; TabBar.BorderSizePixel=0
local tbLine=Instance.new("Frame",TabBar); tbLine.Size=UDim2.new(1,0,0,1); tbLine.Position=UDim2.new(0,0,1,-1); tbLine.BackgroundColor3=SSD; tbLine.BorderSizePixel=0
local curPage=nil
local allTabsList={}
local function mkTabBtn(lbl,xScale,wScale)
	local b=Instance.new("TextButton",TabBar); b.Size=UDim2.new(wScale,0,1,0); b.Position=UDim2.new(xScale,0,0,0)
	b.BackgroundTransparency=1; b.Text=lbl; b.Font=Enum.Font.GothamBold; b.TextSize=8; b.TextColor3=SM; b.AutoButtonColor=false
	local u=Instance.new("Frame",b); u.Size=UDim2.new(0.7,0,0,2); u.Position=UDim2.new(0.15,0,1,-2); u.BackgroundColor3=SA; u.BorderSizePixel=0; u.BackgroundTransparency=1; Instance.new("UICorner",u).CornerRadius=UDim.new(1,0)
	return b,u
end
ContentWrap=Instance.new("ScrollingFrame",main); ContentWrap.Size=UDim2.new(1,0,0,380); ContentWrap.Position=UDim2.new(0,0,0,88)
ContentWrap.BackgroundTransparency=1; ContentWrap.BorderSizePixel=0; ContentWrap.ScrollBarThickness=3; ContentWrap.ScrollBarImageColor3=SS
ContentWrap.CanvasSize=UDim2.new(0,0,0,0); ContentWrap.AutomaticCanvasSize=Enum.AutomaticSize.Y; ContentWrap.ElasticBehavior=Enum.ElasticBehavior.Never
local function mkPage()
	local p=Instance.new("Frame",ContentWrap); p.Size=UDim2.new(1,0,0,0); p.BackgroundTransparency=1; p.AutomaticSize=Enum.AutomaticSize.Y; p.Visible=false
	local ll=Instance.new("UIListLayout",p); ll.Padding=UDim.new(0,6); ll.HorizontalAlignment=Enum.HorizontalAlignment.Center; ll.SortOrder=Enum.SortOrder.LayoutOrder
	local pad=Instance.new("UIPadding",p); pad.PaddingTop=UDim.new(0,8); pad.PaddingBottom=UDim.new(0,12)
	return p
end
local pgCombat=mkPage(); local pgMove=mkPage(); local pgVisual=mkPage(); local pgAuto=mkPage()
local tCB,tCU=mkTabBtn("Combat",0,0.25)
local tMB,tMU=mkTabBtn("Move",0.25,0.25)
local tVB,tVU=mkTabBtn("Visual",0.5,0.25)
local tAB,tAU=mkTabBtn("Auto",0.75,0.25)
allTabsList={{tCB,tCU,pgCombat},{tMB,tMU,pgMove},{tVB,tVU,pgVisual},{tAB,tAU,pgAuto}}
local function switchTab(page,btn,ul)
	if curPage then curPage.Visible=false end
	for _,t in ipairs(allTabsList) do tw(t[1],TIF,{TextColor3=SM}); tw(t[2],TIF,{BackgroundTransparency=1}) end
	page.Visible=true; curPage=page; ContentWrap.CanvasPosition=Vector2.new(0,0)
	tw(btn,TIF,{TextColor3=SA}); tw(ul,TIF,{BackgroundTransparency=0})
end
tCB.MouseButton1Click:Connect(function() switchTab(pgCombat,tCB,tCU) end)
tMB.MouseButton1Click:Connect(function() switchTab(pgMove,tMB,tMU) end)
tVB.MouseButton1Click:Connect(function() switchTab(pgVisual,tVB,tVU) end)
tAB.MouseButton1Click:Connect(function() switchTab(pgAuto,tAB,tAU) end)

-- SECTION HEADER
local function mkSec(parent,lo,lbl)
	local r=Instance.new("Frame",parent); r.Size=UDim2.new(1,-20,0,20); r.BackgroundTransparency=1; r.LayoutOrder=lo
	local l1=Instance.new("Frame",r); l1.Size=UDim2.new(0.26,0,0,1); l1.Position=UDim2.new(0,0,0.5,0); l1.BackgroundColor3=SSD; l1.BorderSizePixel=0; Instance.new("UICorner",l1).CornerRadius=UDim.new(1,0)
	local lb=Instance.new("TextLabel",r); lb.Size=UDim2.new(0.48,0,1,0); lb.Position=UDim2.new(0.26,0,0,0); lb.BackgroundTransparency=1; lb.Text=lbl; lb.Font=Enum.Font.GothamBold; lb.TextSize=9; lb.TextColor3=SA
	local l2=Instance.new("Frame",r); l2.Size=UDim2.new(0.26,0,0,1); l2.Position=UDim2.new(0.74,0,0.5,0); l2.BackgroundColor3=SSD; l2.BorderSizePixel=0; Instance.new("UICorner",l2).CornerRadius=UDim.new(1,0)
end

-- TOGGLE FACTORY
local function mkToggle(parent,lo,label,keybindName,color,defaultOn,onToggle)
	local safeColor=color or SA
	local card=Instance.new("Frame",parent); card.Size=UDim2.new(1,-20,0,60); card.BackgroundColor3=SC; card.BorderSizePixel=0; card.LayoutOrder=lo; Instance.new("UICorner",card).CornerRadius=UDim.new(0,12)
	local cSt2=Instance.new("UIStroke",card); cSt2.Color=SSD; cSt2.Thickness=1.2; cSt2.Transparency=0.4
	local bar=Instance.new("Frame",card); bar.Size=UDim2.new(0,3,0,32); bar.Position=UDim2.new(0,0,0.5,-16); bar.BackgroundColor3=safeColor; bar.BorderSizePixel=0; Instance.new("UICorner",bar).CornerRadius=UDim.new(1,0)
	local xOff=10; local badge,badgeTxt
	if keybindName and keybindName~="" and Keybinds[keybindName] then
		badge=Instance.new("Frame",card); badge.Size=UDim2.new(0,28,0,20); badge.Position=UDim2.new(0,10,0.5,-10); badge.BackgroundColor3=SA; badge.BackgroundTransparency=0.3; badge.BorderSizePixel=0; badge.ZIndex=5; Instance.new("UICorner",badge).CornerRadius=UDim.new(0,6)
		badgeTxt=Instance.new("TextLabel",badge); badgeTxt.Size=UDim2.new(1,0,1,0); badgeTxt.BackgroundTransparency=1; badgeTxt.Text=Keybinds[keybindName].Name; badgeTxt.TextColor3=SW; badgeTxt.Font=Enum.Font.GothamBold; badgeTxt.TextSize=10; badgeTxt.ZIndex=6
		xOff=45
	else
		local icoBg=Instance.new("Frame",card); icoBg.Size=UDim2.new(0,36,0,36); icoBg.Position=UDim2.new(0,10,0.5,-18); icoBg.BackgroundColor3=SAD; icoBg.BorderSizePixel=0; icoBg.ZIndex=5; Instance.new("UICorner",icoBg).CornerRadius=UDim.new(0,9)
		local icSt=Instance.new("UIStroke",icoBg); icSt.Color=safeColor; icSt.Thickness=1.5; icSt.Transparency=0.4
		xOff=54
	end
	local nameLbl=Instance.new("TextLabel",card); nameLbl.Size=UDim2.new(1,-148,0,20); nameLbl.Position=UDim2.new(0,xOff,0,10); nameLbl.BackgroundTransparency=1; nameLbl.Text=label; nameLbl.Font=Enum.Font.GothamBold; nameLbl.TextSize=12; nameLbl.TextColor3=ST; nameLbl.TextXAlignment=Enum.TextXAlignment.Left
	local hintLbl=Instance.new("TextLabel",card); hintLbl.Size=UDim2.new(1,-148,0,13); hintLbl.Position=UDim2.new(0,xOff,0,30); hintLbl.BackgroundTransparency=1; hintLbl.Text=keybindName and (keybindName~="" and "Hold to rebind" or "") or ""; hintLbl.Font=Enum.Font.Gotham; hintLbl.TextSize=9; hintLbl.TextColor3=defaultOn and safeColor or SDM; hintLbl.TextXAlignment=Enum.TextXAlignment.Left
	local track=Instance.new("Frame",card); track.Size=UDim2.new(0,44,0,24); track.Position=UDim2.new(1,-52,0.5,-12); track.BackgroundColor3=defaultOn and safeColor or SOFF; track.BorderSizePixel=0; Instance.new("UICorner",track).CornerRadius=UDim.new(1,0)
	local trkSt=Instance.new("UIStroke",track); trkSt.Color=defaultOn and safeColor or SSD; trkSt.Thickness=1.2
	local knob=Instance.new("Frame",track); knob.Size=UDim2.new(0,18,0,18); knob.Position=defaultOn and UDim2.fromOffset(23,3) or UDim2.fromOffset(3,3); knob.BackgroundColor3=defaultOn and SW or SM; knob.BorderSizePixel=0; Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)
	local btn=Instance.new("TextButton",card); btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""; btn.ZIndex=5
	card.MouseEnter:Connect(function() tw(card,TIF,{BackgroundColor3=SCH}); cSt2.Transparency=0.1 end)
	card.MouseLeave:Connect(function() tw(card,TIF,{BackgroundColor3=SC}); cSt2.Transparency=0.4 end)
	local isOn=defaultOn; local isHolding=false; local holdStart=0
	local function setVis(on)
		isOn=on
		tw(track,TIF,{BackgroundColor3=on and safeColor or SOFF})
		tw(knob,TIF,{BackgroundColor3=on and SW or SM,Position=on and UDim2.fromOffset(23,3) or UDim2.fromOffset(3,3)})
		trkSt.Color=on and safeColor or SSD; hintLbl.TextColor3=on and safeColor or SDM
		tw(bar,TIF,{BackgroundColor3=on and safeColor or SSD})
	end
	if badge and badgeTxt and keybindName and keybindName~="" then
		local function startKBChange()
			waitingForKeySW=keybindName; badgeTxt.Text="..."
			tw(badge,TIF,{BackgroundColor3=Color3.fromRGB(255,180,100)})
			local conn; conn=UserInputService.InputBegan:Connect(function(inp,_)
				if waitingForKeySW~=keybindName then conn:Disconnect();return end
				if not (inp.UserInputType==Enum.UserInputType.Keyboard or inp.UserInputType==Enum.UserInputType.Gamepad1) then return end
				local kc=inp.KeyCode; if kc==Enum.KeyCode.Unknown then return end
				if kc==Enum.KeyCode.Escape then badgeTxt.Text=Keybinds[keybindName].Name; tw(badge,TIF,{BackgroundColor3=SA,BackgroundTransparency=0.3}); waitingForKeySW=nil;conn:Disconnect();return end
				Keybinds[keybindName]=kc; badgeTxt.Text=kc.Name; tw(badge,TIF,{BackgroundColor3=SA,BackgroundTransparency=0.3}); waitingForKeySW=nil;conn:Disconnect()
			end)
		end
		btn.MouseButton1Down:Connect(function() isHolding=false;holdStart=tick(); task.delay(0.6,function() if holdStart>0 and (tick()-holdStart)>=0.6 then isHolding=true;startKBChange() end end) end)
		btn.MouseButton1Up:Connect(function() if (tick()-holdStart)<0.6 then holdStart=0 end end)
		btn.MouseButton2Click:Connect(function() startKBChange() end)
	end
	btn.MouseButton1Click:Connect(function() if not isHolding then isOn=not isOn;setVis(isOn); if onToggle then onToggle(isOn) end end; isHolding=false;holdStart=0 end)
	return setVis,track,knob
end

-- INPUT ROW
local function mkInput(parent,lo,lbl,defaultTxt,onDone)
	local container=Instance.new("Frame",parent); container.Size=UDim2.new(1,-20,0,48); container.BackgroundColor3=SC; container.BorderSizePixel=0; container.LayoutOrder=lo; Instance.new("UICorner",container).CornerRadius=UDim.new(0,12)
	local cSt2=Instance.new("UIStroke",container); cSt2.Color=SSD; cSt2.Thickness=1.2; cSt2.Transparency=0.4
	local bar2=Instance.new("Frame",container); bar2.Size=UDim2.new(0,3,0,28); bar2.Position=UDim2.new(0,0,0.5,-14); bar2.BackgroundColor3=SA; bar2.BorderSizePixel=0; Instance.new("UICorner",bar2).CornerRadius=UDim.new(1,0)
	local lblEl=Instance.new("TextLabel",container); lblEl.Size=UDim2.new(0.5,0,1,0); lblEl.Position=UDim2.new(0,16,0,0); lblEl.BackgroundTransparency=1; lblEl.Text=lbl; lblEl.TextColor3=ST; lblEl.Font=Enum.Font.GothamBold; lblEl.TextSize=12; lblEl.TextXAlignment=Enum.TextXAlignment.Left
	local box=Instance.new("TextBox",container); box.Size=UDim2.new(0,80,0,28); box.Position=UDim2.new(1,-90,0.5,-14); box.BackgroundColor3=SH; box.BorderSizePixel=0; box.Text=defaultTxt; box.TextColor3=ST; box.Font=Enum.Font.GothamBold; box.TextSize=11; box.ClearTextOnFocus=false; Instance.new("UICorner",box).CornerRadius=UDim.new(0,8)
	local bSt=Instance.new("UIStroke",box); bSt.Color=SA; bSt.Thickness=1; bSt.Transparency=0.5
	box.Focused:Connect(function() tw(bSt,TIF,{Transparency=0}) end)
	box.FocusLost:Connect(function() tw(bSt,TIF,{Transparency=0.5}); if onDone then onDone(box.Text,box) end end)
	container.MouseEnter:Connect(function() tw(container,TIF,{BackgroundColor3=SCH}); cSt2.Transparency=0.1 end)
	container.MouseLeave:Connect(function() tw(container,TIF,{BackgroundColor3=SC}); cSt2.Transparency=0.4 end)
end
-- PROGRESS BAR
local progressBar=Instance.new("Frame",gui); progressBar.Size=UDim2.new(0,500,0,58); progressBar.Position=UDim2.new(0.5,-250,1,-72); progressBar.BackgroundColor3=SB; progressBar.BorderSizePixel=0; progressBar.Active=true; progressBar.ZIndex=50; Instance.new("UICorner",progressBar).CornerRadius=UDim.new(0,10)
local pbSt=Instance.new("UIStroke",progressBar); pbSt.Color=SS; pbSt.Thickness=1.5
do
	local drag,ds,sp=false
	progressBar.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 then drag=true;ds=inp.Position;sp=progressBar.Position; inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then drag=false end end) end end)
	UserInputService.InputChanged:Connect(function(inp) if drag and inp.UserInputType==Enum.UserInputType.MouseMovement then local d=inp.Position-ds;progressBar.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y) end end)
end
ProgressLabel=Instance.new("TextLabel",progressBar); ProgressLabel.Size=UDim2.new(0.35,0,0,18); ProgressLabel.Position=UDim2.new(0,10,0,8); ProgressLabel.BackgroundTransparency=1; ProgressLabel.Text="READY"; ProgressLabel.TextColor3=SA; ProgressLabel.Font=Enum.Font.GothamBlack; ProgressLabel.TextSize=12; ProgressLabel.TextXAlignment=Enum.TextXAlignment.Left; ProgressLabel.ZIndex=51
ProgressPercentLabel=Instance.new("TextLabel",progressBar); ProgressPercentLabel.Size=UDim2.new(1,-10,0,18); ProgressPercentLabel.Position=UDim2.new(0,0,0,8); ProgressPercentLabel.BackgroundTransparency=1; ProgressPercentLabel.Text=""; ProgressPercentLabel.TextColor3=SW; ProgressPercentLabel.Font=Enum.Font.GothamBlack; ProgressPercentLabel.TextSize=13; ProgressPercentLabel.TextXAlignment=Enum.TextXAlignment.Right; ProgressPercentLabel.ZIndex=51
local radLbl=Instance.new("TextLabel",progressBar); radLbl.Size=UDim2.new(0,52,0,14); radLbl.Position=UDim2.new(0,10,0,30); radLbl.BackgroundTransparency=1; radLbl.Text="Radius:"; radLbl.TextColor3=SM; radLbl.Font=Enum.Font.Gotham; radLbl.TextSize=10; radLbl.TextXAlignment=Enum.TextXAlignment.Left; radLbl.ZIndex=51
RadiusInput=Instance.new("TextBox",progressBar); RadiusInput.Size=UDim2.new(0,52,0,20); RadiusInput.Position=UDim2.new(0,64,0,28); RadiusInput.BackgroundColor3=SC; RadiusInput.BorderSizePixel=0; RadiusInput.Text=tostring(Settings.StealRadius); RadiusInput.TextColor3=ST; RadiusInput.Font=Enum.Font.GothamBold; RadiusInput.TextSize=10; RadiusInput.ZIndex=51; Instance.new("UICorner",RadiusInput).CornerRadius=UDim.new(0,5); Instance.new("UIStroke",RadiusInput).Color=SS
RadiusInput.FocusLost:Connect(function() local n=tonumber(RadiusInput.Text); if n then Settings.StealRadius=math.clamp(math.floor(n),1,500);Values.STEAL_RADIUS=Settings.StealRadius;RadiusInput.Text=tostring(Settings.StealRadius);cachedPrompts={};promptCacheTime=0 end end)
local pTrack=Instance.new("Frame",progressBar); pTrack.Size=UDim2.new(1,-240,0,16); pTrack.Position=UDim2.new(0,128,0,32); pTrack.BackgroundColor3=SOFF; pTrack.BorderSizePixel=0; pTrack.ZIndex=50; Instance.new("UICorner",pTrack).CornerRadius=UDim.new(0,5)
ProgressBarFill=Instance.new("Frame",pTrack); ProgressBarFill.Size=UDim2.new(0,0,1,0); ProgressBarFill.BackgroundColor3=SA; ProgressBarFill.BorderSizePixel=0; ProgressBarFill.ZIndex=51; Instance.new("UICorner",ProgressBarFill).CornerRadius=UDim.new(0,5)
local bfg2=Instance.new("UIGradient",ProgressBarFill); bfg2.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(30,80,200)),ColorSequenceKeypoint.new(1,Color3.fromRGB(120,200,255))})
local durLbl=Instance.new("TextLabel",progressBar); durLbl.Size=UDim2.new(0,40,0,14); durLbl.Position=UDim2.new(1,-118,0,30); durLbl.BackgroundTransparency=1; durLbl.Text="Dur:"; durLbl.TextColor3=SM; durLbl.Font=Enum.Font.Gotham; durLbl.TextSize=10; durLbl.TextXAlignment=Enum.TextXAlignment.Right; durLbl.ZIndex=51
DurationInput=Instance.new("TextBox",progressBar); DurationInput.Size=UDim2.new(0,64,0,20); DurationInput.Position=UDim2.new(1,-68,0,28); DurationInput.BackgroundColor3=SC; DurationInput.BorderSizePixel=0; DurationInput.Text=tostring(Settings.StealDuration); DurationInput.TextColor3=ST; DurationInput.Font=Enum.Font.GothamBold; DurationInput.TextSize=10; DurationInput.ZIndex=51; Instance.new("UICorner",DurationInput).CornerRadius=UDim.new(0,5); Instance.new("UIStroke",DurationInput).Color=SS
DurationInput.FocusLost:Connect(function() local n=tonumber(DurationInput.Text); if n then Settings.StealDuration=math.clamp(n,0.05,5);Values.STEAL_DURATION=Settings.StealDuration;DurationInput.Text=string.format("%.2f",Settings.StealDuration) end end)

-- ORDER COUNTER
local ord=0; local function O() ord=ord+1;return ord end

-- COMBAT PAGE
mkSec(pgCombat,O(),"SPEED & COMBAT")
local arSetVis,_,_=mkToggle(pgCombat,O(),"Anti Ragdoll","",Color3.fromRGB(255,80,180),Enabled.AntiRagdoll,function(s) Enabled.AntiRagdoll=s; if s then startAntiRagdoll() else stopAntiRagdoll() end end)
VisualSetters.AntiRagdoll=arSetVis
local brSwBgL,brSwCirL,brSwBgR,brSwCirR
local brLVis,_brBgL,_brCirL=mkToggle(pgCombat,O(),"Brainrot Return L","",SMINT,false,function(on)
	if on and brainrotReturnRightEnabled then brainrotReturnRightEnabled=false; if brSwBgR then tw(brSwBgR,TIF,{BackgroundColor3=SOFF}) end; if brSwCirR then tw(brSwCirR,TIF,{Position=UDim2.fromOffset(3,3)}) end end
	brainrotReturnLeftEnabled=on
end)
brSwBgL=_brBgL; brSwCirL=_brCirL
local brRVis,_brBgR,_brCirR=mkToggle(pgCombat,O(),"Brainrot Return R","",SAMB,false,function(on)
	if on and brainrotReturnLeftEnabled then brainrotReturnLeftEnabled=false; if brSwBgL then tw(brSwBgL,TIF,{BackgroundColor3=SOFF}) end; if brSwCirL then tw(brSwCirL,TIF,{Position=UDim2.fromOffset(3,3)}) end end
	brainrotReturnRightEnabled=on
end)
brSwBgR=_brBgR; brSwCirR=_brCirR
local carrySetVis,_cBg,_cCir=mkToggle(pgCombat,O(),"Carry Mode","SpeedToggle",SCYAN,speedToggled,function(on)
	if on and laggerToggled then laggerToggled=false; if laggerSwBg and laggerSwCircle then tw(laggerSwBg,TIF,{BackgroundColor3=SOFF});tw(laggerSwCircle,TIF,{Position=UDim2.fromOffset(3,3)}) end; if sideSetters and sideSetters.laggerSetter then sideSetters.laggerSetter(false) end end
	speedToggled=on; if sideSetters and sideSetters.carrySetter then sideSetters.carrySetter(on) end
end)
speedSwBg=_cBg; speedSwCircle=_cCir
local lagSetVis,_lBg,_lCir=mkToggle(pgCombat,O(),"Lagger Mode","LaggerToggle",Color3.fromRGB(255,80,60),laggerToggled,function(on)
	if on and speedToggled then speedToggled=false; if speedSwBg and speedSwCircle then tw(speedSwBg,TIF,{BackgroundColor3=SOFF});tw(speedSwCircle,TIF,{Position=UDim2.fromOffset(3,3)}) end; if sideSetters and sideSetters.carrySetter then sideSetters.carrySetter(false) end end
	laggerToggled=on; if sideSetters and sideSetters.laggerSetter then sideSetters.laggerSetter(on) end
end)
laggerSwBg=_lBg; laggerSwCircle=_lCir
local batSetVis,_bBg,_bCir=mkToggle(pgCombat,O(),"Auto Bat","AutoBat",SA,autoBatToggled,function(on) autoBatToggled=on;autoSwingEnabled=on; if VisualSetters.AutoSwing then VisualSetters.AutoSwing(on) end; if sideSetters and sideSetters.batSetter then sideSetters.batSetter(on) end end)
batSwBg=_bBg; batSwCircle=_bCir
local hhSetVis,_,_=mkToggle(pgCombat,O(),"Harder Hit Anim","",Color3.fromRGB(200,80,255),false,function(on) harderHitAnimEnabled=on; if on then startHarderHitAnim() else stopHarderHitAnim() end end)
VisualSetters.HarderHitAnim=hhSetVis
local medSetVis,_,_=mkToggle(pgCombat,O(),"Medusa Counter","",Color3.fromRGB(80,220,120),false,function(on) medusaCounterEnabled=on; if on then setupMedusaCounter(LocalPlayer.Character) else stopMedusaCounter() end end)
VisualSetters.MedusaCounter=medSetVis
local asSetVis,_,_=mkToggle(pgCombat,O(),"Auto Swing","",SA,false,function(on) autoSwingEnabled=on end)
VisualSetters.AutoSwing=asSetVis
local fsSetVis,_,_=mkToggle(pgCombat,O(),"Fastest Steal","",SAMB,false,function(on) fastestStealEnabled=on end)
VisualSetters.FastestSteal=fsSetVis
mkSec(pgCombat,O(),"SPEED VALUES")
mkInput(pgCombat,O(),"Normal Speed",tostring(NORMAL_SPEED),function(v,box) local n=tonumber(v); if n then NORMAL_SPEED=math.clamp(n,1,9999);box.Text=string.format("%.1f",NORMAL_SPEED) else box.Text=tostring(NORMAL_SPEED) end end)
mkInput(pgCombat,O(),"Carry Speed",tostring(CARRY_SPEED),function(v,box) local n=tonumber(v); if n then CARRY_SPEED=math.clamp(n,1,9999);box.Text=string.format("%.1f",CARRY_SPEED) else box.Text=tostring(CARRY_SPEED) end end)
mkInput(pgCombat,O(),"Lagger Speed",tostring(LAGGER_SPEED),function(v,box) local n=tonumber(v); if n then LAGGER_SPEED=math.clamp(n,1,9999);box.Text=string.format("%.1f",LAGGER_SPEED) else box.Text=tostring(LAGGER_SPEED) end end)

-- MOVEMENT PAGE
ord=0
mkSec(pgMove,O(),"MOVEMENT")
local ijSetVis,_,_=mkToggle(pgMove,O(),"Infinite Jump","InfiniteJump",SA,Enabled.InfiniteJump,function(s) Enabled.InfiniteJump=s; if s then startInfiniteJump() else stopInfiniteJump() end end)
VisualSetters.InfiniteJump=ijSetVis
mkToggle(pgMove,O(),"Unwalk","",SM,Enabled.Unwalk,function(s) Enabled.Unwalk=s; if s then startUnwalk() else stopUnwalk() end end)
local floatSetVis,_,_=mkToggle(pgMove,O(),"Float","FloatToggle",Color3.fromRGB(120,180,255),false,function(on) floatEnabled=on; if on then startFloat() else stopFloat() end end)
local dropSetVis,_,_=mkToggle(pgMove,O(),"Drop Brainrot","DropBrainrot",SAMB,false,function(on) if on then task.spawn(runDropBrainrot) end end)
setDropBrainrotVisual=dropSetVis
local tpDSetVis,_tpDB,_tpDC=mkToggle(pgMove,O(),"TP Down","TPDown",SMINT,false,function(on) if on then runTPDown() end end)
VisualSetters.TPDown=tpDSetVis
VisualSetters.TPDownReset=function() if _tpDB then tw(_tpDB,TIF,{BackgroundColor3=SOFF}) end; if _tpDC then tw(_tpDC,TIF,{Position=UDim2.fromOffset(3,3)}) end;tpDSetVis(false) end
local ncSetVis,_,_=mkToggle(pgMove,O(),"No Cam Collision","",SM,false,function(on) noCamCollisionEnabled=on; if on then enableNoCameraCollision() else disableNoCameraCollision() end end)
VisualSetters.NoCam=ncSetVis
mkSec(pgMove,O(),"FLOAT HEIGHT")
mkInput(pgMove,O(),"Float Height",tostring(floatHeight),function(v,box) local n=tonumber(v); if n then floatHeight=math.clamp(n,1,100);box.Text=tostring(floatHeight) else box.Text=tostring(floatHeight) end end)

-- VISUAL PAGE
ord=0
mkSec(pgVisual,O(),"VISUAL")
mkToggle(pgVisual,O(),"Anti Lag","",SM,Enabled.Optimizer,function(s) Enabled.Optimizer=s; if s then enableOptimizer() else disableOptimizer() end end)
local ulSetVis,_,_=mkToggle(pgVisual,O(),"Ultra Mode","",Color3.fromRGB(255,80,60),false,function(s) ultraModeEnabled=s; if s then enableUltraMode() else disableUltraMode() end end)
VisualSetters.UltraMode=ulSetVis
mkToggle(pgVisual,O(),"Remove Accessories","",SM,Enabled.RemoveAccessories,function(s) Enabled.RemoveAccessories=s; if s then startRemoveAccessories() else stopRemoveAccessories() end end)
mkSec(pgVisual,O(),"CONFIG")
do
	local c2=Instance.new("Frame",pgVisual); c2.Size=UDim2.new(1,-20,0,48); c2.BackgroundColor3=SC; c2.BorderSizePixel=0; c2.LayoutOrder=O(); Instance.new("UICorner",c2).CornerRadius=UDim.new(0,12)
	local cSt3=Instance.new("UIStroke",c2); cSt3.Color=SSD; cSt3.Thickness=1.2; cSt3.Transparency=0.4
	local lbl2=Instance.new("TextLabel",c2); lbl2.Size=UDim2.new(1,-120,1,0); lbl2.Position=UDim2.new(0,16,0,0); lbl2.BackgroundTransparency=1; lbl2.Text="Reset Config"; lbl2.TextColor3=ST; lbl2.Font=Enum.Font.GothamBold; lbl2.TextSize=12; lbl2.TextXAlignment=Enum.TextXAlignment.Left
	local resetBtn=Instance.new("TextButton",c2); resetBtn.Size=UDim2.new(0,70,0,28); resetBtn.Position=UDim2.new(1,-80,0.5,-14); resetBtn.BackgroundColor3=SRED; resetBtn.BorderSizePixel=0; resetBtn.Text="RESET"; resetBtn.TextColor3=SW; resetBtn.Font=Enum.Font.GothamBold; resetBtn.TextSize=11; resetBtn.ZIndex=5; Instance.new("UICorner",resetBtn).CornerRadius=UDim.new(0,6)
	local confirmed=false; local confirmTimer=nil
	resetBtn.MouseButton1Click:Connect(function()
		if not confirmed then confirmed=true;resetBtn.Text="SURE?";resetBtn.BackgroundColor3=Color3.fromRGB(255,140,0); if confirmTimer then task.cancel(confirmTimer) end; confirmTimer=task.delay(2,function() confirmed=false;resetBtn.Text="RESET";resetBtn.BackgroundColor3=SRED end)
		else confirmed=false; if confirmTimer then task.cancel(confirmTimer) end;resetBtn.Text="RESET";resetBtn.BackgroundColor3=SRED; if writefile then pcall(function() writefile("K7HubConfig.json","{}") end) end;resetBtn.Text="DONE!";resetBtn.BackgroundColor3=Color3.fromRGB(50,180,50);task.delay(1.5,function() resetBtn.Text="RESET";resetBtn.BackgroundColor3=SRED end) end
	end)
	c2.MouseEnter:Connect(function() tw(c2,TIF,{BackgroundColor3=SCH});cSt3.Transparency=0.1 end)
	c2.MouseLeave:Connect(function() tw(c2,TIF,{BackgroundColor3=SC});cSt3.Transparency=0.4 end)
end

-- AUTO PAGE
ord=0
mkSec(pgAuto,O(),"AUTO FEATURES")
local atpSetVis,_,_=mkToggle(pgAuto,O(),"Auto TP","",SMINT,false,function(on) G_tpAutoEnabled=on; if on then task.spawn(function() refreshMyPlotSide() end) end end)
VisualSetters.AutoTP=atpSetVis
local apTPSetVis,_,_=mkToggle(pgAuto,O(),"Auto Play After TP","",SA,false,function(on) G_autoPlayAfterTP=on end)
VisualSetters.APAfterTP=apTPSetVis
local cdSetVis,_,_=mkToggle(pgAuto,O(),"Auto Play After Countdown","",SAMB,false,function(on) if on then local ex=workspace:FindFirstChild("Countdown"); if ex and ex:IsA("Sound") then monitorCountdown(ex) end end end)
VisualSetters.Countdown=cdSetVis
mkSec(pgAuto,O(),"AUTO STEAL")
local astCard=Instance.new("Frame",pgAuto); astCard.Size=UDim2.new(1,-20,0,60); astCard.BackgroundColor3=SC; astCard.BorderSizePixel=0; astCard.LayoutOrder=O(); Instance.new("UICorner",astCard).CornerRadius=UDim.new(0,12)
local astCst=Instance.new("UIStroke",astCard); astCst.Color=SSD; astCst.Thickness=1.2; astCst.Transparency=0.4
local astBar=Instance.new("Frame",astCard); astBar.Size=UDim2.new(0,3,0,32); astBar.Position=UDim2.new(0,0,0.5,-16); astBar.BackgroundColor3=SA; astBar.BorderSizePixel=0; Instance.new("UICorner",astBar).CornerRadius=UDim.new(1,0)
local astLbl=Instance.new("TextLabel",astCard); astLbl.Size=UDim2.new(1,-100,0,20); astLbl.Position=UDim2.new(0,16,0,10); astLbl.BackgroundTransparency=1; astLbl.Text="Auto Steal"; astLbl.Font=Enum.Font.GothamBold; astLbl.TextSize=12; astLbl.TextColor3=ST; astLbl.TextXAlignment=Enum.TextXAlignment.Left
local astHint=Instance.new("TextLabel",astCard); astHint.Size=UDim2.new(1,-100,0,13); astHint.Position=UDim2.new(0,16,0,30); astHint.BackgroundTransparency=1; astHint.Text="Radius/Duration in steal bar"; astHint.Font=Enum.Font.Gotham; astHint.TextSize=9; astHint.TextColor3=SDM; astHint.TextXAlignment=Enum.TextXAlignment.Left
local astTrack=Instance.new("Frame",astCard); astTrack.Size=UDim2.new(0,44,0,24); astTrack.Position=UDim2.new(1,-52,0.5,-12); astTrack.BackgroundColor3=Enabled.AutoSteal and SA or SOFF; astTrack.BorderSizePixel=0; Instance.new("UICorner",astTrack).CornerRadius=UDim.new(1,0)
local astTrkSt=Instance.new("UIStroke",astTrack); astTrkSt.Color=Enabled.AutoSteal and SA or SSD; astTrkSt.Thickness=1.2
local astKnob=Instance.new("Frame",astTrack); astKnob.Size=UDim2.new(0,18,0,18); astKnob.Position=Enabled.AutoSteal and UDim2.fromOffset(23,3) or UDim2.fromOffset(3,3); astKnob.BackgroundColor3=Enabled.AutoSteal and SW or SM; astKnob.BorderSizePixel=0; Instance.new("UICorner",astKnob).CornerRadius=UDim.new(1,0)
local astBtn=Instance.new("TextButton",astCard); astBtn.Size=UDim2.new(1,0,1,0); astBtn.BackgroundTransparency=1; astBtn.Text=""; astBtn.ZIndex=5
astCard.MouseEnter:Connect(function() tw(astCard,TIF,{BackgroundColor3=SCH});astCst.Transparency=0.1 end)
astCard.MouseLeave:Connect(function() tw(astCard,TIF,{BackgroundColor3=SC});astCst.Transparency=0.4 end)
astBtn.MouseButton1Click:Connect(function()
	Enabled.AutoSteal=not Enabled.AutoSteal;Settings.AutoStealEnabled=Enabled.AutoSteal
	tw(astTrack,TIF,{BackgroundColor3=Enabled.AutoSteal and SA or SOFF})
	tw(astKnob,TIF,{BackgroundColor3=Enabled.AutoSteal and SW or SM,Position=Enabled.AutoSteal and UDim2.fromOffset(23,3) or UDim2.fromOffset(3,3)})
	astTrkSt.Color=Enabled.AutoSteal and SA or SSD; astHint.TextColor3=Enabled.AutoSteal and SA or SDM
	tw(astBar,TIF,{BackgroundColor3=Enabled.AutoSteal and SA or SSD})
	if Enabled.AutoSteal then startAutoSteal() else stopAutoSteal() end
end)
-- KEYBIND HANDLER
local function handleKeybind(kc)
	if waitingForKeySW then return end
	if kc==Keybinds.UIToggle then Shadow.Visible=not Shadow.Visible;reopenBtn.Visible=not Shadow.Visible end
	if kc==Keybinds.SpeedToggle then
		speedToggled=not speedToggled
		if speedToggled and laggerToggled then laggerToggled=false; if laggerSwBg and laggerSwCircle then tw(laggerSwBg,TIF,{BackgroundColor3=SOFF});tw(laggerSwCircle,TIF,{Position=UDim2.fromOffset(3,3)}) end; if sideSetters and sideSetters.laggerSetter then sideSetters.laggerSetter(false) end end
		if speedSwBg and speedSwCircle then tw(speedSwBg,TIF,{BackgroundColor3=speedToggled and SCYAN or SOFF});tw(speedSwCircle,TIF,{Position=speedToggled and UDim2.fromOffset(23,3) or UDim2.fromOffset(3,3)}) end
		if sideSetters and sideSetters.carrySetter then sideSetters.carrySetter(speedToggled) end
	end
	if kc==Keybinds.LaggerToggle then
		laggerToggled=not laggerToggled
		if laggerToggled and speedToggled then speedToggled=false; if speedSwBg and speedSwCircle then tw(speedSwBg,TIF,{BackgroundColor3=SOFF});tw(speedSwCircle,TIF,{Position=UDim2.fromOffset(3,3)}) end; if sideSetters and sideSetters.carrySetter then sideSetters.carrySetter(false) end end
		if laggerSwBg and laggerSwCircle then tw(laggerSwBg,TIF,{BackgroundColor3=laggerToggled and Color3.fromRGB(255,80,60) or SOFF});tw(laggerSwCircle,TIF,{Position=laggerToggled and UDim2.fromOffset(23,3) or UDim2.fromOffset(3,3)}) end
		if sideSetters and sideSetters.laggerSetter then sideSetters.laggerSetter(laggerToggled) end
	end
	if kc==Keybinds.AutoBat then
		autoBatToggled=not autoBatToggled
		if batSwBg and batSwCircle then tw(batSwBg,TIF,{BackgroundColor3=autoBatToggled and SA or SOFF});tw(batSwCircle,TIF,{Position=autoBatToggled and UDim2.fromOffset(23,3) or UDim2.fromOffset(3,3)}) end
	end
	if kc==Keybinds.InfiniteJump then Enabled.InfiniteJump=not Enabled.InfiniteJump; if VisualSetters.InfiniteJump then VisualSetters.InfiniteJump(Enabled.InfiniteJump) end; if Enabled.InfiniteJump then startInfiniteJump() else stopInfiniteJump() end end
	if kc==Keybinds.DropBrainrot then if setDropBrainrotVisual then setDropBrainrotVisual(true) end;task.spawn(runDropBrainrot) end
	if kc==Keybinds.FloatToggle then floatEnabled=not floatEnabled; if floatSetVis then floatSetVis(floatEnabled) end; if floatEnabled then startFloat() else stopFloat() end end
	if kc==Keybinds.FullAutoLeft then fullAutoPlayLeftEnabled=not fullAutoPlayLeftEnabled; if fullAutoLeftSetter then fullAutoLeftSetter(fullAutoPlayLeftEnabled) end; if fullAutoPlayLeftEnabled then startFullAutoLeft() else stopFullAutoLeft() end end
	if kc==Keybinds.TPDown then runTPDown() end
end
local CONTROLLER_MAP={[Enum.KeyCode.ButtonA]=Keybinds.DropBrainrot,[Enum.KeyCode.ButtonB]=Keybinds.FloatToggle,[Enum.KeyCode.ButtonX]=Keybinds.FullAutoLeft,[Enum.KeyCode.ButtonY]=Keybinds.AutoBat,[Enum.KeyCode.ButtonL1]=Keybinds.SpeedToggle,[Enum.KeyCode.ButtonR1]=Keybinds.LaggerToggle,[Enum.KeyCode.ButtonL2]=Keybinds.TPDown,[Enum.KeyCode.ButtonR2]=Keybinds.InfiniteJump,[Enum.KeyCode.ButtonStart]=Keybinds.UIToggle,[Enum.KeyCode.DPadUp]=Keybinds.FullAutoLeft,[Enum.KeyCode.DPadDown]=Keybinds.TPDown,[Enum.KeyCode.DPadLeft]=Keybinds.AutoBat,[Enum.KeyCode.DPadRight]=Keybinds.SpeedToggle}
UserInputService.InputBegan:Connect(function(input,gpe)
	if gpe then return end
	if input.UserInputType==Enum.UserInputType.Keyboard then handleKeybind(input.KeyCode)
	elseif input.UserInputType==Enum.UserInputType.Gamepad1 or input.UserInputType==Enum.UserInputType.Gamepad2 then handleKeybind(CONTROLLER_MAP[input.KeyCode] or input.KeyCode) end
end)

-- SPEED LOOP
RunService.RenderStepped:Connect(function()
	local char=LocalPlayer.Character; if not char then return end
	local localH=char:FindFirstChildOfClass("Humanoid"); local localHRP=char:FindFirstChild("HumanoidRootPart"); if not localH or not localHRP then return end
	h=localH;hrp=localHRP
	local md=localH.MoveDirection; local spd=laggerToggled and LAGGER_SPEED or (speedToggled and CARRY_SPEED or NORMAL_SPEED)
	if md.Magnitude>0 then localHRP.AssemblyLinearVelocity=Vector3.new(md.X*spd,localHRP.AssemblyLinearVelocity.Y,md.Z*spd) end
	if speedLbl then speedLbl.Text="Speed: "..string.format("%.1f",Vector3.new(localHRP.AssemblyLinearVelocity.X,0,localHRP.AssemblyLinearVelocity.Z).Magnitude) end
end)

-- MOBILE BUTTONS
mobileButtonContainer=Instance.new("Frame",gui); mobileButtonContainer.Size=UDim2.new(0,160,0,290); mobileButtonContainer.Position=UDim2.new(1,-170,0.5,-107)
mobileButtonContainer.BackgroundColor3=SB; mobileButtonContainer.BackgroundTransparency=0.3; mobileButtonContainer.BorderSizePixel=0; mobileButtonContainer.Active=true; mobileButtonContainer.ZIndex=100; Instance.new("UICorner",mobileButtonContainer).CornerRadius=UDim.new(0,12)
local mobSt=Instance.new("UIStroke",mobileButtonContainer); mobSt.Color=SS; mobSt.Thickness=2; mobSt.Transparency=0.5
do
	local drag,ds,sp=false
	mobileButtonContainer.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then drag=true;ds=inp.Position;sp=mobileButtonContainer.Position; inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then drag=false end end) end end)
	UserInputService.InputChanged:Connect(function(inp) if drag and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then local d=inp.Position-ds;mobileButtonContainer.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y) end end)
end
local function createMobileButton(text,row,col,callback)
	local btn=Instance.new("TextButton",mobileButtonContainer); btn.Size=UDim2.new(0,70,0,65); btn.Position=UDim2.new(0,(col-1)*80+5,0,(row-1)*70+5); btn.BackgroundColor3=SC; btn.BorderSizePixel=0; btn.Text=""; btn.ZIndex=101; Instance.new("UICorner",btn).CornerRadius=UDim.new(0,10)
	local btnSt=Instance.new("UIStroke",btn); btnSt.Color=SS; btnSt.Thickness=2; btnSt.Transparency=0.5
	local label=Instance.new("TextLabel",btn); label.Size=UDim2.new(1,0,0,25); label.Position=UDim2.new(0,0,0,8); label.BackgroundTransparency=1; label.Text=text; label.TextColor3=SW; label.Font=Enum.Font.GothamBlack; label.TextSize=11; label.ZIndex=102
	local circle=Instance.new("Frame",btn); circle.Size=UDim2.new(0,14,0,14); circle.Position=UDim2.new(0.5,-7,1,-18); circle.BackgroundColor3=SB; circle.BorderSizePixel=0; circle.ZIndex=102; Instance.new("UICorner",circle).CornerRadius=UDim.new(1,0)
	local cirSt=Instance.new("UIStroke",circle); cirSt.Color=SW; cirSt.Thickness=2
	local cirFill=Instance.new("Frame",circle); cirFill.Size=UDim2.new(0,0,0,0); cirFill.Position=UDim2.new(0.5,0,0.5,0); cirFill.AnchorPoint=Vector2.new(0.5,0.5); cirFill.BackgroundColor3=SW; cirFill.BorderSizePixel=0; cirFill.ZIndex=103; Instance.new("UICorner",cirFill).CornerRadius=UDim.new(1,0)
	local isActive=false
	local function setVis(state) isActive=state; TweenService:Create(cirFill,TweenInfo.new(0.2,Enum.EasingStyle.Back),{Size=isActive and UDim2.new(1,-4,1,-4) or UDim2.new(0,0,0,0)}):Play(); TweenService:Create(btnSt,TweenInfo.new(0.2),{Transparency=isActive and 0 or 0.5}):Play() end
	btn.MouseButton1Click:Connect(function() isActive=not isActive;setVis(isActive); if callback then callback(isActive) end end)
	btn.MouseEnter:Connect(function() TweenService:Create(btn,TweenInfo.new(0.15),{BackgroundColor3=SCH}):Play() end)
	btn.MouseLeave:Connect(function() TweenService:Create(btn,TweenInfo.new(0.15),{BackgroundColor3=SC}):Play() end)
	return setVis
end
local batSetter=createMobileButton("BAT",1,1,function(on) autoBatToggled=on; if batSwBg and batSwCircle then tw(batSwBg,TIF,{BackgroundColor3=on and SA or SOFF});tw(batSwCircle,TIF,{Position=on and UDim2.fromOffset(23,3) or UDim2.fromOffset(3,3)}) end end)
local laggerSetter
local carrySetter=createMobileButton("CARRY",1,2,function(on)
	if on and laggerToggled then laggerToggled=false; if laggerSwBg and laggerSwCircle then tw(laggerSwBg,TIF,{BackgroundColor3=SOFF});tw(laggerSwCircle,TIF,{Position=UDim2.fromOffset(3,3)}) end; if laggerSetter then laggerSetter(false) end end
	speedToggled=on; if speedSwBg and speedSwCircle then tw(speedSwBg,TIF,{BackgroundColor3=on and SCYAN or SOFF});tw(speedSwCircle,TIF,{Position=on and UDim2.fromOffset(23,3) or UDim2.fromOffset(3,3)}) end
end)
local floatMobSetter=createMobileButton("FLOAT",2,2,function(on) floatEnabled=on; if on then startFloat() else stopFloat() end end)
local dropMobV=createMobileButton("DROP",4,1,function(on) if on then if setDropBrainrotVisual then setDropBrainrotVisual(true) end;task.spawn(runDropBrainrot) end end)
dropMobileSetter=dropMobV
fullAutoLeftSetter=createMobileButton("AUTO L",3,1,function(on) fullAutoPlayLeftEnabled=on; if on then startFullAutoLeft() else stopFullAutoLeft() end end)
fullAutoRightSetter=createMobileButton("AUTO R",3,2,function(on) fullAutoPlayRightEnabled=on; if on then startFullAutoRight() else stopFullAutoRight() end end)
laggerSetter=createMobileButton("LAG",2,1,function(on)
	if on and speedToggled then speedToggled=false; if speedSwBg and speedSwCircle then tw(speedSwBg,TIF,{BackgroundColor3=SOFF});tw(speedSwCircle,TIF,{Position=UDim2.fromOffset(3,3)}) end; if carrySetter then carrySetter(false) end end
	laggerToggled=on; if laggerSwBg and laggerSwCircle then tw(laggerSwBg,TIF,{BackgroundColor3=on and Color3.fromRGB(255,80,60) or SOFF});tw(laggerSwCircle,TIF,{Position=on and UDim2.fromOffset(23,3) or UDim2.fromOffset(3,3)}) end
end)
sideSetters={batSetter=batSetter,carrySetter=carrySetter,laggerSetter=laggerSetter}

-- CHARACTER SETUP
local function setupChar(char)
	h=char:WaitForChild("Humanoid");hrp=char:WaitForChild("HumanoidRootPart")
	local head=char:FindFirstChild("Head"); lastKnownHealth=h and h.Health or 100
	if medusaCounterEnabled then setupMedusaCounter(char) end
	if harderHitAnimEnabled then task.wait(0.3);saveOriginalAnims(char);applyAnimPack(char) end
	if head then
		local bb=Instance.new("BillboardGui",head); bb.Size=UDim2.new(0,160,0,28); bb.StudsOffset=Vector3.new(0,3,0); bb.AlwaysOnTop=true
		speedLbl=Instance.new("TextLabel",bb); speedLbl.Size=UDim2.new(1,0,1,0); speedLbl.BackgroundTransparency=1; speedLbl.TextColor3=SA; speedLbl.Font=Enum.Font.GothamBold; speedLbl.TextScaled=true
	end
end
LocalPlayer.CharacterAdded:Connect(setupChar)
if LocalPlayer.Character then setupChar(LocalPlayer.Character) end

task.spawn(function() task.wait(1); batSetter(autoBatToggled);carrySetter(speedToggled);laggerSetter(laggerToggled);floatMobSetter(floatEnabled) end)
task.spawn(function()
	task.wait(2)
	if Enabled.AutoSteal then startAutoSteal() end
	if Enabled.AntiRagdoll then startAntiRagdoll() end
	if Enabled.InfiniteJump then if VisualSetters.InfiniteJump then VisualSetters.InfiniteJump(true) end;startInfiniteJump() end
	if Enabled.Unwalk then startUnwalk() end
	if Enabled.Optimizer then enableOptimizer() end
	if ultraModeEnabled then enableUltraMode() end
	if Enabled.RemoveAccessories then startRemoveAccessories() end
	local cam=workspace.CurrentCamera; if cam then cam.FieldOfView=FOV_VALUE end
end)

-- slide-in animation after loader
switchTab(pgCombat,tCB,tCU)
task.delay(2.3,function()
	TweenService:Create(Shadow,TweenInfo.new(0.5,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Position=UDim2.new(0.5,-146,0.5,-240),BackgroundTransparency=0.82}):Play()
	TweenService:Create(main,TweenInfo.new(0.5,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{BackgroundTransparency=0}):Play()
end)
print("[SWEETY K7 HUB] Loaded!")
end -- _buildGUI
-- ============================================================
-- AUTO PLAY PANEL (original K7 logic, void blue design)
-- ============================================================
;(function()
local Players2=game:GetService("Players"); local RunService2=game:GetService("RunService")
local UserInputService2=game:GetService("UserInputService"); local TweenService2=game:GetService("TweenService")
local HttpService2=game:GetService("HttpService"); local LocalPlayer2=Players2.LocalPlayer
local AP_NORMAL_SPEED=60
local AP_Keybinds={AutoLeft=Enum.KeyCode.Z,AutoRight=Enum.KeyCode.C,UIToggle=Enum.KeyCode.P,FullAutoLeft=Enum.KeyCode.G,FullAutoRight=Enum.KeyCode.H}
local SAVE_FILE="AutoPlayConfig.json"
local function apSaveConfig() pcall(function() if not writefile then return end; writefile(SAVE_FILE,HttpService2:JSONEncode({speed=AP_NORMAL_SPEED,autoLeft=AP_Keybinds.AutoLeft.Name,autoRight=AP_Keybinds.AutoRight.Name,uiToggle=AP_Keybinds.UIToggle.Name,fullAutoLeft=AP_Keybinds.FullAutoLeft.Name,fullAutoRight=AP_Keybinds.FullAutoRight.Name})) end) end
local function apLoadConfig()
	pcall(function()
		if not (isfile and isfile(SAVE_FILE)) then return end
		local ok,cfg=pcall(function() return HttpService2:JSONDecode(readfile(SAVE_FILE)) end); if not ok or not cfg then return end
		if cfg.speed then AP_NORMAL_SPEED=math.clamp(tonumber(cfg.speed) or 60,1,9999) end
		if cfg.autoLeft and Enum.KeyCode[cfg.autoLeft] then AP_Keybinds.AutoLeft=Enum.KeyCode[cfg.autoLeft] end
		if cfg.autoRight and Enum.KeyCode[cfg.autoRight] then AP_Keybinds.AutoRight=Enum.KeyCode[cfg.autoRight] end
		if cfg.uiToggle and Enum.KeyCode[cfg.uiToggle] then AP_Keybinds.UIToggle=Enum.KeyCode[cfg.uiToggle] end
		if cfg.fullAutoLeft and Enum.KeyCode[cfg.fullAutoLeft] then AP_Keybinds.FullAutoLeft=Enum.KeyCode[cfg.fullAutoLeft] end
		if cfg.fullAutoRight and Enum.KeyCode[cfg.fullAutoRight] then AP_Keybinds.FullAutoRight=Enum.KeyCode[cfg.fullAutoRight] end
	end)
end
apLoadConfig()
local AP_L1=Vector3.new(-476.48,-6.28,92.73); local AP_L2=Vector3.new(-483.12,-4.95,94.80)
local AP_R1=Vector3.new(-476.16,-6.52,25.62); local AP_R2=Vector3.new(-483.06,-5.03,25.48)
local AP_LeftOn=false; local AP_RightOn=false; local AP_LeftConn=nil; local AP_RightConn=nil
local AP_LeftPhase=1; local AP_RightPhase=1; local AP_WFK=nil
local AP_SetLeftVisual=nil; local AP_SetRightVisual=nil
local function apGetKey(kc) local n=kc.Name; local m={ButtonA="A",ButtonB="B",ButtonX="X",ButtonY="Y",ButtonL1="L1",ButtonL2="L2",ButtonR1="R1",ButtonR2="R2",ButtonStart="Sta"}; return m[n] or n end
RunService2.RenderStepped:Connect(function()
	local char=LocalPlayer2.Character; if not char then return end
	local h2=char:FindFirstChild("HumanoidRootPart"); local hum=char:FindFirstChildOfClass("Humanoid"); if not h2 or not hum then return end
	local md=hum.MoveDirection; if md.Magnitude>0 then h2.AssemblyLinearVelocity=Vector3.new(md.X*AP_NORMAL_SPEED,h2.AssemblyLinearVelocity.Y,md.Z*AP_NORMAL_SPEED) end
end)
local function AP_StartLeft()
	if AP_LeftConn then AP_LeftConn:Disconnect() end; AP_LeftPhase=1
	AP_LeftConn=RunService2.Heartbeat:Connect(function()
		if not AP_LeftOn then return end; local c=LocalPlayer2.Character; if not c then return end
		local rp=c:FindFirstChild("HumanoidRootPart"); local hum=c:FindFirstChildOfClass("Humanoid"); if not rp or not hum then return end; local spd=AP_NORMAL_SPEED
		if AP_LeftPhase==1 then
			if (Vector3.new(AP_L1.X,rp.Position.Y,AP_L1.Z)-rp.Position).Magnitude<1 then AP_LeftPhase=2; local d=AP_L2-rp.Position; local mv=Vector3.new(d.X,0,d.Z).Unit;hum:Move(mv,false);rp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,rp.AssemblyLinearVelocity.Y,mv.Z*spd);return end
			local d=AP_L1-rp.Position; local mv=Vector3.new(d.X,0,d.Z).Unit;hum:Move(mv,false);rp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,rp.AssemblyLinearVelocity.Y,mv.Z*spd)
		elseif AP_LeftPhase==2 then
			if (Vector3.new(AP_L2.X,rp.Position.Y,AP_L2.Z)-rp.Position).Magnitude<1 then hum:Move(Vector3.zero,false);rp.AssemblyLinearVelocity=Vector3.zero;AP_LeftOn=false; if AP_LeftConn then AP_LeftConn:Disconnect();AP_LeftConn=nil end;AP_LeftPhase=1; if AP_SetLeftVisual then AP_SetLeftVisual(false) end; rp.CFrame=CFrame.new(rp.Position)*CFrame.Angles(0,0,0);return end
			local d=AP_L2-rp.Position; local mv=Vector3.new(d.X,0,d.Z).Unit;hum:Move(mv,false);rp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,rp.AssemblyLinearVelocity.Y,mv.Z*spd)
		end
	end)
end
local function AP_StopLeft() if AP_LeftConn then AP_LeftConn:Disconnect();AP_LeftConn=nil end;AP_LeftPhase=1; local c=LocalPlayer2.Character; if c then local hum=c:FindFirstChildOfClass("Humanoid"); if hum then hum:Move(Vector3.zero,false) end end end
local function AP_StartRight()
	if AP_RightConn then AP_RightConn:Disconnect() end; AP_RightPhase=1
	AP_RightConn=RunService2.Heartbeat:Connect(function()
		if not AP_RightOn then return end; local c=LocalPlayer2.Character; if not c then return end
		local rp=c:FindFirstChild("HumanoidRootPart"); local hum=c:FindFirstChildOfClass("Humanoid"); if not rp or not hum then return end; local spd=AP_NORMAL_SPEED
		if AP_RightPhase==1 then
			if (Vector3.new(AP_R1.X,rp.Position.Y,AP_R1.Z)-rp.Position).Magnitude<1 then AP_RightPhase=2; local d=AP_R2-rp.Position; local mv=Vector3.new(d.X,0,d.Z).Unit;hum:Move(mv,false);rp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,rp.AssemblyLinearVelocity.Y,mv.Z*spd);return end
			local d=AP_R1-rp.Position; local mv=Vector3.new(d.X,0,d.Z).Unit;hum:Move(mv,false);rp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,rp.AssemblyLinearVelocity.Y,mv.Z*spd)
		elseif AP_RightPhase==2 then
			if (Vector3.new(AP_R2.X,rp.Position.Y,AP_R2.Z)-rp.Position).Magnitude<1 then hum:Move(Vector3.zero,false);rp.AssemblyLinearVelocity=Vector3.zero;AP_RightOn=false; if AP_RightConn then AP_RightConn:Disconnect();AP_RightConn=nil end;AP_RightPhase=1; if AP_SetRightVisual then AP_SetRightVisual(false) end; rp.CFrame=CFrame.new(rp.Position)*CFrame.Angles(0,math.rad(180),0);return end
			local d=AP_R2-rp.Position; local mv=Vector3.new(d.X,0,d.Z).Unit;hum:Move(mv,false);rp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,rp.AssemblyLinearVelocity.Y,mv.Z*spd)
		end
	end)
end
local function AP_StopRight() if AP_RightConn then AP_RightConn:Disconnect();AP_RightConn=nil end;AP_RightPhase=1; local c=LocalPlayer2.Character; if c then local hum=c:FindFirstChildOfClass("Humanoid"); if hum then hum:Move(Vector3.zero,false) end end end

-- VOID BLUE COLORS for AP panel
local AP_BG=Color3.fromRGB(8,10,18); local AP_CARD=Color3.fromRGB(12,15,28); local AP_CARDH=Color3.fromRGB(16,20,38)
local AP_ACC=Color3.fromRGB(60,140,255); local AP_ACCD=Color3.fromRGB(20,50,120); local AP_RED=Color3.fromRGB(220,30,30)
local AP_ST=Color3.fromRGB(40,80,180); local AP_SSD=Color3.fromRGB(20,35,80); local AP_OFF=Color3.fromRGB(18,22,45)
local AP_TEXT=Color3.fromRGB(220,235,255); local AP_MUT=Color3.fromRGB(100,120,170); local AP_DIM=Color3.fromRGB(50,65,110)
local AP_WHITE=Color3.fromRGB(255,255,255)
local AP_TIF=TweenInfo.new(0.12,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
local function apTw(o,i,p) TweenService2:Create(o,i,p):Play() end

local apGui2=Instance.new("ScreenGui"); apGui2.Name="AutoPlayGUI2"; apGui2.ResetOnSpawn=false; apGui2.DisplayOrder=10; apGui2.Parent=LocalPlayer2:WaitForChild("PlayerGui")
apMain=Instance.new("Frame"); apMain.Name="Main"; apMain.Size=UDim2.new(0,300,0,380); apMain.Position=UDim2.new(0.5,-150,0.5,-190); apMain.BackgroundColor3=AP_BG; apMain.BorderSizePixel=0; apMain.Active=true; apMain.ClipsDescendants=true; apMain.Parent=apGui2; Instance.new("UICorner",apMain).CornerRadius=UDim.new(0,16)
Instance.new("UIStroke",apMain).Color=AP_ST; local apSt=apMain:FindFirstChildOfClass("UIStroke"); if apSt then apSt.Thickness=1.5 end
do local drag=false; local ds,sp; apMain.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then drag=true;ds=inp.Position;sp=apMain.Position; inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then drag=false end end) end end); UserInputService2.InputChanged:Connect(function(inp) if drag and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then local d=inp.Position-ds;apMain.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y) end end) end
local apHdr=Instance.new("Frame",apMain); apHdr.Size=UDim2.new(1,0,0,54); apHdr.BackgroundColor3=Color3.fromRGB(6,8,14); apHdr.BorderSizePixel=0; apHdr.ZIndex=4; Instance.new("UICorner",apHdr).CornerRadius=UDim.new(0,16)
local apHFix=Instance.new("Frame",apHdr); apHFix.Size=UDim2.new(1,0,0,16); apHFix.Position=UDim2.new(0,0,1,-16); apHFix.BackgroundColor3=Color3.fromRGB(6,8,14); apHFix.BorderSizePixel=0; apHFix.ZIndex=3
local apIco=Instance.new("TextLabel",apHdr); apIco.Size=UDim2.new(0,32,0,32); apIco.Position=UDim2.new(0,12,0.5,-16); apIco.BackgroundColor3=AP_ACCD; apIco.BorderSizePixel=0; apIco.Text="AP"; apIco.TextSize=13; apIco.Font=Enum.Font.GothamBlack; apIco.TextColor3=AP_ACC; Instance.new("UICorner",apIco).CornerRadius=UDim.new(0,8)
local apTitle=Instance.new("TextLabel",apHdr); apTitle.Size=UDim2.new(1,-100,0,20); apTitle.Position=UDim2.new(0,52,0,8); apTitle.BackgroundTransparency=1; apTitle.Text="AUTO PLAY"; apTitle.TextColor3=AP_TEXT; apTitle.Font=Enum.Font.GothamBlack; apTitle.TextSize=14; apTitle.TextXAlignment=Enum.TextXAlignment.Left; apTitle.ZIndex=6
local apSub=Instance.new("TextLabel",apHdr); apSub.Size=UDim2.new(1,-100,0,13); apSub.Position=UDim2.new(0,52,0,29); apSub.BackgroundTransparency=1; apSub.Text="discord.gg/XuKmRwXc4w"; apSub.TextColor3=AP_MUT; apSub.Font=Enum.Font.GothamMedium; apSub.TextSize=9; apSub.TextXAlignment=Enum.TextXAlignment.Left; apSub.ZIndex=5
local apClose=Instance.new("TextButton",apHdr); apClose.Size=UDim2.new(0,28,0,28); apClose.Position=UDim2.new(1,-34,0.5,-14); apClose.BackgroundColor3=AP_RED; apClose.BorderSizePixel=0; apClose.Text="x"; apClose.TextColor3=AP_WHITE; apClose.Font=Enum.Font.GothamBold; apClose.TextSize=18; apClose.ZIndex=8; Instance.new("UICorner",apClose).CornerRadius=UDim.new(0,6)
local apReopen=Instance.new("TextButton",apGui2); apReopen.Size=UDim2.new(0,45,0,45); apReopen.Position=UDim2.new(0.5,-22.5,0.5,-22.5); apReopen.BackgroundColor3=AP_ACC; apReopen.BorderSizePixel=0; apReopen.Text="AP"; apReopen.TextColor3=AP_WHITE; apReopen.Font=Enum.Font.GothamBlack; apReopen.TextSize=14; apReopen.ZIndex=20; apReopen.Visible=false; Instance.new("UICorner",apReopen).CornerRadius=UDim.new(0,10)
apClose.MouseButton1Click:Connect(function() apMain.Visible=false;apReopen.Visible=true end)
apReopen.MouseButton1Click:Connect(function() apMain.Visible=true;apReopen.Visible=false end)
local apScroll=Instance.new("ScrollingFrame",apMain); apScroll.Size=UDim2.new(1,-20,1,-64); apScroll.Position=UDim2.new(0,10,0,58); apScroll.BackgroundTransparency=1; apScroll.BorderSizePixel=0; apScroll.ScrollBarThickness=3; apScroll.ScrollBarImageColor3=AP_ACC; apScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; apScroll.CanvasSize=UDim2.new(0,0,0,0)
local apVS=Instance.new("Frame",apScroll); apVS.Size=UDim2.new(1,0,0,0); apVS.AutomaticSize=Enum.AutomaticSize.Y; apVS.BackgroundTransparency=1
local apLL=Instance.new("UIListLayout",apVS); apLL.SortOrder=Enum.SortOrder.LayoutOrder; apLL.Padding=UDim.new(0,6)
local apPad=Instance.new("UIPadding",apVS); apPad.PaddingTop=UDim.new(0,6); apPad.PaddingBottom=UDim.new(0,10)
local apOrd=0; local function APO() apOrd=apOrd+1;return apOrd end
local function apSec(txt)
	local r=Instance.new("Frame",apVS); r.Size=UDim2.new(1,0,0,22); r.BackgroundTransparency=1; r.LayoutOrder=APO()
	local l1=Instance.new("Frame",r); l1.Size=UDim2.new(0.26,0,0,1); l1.Position=UDim2.new(0,0,0.5,0); l1.BackgroundColor3=AP_SSD; l1.BorderSizePixel=0; Instance.new("UICorner",l1).CornerRadius=UDim.new(1,0)
	local lb=Instance.new("TextLabel",r); lb.Size=UDim2.new(0.48,0,1,0); lb.Position=UDim2.new(0.26,0,0,0); lb.BackgroundTransparency=1; lb.Text=txt; lb.TextColor3=AP_ACC; lb.Font=Enum.Font.GothamBold; lb.TextSize=9
	local l2=Instance.new("Frame",r); l2.Size=UDim2.new(0.26,0,0,1); l2.Position=UDim2.new(0.74,0,0.5,0); l2.BackgroundColor3=AP_SSD; l2.BorderSizePixel=0; Instance.new("UICorner",l2).CornerRadius=UDim.new(1,0)
end
local function apRow(keybindName,labelTxt,onToggle)
	local container=Instance.new("Frame",apVS); container.Size=UDim2.new(1,0,0,60); container.BackgroundColor3=AP_CARD; container.BorderSizePixel=0; container.LayoutOrder=APO(); Instance.new("UICorner",container).CornerRadius=UDim.new(0,12)
	local cSt2=Instance.new("UIStroke",container); cSt2.Color=AP_SSD; cSt2.Thickness=1.2; cSt2.Transparency=0.4
	local bar=Instance.new("Frame",container); bar.Size=UDim2.new(0,3,0,32); bar.Position=UDim2.new(0,0,0.5,-16); bar.BackgroundColor3=AP_ACC; bar.BorderSizePixel=0; Instance.new("UICorner",bar).CornerRadius=UDim.new(1,0)
	local kbBg=Instance.new("Frame",container); kbBg.Size=UDim2.new(0,36,0,36); kbBg.Position=UDim2.new(0,10,0.5,-18); kbBg.BackgroundColor3=AP_ACCD; kbBg.BackgroundTransparency=0.3; kbBg.BorderSizePixel=0; kbBg.ZIndex=5; Instance.new("UICorner",kbBg).CornerRadius=UDim.new(0,9)
	local kbSt2=Instance.new("UIStroke",kbBg); kbSt2.Color=AP_ACC; kbSt2.Thickness=1.5; kbSt2.Transparency=0.4
	local kbTxt=Instance.new("TextLabel",kbBg); kbTxt.Size=UDim2.new(1,0,1,0); kbTxt.BackgroundTransparency=1; kbTxt.Text=apGetKey(AP_Keybinds[keybindName]); kbTxt.TextColor3=AP_WHITE; kbTxt.Font=Enum.Font.GothamBold; kbTxt.TextSize=10; kbTxt.ZIndex=6
	local nameLbl=Instance.new("TextLabel",container); nameLbl.Size=UDim2.new(1,-148,0,20); nameLbl.Position=UDim2.new(0,54,0,10); nameLbl.BackgroundTransparency=1; nameLbl.Text=labelTxt; nameLbl.TextColor3=AP_TEXT; nameLbl.Font=Enum.Font.GothamBold; nameLbl.TextSize=12; nameLbl.TextXAlignment=Enum.TextXAlignment.Left; nameLbl.ZIndex=5
	local hintLbl=Instance.new("TextLabel",container); hintLbl.Size=UDim2.new(1,-148,0,13); hintLbl.Position=UDim2.new(0,54,0,30); hintLbl.BackgroundTransparency=1; hintLbl.Text="Hold to rebind"; hintLbl.Font=Enum.Font.Gotham; hintLbl.TextSize=9; hintLbl.TextColor3=AP_DIM; hintLbl.TextXAlignment=Enum.TextXAlignment.Left
	local track=Instance.new("Frame",container); track.Size=UDim2.new(0,44,0,24); track.Position=UDim2.new(1,-52,0.5,-12); track.BackgroundColor3=AP_OFF; track.BorderSizePixel=0; Instance.new("UICorner",track).CornerRadius=UDim.new(1,0)
	local trkSt2=Instance.new("UIStroke",track); trkSt2.Color=AP_SSD; trkSt2.Thickness=1.2
	local knob=Instance.new("Frame",track); knob.Size=UDim2.new(0,18,0,18); knob.Position=UDim2.fromOffset(3,3); knob.BackgroundColor3=AP_MUT; knob.BorderSizePixel=0; Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)
	local isOn=false
	local function setVis(state)
		isOn=state; apTw(track,AP_TIF,{BackgroundColor3=isOn and AP_ACC or AP_OFF}); apTw(knob,AP_TIF,{BackgroundColor3=isOn and AP_WHITE or AP_MUT,Position=isOn and UDim2.fromOffset(23,3) or UDim2.fromOffset(3,3)}); trkSt2.Color=isOn and AP_ACC or AP_SSD; hintLbl.TextColor3=isOn and AP_ACC or AP_DIM; apTw(bar,AP_TIF,{BackgroundColor3=isOn and AP_ACC or AP_SSD})
	end
	local isHolding=false; local holdStart=0
	local function startKBChange()
		AP_WFK=keybindName; kbTxt.Text="..."; apTw(kbBg,AP_TIF,{BackgroundColor3=Color3.fromRGB(100,70,0),BackgroundTransparency=0})
		local conn; conn=UserInputService2.InputBegan:Connect(function(inp,_)
			if AP_WFK~=keybindName then conn:Disconnect();return end
			if not (inp.UserInputType==Enum.UserInputType.Keyboard or inp.UserInputType==Enum.UserInputType.Gamepad1) then return end
			local kc=inp.KeyCode; if kc==Enum.KeyCode.Unknown then return end
			if kc==Enum.KeyCode.Escape then kbTxt.Text=apGetKey(AP_Keybinds[keybindName]);apTw(kbBg,AP_TIF,{BackgroundColor3=AP_ACCD,BackgroundTransparency=0.3});AP_WFK=nil;conn:Disconnect();return end
			AP_Keybinds[keybindName]=kc; if Keybinds and Keybinds[keybindName] then Keybinds[keybindName]=kc end; kbTxt.Text=apGetKey(kc); apTw(kbBg,AP_TIF,{BackgroundColor3=AP_ACCD,BackgroundTransparency=0.3}); AP_WFK=nil;conn:Disconnect();apSaveConfig()
		end)
	end
	local clk=Instance.new("TextButton",container); clk.Size=UDim2.new(1,0,1,0); clk.BackgroundTransparency=1; clk.Text=""; clk.ZIndex=7
	container.MouseEnter:Connect(function() apTw(container,AP_TIF,{BackgroundColor3=AP_CARDH});cSt2.Transparency=0.1 end)
	container.MouseLeave:Connect(function() apTw(container,AP_TIF,{BackgroundColor3=AP_CARD});cSt2.Transparency=0.4 end)
	clk.MouseButton1Down:Connect(function() isHolding=false;holdStart=tick(); task.delay(0.6,function() if holdStart>0 and (tick()-holdStart)>=0.6 then isHolding=true;startKBChange() end end) end)
	clk.MouseButton1Up:Connect(function() if (tick()-holdStart)<0.6 then holdStart=0 end end)
	clk.MouseButton2Click:Connect(function() startKBChange() end)
	clk.MouseButton1Click:Connect(function() if not isHolding then isOn=not isOn;setVis(isOn); if onToggle then onToggle(isOn) end end;isHolding=false;holdStart=0 end)
	return setVis
end
local function apInput(lbl,defaultTxt,onDone)
	local wrap=Instance.new("Frame",apVS); wrap.Size=UDim2.new(1,0,0,48); wrap.BackgroundColor3=AP_CARD; wrap.BorderSizePixel=0; wrap.LayoutOrder=APO(); Instance.new("UICorner",wrap).CornerRadius=UDim.new(0,12)
	local wSt=Instance.new("UIStroke",wrap); wSt.Color=AP_SSD; wSt.Thickness=1.2; wSt.Transparency=0.4
	local barI=Instance.new("Frame",wrap); barI.Size=UDim2.new(0,3,0,28); barI.Position=UDim2.new(0,0,0.5,-14); barI.BackgroundColor3=AP_ACC; barI.BorderSizePixel=0; Instance.new("UICorner",barI).CornerRadius=UDim.new(1,0)
	local lbTxt=Instance.new("TextLabel",wrap); lbTxt.Size=UDim2.new(0.5,0,1,0); lbTxt.Position=UDim2.new(0,16,0,0); lbTxt.BackgroundTransparency=1; lbTxt.Text=lbl; lbTxt.TextColor3=AP_TEXT; lbTxt.Font=Enum.Font.GothamBold; lbTxt.TextSize=12; lbTxt.TextXAlignment=Enum.TextXAlignment.Left
	local box=Instance.new("TextBox",wrap); box.Size=UDim2.new(0,80,0,28); box.Position=UDim2.new(1,-90,0.5,-14); box.BackgroundColor3=Color3.fromRGB(6,8,14); box.BorderSizePixel=0; box.Text=defaultTxt; box.TextColor3=AP_TEXT; box.Font=Enum.Font.GothamBold; box.TextSize=11; box.ClearTextOnFocus=false; Instance.new("UICorner",box).CornerRadius=UDim.new(0,8)
	local bSt=Instance.new("UIStroke",box); bSt.Color=AP_ACC; bSt.Thickness=1; bSt.Transparency=0.5
	box.Focused:Connect(function() apTw(bSt,AP_TIF,{Transparency=0}) end); box.FocusLost:Connect(function() apTw(bSt,AP_TIF,{Transparency=0.5}); if onDone then onDone(box.Text,box) end end)
	wrap.MouseEnter:Connect(function() apTw(wrap,AP_TIF,{BackgroundColor3=AP_CARDH});wSt.Transparency=0.1 end); wrap.MouseLeave:Connect(function() apTw(wrap,AP_TIF,{BackgroundColor3=AP_CARD});wSt.Transparency=0.4 end)
end

apSec("FULL AUTO PLAY")
local falVis=apRow("FullAutoLeft","Full Auto Left",function(on) fullAutoPlayLeftEnabled=on; if on then startFullAutoLeft() else stopFullAutoLeft() end end)
fullAutoLeftSetter=falVis
local farVis=apRow("FullAutoRight","Full Auto Right",function(on) fullAutoPlayRightEnabled=on; if on then startFullAutoRight() else stopFullAutoRight() end end)
fullAutoRightSetter=farVis
apSec("AUTO PLAY")
local leftVis=apRow("AutoLeft","Auto Left",function(on) AP_LeftOn=on; if on then AP_StartLeft() else AP_StopLeft() end end)
AP_SetLeftVisual=leftVis
local rightVis=apRow("AutoRight","Auto Right",function(on) AP_RightOn=on; if on then AP_StartRight() else AP_StopRight() end end)
AP_SetRightVisual=rightVis
apSec("SETTINGS")
apInput("Speed",tostring(AP_NORMAL_SPEED),function(v,box) local n=tonumber(v); if n then AP_NORMAL_SPEED=math.clamp(n,1,9999);box.Text=tostring(AP_NORMAL_SPEED);apSaveConfig() else box.Text=tostring(AP_NORMAL_SPEED) end end)

local function apHandleInput(kc)
	if AP_WFK then return end
	if kc==AP_Keybinds.UIToggle then apMain.Visible=not apMain.Visible;apReopen.Visible=not apMain.Visible end
	if kc==AP_Keybinds.AutoLeft then AP_LeftOn=not AP_LeftOn;leftVis(AP_LeftOn); if AP_LeftOn then AP_StartLeft() else AP_StopLeft() end end
	if kc==AP_Keybinds.AutoRight then AP_RightOn=not AP_RightOn;rightVis(AP_RightOn); if AP_RightOn then AP_StartRight() else AP_StopRight() end end
end
UserInputService2.InputBegan:Connect(function(input,gpe) if gpe then return end; if input.UserInputType==Enum.UserInputType.Keyboard or input.UserInputType==Enum.UserInputType.Gamepad1 or input.UserInputType==Enum.UserInputType.Gamepad2 then apHandleInput(input.KeyCode) end end)
print("[SWEETY HUB] Auto Play loaded - Z=L C=R P=Toggle")
end)()

-- ============================================================
-- CALL _buildGUI (must be last)
-- ============================================================
_buildGUI()
print("[SWEETY HUB] All systems loaded!")
