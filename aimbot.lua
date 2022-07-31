
if not game:IsLoaded() then
	game.Loaded:Wait()
end

local global = getrenv()._G

repeat task.wait() until global.BB ~= nil;


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
local Character = nil; --will be initialized later
local tool = nil --will be inited later
local toolModule = nil --will be inited later too


local Aesthetics = require(global.BB.Modules:WaitForChild("Aesthetics"))
local SafeWait = require(global.BB.Modules.Security:WaitForChild("SafeWait"))
local MakeSuperball = require(global.BB.ClientObjects:WaitForChild("MakeSuperball"))

local ReloadTime = global.BB.Settings.Superball.ReloadTime
local UpdateEvent = nil; --will be inited later


local playerData = {}


local settings = {
	aimbot = true,
	arc = "low",
	targetPlayer = nil,
	panicMode = false,
	moveDirectionMultiplier = 16.2;
}


local Superball = {}


local function canSBJump(Character)
	return (global.BB.Settings.SuperballJump 
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


local function getDir(player, pos, moveDirection, walkSpeed)
	local dir = Vector3.new(0, 0, 0)
	local g = -workspace.Gravity;
	local k = moveDirection*walkSpeed;
	local data  = playerData[player];

	
	local playerMinY = nil; do
		local r = Ray.new(pos, Vector3.new(0, -1, 0) * 2000)
		local hit, pos = workspace:FindPartOnRay(r, player.Character, true, false)
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

	return dir, t;
end

function Superball:Shoot()
	if tool.Enabled then
		tool.Enabled = false

		global.BB.ProjectileCounts.Superballs += 1

		local count = global.BB.ProjectileCounts.Superballs
		local CollisionGroup = "Superballs"

		if canSBJump(Character) then
			CollisionGroup = "JumpySuperballs"
		end

		local Superball = MakeSuperball(Player, CollisionGroup, count, tool.Handle.Color)


		local Speed = global.BB.Settings.Superball.Speed
		local ShootInsideBricks = global.BB.Settings.Superball.ShootInsideBricks
		local aimPart = settings.targetPlayer.Character:FindFirstChild(AIM_PART);
		local data = playerData[settings.targetPlayer];
	
		local dir = getDir(settings.targetPlayer, aimPart.Position, data.moveDirection, data.walkSpeed);
	
	
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
	
		self.Hit:HandleHitDetection(Superball)
		UpdateEvent:FireServer(LaunchCF.Position, Velocity, now, Superball.Color, count)
		Aesthetics:HandleSBHandle(Player, tool.Handle, self.colorEvent)

		SafeWait.wait(ReloadTime)

		tool.Enabled = true
	end
end


function Superball:Init()
	self.Hit = require(global.BB.Modules:WaitForChild("Hit"))
	self.Delete = require(global.BB.ClientObjects:WaitForChild("Delete"))
	self.isInsideSomething = require(global.BB.ClientObjects:WaitForChild("isInsideSomething"))

	self.ClientActiveFolder = workspace:WaitForChild("Projectiles"):WaitForChild("Active"):WaitForChild(Player.Name)
	self.colorEvent = tool:WaitForChild("Color")

	local HandleCrosshair = require(global.BB.ClientObjects:WaitForChild("HandleCrosshair"))

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

	data.oldPos = Vector3.new();
	data.walkSpeed = 16.2;
	data.moveDirection = Vector3.new();

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
				return;
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

			if not checkcaller() and self == _G then
				print("Attempt to access syn _G, key =", key)
				return global[key];
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
	
	task.spawn(function()
		local dt = 0.2;
		while true do
			for player, data in next, playerData do
				local aimPart = player.Character and player.Character:FindFirstChild(AIM_PART);
				if not aimPart then continue end;
				data.oldPos = aimPart.Position
			end
	
	
			task.wait(dt);
	
			
			for player, data in next, playerData do
				local aimPart = player.Character and player.Character:FindFirstChild(AIM_PART);
				if not aimPart then continue end;
	
				local oldPos = data.oldPos;
				local newPos = aimPart.Position;
				local moveDirection = (newPos-oldPos)
				moveDirection = aimPart.Parent.Humanoid.MoveDirection;

				data.walkSpeed = math.min(moveDirection.Magnitude/dt, settings.moveDirectionMultiplier);

				if moveDirection.Magnitude > 0.05 then
					moveDirection = moveDirection.Unit;
				else
					moveDirection = Vector3.new();
				end

				data.moveDirection = moveDirection;
			end
		end
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