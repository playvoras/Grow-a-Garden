local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

_G.WebhookConfig = {
    ["Enabled"] = true,
    ["Webhook"] = "no",
    ["TrackedSeeds"] = {"Beanstalk", "Ember Lily"}
}

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui
local GameInfo = MarketplaceService:GetProductInfo(game.PlaceId)

local GuiLib = loadstring(game:HttpGet('https://raw.githubusercontent.com/depthso/Dear-ReGui/refs/heads/main/ReGui.lua'))()
local PrefabAssetId = "rbxassetid://" .. GuiLib.PrefabsId
local GameEvents = ReplicatedStorage.GameEvents

local vim = Instance.new("VirtualInputManager")

local ThemeColors = {
    DarkGreen = Color3.fromRGB(45, 95, 25),
    Green = Color3.fromRGB(69, 142, 40),
    Brown = Color3.fromRGB(26, 20, 8),
}

GuiLib:Init({Prefabs = InsertService:LoadLocalAsset(PrefabAssetId)})
GuiLib:DefineTheme("GardenTheme", {
	WindowBg = ThemeColors.Brown,
	TitleBarBg = ThemeColors.DarkGreen,
	TitleBarBgActive = ThemeColors.Green,
    ResizeGrab = ThemeColors.DarkGreen,
    FrameBg = ThemeColors.DarkGreen,
    FrameBgActive = ThemeColors.Green,
	CollapsingHeaderBg = ThemeColors.Green,
    ButtonsBg = ThemeColors.Green,
    CheckMark = ThemeColors.Green,
    SliderGrab = ThemeColors.Green,
})

local SeedInventory = {}
local ToggleBuyAll, ToggleBuyPot, ToggleBuySprinklers, ToggleBuyCan, ToggleBuyFlowerPack
local ToggleAntiAFK

local function mouse1click(x, y)
    x = x or 0
    y = y or 0
    vim:SendMouseButtonEvent(x, y, 0, true, game, false)
    task.wait()
    vim:SendMouseButtonEvent(x, y, 0, false, game, false)
end

local function SendLog(Message)
    if not _G.WebhookConfig.Enabled then return end

    local IsoTime = DateTime.now():ToIsoDate()
    local TimeString = os.date("%H:%M:%S")

    local Payload = {
        embeds = {
            {
                color = 5763719,
                description = Message .. " at time " .. TimeString,
                timestamp = IsoTime
            }
        }
    }

    local Data = {
        Url = _G.WebhookConfig.Webhook,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = HttpService:JSONEncode(Payload)
    }

    task.spawn(request, Data)
end

local function IsTracked(Name)
    for _, Tracked in pairs(_G.WebhookConfig.TrackedSeeds) do
        if Name == Tracked then
            return true
        end
    end
    return false
end

local function PurchaseSeed(Name)
    GameEvents.BuySeedStock:FireServer(Name)
    if IsTracked(Name) then
        SendLog("Bought " .. Name)
    end
end

local function PurchasePot() GameEvents.BuyGearStock:FireServer("Friendship Pot") end
local function PurchaseSprinkler(Name) GameEvents.BuyGearStock:FireServer(Name) end
local function PurchaseCan() GameEvents.BuyGearStock:FireServer("Watering Can") end
local function PurchaseFlowerSeedPack() GameEvents.BuyEventShopStock:FireServer("Flower Seed Pack") end

local function PurchaseAllSprinklers()
	local Names = {"Basic Sprinkler", "Advanced Sprinkler", "Godly Sprinkler", "Master Sprinkler"}
	for _, Name in pairs(Names) do
		PurchaseSprinkler(Name)
	end
end

local function PurchaseAllSeeds()
    for Name, Count in pairs(SeedInventory) do
        if Count > 0 then
            for _ = 1, Count do
                PurchaseSeed(Name)
            end
        end
    end
end

local function RefreshStock(OmitEmpty)
	local Shop = PlayerGui.Seed_Shop
	local Container = Shop:FindFirstChild("Blueberry", true).Parent
	local Result = {}
	for _, Item in next, Container:GetChildren() do
		local Frame = Item:FindFirstChild("Main_Frame")
		if Frame then
			local Count = tonumber(Frame.Stock_Text.Text:match("%d+"))
			if OmitEmpty then
				if Count > 0 then Result[Item.Name] = Count end
			else
				SeedInventory[Item.Name] = Count
			end
		end
	end
	return OmitEmpty and Result or SeedInventory
end

local function CreateLoop(Toggle, Action)
	coroutine.wrap(function()
		while wait(0.01) do
			if Toggle.Value then Action() end
		end
	end)()
end

local function CreateAntiAFKLoop()
    coroutine.wrap(function()
        while wait(600) do
            if ToggleAntiAFK.Value then
                mouse1click(1, 1)
            end
        end
    end)()
end

local function Initialize()
	CreateLoop(ToggleBuyAll, PurchaseAllSeeds)
	CreateLoop(ToggleBuyPot, function() PurchasePot() wait(1) end)
	CreateLoop(ToggleBuySprinklers, function() PurchaseAllSprinklers() wait(1) end)
	CreateLoop(ToggleBuyCan, function() PurchaseCan() wait(1) end)
	CreateLoop(ToggleBuyFlowerPack, function() PurchaseFlowerSeedPack() wait(1) end)
    CreateAntiAFKLoop()
	while wait(0.1) do
		RefreshStock()
	end
end

local MainWindow = GuiLib:Window({
	Title = `{GameInfo.Name} | Depso`,
    Theme = "GardenTheme",
	Size = UDim2.fromOffset(300, 200)
})

local BuyGroup = MainWindow:TreeNode({Title = "Auto-Buy 🥕"})
ToggleBuyAll = BuyGroup:Checkbox({Value = false, Label = "Auto-Buy All Seeds"})
ToggleBuyPot = BuyGroup:Checkbox({Value = false, Label = "Auto-Buy Friendship Pot"})
ToggleBuySprinklers = BuyGroup:Checkbox({Value = false, Label = "Auto-Buy All Sprinklers"})
ToggleBuyCan = BuyGroup:Checkbox({Value = false, Label = "Auto-Buy Watering Can"})
ToggleBuyFlowerPack = BuyGroup:Checkbox({Value = false, Label = "Auto-Buy Flower Seed Pack"})
BuyGroup:Button({Text = "Buy all seeds", Callback = PurchaseAllSeeds})
BuyGroup:Button({Text = "Buy Friendship Pot", Callback = PurchasePot})
BuyGroup:Button({Text = "Buy All Sprinklers", Callback = PurchaseAllSprinklers})
BuyGroup:Button({Text = "Buy Watering Can", Callback = PurchaseCan})
BuyGroup:Button({Text = "Buy Flower Seed Pack", Callback = PurchaseFlowerSeedPack})

local SettingsGroup = MainWindow:TreeNode({Title = "Settings"})
ToggleAntiAFK = SettingsGroup:Checkbox({Value = false, Label = "Anti AFK"})

Initialize()
