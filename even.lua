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
        HugeWebhookURL = "https://discord.com/api/webhooks/1486589834297348338/AtiMLlFQDuilCNEWymiZOYLZ7MOKZ5ba3ogV6uy_HFyC1UlcGKio5XVadaQ-RvzwBMdd",
        TitanicWebhookURL = "https://discord.com/api/webhooks/1486589834297348338/AtiMLlFQDuilCNEWymiZOYLZ7MOKZ5ba3ogV6uy_HFyC1UlcGKio5XVadaQ-RvzwBMdd",
        GargantuanWebhookURL = "https://discord.com/api/webhooks/1486589834297348338/AtiMLlFQDuilCNEWymiZOYLZ7MOKZ5ba3ogV6uy_HFyC1UlcGKio5XVadaQ-RvzwBMdd",
        RankWebhookURL = "https://discord.com/api/webhooks/1486589834297348338/AtiMLlFQDuilCNEWymiZOYLZ7MOKZ5ba3ogV6uy_HFyC1UlcGKio5XVadaQ-RvzwBMdd",
        TimeTrialWebhookURL = "https://discord.com/api/webhooks/1486589834297348338/AtiMLlFQDuilCNEWymiZOYLZ7MOKZ5ba3ogV6uy_HFyC1UlcGKio5XVadaQ-RvzwBMdd",
        DiscordID  = "" -- Discord ID
    }
}
loadstring(game:HttpGet("https://api.luarmor.net/files/v4/loaders/4f8f7464be96cf9a78297a6f67f9be6e.lua"))()
