
if not game:IsLoaded() then
	game.Loaded:Wait()
end

setmetatable(_G, {
    __index = function(self, key)
        return rawget(getrenv()._G, key)
    end
})

repeat task.wait() until _G.BB ~= nil;


local TOGGLE_AIMBOT_KEY = Enum.KeyCode.X;
local TOGGLE_ARC_KEY = Enum.KeyCode.C;
local TOGGLE_PANIC_MODE_KEY = Enum.KeyCode.Z;
local MOVEDIRECTION_MULTIPLIER_INCREMENT = 0.3;
local AIM_PART = "Head"


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
local PlayerGui = Player:WaitForChild("PlayerGui")
local Character = nil; --will be initialized later
local tool = nil --will be inited later
local toolModule = nil --will be inited later too

local Kill = require(_G.BB.Modules:WaitForChild("Kill"))
local PSPV = require(_G.BB.Modules.Security:WaitForChild("PSPV"))
local HitRemote = _G.BB.Remotes:WaitForChild("Hit")
local Settings = _G.BB.Settings
local Aesthetics = require(_G.BB.Modules:WaitForChild("Aesthetics"))
local SafeWait = require(_G.BB.Modules.Security:WaitForChild("SafeWait"))
local MakeSuperball = require(_G.BB.ClientObjects:WaitForChild("MakeSuperball"))

local ReloadTime = _G.BB.Settings.Superball.ReloadTime
local UpdateEvent = nil; --will be inited later


local FPS = 0
local playerData = {}


local settings = {
	aimbot = false,
	arc = "low",
	targetPlayer = nil,
	panicMode = false,
	moveDirectionMultiplier = 16.2;
}


if RunService:IsClient() then
	RunService.Stepped:Connect(
		function(_, dt)
			FPS = 1 / dt
		end
	)
end


local HitModule = {};


function IsAcceptableHit(player, hit)
	return hit.Parent:FindFirstChildWhichIsA("Humanoid") or 
		not (
		CollectionService:HasTag(hit,"Projectile") 
			or (hit.CanCollide == false) 
			or hit.Name == "Handle"
	)
end


function HitModule:HandleHitDetection(projectile)
	--print("__________")
	--print("Initializing:", PhysicsFolder.UniqueID.Value)
	local Delete = require(_G.BB.ClientObjects:WaitForChild("Delete"))
	
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
	
	--local p0, v0, t0 = PhysicsFolder.LastSentPosition, PhysicsFolder.LastSentVelocity, PhysicsFolder.LastSentTime
	
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
		
		if IsAcceptableHit(player, hit) then
			FireToServer = true
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



local Superball = {}

local function canSBJump(Character)
	return (_G.BB.Settings.SuperballJump 
		and Character.Humanoid.FloorMaterial == Enum.Material.Air)
end


local function isSwordLaunching(player)
	local sword = player:WaitForChild("Backpack"):FindFirstChild("1 Sword") or player.Character and player.Character:FindFirstChild("1 Sword")
	if not sword then return false end
	if sword.Grip == CFrame.new(0, 0, -1.5, 0, -1, -0, -1, 0, -0, 0, 0, -1) then
		return true
	end
	return false;
end


local function getDir(player, pos)
	local dir = Vector3.new(0, 0, 0)
	local g = -workspace.Gravity;
	local k = player.Character.Humanoid.MoveDirection*16.2;
	local torso = player.Character.Torso;

	-- local averageMoveDirection = Vector3.new(0, 0, 0);
	-- local averageHeadHeight = 0;
	-- do
	-- 	local sumDir = Vector3.new(0, 0, 0);
	-- 	local sum_y = 0;
	-- 	local moveDirs = playerData[player].moveDirectionData.directions;
	-- 	for _, moveDir in next, moveDirs do
	-- 		sumDir += Vector3.new(moveDir.X, 0, moveDir.Z)
	-- 		sum_y += moveDir.Y;
	-- 	end
	-- 	averageMoveDirection = sumDir / #moveDirs;
	-- 	averageHeadHeight = sum_y / #moveDirs;
	-- end

	-- pos = Vector3.new(pos.X, averageHeadHeight, pos.Z);
	
	local playerMinY = nil; do
		local r = Ray.new(pos, Vector3.new(0, -1, 0) * 2000)
		local hit, pos = workspace:FindPartOnRay(r, player.Character, true, false)
		playerMinY = (pos.Y or -9999999) + 2 + 2 + 1/2;
	end
	
	local t = 0;
	local sign = settings.arc == "high" and 1 or -1;

	for i = 1, 7 do
		local y_pred = nil;
		if isSwordLaunching(player) then
			local new_t = math.max(0, t-0.3)
			y_pred = math.max(playerMinY, pos.Y +  player.Character.Torso.Velocity.y*t + 1/2*g*new_t^2)
		else
			y_pred = math.max(playerMinY, pos.Y +  player.Character.Torso.Velocity.y*t + 1/2*g*t^2)
		end

		local d = (k*t + Vector3.new(pos.X, y_pred, pos.Z)) - (Character:GetPrimaryPartCFrame().Position + 5*dir)

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


function Superball:Fire(Superball)
	local Speed = _G.BB.Settings.Superball.Speed
	local ShootInsideBricks = _G.BB.Settings.Superball.ShootInsideBricks

	local dir = getDir(settings.targetPlayer, settings.targetPlayer.Character:FindFirstChild(AIM_PART).Position);


	if dir:FuzzyEq(Vector3.new()) then
		dir = (Player:GetMouse().Hit.Position - Character.Head.Position).Unit
	end


	local now = time()
	local SpawnPosition = Character.Head.Position + dir * 5
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
		local Position = tool.Handle.Position
		local cFrame = CFrame.lookAt(Position, Position + dir)
		Superball.CFrame = cFrame
		Superball.Velocity = Superball.CFrame.LookVector * Speed
		Superball.Anchored = false
	end

	tool.Handle.Boing:Play() -- or handle.Boing:Play()

	self.Delete(Superball, 8) -- exists for 8 seconds		

    HitModule:HandleHitDetection(Superball)
	return LaunchCF.Position, Velocity, now
