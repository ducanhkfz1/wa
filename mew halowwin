-- Halloween Games Auto Minigame (Pet Simulator 99)
-- Modular State Machine & Round Dispatcher

local Config = {
    Enabled = true,
    DebugLog = true,

    -- Night selection: "Highest" (5 -> 1), "Recommended" (meets Luck requirement), or "Fixed"
    NightSelectMode = "Highest",
    FixedNight = 5,
    MaxNight = 5,

    -- Match progression: false = always play through Final for 2x Bag + Midnight Gifts + Huge chance
    AutoCashOut = false,
    CashOutMinTreats = 500,

    -- Leave match immediately if eliminated / turned into a ghost
    ExitOnEliminated = true,

    -- Trick consumables usage
    AutoUseLuckyCharm = true,
    AutoUseTreatMagnet = true,
    AutoUseBroomstick = true,
    AutoUseLantern = true,
    AutoUseLanternInFinal = true,
    AutoUseTreatBoost = true,

    -- Auto Open Midnight Gifts
    AutoOpenMidnightGifts = true,
    LobbyOpenGiftsDelay = 6.0,

    -- Auto enter HalloweenGames instance portal if currently in main world
    AutoEnterInstance = true,

    -- Re-execute automatically across Lobby <-> Match place teleports
    AutoQueueOnTeleport = true,

    -- Performance, Map Deletion & 3D Rendering Optimization
    OptimizeFPS = true,
    DeleteUnneededMap = true,
    HideOtherPlayersAndBots = true,
    Disable3DRendering = false,
    FPSCap = 60,
}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

-- Clean up previous instance if re-executed
local env = (getgenv and getgenv()) or _G
if type(env.__HG_AUTO_CLEANUP) == "function" then
    pcall(env.__HG_AUTO_CLEANUP)
end

local State = {
    Running = true,
    Connections = {},
    Restorers = {},
    LastLog = "",
    LastCirclePickAt = 0,
    LastCircleMoveAt = 0,
    LastExitAt = 0,
    LastPortalEnterAt = os.clock() + 12.0,
    LastLobbyJoinAt = 0,
    LobbyArrivedAt = nil,
    LastOptimizeAt = 0,
    EngineOptimized = false,
    OptHooksInstalled = false,
    CurrentNightId = nil,
    LuckyCharmUsedNightId = nil,
    LanternUsedRoundId = nil,
    TreatMagnetUsedRoundId = nil,
    BroomstickUsedNightId = nil,
    LastReportedNightId = nil,
    PreMatchGiftsCount = nil,
    LastGiftOpenAt = 0,
    LastTreatBoostAt = 0,
    LootboxAnimHooked = false,
    KnownHugePetUIDs = {},
    LastTrickUsedAt = {},

    Round = {
        Id = nil,
        Arena = nil,
        Info = nil,
        Phase = nil,

        -- BroomSweep state
        BroomOrigin = nil,
        BroomConfig = nil,
        BroomLead = 0,
        LastJumpAt = 0,
        LastDuckAt = 0,

        -- HotPumpkin state
        HotHolders = {},
        HotBombs = {},
        LastPassAt = 0,

        -- LightsOut state
        Blackout = false,
        BlackoutSchedule = {},
        LightStartAt = 0,
        LightPos = nil,
        LightVel = Vector3.zero,
        LightRadius = 16,
        ActiveAttack = nil,

        -- BumperPumpkins state
        RingCenter = nil,
        RingRadius = 30,
        BumperRingRel = Vector3.zero,
        BumperCars = {},
        LastSteerAt = 0,
        LastBoostAt = 0,

        -- PumpkinColors state
        SafeColors = {},
        SafePads = {},
        ColorCallEndsAt = 0,

        -- TrickOrTreatDoors state
        DoorWave = 0,
        ActiveDoors = {},
        RevealedDoors = {},
        TakenDoors = {},
        HiddenDoors = {},
        SniffDoorId = nil,
        LanternDoorId = nil,
        CommittedDoorId = nil,
        DoorPhase = "enter",
        LastCommitAt = 0,

        -- ScarecrowStare state
        ScarecrowLight = "staging",
        ScarecrowFinished = false,
    },
}

local function log(msg)
    if not Config.DebugLog then
        return
    end
    local text = "[HalloweenGames] " .. tostring(msg)
    if text ~= State.LastLog then
        State.LastLog = text
        print(text)
    end
end

local function getCharacter()
    local char = LocalPlayer.Character
    if not char then
        return nil, nil, nil
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not (hrp and hrp:IsA("BasePart") and hum) then
        return nil, nil, nil
    end
    return char, hrp, hum
end

-- Lazy-loaded game modules
local Modules = {}

local function getModules()
    if Modules.HalloweenGamesCmds and Modules.HalloweenGames then
        return Modules
    end
    local lib = ReplicatedStorage:FindFirstChild("Library")
    if not lib then
        return nil
    end
    local typesFolder = lib:FindFirstChild("Types")
    local clientFolder = lib:FindFirstChild("Client")
    local hgTypesMod = typesFolder and typesFolder:FindFirstChild("HalloweenGames")
    local hgCmdsMod = clientFolder and clientFolder:FindFirstChild("HalloweenGamesCmds")
    if not (hgTypesMod and hgCmdsMod) then
        return nil
    end

    local tabCtrlMod = clientFolder:FindFirstChild("TabController")
    local saveModScript = clientFolder:FindFirstChild("Save")

    local ok1, hgTypes = pcall(require, hgTypesMod)
    local ok2, hgCmds = pcall(require, hgCmdsMod)
    local ok3, tabCtrl = pcall(function()
        return tabCtrlMod and require(tabCtrlMod) or nil
    end)
    local ok4, saveMod = pcall(function()
        return saveModScript and require(saveModScript) or nil
    end)

    if ok1 and ok2 then
        Modules.HalloweenGames = hgTypes
        Modules.HalloweenGamesCmds = hgCmds
        Modules.TabController = ok3 and tabCtrl or nil
        Modules.Save = ok4 and saveMod or nil
        Modules.Night = hgCmds.Feature("Night")
        Modules.NightSelect = hgCmds.Feature("NightSelect")
        Modules.Match = hgCmds.Feature("Match")
        Modules.Results = hgCmds.Feature("Results")
        return Modules
    end
    return nil
end

local function getActiveInstanceModel()
    local m = getModules()
    local inst = m and m.HalloweenGamesCmds and m.HalloweenGamesCmds.Instance()
    if inst and inst.model then
        return inst.model
    end
    local things = workspace:FindFirstChild("__THINGS")
    local container = things and things:FindFirstChild("__INSTANCE_CONTAINER")
    local active = container and container:FindFirstChild("Active")
    return active and active:FindFirstChild("HalloweenGames") or nil
end

local function resetRoundState(roundId, arena, info)
    local r = State.Round
    r.Id = roundId
    r.Arena = arena
    r.Info = info
    r.Phase = "intro"

    r.BroomOrigin = arena and arena:GetPivot() or nil
    r.BroomConfig = (info and info.config and info.config.t0) and info.config or nil
    r.BroomLead = 0
    r.LastJumpAt = 0
    r.LastDuckAt = 0

    table.clear(r.HotHolders)
    table.clear(r.HotBombs)
    r.LastPassAt = 0

    r.Blackout = false
    table.clear(r.BlackoutSchedule)
    r.LightStartAt = 0
    r.LightPos = arena and arena:GetPivot().Position or nil
    r.LightVel = Vector3.zero
    r.LightRadius = 16
    r.ActiveAttack = nil

    r.RingCenter = arena and arena:GetPivot().Position or nil
    r.RingRadius = 30
    r.BumperRingRel = Vector3.zero
    table.clear(r.BumperCars)
    r.LastSteerAt = 0
    r.LastBoostAt = 0

    table.clear(r.SafeColors)
    table.clear(r.SafePads)
    r.ColorCallEndsAt = 0

    r.DoorWave = 0
    table.clear(r.ActiveDoors)
    table.clear(r.RevealedDoors)
    table.clear(r.TakenDoors)
    table.clear(r.HiddenDoors)
    r.SniffDoorId = nil
    r.LanternDoorId = nil
    r.CommittedDoorId = nil
    r.DoorPhase = "enter"
    r.LastCommitAt = 0

    r.ScarecrowLight = "staging"
    r.ScarecrowFinished = false
end

-- Retrieve player's Save data across Match place, Queue Lobby, and World 1
local function getSaveData()
    local lib = ReplicatedStorage:FindFirstChild("Library")
    local clientFolder = lib and lib:FindFirstChild("Client")
    local saveMod = clientFolder and clientFolder:FindFirstChild("Save")
    if saveMod then
        local ok, s = pcall(require, saveMod)
        if ok and s then
            local lp = Players.LocalPlayer
            if type(s.Get) == "function" then
                local okD, d = pcall(s.Get, lp)
                if okD and type(d) == "table" then
                    return d
                end
                local okD2, d2 = pcall(s.Get)
                if okD2 and type(d2) == "table" then
                    return d2
                end
            end
            if type(s.GetSaves) == "function" then
                local okS, saves = pcall(s.GetSaves)
                if okS and type(saves) == "table" then
                    if lp and type(saves[lp.Name]) == "table" then
                        return saves[lp.Name]
                    elseif lp and type(saves[lp]) == "table" then
                        return saves[lp]
                    end
                end
            end
        end
    end
    return nil
end

local function getTrickHudButton(trickKey)
    local lp = Players.LocalPlayer
    local pgui = lp and lp:FindFirstChildOfClass("PlayerGui")
    local hud = pgui and pgui:FindFirstChild("_INSTANCES") and pgui._INSTANCES:FindFirstChild("HalloweenGamesHud")
    local tricks = hud and hud:FindFirstChild("Tricks")
    return tricks and tricks:FindFirstChild(trickKey)
end

local function getTrickCount(trickKey)
    local btn = getTrickHudButton(trickKey)
    if btn then
        local cntLabel = btn:FindFirstChild("Count")
        if cntLabel and cntLabel:IsA("TextLabel") then
            local num = tonumber(string.match(cntLabel.Text, "%d+"))
            if num then
                return num
            end
        end
    end
    return 0
end

local function isTrickArmed(trickKey)
    local btn = getTrickHudButton(trickKey)
    if btn then
        local stLabel = btn:FindFirstChild("State")
        if stLabel and stLabel:IsA("TextLabel") and (stLabel.Text == "Armed!" or stLabel.Text == "Active!") then
            return true
        end
    end
    return false
end

local function isTrickReady(trickKey)
    local btn = getTrickHudButton(trickKey)
    if btn then
        local stLabel = btn:FindFirstChild("State")
        if stLabel and stLabel:IsA("TextLabel") then
            if stLabel.Text == "Off" then
                return false
            end
            if stLabel.Text == "Ready!" or stLabel.Text == "" then
                return true
            end
        end
    end
    return true
end

local TRICK_NAME_MAP = {
    LuckyCharm = "Halloween Games Lucky Charm",
    TreatMagnet = "Halloween Games Treat Magnet",
    Broomstick = "Halloween Games Broomstick",
    Lantern = "Halloween Games Lantern",
    Flashlight = "Halloween Games Lantern",
    ["Halloween Games Lucky Charm"] = "Halloween Games Lucky Charm",
    ["Halloween Games Treat Magnet"] = "Halloween Games Treat Magnet",
    ["Halloween Games Broomstick"] = "Halloween Games Broomstick",
    ["Halloween Games Lantern"] = "Halloween Games Lantern",
}

-- Check if player owns a specific Trick consumable via HUD count, Consumable inventory, or Misc inventory
local function hasTrickItem(trickKeyOrId)
    local hudCount = getTrickCount(trickKeyOrId)
    if hudCount > 0 then
        return true
    end

    local fullName = TRICK_NAME_MAP[trickKeyOrId] or trickKeyOrId
    local save = getSaveData()
    if save and type(save.Inventory) == "table" then
        local function scanFolder(folder)
            if type(folder) == "table" then
                for _, item in pairs(folder) do
                    if type(item) == "table" and (item.id == fullName or item.id == trickKeyOrId) then
                        if (tonumber(item._am) or 1) > 0 then
                            return true
                        end
                    end
                end
            end
            return false
        end
        if scanFolder(save.Inventory.Consumable) or scanFolder(save.Inventory.Misc) then
            return true
        end
    end

    return false
end

