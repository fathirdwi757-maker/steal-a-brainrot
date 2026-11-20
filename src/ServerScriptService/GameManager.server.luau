-- GameManager: builds the whole STEAL A BRAINROT world when the server starts
-- and runs the base plots.
--
-- The world is one big lawn, a conveyor belt running east-west through the
-- middle, and eight player bases around it, four on the north side and four
-- on the south. Each base is a coloured floor pad with six display stands, an
-- owner sign, a glowing delivery pad at its front edge and a lock wall the
-- Steal script raises when the owner locks the base. GameManager also creates
-- the shared RemoteEvents (ReplicatedStorage.Remotes) before anything else
-- needs them, hands a free base to every player who joins, teleports them to
-- it, and frees the base again when they leave.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BASE_COUNT = 8
local STANDS_PER_BASE = 6

-- Base plots: four north of the belt (z = -42), four south (z = +42).
local BASE_POSITIONS = {
	Vector3.new(-87, 0, -42), Vector3.new(-29, 0, -42),
	Vector3.new(29, 0, -42), Vector3.new(87, 0, -42),
	Vector3.new(-87, 0, 42), Vector3.new(-29, 0, 42),
	Vector3.new(29, 0, 42), Vector3.new(87, 0, 42),
}

local BASE_COLORS = {
	Color3.fromRGB(255, 120, 120), Color3.fromRGB(255, 180, 90),
	Color3.fromRGB(255, 235, 120), Color3.fromRGB(140, 235, 130),
	Color3.fromRGB(110, 220, 255), Color3.fromRGB(140, 160, 255),
	Color3.fromRGB(205, 140, 255), Color3.fromRGB(255, 140, 205),
}

-- The remotes every other script talks through. Notify carries a short text
-- message from the server to one player's HUD; LockBase carries the HUD's
-- lock button press to the server.
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local notifyRemote = Instance.new("RemoteEvent")
notifyRemote.Name = "Notify"
notifyRemote.Parent = remotes

local lockRemote = Instance.new("RemoteEvent")
lockRemote.Name = "LockBase"
lockRemote.Parent = remotes

