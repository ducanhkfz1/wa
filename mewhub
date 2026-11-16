-- 1. Cấu hình khởi chạy
-- Ghi thời điểm khởi động trước khi tải các module.
local scriptStartedAt = os.clock()

-- Launcher có thể truyền cấu hình riêng cho lần chạy này.
local environment = type(getgenv) == "function" and getgenv() or _G
local launchConfig = environment.RobloxHubConfig
environment.RobloxHubConfig = nil
if type(launchConfig) ~= "table" then launchConfig = nil end
local launchToggles = launchConfig and type(launchConfig.toggles) == "table" and launchConfig.toggles or {}
local startupActions = {}

-- Anti-AFK / Gửi phím Space mỗi phút.
do
    -- Dừng vòng nhảy từ bản cũ.
    if environment.RobloxHubAntiAfkJob then
        pcall(task.cancel, environment.RobloxHubAntiAfkJob)
        environment.RobloxHubAntiAfkJob = nil
    end

    -- Gỡ kết nối anti-AFK của lần chạy trước.
    if environment.RobloxHubAntiAfkConnection then
        environment.RobloxHubAntiAfkConnection:Disconnect()
        environment.RobloxHubAntiAfkConnection = nil
    end

    -- Gỡ kết nối theo dõi idle của lần chạy trước.
    if environment.RobloxHubAntiAfkIdleConnection then
        environment.RobloxHubAntiAfkIdleConnection:Disconnect()
        environment.RobloxHubAntiAfkIdleConnection = nil
    end

    -- Dừng đoạn exec thử nếu nó vẫn đang gửi phím.
    if type(environment.StopAfkTest) == "function" then
        environment.StopAfkTest()
        environment.StopAfkTest = nil
    end

    local input = game:GetService("UserInputService")
    local useNativeInput = type(keypress) == "function" and type(keyrelease) == "function"
    local setSpace
    if useNativeInput then
        setSpace = function(down)
            if down then keypress(0x20) else keyrelease(0x20) end
        end
    else
        local ok, virtualInput = pcall(function() return input:CreateVirtualInput() end)
        if ok and virtualInput then
            setSpace = function(down)
                virtualInput:SendKey(down, Enum.KeyCode.Space, false)
            end
        end
    end

    if setSpace then
        local player = game:GetService("Players").LocalPlayer
        -- Báo số giây Roblox vẫn tính là idle.
        environment.RobloxHubAntiAfkIdleConnection = player.Idled:Connect(function(seconds)
            warn(("[Anti-AFK] Roblox ghi nhận idle %ds."):format(math.floor(seconds)))
        end)

        local nextInputAt = os.clock() + 60
        local runService = game:GetService("RunService")
        -- Bỏ qua lượt gửi khi input đang được dùng ở nơi khác.
        environment.RobloxHubAntiAfkConnection = runService.Heartbeat:Connect(function()
            local now = os.clock()
            if now < nextInputAt then return end
            nextInputAt = now + 60

            if input:GetFocusedTextBox() or (useNativeInput and type(isrbxactive) == "function" and not isrbxactive()) then
                return
            end

            local ok, err = pcall(function()
                setSpace(true)
                task.wait(0.08)
                setSpace(false)
            end)
            if not ok then warn("[Anti-AFK] Gửi Space lỗi: " .. tostring(err)) end
        end)
    else
        warn("[Anti-AFK] Executor không có API gửi phím dùng được.")
    end
end

-- 2. Tải các module tính năng
-- Thêm một URL Raw vào danh sách cho mỗi file xử lý mới.
local urls = {
    "https://raw.githubusercontent.com/duyvip453/dyu/refs/heads/main/farm.lua",
    "https://raw.githubusercontent.com/duyvip453/dyu/refs/heads/main/rank.lua",
    "https://raw.githubusercontent.com/duyvip453/dyu/main/automatic.lua",
    "https://raw.githubusercontent.com/duyvip453/dyu/refs/heads/main/optimize.lua",
    "https://raw.githubusercontent.com/duyvip453/dyu/refs/heads/main/mail.lua",
    "https://raw.githubusercontent.com/duyvip453/dyu/main/webhook.lua",
    "https://raw.githubusercontent.com/duyvip453/dyu/main/event.lua",
    "https://raw.githubusercontent.com/duyvip453/dyu/main/trading.lua",
}

