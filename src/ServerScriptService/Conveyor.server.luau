-- Conveyor: the brainrot supply line.
--
-- Every few seconds a new brainrot rolls onto the west end of the belt: its
-- rarity is rolled with BrainrotData's weights, so Commons are everyday and
-- a Mythic is an event. The offer rides the belt east at a steady speed with
-- a floating name-and-price label and a ProximityPrompt; pressing the prompt
-- hands the offer to the Economy through the BuyRequest BindableEvent, and
-- whatever reaches the east end unpurchased rolls off and is removed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local BrainrotData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))

local BELT_START_X = -106
local BELT_END_X = 106
local BELT_SURFACE_Y = 1.85
local BELT_SPEED = 7 -- studs per second
local SPAWN_INTERVAL = 3.2
local MAX_OFFERS = 8

local offersFolder = Instance.new("Folder")
offersFolder.Name = "Offers"
offersFolder.Parent = Workspace

local buyRequest = ServerStorage:WaitForChild("BuyRequest")

local offers: { Model } = {}

local function spawnOffer()
	local brainrot = BrainrotData.RollBrainrot()
	local model = BrainrotData.BuildModel(brainrot, "$" .. BrainrotData.FormatMoney(brainrot.Price))
	model:SetAttribute("Price", brainrot.Price)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Buy"
	prompt.ObjectText = brainrot.Name .. " - $" .. BrainrotData.FormatMoney(brainrot.Price)
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart

	prompt.Triggered:Connect(function(player)
		if model.Parent == offersFolder then
			buyRequest:Fire(player, model)
		end
	end)

	model:PivotTo(CFrame.new(BELT_START_X, BELT_SURFACE_Y, 0))
	model.Parent = offersFolder
	table.insert(offers, model)
end

-- The spawn loop: keep the belt stocked while the server runs.
task.spawn(function()
	while true do
		if #offers < MAX_OFFERS then
			spawnOffer()
		end
		task.wait(SPAWN_INTERVAL)
	end
end)

-- The ride: every heartbeat each live offer slides east; offers the Economy
-- bought have left the folder (and get pruned here), and offers that reach
-- the end of the belt are removed to make room for new rolls.
RunService.Heartbeat:Connect(function(deltaTime)
	for index = #offers, 1, -1 do
		local model = offers[index]
		if model.Parent ~= offersFolder then
			table.remove(offers, index)
		else
			local position = model:GetPivot().Position
			if position.X >= BELT_END_X then
				model:Destroy()
				table.remove(offers, index)
			else
				model:PivotTo(CFrame.new(position.X + BELT_SPEED * deltaTime, BELT_SURFACE_Y, 0))
			end
		end
	end
end)