-- Automatically activate any trick buff that the game HUD marks as "Ready!"
local function autoUseReadyTricks(nightMod)
    if not (nightMod and type(nightMod.Trick) == "function") then
        return
    end
    local lp = Players.LocalPlayer
    local pgui = lp and lp:FindFirstChildOfClass("PlayerGui")
    local hud = pgui and pgui:FindFirstChild("_INSTANCES") and pgui._INSTANCES:FindFirstChild("HalloweenGamesHud")
    local tricksFolder = hud and hud:FindFirstChild("Tricks")
    if not tricksFolder then
        return
    end

    local now = os.clock()
    for _, btn in ipairs(tricksFolder:GetChildren()) do
        if btn:IsA("GuiObject") and btn.Visible then
            local trickKey = btn.Name
            local stateLabel = btn:FindFirstChild("State")
            local countLabel = btn:FindFirstChild("Count")
            local stateText = stateLabel and stateLabel:IsA("TextLabel") and stateLabel.Text or ""
            local count = countLabel and countLabel:IsA("TextLabel") and tonumber(string.match(countLabel.Text, "%d+")) or 0

            if stateText == "Ready!" and (count > 0 or hasTrickItem(trickKey)) then
                local shouldRun = false
                if trickKey == "LuckyCharm" and Config.AutoUseLuckyCharm then
                    shouldRun = true
                elseif trickKey == "TreatMagnet" and Config.AutoUseTreatMagnet then
                    shouldRun = true
                elseif trickKey == "Broomstick" and Config.AutoUseBroomstick then
                    shouldRun = true
                elseif (trickKey == "Lantern" or trickKey == "Flashlight") and (Config.AutoUseLantern or Config.AutoUseLanternInFinal) then
                    shouldRun = true
                end

                if shouldRun then
                    local lastUsed = State.LastTrickUsedAt[trickKey] or 0
                    if (now - lastUsed) > 1.5 then
                        State.LastTrickUsedAt[trickKey] = now
                        local targetName = (trickKey == "Flashlight") and "Lantern" or trickKey
                        log("Auto-using ready buff: " .. targetName)
                        task.spawn(function()
                            pcall(nightMod.Trick, targetName)
                        end)
                        local firesig = firesignal or fire_signal
                        if type(firesig) == "function" then
                            pcall(firesig, btn.Activated)
                        end
                    end
                end
            end
        end
    end
end

-- Ensure internal Autopilot upvalue on LightsOut is disabled (nil) so our custom solver controls movement
local function tryEnableNativeAutopilot(roundName, roundMod)
    local setupval = (debug and debug.setupvalue) or setupvalue
    if type(setupval) == "function" and roundName == "LightsOut" and type(roundMod and roundMod.Autopilot) == "function" then
        pcall(setupval, roundMod.Autopilot, 2, nil)
    end
    return false
end

-- ============================================================================
-- FPS, MAP DELETION & 3D RENDERING OPTIMIZER
-- ============================================================================
local THINGS_BLOAT_FOLDERS = {
    "Breakables",
    "Pets",
    "Orbs",
    "Lootbags",
    "RenderedEggs",
    "CustomEggs",
    "VFX",
    "AnimatedBreakables",
    "Booths",
    "Flags",
    "Hoverboards",
    "RandomEvents",
    "Chests",
    "Shinies",
    "Ultimates",
}

local WORLD_BLOAT_NAMES = {
    "Map",
    "Zone 1",
    "GREYBOX_WIP",
    "PSX Hall",
    "Border",
    "FlyBorder",
}

local HG_ACTIVE_DELETE_NAMES = {
    "Map",
    "Border",
    "BREAK_ZONES",
    "INTERACT",
}

local LOBBY_MODELS_KEEP = {
    Pad = true,
    GROUND = true,
    Board = true,
    TeleportHide = true,
    Billboard = true,
    RemainingPlayers = true,
    RemainingIcons = true,
    Animations = true,
}

local function simplifyVisualTree(root)
    if not root then
        return
    end
    for _, desc in ipairs(root:GetDescendants()) do
        if desc:IsA("BasePart") then
            if not desc:GetAttribute("HGOpt") then
                desc:SetAttribute("HGOpt", true)
                desc.Material = Enum.Material.SmoothPlastic
                desc.CastShadow = false
                desc.Reflectance = 0
            end
        elseif desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") or desc:IsA("Fire") or desc:IsA("Smoke") or desc:IsA("Sparkles") then
            desc.Enabled = false
        elseif desc:IsA("PointLight") or desc:IsA("SpotLight") or desc:IsA("SurfaceLight") then
            desc.Enabled = false
        elseif desc:IsA("Decal") or desc:IsA("Texture") then
            desc.Transparency = 1
        end
    end
end

local function applyEngineOptimization()
    if State.EngineOptimized then
        return
    end
    State.EngineOptimized = true

    pcall(function()
        RunService:Set3dRenderingEnabled(not Config.Disable3DRendering)
    end)
    table.insert(State.Restorers, function()
        pcall(function()
            RunService:Set3dRenderingEnabled(true)
        end)
    end)

    if Config.FPSCap and tonumber(Config.FPSCap) and tonumber(Config.FPSCap) > 0 then
        local capFn = setfpscap or set_fps_cap
        if type(capFn) == "function" then
            pcall(capFn, tonumber(Config.FPSCap))
        end
    end

    if not Config.OptimizeFPS then
        return
    end

    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)

    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.ShadowSoftness = 0
        for _, child in ipairs(Lighting:GetChildren()) do
            if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Clouds") or child:IsA("Sky") then
                if child:IsA("PostEffect") then
                    child.Enabled = false
                else
                    child:Destroy()
                end
            end
        end
    end)

    pcall(function()
        local terrain = workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 0
            for _, child in ipairs(terrain:GetChildren()) do
                if child:IsA("Clouds") then
                    child:Destroy()
                end
            end
            terrain:Clear()
        end
    end)
end

local function installOptimizationHooks()
    if State.OptHooksInstalled or not Config.OptimizeFPS then
        return
    end
    local lib = ReplicatedStorage:FindFirstChild("Library")
    local clientLib = lib and lib:FindFirstChild("Client")
    local hgCmds = clientLib and clientLib:FindFirstChild("HalloweenGamesCmds")
    if not hgCmds then
        return
    end
    State.OptHooksInstalled = true

    -- Suppress HalloweenGamesCmds.Fx particles & screen shakes
    local fxScript = hgCmds:FindFirstChild("Fx")
    local okFx, fxMod = pcall(function()
        return fxScript and require(fxScript)
    end)
    if okFx and type(fxMod) == "table" then
        for _, fnName in ipairs({ "Burst", "Celebrate", "Through", "RoundStart", "Countdown", "Poof" }) do
            local orig = fxMod[fnName]
            if type(orig) == "function" then
                fxMod[fnName] = function() end
                table.insert(State.Restorers, function()
                    fxMod[fnName] = orig
                end)
            end
        end
        local origEmitter = fxMod.Emitter
        if type(origEmitter) == "function" then
            fxMod.Emitter = function(...)
                local em = origEmitter(...)
                if em and typeof(em) == "Instance" and em:IsA("ParticleEmitter") then
                    em.Enabled = false
                    em.Rate = 0
                end
                return em
            end
            table.insert(State.Restorers, function()
                fxMod.Emitter = origEmitter
            end)
        end
    end

    -- Suppress CurrencyBurst particle bursts
    local cbScript = clientLib:FindFirstChild("CurrencyBurst")
    local okCb, cbMod = pcall(function()
        return cbScript and require(cbScript)
    end)
    if okCb and type(cbMod) == "table" and type(cbMod.Play) == "function" then
        local origPlay = cbMod.Play
        cbMod.Play = function()
            return 0
        end
        table.insert(State.Restorers, function()
            cbMod.Play = origPlay
        end)
    end

    -- Suppress 19-bot 8-limb BulkMoveTo animations every RenderStepped while preserving PrimaryPart for HotPumpkin
    if Config.HideOtherPlayersAndBots then
        local rigsScript = hgCmds:FindFirstChild("Rigs")
        local okRigs, rigsMod = pcall(function()
            return rigsScript and require(rigsScript)
        end)
        if okRigs and type(rigsMod) == "table" then
            if type(rigsMod.Update) == "function" then
                local origUpdate = rigsMod.Update
                rigsMod.Update = function(_, model, cf)
                    if model and model.PrimaryPart and typeof(cf) == "CFrame" then
                        model.PrimaryPart.CFrame = cf * CFrame.new(0, 3, 0)
                    end
                end
                table.insert(State.Restorers, function()
                    rigsMod.Update = origUpdate
                end)
            end
            if type(rigsMod.Poof) == "function" then
                local origPoof = rigsMod.Poof
                rigsMod.Poof = function() end
                table.insert(State.Restorers, function()
                    rigsMod.Poof = origPoof
                end)
            end
        end
    end
end

local function stepOptimization()
    if not (Config.OptimizeFPS or Config.DeleteUnneededMap or Config.HideOtherPlayersAndBots) then
        return
    end
    local now = os.clock()
    if (now - State.LastOptimizeAt) < 2.0 then
        return
    end
    State.LastOptimizeAt = now

    installOptimizationHooks()

    -- 1. Clear temporary debris
    local debris = workspace:FindFirstChild("__DEBRIS")
    if debris then
        for _, child in ipairs(debris:GetChildren()) do
            pcall(child.Destroy, child)
        end
    end

    -- 2. Hide other players & bot rigs while keeping HumanoidRootPart / PrimaryPart for HotPumpkin
    if Config.HideOtherPlayersAndBots then
        local botsFolder = workspace:FindFirstChild("HalloweenGamesBots")
        if botsFolder then
            for _, botModel in ipairs(botsFolder:GetChildren()) do
                local pp = botModel:IsA("Model") and botModel.PrimaryPart or nil
                for _, child in ipairs(botModel:GetChildren()) do
                    if child == pp then
                        child.Transparency = 1
                        child.CastShadow = false
                    else
                        pcall(child.Destroy, child)
                    end
                end
            end
        end

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                for _, desc in ipairs(plr.Character:GetDescendants()) do
                    if desc:IsA("BasePart") then
                        desc.Transparency = 1
                        desc.CastShadow = false
                    elseif desc:IsA("Decal") or desc:IsA("Texture") then
                        desc.Transparency = 1
                    elseif desc:IsA("Accessory") or desc:IsA("Clothing") or desc:IsA("ShirtGraphic") or desc:IsA("CharacterMesh") then
                        pcall(desc.Destroy, desc)
                    elseif desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") or desc:IsA("BillboardGui") then
                        pcall(desc.Destroy, desc)
                    end
                end
            end
        end
    end

    if not Config.DeleteUnneededMap then
        return
    end

    -- 3. Clean World 1 / Match Place bloat folders
    local things = workspace:FindFirstChild("__THINGS")
    if things then
        for _, folderName in ipairs(THINGS_BLOAT_FOLDERS) do
            local f = things:FindFirstChild(folderName)
            if f then
                for _, child in ipairs(f:GetChildren()) do
                    pcall(child.Destroy, child)
                end
            end
        end
    end

    for _, name in ipairs(WORLD_BLOAT_NAMES) do
        local obj = workspace:FindFirstChild(name)
        if obj then
            pcall(obj.Destroy, obj)
        end
    end

    -- 4. Clean inside Active.HalloweenGames (preserve ArenaSlots, Hub.Circle/Model, Teleports, ZONE_GROUND, SAFETY_NET)
    local activeModel = getActiveInstanceModel()
    if activeModel then
        for _, delName in ipairs(HG_ACTIVE_DELETE_NAMES) do
            local target = activeModel:FindFirstChild(delName)
            if target then
                pcall(target.Destroy, target)
            end
        end
        local hub = activeModel:FindFirstChild("Hub")
        if hub then
            local props = hub:FindFirstChild("Props")
            if props then
                pcall(props.Destroy, props)
            end
            simplifyVisualTree(hub)
        end
        local zg = activeModel:FindFirstChild("ZONE_GROUND")
        if zg then
            simplifyVisualTree(zg)
        end
        local slots = activeModel:FindFirstChild("ArenaSlots")
        if slots then
            simplifyVisualTree(slots)
        end
    end

    -- 5. Clean Multiplayer Queue Lobby ("Want to Play? Join Here!")
    local models = workspace:FindFirstChild("Models")
    local netFolder = ReplicatedStorage:FindFirstChild("Network")
    if models and netFolder and netFolder:FindFirstChild("RequestRegister") then
        for _, child in ipairs(models:GetChildren()) do
            if not LOBBY_MODELS_KEEP[child.Name] then
                pcall(child.Destroy, child)
            end
        end
        local padModel = models:FindFirstChild("Pad")
        if padModel then
            simplifyVisualTree(padModel)
        end
        local groundModel = models:FindFirstChild("GROUND")
        if groundModel then
            simplifyVisualTree(groundModel)
        end
    end
