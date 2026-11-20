-- BrainrotData: the single source of truth for the STEAL A BRAINROT cast.
--
-- Every brainrot in the game is one row of this table: what it costs to buy off
-- the conveyor, how much cash it earns per second while it stands on a base,
-- how much it slows down a thief who carries it home, and the colour its
-- blocky model is built from. The conveyor, the economy and the steal loop all
-- read this module, and BuildModel below is the one place that turns a row
-- into a 3D character, so an offer on the belt, a brainrot on a stand and a
-- stolen brainrot on a thief's head always look the same.

local BrainrotData = {}

export type Brainrot = {
	Name: string,
	Rarity: string,
	Price: number,
	IncomePerSecond: number,
	CarrySlowdown: number,
	Color: Color3,
}

local function entry(name: string, rarity: string, price: number, income: number, slowdown: number, r: number, g: number, b: number): Brainrot
	return {
		Name = name,
		Rarity = rarity,
		Price = price,
		IncomePerSecond = income,
		CarrySlowdown = slowdown,
		Color = Color3.fromRGB(r, g, b),
	}
end

-- The rarity ladder, cheapest first. Labels and stand trims use these colours.
BrainrotData.RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

BrainrotData.RarityColors = {
	Common = Color3.fromRGB(175, 180, 190),
	Rare = Color3.fromRGB(70, 150, 255),
	Epic = Color3.fromRGB(175, 85, 255),
	Legendary = Color3.fromRGB(255, 175, 30),
	Mythic = Color3.fromRGB(255, 60, 95),
}

-- How likely each rarity is to roll onto the conveyor, as weights of 100.
BrainrotData.RarityWeights = {
	Common = 46,
	Rare = 28,
	Epic = 16,
	Legendary = 7,
	Mythic = 3,
}

-- The cast: fifteen Italian brainrot legends, priced from a first-buy $50
-- Tralalero Tralala up to the $7,500,000 Dragon Cannelloni.
BrainrotData.List = {
	entry("Tralalero Tralala", "Common", 50, 1, 0.05, 80, 170, 255),
	entry("Tung Tung Tung Sahur", "Common", 120, 3, 0.08, 165, 110, 65),
	entry("Brr Brr Patapim", "Common", 300, 7, 0.10, 90, 200, 95),
	entry("Chimpanzini Bananini", "Rare", 750, 16, 0.13, 255, 215, 60),
	entry("Cappuccino Assassino", "Rare", 1800, 35, 0.16, 205, 165, 110),
	entry("Frigo Camelo", "Rare", 4000, 70, 0.18, 205, 240, 255),
	entry("Bombardiro Crocodilo", "Epic", 9000, 150, 0.22, 110, 165, 70),
	entry("Bombombini Gusini", "Epic", 20000, 320, 0.25, 255, 140, 40),
	entry("La Vaca Saturno Saturnita", "Epic", 45000, 650, 0.28, 205, 120, 255),
	entry("Giraffa Celeste", "Legendary", 100000, 1400, 0.32, 80, 255, 220),
	entry("Matteo", "Legendary", 220000, 3000, 0.35, 255, 70, 70),
	entry("La Grande Combinazione", "Legendary", 500000, 6500, 0.38, 255, 190, 40),
	entry("Los Tralaleritos", "Mythic", 1200000, 15000, 0.42, 130, 205, 255),
	entry("Graipuss Medussi", "Mythic", 2800000, 34000, 0.46, 155, 60, 225),
	entry("Dragon Cannelloni", "Mythic", 7500000, 85000, 0.50, 255, 90, 30),
}

local byName: { [string]: Brainrot } = {}
local byRarity: { [string]: { Brainrot } } = {}

for _, brainrot in ipairs(BrainrotData.List) do
	byName[brainrot.Name] = brainrot
	if not byRarity[brainrot.Rarity] then
		byRarity[brainrot.Rarity] = {}
	end
	table.insert(byRarity[brainrot.Rarity], brainrot)
end

-- GetBrainrot: one cast member by its exact name, or nil.
function BrainrotData.GetBrainrot(name: string): Brainrot?
	return byName[name]
end

