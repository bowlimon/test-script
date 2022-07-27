
setmetatable(_G, {
    __index = function(self, key)
        return getrenv()._G[key]
    end
})

local CollectionService = game:GetService("CollectionService")

local Superball = {}

local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()

local Aesthetics = require(_G.BB.Modules:WaitForChild("Aesthetics"))
local SafeWait = require(_G.BB.Modules.Security:WaitForChild("SafeWait"))
local MakeSuperball = require(_G.BB.ClientObjects:WaitForChild("MakeSuperball"))

local tool = Character:WaitForChild("Superball")

local ReloadTime = _G.BB.Settings.Superball.ReloadTime
local UpdateEvent = tool:WaitForChild("Update")

local targetPlayer = nil;

local function canSBJump(Character)
	return (_G.BB.Settings.SuperballJump 
		and Character.Humanoid.FloorMaterial == Enum.Material.Air)
end

local function getDir(player, pos)
	local dir = Vector3.new(0, 0, 0)

	local g = -workspace.Gravity;
	local k = player.Character.Humanoid.MoveDirection*18.5;
	local t = 0;

	for i = 1, 2 do
		local d = (pos + k*t) - (Character:GetPrimaryPartCFrame().Position + 5*dir) 

		local dx, dy, dz = d.x, d.y, d.z;

		local a = 1/4*g^2
		local b = -200^2 - dy*g;
		local c = dx^2 + dy^2 + dz^2;

		local discriminant = b^2 - 4*a*c;

		if discriminant < 0 then
			return Vector3.new();
		else
			t = math.sqrt((-b - math.sqrt(discriminant)) / (2*a));
		end
		dir = Vector3.new(dx/t, dy/t - 1/2*g*t, dz/t).Unit;
	end

	return dir;
end


function Superball:Fire(Superball, SpawnDistance, count)
	local Speed = _G.BB.Settings.Superball.Speed
	local ShootInsideBricks = _G.BB.Settings.Superball.ShootInsideBricks

	local dir = getDir(targetPlayer, targetPlayer.Character.Head.Position);

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
	for _, child in next, _G.BB.ClientObjects:GetChildren() do
		print(child.Name)
	end
    self.Hit:HandleHitDetection(Superball, count)
	return LaunchCF.Position, Velocity, now
end

function Superball:Shoot()
	if tool.Enabled then
		tool.Enabled = false

		_G.BB.ProjectileCounts.Superballs += 1

		local count = _G.BB.ProjectileCounts.Superballs
		local CollisionGroup = "Superballs" 
		local SpawnDistance = _G.BB.Settings.Superball.SpawnDistance

		if canSBJump(Character) then
			CollisionGroup = "JumpySuperballs"
			SpawnDistance = 5 -- optimal spawn distance for superball jumping
		end

		local Superball = MakeSuperball(Player, CollisionGroup, count, self.handle.Color)

		local position, velocity, now = self:Fire(Superball, SpawnDistance, count)
		UpdateEvent:FireServer(position, velocity, now, Superball.Color, count)

		SafeWait.wait(ReloadTime)

		tool.Enabled = true
	end
end

function Superball:Init()
	self.Hit = require(_G.BB.Modules:WaitForChild("Hit"))
	self.Delete = require(_G.BB.ClientObjects:WaitForChild("Delete"))
	self.isInsideSomething = require(_G.BB.ClientObjects:WaitForChild("isInsideSomething"))

	self.ClientActiveFolder = workspace:WaitForChild("Projectiles"):WaitForChild("Active"):WaitForChild(Player.Name)

	self.handle = tool:WaitForChild("Handle")

	self.Head = Character:WaitForChild("Head")

	local HandleCrosshair = require(_G.BB.ClientObjects:WaitForChild("HandleCrosshair"))
	local Activation = tool:WaitForChild("Activation")
	local colorEvent = tool:WaitForChild("Color")

	Aesthetics:HandleSBHandle(Player, self.handle, colorEvent, true)
	HandleCrosshair(tool)

	tool.Enabled = true

	task.spawn(function()
		while task.wait() and Character.Parent == workspace do
		    if tool.Parent ~= Character or not targetPlayer then continue end;
		    
			Superball:Shoot()
		end
	end)
end

Superball:Init()

--setup hbe;

local parts = {};

game:GetService("UserInputService").InputBegan:Connect(function(input, gpe)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and not gpe then
        local target = game.Players.LocalPlayer:GetMouse().Target;
        if not target then return end;
        if target and CollectionService:HasTag(target, "Box") then
            local oldPlayer = targetPlayer;
            if oldPlayer then
                parts[oldPlayer].Color = Color3.new(1, 0, 0);
                targetPlayer = nil;
                if oldPlayer == player then return end;
            end
            
            for x, y in next, parts do
                if y == target then
                    targetPlayer = x;
                    break;
                end;
            end;
            
            target.Color = Color3.new(0, 1, 0)
        end
    end
end)


while true do
    for _, part in next, parts do
        part:Destroy();
    end
    table.clear(parts);
    
    if Player.Character.Parent == nil then
        break;
    end
    
    for _, player in next, Players:GetPlayers() do
        local character = player.Character;
        local humanoid = character and character.Humanoid;
        if humanoid and humanoid.Health > 0 and player ~= Player then
            local p = Instance.new("Part")
            p.Size = Vector3.new(20, 500, 20)
            p.Transparency = 0.85;
            p.Color = Color3.new(1, 0, 0)
            p.Material = Enum.Material.Neon;
            CollectionService:AddTag(p, "Box")
            p.CanCollide = false;
            p.Anchored = true;
            
            p.Parent = workspace;
            
            task.spawn(function()
                while character.Parent and character:FindFirstChild("HumanoidRootPart") and p.Parent do
                    p.CFrame = character.HumanoidRootPart.CFrame;
                    game:GetService("RunService").RenderStepped:Wait()
                end
            end)
            
            parts[player] = p;
        end
    end
    
    task.wait(3)
end
    