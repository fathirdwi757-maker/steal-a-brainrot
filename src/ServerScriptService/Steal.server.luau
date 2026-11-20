-- Steal: the tension at the heart of STEAL A BRAINROT.
--
-- Every brainrot standing on a rival's base carries a Steal prompt. Holding
-- it rips the brainrot off its stand and puts it on the thief's head: their
-- WalkSpeed drops by the brainrot's CarrySlowdown, so a Dragon Cannelloni
-- haul is a slow, desperate walk. Touching their own base's delivery pad
-- banks the steal through the Economy's PlaceRequest. Dying on the way home
-- sends the brainrot back to its owner's base instead.
--
-- The same script runs the defence: the LockBase RemoteEvent from the HUD
-- raises the owner's lock wall for 30 seconds (nobody can steal from a
-- locked base), with a 60 second cooldown from the moment it is raised.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local BrainrotData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))

local LOCK_DURATION = 30
local LOCK_COOLDOWN = 60
local DEFAULT_WALKSPEED = 16

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local notifyRemote = remotes:WaitForChild("Notify")
local lockRemote = remotes:WaitForChild("LockBase")
local placeRequest = ServerStorage:WaitForChild("PlaceRequest")

local carriedModels: { [Player]: Model } = {}

local function notify(player: Player, message: string)
	notifyRemote:FireClient(player, message)
end

local function findBaseOfPlayer(player: Player): Model?
	local basesFolder = Workspace:WaitForChild("Bases")
	for _, base in ipairs(basesFolder:GetChildren()) do
		if base:GetAttribute("OwnerUserId") == player.UserId then
			return base
		end
	end
	return nil
end

local function setWalkSpeed(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local carryingName = player:GetAttribute("CarryingName")
	local brainrot = carryingName and BrainrotData.GetBrainrot(carryingName)
	if brainrot then
		humanoid.WalkSpeed = DEFAULT_WALKSPEED * (1 - brainrot.CarrySlowdown)
	else
		humanoid.WalkSpeed = DEFAULT_WALKSPEED
	end
end

local function clearCarrying(player: Player)
	player:SetAttribute("CarryingName", nil)
	player:SetAttribute("CarryOriginUserId", nil)
	local model = carriedModels[player]
	if model then
		model:Destroy()
		carriedModels[player] = nil
	end
	setWalkSpeed(player)
end

-- ReturnCarryHome: a thief who dies or leaves drops the haul, and it goes
-- back to the base it was stolen from.
local function returnCarryHome(player: Player)
	local carryingName = player:GetAttribute("CarryingName")
	local originUserId = player:GetAttribute("CarryOriginUserId")
	if carryingName and originUserId then
		local origin = Players:GetPlayerByUserId(originUserId)
		if origin then
			placeRequest:Fire(origin, carryingName)
			notify(origin, "Your " .. carryingName .. " was recovered and is back on your base!")
		end
	end
	clearCarrying(player)
end

local function onStealPrompt(player: Player, placedModel: Model, base: Model)
	local ownerUserId = placedModel:GetAttribute("OwnerUserId")
	if ownerUserId == player.UserId then
		return
	end
	if base:GetAttribute("Locked") then
		notify(player, "That base is LOCKED - its brainrots are safe for now!")
		return
	end
	if player:GetAttribute("CarryingName") then
		notify(player, "You are already carrying a brainrot - run it home first!")
		return
	end
	local brainrotName = placedModel:GetAttribute("BrainrotName")
	local brainrot = brainrotName and BrainrotData.GetBrainrot(brainrotName)
	if not brainrot then
		return
	end

	-- Free the stand the brainrot stood on, then take it off the base.
	local standIndex = placedModel:GetAttribute("StandIndex")
	local stands = base:FindFirstChild("Stands")
	if stands and standIndex then
		for _, stand in ipairs(stands:GetChildren()) do
			if stand:GetAttribute("StandIndex") == standIndex then
				stand:SetAttribute("Occupied", false)
			end
		end
	end
	placedModel:Destroy()

	local carry = BrainrotData.BuildModel(brainrot, "STOLEN!")
	carry.Name = "Carried_" .. brainrot.Name
	carry.Parent = Workspace
	carriedModels[player] = carry

	player:SetAttribute("CarryingName", brainrot.Name)
	player:SetAttribute("CarryOriginUserId", ownerUserId)
	setWalkSpeed(player)

	notify(player, "You stole " .. brainrot.Name .. "! Run it to your base's green pad!")
	local victim = ownerUserId and Players:GetPlayerByUserId(ownerUserId)
	if victim then
		notify(victim, player.DisplayName .. " stole your " .. brainrot.Name .. "! Chase them down!")
	end
end

local function watchPlacedModel(model: Model, base: Model)
	task.defer(function()
		if not model.Parent or not model:GetAttribute("Placed") then
			return
		end
		local body = model:FindFirstChild("Body")
		if not body or model:FindFirstChild("StealPrompt", true) then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "StealPrompt"
		prompt.ActionText = "Steal"
		prompt.ObjectText = model:GetAttribute("BrainrotName") or model.Name
		prompt.HoldDuration = 0.8
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = body
		prompt.Triggered:Connect(function(player)
			if model.Parent == base then
				onStealPrompt(player, model, base)
			end
		end)
	end)
end

-- Watch every base for brainrots being placed, and hook every delivery pad.
local basesFolder = Workspace:WaitForChild("Bases")
for _, base in ipairs(basesFolder:GetChildren()) do
	base.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			watchPlacedModel(child, base)
		end
	end)
	for _, child in ipairs(base:GetChildren()) do
		if child:IsA("Model") then
			watchPlacedModel(child, base)
		end
	end
	local pad = base:FindFirstChild("DeliverPad")
	if pad then
		pad.Touched:Connect(function(hit)
			local character = hit.Parent
			local player = character and Players:GetPlayerFromCharacter(character)
			if player and player:GetAttribute("CarryingName") and base:GetAttribute("OwnerUserId") == player.UserId then
				local carryingName = player:GetAttribute("CarryingName")
				clearCarrying(player)
				placeRequest:Fire(player, carryingName)
			end
		end)
	end
