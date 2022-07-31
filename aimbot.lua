
if not game:IsLoaded() then
	game.Loaded:Wait()
end


local TOGGLE_AIMBOT_KEY = Enum.KeyCode.X;
local TOGGLE_ARC_KEY = Enum.KeyCode.C;
local TOGGLE_PANIC_MODE_KEY = Enum.KeyCode.Z;
local MOVEDIRECTION_MULTIPLIER_INCREMENT = 0.3;
local AIM_PART = "Head"
local TOOL_TYPE = _G.placeIds[game.PlaceId];


local function create(class, properties)
	local obj = Instance.new(class)
	for key, value in next, properties do
		if key == "Parent" then continue end
		obj[key] = value;
	end
	obj.Parent = properties.Parent;
	return obj;
end


local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Player = Players.LocalPlayer
local Character = nil; --will be initialized later
local tool = nil --will be inited later


local playerData = {}


local settings = {
	aimbot = true,
	arc = "low",
	targetPlayer = nil,
	panicMode = false,
	moveDirectionMultiplier = 16.2;
}


local function getDir(player, pos, moveDirection, walkSpeed)
	local dir = Vector3.new(0, 0, 0)
	local g = -workspace.Gravity;
	local k = moveDirection*walkSpeed;
	local data  = playerData[player];

	
	local playerMinY = nil; do
		local r = Ray.new(pos, Vector3.new(0, -1, 0) * 2000)
		local _, pos = workspace:FindPartOnRay(r, player.Character, true, false)
		playerMinY = (pos.Y or -9999999) + 2 + 2 + 1/2;
	end


	local sign = settings.arc == "high" and 1 or -1;
	local t = 0;
	local new_k = k;


	for i = 1, 7 do
		if t > 0.7 then
			new_k = k / (3*(t/0.7))
		end
		local time_diff = math.max(0, 0.4 + data.lungeTime - tick())
		local new_t1 = math.max(0, t-time_diff)
		local y_pred = math.max(playerMinY, pos.Y + player.Character.Torso.Velocity.y*t + 1/2*g*new_t1^2)
		
		local d = (new_k*t + Vector3.new(pos.X, y_pred, pos.Z)) - (Character:GetPrimaryPartCFrame().Position + 5*dir)

		local dx, dy, dz = d.x, d.y, d.z;

		local a = 1/4*g^2
		local b = -200^2 - dy*g;
		local c = dx^2 + dy^2 + dz^2;

		local discriminant = b^2 - 4*a*c;

		if discriminant < 0 then
			return Vector3.new();
		else
			t = math.sqrt((-b + sign*math.sqrt(discriminant)) / (2*a));
		end
		
		dir = Vector3.new(dx/t, dy/t - 1/2*g*t, dz/t).Unit;
	end

	return dir;
end


