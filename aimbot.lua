
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
local updateEvent = nil;


local playerData = {}


local settings = {
	aimbot = true,
	arc = "low",
	targetPlayer = nil,
	panicMode = false,
	moveDirectionMultiplier = 16.2;
}


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
	updateEvent = tool:WaitForChild("Update")


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
		oldNameCall = hookmetamethod(game, "__namecall", function(self, ...)
			local namecallMethod = getnamecallmethod();
			local args = {...}

			if not checkcaller() and self == os and namecallMethod == "time" and os.time(args[1]) == os.time(os.date("*t")) then
				--Spoof the time to be 3600 seconds (1 hour) ahead (germany)
				return os.time(os.date("*t")) + 3600;
			end

			if not checkcaller() and self == ls and namecallMethod == "GetCountryRegionForPlayerAsync" and args[1] == Player then
				return "DE"; --germany
			end

			if not checkcaller() and self == updateEvent and namecallMethod == "FireServer" then
				print(self, unpack(args))
				local data = settings.targetPlayer and playerData[settings.targetPlayer];
				if data then
					local dir = getDir(settings.targetPlayer, data.newPos, data.moveDirection, data.walkSpeed)
					local spawnPos = Player.Character.Head.Position + dir * 5;
					args[1] = spawnPos;
					args[2] = dir;
				end
			end


			return oldNameCall(self, unpack(args))
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
	end)
end


main();