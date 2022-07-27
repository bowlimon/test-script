
setmetatable(_G, {
    __index = function(self, key)
		print(debug.traceback("synapse _G accessed. Call stack:"))
        return rawget(getrenv()._G, key)
    end
})


-- GloriedRage, GFink, tyzone
-- Used in Superball, Paintball Gun, and Slingshot client modules.

local HitModule = {}

local Collections = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Kill = require(_G.BB.Modules:WaitForChild("Kill"))
local Aesthetics = require(_G.BB.Modules:WaitForChild("Aesthetics"))
local PSPV = require(_G.BB.Modules.Security:WaitForChild("PSPV"))
local HitRemote = _G.BB.Remotes:WaitForChild("Hit")
local Settings = _G.BB.Settings

local PaintballColorCallback = require(_G.BB.Modules.Callbacks.PaintballColor)
local PBG_Classes = {"Accoutrement", "Tool", "Accessory"} -- if hit.Parent:IsA... then color it

local FPS = 0

if RunService:IsClient() then
	RunService.Stepped:Connect(
		function(_, dt)
			FPS = 1 / dt
		end
	)
end

function IsAcceptableHit(player, hit)
	return hit.Parent:FindFirstChildWhichIsA("Humanoid") or 
		not (
		Collections:HasTag(hit,"Projectile") 
			or (hit.CanCollide == false) 
			or hit.Name == "Handle"
	)
end

local function PaintballDamageMultiplier(Projectile, HitPart)
	
	local properPart = Settings.PaintballGun.MultiplierPartNames[HitPart.Name]
		
	if Projectile.ProjectileType.Value == "PaintballGun" and properPart then
		
		Projectile.Damage.Value *= 1 + 2 / 3
		
		return Projectile.Damage.Value
	end
	return false
end

--[[
	This function handles the hit detection for both the Superball and Slingshot.
	Incorporates hit detection, damage and indicators all on the client to maximize
	experience. 
]]

local HitModule = {};

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
		local hat = table.find(PBG_Classes, hit.Parent.ClassName)

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

				PaintballDamageMultiplier(projectile, hit)
				
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
				
				if ProjectileType == "PaintballGun" and PaintballColorCallback(hit, player) and Settings.InstantDamage then
					FireToServer = true
					
					projectile.Ready.Value = false
					Aesthetics:PaintballColor(hit, projectile.Color)
					Aesthetics:ExplodePaintball(projectile)
					
					TouchedConnection:Disconnect()
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

	print("\nDEBUG OF CLIENTOBJECT MODULES")
	for _, child in next, _G.BB.ClientObjects:GetChildren() do
		print(child.Name, "\t", child.ClassName)
	end
	print("\nEND OF DEBUG OF CLIENTOBJECT MODULES")

    HitModule:HandleHitDetection(Superball, count)
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
    