local function TOB_Fire(player)
	local data = playerData[player]
	if not data or not data.newPos then return end

	local _G = getrenv()._G
	local Collections = game:GetService("CollectionService")


	local MakeSuperball = require(_G.BB.ClientObjects:WaitForChild("MakeSuperball"))
	local Aesthetics = require(_G.BB.Modules:WaitForChild("Aesthetics"))
	local UpdateEvent = tool:WaitForChild("Update")
	local colorEvent = tool:WaitForChild("Color")


	local self = {};
	self.ClientActiveFolder = workspace:WaitForChild("Projectiles"):WaitForChild("Active"):WaitForChild(Player.Name);
	self.handle = tool:FindFirstChild("Handle");
	self.Head = Character:FindFirstChild("Head");
	self.Delete = require(_G.BB.ClientObjects:WaitForChild("Delete"))
	self.isInsideSomething = require(_G.BB.ClientObjects:WaitForChild("isInsideSomething"))

	local FPS = 0

	if RunService:IsClient() then
		RunService.Stepped:Connect(
			function(_, dt)
				FPS = 1 / dt
			end
		)
	end

	local function IsAcceptableHit(player, hit)
		return hit.Parent:FindFirstChildWhichIsA("Humanoid") or 
			not (
			Collections:HasTag(hit,"Projectile") 
				or (hit.CanCollide == false) 
				or hit.Name == "Handle"
		)
	end
	

	local function handleHitDetection(projectile)
		local Delete = require(_G.BB.ClientObjects:WaitForChild("Delete"))
		local Settings = _G.BB.Settings
		local Kill = require(_G.BB.Modules:WaitForChild("Kill"))
		local PSPV = require(_G.BB.Modules.Security:WaitForChild("PSPV"))
		local HitRemote = _G.BB.Remotes:WaitForChild("Hit")
		
		if projectile:FindFirstChildWhichIsA("TouchTransmitter") then 
			return 
		end
		
		projectile.Ready.Value = true
		
		local player = Players.LocalPlayer
		local ProjectileType = projectile.ProjectileType.Value
		local setting = Settings[ProjectileType]
		local damage = projectile.Damage.Value
		
		local CanHalfDamage = setting.RicochetDamage
		local hitHumanoid = false
		local SetGlobal = false
		
		local TouchedConnection
		
		TouchedConnection = projectile.Touched:Connect(function(hit)
			
			local humanoid = hit.Parent:FindFirstChildWhichIsA("Humanoid")
			local Player = Players:GetPlayerFromCharacter(hit.Parent)
	
			local p1 = projectile.Position
			local v1 = projectile.Velocity
			local t1 = time()
	
			local CharacterData
			local FireToServer = false
	
			-- Play boing sound
			if projectile:FindFirstChild("Boing") then
				if not projectile.Boing.IsPlaying and (damage > 12) then
					projectile.Boing:Play()
				end
			end
			
			-- Evaluate SB fly status
			if ProjectileType == "Superball" and (Player and Player == Players.LocalPlayer) and not SetGlobal then
				if Settings.SuperballJump and not Settings.SuperballFly then
					if _G.BB.CanSBFly then
						
						SetGlobal = true					
						task.delay(.1, function() _G.BB.CanSBFly = false end)
					end				
				end
			end
			
			-- Evaluate damage
			if humanoid and not hitHumanoid then
				if Kill:CanDamage(player, humanoid, false) then
					hitHumanoid = true
					FireToServer = true
					
					-- Instant damage
					if Settings.InstantDamage then
						if (humanoid.Health - projectile.Damage.Value) <= 0 then
							if (humanoid.Health == humanoid.MaxHealth) then --Fix health not updating if target player is full health
								task.delay(3, function() if math.abs(humanoid.Health - .1) < 1e6 then humanoid.Health = humanoid.MaxHealth end end)
							end
							humanoid.Health = .1
						else
							humanoid:TakeDamage(projectile.Damage.Value)
						end
					end
					
					-- Get character positions at multiple frames
					if Player then
						CharacterData = PSPV:CreateCharFrameTables(Player, _G.BB.SlaveTimeTable)
					end
					
					-- Play sound
					if _G.BB.Local.Hit ~= "None" then
						_G.BB.ClientObjects.Sounds.Hit[_G.BB.Local.Hit]:Play()
					end
					
					Aesthetics:CreateVisual(hit, player, false)
					
					TouchedConnection:Disconnect()
					
					if ProjectileType == "Superball" or ProjectileType == "Slingshot" then
						Delete(projectile, 1)
					end
					
				elseif humanoid.Parent ~= player.Character then			
					if _G.BB.Local.BlockedHit ~="None" then
						local Sound = _G.BB.ClientObjects.Sounds.Blocked[_G.BB.Local.BlockedHit]
						if not Sound.Playing then
							Sound:Play()
						end
					end
				end
			elseif CanHalfDamage and IsAcceptableHit(player,hit) then
				CanHalfDamage = false
				
				-- Halving value on the client for instant damage purposes
				if ProjectileType == "Superball" or ProjectileType == "Slingshot" then
					local function halfDamage()
						projectile.Damage.Value = projectile.Damage.Value / 2
					end
					
					local halfDmgDelay = Settings.Ricochet.HalfDamageDelay
					local resetDelay = Settings.Ricochet.ResetStateDelay
					
					local function evaluateRicochet()
						if projectile.Damage.Value <= 3 then
							Delete(projectile, .2)
						else
							CanHalfDamage = true -- reset bool
						end
					end
					
					task.delay(halfDmgDelay, halfDamage)
					task.delay(resetDelay, evaluateRicochet)
				end
			end
			
			if FireToServer then
				local ID_array = {
					projectile.ProjectileType.Value, -- string
					projectile.Count.Value -- integer
				}
				
				
				local sendingTable = {
					ID_array, 
					hit,  -- hit part
					projectile.Damage.Value, -- integer
				}
				
				if _G.BB.Settings.Security.Master then
					
					local securityInfo = {
						p1, v1, t1, -- post hit position, velocity, and time
						CharacterData, -- table with cframe of char data (nil if security is off)
						FPS
					}
					
					for i = 1, #securityInfo do
						table.insert(sendingTable, securityInfo)
					end
				end
					
				HitRemote:FireServer(table.unpack(sendingTable))
			end
		end)
	end


	local function canSBJump(c)
		return (_G.BB.Settings.SuperballJump 
			and c.Humanoid.FloorMaterial == Enum.Material.Air 
			and _G.BB.CanSBFly)
	end


	_G.BB.ProjectileCounts.Superballs += 1
			
	local count = _G.BB.ProjectileCounts.Superballs
	local CollisionGroup = "Superballs" 
	local SpawnDistance = _G.BB.Settings.Superball.SpawnDistance
	
	if canSBJump(Character) then
		CollisionGroup = "JumpySuperballs"
		SpawnDistance = 5 -- optimal spawn distance for superball jumping
	end
				
	local Superball = MakeSuperball(Player, CollisionGroup, count, self.handle.Color)
	
	local Speed = _G.BB.Settings.Superball.Speed
	local ShootInsideBricks = _G.BB.Settings.Superball.ShootInsideBricks

	local dir = getDir(player, data.newPos, data.moveDirection, data.walkSpeed)

	if dir:FuzzyEq(Vector3.new()) then
		dir = (Player:GetMouse().Hit.Position - self.Head.Position).Unit
	end
	
	local now = time()
	local SpawnPosition = self.Head.Position + dir * SpawnDistance
	local LaunchCF = CFrame.new(SpawnPosition, SpawnPosition + dir)
	local Velocity = LaunchCF.LookVector * Speed
	
	Superball.LastSentPosition.Value = LaunchCF.Position
	Superball.LastSentVelocity.Value = Velocity
	Superball.LastSentTime.Value = now
	
	Superball.CFrame = LaunchCF
	Superball.Velocity = Velocity
	Superball.Parent = self.ClientActiveFolder
	

	if not ShootInsideBricks and self.isInsideSomething(Superball) then
		Superball.Anchored = true
		local Position = self.handle.Position
		local cFrame = CFrame.lookAt(Position, Position + dir)
		Superball.CFrame = cFrame
		Superball.Velocity = Superball.CFrame.LookVector * Speed
		Superball.Anchored = false
	end
	

	self.handle.Boing:Play() -- or handle.Boing:Play()
	self.Delete(Superball, 8) -- exists for 8 seconds		
	handleHitDetection(Superball, count)


	UpdateEvent:FireServer(LaunchCF.Position, dir * 200, now, Superball.Color, count)
	Aesthetics:HandleSBHandle(Player, self.handle, colorEvent)
