-- Economy: cash, income and putting brainrots on stands.
--
-- Every player gets a leaderstats folder with Cash (starting at $100, enough
-- for a first Tralalero Tralala off the belt) and an Income readout. Once a
-- second, each player is paid the summed IncomePerSecond of every brainrot
-- standing on their base. Buying runs through the BuyRequest BindableEvent
-- the Conveyor fires: the Economy checks the price against the buyer's cash,
-- finds a free stand on their base and places the brainrot there. The Steal
-- script uses the PlaceRequest BindableEvent to bank a delivered steal the
-- same way, free of charge.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local BrainrotData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))

local STARTING_CASH = 100

-- The bindables the other server scripts fire. The Conveyor and the Steal
-- script wait for these, so this script creates them before anything else.
local buyRequest = Instance.new("BindableEvent")
buyRequest.Name = "BuyRequest"
buyRequest.Parent = ServerStorage

local placeRequest = Instance.new("BindableEvent")
placeRequest.Name = "PlaceRequest"
placeRequest.Parent = ServerStorage

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local notifyRemote = remotes:WaitForChild("Notify")

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

local function findFreeStand(base: Model): Part?
	local stands = base:FindFirstChild("Stands")
	if not stands then
		return nil
	end
	for _, stand in ipairs(stands:GetChildren()) do
		if stand:IsA("Part") and stand:GetAttribute("StandIndex") and not stand:GetAttribute("Occupied") then
			return stand
		end
	end
	return nil
end

-- PlaceBrainrot: stand a brainrot on a base's free stand, earning for its
-- owner. Returns false when the base has no free stand.
local function placeBrainrot(player: Player, brainrotName: string): boolean
	local brainrot = BrainrotData.GetBrainrot(brainrotName)
	local base = findBaseOfPlayer(player)
	if not brainrot or not base then
		return false
	end
	local stand = findFreeStand(base)
	if not stand then
		return false
	end
	local model = BrainrotData.BuildModel(brainrot, "+$" .. BrainrotData.FormatMoney(brainrot.IncomePerSecond) .. "/s")
	model:SetAttribute("Placed", true)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("StandIndex", stand:GetAttribute("StandIndex"))
	local top = stand.Position + Vector3.new(0, stand.Size.Y / 2 + 0.35, 0)
	model:PivotTo(CFrame.new(top))
	model.Parent = base
	stand:SetAttribute("Occupied", true)
	return true
end

local function onBuyRequest(player: Player, offerModel: Model)
	if typeof(offerModel) ~= "Instance" or not offerModel:IsA("Model") then
		return
	end
	local brainrotName = offerModel:GetAttribute("BrainrotName")
	local brainrot = brainrotName and BrainrotData.GetBrainrot(brainrotName)
	if not brainrot then
		return
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if not cash then
		return
	end
	if cash.Value < brainrot.Price then
		notify(player, "Not enough cash for " .. brainrot.Name .. " - it costs $" .. BrainrotData.FormatMoney(brainrot.Price))
		return
	end
	if not findBaseOfPlayer(player) then
		notify(player, "You have no base to put it on!")
		return
	end
	local base = findBaseOfPlayer(player)
	if base and not findFreeStand(base) then
		notify(player, "Your base is full - steal a bigger haul home first!")
		return
	end
	cash.Value -= brainrot.Price
	if placeBrainrot(player, brainrot.Name) then
		offerModel:Destroy()
		notify(player, "Bought " .. brainrot.Name .. "! +$" .. BrainrotData.FormatMoney(brainrot.IncomePerSecond) .. "/s on your base")
	else
		cash.Value += brainrot.Price
		notify(player, "Could not place " .. brainrot.Name .. " - refunded")
	end
end

local function onPlaceRequest(player: Player, brainrotName: string)
	local brainrot = BrainrotData.GetBrainrot(brainrotName)
	if not brainrot then
		return
	end
	if placeBrainrot(player, brainrotName) then
		notify(player, "Delivered " .. brainrotName .. " to your base! +$" .. BrainrotData.FormatMoney(brainrot.IncomePerSecond) .. "/s")
	else
		-- No room on the base: the haul is sold on the spot instead.
		local leaderstats = player:FindFirstChild("leaderstats")
		local cash = leaderstats and leaderstats:FindFirstChild("Cash")
		if cash then
			cash.Value += brainrot.Price
		end
		notify(player, "Base full - sold " .. brainrotName .. " for $" .. BrainrotData.FormatMoney(brainrot.Price))
	end
end

buyRequest.Event:Connect(onBuyRequest)
placeRequest.Event:Connect(onPlaceRequest)

local function setupPlayer(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = STARTING_CASH
	cash.Parent = leaderstats

	local income = Instance.new("IntValue")
	income.Name = "Income"
	income.Value = 0
	income.Parent = leaderstats

	leaderstats.Parent = player
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

-- The income tick: once a second, pay every player the total rate of the
-- brainrots standing on their base and refresh their Income readout.
task.spawn(function()
	while true do
		task.wait(1)
		local basesFolder = Workspace:FindFirstChild("Bases")
		if basesFolder then
			for _, player in ipairs(Players:GetPlayers()) do
				local total = 0
				for _, base in ipairs(basesFolder:GetChildren()) do
					if base:GetAttribute("OwnerUserId") == player.UserId then
						for _, child in ipairs(base:GetChildren()) do
							if child:IsA("Model") and child:GetAttribute("Placed") then
								local brainrot = BrainrotData.GetBrainrot(child:GetAttribute("BrainrotName"))
								if brainrot then
									total += brainrot.IncomePerSecond
								end
							end
						end
					end
				end
				local leaderstats = player:FindFirstChild("leaderstats")
				if leaderstats then
					local cash = leaderstats:FindFirstChild("Cash")
					local income = leaderstats:FindFirstChild("Income")
					if cash and total > 0 then
						cash.Value += total
					end
					if income then
						income.Value = total
					end
				end
			end
		end
	end
end)
