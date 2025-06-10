local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Leaderstats = LocalPlayer.leaderstats
local Backpack = LocalPlayer.Backpack
local PlayerGui = LocalPlayer.PlayerGui
local ShecklesCount = Leaderstats.Sheckles
local GameInfo = MarketplaceService:GetProductInfo(game.PlaceId)

local ReGui = loadstring(game:HttpGet('https://raw.githubusercontent.com/depthso/Dear-ReGui/refs/heads/main/ReGui.lua'))()
local PrefabsId = "rbxassetid://" .. ReGui.PrefabsId
local GameEvents = ReplicatedStorage.GameEvents
local Farms = workspace.Farm

local Accent = {
    DarkGreen = Color3.fromRGB(45, 95, 25),
    Green = Color3.fromRGB(69, 142, 40),
    Brown = Color3.fromRGB(26, 20, 8),
}

ReGui:Init({Prefabs = InsertService:LoadLocalAsset(PrefabsId)})
ReGui:DefineTheme("GardenTheme", {
	WindowBg = Accent.Brown,
	TitleBarBg = Accent.DarkGreen,
	TitleBarBgActive = Accent.Green,
    ResizeGrab = Accent.DarkGreen,
    FrameBg = Accent.DarkGreen,
    FrameBgActive = Accent.Green,
	CollapsingHeaderBg = Accent.Green,
    ButtonsBg = Accent.Green,
    CheckMark = Accent.Green,
    SliderGrab = Accent.Green,
})

local SeedStock = {}
local OwnedSeeds = {}
local HarvestIgnores = {Normal = false, Gold = false, Rainbow = false}
local SelectedSeed, AutoPlantRandom, AutoPlant, AutoHarvest, AutoBuy, AutoBuyAll, SellThreshold, NoClip, AutoWalkAllowRandom, AutoSell, AutoWalk, AutoWalkStatus, AutoWalkMaxWait, SelectedSeedStock, AutoBuyFriendshipPot, AutoBuyAllSprinklers, AutoBuyWateringCan
local IsSelling = false

local function Plant(Position, Seed)
	GameEvents.Plant_RE:FireServer(Position, Seed)
	wait(.3)
}

local function GetFarmOwner(Farm)
	return Farm.Important.Data.Owner.Value
}

local function GetFarm(PlayerName)
	for _, Farm in next, Farms:GetChildren() do
		if GetFarmOwner(Farm) == PlayerName then return Farm end
	end
end

local function SellInventory()
	local Character = LocalPlayer.Character
	local Previous = Character:GetPivot()
	local PreviousSheckles = ShecklesCount.Value
	if IsSelling then return end
	IsSelling = true
	Character:PivotTo(CFrame.new(62, 4, -26))
	while wait() do
		if ShecklesCount.Value ~= PreviousSheckles then break end
		GameEvents.Sell_Inventory:FireServer()
	end
	Character:PivotTo(Previous)
	wait(0.2)
	IsSelling = false
}

local function BuySeed(Seed) GameEvents.BuySeedStock:FireServer(Seed) end
local function BuyFriendshipPot() GameEvents.BuyGearStock:FireServer("Friendship Pot") end
local function BuySprinkler(Type) GameEvents.BuyGearStock:FireServer(Type) end
local function BuyWateringCan() GameEvents.BuyGearStock:FireServer("Watering Can") end

local function BuyAllSprinklers()
	local sprinklers = {"Basic Sprinkler", "Advanced Sprinkler", "Godly Sprinkler", "Master Sprinkler"}
	for _, sprinkler in pairs(sprinklers) do
		BuySprinkler(sprinkler)
	end
end

local function BuyAllSelectedSeeds()
    local Seed = SelectedSeedStock.Selected
    local Stock = SeedStock[Seed]
	if not Stock or Stock <= 0 then return end
    for i = 1, Stock do BuySeed(Seed) end
}

local function BuyAllAvailableSeeds()
    for SeedName, Stock in pairs(SeedStock) do
        if Stock > 0 then
            for i = 1, Stock do BuySeed(SeedName) end
        end
    end
}

local function GetSeedInfo(Seed)
	local PlantName = Seed:FindFirstChild("Plant_Name")
	local Count = Seed:FindFirstChild("Numbers")
	if not PlantName then return end
	return PlantName.Value, Count.Value
}

local function CollectSeedsFromParent(Parent, Seeds)
	for _, Tool in next, Parent:GetChildren() do
		local Name, Count = GetSeedInfo(Tool)
		if Name then Seeds[Name] = {Count = Count, Tool = Tool} end
	end
}

local function CollectCropsFromParent(Parent, Crops)
	for _, Tool in next, Parent:GetChildren() do
		local Name = Tool:FindFirstChild("Item_String")
		if Name then table.insert(Crops, Tool) end
	end
}

local function GetOwnedSeeds()
	local Character = LocalPlayer.Character
	CollectSeedsFromParent(Backpack, OwnedSeeds)
	CollectSeedsFromParent(Character, OwnedSeeds)
	return OwnedSeeds
}