end

-- Keep every carried brainrot riding on its thief's head.
RunService.Heartbeat:Connect(function()
	for player, model in pairs(carriedModels) do
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if head then
			model:PivotTo(head.CFrame * CFrame.new(0, 2.4, 0))
		end
	end
end)

-- The base lock: raise the wall, block steals for LOCK_DURATION seconds, and
-- keep the button on cooldown for LOCK_COOLDOWN seconds in all.
lockRemote.OnServerEvent:Connect(function(player)
	local base = findBaseOfPlayer(player)
	if not base then
		notify(player, "You have no base to lock!")
		return
	end
	local now = os.clock()
	local readyAt = base:GetAttribute("LockReadyAt") or 0
	if now < readyAt then
		notify(player, "Base lock recharging - " .. math.ceil(readyAt - now) .. "s to go")
		return
	end
	base:SetAttribute("Locked", true)
	base:SetAttribute("LockReadyAt", now + LOCK_COOLDOWN)
	local wall = base:FindFirstChild("LockWall")
	if wall then
		wall.Transparency = 0.35
		wall.CanCollide = true
	end
	notify(player, "Base LOCKED for " .. LOCK_DURATION .. " seconds - nothing can be stolen!")
	task.delay(LOCK_DURATION, function()
		base:SetAttribute("Locked", false)
		local lockWall = base:FindFirstChild("LockWall")
		if lockWall then
			lockWall.Transparency = 1
			lockWall.CanCollide = false
		end
	end)
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		-- A fresh character means the old one died: the haul goes home.
		if player:GetAttribute("CarryingName") then
			returnCarryHome(player)
		end
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			if player:GetAttribute("CarryingName") then
				returnCarryHome(player)
			end
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	if player:GetAttribute("CarryingName") then
		returnCarryHome(player)
	end
	carriedModels[player] = nil
end)