end


local function isSwordLaunching(player)
	local function findSword(parent)
		for _, child in next, parent:GetChildren() do
			if child:IsA("Tool") and string.find(child.Name:lower(), "sword") then
				return child
			end
		end
		return nil
	end

	local sword = findSword(player:WaitForChild("Backpack")) or player.Character and findSword(player.Character)
	if not sword then return false end
	if sword.Grip == CFrame.new(0, 0, -1.5, 0, -1, -0, -1, 0, -0, 0, 0, -1) then
		return true
	end
	return false;
end


local function initializePlayer(player)
	if player == Player then return end

	local data = {};

	data.selectorPart = create("Part", {
		Size = Vector3.new(10, 150, 10),
		Transparency = 0.8,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Anchored = true
	})

	local billboard = create("BillboardGui", {
		Name = "InfoGui";
		Size = UDim2.new(30, 0, 15, 0);
		ClipsDescendants = false;
		StudsOffset = Vector3.new(0, 20, 0);
		AlwaysOnTop = true;
		LightInfluence = 0;
		ResetOnSpawn = false;
	})

	local mainFrame = create("Frame", {
		Name = "Frame";
		Size = UDim2.new(1, 0, 1, 0);
		BackgroundTransparency = 1;
		Parent = billboard;
		BackgroundColor3 = Color3.new(1, 1, 1);
	})

	local healthBarFrame = create("Frame", {
		Name = "HealthBar";
		Size = UDim2.new(1, 0, 0.35, 0);
		AnchorPoint = Vector2.new(0, 1);
		Position = UDim2.new(0, 0, 1, 0);
		BorderColor3 = Color3.new(1, 1, 1);
		BorderSizePixel = 3;
		Parent = mainFrame;
		BackgroundColor3 = Color3.new(0,0,0);
		ZIndex = 1;
	})

	create("Frame", {
		Name = "ProgressBar";
		AnchorPoint = Vector2.new(0, 0.5);
		Size = UDim2.new(0, 0, 1, 0);
		Position = UDim2.new(0, 0, 0.5, 0);
		BackgroundColor3 = Color3.new(0, 1, 0);
		Parent = healthBarFrame;
		ZIndex = 2;
	})

	create("TextLabel", {
		Name = "HealthLabel";
		Size = UDim2.new(1, 0, 1, 0);
		Position = UDim2.new(0.5, 0, 0.5, 0);
		AnchorPoint = Vector2.new(0.5, 0.5);
		Font = Enum.Font.SourceSansBold;
		TextStrokeTransparency = 0;
		TextScaled = true;
		TextColor3 = Color3.new(1, 1, 1);
		Parent = healthBarFrame;
		ZIndex = 3;
		BackgroundTransparency = 1;
	})

	create("TextLabel", {
		Name = "Username";
		Text = ("%s\n(@%s)"):format(player.DisplayName, player.Name);
		Size = UDim2.new(1, 0, 0.6, 0);
		Position = UDim2.new(0, 0, 0, 0);
		TextScaled = true;
		TextColor3 = Color3.new(1, 1, 1);
		Font = Enum.Font.SourceSansBold;
		TextStrokeTransparency = 0;
		BackgroundTransparency = 1;
		Parent = mainFrame;
	})

	billboard.Adornee = data.selectorPart;
	billboard.Parent = data.selectorPart;

	data.lungeTime = 0;
	data.isLungingBefore = false;

	data.walkSpeed = 16.2;
	data.moveDirection = Vector3.new();
	data.newPos = Vector3.new();

	CollectionService:AddTag(data.selectorPart, "SelectorPart")

	playerData[player] = data;