end

-- ============================================================================
-- ROUND SOLVER 1: BroomSweep
-- ============================================================================
local function sweptMult(events, t)
    local total = 0
    local prevAt = 0
    local mult = 1
    for _, ev in ipairs(events or {}) do
        if t <= ev.at then
            break
        end
        total = total + mult * (ev.at - prevAt)
        local dt = math.min(ev.ramp, t - ev.at)
        total = total + (mult + (mult + (ev.mult - mult) * dt / ev.ramp)) / 2 * dt
        if dt < ev.ramp then
            return total
        end
        prevAt = ev.at + ev.ramp
        mult = ev.mult
    end
    return total + mult * (t - prevAt)
end

local function sweepAngle(cfg, elapsed)
    if not cfg or elapsed <= (cfg.intro or 0) then
        return 0
    end
    local omega = (math.pi * 2) / (cfg.period or 6)
    local afterIntro = elapsed - (cfg.intro or 0)
    local countdown = cfg.countdown or 3
    if afterIntro <= countdown then
        return omega * afterIntro * afterIntro / (2 * countdown)
    end
    local baseAngle = omega * countdown / 2
    return baseAngle + omega * sweptMult(cfg.events, afterIntro - countdown)
end

local function nextCrossTime(cfg, armKind, playerAngle, playerRadius, startElapsed)
    if not cfg then
        return nil
    end
    local poleRadius = cfg.poleRadius or 3
    local rimRadius = cfg.rimRadius or 24
    local reach = cfg[armKind .. "Reach"] or rimRadius
    if playerRadius < poleRadius or playerRadius > math.min(reach, rimRadius) then
        return nil
    end

    local offset = (armKind == "high") and (math.pi / 2) or 0
    local prevDiff = (playerAngle - (sweepAngle(cfg, startElapsed) + offset)) % math.pi
    local t = startElapsed
    while t < startElapsed + 4 do
        t = t + 0.02
        local curDiff = (playerAngle - (sweepAngle(cfg, t) + offset)) % math.pi
        if prevDiff < curDiff then
            return t
        end
        prevDiff = curDiff
    end
    return nil
end

local function performBroomJump(hum, hrp)
    if hum.FloorMaterial == Enum.Material.Air then
        return
    end
    hum:ChangeState(Enum.HumanoidStateType.Jumping)
    local vel = hrp.AssemblyLinearVelocity
    local jumpVy = hum.UseJumpPower and hum.JumpPower or math.sqrt(2 * workspace.Gravity * hum.JumpHeight)
    hrp.AssemblyLinearVelocity = Vector3.new(vel.X, math.max(vel.Y, jumpVy), vel.Z)
end

local function performBroomDuck(nightMod, cfg)
    local cooldown = (cfg and cfg.cooldown) or 1
    local now = os.clock()
    if now - State.Round.LastDuckAt < cooldown then
        return
    end
    State.Round.LastDuckAt = now
    if nightMod then
        nightMod.Input("duck", {})
    end
end

local function recoverBroomStateIfMissing()
    local r = State.Round
    if r.BroomConfig and r.BroomConfig.t0 then
        return
    end
    local getupvals = (debug and debug.getupvalues) or getupvalues
    if type(getupvals) ~= "function" then
        return
    end
    local lib = ReplicatedStorage:FindFirstChild("Library")
    local cmds = lib and lib:FindFirstChild("Client") and lib.Client:FindFirstChild("HalloweenGamesCmds")
    local rounds = cmds and cmds:FindFirstChild("Rounds")
    local bsModScript = rounds and rounds:FindFirstChild("BroomSweep")
    if not bsModScript then
        return
    end
    local ok, bsMod = pcall(require, bsModScript)
    if not (ok and type(bsMod) == "table") then
        return
    end
    local fn = bsMod.__HG_ORIG_ONSTATE or bsMod.OnState
    if type(fn) ~= "function" then
        return
    end
    local okUp, upvals = pcall(getupvals, fn)
    if not (okUp and type(upvals) == "table") then
        return
    end
    for _, v in pairs(upvals) do
        if type(v) == "table" and v.t0 and v.period then
            r.BroomConfig = v
        elseif typeof(v) == "CFrame" then
            r.BroomOrigin = v
        end
    end
end

local function stepBroomSweep(nightMod)
    local _, hrp, hum = getCharacter()
    if not (hrp and hum) then
        return
    end

    local now = os.clock()
    recoverBroomStateIfMissing()

    local cfg = State.Round.BroomConfig

    -- Immediate check via BroomSweepSign billboard so it works even before/without sweep config
    local sign = hrp:FindFirstChild("BroomSweepSign")
    if sign and sign:IsA("BillboardGui") and sign.Enabled then
        local label = sign:FindFirstChild("Label")
        local txt = label and label.Text or ""
        if txt == "JUMP!" and (now - State.Round.LastJumpAt) > 0.45 then
            State.Round.LastJumpAt = now
            performBroomJump(hum, hrp)
        elseif txt == "DIVE!" then
            performBroomDuck(nightMod, cfg)
        end
    end

    local origin = State.Round.BroomOrigin or (State.Round.Arena and State.Round.Arena:GetPivot())
    if not (cfg and cfg.t0 and origin) then
        return
    end

    local elapsed = workspace:GetServerTimeNow() - cfg.t0
    local startActive = (cfg.intro or 0) + (cfg.countdown or 0)
    local endActive = startActive + (cfg.active or 60)
    if elapsed < startActive - 0.3 or elapsed > endActive then
        return
    end

    local rel = origin:PointToObjectSpace(hrp.Position)
    local pAngle = math.atan2(rel.Z, rel.X)
    local pRadius = math.sqrt(rel.X * rel.X + rel.Z * rel.Z)

    local searchFrom = math.max(elapsed, startActive - 0.2)
    local lowCross = nextCrossTime(cfg, "low", pAngle, pRadius, searchFrom)
    local highCross = nextCrossTime(cfg, "high", pAngle, pRadius, searchFrom)
    local leadBonus = State.Round.BroomLead or 0

    if lowCross and lowCross >= startActive and lowCross <= endActive then
        local leadLow = lowCross - elapsed
        if leadLow <= (0.35 + leadBonus) and leadLow >= -0.08 and (now - State.Round.LastJumpAt) > 0.45 then
            State.Round.LastJumpAt = now
            performBroomJump(hum, hrp)
        end
    end

    if highCross and highCross >= startActive and highCross <= endActive then
        local leadHigh = highCross - elapsed
        if leadHigh <= (0.22 + leadBonus) and leadHigh >= -0.08 then
            performBroomDuck(nightMod, cfg)
        end
    end
end

-- ============================================================================
-- ROUND SOLVER 2: HotPumpkin
-- ============================================================================
local function getContestantRoot(nightMod, id)
    if not nightMod then
        return nil
    end
    local nState = nightMod.State()
    if id == nState.me then
        local _, hrp = getCharacter()
        return hrp
    end
    if id < 0 then
        local rig = nightMod.Rig and nightMod.Rig(id)
        if rig then
            return rig.PrimaryPart or rig:FindFirstChild("HumanoidRootPart") or rig:FindFirstChild("Body")
        end
        return nil
    end
    local c = nightMod.Contestant and nightMod.Contestant(id)
    local plr = c and c.UserId and Players:GetPlayerByUserId(c.UserId)
    local char = plr and plr.Character
    return char and char:FindFirstChild("HumanoidRootPart") or nil
end

local function getRoundModuleTable(roundName)
    local lib = ReplicatedStorage:FindFirstChild("Library")
    local cmds = lib and lib:FindFirstChild("Client") and lib.Client:FindFirstChild("HalloweenGamesCmds")
    local rounds = cmds and cmds:FindFirstChild("Rounds")
    local modScript = rounds and rounds:FindFirstChild(roundName)
    if not modScript then
        return nil
    end
    local ok, mod = pcall(require, modScript)
    return (ok and type(mod) == "table") and mod or nil
end

local function stepHotPumpkin(nightMod)
    local char, hrp, hum = getCharacter()
    if not (char and hrp and hum) then
        return
    end

    local nState = nightMod.State()
    local myId = nState.me
    if not myId then
        return
    end

    -- 1. Collect all active bomb holders from Workspace models, OnState upvalue u135, and tracked HotBombs
    local holdingBomb = false
    local holderIds = {}
    local holderRoots = {}

    for _, hId in pairs(State.Round.HotBombs) do
        holderIds[hId] = true
    end
    for hId in pairs(State.Round.HotHolders) do
        holderIds[hId] = true
    end

    local getupvals = (debug and debug.getupvalues) or getupvalues
    local hpMod = getRoundModuleTable("HotPumpkin")
    local origFn = hpMod and (hpMod.__HG_ORIG_ONSTATE or hpMod.OnState)
    if type(getupvals) == "function" and type(origFn) == "function" then
        local okUp, upvals = pcall(getupvals, origFn)
        if okUp and type(upvals) == "table" then
            for _, uVal in pairs(upvals) do
                if type(uVal) == "table" then
                    for _, entry in pairs(uVal) do
                        if type(entry) == "table" and tonumber(entry.holder) and entry.model then
                            holderIds[tonumber(entry.holder)] = true
                        end
                    end
                end
            end
        end
    end

    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") and string.find(child.Name, "^HotPumpkin%d+$") then
            local hl = child:FindFirstChildOfClass("Highlight")
            local adornee = hl and hl.Adornee
            if adornee then
                if adornee == char then
                    holdingBomb = true
                else
                    local root = adornee:FindFirstChild("HumanoidRootPart") or adornee.PrimaryPart or adornee:FindFirstChild("Body")
                    if root then
                        holderRoots[root] = true
                    end
                end
            end
        end
    end

    if holderIds[myId] then
        holdingBomb = true
    end

    for hId in pairs(holderIds) do
        if hId ~= myId then
            local root = getContestantRoot(nightMod, hId)
            if root then
                holderRoots[root] = true
            end
        end
    end

    local contestants = nightMod.Contestants and nightMod.Contestants() or {}

    if holdingBomb then
        -- Chase nearest valid non-holder contestant and pass the pumpkin immediately
        local bestId = nil
        local bestRoot = nil
        local bestDist = math.huge

        for id, c in pairs(contestants) do
            if id ~= myId and c.Alive ~= false and not c.Ghost and c.Sitting ~= true and not holderIds[id] then
                local root = getContestantRoot(nightMod, id)
                if root and not holderRoots[root] then
                    local dist = (root.Position - hrp.Position).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        bestId = id
                        bestRoot = root
                    end
                end
            end
        end

        if bestRoot then
            hum:MoveTo(bestRoot.Position)
            local now = os.clock()
            if bestDist > 3.2 and (now - State.Round.LastPassAt) >= 0.2 then
                hrp.CFrame = CFrame.new(bestRoot.Position + Vector3.new(1.5, 0, 0))
            end
            if (now - State.Round.LastPassAt) >= 0.25 then
                State.Round.LastPassAt = now
                nightMod.Input("pass", { id = bestId })
            end
        end
    else
        -- Orbit around the arena ring at the point that maximizes minimum distance to all bomb holders
        local arenaCenter = (State.Round.Arena and State.Round.Arena:GetPivot().Position) or nState.origin or hrp.Position
        local nearestHolderDist = math.huge
        for root in pairs(holderRoots) do
            local d = Vector3.new(hrp.Position.X - root.Position.X, 0, hrp.Position.Z - root.Position.Z).Magnitude
            if d < nearestHolderDist then
                nearestHolderDist = d
            end
        end

        if nearestHolderDist < math.huge then
            local bestCand = hrp.Position
            local bestScore = -math.huge
            local orbitRadius = 17

            for i = 0, 15 do
                local ang = (i * math.pi * 2) / 16
                local cand = Vector3.new(
                    arenaCenter.X + math.cos(ang) * orbitRadius,
                    hrp.Position.Y,
                    arenaCenter.Z + math.sin(ang) * orbitRadius
                )
                local minDistToHolder = math.huge
                for root in pairs(holderRoots) do
                    local hd = Vector3.new(cand.X - root.Position.X, 0, cand.Z - root.Position.Z).Magnitude
                    if hd < minDistToHolder then
                        minDistToHolder = hd
                    end
                end
                local moveDist = Vector3.new(cand.X - hrp.Position.X, 0, cand.Z - hrp.Position.Z).Magnitude
                local score = minDistToHolder - (moveDist * 0.15)
                if score > bestScore then
                    bestScore = score
                    bestCand = cand
                end
            end

            if nearestHolderDist < 11.0 then
                hrp.CFrame = CFrame.new(bestCand.X, hrp.Position.Y, bestCand.Z)
            else
                hum:MoveTo(bestCand)
            end
        end
    end
