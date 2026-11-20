-- HUD: the STEAL A BRAINROT screen interface.
--
-- A ScreenGui over the 3D world: the game's title across the top centre, the
-- player's cash and income rate at the top right (kept clear of the top-left
-- corner, where Roblox draws its own menu buttons), a LOCK BASE button at
-- the bottom right that fires the LockBase RemoteEvent, a toast line under
-- the title that shows whatever the server's Notify RemoteEvent sends
-- (bought, stolen, delivered, lock results), and a one-line help hint at the
-- bottom left.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local notifyRemote = remotes:WaitForChild("Notify")
local lockRemote = remotes:WaitForChild("LockBase")

local leaderstats = player:WaitForChild("leaderstats")
local cashValue = leaderstats:WaitForChild("Cash")
local incomeValue = leaderstats:WaitForChild("Income")

local function formatMoney(amount: number): string
	local text = tostring(math.floor(amount))
	local grouped = ""
	while #text > 3 do
		grouped = "," .. string.sub(text, -3) .. grouped
		text = string.sub(text, 1, -4)
	end
	return text .. grouped
end

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.new(0.5, 0, 0, 14)
title.Size = UDim2.new(0, 620, 0, 52)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(255, 210, 60)
title.TextStrokeTransparency = 0.3
title.TextStrokeColor3 = Color3.new(0, 0, 0)
title.Text = "STEAL A BRAINROT"
title.Parent = gui

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 72)
toast.Size = UDim2.new(0, 720, 0, 36)
toast.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
toast.BackgroundTransparency = 0.35
toast.Font = Enum.Font.GothamBold
toast.TextScaled = true
toast.TextColor3 = Color3.fromRGB(255, 255, 255)
toast.Text = ""
toast.Visible = false
toast.Parent = gui

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 10)
toastCorner.Parent = toast

local cashLabel = Instance.new("TextLabel")
cashLabel.Name = "CashLabel"
cashLabel.AnchorPoint = Vector2.new(1, 0)
cashLabel.Position = UDim2.new(1, -16, 0, 14)
cashLabel.Size = UDim2.new(0, 250, 0, 44)
cashLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
cashLabel.BackgroundTransparency = 0.25
cashLabel.Font = Enum.Font.GothamBlack
cashLabel.TextScaled = true
cashLabel.TextColor3 = Color3.fromRGB(120, 255, 140)
cashLabel.Text = "$100"
cashLabel.Parent = gui

local cashCorner = Instance.new("UICorner")
cashCorner.CornerRadius = UDim.new(0, 10)
cashCorner.Parent = cashLabel

local incomeLabel = Instance.new("TextLabel")
incomeLabel.Name = "IncomeLabel"
incomeLabel.AnchorPoint = Vector2.new(1, 0)
incomeLabel.Position = UDim2.new(1, -16, 0, 62)
incomeLabel.Size = UDim2.new(0, 250, 0, 30)
incomeLabel.BackgroundTransparency = 1
incomeLabel.Font = Enum.Font.GothamBold
incomeLabel.TextScaled = true
incomeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
incomeLabel.TextStrokeTransparency = 0.4
incomeLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
incomeLabel.Text = "+$0/s"
incomeLabel.Parent = gui

local lockButton = Instance.new("TextButton")
lockButton.Name = "LockButton"
lockButton.AnchorPoint = Vector2.new(1, 1)
lockButton.Position = UDim2.new(1, -16, 1, -16)
lockButton.Size = UDim2.new(0, 230, 0, 58)
lockButton.BackgroundColor3 = Color3.fromRGB(50, 140, 255)
lockButton.Font = Enum.Font.GothamBlack
lockButton.TextScaled = true
lockButton.TextColor3 = Color3.fromRGB(255, 255, 255)
lockButton.TextStrokeTransparency = 0.5
lockButton.Text = "LOCK BASE"
lockButton.AutoButtonColor = true
lockButton.Parent = gui

local lockCorner = Instance.new("UICorner")
lockCorner.CornerRadius = UDim.new(0, 12)
lockCorner.Parent = lockButton

local helpLabel = Instance.new("TextLabel")
helpLabel.Name = "HelpLabel"
helpLabel.AnchorPoint = Vector2.new(0, 1)
helpLabel.Position = UDim2.new(0, 16, 1, -16)
helpLabel.Size = UDim2.new(0, 560, 0, 28)
helpLabel.BackgroundTransparency = 1
helpLabel.Font = Enum.Font.GothamBold
helpLabel.TextScaled = true
helpLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
helpLabel.TextStrokeTransparency = 0.4
helpLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
helpLabel.TextXAlignment = Enum.TextXAlignment.Left
helpLabel.Text = "Buy brainrots off the belt - steal rivals' - run them home!"
helpLabel.Parent = gui

local function refreshCash()
	cashLabel.Text = "$" .. formatMoney(cashValue.Value)
	incomeLabel.Text = "+$" .. formatMoney(incomeValue.Value) .. "/s"
end

cashValue.Changed:Connect(refreshCash)
incomeValue.Changed:Connect(refreshCash)
refreshCash()

lockButton.MouseButton1Click:Connect(function()
	lockRemote:FireServer()
end)

local toastToken = 0
notifyRemote.OnClientEvent:Connect(function(message: string)
	toastToken += 1
	local myToken = toastToken
	toast.Text = message
	toast.Visible = true
	task.delay(3.5, function()
		if toastToken == myToken then
			toast.Visible = false
		end
	end)
end)