end


function Superball:Shoot()
	if tool.Enabled then
		tool.Enabled = false

		_G.BB.ProjectileCounts.Superballs += 1

		local count = _G.BB.ProjectileCounts.Superballs
		local CollisionGroup = "Superballs"

		if canSBJump(Character) then
			CollisionGroup = "JumpySuperballs"
		end

		local Superball = MakeSuperball(Player, CollisionGroup, count, tool.Handle.Color)

		local position, velocity, now = self:Fire(Superball)
		if position ~= nil and velocity ~= nil and now ~= nil then
			UpdateEvent:FireServer(position, velocity, now, Superball.Color, count)

			Aesthetics:HandleSBHandle(Player, tool.handle, self.colorEvent)

			SafeWait.wait(ReloadTime)
	
			tool.Enabled = true
		end
	end
end


function Superball:Init()
	self.Hit = require(_G.BB.Modules:WaitForChild("Hit"))
	self.Delete = require(_G.BB.ClientObjects:WaitForChild("Delete"))
	self.isInsideSomething = require(_G.BB.ClientObjects:WaitForChild("isInsideSomething"))

	self.ClientActiveFolder = workspace:WaitForChild("Projectiles"):WaitForChild("Active"):WaitForChild(Player.Name)
	self.colorEvent = tool:WaitForChild("Color")

	local HandleCrosshair = require(_G.BB.ClientObjects:WaitForChild("HandleCrosshair"))

	Aesthetics:HandleSBHandle(Player, tool.Handle, self.colorEvent, true)
	HandleCrosshair(tool)

	tool.Enabled = true
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
		Size = UDim2.new(0, 200, 0, 100);
		ClipsDescendants = false;
		StudsOffset = Vector3.new(0, 60, 0);
		AlwaysOnTop = true;
		LightInfluence = 0;
		ResetOnSpawn = false;
	})

	local mainFrame = create("Frame", {
		Name = "Frame";
		Size = UDim2.new(1, 0, 1, 0);
		BackgroundTransparency = 1;
		Parent = billboard;
	})

	local healthBarFrame = create("Frame", {
		Name = "HealthBar";
		Size = UDim2.new(1, 0, 0.35, 0);
		AnchorPoint = Vector2.new(0, 1);
		Position = UDim2.new(0, 0, 1, 0);
		BorderColor3 = Color3.new(1, 1, 1);
		BorderSizePixel = 3;
		Parent = mainFrame;
	})

	create("Frame", {
		Name = "ProgressBar";
		AnchorPoint = Vector2.new(0, 0.5);
		Size = UDim2.new(0, 0, 1, 0);
		BackgroundColor3 = Color3.new(0, 1, 0);
		Parent = healthBarFrame;
	})

	healthLabel = create("TextLabel", {
		Name = "HealthLabel";
		Size = UDim2.new(1, 0, 1, 0);
		Position = UDim2.new(0.5, 0, 0.5, 0);
		AnchorPoint = Vector2.new(0.5, 0.5);
		Font = Enum.Font.SourceSansBold;
		TextStrokeTransparency = 0;
		TextScaled = true;
		TextColor3 = Color3.new(1, 1, 1);
		Parent = healthBarFrame;
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
		Parent = mainFrame;
	})

	billboard.Adornee = data.selectorPart;
	billboard.Parent = data.selectorPart;

	data.moveDirectionData = {
		averageMoveDirection = nil,
		directions = {};
	}

	CollectionService:AddTag(data.selectorPart, "SelectorPart")

	playerData[player] = data;
end


local function updateCharVars()
	Character = Player.Character or Player.CharacterAdded:Wait();
	tool = Player:WaitForChild("Backpack"):WaitForChild("Superball")
	toolModule = require(tool:WaitForChild("Client"):WaitForChild("SuperballClient"))
	UpdateEvent = tool:WaitForChild("Update");

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


	Superball:Init()

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

	--need to hook the real superball module's fire function so that it won't ever get called unless aimbot is turned off
	do
		local ls = game:GetService("LocalizationService")

		local oldNameCall = nil;
		oldNameCall = hookmetamethod(game, "__namecall", function(self, ...)
			local namecallMethod = getnamecallmethod();
			local args = {...}

			if not checkcaller() and self == tool.Activation and namecallMethod == "Fire" and settings.aimbot == true and settings.targetPlayer ~= nil then
				return nil;
			end;

			if not checkcaller() and self == os and namecallMethod == "time" and os.time(args[1]) == os.time(os.date("*t")) then
				--Spoof the time to be 3600 seconds (1 hour) ahead (germany)
				return os.time(os.date("*t")) + 3600;
			end

			if not checkcaller() and self == ls and namecallMethod == "GetCountryRegionForPlayerAsync" and args[1] == Player then
				return "DE"; --germany
			end

			return oldNameCall(self, ...)
		end)

		local oldIndex = nil;
		oldIndex = hookmetamethod(game, "__index", function(self, key)
			if not checkcaller() and self == ls and key == "SystemLocaleId" then
				return "de-de";
			end
			return oldIndex(self, key)
		end)
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

		if input.UserInputType == Enum.UserInputType.MouseButton1 and Character.Parent == workspace and tool.Parent == Character and settings.aimbot == true and settings.targetPlayer ~= nil and Character.Humanoid.Health > 0 then
			Superball:Shoot();
		end
	end)
end


main();