-- GetByRarity: every cast member of one rarity, in price order.
function BrainrotData.GetByRarity(rarity: string): { Brainrot }
	return byRarity[rarity] or {}
end

-- RollRarity: pick a rarity by the conveyor weights above.
function BrainrotData.RollRarity(): string
	local total = 0
	for _, rarity in ipairs(BrainrotData.RarityOrder) do
		total += BrainrotData.RarityWeights[rarity] or 0
	end
	local roll = math.random() * total
	for _, rarity in ipairs(BrainrotData.RarityOrder) do
		roll -= BrainrotData.RarityWeights[rarity] or 0
		if roll <= 0 then
			return rarity
		end
	end
	return "Common"
end

-- RollBrainrot: a random cast member, weighted so Mythics stay rare.
function BrainrotData.RollBrainrot(): Brainrot
	local pool = BrainrotData.GetByRarity(BrainrotData.RollRarity())
	return pool[math.random(1, #pool)]
end

-- FormatMoney: 1234567 -> "1,234,567", for prices, labels and the HUD.
function BrainrotData.FormatMoney(amount: number): string
	local text = tostring(math.floor(amount))
	local grouped = ""
	while #text > 3 do
		grouped = "," .. string.sub(text, -3) .. grouped
		text = string.sub(text, 1, -4)
	end
	return text .. grouped
end

-- BuildModel: build the blocky 3D character for one cast member. The model
-- stands on its pivot (feet at the pivot's position), wears its own colour,
-- gets a rarity-coloured crest, two eyes, and a floating label that shows its
-- name over a caller-chosen second line (a price on the belt, an income rate
-- on a base). Every part is anchored: the game moves models with PivotTo.
function BrainrotData.BuildModel(brainrot: Brainrot, secondLine: string): Model
	local model = Instance.new("Model")
	model.Name = brainrot.Name
	model:SetAttribute("BrainrotName", brainrot.Name)
	model:SetAttribute("Rarity", brainrot.Rarity)

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(3, 3.4, 2)
	body.CFrame = CFrame.new(0, 2.2, 0)
	body.Color = brainrot.Color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2.4, 2.4, 2.4)
	head.CFrame = CFrame.new(0, 5.1, 0)
	head.Color = brainrot.Color:Lerp(Color3.new(1, 1, 1), 0.18)
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CanCollide = false
	head.Parent = model

	for _, side in ipairs({ -0.55, 0.55 }) do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Size = Vector3.new(0.42, 0.55, 0.1)
		eye.CFrame = CFrame.new(side, 5.35, -1.21)
		eye.Color = Color3.fromRGB(20, 20, 25)
		eye.Material = Enum.Material.SmoothPlastic
		eye.Anchored = true
		eye.CanCollide = false
		eye.Parent = model
	end

	local crest = Instance.new("Part")
	crest.Name = "Crest"
	crest.Size = Vector3.new(1.7, 0.8, 1.7)
	crest.CFrame = CFrame.new(0, 6.7, 0)
	crest.Color = BrainrotData.RarityColors[brainrot.Rarity]
	crest.Material = Enum.Material.Neon
	crest.Anchored = true
	crest.CanCollide = false
	crest.Parent = model

	local label = Instance.new("BillboardGui")
	label.Name = "Label"
	label.Size = UDim2.fromOffset(260, 76)
	label.StudsOffset = Vector3.new(0, 2.6, 0)
	label.AlwaysOnTop = true
	label.MaxDistance = 90
	label.Adornee = head
	label.Parent = model

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = BrainrotData.RarityColors[brainrot.Rarity]
	nameLabel.TextStrokeTransparency = 0.35
	nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLabel.Text = brainrot.Name
	nameLabel.Parent = label

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "InfoLabel"
	infoLabel.Size = UDim2.new(1, 0, 0.45, 0)
	infoLabel.Position = UDim2.new(0, 0, 0.55, 0)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Font = Enum.Font.GothamBold
	infoLabel.TextScaled = true
	infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	infoLabel.TextStrokeTransparency = 0.35
	infoLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	infoLabel.Text = secondLine
	infoLabel.Parent = label

	model.PrimaryPart = body
	return model
end

return BrainrotData