local function makePart(name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- The lawn and the plaza slab the belt sits on.
local ground = makePart("Ground", Vector3.new(320, 1, 230), Vector3.new(0, -0.5, 0), Color3.fromRGB(96, 178, 88), Enum.Material.Grass)
ground.Parent = Workspace

local plaza = makePart("Plaza", Vector3.new(250, 0.6, 30), Vector3.new(0, 0.05, 0), Color3.fromRGB(214, 196, 160), Enum.Material.Sand)
plaza.Parent = Workspace

-- The conveyor: a dark belt bed, yellow rails, end blocks and a big overhead
-- sign, so the middle of the map reads as the place brainrots arrive.
local belt = makePart("Belt", Vector3.new(232, 1.6, 11), Vector3.new(0, 0.8, 0), Color3.fromRGB(42, 42, 52), Enum.Material.Metal)
belt.Parent = Workspace

local beltTop = makePart("BeltTop", Vector3.new(232, 0.25, 9.4), Vector3.new(0, 1.72, 0), Color3.fromRGB(66, 66, 80), Enum.Material.DiamondPlate)
beltTop.CanCollide = false
beltTop.Parent = Workspace

for _, side in ipairs({ -5.8, 5.8 }) do
	local rail = makePart("BeltRail", Vector3.new(232, 0.9, 0.7), Vector3.new(0, 2.1, side), Color3.fromRGB(255, 200, 40), Enum.Material.Metal)
	rail.Parent = Workspace
end

for _, endX in ipairs({ -118, 118 }) do
	local cap = makePart("BeltEnd", Vector3.new(4, 3.4, 12), Vector3.new(endX, 1.7, 0), Color3.fromRGB(255, 120, 60), Enum.Material.Metal)
	cap.Parent = Workspace
end

for _, postX in ipairs({ -20, 20 }) do
	local post = makePart("SignPost", Vector3.new(1.2, 10, 1.2), Vector3.new(postX, 5, 0), Color3.fromRGB(90, 90, 100), Enum.Material.Metal)
	post.Parent = Workspace
end

local signBoard = makePart("ConveyorSign", Vector3.new(42, 5, 1), Vector3.new(0, 10.5, 0), Color3.fromRGB(35, 35, 45), Enum.Material.Metal)
signBoard.Parent = Workspace

local signGui = Instance.new("SurfaceGui")
signGui.Face = Enum.NormalId.Front
signGui.Parent = signBoard

local signText = Instance.new("TextLabel")
signText.Size = UDim2.new(1, 0, 1, 0)
signText.BackgroundTransparency = 1
signText.Font = Enum.Font.GothamBlack
signText.TextScaled = true
signText.TextColor3 = Color3.fromRGB(255, 210, 60)
signText.TextStrokeTransparency = 0.5
signText.Text = "BRAINROT CONVEYOR"
signText.Parent = signGui

-- A ring of blocky trees around the lawn so the world has edges.
local treeSpots = {
	Vector3.new(-140, 0, -80), Vector3.new(-70, 0, -95), Vector3.new(10, 0, -90),
	Vector3.new(90, 0, -95), Vector3.new(145, 0, -60), Vector3.new(-145, 0, 55),
	Vector3.new(-80, 0, 95), Vector3.new(0, 0, 98), Vector3.new(80, 0, 92),
	Vector3.new(148, 0, 70), Vector3.new(-148, 0, -10), Vector3.new(150, 0, 5),
}
for index, spot in ipairs(treeSpots) do
	local trunk = makePart("TreeTrunk", Vector3.new(1.6, 6, 1.6), spot + Vector3.new(0, 3, 0), Color3.fromRGB(120, 82, 50), Enum.Material.Wood)
	trunk.Parent = Workspace
	local leaves = Instance.new("Part")
	leaves.Name = "TreeLeaves"
	leaves.Shape = Enum.PartType.Ball
	leaves.Size = Vector3.new(8, 8, 8)
	leaves.Position = spot + Vector3.new(0, 9, 0)
	leaves.Color = Color3.fromRGB(52, 148 - (index % 3) * 12, 58)
	leaves.Material = Enum.Material.Grass
	leaves.Anchored = true
	leaves.Parent = Workspace
end

-- The bases. Everything the other scripts need to know about a base lives in
-- attributes on its Model: BaseIndex, OwnerUserId (0 while free) and Locked.
local basesFolder = Instance.new("Folder")
basesFolder.Name = "Bases"
basesFolder.Parent = Workspace

local function buildBase(index: number, position: Vector3): Model
	local base = Instance.new("Model")
	base.Name = "Base" .. index
	base:SetAttribute("BaseIndex", index)
	base:SetAttribute("OwnerUserId", 0)
	base:SetAttribute("Locked", false)
	base:SetAttribute("LockReadyAt", 0)

	local facing = if position.Z < 0 then 1 else -1 -- +1: the belt is at +z of this base

	local skirt = makePart("Skirt", Vector3.new(36, 0.8, 30), position + Vector3.new(0, 0.1, 0), BASE_COLORS[index]:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.SmoothPlastic)
	skirt.Parent = base

	local floor = makePart("Floor", Vector3.new(33, 1, 27), position + Vector3.new(0, 0.6, 0), BASE_COLORS[index], Enum.Material.SmoothPlastic)
	floor.Parent = base

	-- Six display stands, two rows of three, each a pedestal with a glowing
	-- top plate. Stands carry a StandIndex and an Occupied flag for Economy.
	local stands = Instance.new("Folder")
	stands.Name = "Stands"
	stands.Parent = base

	local standNumber = 0
	for _, rowZ in ipairs({ -6.5, 6.5 }) do
		for _, colX in ipairs({ -10, 0, 10 }) do
			standNumber += 1
			local stand = makePart("Stand" .. standNumber, Vector3.new(3.6, 1.4, 3.6), position + Vector3.new(colX, 1.8, rowZ), Color3.fromRGB(70, 70, 82), Enum.Material.Metal)
			stand:SetAttribute("StandIndex", standNumber)
			stand:SetAttribute("Occupied", false)
			stand.Parent = stands
			local plate = makePart("StandPlate", Vector3.new(4, 0.3, 4), position + Vector3.new(colX, 2.65, rowZ), Color3.fromRGB(255, 220, 90), Enum.Material.Neon)
			plate.CanCollide = false
			plate.Parent = stands
		end
	end

	-- The delivery pad at the front edge: a thief who reaches their own pad
	-- while carrying banks the brainrot they stole.
	local deliverPad = makePart("DeliverPad", Vector3.new(11, 0.5, 4.5), position + Vector3.new(0, 1.3, facing * 11), Color3.fromRGB(90, 255, 120), Enum.Material.Neon)
	deliverPad:SetAttribute("BaseIndex", index)
	deliverPad.Parent = base

	-- The lock wall across the front edge: invisible and walk-through until
	-- the Steal script raises it for a lock.
	local wall = makePart("LockWall", Vector3.new(33, 8, 1), position + Vector3.new(0, 4.5, facing * 13.5), Color3.fromRGB(90, 200, 255), Enum.Material.ForceField)
	wall.Transparency = 1
	wall.CanCollide = false
	wall.Parent = base

	-- The owner sign on the back edge, facing the belt.
	local sign = makePart("OwnerSign", Vector3.new(16, 4.5, 0.6), position + Vector3.new(0, 4.5, -facing * 13), Color3.fromRGB(35, 35, 45), Enum.Material.Metal)
	sign.Parent = base

	local gui = Instance.new("SurfaceGui")
	gui.Face = if facing == 1 then Enum.NormalId.Front else Enum.NormalId.Back
	gui.Parent = sign

	local text = Instance.new("TextLabel")
	text.Name = "SignText"
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextStrokeTransparency = 0.5
	text.Text = "BASE " .. index
	text.Parent = gui

	base.Parent = basesFolder
	return base
end

local bases: { Model } = {}
for index, position in ipairs(BASE_POSITIONS) do
	bases[index] = buildBase(index, position)
end

-- FindBaseOfPlayer: the base a player owns, or nil.
local function findBaseOfPlayer(player: Player): Model?
	for _, base in ipairs(bases) do
		if base:GetAttribute("OwnerUserId") == player.UserId then
			return base
		end
	end
	return nil
end

local function setSignText(base: Model, text: string)
	local sign = base:FindFirstChild("OwnerSign")
	local gui = sign and sign:FindFirstChildOfClass("SurfaceGui")
	local label = gui and gui:FindFirstChild("SignText")
	if label then
		label.Text = text
	end
end

local function assignBase(player: Player)
	if findBaseOfPlayer(player) then
		return
	end
	for _, base in ipairs(bases) do
		if base:GetAttribute("OwnerUserId") == 0 then
			base:SetAttribute("OwnerUserId", player.UserId)
			setSignText(base, player.DisplayName .. "'s BASE")
			return
		end
	end
end

local function freeBase(player: Player)
	local base = findBaseOfPlayer(player)
	if not base then
		return
	end
	base:SetAttribute("OwnerUserId", 0)
	base:SetAttribute("Locked", false)
	base:SetAttribute("LockReadyAt", 0)
	setSignText(base, "BASE " .. base:GetAttribute("BaseIndex"))
	-- Clear whatever the player left standing on the base.
	for _, child in ipairs(base:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("Placed") then
			child:Destroy()
		end
	end
	local stands = base:FindFirstChild("Stands")
	if stands then
		for _, stand in ipairs(stands:GetChildren()) do
			if stand:IsA("Part") and stand:GetAttribute("StandIndex") then
				stand:SetAttribute("Occupied", false)
			end
		end
	end
	local wall = base:FindFirstChild("LockWall")
	if wall then
		wall.Transparency = 1
		wall.CanCollide = false
	end
end

local function sendPlayerHome(player: Player)
	local base = findBaseOfPlayer(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if base and root then
		local floor = base:FindFirstChild("Floor")
		if floor then
			root.CFrame = CFrame.new(floor.Position + Vector3.new(0, 4, 0))
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	assignBase(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		sendPlayerHome(player)
	end)
end)

Players.PlayerRemoving:Connect(freeBase)

for _, player in ipairs(Players:GetPlayers()) do
	assignBase(player)
end
