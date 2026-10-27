getgenv().Config = {
    FPSCap = 60, -- FPScap
    CPUSaver = true,
    Enchants = { "Criticals", "Tap Power", "Tap Power", "Criticals", "Treasure Hunter", "Lucky Eggs" },
    AutoOpen = { "Charm Stone", "Large Gift Bag", "Gift Bag", "Potion Bundle", "Enchant Bundle", "Toy Bundle", "Fruit Bundle", "Flag Bundle", "Large Enchant Bundle", "Large Potion Bundle", "Mini Chest" }, -- // Opening Gifts
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
loadstring(game:HttpGet("https://api.luarmor.net/files/v4/loaders/4f8f7464be96cf9a78297a6f67f9be6e.lua"))()