-- Gộp tính năng từ các module theo tên flag.
local features = {}
for _, url in ipairs(urls) do
    local filename = url:match("[^/]+$")
    local source = game:HttpGet(url)
    -- Một số client còn nhận bản webhook giữ chỗ rỗng từ cache.
    if filename == "webhook.lua" and not source:find("%S") then continue end
    local loadTab = assert(loadstring(source, "@" .. filename))
    local moduleFeatures
    if filename == "rank.lua" or filename == "event.lua" then
        moduleFeatures = loadTab(scriptStartedAt)
    else
        moduleFeatures = loadTab()
    end
    assert(type(moduleFeatures) == "table", filename .. " phải trả về bảng features")
    for flag, feature in pairs(moduleFeatures) do
        features[flag] = feature
    end
end

-- 3. Tạo cửa sổ và các tab
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

local window = Rayfield:CreateWindow({
    name = "Menu Roblox",
    sidebarLayout = true,
    configuration = {
        autoSave = launchConfig == nil,
        autoLoad = launchConfig == nil,
        fileName = "RobloxHubUI",
    },
})

-- Khai báo các tab theo thứ tự xuất hiện trên menu.
window:CreateTab({ name = "Stats" })
local farm = window:CreateTab({ name = "farm" })
local optimize = window:CreateTab({ name = "optimize" })
local event = window:CreateTab({ name = "Event" })
local mail = window:CreateTab({ name = "mail" })
local trading = window:CreateTab({ name = "trading" })
local rank = window:CreateTab({ name = "rank" })
local automatic = window:CreateTab({ name = "automatic" })
local webhook = window:CreateTab({ name = "webhook" })
window:CreateTab({ name = "setting" })

-- 4. Hàm tạo toggle dùng chung
-- Launcher bật toggle qua RobloxHubConfig.toggles[flag] = true.
-- Nối toggle Rayfield với tính năng cùng flag.
local function createToggle(tab, name, flag)
    local initial = launchToggles[flag] == true
    local applied = false
    -- Áp dụng trạng thái bật tắt từ giao diện hoặc launcher.
    local function apply(enabled)
        local feature = features[flag]
        if feature and (not launchConfig or applied ~= enabled) then
            applied = enabled
            feature.duy(enabled, features)
        end
    end

    local control = tab:CreateToggle({
        name = name,
        flag = flag,
        value = initial,
        callback = apply,
    })
    if initial then table.insert(startupActions, function() apply(true) end) end
    return control
end

-- 5. Cấu hình các tab

-- Tạo toggle mở map event.
do
    createToggle(event, "auto open map event", "EventAutoOpenMap")
    createToggle(event, "auto pumpkin", "EventAutoPumpkin")
    createToggle(event, "auto buy pumkin", "EventAutoBuyPumpkin")
    createToggle(event, "Auto Hot Coca", "EventAutoHotCoca")
    createToggle(event, "auto fannel gift", "EventAutoFlannelGift")
    local hugeGift = features.EventAutoGiftHuge
    if hugeGift then
        local inputFlag = "EventHugeGiftRecipient"
        local inputs = launchConfig and launchConfig.inputs
        local preset = launchConfig and (
            launchConfig.eventHugeGiftRecipient
            or launchConfig[inputFlag]
            or (type(inputs) == "table" and inputs[inputFlag])
            or launchToggles[inputFlag]
        )
        local recipient = type(preset) == "string" and preset:match("^%s*(.-)%s*$") or ""
        local input = event:CreateInput({
            name = "Gift Huge User Name",
            flag = inputFlag,
            value = recipient,
            placeholder = "Roblox username",
            callback = hugeGift.setRecipient,
        })
        -- Đồng bộ ô tên và module trước khi launcher bật Auto Gift Huge.
        if launchConfig then
            table.insert(startupActions, function()
                input:Set(recipient, true)
                hugeGift.setRecipient(recipient)
            end)
        end
        local control = createToggle(event, "Auto Gift Huge", "EventAutoGiftHuge")
        hugeGift.setStopCallback(function() control:Set(false) end)
    end
    createToggle(event, "optimize event", "EventOptimize")
    createToggle(event, "fast farm event", "EventFastFarm")
    local stats = features.EventStatsGui
    if stats then
        local control = createToggle(event, "stats event", "EventStatsGui")
        stats.setQuickClose(function() control:Set(false) end)
    end

    -- Chọn các mục nâng cấp Pumpkin Tycoon.
    local upgrade = features.EventAutoPumpkinUpgrade
    if upgrade then
        local options = upgrade.getOptions()
        local initial = {}
        local preset = launchConfig and launchConfig.pumpkinUpgrades
        if type(preset) == "table" then
            for _, name in ipairs(options) do
                if table.find(preset, name) then table.insert(initial, name) end
            end
        end
        event:CreateDropdown({
            name = "Pumpkin Upgrades",
            flag = "EventPumpkinUpgradeSelection",
            options = options,
            multiSelect = true,
            value = initial,
            callback = upgrade.setSelection,
        })
        if launchConfig then upgrade.setSelection(initial) end
        createToggle(event, "auto pumpkin upgrade", "EventAutoPumpkinUpgrade")
    end

    -- Chọn boost dùng tự động trong Pumpkin Tycoon.
    local boost = features.EventAutoEquipBoost
    if boost then
        local options, initial = boost.getOptions(), {}
        local preset = launchConfig and launchConfig.boosts
        if boost.resolveSelection then
            initial = boost.resolveSelection(preset)
        elseif type(preset) == "table" then
            for _, name in ipairs(options) do
                if table.find(preset, name) then table.insert(initial, name) end
            end
        end
        event:CreateDropdown({
            name = "Boosts",
            flag = "EventBoostSelection",
            options = options,
            multiSelect = true,
            value = initial,
            callback = boost.setSelection,
        })
        if launchConfig then boost.setSelection(initial) end
        createToggle(event, "auto equip boost", "EventAutoEquipBoost")
    end
