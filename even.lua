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
        Enable        = false, -- true/false
        AutoClaim     = true, -- auto nhận mail
        SendAllHuges  = false, -- true/false
        User         = { "" }, -- Your User for mail
        Items = {
            -- ["Name"]           = { Class = "Classitem", Amount = Number },
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

local function clickMailButton(button)
    if not button then
        return false
    end

    local ok, err = pcall(function()
        if button:IsA("TextButton") or button:IsA("ImageButton") then
            local text = (button.Text or ""):lower()
            if string.find(text, "claim") or string.find(text, "collect") or string.find(text, "receive") or string.find(text, "nhận") then
                if button:IsA("TextButton") and button.Visible ~= false then
                    button:Activate()
                elseif button:IsA("ImageButton") and button.Visible ~= false then
                    button:Activate()
                end
            end
        end
    end)

    return ok and err ~= nil
end

local function autoClaimMail()
    if not Config.AutoMail or not Config.AutoMail.Enable or not Config.AutoMail.AutoClaim then
        return
    end

    local player = game:GetService("Players").LocalPlayer
    if not player then
        return
    end

    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        return
    end

    local queue = {playerGui}
    local checked = {}

    while #queue > 0 do
        local obj = table.remove(queue, 1)
        if obj and not checked[obj] then
            checked[obj] = true

            if obj:IsA("TextButton") or obj:IsA("ImageButton") then
                local text = (obj.Text or ""):lower()
                if string.find(text, "claim") or string.find(text, "collect") or string.find(text, "receive") or string.find(text, "nhận") then
                    clickMailButton(obj)
                end
            end

            for _, child in ipairs(obj:GetChildren()) do
                table.insert(queue, child)
            end
        end
    end
end

spawn(function()
    while true do
        pcall(autoClaimMail)
        wait(5)
    end
end)

loadstring(game:HttpGet("https://api.luarmor.net/files/v4/loaders/4f8f7464be96cf9a78297a6f67f9be6e.lua"))()
