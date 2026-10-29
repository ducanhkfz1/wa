getgenv().Config = {
    FPSCap = 60, -- FPScap
    CPUSaver = true,
    Enchants = { "Criticals", "Tap Power", "Tap Power", "Criticals", "Treasure Hunter", "Lucky Eggs" },
    AutoOpen = { "Charm Stone", "Large Gift Bag", "Gift Bag", "Potion Bundle", "Enchant Bundle", "Toy Bundle", "Fruit Bundle", "Flag Bundle", "Large Enchant Bundle", "Large Potion Bundle", "Mini Chest" },
    Lootbox = {}, -- // Opening Lootbox
    Potions = {"Diamonds", "Damage", "Treasure Hunter", "Lucky", "Walkspeed", "Coins", "The Cocktail"}, -- // Using Best Tier of Potion
    ConsumeFlag = {"Hasty Flag","Fortune Flag"},
    UseSprinkler = true,
    UltraMasteryPot = "Pets",
    AutoRank = {Enable = true, FastRank = 9},
    AutoUsePartyBox = false,
    BuyUpgrades = {Enabled = true, MaxCosts = 1000000},
    TimeTrials = {
        Enable = false, -- true/ false
        OpenChests = {1,2,3},
    },
    AutoMail = {
        Enable        = true, -- true/false
        AutoClaim     = true, -- auto nhận mail
        SendAllHuges  = false, -- true/false
        User          = { "" }, -- Your User for mail
        Items = {
            -- ["Name"] = { Class = "Classitem", Amount = Number },
        }
    },
    Webhook = {
        Enable = true, -- true/false
        HugeWebhookURL = "",
        TitanicWebhookURL = "",
        GargantuanWebhookURL = "",
        RankWebhookURL = "",
        TimeTrialWebhookURL = "",
        DiscordID  = "" -- Discord ID
    }
}

local Config = getgenv().Config

local function normalizeText(value)
    if type(value) ~= "string" then
        return ""
    end
    return string.lower(string.gsub(value, "%s+", " "))
end

local function isClaimAllText(text)
    local t = normalizeText(text)
    return t == "claim all" or t == "claim" or t == "nhận tất" or t == "nhận"
end

local function tryClick(obj)
    if not obj then return end
    pcall(function()
        if obj.Activated then
            obj:Activate()
        elseif obj.MouseButton1Click then
            obj:MouseButton1Click()
        elseif obj.Click then
            obj:Click()
        end
    end)
end

local function autoClaimMail()
    if not Config.AutoMail or not Config.AutoMail.Enable or not Config.AutoMail.AutoClaim then
        return
    end

    local player = game:GetService("Players").LocalPlayer
    if not player then
        return
    end

    local gui = player:FindFirstChildOfClass("PlayerGui")
    if not gui then
        return
    end

    for _, obj in ipairs(gui:GetDescendants()) do
        if obj:IsA("TextButton") or obj:IsA("ImageButton") then
            local text = obj.Text or ""
            local name = obj.Name or ""

            if isClaimAllText(text) or isClaimAllText(name) then
                if obj.Visible ~= false then
                    tryClick(obj)
                end
            end
        end
    end
end

spawn(function()
    while true do
        pcall(autoClaimMail)
        task.wait(1)
    end
end)

loadstring(game:HttpGet("https://api.luarmor.net/files/v4/loaders/4f8f7464be96cf9a78297a6f67f9be6e.lua"))()