end

-- Tạo giao diện cho các tính năng farm.
do
    -- Farm và di chuyển
    createToggle(farm, "inf pet speed", "FarmInfinityPetSpeed")
    createToggle(farm, "fast farm", "FarmFastFarm")
    createToggle(farm, "auto tap", "FarmAutoTap")
    createToggle(farm, "Tự nhặt orb", "FarmAutoCollectOrb")
    createToggle(farm, "tele to best area", "FarmTeleToBestArea")
    createToggle(farm, "tele to best world", "FarmTeleToBestWorld")
    createToggle(farm, "auto buy next area", "FarmAutoBuyNextArea")

    farm:CreateSection({ name = "Nâng cấp slot" })
    createToggle(farm, "auto upd pet slot", "FarmAutoPetSlot")
    createToggle(farm, "auto upd egg slot", "FarmAutoEggSlot")
end

-- Tạo các toggle tối ưu hiển thị.
do
    optimize:CreateSection({ name = "Loot boxes" })
    createToggle(optimize, "disable loot boxes", "OptimizeDisableLootBoxes")
    optimize:CreateSection({ name = "Dropped objects" })
    createToggle(optimize, "disable objects", "OptimizeDisableObjects")
    optimize:CreateSection({ name = "Combined" })
    createToggle(optimize, "super optimize", "OptimizeSuper")

    -- Cấu hình giới hạn FPS của client.
    local fpsLimit = features.OptimizeFpsLimit
    local initialFps = "30"
    if fpsLimit and launchConfig and launchConfig.fpsTarget ~= nil then
        if fpsLimit.setTarget(launchConfig.fpsTarget) then
            initialFps = tostring(tonumber(launchConfig.fpsTarget))
        end
    end
    optimize:CreateSection({ name = "FPS" })
    optimize:CreateInput({
        name = "Target FPS",
        flag = "OptimizeFpsTarget",
        numeric = true,
        value = initialFps,
        placeholder = "Nhập FPS mong muốn",
        callback = function(value)
            if fpsLimit then fpsLimit.setTarget(value) end
        end,
    })
    createToggle(optimize, "Limit FPS", "OptimizeFpsLimit")
end