end

-- ============================================================================
-- ROUND SOLVER 3: LightsOut
-- ============================================================================
local function isInsideAttackZone(attack, pos, margin)
    if not attack then
        return false
    end
    if attack.k == "pounce" then
        return Vector3.new(pos.X - attack.to.X, 0, pos.Z - attack.to.Z).Magnitude <= (attack.r + margin)
    end
    local seg = Vector3.new(attack.to.X - attack.from.X, 0, attack.to.Z - attack.from.Z)
    local rel = Vector3.new(pos.X - attack.from.X, 0, pos.Z - attack.from.Z)
    local t = math.clamp(rel:Dot(seg) / math.max(seg:Dot(seg), 1e-6), 0, 1)
    return (rel - seg * t).Magnitude <= (attack.w / 2 + margin)
end

local function computeAttackEscape(attack, pos, lightCenter)
    if attack.k ~= "pounce" then
        local seg = Vector3.new(attack.to.X - attack.from.X, 0, attack.to.Z - attack.from.Z)
        local perp = Vector3.new(-seg.Z, 0, seg.X)
        local unit = (perp.Magnitude > 0.1) and perp.Unit or Vector3.new(1, 0, 0)
        local side = Vector3.new(pos.X - attack.from.X, 0, pos.Z - attack.from.Z):Dot(unit)
        local sign = (side >= 0) and 1 or -1
        return pos + unit * sign * (attack.w / 2 + 4 - math.abs(side))
    end

    local refCenter = lightCenter or pos
    local bestPos = attack.to
    local bestScore = math.huge
    for i = 0, 7 do
        local ang = i * math.pi / 4
        local cand = attack.to + Vector3.new(math.cos(ang), 0, math.sin(ang)) * (attack.r + 3.5)
        local score = (cand - pos).Magnitude + 0.35 * (cand - refCenter).Magnitude
        if score < bestScore then
            bestScore = score
            bestPos = cand
        end
    end
    return Vector3.new(bestPos.X, pos.Y, bestPos.Z)
end

local function stepLightsOut()
    local _, hrp, hum = getCharacter()
    if not (hrp and hum) then
        return
    end

    local r = State.Round
    local pos = hrp.Position

    -- Keep native LightsOut Autopilot disabled (u137 = nil) because native steer() has a blackout window bug
    local loMod = getRoundModuleTable("LightsOut")
    if loMod then
        if type(loMod.Autopilot) == "function" and type(debug) == "table" and type(debug.setupvalue) == "function" then
            pcall(debug.setupvalue, loMod.Autopilot, 2, nil)
        end
        local fn = loMod.__HG_ORIG_ONSTATE or loMod.OnState
        if type(fn) == "function" and type(debug) == "table" and type(debug.getupvalues) == "function" then
            local ok, ups = pcall(debug.getupvalues, fn)
            if ok and type(ups) == "table" then
                for _, v in pairs(ups) do
                    if type(v) == "number" and v > 1e9 and v < 2e10 then
                        r.LightStartAt = v
                    elseif type(v) == "table" and type(v[1]) == "table" and #v[1] == 2 and type(v[1][1]) == "number" and v[1][1] < 200 then
                        r.BlackoutSchedule = v
                    elseif type(v) == "function" then
                        local ok2, fups = pcall(debug.getupvalues, v)
                        if ok2 and type(fups) == "table" and fups[2] == Players and type(fups[9]) == "function" then
                            -- lightCheck() upvalues: 1=u112(phase), 2=Players, 3=u108(lightPos), 4=u111(blackout), 5=u105(radius), 8=u149(attack)
                            if typeof(fups[3]) == "Vector3" then
                                r.LightPos = fups[3]
                            end
                            r.Blackout = (fups[4] == true)
                            if type(fups[5]) == "number" and fups[5] > 0 then
                                r.LightRadius = fups[5]
                            end
                            r.ActiveAttack = type(fups[8]) == "table" and fups[8] or nil
                        end
                    end
                end
            end
        end
    end

    -- Fallback: read visual LightFill cylinder in workspace.LightsOutClient
    local loFolder = workspace:FindFirstChild("LightsOutClient")
    local lightFill = loFolder and loFolder:FindFirstChild("LightFill")
    if lightFill and lightFill:IsA("BasePart") and lightFill.Transparency < 0.95 then
        r.LightPos = Vector3.new(lightFill.Position.X, pos.Y, lightFill.Position.Z)
        if lightFill.Size.Y > 2 then
            r.LightRadius = lightFill.Size.Y / 2
        end
    end

    -- Check if blackout pulse is active or within [start - 0.55s, end + 0.25s]
    local blackoutImminent = r.Blackout
    if not blackoutImminent and r.LightStartAt > 0 then
        local elapsed = workspace:GetServerTimeNow() - r.LightStartAt
        for _, window in ipairs(r.BlackoutSchedule) do
            local wStart = tonumber(window[1]) or 0
            local wDur = tonumber(window[2]) or 2.5
            if elapsed >= (wStart - 0.55) and elapsed <= (wStart + wDur + 0.25) then
                blackoutImminent = true
                break
            end
        end
    end

    -- Freeze completely during blackout (never move or teleport while dark)
    if blackoutImminent then
        hum:Move(Vector3.zero)
        hum:MoveTo(pos)
        hrp.AssemblyLinearVelocity = Vector3.zero
        return
    end

    local lightCenter = r.LightPos or pos
    local safeRadius = math.max((r.LightRadius or 12) - 2.5, 4)

    -- Pick safe spot inside the light circle that avoids any active Gloomkin attack
    local target = Vector3.new(lightCenter.X, pos.Y, lightCenter.Z)
    if r.ActiveAttack and (isInsideAttackZone(r.ActiveAttack, pos, 3.5) or isInsideAttackZone(r.ActiveAttack, target, 3.5)) then
        local bestCand = nil
        local bestScore = math.huge
        for _, radFrac in ipairs({ 0.35, 0.7 }) do
            local rad = safeRadius * radFrac
            for i = 0, 15 do
                local ang = (i / 16) * math.pi * 2
                local cand = Vector3.new(lightCenter.X + math.cos(ang) * rad, pos.Y, lightCenter.Z + math.sin(ang) * rad)
                if not isInsideAttackZone(r.ActiveAttack, cand, 3.5) then
                    local score = (cand - pos).Magnitude + 0.25 * (cand - target).Magnitude
                    if score < bestScore then
                        bestScore = score
                        bestCand = cand
                    end
                end
            end
        end
        if not bestCand then
            bestCand = computeAttackEscape(r.ActiveAttack, pos, lightCenter)
        end
        target = Vector3.new(bestCand.X, pos.Y, bestCand.Z)
    end

    local flatDist = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z).Magnitude
    local distFromLight = Vector3.new(lightCenter.X - pos.X, 0, lightCenter.Z - pos.Z).Magnitude
    local inDanger = (distFromLight > safeRadius * 0.8)
        or (r.ActiveAttack ~= nil and isInsideAttackZone(r.ActiveAttack, pos, 3.0))

    if inDanger or flatDist > 7.5 then
        hrp.CFrame = CFrame.new(target.X, pos.Y, target.Z) * hrp.CFrame.Rotation
        hum:MoveTo(target)
    elseif flatDist > 1.8 then
        hum:MoveTo(target)
    end
end