end


local function updateCharVars()
	Character = Player.Character or Player.CharacterAdded:Wait();
	tool = Player:WaitForChild("Backpack"):WaitForChild("Superball")

	if TOOL_TYPE == "TOB" then
		local activationEvent = tool:WaitForChild("Activation")
		local oldFire = nil;
		oldFire = hookfunction(activationEvent.Fire, newcclosure(function(...)
			print("fire() called")
			if not checkcaller() and settings.aimbot == true and settings.targetPlayer ~= nil then
				TOB_Fire(settings.targetPlayer);
				return nil;
			end
			return oldFire(...);
		end))
	end


	local dead = false;
	Character:WaitForChild("Humanoid").Died:Connect(function()
		if dead then return end;
		dead = true;
		Player.CharacterAdded:Wait()
		updateCharVars();
	end)
end;


local function main()
	updateCharVars();


	local gui = create("ScreenGui", {
		Parent = game:GetService("CoreGui"),
		ResetOnSpawn = false,
		Enabled = true,
		DisplayOrder = 9999999999999
	})

	local label = create("TextLabel", {
		Parent = gui,
		Size = UDim2.new(0.25, 0, 0.15, 0),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -10),
		TextScaled = true,
		Font = Enum.Font.SourceSansBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundColor3 = Color3.new(1, 1, 1),
		TextColor3 = Color3.new(0, 0, 0)
	})

	--Hook game metatables
	do
		local ls = game:GetService("LocalizationService")

		local oldNameCall = nil;
		oldNameCall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			local namecallMethod = getnamecallmethod();
			local args = {...}

			if not checkcaller() and self == os and namecallMethod == "time" and os.time(args[1]) == os.time(os.date("*t")) then
				--Spoof the time to be 3600 seconds (1 hour) ahead (germany)
				return os.time(os.date("*t")) + 3600;
			end

			if not checkcaller() and self == ls and namecallMethod == "GetCountryRegionForPlayerAsync" and args[1] == Player then
				return "DE"; --germany
			end

			if not checkcaller() and self == tool.Activation and namecallMethod == "Fire" and settings.aimbot == true and settings.targetPlayer ~= nil then
				return;
			end;

			return oldNameCall(self, ...)
		end))

		local oldIndex = nil;
		oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
			if not checkcaller() and self == ls and key == "SystemLocaleId" then
				return "de-de";
			end

			return oldIndex(self, key)
		end))
	end


	Players.PlayerAdded:Connect(initializePlayer)
	for _, player in next, Players:GetPlayers() do
		initializePlayer(player)
	end


	Players.PlayerRemoving:Connect(function(player)
		if settings.targetPlayer == player then
			settings.targetPlayer = nil;
		end

		local data = playerData[player];

		data.selectorPart:Destroy();

		table.clear(data);
		playerData[player] = nil;
	end)


	RunService.RenderStepped:Connect(function()
		local mouseTarget = Player:GetMouse().Target;

		if not mouseTarget or not CollectionService:HasTag(mouseTarget, "SelectorPart") then
			settings.targetPlayer = nil;
		end

		for player, data in next, playerData do
			local character = player.Character;
			local head = character and character:FindFirstChild("Head")
			local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
			if not head or not humanoid then continue end


			if data.isLungingBefore == false and isSwordLaunching(player) == true then
				data.isLungingBefore = true
				data.lungeTime = tick() - 0.1;
			end
			data.isLungingBefore = isSwordLaunching(player)


			if mouseTarget == data.selectorPart then
				settings.targetPlayer = player;
			end

			if settings.panicMode or humanoid.Health <= 0 or character:FindFirstChildWhichIsA("ForceField", true) then
				data.selectorPart.Parent = nil;
			else
				data.selectorPart.CFrame = CFrame.new(head.Position)
				if settings.targetPlayer == player then
					data.selectorPart.Color = Color3.new(0, 1, 0);
				else
					data.selectorPart.Color = Color3.new(1, 0, 0);
				end
				data.selectorPart.Parent = workspace;
			end

			local gui = data.selectorPart.InfoGui;
			gui.Frame.HealthBar.ProgressBar.Size = UDim2.new(humanoid.Health / humanoid.MaxHealth, 0, 1, 0);
			gui.Frame.HealthBar.HealthLabel.Text = ("%d/%d"):format(math.round(humanoid.Health), math.round(humanoid.MaxHealth));
		end

		label.Text =
		"\nPanicMode = "..tostring(settings.panicMode).." ["..TOGGLE_PANIC_MODE_KEY.Name.."]"..
		"\nAimbotEnabled = "..tostring(settings.aimbot).." ["..TOGGLE_AIMBOT_KEY.Name.."]"..
		"\nArc = "..tostring(settings.arc).." ["..TOGGLE_ARC_KEY.Name.."]"..
		"\nTargetPlayer = "..tostring(settings.targetPlayer and settings.targetPlayer.Name or "Nobody!")..
		("\nMoveDirectionMultiplier = %.2f"):format(settings.moveDirectionMultiplier).." [edit with +/-]"

		gui.Enabled = not settings.panicMode;


		local oldPositions = {};
		local dt = 0.2;


		for player, _ in next, playerData do
			local aimPart = player.Character and player.Character:FindFirstChild(AIM_PART);
			if not aimPart then continue end;
			oldPositions[player] = aimPart.Position
		end


		task.wait(dt);

		
		for player, data in next, playerData do
			local aimPart = player.Character and player.Character:FindFirstChild(AIM_PART);
			local character = player.Character;
			local humanoid = character and character:FindFirstChild("Humanoid");
			local oldPos = oldPositions[player];
			if not aimPart or not humanoid or not oldPos then continue end;

			
			local newPos = aimPart.Position;
			local moveDirection = (newPos-oldPos)
			moveDirection = humanoid.MoveDirection;

			data.walkSpeed = moveDirection.Magnitude/dt --math.min(moveDirection.Magnitude/dt, settings.moveDirectionMultiplier);

			if moveDirection.Magnitude > 0.05 then
				moveDirection = moveDirection.Unit;
			else
				moveDirection = Vector3.new();
			end

			data.moveDirection = moveDirection;
			data.newPos = newPos;
		end
	end)


	game:GetService("UserInputService").InputBegan:Connect(function(input, gpe)
		if gpe then return end

		local key = input.KeyCode;
		if key == TOGGLE_AIMBOT_KEY then
			settings.aimbot = not settings.aimbot;
		elseif key == TOGGLE_ARC_KEY then
			settings.arc = settings.arc == "high" and "low" or "high"
		elseif key == TOGGLE_PANIC_MODE_KEY then
			settings.panicMode = not settings.panicMode;
			if settings.panicMode == true then
				settings.aimbot = false;
				settings.targetPlayer = nil;
			end
		elseif key == Enum.KeyCode.E or key == Enum.KeyCode.Q then
			local sign = key == Enum.KeyCode.E and 1 or -1;
			settings.moveDirectionMultiplier = math.abs(settings.moveDirectionMultiplier + sign * MOVEDIRECTION_MULTIPLIER_INCREMENT)
		end

		if tool.Enabled == true and input.UserInputType == Enum.UserInputType.MouseButton1 and Character.Parent == workspace and tool.Parent == Character and settings.aimbot == true and settings.targetPlayer ~= nil and Character.Humanoid.Health > 0 then
			tool.Enabled = false;
			if TOOL_TYPE == "TOB" then
				TOB_Fire(settings.targetPlayer);
			end
			task.wait(2);
			tool.Enabled = true;
		end
	end)
end


main();