local function GetInvCrops()
	local Character = LocalPlayer.Character
	local Crops = {}
	CollectCropsFromParent(Backpack, Crops)
	CollectCropsFromParent(Character, Crops)
	return Crops
}

local function GetArea(Base)
	local Center = Base:GetPivot()
	local Size = Base.Size
	local X1 = math.ceil(Center.X - (Size.X/2))
	local Z1 = math.ceil(Center.Z - (Size.Z/2))
	local X2 = math.floor(Center.X + (Size.X/2))
	local Z2 = math.floor(Center.Z + (Size.Z/2))
	return X1, Z1, X2, Z2
}

local function EquipCheck(Tool)
    local Character = LocalPlayer.Character
    if Tool.Parent ~= Backpack then return end
    Character.Humanoid:EquipTool(Tool)
}

local MyFarm = GetFarm(LocalPlayer.Name)
local MyImportant = MyFarm.Important
local PlantLocations = MyImportant.Plant_Locations
local PlantsPhysical = MyImportant.Plants_Physical
local Dirt = PlantLocations:FindFirstChildOfClass("Part")
local X1, Z1, X2, Z2 = GetArea(Dirt)

local function GetRandomFarmPoint()
    local FarmLands = PlantLocations:GetChildren()
    local FarmLand = FarmLands[math.random(1, #FarmLands)]
    local X1, Z1, X2, Z2 = GetArea(FarmLand)
    return Vector3.new(math.random(X1, X2), 4, math.random(Z1, Z2))
end

local function AutoPlantLoop()
	local Seed = SelectedSeed.Selected
	local SeedData = OwnedSeeds[Seed]
	if not SeedData then return end
    local Count = SeedData.Count
    local Tool = SeedData.Tool
	if Count <= 0 then return end
    local Planted = 0
    EquipCheck(Tool)
	if AutoPlantRandom.Value then
		for i = 1, Count do
			Plant(GetRandomFarmPoint(), Seed)
		end
	end
	for X = X1, X2 do
		for Z = Z1, Z2 do
			if Planted > Count then break end
			Planted += 1
			Plant(Vector3.new(X, 0.13, Z), Seed)
		end
	end
end

local function HarvestPlant(Plant)
	local Prompt = Plant:FindFirstChild("ProximityPrompt", true)
	if Prompt then fireproximityprompt(Prompt) end
}

local function GetSeedStock(IgnoreNoStock)
	local SeedShop = PlayerGui.Seed_Shop
	local Items = SeedShop:FindFirstChild("Blueberry", true).Parent
	local NewList = {}
	for _, Item in next, Items:GetChildren() do
		local MainFrame = Item:FindFirstChild("Main_Frame")
		if MainFrame then
			local StockText = MainFrame.Stock_Text.Text
			local StockCount = tonumber(StockText:match("%d+"))
			if IgnoreNoStock then
				if StockCount > 0 then NewList[Item.Name] = StockCount end
			else
				SeedStock[Item.Name] = StockCount
			end
		end
	end
	return IgnoreNoStock and NewList or SeedStock
}

local function CanHarvest(Plant)
    local Prompt = Plant:FindFirstChild("ProximityPrompt", true)
	return Prompt and Prompt.Enabled
}

local function CollectHarvestable(Parent, Plants, IgnoreDistance)
	local Character = LocalPlayer.Character
	local PlayerPosition = Character:GetPivot().Position
    for _, Plant in next, Parent:GetChildren() do
		local Fruits = Plant:FindFirstChild("Fruits")
		if Fruits then CollectHarvestable(Fruits, Plants, IgnoreDistance) end
		local PlantPosition = Plant:GetPivot().Position
		local Distance = (PlayerPosition-PlantPosition).Magnitude
		if not IgnoreDistance and Distance > 15 then continue end
		local Variant = Plant:FindFirstChild("Variant")
		if HarvestIgnores[Variant.Value] then continue end
        if CanHarvest(Plant) then table.insert(Plants, Plant) end
	end
    return Plants
}

local function GetHarvestablePlants(IgnoreDistance)
    local Plants = {}
    CollectHarvestable(PlantsPhysical, Plants, IgnoreDistance)
    return Plants
}

local function HarvestPlants()
	local Plants = GetHarvestablePlants()
    for _, Plant in next, Plants do HarvestPlant(Plant) end
}

local function AutoSellCheck()
    local CropCount = #GetInvCrops()
    if AutoSell.Value and CropCount >= SellThreshold.Value then SellInventory() end
}

local function AutoWalkLoop()
	if IsSelling then return end
    local Character = LocalPlayer.Character
    local Humanoid = Character.Humanoid
    local Plants = GetHarvestablePlants(true)
	local RandomAllowed = AutoWalkAllowRandom.Value
	local DoRandom = #Plants == 0 or math.random(1, 3) == 2
    if RandomAllowed and DoRandom then
        Humanoid:MoveTo(GetRandomFarmPoint())
		AutoWalkStatus.Text = "Random point"
        return
    end
    for _, Plant in next, Plants do
        Humanoid:MoveTo(Plant:GetPivot().Position)
		AutoWalkStatus.Text = Plant.Name
    end
}