-- ============================================================================
-- ROUND SOLVER 4: BumperPumpkins
-- ============================================================================
local function computeDefensiveBumperSteer(myId, ringCenterRel, ringRadius, carsMap, carsHistMap)
    local myPos = carsMap[myId]
    if not myPos then
        return 0, 0, false
    end

    local rx = ringCenterRel.X
    local rz = ringCenterRel.Z
    local rad = math.max(ringRadius or 28, 6)

    -- Compute our velocity from history
    local vx, vz = 0, 0
    local myHist = carsHistMap and carsHistMap[myId]
    if type(myHist) == "table" and #myHist >= 2 then
        local p1 = myHist[#myHist - 1]
        local p2 = myHist[#myHist]
        local dt = (tonumber(p2.t) or 0) - (tonumber(p1.t) or 0)
        if dt > 0.001 then
            vx = ((tonumber(p2.x) or 0) - (tonumber(p1.x) or 0)) / dt
            vz = ((tonumber(p2.z) or 0) - (tonumber(p1.z) or 0)) / dt
        end
    end

    -- Project position 0.45s ahead to counter outward momentum early
    local predX = myPos.X + vx * 0.45
    local predZ = myPos.Z + vz * 0.45

    local offsetX = myPos.X - rx
    local offsetZ = myPos.Z - rz
    local distCenter = math.sqrt(offsetX * offsetX + offsetZ * offsetZ)

    local predOffX = predX - rx
    local predOffZ = predZ - rz
    local predDistCenter = math.sqrt(predOffX * predOffX + predOffZ * predOffZ)

    -- Desired target starts at ring center
    local goalX = rx
    local goalZ = rz

    -- Repulsion from other cars (prevent getting rammed toward the edge)
    local repX, repZ = 0, 0
    for otherId, otherPos in pairs(carsMap) do
        if otherId ~= myId and otherPos then
            local ox = otherPos.X
            local oz = otherPos.Z
            local ovx, ovz = 0, 0
            local oHist = carsHistMap and carsHistMap[otherId]
            if type(oHist) == "table" and #oHist >= 2 then
                local op1 = oHist[#oHist - 1]
                local op2 = oHist[#oHist]
                local odt = (tonumber(op2.t) or 0) - (tonumber(op1.t) or 0)
                if odt > 0.001 then
                    ovx = ((tonumber(op2.x) or 0) - (tonumber(op1.x) or 0)) / odt
                    ovz = ((tonumber(op2.z) or 0) - (tonumber(op1.z) or 0)) / odt
                end
            end
            local futureOx = ox + ovx * 0.25
            local futureOz = oz + ovz * 0.25
            local dx = myPos.X - futureOx
            local dz = myPos.Z - futureOz
            local d = math.sqrt(dx * dx + dz * dz)
            if d < 12.0 and d > 0.05 then
                -- Sidestep perpendicular/inward rather than outward!
                local weight = ((12.0 - d) / 12.0) ^ 1.5 * 8.0
                repX = repX + (dx / d) * weight
                repZ = repZ + (dz / d) * weight
            end
        end
    end

    -- Clamp goal strictly inside 38% of ring radius so avoidance never pushes us toward the ring edge
    local rawGoalOffX = (goalX + repX) - rx
    local rawGoalOffZ = (goalZ + repZ) - rz
    local rawGoalDist = math.sqrt(rawGoalOffX * rawGoalOffX + rawGoalOffZ * rawGoalOffZ)
    local maxSafeOrbit = math.max(rad * 0.35, 2.5)
    if rawGoalDist > maxSafeOrbit and rawGoalDist > 0.01 then
        rawGoalOffX = rawGoalOffX / rawGoalDist * maxSafeOrbit
        rawGoalOffZ = rawGoalOffZ / rawGoalDist * maxSafeOrbit
    end
    goalX = rx + rawGoalOffX
    goalZ = rz + rawGoalOffZ

    -- PD velocity controller: desired velocity toward goal minus current velocity
    local toGoalX = goalX - myPos.X
    local toGoalZ = goalZ - myPos.Z
    local toGoalDist = math.sqrt(toGoalX * toGoalX + toGoalZ * toGoalZ)

    local desSpeed = math.clamp(toGoalDist * 3.2, 0, 28)
    if distCenter > rad * 0.55 or predDistCenter > rad * 0.62 then
        -- Emergency inward recovery: point straight at ring center at full speed
        toGoalX = rx - myPos.X
        toGoalZ = rz - myPos.Z
        toGoalDist = math.sqrt(toGoalX * toGoalX + toGoalZ * toGoalZ)
        desSpeed = 32
    end

    local desVx, desVz = 0, 0
    if toGoalDist > 0.05 then
        desVx = (toGoalX / toGoalDist) * desSpeed
        desVz = (toGoalZ / toGoalDist) * desSpeed
    end

    -- Subtract current velocity (damping) so car brakes instead of overshooting center
    local steerX = desVx - vx * 0.85
    local steerZ = desVz - vz * 0.85
    local steerMag = math.sqrt(steerX * steerX + steerZ * steerZ)
    if steerMag > 0.05 then
        steerX = steerX / steerMag
        steerZ = steerZ / steerMag
    else
        steerX, steerZ = 0, 0
    end

    -- Only boost when recovering inward from outer half OR dodging an imminent ram while pointing inward
    local outSpeed = 0
    if distCenter > 0.5 then
        outSpeed = (vx * offsetX + vz * offsetZ) / distCenter
    end
    local wantBoost = (distCenter > rad * 0.58) or (predDistCenter > rad * 0.68) or (distCenter > rad * 0.42 and outSpeed > 10)

    return steerX, steerZ, wantBoost
end

local function stepBumperPumpkins(nightMod)
    local now = os.clock()
    if now - State.Round.LastSteerAt < 0.06 then
        return
    end
    State.Round.LastSteerAt = now

    local nState = nightMod.State()
    local myId = nState.me
    if not myId then
        return
    end

    local r = State.Round
    local getupval = (debug and debug.getupvalue) or getupvalue
    local setupval = (debug and debug.setupvalue) or setupvalue
    local bpMod = getRoundModuleTable("BumperPumpkins")
    local carsHistMap = nil

    if bpMod and type(getupval) == "function" then
        -- 1. Read live ring and car positions directly from decode upvalue of BumperPumpkins.OnState
        --    Note: inside decode(a1), u166 = ringRadius (#2), u168 = ringZ (#4), u169 = ringHistory (#5), u165 = carsHistMap (#6)
        local origOnState = bpMod.__HG_ORIG_ONSTATE
        if not origOnState and type(bpMod.OnState) == "function" then
            local okU, u3 = pcall(getupval, bpMod.OnState, 3)
            origOnState = (okU and type(u3) == "function") and u3 or bpMod.OnState
        end
        if type(origOnState) == "function" then
            local okD, decodeFn = pcall(getupval, origOnState, 1)
            local okA, arenaCf = pcall(getupval, origOnState, 3)
            if okD and type(decodeFn) == "function" then
                local _, ringR = pcall(getupval, decodeFn, 2)
                local _, ringHist = pcall(getupval, decodeFn, 5)
                local _, cMap = pcall(getupval, decodeFn, 6)
                if tonumber(ringR) and ringR > 0 then
                    r.RingRadius = tonumber(ringR)
                end
                if type(ringHist) == "table" and #ringHist > 0 then
                    local latestRing = ringHist[#ringHist]
                    if latestRing and tonumber(latestRing.x) and tonumber(latestRing.z) then
                        r.BumperRingRel = Vector3.new(latestRing.x, 0, latestRing.z)
                        if tonumber(latestRing.r) and latestRing.r > 0 then
                            r.RingRadius = tonumber(latestRing.r)
                        end
                        if okA and typeof(arenaCf) == "CFrame" then
                            r.RingCenter = arenaCf:PointToWorldSpace(r.BumperRingRel)
                        end
                    end
                end
                if type(cMap) == "table" then
                    carsHistMap = cMap
                    for id, hist in pairs(cMap) do
                        if type(hist) == "table" and #hist > 0 then
                            local latest = hist[#hist]
                            if latest and tonumber(latest.x) and tonumber(latest.z) then
                                r.BumperCars[id] = Vector3.new(latest.x, 0, latest.z)
                            end
                        end
                    end
                end
            end
        end

        -- 2. Hook steerFn's moveVector (upvalue #14) AND boostFn's moveVector (upvalue #10)
        --    with our defensive PD ring-center + anti-ram controller!
        if type(setupval) == "function" then
            local origEnter = bpMod.__HG_ORIG_ENTER
            if not origEnter and type(bpMod.Enter) == "function" then
                local okE, u6 = pcall(getupval, bpMod.Enter, 6)
                origEnter = (okE and type(u6) == "function") and u6 or bpMod.Enter
            end
            if type(origEnter) == "function" then
                local okR, renderFn = pcall(getupval, origEnter, 17)
                if okR and type(renderFn) == "function" then
                    local okS, steerFn = pcall(getupval, renderFn, 3)
                    if okS and type(steerFn) == "function" then
                        local _, boostFn = pcall(getupval, steerFn, 13)
                        local _, curMoveVecFn = pcall(getupval, steerFn, 14)

                        if curMoveVecFn ~= r.HookedMoveVecFn then
                            r.HookedMoveVecFn = function()
                                local _, arenaCf = pcall(getupval, steerFn, 10)
                                local sx, sz, wantBoost = computeDefensiveBumperSteer(
                                    myId,
                                    r.BumperRingRel,
                                    r.RingRadius,
                                    r.BumperCars,
                                    carsHistMap
                                )
                                if wantBoost and type(boostFn) == "function" and (os.clock() - r.LastBoostAt) > 0.5 then
                                    r.LastBoostAt = os.clock()
                                    task.defer(pcall, boostFn)
                                end
                                local localVec = Vector3.new(sx, 0, sz)
                                if localVec.Magnitude > 1 then
                                    localVec = localVec.Unit
                                end
                                if typeof(arenaCf) == "CFrame" then
                                    return arenaCf:VectorToWorldSpace(localVec)
                                end
                                return localVec
                            end
                            pcall(setupval, steerFn, 14, r.HookedMoveVecFn)
                            if type(boostFn) == "function" then
                                pcall(setupval, boostFn, 10, r.HookedMoveVecFn)
                            end
                            log("BumperPumpkins hooked defensive PD moveVector on steer + boost")
                        end
                    end
                end
            end
        end
    end

    -- Fallback if steerFn moveVector could not be hooked
    if not r.HookedMoveVecFn then
        local sx, sz, wantBoost = computeDefensiveBumperSteer(
            myId,
            r.BumperRingRel,
            r.RingRadius,
            r.BumperCars,
            carsHistMap
        )
        local arena = r.Arena
        local worldDir = Vector3.new(sx, 0, sz)
        if arena and worldDir.Magnitude > 0.01 then
            worldDir = arena:GetPivot():VectorToWorldSpace(worldDir)
        end
        nightMod.Input("steer", {
            x = math.floor(worldDir.X * 100) / 100,
            z = math.floor(worldDir.Z * 100) / 100,
        })
        if wantBoost and (now - r.LastBoostAt) > 0.8 then
            r.LastBoostAt = now
            nightMod.Input("boost", {
                x = math.floor(worldDir.X * 100) / 100,
                z = math.floor(worldDir.Z * 100) / 100,
            })
        end
    end
end

-- ============================================================================
-- ROUND SOLVER 5: PumpkinColors
-- ============================================================================
local function stepPumpkinColors()
    local _, hrp, hum = getCharacter()
    if not (hrp and hum) then
        return
    end

    local r = State.Round
    local getupval = (debug and debug.getupvalue) or getupvalue
    local pcMod = getRoundModuleTable("PumpkinColors")
    local origFn = pcMod and (pcMod.__HG_ORIG_ONSTATE or pcMod.OnState)
    if not origFn and pcMod and type(pcMod.OnState) == "function" and type(getupval) == "function" then
        local okU, u3 = pcall(getupval, pcMod.OnState, 3)
        origFn = (okU and type(u3) == "function") and u3 or pcMod.OnState
    end

    local directPadsMap = nil
    local unsafePadsSet = {}

    if type(getupval) == "function" and type(origFn) == "function" then
        -- u64 (upvalue #4): { text, first, second, round, startsAt, endsAt }
        local okCall, u64 = pcall(getupval, origFn, 4)
        if okCall and type(u64) == "table" and type(u64.first) == "string" and tonumber(u64.endsAt) then
            r.SafeColors = { u64.first }
            if type(u64.second) == "string" then
                table.insert(r.SafeColors, u64.second)
            end
            r.ColorCallEndsAt = tonumber(u64.endsAt)
        end
        -- u67 (upvalue #15): array of UNSAFE pad BaseParts for the active call
        local okUnsafe, u67 = pcall(getupval, origFn, 15)
        if okUnsafe and type(u67) == "table" then
            for _, p in ipairs(u67) do
                unsafePadsSet[p] = true
            end
        end
        -- u59 (upvalue #16): map of padIndex -> BasePart (all 16 pads)
        local okPads, u59 = pcall(getupval, origFn, 16)
        if okPads and type(u59) == "table" then
            directPadsMap = u59
        end
    end

    local nowServer = workspace:GetServerTimeNow()
    if #r.SafeColors == 0 or nowServer >= (r.ColorCallEndsAt - 0.02) then
        return
    end

    local allowedColor = {}
    for _, cName in ipairs(r.SafeColors) do
        allowedColor[cName] = true
    end

    local bestPad = nil
    local bestDist = math.huge

    -- Priority 1: Use u59 (all pads) minus u67 (unsafe pads) from PumpkinColors.OnState upvalues
    if directPadsMap and next(unsafePadsSet) ~= nil then
        for _, pad in pairs(directPadsMap) do
            if typeof(pad) == "Instance" and pad:IsA("BasePart") and not unsafePadsSet[pad] and pad:GetAttribute("Hidden") ~= true then
                local d = Vector3.new(pad.Position.X - hrp.Position.X, 0, pad.Position.Z - hrp.Position.Z).Magnitude
                if d < bestDist then
                    bestDist = d
                    bestPad = pad
                end
            end
        end
    end

    -- Priority 2: Scan arena descendants by ColorName attribute
    local arena = r.Arena
    if not bestPad and arena then
        for _, desc in ipairs(arena:GetDescendants()) do
            if desc:IsA("BasePart") then
                local cName = desc:GetAttribute("ColorName")
                local hidden = desc:GetAttribute("Hidden")
                if cName and allowedColor[cName] and hidden ~= true and not unsafePadsSet[desc] then
                    local d = Vector3.new(desc.Position.X - hrp.Position.X, 0, desc.Position.Z - hrp.Position.Z).Magnitude
                    if d < bestDist then
                        bestDist = d
                        bestPad = desc
                    end
                end
            end
        end
    end

    if bestPad then
        local targetPos = Vector3.new(bestPad.Position.X, hrp.Position.Y, bestPad.Position.Z)
        if bestDist > 5.0 or ((r.ColorCallEndsAt - nowServer) < 1.8 and bestDist > 1.0) then
            hrp.CFrame = CFrame.new(targetPos) * hrp.CFrame.Rotation
            hum:MoveTo(targetPos)
        elseif bestDist > 0.75 then
            hum:MoveTo(targetPos)
        else
            hum:Move(Vector3.zero)
        end
    end
end

-- ============================================================================
-- ROUND SOLVER 6: TrickOrTreatDoors (Part 2 Final Round)
-- ============================================================================
local function findDoorBoothTrigger(arena, doorId, directDoorsMap)
    if type(directDoorsMap) == "table" and type(directDoorsMap[doorId]) == "table" then
        local entry = directDoorsMap[doorId]
        if typeof(entry.trigger) == "Instance" and entry.trigger:IsA("BasePart") then
            return entry.trigger
        end
    end
    if not arena then
        return nil
    end
    local booths = arena:FindFirstChild("DoorBooths") or arena
    for _, booth in ipairs(booths:GetChildren()) do
        local attrId = booth:GetAttribute("DoorId") or booth:GetAttribute("Id") or tonumber(string.match(booth.Name, "%d+"))
        if attrId == doorId then
            local trig = booth:FindFirstChild("Trigger", true)
                or booth:FindFirstChild("Pad", true)
                or booth:FindFirstChildWhichIsA("BasePart", true)
            if trig then
                return trig
            end
        end
    end
    return nil
end

local function isDoorPickable(doorId)
    local r = State.Round
    if r.RevealedDoors[doorId] == "trick" then
        return false
    end
    if r.TakenDoors[doorId] == true then
        return false
    end
    if r.HiddenDoors[doorId] ~= nil then
        return false
    end
    return true
end

local function chooseBestDoorId()
    local r = State.Round
    if #r.ActiveDoors == 0 then
        return nil
    end

    local candidates = {}
    for _, doorId in ipairs(r.ActiveDoors) do
        if doorId ~= r.LanternDoorId and isDoorPickable(doorId) then
            table.insert(candidates, doorId)
        end
    end

    if #candidates == 0 then
        -- Fallback to any pickable door even if Lantern flagged it (shouldn't happen unless 1 door)
        for _, doorId in ipairs(r.ActiveDoors) do
            if isDoorPickable(doorId) then
                return doorId
            end
        end
        return r.ActiveDoors[1]
    end

    -- 1. Prefer doors already revealed as "treat" that are still pickable
    for _, doorId in ipairs(candidates) do
        if r.RevealedDoors[doorId] == "treat" and doorId ~= r.SniffDoorId then
            return doorId
        end
    end

    -- 2. Prefer unopened doors not flagged by SniffHint ("smells funny" = likely trick)
    for _, doorId in ipairs(candidates) do
        if doorId ~= r.SniffDoorId and r.RevealedDoors[doorId] == nil then
            return doorId
        end
    end

    -- 3. Any candidate not flagged by SniffHint
    for _, doorId in ipairs(candidates) do
        if doorId ~= r.SniffDoorId then
            return doorId
        end
    end

    return candidates[1]
end

local function stepTrickOrTreatDoors(nightMod)
    local _, hrp, hum = getCharacter()
    if not (hrp and hum) then
        return
    end

    local r = State.Round
    local getupval = (debug and debug.getupvalue) or getupvalue
    local tdMod = getRoundModuleTable("TrickOrTreatDoors")
    local origFn = tdMod and (tdMod.__HG_ORIG_ONSTATE or tdMod.OnState)
    if not origFn and tdMod and type(tdMod.OnState) == "function" and type(getupval) == "function" then
        local okU, u3 = pcall(getupval, tdMod.OnState, 3)
        origFn = (okU and type(u3) == "function") and u3 or tdMod.OnState
    end

    local directDoorsMap = nil
    local setPreviewFn = nil
    if type(getupval) == "function" and type(origFn) == "function" then
        -- Verified TrickOrTreatDoors.OnState upvalue layout:
        -- #1 u83 (activeDoors array), #2 u84 (activeMap), #3 u85 (revealedMap),
        -- #4 u86 (takenDoors map!), #5 u87 (doorPhase string!),
        -- #10 u105 (waveIndex), #12 u88 (committedDoorId!),
        -- #15 setPreview(doorId), #17 u94 (sniffDoorId!),
        -- #19 u95 (lanternDoorId!), #21 u82 (doorsMap!), #23 u99 (hiddenDoorsMap!)
        local _, u83 = pcall(getupval, origFn, 1)
        local _, u85 = pcall(getupval, origFn, 3)
        local _, u86 = pcall(getupval, origFn, 4)
        local _, u87 = pcall(getupval, origFn, 5)
        local _, u105 = pcall(getupval, origFn, 10)
        local _, u88 = pcall(getupval, origFn, 12)
        local _, spFn = pcall(getupval, origFn, 15)
        local _, u94 = pcall(getupval, origFn, 17)
        local _, u95 = pcall(getupval, origFn, 19)
        local _, u82 = pcall(getupval, origFn, 21)
        local _, u99 = pcall(getupval, origFn, 23)

        if type(u83) == "table" and #u83 > 0 then
            r.ActiveDoors = u83
        end
        if type(u85) == "table" then
            r.RevealedDoors = u85
        end
        if type(u86) == "table" then
            r.TakenDoors = u86
        end
        if type(u87) == "string" and u87 ~= "" then
            r.DoorPhase = u87
        end
        if tonumber(u105) and tonumber(u105) > 0 then
            r.DoorWave = tonumber(u105)
        end
        r.CommittedDoorId = u88
        if type(spFn) == "function" then
            setPreviewFn = spFn
        end
        r.SniffDoorId = tonumber(u94) or r.SniffDoorId
        r.LanternDoorId = tonumber(u95) or r.LanternDoorId
        if type(u82) == "table" then
            directDoorsMap = u82
        end
        if type(u99) == "table" then
            r.HiddenDoors = u99
        end
    end

    if (r.DoorPhase ~= "pick" and r.DoorPhase ~= "sniff") or r.CommittedDoorId ~= nil then
        return
    end

    if Config.AutoUseLanternInFinal and r.DoorPhase == "pick" then
        local nState = nightMod.State()
        local waveKey = tostring(nState.roundId) .. "_" .. tostring(r.DoorWave)
        if State.LanternUsedRoundId ~= waveKey and hasTrickItem("Lantern") then
            State.LanternUsedRoundId = waveKey
            log("Using Lantern in TrickOrTreatDoors")
            nightMod.Trick("Lantern")
        end
    end

    local targetDoorId = chooseBestDoorId()
    if not targetDoorId then
        return
    end

    local trig = findDoorBoothTrigger(r.Arena, targetDoorId, directDoorsMap)
    if trig then
        -- Stand right inside the trigger box (same check as TrickOrTreatDoors.step(): |X|<=Size.X/2, |Z|<=Size.Z/2)
        local targetPos = Vector3.new(trig.Position.X, hrp.Position.Y, trig.Position.Z)
        local dist = Vector3.new(targetPos.X - hrp.Position.X, 0, targetPos.Z - hrp.Position.Z).Magnitude
        if dist > 2.2 then
            hrp.CFrame = CFrame.new(targetPos) * hrp.CFrame.Rotation
            hum:MoveTo(targetPos)
        else
            hum:MoveTo(targetPos)
        end
        if r.DoorPhase == "pick" then
            if type(setPreviewFn) == "function" then
                pcall(setPreviewFn, targetDoorId)
            end
            if (os.clock() - r.LastCommitAt) > 0.32 then
                r.LastCommitAt = os.clock()
                nightMod.Input("CommitDoor", { doorId = targetDoorId })
            end
        end
    elseif r.DoorPhase == "pick" then
        if (os.clock() - r.LastCommitAt) > 0.4 then
            r.LastCommitAt = os.clock()
            nightMod.Input("CommitDoor", { doorId = targetDoorId })
        end
    end
end

-- ============================================================================
-- ROUND SOLVER 7: ScarecrowStare (Part 1 Round 1)
-- ============================================================================
local function stepScarecrowStare()
    local _, hrp, hum = getCharacter()
    if not (hrp and hum) then
        return
    end

    local r = State.Round
    if r.ScarecrowFinished then
        hum:Move(Vector3.zero)
        return
    end

    if r.ScarecrowLight == "green" then
        local arena = r.Arena
        local finish = arena and (arena:FindFirstChild("FinishWall", true) or arena:FindFirstChild("ScarecrowRig", true))
        if finish then
            local finishPos = finish:IsA("BasePart") and finish.Position or finish:GetPivot().Position
            hum:MoveTo(Vector3.new(finishPos.X, hrp.Position.Y, finishPos.Z))
        end
    else
        hum:MoveTo(hrp.Position)
        hum:Move(Vector3.zero)
    end
end

-- ============================================================================
-- HOOK ROUND MODULES (Enter / OnState / Leave)
-- ============================================================================
local function handleRoundOnState(roundName, packet)
    if type(packet) ~= "table" then
        return
    end
    local ev = packet.event
    local data = packet.data or {}
    local r = State.Round

    if roundName == "BroomSweep" then
        if ev == "sweep" then
            r.BroomConfig = data
            if typeof(data.origin) == "CFrame" then
                r.BroomOrigin = data.origin
            end
        elseif ev == "luck" then
            r.BroomLead = tonumber(data.lead) or 0
        elseif ev == "phase" then
            r.Phase = data.phase
        end

    elseif roundName == "HotPumpkin" then
        if ev == "light" then
            if data.k and data.holder then
                r.HotBombs[data.k] = data.holder
            end
        elseif ev == "pass" then
            if data.k and data.to then
                r.HotBombs[data.k] = data.to
            end
        elseif ev == "pop" then
            if data.k then
                r.HotBombs[data.k] = nil
            end
        elseif ev == "over" or ev == "boom" then
            table.clear(r.HotBombs)
            table.clear(r.HotHolders)
        end
        table.clear(r.HotHolders)
        for _, hId in pairs(r.HotBombs) do
            r.HotHolders[hId] = true
        end

    elseif roundName == "LightsOut" then
        if ev == "pulse" or ev == "blackout" then
            r.Blackout = (data.on == true) or (data.active == true)
        elseif ev == "intro" then
            local y = data.floorY or (r.LightPos and r.LightPos.Y) or 0
            if type(data.center) == "table" and data.center.x and data.center.z then
                r.LightPos = Vector3.new(data.center.x, y, data.center.z)
            end
            if tonumber(data.radius) then
                r.LightRadius = tonumber(data.radius)
            end
        elseif ev == "drop" or ev == "hunt" or ev == "start" or ev == "init" then
            if type(data.pulses) == "table" then
                r.BlackoutSchedule = data.pulses
            elseif type(data.blackouts) == "table" then
                r.BlackoutSchedule = data.blackouts
            end
            if tonumber(data.at) then
                r.LightStartAt = tonumber(data.at)
            elseif tonumber(data.t0) then
                r.LightStartAt = tonumber(data.t0)
            end
            if tonumber(data.radius) then
                r.LightRadius = tonumber(data.radius)
            end
        elseif ev == "state" or ev == "light" or ev == "candle" then
            local cx = data.cx or data.x
            local cz = data.cz or data.z
            if cx and cz then
                local y = r.LightPos and r.LightPos.Y or 0
                r.LightPos = Vector3.new(cx, y, cz)
            end
            if data.vx and data.vz then
                r.LightVel = Vector3.new(data.vx, 0, data.vz)
            end
            if data.r and data.r > 0 then
                r.LightRadius = data.r
            end
        elseif ev == "attack" or ev == "telegraph" then
            local y = r.LightPos and r.LightPos.Y or 0
            r.ActiveAttack = {
                k = data.k,
                from = Vector3.new(data.fx or 0, y, data.fz or 0),
                to = Vector3.new(data.tx or 0, y, data.tz or 0),
                r = data.r or 7,
                w = data.w or 7,
                at = data.at or (workspace:GetServerTimeNow() + 1.2),
            }
        elseif ev == "strike" or ev == "land" or ev == "clear" then
            r.ActiveAttack = nil
        elseif ev == "flare" then
            r.Blackout = false
            r.ActiveAttack = nil
        end

    elseif roundName == "BumperPumpkins" then
        if typeof(data) == "buffer" and buffer.len(data) >= 16 and buffer.readu8(data, 0) == 2 then
            local carCount = buffer.readu8(data, 1)
            r.RingRadius = buffer.readu16(data, 2) / 64
            local rx = buffer.readi16(data, 12) / 32
            local rz = buffer.readi16(data, 14) / 32
            r.BumperRingRel = Vector3.new(rx, 0, rz)
            if r.Arena then
                r.RingCenter = r.Arena:GetPivot():PointToWorldSpace(r.BumperRingRel)
            end
            local len = buffer.len(data)
            for i = 0, carCount - 1 do
                local offset = 16 + i * 8
                if offset + 6 <= len then
                    local id = buffer.readi16(data, offset)
                    local cx = buffer.readi16(data, offset + 2) / 32
                    local cz = buffer.readi16(data, offset + 4) / 32
                    r.BumperCars[id] = Vector3.new(cx, 0, cz)
                end
            end
        end

    elseif roundName == "PumpkinColors" then
        if ev == "call" then
            r.SafeColors = data.called or {}
            r.SafePads = data.safe or {}
            r.ColorCallEndsAt = tonumber(data.endsAt) or (workspace:GetServerTimeNow() + 4)
        elseif ev == "board" or ev == "drop" then
            table.clear(r.SafeColors)
        end

    elseif roundName == "TrickOrTreatDoors" then
        if ev == "wave" then
            r.DoorWave = (tonumber(data.waveIndex) or (r.DoorWave + 1))
            r.ActiveDoors = data.doors or {}
            table.clear(r.RevealedDoors)
            table.clear(r.TakenDoors)
            r.SniffDoorId = nil
            r.LanternDoorId = nil
            r.CommittedDoorId = nil
            r.DoorPhase = "sniff"
        elseif ev == "SniffHint" then
            r.SniffDoorId = data.doorId
        elseif ev == "lantern" then
            r.LanternDoorId = data.doorId
        elseif ev == "taken" and data.doorId then
            r.TakenDoors[data.doorId] = true
        elseif ev == "pick" then
            r.DoorPhase = "pick"
        elseif ev == "DoorRevealed" and data.doorId then
            r.RevealedDoors[data.doorId] = data.result
        elseif ev == "committed" then
            local m = getModules()
            local nState = m and m.Night and m.Night.State()
            if nState and data.id == nState.me then
                r.CommittedDoorId = data.doorId
            end
        elseif ev == "WaveResult" then
            r.DoorPhase = "reveal"
        end

    elseif roundName == "ScarecrowStare" then
        if ev == "light" then
            r.ScarecrowLight = tostring(data.state or "red")
        elseif ev == "early" then
            r.ScarecrowLight = "tell"
        elseif ev == "finished" then
            local m = getModules()
            local nState = m and m.Night and m.Night.State()
            if nState and data.id == nState.me then
                r.ScarecrowFinished = true
            end
        end
    end
end

local function installRoundHooks()
    local lib = ReplicatedStorage:FindFirstChild("Library")
    local cmds = lib and lib:FindFirstChild("Client") and lib.Client:FindFirstChild("HalloweenGamesCmds")
    local roundsFolder = cmds and cmds:FindFirstChild("Rounds")
    if not roundsFolder then
        return false
    end

    for _, modScript in ipairs(roundsFolder:GetChildren()) do
        if modScript:IsA("ModuleScript") and modScript.Name ~= "_Sample" then
            local ok, roundMod = pcall(require, modScript)
            if ok and type(roundMod) == "table" and not roundMod.__HG_HOOKED then
                local roundName = modScript.Name
                local origEnter = roundMod.Enter
                local origOnState = roundMod.OnState
                local origLeave = roundMod.Leave

                roundMod.__HG_HOOKED = true
                roundMod.__HG_ORIG_ENTER = origEnter
                roundMod.__HG_ORIG_ONSTATE = origOnState

                if type(origEnter) == "function" then
                    roundMod.Enter = function(arena, info, ...)
                        resetRoundState(roundName, arena, info)
                        tryEnableNativeAutopilot(roundName, roundMod)
                        log("Entered round: " .. roundName)
                        return origEnter(arena, info, ...)
                    end
                end

                if type(origOnState) == "function" then
                    roundMod.OnState = function(packet, ...)
                        pcall(handleRoundOnState, roundName, packet)
                        return origOnState(packet, ...)
                    end
                end

                if type(origLeave) == "function" then
                    roundMod.Leave = function(...)
                        if State.Round.Id == roundName then
                            State.Round.Id = nil
                        end
                        return origLeave(...)
                    end
                end

                table.insert(State.Restorers, function()
                    roundMod.Enter = origEnter
                    roundMod.OnState = origOnState
                    roundMod.Leave = origLeave
                    roundMod.__HG_ORIG_ENTER = nil
                    roundMod.__HG_ORIG_ONSTATE = nil
                    roundMod.__HG_HOOKED = nil
                end)
            end
        end
    end
    return true
end

-- ============================================================================
-- CORE LOBBY / MATCH LOOP
-- ============================================================================
local function getCirclePart()
    local model = getActiveInstanceModel()
    if not model then
        return nil
    end
    if model.Name ~= "Models" and model:FindFirstChild("Models") then
        model = model.Models
    end
    local hub = model:FindFirstChild("Hub")
    local circle = hub and hub:FindFirstChild("Circle")
    if circle and circle:IsA("BasePart") then
        return circle
    end
    return nil
end

local function selectBestNight(nightMod, nightSelectMod)
    if not (nightMod and nightSelectMod and type(nightSelectMod.DebugJson) == "function") then
        return
    end
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(nightSelectMod.DebugJson())
    end)
    if not (ok and type(decoded) == "table") then
        return
    end

    if decoded.last ~= "pick" and not decoded.open then
        return
    end

    local unlocked = {}
    for _, n in ipairs(decoded.nights or {}) do
        unlocked[tonumber(n) or 0] = true
    end

    local chosen = nil
    local maxN = math.clamp(Config.MaxNight or 5, 1, 5)

    if Config.NightSelectMode == "Fixed" then
        local fixed = math.clamp(Config.FixedNight or 5, 1, maxN)
        if unlocked[fixed] then
            chosen = fixed
        end
    elseif Config.NightSelectMode == "Recommended" and type(decoded.rows) == "table" then
        for n = maxN, 1, -1 do
            local row = decoded.rows[n] or decoded.rows[tostring(n)]
            if unlocked[n] and row and row.ready == true then
                chosen = n
                break
            end
        end
    end

    if not chosen then
        for n = maxN, 1, -1 do
            if unlocked[n] then
                chosen = n
                break
            end
        end
    end

    if chosen and (os.clock() - State.LastCirclePickAt) > 1.5 then
        State.LastCirclePickAt = os.clock()
        log("Selecting Night " .. tostring(chosen))
        nightMod.Circle("pick", chosen)
        local m = getModules()
        if m and m.TabController and m.TabController.IsOpen("HalloweenGamesNightSelect") then
            pcall(m.TabController.CloseTab)
        end
    end
end

-- ============================================================================
-- AUTO OPEN MIDNIGHT GIFTS & AUTO BOOSTS
-- ============================================================================
local function isDedicatedMatchPlace()
    return game.PlaceId == 93869716229773 or game.PlaceId == 82075097396409
end

local function getMidnightGiftsCount()
    local save = getSaveData()
    local lootboxes = save and save.Inventory and save.Inventory.Lootbox
    if not lootboxes then return 0 end
    local total = 0
    for _, item in pairs(lootboxes) do
        if item.id == "Midnight Gift" then
            total = total + (tonumber(item._am) or 1)
        end
    end
    return total
end

local function syncKnownHugePets()
    local save = getSaveData()
    local pets = save and save.Inventory and save.Inventory.Pet
    if not pets then return end
    for uid, petData in pairs(pets) do
        if petData.id == "Huge Neon Skeleton Dino" then
            State.KnownHugePetUIDs[uid] = true
        end
    end
end

local function checkForNewHugePets()
    local save = getSaveData()
    local pets = save and save.Inventory and save.Inventory.Pet
    if not pets then return end

    for uid, petData in pairs(pets) do
        if petData.id == "Huge Neon Skeleton Dino" and not State.KnownHugePetUIDs[uid] then
            State.KnownHugePetUIDs[uid] = true
            local pt = tonumber(petData.pt) or 0
            local isShiny = (petData.sh == true)
            local variantName = "Regular"
            local prefix = ""
            local assetId = "80322911658458"

            if pt == 1 and isShiny then
                variantName = "Golden Shiny"
                prefix = "Golden Shiny "
                assetId = "81229016133497"
            elseif pt == 2 and isShiny then
                variantName = "Rainbow Shiny"
                prefix = "Rainbow Shiny "
                assetId = "80322911658458"
            elseif pt == 1 then
                variantName = "Golden"
                prefix = "Golden "
                assetId = "81229016133497"
            elseif pt == 2 then
                variantName = "Rainbow"
                prefix = "Rainbow "
                assetId = "80322911658458"
            elseif isShiny then
                variantName = "Shiny"
                prefix = "Shiny "
                assetId = "80322911658458"
            end

            local fullName = prefix .. "Huge Neon Skeleton Dino"
            log("Huge Hatched: " .. fullName .. " (Asset: " .. assetId .. ")")
        end
    end
end

local function openMidnightGifts()
    if not Config.AutoOpenMidnightGifts then
        return false
    end
    if isDedicatedMatchPlace() then
        return false
    end
    local now = os.clock()
    if (now - State.LastGiftOpenAt) < 1.0 then
        return false
    end

    local save = getSaveData()
    local lootboxes = save and save.Inventory and save.Inventory.Lootbox
    if not lootboxes then
        return false
    end

    local network = ReplicatedStorage:FindFirstChild("Network")
    local kxRelease = network and network:FindFirstChild("KX_Release")
    if not (kxRelease and kxRelease:IsA("RemoteFunction")) then
        return false
    end

    for uid, item in pairs(lootboxes) do
        if item.id == "Midnight Gift" then
            local count = tonumber(item._am) or 1
            if count > 0 then
                State.LastGiftOpenAt = now
                local openAmount = math.min(count, 8)
                log("Opening " .. tostring(openAmount) .. " Midnight Gifts (Remaining: " .. tostring(count) .. ")")
                syncKnownHugePets()
                local ok, res1, res2 = pcall(kxRelease.InvokeServer, kxRelease, uid, openAmount, nil)
                log("Gift open result: ok=" .. tostring(ok) .. " res1=" .. tostring(res1) .. " res2=" .. tostring(res2))
                task.wait(0.5)
                checkForNewHugePets()
                return true
            end
        end
    end
    return false
end

local function autoUsePostMatchBoost()
    if not Config.AutoUseTreatBoost then
        return
    end
    local now = os.clock()
    if (now - State.LastTreatBoostAt) < 60.0 then
        return
    end
    local save = getSaveData()
    if not (save and save.Inventory) then return end

    local network = ReplicatedStorage:FindFirstChild("Network")
    local consumeRemote = network and network:FindFirstChild("Consumables_Consume")
    if not (consumeRemote and consumeRemote:IsA("RemoteFunction")) then
        return
    end

    local function scanAndConsume(folder)
        if type(folder) ~= "table" then return false end
        for uid, item in pairs(folder) do
            if item.id == "Halloween Games Treat Boost" and (tonumber(item._am) or 1) > 0 then
                State.LastTreatBoostAt = now
                log("Using Treat Boost post-match")
                task.spawn(function()
                    pcall(consumeRemote.InvokeServer, consumeRemote, uid, 1)
                end)
                return true
            end
        end
        return false
    end

    if not scanAndConsume(save.Inventory.Consumable) then
        scanAndConsume(save.Inventory.Misc)
    end
end

local function closeEliminatedScreenIfOpen(nightMod)
    local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local instGui = pgui and pgui:FindFirstChild("_INSTANCES")
    local elimGui = instGui and instGui:FindFirstChild("HalloweenGamesEliminated")
    if elimGui and elimGui.Enabled then
        elimGui.Enabled = false
        if nightMod and (os.clock() - State.LastExitAt) > 2.0 then
            State.LastExitAt = os.clock()
            pcall(nightMod.MatchExit)
        end
    end
end

-- Handle the multiplayer Queue Lobby place ("Want to Play? Join Here!")
local function stepQueueLobby(hrp)
    local models = workspace:FindFirstChild("Models")
    local padModel = models and models:FindFirstChild("Pad")
    local innerPad = padModel and padModel:FindFirstChild("Pad")
    local netFolder = ReplicatedStorage:FindFirstChild("Network")
    if not (innerPad and netFolder and netFolder:FindFirstChild("RequestRegister")) then
        return false
    end

    -- Do not pull player back if server already started teleporting to match
    local board = models:FindFirstChild("Board")
    local sgui = board and board:FindFirstChild("SurfaceGui")
    local frame = sgui and sgui:FindFirstChild("Frame")
    local timerLabel = frame and frame:FindFirstChild("Timer")
    if timerLabel and (timerLabel.Text == "Teleporting!" or timerLabel.Text == "Closed right now") then
        return true
    end

    local tpHide = models:FindFirstChild("TeleportHide")
    if tpHide and tpHide:IsA("BasePart") and (hrp.Position - tpHide.Position).Magnitude < 25 then
        return true
    end

    if not State.LobbyArrivedAt then
        State.LobbyArrivedAt = os.clock()
        log("Entered Queue Lobby, delaying " .. tostring(Config.LobbyOpenGiftsDelay) .. "s to open gifts")
    end

    -- Open gifts in lobby before registering on pad so teleport does not interrupt opening
    local giftsRemaining = getMidnightGiftsCount()
    if Config.AutoOpenMidnightGifts and giftsRemaining > 0 then
        openMidnightGifts()
    end
    autoUsePostMatchBoost()
    checkForNewHugePets()

    -- Delay before joining pad so gifts have time to open
    local lobbyElapsed = os.clock() - State.LobbyArrivedAt
    if Config.AutoOpenMidnightGifts and giftsRemaining > 0 and lobbyElapsed < Config.LobbyOpenGiftsDelay then
        return true
    end

    local padPos = innerPad:GetPivot().Position
    local safeRadius = math.max((innerPad.Size.X / 2) - 4, 6)
    local flatDist = Vector3.new(hrp.Position.X - padPos.X, 0, hrp.Position.Z - padPos.Z).Magnitude
    local registered = (padModel:GetAttribute("Registered") == true)

    if flatDist > safeRadius or math.abs(hrp.Position.Y - padPos.Y) > 12 or not registered then
        if (os.clock() - State.LastLobbyJoinAt) > 1.5 then
            State.LastLobbyJoinAt = os.clock()
            log("Joining Queue Lobby Pad")
            hrp.CFrame = CFrame.new(padPos + Vector3.new(0, 3.5, 0))
            local reqReg = netFolder:FindFirstChild("RequestRegister")
            if reqReg and reqReg:IsA("RemoteFunction") then
                task.spawn(function()
                    local ok, res = pcall(reqReg.InvokeServer, reqReg)
                    if ok and res == true then
                        padModel:SetAttribute("Registered", true)
                    end
                end)
            end
        end
    end

    return true
end

local function syncRoundFromNightState(activeModel, nState)
    if not (activeModel and nState and nState.roundId) then
        return
    end
    local r = State.Round
    if r.Id ~= nState.roundId or not r.Arena then
        local model = activeModel
        if model.Name ~= "Models" and model:FindFirstChild("Models") then
            model = model.Models
        end
        local slots = model:FindFirstChild("ArenaSlots")
        local slotFolder = slots and slots:FindFirstChild("Slot" .. tostring(nState.slot or 1))
        local arenaName = (nState.config and nState.config.Arena) or nState.roundId
        local arena = slotFolder and slotFolder:FindFirstChild(arenaName)
        if r.Id ~= nState.roundId then
            resetRoundState(nState.roundId, arena, { config = nState.config })
            log("Round active: " .. tostring(nState.roundId))
        else
            r.Arena = arena or r.Arena
            if nState.config and nState.config.t0 then
                r.BroomConfig = nState.config
            end
            if not r.BroomOrigin and r.Arena then
                r.BroomOrigin = r.Arena:GetPivot()
            end
        end
    end
end

local function isOngoingMatchSpectator(nightMod, nightSelectMod)
    if nightSelectMod and type(nightSelectMod.Circle) == "function" then
        local getupval = (debug and debug.getupvalue) or getupvalue
        if type(getupval) == "function" then
            local okU, u55 = pcall(getupval, nightSelectMod.Circle, 1)
            if okU and type(u55) == "table" and u55.phase == "wait" and type(u55.reason) == "string" then
                if string.find(string.lower(u55.reason), "match is on") then
                    return true
                end
            end
        end
    end
    local nState = nightMod and nightMod.State() or {}
    if type(nState.banner) == "string" and string.find(string.lower(nState.banner), "match is on") then
        return true
    end
    local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local hgHud = pgui and pgui:FindFirstChild("HalloweenGamesHud")
    if hgHud then
        for _, desc in ipairs(hgHud:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Visible and string.find(string.lower(desc.Text), "match is on") then
                return true
            end
        end
    end
    return false
end

local function stepMainLoop()
    if not Config.Enabled or not State.Running then
        return
    end

    applyEngineOptimization()
    stepOptimization()

    local _, hrp, hum = getCharacter()
    if not (hrp and hum) then
        return
    end

    -- 1. Check if in Multiplayer Queue Lobby ("Want to Play? Join Here!")
    if stepQueueLobby(hrp) then
        return
    end
    State.LobbyArrivedAt = nil

    -- 2. Check if inside HalloweenGames instance
    local activeModel = getActiveInstanceModel()
    if not activeModel then
        -- Only use World 1 portal when NOT in a dedicated match place
        if Config.AutoEnterInstance and not isDedicatedMatchPlace() and (os.clock() - State.LastPortalEnterAt) > 3.0 then
            local things = workspace:FindFirstChild("__THINGS")
            local instances = things and things:FindFirstChild("Instances")
            local hgPortal = instances and instances:FindFirstChild("HalloweenGames")
            local teleports = hgPortal and hgPortal:FindFirstChild("Teleports")
            local enterPart = teleports and teleports:FindFirstChild("Enter")
            if enterPart and enterPart:IsA("BasePart") then
                State.LastPortalEnterAt = os.clock()
                log("Entering HalloweenGames portal")
                hrp.CFrame = enterPart.CFrame + Vector3.new(0, 3, 0)
            end
        end
        return
    end

    installRoundHooks()

    local m = getModules()
    if not (m and m.Night) then
        return
    end

    local nightMod = m.Night
    local nState = nightMod.State() or {}
    local inActiveNight = (nState.nightId ~= nil and nState.phase ~= "ended")

    if not inActiveNight then
        openMidnightGifts()
        autoUsePostMatchBoost()
        checkForNewHugePets()

        closeEliminatedScreenIfOpen(nightMod)

        -- Recover if character is falling into void while waiting in match server
        if hrp.Position.Y < -200 then
            local circle = getCirclePart()
            if circle then
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.CFrame = CFrame.new(circle.Position + Vector3.new(0, 5, 0))
            end
        end

        if isOngoingMatchSpectator(nightMod, m.NightSelect) then
            if (os.clock() - State.LastExitAt) > 3.0 then
                State.LastExitAt = os.clock()
                log("Ongoing match spectator detected, exiting to Queue Lobby")
                pcall(nightMod.MatchExit)
            end
            return
        end

        if nState.phase == "ended" and (isDedicatedMatchPlace() or nState.match == true) then
            if (os.clock() - State.LastExitAt) > 3.0 then
                State.LastExitAt = os.clock()
                log("Match ended, exiting to Queue Lobby")
                pcall(nightMod.MatchExit)
            end
            return
        end

        -- In the dedicated 20-player Match place, wait for the server to start the match; do not teleport to Hub.Circle
        if isDedicatedMatchPlace() or nState.match == true then
            return
        end

        local circle = getCirclePart()
        if circle then
            local flatDist = Vector3.new(hrp.Position.X - circle.Position.X, 0, hrp.Position.Z - circle.Position.Z).Magnitude
            local maxRadius = math.max(circle.Size.Y, circle.Size.Z) / 2
            if flatDist > maxRadius or math.abs(hrp.Position.Y - circle.Position.Y) > 12 then
                if (os.clock() - State.LastCircleMoveAt) > 1.0 then
                    State.LastCircleMoveAt = os.clock()
                    log("Moving to Hub.Circle")
                    hrp.CFrame = CFrame.new(circle.Position + Vector3.new(0, 3.5, 0))
                end
            else
                selectBestNight(nightMod, m.NightSelect)
            end
        end
        return
    end

    syncRoundFromNightState(activeModel, nState)

    -- Inside an active Night
    if not State.PreMatchGiftsCount then
        State.PreMatchGiftsCount = getMidnightGiftsCount()
        syncKnownHugePets()
    end

    local meContestant = nState.contestants and nState.me and nState.contestants[nState.me]
    local isEliminated = (nState.ghost == true)
        or (nState.out == true)
        or (meContestant ~= nil and meContestant.Alive == false)

    if isEliminated then
        closeEliminatedScreenIfOpen(nightMod)
        if Config.ExitOnEliminated and (os.clock() - State.LastExitAt) > 2.0 then
            State.LastExitAt = os.clock()
            log("Eliminated from match, exiting to lobby")
            pcall(nightMod.MatchExit)
        end
        return
    end

    -- Match victory detection (survived through results / victory screen)
    if (nState.phase == "results" or nState.phase == "ended") and not isEliminated then
        if State.LastReportedNightId ~= nState.nightId then
            State.LastReportedNightId = nState.nightId
            task.spawn(function()
                task.wait(2.0)
                local currentTotal = getMidnightGiftsCount()
                local prev = State.PreMatchGiftsCount or currentTotal
                local giftsWon = math.max(currentTotal - prev, 0)
                if giftsWon == 0 then
                    giftsWon = 1
                end
                local treatsBag = tonumber(nState.bag) or 0
                log("Match victory: Won " .. tostring(giftsWon) .. " gifts (Total: " .. tostring(currentTotal) .. ", Treats: " .. tostring(treatsBag) .. ")")
                State.PreMatchGiftsCount = currentTotal

                if Config.AutoOpenMidnightGifts then
                    task.wait(1.0)
                    openMidnightGifts()
                end
                autoUsePostMatchBoost()
            end)
        end
    end

    -- Optional CashOut (disabled by default to reach Final)
    if Config.AutoCashOut and nState.cashoutOpen == true and (tonumber(nState.bag) or 0) >= Config.CashOutMinTreats then
        log("Cashing out with bag: " .. tostring(nState.bag))
        pcall(nightMod.CashOut)
        return
    end

    -- Trick buffs activation: auto-use any trick the HUD marks as Ready! immediately
    autoUseReadyTricks(nightMod)

    if nState.phase == "play" or nState.phase == "intermission" then

        if Config.AutoUseLuckyCharm and State.LuckyCharmUsedNightId ~= nState.nightId then
            if isTrickArmed("LuckyCharm") then
                State.LuckyCharmUsedNightId = nState.nightId
            elseif hasTrickItem("LuckyCharm") and isTrickReady("LuckyCharm") then
                log("Activating Lucky Charm")
                nightMod.Trick("LuckyCharm")
                State.LuckyCharmUsedNightId = nState.nightId
            end
        end

        if Config.AutoUseTreatMagnet and State.TreatMagnetUsedRoundId ~= (nState.roundId or State.Round.Id) then
            if isTrickArmed("TreatMagnet") then
                State.TreatMagnetUsedRoundId = nState.roundId or State.Round.Id
            elseif hasTrickItem("TreatMagnet") and isTrickReady("TreatMagnet") then
                log("Activating Treat Magnet")
                nightMod.Trick("TreatMagnet")
                State.TreatMagnetUsedRoundId = nState.roundId or State.Round.Id
            end
        end

        if Config.AutoUseBroomstick and State.BroomstickUsedNightId ~= nState.nightId then
            if hasTrickItem("Broomstick") and isTrickReady("Broomstick") then
                log("Activating Broomstick")
                nightMod.Trick("Broomstick")
                State.BroomstickUsedNightId = nState.nightId
            end
        end
    end

    -- Active round execution
    if nState.phase == "play" then

        local roundId = nState.roundId or State.Round.Id
        if roundId == "BroomSweep" then
            stepBroomSweep(nightMod)
        elseif roundId == "HotPumpkin" then
            stepHotPumpkin(nightMod)
        elseif roundId == "LightsOut" then
            stepLightsOut()
        elseif roundId == "BumperPumpkins" then
            stepBumperPumpkins(nightMod)
        elseif roundId == "PumpkinColors" then
            stepPumpkinColors()
        elseif roundId == "TrickOrTreatDoors" then
            stepTrickOrTreatDoors(nightMod)
        elseif roundId == "ScarecrowStare" then
            stepScarecrowStare()
        end
    end
end

-- Bind main Heartbeat dispatcher
table.insert(
    State.Connections,
    RunService.Heartbeat:Connect(function()
        local ok, err = pcall(stepMainLoop)
        if not ok and Config.DebugLog then
            warn("[HalloweenGames] Loop error: " .. tostring(err))
        end
    end)
)

env.__HG_AUTO_CLEANUP = function()
    State.Running = false
    for _, conn in ipairs(State.Connections) do
        pcall(function()
            conn:Disconnect()
        end)
    end
    table.clear(State.Connections)
    for _, restore in ipairs(State.Restorers) do
        pcall(restore)
    end
    table.clear(State.Restorers)
    log("Stopped previous instance")
end

if Config.AutoQueueOnTeleport then
    local qot = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
    if type(qot) == "function" and type(isfile) == "function" and type(readfile) == "function" then
        if isfile("__hg_auto_minigame.lua") then
            pcall(
                qot,
                'repeat task.wait() until game:IsLoaded(); if isfile and isfile("__hg_auto_minigame.lua") then loadstring(readfile("__hg_auto_minigame.lua"))() end'
            )
            log("Registered queue_on_teleport")
        end
    end
end

task.spawn(function()
    task.wait(1.0)
    syncKnownHugePets()
    State.PreMatchGiftsCount = getMidnightGiftsCount()
end)

log("Auto Minigame initialized")