-- Tạo giao diện nhận thư và cấu hình gửi quà.
do
    createToggle(mail, "Tự nhận thư", "MailAutoClaim")
    local gift = features.MailAutoGift
    if not gift then return end
    local preset = launchConfig and launchConfig.mailGift
    local recipient = type(preset) == "table" and type(preset.recipient) == "string" and preset.recipient or ""
    mail:CreateInput({
        name = "User Name",
        flag = "MailUserName",
        value = recipient,
        placeholder = "...",
        callback = gift.setRecipient,
    })

    local selectedClass, itemDropdown
    -- Đổi danh sách Item ID theo Class đang chọn.
    local function selectClass(class)
        local changed = selectedClass ~= nil and selectedClass ~= class
        selectedClass = class
        if itemDropdown then
            if changed then itemDropdown:Set("", true) end
            itemDropdown:Refresh(gift.getNames(class))
        end
    end
    mail:CreateDropdown({
        name = "Item Class",
        flag = "MailGiftClass",
        options = gift.getClasses(),
        multiSelect = false,
        callback = selectClass,
    })
    itemDropdown = mail:CreateDropdown({
        name = "Item ID",
        flag = "MailGiftItem",
        options = {},
        multiSelect = false,
    })
    if selectedClass then selectClass(selectedClass) end

    local amount = mail:CreateInput({
        name = "Amount",
        flag = "MailGiftAmount",
        value = "",
        placeholder = "Ví dụ: 100k",
    })
    local keep = mail:CreateInput({
        name = "Keep",
        flag = "MailGiftKeep",
        value = "",
        placeholder = "Ví dụ: 10k hoặc 0",
    })
    local giftText = mail:CreateText({ text = "Danh sách gift: (trống)" })
    -- Hiện mỗi quy tắc gửi quà trên một dòng.
    local function updateGiftText()
        local lines = {}
        for _, rule in ipairs(gift.getList()) do
            lines[#lines + 1] = ("%s, %s, %s, %s"):format(rule.class, rule.name, rule.amount, rule.keep)
        end
        giftText:Set(#lines > 0 and table.concat(lines, "\n") or "Danh sách gift: (trống)")
    end
    mail:CreateButton({
        name = "Add Item",
        callback = function()
            local added, reason = gift.add(selectedClass, itemDropdown.value[1], amount.value, keep.value)
            if added then updateGiftText() else warn("[Auto Gift] " .. reason) end
        end,
    })
    mail:CreateButton({
        name = "Clear 1 Item",
        callback = function()
            gift.removeLast()
            updateGiftText()
        end,
    })
    -- Nạp người nhận và danh sách trước khi launcher bật Auto Gift.
    if type(preset) == "table" then
        gift.setRecipient(recipient)
        for _, rule in ipairs(type(preset.items) == "table" and preset.items or {}) do
            if type(rule) == "table" then
                local added, reason = gift.add(rule.class, rule.name, tostring(rule.amount), tostring(rule.keep))
                if not added then warn("[Auto Gift] " .. reason) end
            end
        end
        updateGiftText()
    end
    createToggle(mail, "auto gift", "MailAutoGift")
end

-- Tạo các nhóm giao diện giao dịch.
do
    local boothSnipe = trading:CreateGroup({ direction = "column" })
    boothSnipe:CreateSection({ name = "Săn món ở gian hàng" })
    local sniper = features.TradingSniperBooth
    if sniper then
        local config = launchConfig and launchConfig.trading
        trading:CreateText({ text = sniper.configure(config) })
        createToggle(trading, "Sniper Booth", "TradingSniperBooth")
        local report = features.TradingWebhook
        if report then
            config = type(config) == "table" and config or {}
            -- Nhập URL và số dư cảnh báo cho webhook giao dịch.
            trading:CreateInput({
                name = "Trading Webhook URL",
                flag = "TradingWebhookUrl",
                value = type(config.webhookUrl) == "string" and config.webhookUrl or "",
                callback = report.setUrl,
            })
            trading:CreateInput({
                name = "Min Diamonds",
                flag = "TradingMinDiamond",
                value = tostring(config.minDiamond or 0),
                callback = report.setMinimum,
            })
            createToggle(trading, "Webhook Trading", "TradingWebhook")
        end
    end

    local boothSeller = trading:CreateGroup({ direction = "column" })
    boothSeller:CreateSection({ name = "Bán ở gian hàng" })
end

-- Tạo giao diện cho các tính năng rank.
do
    createToggle(rank, "auto claim rank reward", "RankAutoClaimReward")
    rank:CreateSection({ name = "auto quest" })
    createToggle(rank, "auto rank quest", "RankAutoQuest")
    createToggle(rank, "stats gui", "RankStatsGui")
end

-- Tạo giao diện cấu hình webhook.
do
    -- Webhook chung: URL, loại thông báo và nút điều khiển.
    local petWebhook = features.WebhookEnabled
    local petPreset = launchConfig and type(launchConfig.petWebhook) == "table" and launchConfig.petWebhook or {}
    local initialPetUrl = type(petPreset.url) == "string" and petPreset.url or ""
    local petOptions = petWebhook and petWebhook.getOptions() or {}
    local initialPetEvents = {}
    if type(petPreset.events) == "table" then
        for _, category in ipairs(petOptions) do
            if table.find(petPreset.events, category) then table.insert(initialPetEvents, category) end
        end
    end
    webhook:CreateSection({ name = "webhook" })
    webhook:CreateInput({
        name = "Webhook URL",
        flag = "WebhookUrl",
        value = initialPetUrl,
        placeholder = "Dán link webhook",
        callback = function(value)
            if petWebhook then petWebhook.setUrl(value) end
        end,
    })
    webhook:CreateDropdown({
        name = "Webhook Events",
        flag = "WebhookEvents",
        options = petOptions,
        multiSelect = true,
        value = initialPetEvents,
        placeholder = "Chọn loại pet muốn báo",
        callback = function(values)
            if petWebhook then petWebhook.setSelection(values) end
        end,
    })
    -- Nạp URL và loại pet trước khi launcher bật webhook.
    if petWebhook and launchConfig then
        petWebhook.setUrl(initialPetUrl)
        petWebhook.setSelection(initialPetEvents)
    end
    createToggle(webhook, "Start Webhook", "WebhookEnabled")
    webhook:CreateButton({
        name = "Test Webhook",
        callback = function()
            if petWebhook then petWebhook.test() end
        end,
    })

    -- Webhook Rank dùng URL và cấu hình riêng.
    local rankWebhook = features.RankWebhookEnabled
    local rankPreset = launchConfig and type(launchConfig.rankWebhook) == "table" and launchConfig.rankWebhook or {}
    local initialRankUrl = type(rankPreset.url) == "string" and rankPreset.url or ""
    local initialRankTarget = rankPreset.target ~= nil and tostring(rankPreset.target) or ""
    webhook:CreateSection({ name = "webhook rank" })
    webhook:CreateInput({
        name = "Rank Webhook URL",
        flag = "RankWebhookUrl",
        value = initialRankUrl,
        placeholder = "Dán link webhook rank",
        callback = function(value)
            if rankWebhook then rankWebhook.setUrl(value) end
        end,
    })
    webhook:CreateInput({
        name = "Target Rank",
        flag = "RankWebhookTarget",
        numeric = true,
        value = initialRankTarget,
        placeholder = "Nhập rank để kích hoạt",
        callback = function(value)
            if rankWebhook then rankWebhook.setTarget(value) end
        end,
    })
    if rankWebhook and launchConfig then
        rankWebhook.setUrl(initialRankUrl)
        rankWebhook.setTarget(initialRankTarget)
    end
    createToggle(webhook, "Start Rank Webhook", "RankWebhookEnabled")
    webhook:CreateButton({
        name = "Test Rank Webhook",
        callback = function()
            if rankWebhook then rankWebhook.test() end
        end,
    })
end

-- Tạo giao diện cho các tính năng tự động.
do
    -- Danh sách Add Enchant không phải control có flag, nên lưu riêng theo tài khoản.
    local enchantConfigPath = "RobloxHubEnchantList_" .. game:GetService("Players").LocalPlayer.UserId .. ".json"
    local httpService = game:GetService("HttpService")

    -- Đọc danh sách enchant đã lưu của tài khoản.
    local function loadEnchantList()
        if launchConfig then
            return type(launchConfig.enchants) == "table" and launchConfig.enchants or {}
        end
        if type(readfile) ~= "function" then return {} end
        if type(isfile) == "function" and not isfile(enchantConfigPath) then return {} end
        local ok, list = pcall(function()
            return httpService:JSONDecode(readfile(enchantConfigPath))
        end)
        return ok and type(list) == "table" and list or {}
    end

    -- Lưu thứ tự Add Enchant vào JSON cục bộ.
    local function saveEnchantList(list)
        if launchConfig then return end
        local ok = pcall(function()
            writefile(enchantConfigPath, httpService:JSONEncode(list))
        end)
        if not ok then warn("[Enchant UI] Không lưu được danh sách enchant vào config") end
    end

    -- Đọc kho ở luồng riêng để giữ quyền tạo UI của Rayfield.
    local function runInventoryAction(action, ...)
        local result
        task.spawn(function(...)
            result = table.pack(pcall(action, ...))
        end, ...)
        while not result do task.wait() end
        return table.unpack(result, 1, result.n)
    end

    -- Nhận quà online
    createToggle(automatic, "auto claim free gift", "AutoClaimFreeGift")

    -- Trang bị enchant
    automatic:CreateSection({ name = "Enchant" })
    local enchantFeature = features.AutoEquipEnchant
    local selectedEnchant

    local hasEnchantNames, enchantNames = runInventoryAction(enchantFeature.getNames)
    if not hasEnchantNames then
        warn("[Enchant UI] " .. tostring(enchantNames))
        enchantNames = {}
    end
    local enchantDropdown = automatic:CreateDropdown({
        name = "Enchant",
        flag = "AutoEnchantSelection",
        multiSelect = false,
        options = enchantNames,
        callback = function(value) selectedEnchant = value end,
    })
    local enchantText = automatic:CreateText({ text = "enchant : (trống)" })
    -- Hiện sách theo đúng thứ tự trong danh sách Add Enchant.
    local function updateEnchantText()
        local list = enchantFeature.getList()
        enchantText:Set("enchant : " .. (#list > 0 and table.concat(list, ", ") or "(trống)"))
    end

    -- Khôi phục danh sách trước khi Rayfield có thể bật lại Auto Equip từ config.
    local savedEnchants = loadEnchantList()
    if #savedEnchants > 0 then
        local ok, err = runInventoryAction(function()
            for _, name in ipairs(savedEnchants) do
                if type(name) == "string" then enchantFeature.add(name) end
            end
        end)
        if not ok then warn("[Enchant UI] " .. tostring(err)) end
        updateEnchantText()
    end
    automatic:CreateButton({
        name = "add enchant",
        callback = function()
            local name = selectedEnchant or enchantDropdown.value[1]
            if name then
                local ok, err = runInventoryAction(enchantFeature.add, name)
                if not ok then warn("[Enchant UI] " .. tostring(err)) end
                if ok and err then saveEnchantList(enchantFeature.getList()) end
            end
            updateEnchantText()
        end,
    })
    automatic:CreateButton({
        name = "clear enchant",
        callback = function()
            enchantFeature.clear()
            saveEnchantList(enchantFeature.getList())
            updateEnchantText()
        end,
    })
    createToggle(automatic, "auto equip enchant", "AutoEquipEnchant")

    -- Dọn vòng làm mới inventory còn chạy từ bản UI cũ.
    if environment.RobloxHubEnchantUiJob then
        pcall(task.cancel, environment.RobloxHubEnchantUiJob)
        environment.RobloxHubEnchantUiJob = nil
    end

    -- Chọn loại và tự mở quà
    local giftFeature = features.AutoOpenGifts
    local giftOptions = giftFeature and giftFeature.getOptions and giftFeature.getOptions()
        or { "Gift Bag", "Large Gift Bag", "Mini Chest" }
    local initialGifts = {}
    if launchConfig then
        local giftPreset = launchConfig.gifts
        for _, id in ipairs(giftOptions) do
            if type(id) == "string" and id:find("%S")
                and (giftPreset == "all" or (type(giftPreset) == "table" and table.find(giftPreset, id))) then
                table.insert(initialGifts, id)
            end
        end
    end
    -- Chuyển các loại quà đã chọn sang module Automatic.
    local function setGiftSelection(values)
        local feature = features.AutoOpenGifts
        if feature then feature.setSelection(values) end
    end

    automatic:CreateDropdown({
        name = "Gifts",
        flag = "AutoOpenGiftTypes",
        options = giftOptions,
        multiSelect = true,
        value = initialGifts,
        callback = setGiftSelection,
    })
    if launchConfig then setGiftSelection(initialGifts) end
    createToggle(automatic, "auto open gifts", "AutoOpenGifts")
end

-- 6. Áp dụng cấu hình khởi chạy
-- Áp dụng các toggle được launcher đặt sẵn.
for _, start in ipairs(startupActions) do start() end