local function NoclipLoop()
    local Character = LocalPlayer.Character
    if not NoClip.Value or not Character then return end
    for _, Part in Character:GetDescendants() do
        if Part:IsA("BasePart") then Part.CanCollide = false end
    end
}

local function MakeLoop(Toggle, Func)
	coroutine.wrap(function()
		while wait(.01) do
			if Toggle.Value then Func() end
		end
	end)()
}

local function StartServices()
	MakeLoop(AutoWalk, function()
		AutoWalkLoop()
		wait(math.random(1, AutoWalkMaxWait.Value))
	end)
	MakeLoop(AutoHarvest, HarvestPlants)
	MakeLoop(AutoBuy, BuyAllSelectedSeeds)
	MakeLoop(AutoBuyAll, BuyAllAvailableSeeds)
	MakeLoop(AutoBuyFriendshipPot, function() BuyFriendshipPot() wait(1) end)
	MakeLoop(AutoBuyAllSprinklers, function() BuyAllSprinklers() wait(1) end)
	MakeLoop(AutoBuyWateringCan, function() BuyWateringCan() wait(1) end)
	MakeLoop(AutoPlant, AutoPlantLoop)
	while wait(.1) do
		GetSeedStock()
		GetOwnedSeeds()
	end
}

local function CreateCheckboxes(Parent, Dict)
	for Key, Value in next, Dict do
		Parent:Checkbox({
			Value = Value,
			Label = Key,
			Callback = function(_, Value) Dict[Key] = Value end
		})
	end
}

local Window = ReGui:Window({
	Title = `{GameInfo.Name} | Depso`,
    Theme = "GardenTheme",
	Size = UDim2.fromOffset(300, 200)
})

local PlantNode = Window:TreeNode({Title="Auto-Plant 🥕"})
SelectedSeed = PlantNode:Combo({Label = "Seed", Selected = "", GetItems = GetSeedStock})
AutoPlant = PlantNode:Checkbox({Value = false, Label = "Enabled"})
AutoPlantRandom = PlantNode:Checkbox({Value = false, Label = "Plant at random points"})
PlantNode:Button({Text = "Plant all", Callback = AutoPlantLoop})

local HarvestNode = Window:TreeNode({Title="Auto-Harvest 🚜"})
AutoHarvest = HarvestNode:Checkbox({Value = false, Label = "Enabled"})
HarvestNode:Separator({Text="Ignores:"})
CreateCheckboxes(HarvestNode, HarvestIgnores)

local BuyNode = Window:TreeNode({Title="Auto-Buy 🥕"})
local OnlyShowStock
SelectedSeedStock = BuyNode:Combo({
	Label = "Seed",
	Selected = "",
	GetItems = function()
		return GetSeedStock(OnlyShowStock and OnlyShowStock.Value)
	end,
})
AutoBuy = BuyNode:Checkbox({Value = false, Label = "Enabled"})
AutoBuyAll = BuyNode:Checkbox({Value = false, Label = "Auto-Buy All Seeds"})
AutoBuyFriendshipPot = BuyNode:Checkbox({Value = false, Label = "Auto-Buy Friendship Pot"})
AutoBuyAllSprinklers = BuyNode:Checkbox({Value = false, Label = "Auto-Buy All Sprinklers"})
AutoBuyWateringCan = BuyNode:Checkbox({Value = false, Label = "Auto-Buy Watering Can"})
OnlyShowStock = BuyNode:Checkbox({Value = false, Label = "Only list stock"})
BuyNode:Button({Text = "Buy all", Callback = BuyAllSelectedSeeds})
BuyNode:Button({Text = "Buy all seeds", Callback = BuyAllAvailableSeeds})
BuyNode:Button({Text = "Buy Friendship Pot", Callback = BuyFriendshipPot})
BuyNode:Button({Text = "Buy All Sprinklers", Callback = BuyAllSprinklers})
BuyNode:Button({Text = "Buy Watering Can", Callback = BuyWateringCan})

local SellNode = Window:TreeNode({Title="Auto-Sell 💰"})
SellNode:Button({Text = "Sell inventory", Callback = SellInventory})
AutoSell = SellNode:Checkbox({Value = false, Label = "Enabled"})
SellThreshold = SellNode:SliderInt({Label = "Crops threshold", Value = 15, Minimum = 1, Maximum = 199})

local WalkNode = Window:TreeNode({Title="Auto-Walk 🚶"})
AutoWalkStatus = WalkNode:Label({Text = "None"})
AutoWalk = WalkNode:Checkbox({Value = false, Label = "Enabled"})
AutoWalkAllowRandom = WalkNode:Checkbox({Value = true, Label = "Allow random points"})
NoClip = WalkNode:Checkbox({Value = false, Label = "NoClip"})
AutoWalkMaxWait = WalkNode:SliderInt({Label = "Max delay", Value = 10, Minimum = 1, Maximum = 120})

RunService.Stepped:Connect(NoclipLoop)
Backpack.ChildAdded:Connect(AutoSellCheck)
StartServices()
