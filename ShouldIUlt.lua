local ADDON_NAME = "ShouldIUlt"
local ADDON_VERSION = 1

ShouldIUlt = {}

ShouldIUlt.version = "1.0.0"
ShouldIUlt.savedVars = nil
ShouldIUlt.buffData = {}
ShouldIUlt.isInitialized = false
ShouldIUlt.lastScanTime = 0
ShouldIUlt.scanThrottle = 250
ShouldIUlt.lastUltCheck = 0
ShouldIUlt.ultCheckThrottle = 500
-- Default settings
local defaults = {
    version = ADDON_VERSION,
    trackBerserk = true,
    trackCourage = true,
    trackWarhorn = true,
    trackPA = true,
    trackOffBalance = true,
    trackVulnerability = true,

    trackBrittle = true,

    trackSlayer = true,
    trackBrutality = false,
    trackSorcery = false,
    trackProphecy = false,
    trackSavagery = false,
    trackResolve = false,
    trackForce = true,
    trackHeroism = false,
    trackProtection = false,
    trackFortitude = false,
    trackEvasion = false,
    showStacks = false,
    trackBreach = false,
    trackPermanentBuffs = false,

    -- UI settings
    positionX = 720,
    positionY = 420,
    iconSpacing = 5,
    iconSize = 50,
    showTimer = true,
    trackAbyssalInk = true,

    trackWeaponSpellDamage = false,
    trackWeaponSpellCrit = false,
    enableBossScanning = true,
    maxBuffScanLimit = 50,
    scanUpdateRate = 1000,

    -- Simulate
    simulationMode = false,
    simulateAllTracked = false,

    hidePermanentBuffs = false,

    -- Should I Ult settings
    enableUltCheck = false,
    ultCheckMode = "any",
    showUltMessage = true,
    ultMessageSize = 2,
    ultMessageColor = { 1, 1, 0, 1 },
    ultMessageSound = true,
    ultCooldown = 6,

    showTimerBar = true,
    timerBarHeight = 4,
    timerBarColor = { 0, 1, 0, 0.8 },
    timerBarPosition = "bottom",

    ultRequiredBuffs = {
        -- Vulnerability
        trackMajorVulnerability = true,
        trackMinorVulnerability = true,
        trackWarhorn = true,
        -- Slayer
        trackMajorSlayer = true,
        trackMinorSlayer = false,

        -- Berserk
        trackMajorBerserk = true,
        trackMinorBerserk = true,

        -- Force
        trackMajorForce = false,
        trackMinorForce = false,

        -- Damage buffs
        trackMajorBrutality = false,
        trackMinorBrutality = false,
        trackMajorSorcery = false,
        trackMinorSorcery = false,

        -- Crit buffs
        trackMajorProphecy = false,
        trackMinorProphecy = false,
        trackMajorSavagery = false,
        trackMinorSavagery = false,

        -- Other buffs
        trackMajorHeroism = false,
        trackMinorHeroism = false,
        trackMajorBrittle = false,
        trackMinorBrittle = false,
        trackOffBalance = false,
        trackPowerfulAssault = false,
        trackAbyssalInk = false,

        -- Courage
        trackMajorCourage = false,
        trackMinorCourage = false
    },
}

-- Buff database
ShouldIUlt.buffDatabase = {
    -- TARGET DEBUFFS
    bossDebuffs = {
        vulnerability = {
            [106754] = "Major Vulnerability",
            [106755] = "Major Vulnerability",
            [106758] = "Major Vulnerability",
            [106760] = "Major Vulnerability",
            [106762] = "Major Vulnerability",
            [122177] = "Major Vulnerability",
            [163060] = "Major Vulnerability",
            [42062] = "Minor Vulnerability",
            [51434] = "Minor Vulnerability",
            [61782] = "Minor Vulnerability",
            [68359] = "Minor Vulnerability",
            [79715] = "Minor Vulnerability",
            [81519] = "Minor Vulnerability",
        },
        brittle = {
            [145977] = "Major Brittle",
            [167681] = "Major Brittle",
            [145975] = "Minor Brittle"
        },
        breach = {
            [38688] = "Minor Breach",
            [61742] = "Minor Breach",
            [68588] = "Minor Breach",
            [83031] = "Minor Breach",
            [61743] = "Major Breach"
        },
        offBalance = {
            [62988] = "Off-Balance",  -- long wall
            [63108] = "Off-Balance",  -- dodge roll
            [130145] = "Off-Balance", -- mag birb
            [23808] = "Off-Balance",  -- lava whip
            [20806] = "Off-Balance",  -- molten whip
            [34117] = "Off-Balance",  -- flame lash
            [45902] = "Off-Balance",  -- generic off balance
            [120014] = "Off-Balance", -- iron atronach
            [25256] = "Off-Balance",  -- veiled strike
            [34733] = "Off-Balance",  -- surprise attack
            [34737] = "Off-Balance",  -- concealed weapon
            [49205] = "Off-Balance",  -- focused charge
            [49213] = "Off-Balance",  -- explosive charge
            [130129] = "Off-Balance", -- unmorphed birb
            [125750] = "Off-Balance", -- ruinous scythe
            [131562] = "Off-Balance", -- dizzy swing
            [62968] = "Off-Balance",  -- unmorphed wall
            [39077] = "Off-Balance",  -- explosive wall

        }
    },

    --PLAYER BUFFS
    slayer = {
        [93109] = "Major Slayer",
        [93120] = "Major Slayer",
        [93442] = "Major Slayer",
        [121871] = "Major Slayer",
        [137986] = "Major Slayer",
        [76617] = "Minor Slayer",
        [147226] = "Minor Slayer",
        [181840] = "Minor Slayer",
    },
    brutality = {
        [23673] = "Major Brutality",
        [36903] = "Major Brutality",
        [45228] = "Major Brutality",
        [61662] = "Minor Brutality",
        [62060] = "Major Brutality",
        [62147] = "Major Brutality",
        [61798] = "Minor Brutality",
        [61799] = "Minor Brutality",
        [79281] = "Minor Brutality",
        [61665] = "Minor Brutality",
    },

    sorcery = {
        [33317] = "Major Sorcery",
        [45227] = "Major Sorcery",
        [62062] = "Major Sorcery",
        [61687] = "Major Sorcery",
        [62240] = "Major Sorcery",
        [63227] = "Major Sorcery",
        [61685] = "Minor Sorcery",
        [62800] = "Minor Sorcery",
        [62799] = "Minor Sorcery",
        [79221] = "Minor Sorcery",
    },
    prophecy = {
        [61689] = "Major Prophecy",
        [47193] = "Major Prophecy",
        [62747] = "Major Prophecy",
        [61691] = "Minor Prophecy",
        [62319] = "Minor Prophecy",
        [62320] = "Minor Prophecy",
        [79447] = "Minor Prophecy",
    },
    savagery = {
        [61667] = "Major Savagery",
        [45241] = "Major Savagery",
        [45466] = "Major Savagery",
        [61666] = "Minor Savagery",
        [61882] = "Minor Savagery",
        [61898] = "Minor Savagery",
        [79453] = "Minor Savagery",
    },
    berserk = {
        [61744] = "Minor Berserk",
        [62636] = "Minor Berserk",
        [80471] = "Minor Berserk",
        [114862] = "Minor Berserk",
        [36973] = "Major Berserk",
        [61745] = "Major Berserk",
        [62195] = "Major Berserk",
        [84310] = "Major Berserk",
        [134094] = "Major Berserk",
        [134433] = "Major Berserk",
        [137206] = "Major Berserk",
        [143992] = "Major Berserk",
        [147421] = "Major Berserk",
        [150757] = "Major Berserk",
        [172866] = "Major Berserk",
        [188408] = "Major Berserk",
        [219674] = "Major Berserk",
        [221601] = "Major Berserk",
        [237956] = "Major Berserk",
    },
    courage = {
        [121878] = "Minor Courage",
        [137348] = "Minor Courage",
        [147417] = "Minor Courage",
        [159310] = "Minor Courage",
        [109084] = "Minor Courage",
        [109966] = "Major Courage"
    },
    force = {
        [61746] = "Minor Force",
        [68595] = "Minor Force",
        [68628] = "Minor Force",
        [76564] = "Minor Force",
        [46522] = "Major Force",
        [46533] = "Major Force",
        [46536] = "Major Force",
        [46539] = "Major Force"
    },
    warhorn = {
        [40224] = "Aggressive Horn"
    },

    heroism = {
        [61708] = "Minor Heroism",
        [62505] = "Minor Heroism",
        [85593] = "Minor Heroism",
        [113284] = "Minor Heroism",
        [61709] = "Major Heroism"
    },
    protection = {
        [35739] = "Minor Protection",
        [40171] = "Minor Protection",
        [40185] = "Minor Protection",
        [61721] = "Minor Protection",
    },
    fortitude = {
        [26213] = "Minor Fortitude",
        [26220] = "Minor Fortitude",
        [61697] = "Minor Fortitude",
        [124701] = "Minor Fortitude",
    },
    evasion = {
        [61715] = "Minor Evasion",
        [114858] = "Minor Evasion",
        [187865] = "Minor Evasion",
        [184931] = "Minor Evasion",
    },
    resolve = {
        [37247] = "Minor Resolve",
        [61693] = "Minor Resolve",
        [61817] = "Minor Resolve",
        [62626] = "Minor Resolve",
    },
    PowerfulAssault = {
        [61771] = "PowerfulAssault"
    },
    abyssalInk = {
        [183008] = "Abyssal Ink",
    }
}
---=============================================================================
-- Ulti Indicator
--=============================================================================
function ShouldIUlt:CheckUltConditions()
    local currentTime = GetGameTimeMilliseconds()
    -- Throttle ult checks to reduce CPU usage
    if (currentTime - self.lastUltCheck) < self.ultCheckThrottle then
        return self.lastUltResult or false
    end
    self.lastUltCheck = currentTime
    if not ShouldIUlt.savedVars.enableUltCheck then
        self.lastUltResult = false
        return false
    end

    local requiredBuffs = {}

    -- Vulnerability
    if ShouldIUlt.savedVars.ultRequiredBuffs.trackMajorVulnerability then
        requiredBuffs["Major Vulnerability"] = false
    end
    if ShouldIUlt.savedVars.ultRequiredBuffs.trackMinorVulnerability then
        requiredBuffs["Minor Vulnerability"] = false
    end

    -- Slayer
    if ShouldIUlt.savedVars.ultRequiredBuffs.trackMajorSlayer then
        requiredBuffs["Major Slayer"] = false
    end
    if ShouldIUlt.savedVars.ultRequiredBuffs.trackMinorSlayer then
        requiredBuffs["Minor Slayer"] = false
    end

    -- Berserk
    if ShouldIUlt.savedVars.ultRequiredBuffs.trackMajorBerserk then
        requiredBuffs["Major Berserk"] = false
    end
    if ShouldIUlt.savedVars.ultRequiredBuffs.trackMinorBerserk then
        requiredBuffs["Minor Berserk"] = false
    end

    -- Force
    if ShouldIUlt.savedVars.ultRequiredBuffs.trackMajorForce then
        requiredBuffs["Major Force"] = false
    end
    if ShouldIUlt.savedVars.ultRequiredBuffs.trackMinorForce then
        requiredBuffs["Minor Force"] = false
    end

    -- Damage buffs
    if ShouldIUlt.savedVars.ultRequiredBuffs.trackMajorBrutality then
        requiredBuffs["Major Brutality"] = false
    end
    if ShouldIUlt.savedVars.ultRequiredBuffs.trackMinorBrutality then
        requiredBuffs["Minor Brutality"] = false
    end
    if ShouldIUlt.savedVars.ultRequiredBuffs.trackMajorSorcery then
        requiredBuffs["Major Sorcery"] = false
    end
    if ShouldIUlt.savedVars.ultRequiredBuffs.trackMinorSorcery then
        requiredBuffs["Minor Sorcery"] = false
    end

    -- Crit buffs
    if ShouldIUlt.savedVars.ultRequiredBuffs.trackMajorProphecy then
        requiredBuffs["Major Prophecy"] = false
    end
    if ShouldIUlt.savedVars.ultRequiredBuffs.trackMinorProphecy then
        requiredBuffs["Minor Prophecy"] = false
    end
    if ShouldIUlt.savedVars.ultRequiredBuffs.trackMajorSavagery then
        requiredBuffs["Major Savagery"] = false
    end
    if ShouldIUlt.savedVars.ultRequiredBuffs.trackMinorSavagery then
        requiredBuffs["Minor Savagery"] = false
    end

    -- Other buffs
    if ShouldIUlt.savedVars.ultRequiredBuffs.trackMajorHeroism then
        requiredBuffs["Major Heroism"] = false
    end
    if ShouldIUlt.savedVars.ultRequiredBuffs.trackMinorHeroism then
        requiredBuffs["Minor Heroism"] = false
    end
    if ShouldIUlt.savedVars.ultRequiredBuffs.trackMajorBrittle then
        requiredBuffs["Major Brittle"] = false
    end
    if ShouldIUlt.savedVars.ultRequiredBuffs.trackMinorBrittle then
        requiredBuffs["Minor Brittle"] = false
    end
    if ShouldIUlt.savedVars.ultRequiredBuffs.trackOffBalance then
        requiredBuffs["Off-Balance"] = false
    end
    if ShouldIUlt.savedVars.ultRequiredBuffs.trackPowerfulAssault then
        requiredBuffs["PowerfulAssault"] = false
    end
    if ShouldIUlt.savedVars.ultRequiredBuffs.trackAbyssalInk then
        requiredBuffs["Abyssal Ink"] = false
    end

    -- If no buffs are required, don't show ult message
    if next(requiredBuffs) == nil then
        self.lastUltResult = false
        return false
    end

    -- Check player buffs (optimized lookup)
    for abilityId, buffInfo in pairs(self.buffData) do
        local buffName = self:FindBuffNameInDatabase(abilityId)
        if buffName and requiredBuffs[buffName] ~= nil then
            requiredBuffs[buffName] = true
        end
    end

    -- Check boss debuffs
    if self.bossDebuffData then
        for abilityId, debuffInfo in pairs(self.bossDebuffData) do
            local buffName = self:FindBuffNameInDatabase(abilityId)
            if buffName and requiredBuffs[buffName] ~= nil then
                requiredBuffs[buffName] = true
            end
        end
    end

    -- Determine if conditions are met
    local result = false
    if ShouldIUlt.savedVars.ultCheckMode == "all" then
        result = true
        for buffName, isActive in pairs(requiredBuffs) do
            if not isActive then
                result = false
                break
            end
        end
    else
        for buffName, isActive in pairs(requiredBuffs) do
            if isActive then
                result = true
                break
            end
        end
    end
    self.lastUltResult = result
    return result
end

function ShouldIUlt:ShowUltMessage()
    -- Check cooldown
    local currentTime = GetGameTimeMilliseconds()
    if self.lastUltNotification and (currentTime - self.lastUltNotification) < (ShouldIUlt.savedVars.ultCooldown * 1000) then
        return
    end
    self.lastUltNotification = currentTime
    if ShouldIUlt.savedVars.ultMessageSound then
        PlaySound(SOUNDS.SKILL_LINE_LEVELED_UP)
    end
    self:DisplayUltNowMessage()
end

function ShouldIUlt:DisplayUltNowMessage()
    local container = BuffTrackerContainer
    if not container then
        return
    end

    local ultMessage = container:GetNamedChild("UltMessage")
    if not ultMessage then
        for i = 1, container:GetNumChildren() do
            local child = container:GetChild(i)
            if child and child:GetName() then
                local childName = child:GetName()

                if string.find(childName, "UltMessage") then
                    ultMessage = child

                    break
                end
            end
        end
        if not ultMessage then
            return
        end
    end

    local color = ShouldIUlt.savedVars.ultMessageColor or { 1, 0.843, 0, 1 }
    ultMessage:SetColor(color[1], color[2], color[3], color[4])
    ultMessage:SetText("ULT NOW!")
    ultMessage:SetHidden(false)
    ultMessage:SetAlpha(1)
    local scale = ShouldIUlt.savedVars.ultMessageSize or 2
    ultMessage:SetScale(scale)

    zo_callLater(function()
        if ultMessage then
            ultMessage:SetHidden(true)
        end
    end, 6000)
end

function ShouldIUlt:HideUltMessage()
    local container = BuffTrackerContainer
    if not container then return end

    local ultMessage = container:GetNamedChild("UltMessage")
    if ultMessage and not ultMessage:IsHidden() then
        ultMessage:SetHidden(true)
    end
end

---=============================================================================
-- Buffs
--=============================================================================
ShouldIUlt.buffTypeMap = {
    vulnerability = {
        setting = "trackVulnerability",
        major = "Major Vulnerability",
        minor = "Minor Vulnerability"
    },
    slayer = {
        setting = "trackSlayer",
        major = "Major Slayer",
        minor = "Minor Slayer"
    },

    brutality = {
        setting = "trackWeaponSpellDamage",
        major = "Major Brutality",
        minor = "Minor Brutality"
    },
    sorcery = {
        setting = "trackWeaponSpellDamage",
        major = "Major Sorcery",
        minor = "Minor Sorcery"
    },

    prophecy = {
        setting = "trackWeaponSpellCrit",
        major = "Major Prophecy",
        minor = "Minor Prophecy"
    },
    savagery = {
        setting = "trackWeaponSpellCrit",
        major = "Major Savagery",
        minor = "Minor Savagery"
    },

    resolve = {
        setting = "trackResolve",
        major = "Major Resolve",
        minor = "Minor Resolve"
    },
    brittle = {
        setting = "trackBrittle",
        major = "Major Brittle",
        minor = "Minor Brittle"
    },
    offBalance = {
        setting = "trackOffBalance",
        major = nil,
        minor = "Off-Balance"
    },
    force = {
        setting = "trackForce",
        major = "Major Force",
        minor = "Minor Force"
    },
    heroism = {
        setting = "trackHeroism",
        major = "Major Heroism",
        minor = "Minor Heroism"
    },
    protection = {
        setting = "trackProtection",
        major = nil,
        minor = "Minor Protection"
    },
    fortitude = {
        setting = "trackFortitude",
        major = nil,
        minor = "Minor Fortitude"
    },
    evasion = {
        setting = "trackEvasion",
        major = nil,
        minor = "Minor Evasion"
    },
    berserk = {
        setting = "trackBerserk",
        major = "Major Berserk",
        minor = "Minor Berserk"
    },
    courage = {
        setting = "trackCourage",
        major = "Major Courage",
        minor = "Minor Courage"
    },
    breach = {
        setting = "trackBreach",
        major = "Major Breach",
        minor = "Minor Breach"
    },
    PowerfulAssault = {
        setting = "trackPA",
        major = nil,
        minor = "PowerfulAssault"
    },
    -- For testing
    abyssalInk = {
        setting = "trackAbyssalInk",
        major = nil,
        minor = "Abyssal Ink"
    },
    warhorn = {
        setting = "trackWarhorn",
        major = nil,
        minor = "Agressive Horn"
    }
}


function ShouldIUlt:GetBuffIcon(buffName)
    local iconMap = {
        -- Major buffs
        ["Major Vulnerability"] = "/esoui/art/icons/ability_debuff_major_vulnerability.dds",
        ["Major Slayer"] = "/esoui/art/icons/ability_buff_major_slayer.dds",
        ["Major Brutality"] = "/esoui/art/icons/ability_buff_major_brutality.dds",
        ["Major Sorcery"] = "/esoui/art/icons/ability_buff_major_sorcery.dds",
        ["Major Prophecy"] = "/esoui/art/icons/ability_buff_major_prophecy.dds",
        ["Major Savagery"] = "/esoui/art/icons/ability_buff_major_savagery.dds",
        ["Major Resolve"] = "/esoui/art/icons/ability_buff_major_resolve.dds",
        ["Major Ward"] = "/esoui/art/icons/ability_buff_major_ward.dds",
        ["Major Endurance"] = "/esoui/art/icons/ability_buff_major_endurance.dds",
        ["Major Intellect"] = "/esoui/art/icons/ability_buff_major_intellect.dds",
        ["Major Brittle"] = "/esoui/art/icons/ability_debuff_major_brittle.dds",
        ["Major Force"] = "/esoui/art/icons/ability_buff_major_force.dds",
        ["Major Berserk"] = "/esoui/art/icons/ability_buff_major_berserk.dds",
        ["Major Breach"] = "/esoui/art/icons/ability_buff_major_breach.dds",
        ["Off-Balance"] = "/esoui/art/icons/ability_debuff_offbalance.dds",
        ["Off-Balance Immunity"] = "/esoui/art/icons/ability_debuff_offbalance.dds",
        ["Major Courage"] = "/esoui/art/icons/ability_buff_major_courage.dds",
        -- Minor buffs
        ["Minor Vulnerability"] = "/esoui/art/icons/ability_debuff_minor_vulnerability.dds",
        ["Minor Slayer"] = "/esoui/art/icons/ability_buff_minor_slayer.dds",
        ["Minor Brutality"] = "/esoui/art/icons/ability_buff_minor_brutality.dds",
        ["Minor Sorcery"] = "/esoui/art/icons/ability_buff_minor_sorcery.dds",
        ["Minor Prophecy"] = "/esoui/art/icons/ability_buff_minor_prophecy.dds",
        ["Minor Savagery"] = "/esoui/art/icons/ability_buff_minor_savagery.dds",
        ["Minor Resolve"] = "/esoui/art/icons/ability_buff_minor_resolve.dds",

        ["Minor Endurance"] = "/esoui/art/icons/ability_buff_minor_endurance.dds",
        ["Minor Intellect"] = "/esoui/art/icons/ability_buff_minor_intellect.dds",
        ["Minor Brittle"] = "/esoui/art/icons/ability_debuff_minor_brittle.dds",
        ["Minor Aegis"] = "/esoui/art/icons/ability_buff_minor_aegis.dds",
        ["Minor Berserk"] = "/esoui/art/icons/ability_buff_minor_berserk.dds",
        ["Minor Breach"] = "/esoui/art/icons/ability_debuff_minor_breach.dds",
        ["Minor Courage"] = "/esoui/art/icons/ability_buff_minor_courage.dds",
        ["Minor Cowardice"] = "/esoui/art/icons/ability_debuff_minor_cowardice.dds",
        ["Minor Defile"] = "/esoui/art/icons/ability_debuff_minor_defile.dds",
        ["Minor Enervation"] = "/esoui/art/icons/ability_debuff_minor_enervation.dds",
        ["Minor Evasion"] = "/esoui/art/icons/ability_buff_minor_evasion.dds",
        ["Minor Expedition"] = "/esoui/art/icons/ability_buff_minor_expedition.dds",
        ["Minor Force"] = "/esoui/art/icons/ability_buff_minor_force.dds",
        ["Minor Fortitude"] = "/esoui/art/icons/ability_buff_minor_fortitude.dds",
        ["Minor Heroism"] = "/esoui/art/icons/ability_buff_minor_heroism.dds",
        ["Minor Lifesteal"] = "/esoui/art/icons/ability_buff_minor_lifesteal.dds",
        ["Minor Magickasteal"] = "/esoui/art/icons/ability_buff_minor_magickasteal.dds",
        ["Minor Maim"] = "/esoui/art/icons/ability_debuff_minor_maim.dds",
        ["Minor Mangle"] = "/esoui/art/icons/ability_debuff_minor_mangle.dds",
        ["Minor Mending"] = "/esoui/art/icons/ability_buff_minor_mending.dds",
        ["Minor Protection"] = "/esoui/art/icons/ability_buff_minor_protection.dds",
        ["Minor Timidity"] = "/esoui/art/icons/ability_debuff_minor_timidity.dds",
        ["Minor Toughness"] = "/esoui/art/icons/ability_buff_minor_toughness.dds",
        ["Minor Uncertainty"] = "/esoui/art/icons/ability_debuff_minor_uncertainty.dds",
        ["Minor Vitality"] = "/esoui/art/icons/ability_buff_minor_vitality.dds",
        ["PowerfulAssault"] = "/esoui/art/icons/ability_healer_019.dds",
        ["Abyssal Ink"] = "/esoui/art/icons/ability_scribing_grimoire_005.dds",

    }
    -- Fallback
    return iconMap[buffName] or "/esoui/art/icons/ability_weapon_001.dds"
end

function ShouldIUlt:SyncCombinedSettings()
    -- Sync weapon/spell damage buffs
    ShouldIUlt.savedVars.trackBrutality = ShouldIUlt.savedVars.trackWeaponSpellDamage
    ShouldIUlt.savedVars.trackSorcery = ShouldIUlt.savedVars.trackWeaponSpellDamage

    -- Sync weapon/spell crit buffs
    ShouldIUlt.savedVars.trackProphecy = ShouldIUlt.savedVars.trackWeaponSpellCrit
    ShouldIUlt.savedVars.trackSavagery = ShouldIUlt.savedVars.trackWeaponSpellCrit
end

function ShouldIUlt:GetDisplayBuffs()
    if ShouldIUlt.savedVars.simulationMode then
        return self:GetSimulatedBuffs()
    else
        local allBuffs = {}


        for abilityId, buffInfo in pairs(self.buffData) do
            if not (ShouldIUlt.savedVars.hidePermanentBuffs and buffInfo.isPermanent) then
                allBuffs[abilityId] = buffInfo
            end
        end


        if (ShouldIUlt.savedVars.trackAbyssalInk or ShouldIUlt.savedVars.trackBossDebuffs) and self.bossDebuffData then
            for abilityId, debuffInfo in pairs(self.bossDebuffData) do
                if not (ShouldIUlt.savedVars.hidePermanentBuffs and debuffInfo.isPermanent) then
                    allBuffs[abilityId] = debuffInfo
                end
            end
        end

        return allBuffs
    end
end

function ShouldIUlt:GetTrackedBuffs()
    local trackedBuffs = {}

    -- Iterate through the buff type map
    for buffType, data in pairs(self.buffTypeMap) do
        if ShouldIUlt.savedVars[data.setting] then
            -- Search for all IDs that match our target buff names
            for category, categoryData in pairs(self.buffDatabase) do
                if category == "bossDebuffs" then
                    -- Handle nested boss debuffs
                    for subcat, buffs in pairs(categoryData) do
                        for abilityId, name in pairs(buffs) do
                            if (data.major and name == data.major) or (data.minor and name == data.minor) then
                                table.insert(trackedBuffs, abilityId)
                            end
                        end
                    end
                else
                    -- Handle direct categories
                    for abilityId, name in pairs(categoryData) do
                        if type(abilityId) == "number" then
                            if (data.major and name == data.major) or (data.minor and name == data.minor) then
                                table.insert(trackedBuffs, abilityId)
                            end
                        end
                    end
                end
            end
        end
    end

    return trackedBuffs
end

function ShouldIUlt:CreateBuffToggleOption(buffType, displayName, majorIcon, minorIcon)
    local data = self.buffTypeMap[buffType]
    if not data then return nil end

    local tooltip = "\n\n\n\n\n\n\n"

    -- Add major buff info if it exists
    if data.major then
        tooltip = tooltip .. majorIcon .. "|cFFFFFF• " .. data.major .. "|r"
    end

    -- Add minor buff info if it exists
    if data.minor then
        -- Add a newline separator if we already have major buff text
        if tooltip ~= "" then
            tooltip = tooltip .. "\n"
        end
        tooltip = tooltip .. minorIcon .. "|cFFFFFF• " .. data.minor .. "|r"
    end

    return {
        type = "checkbox",
        name = displayName,
        tooltip = tooltip,
        getFunc = function() return ShouldIUlt.savedVars[data.setting] end,
        setFunc = function(value)
            ShouldIUlt.savedVars[data.setting] = value
            ShouldIUlt:ScanCurrentBuffs()
            ShouldIUlt:UpdateUI()
        end,
    }
end

function ShouldIUlt:IsTrackedBuff(abilityId)
    local trackedBuffs = ShouldIUlt:GetTrackedBuffs()
    for _, trackedId in ipairs(trackedBuffs) do
        if trackedId == abilityId then
            return true
        end
    end
    return false
end

function ShouldIUlt:ScanCurrentBuffs()
    self.buffData = {}

    local unitTag = "player"
    local numberOfBuffs = GetNumBuffs(unitTag)

    for i = 0, numberOfBuffs do
        local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff, castByPlayer =
            GetUnitBuffInfo(unitTag, i)

        if buffName and abilityId and ShouldIUlt:IsTrackedBuff(abilityId) then
            local startTimeMs = timeStarted * 1000
            local endTimeMs = timeEnding * 1000
            local durationMs = endTimeMs - startTimeMs

            local isPermanent = false


            if timeStarted == timeEnding then
                isPermanent = true
            elseif durationMs > 3600000 then
                isPermanent = true
            elseif durationMs <= 0 then
                isPermanent = true
            end

            -- Handle permanent buffs
            if isPermanent then
                durationMs = 0
                endTimeMs = 0
            end

            self.buffData[abilityId] = {
                name = buffName,
                iconName = iconFilename,
                endTime = endTimeMs,
                startTime = startTimeMs,
                stackCount = stackCount or 1,
                duration = durationMs,
                slot = buffSlot,
                isPermanent = isPermanent,
                canClickOff = canClickOff,
                castByPlayer = castByPlayer
            }
        end
    end
end

function ShouldIUlt:ScanBossDebuffs()
    local bossDebuffs = {}
    local bossUnitTags = { "boss1", "boss2", "boss3", "boss4", "boss5", "boss6" }

    for _, unitTag in ipairs(bossUnitTags) do
        if DoesUnitExist(unitTag) and IsUnitAttackable(unitTag) then
            local unitName = GetUnitName(unitTag)
            local numberOfBuffs = GetNumBuffs(unitTag)

            for i = 0, numberOfBuffs do
                local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff, castByPlayer =
                    GetUnitBuffInfo(unitTag, i)

                if buffName and abilityId and self:IsTrackedBuff(abilityId) then
                    local startTimeMs = timeStarted * 1000
                    local endTimeMs = timeEnding * 1000
                    local durationMs = endTimeMs - startTimeMs

                    local isPermanent = (timeStarted == timeEnding) or (durationMs <= 0)
                    if isPermanent then
                        durationMs = 0
                        endTimeMs = 0
                    end

                    local isOffBalanceImmunity = (abilityId == 134599)

                    bossDebuffs[abilityId] = {
                        name = buffName,
                        iconName = iconFilename,
                        endTime = endTimeMs,
                        startTime = startTimeMs,
                        stackCount = stackCount or 1,
                        duration = durationMs,
                        slot = buffSlot,
                        bossName = unitName,
                        bossTag = unitTag,
                        isBossDebuff = true,
                        isOffBalanceImmunity = isOffBalanceImmunity,
                        isPermanent = isPermanent,
                        canClickOff = canClickOff,
                        castByPlayer = castByPlayer
                    }
                end
            end
        end
    end

    return bossDebuffs
end

function ShouldIUlt:FindBuffNameInDatabase(abilityId)
    for category, data in pairs(self.buffDatabase) do
        if category == "bossDebuffs" then
            for subcat, buffs in pairs(data) do
                if buffs[abilityId] then
                    return buffs[abilityId]
                end
            end
        else
            if data[abilityId] then
                return data[abilityId]
            end
        end
    end
    return nil
end

function ShouldIUlt:ScanTargetDebuffs()
    local currentTime = GetGameTimeMilliseconds()


    if (currentTime - self.lastScanTime) < self.scanThrottle then
        return
    end
    self.lastScanTime = currentTime

    local targetTag = "reticleover"

    if not DoesUnitExist(targetTag) then
        if self.bossDebuffData then
            for abilityId in pairs(self.bossDebuffData) do
                self.bossDebuffData[abilityId] = nil
            end
        end
        return
    end

    local targetName = GetUnitName(targetTag)

    if not IsUnitAttackable(targetTag) then
        return
    end


    if not self.bossDebuffData then
        self.bossDebuffData = {}
    end


    local trackedBuffIds = {}
    for _, buffId in ipairs(self:GetTrackedBuffs()) do
        trackedBuffIds[buffId] = true
    end


    local existingDebuffs = {}
    for abilityId in pairs(self.bossDebuffData) do
        existingDebuffs[abilityId] = true
    end

    local numberOfBuffs = GetNumBuffs(targetTag)


    local maxBuffsToCheck = math.min(numberOfBuffs, 50)

    for i = 0, maxBuffsToCheck do
        local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff, castByPlayer =
            GetUnitBuffInfo(targetTag, i)


        if buffName and abilityId and trackedBuffIds[abilityId] then
            existingDebuffs[abilityId] = nil

            local startTimeMs = timeStarted * 1000
            local endTimeMs = timeEnding * 1000
            local durationMs = endTimeMs - startTimeMs

            local isPermanent = (timeStarted == timeEnding) or (durationMs <= 0)
            if isPermanent then
                durationMs = 0
                endTimeMs = 0
            end

            local isOffBalanceImmunity = (abilityId == 134599)

            self.bossDebuffData[abilityId] = {
                name = buffName,
                iconName = iconFilename,
                endTime = endTimeMs,
                startTime = startTimeMs,
                stackCount = stackCount or 1,
                duration = durationMs,
                slot = buffSlot,
                unitTag = targetTag,
                bossName = targetName,
                isBossDebuff = true,
                isOffBalanceImmunity = isOffBalanceImmunity,
                isPermanent = isPermanent
            }
        end
    end

    -- Remove debuffs that are no longer present
    for abilityId in pairs(existingDebuffs) do
        self.bossDebuffData[abilityId] = nil
    end
end

---=============================================================================
-- UI
--=============================================================================
function ShouldIUlt:ShowTestIcon()
    local container = BuffTrackerContainer
    if container then
        local buffIcon = container:GetNamedChild("BuffIcon1")
        if buffIcon then
            local iconControl = buffIcon:GetNamedChild("Icon")
            if iconControl then
                -- default ESO icon
                iconControl:SetTexture("/esoui/art/icons/ability_weapon_001.dds")
                buffIcon:SetHidden(false)
            end
        end
    end
end

function ShouldIUlt:UpdateUIPosition()
    local container = BuffTrackerContainer
    if container then
        local maxX = math.floor(GuiRoot:GetWidth() / 2)
        local maxY = math.floor(GuiRoot:GetHeight() / 2)

        local clampedX = math.max(-maxX, math.min(maxX, ShouldIUlt.savedVars.positionX))
        local clampedY = math.max(-maxY, math.min(maxY, ShouldIUlt.savedVars.positionY))


        if clampedX ~= ShouldIUlt.savedVars.positionX then
            ShouldIUlt.savedVars.positionX = clampedX
        end
        if clampedY ~= ShouldIUlt.savedVars.positionY then
            ShouldIUlt.savedVars.positionY = clampedY
        end

        container:ClearAnchors()
        container:SetAnchor(CENTER, GuiRoot, CENTER, clampedX, clampedY)
    end
end

function ShouldIUlt:UpdateUI()
    local container = BuffTrackerContainer
    if not container then
        return
    end

    local iconSize = ShouldIUlt.savedVars.iconSize
    local spacing = ShouldIUlt.savedVars.iconSpacing or 5
    local adjustedSpacing = math.max(1, math.floor(iconSize * 0.1))


    for i = 1, 14 do
        local buffIcon = container:GetNamedChild("BuffIcon" .. i)
        if buffIcon then
            buffIcon:SetHidden(true)
            buffIcon:SetDimensions(iconSize, iconSize)


            local row = math.floor((i - 1) / 7)
            local col = (i - 1) % 7
            local x = col * (iconSize + adjustedSpacing)
            local y = row * (iconSize + adjustedSpacing)

            buffIcon:ClearAnchors()
            buffIcon:SetAnchor(TOPLEFT, container, TOPLEFT, x, y)
        end
    end
    local cols = 7
    local rows = math.ceil(14 / cols)
    local containerWidth = (cols * iconSize) + ((cols - 1) * adjustedSpacing)
    local containerHeight = (rows * iconSize) + ((rows - 1) * adjustedSpacing)
    container:SetDimensions(containerWidth, containerHeight)

    -- Get buffs to display
    local displayBuffs = self:GetDisplayBuffs()

    -- Show active buffs
    local index = 1
    for abilityId, buffInfo in pairs(displayBuffs) do
        local buffIcon = container:GetNamedChild("BuffIcon" .. index)
        if buffIcon then
            local iconControl = buffIcon:GetNamedChild("Icon")
            local timerLabel = buffIcon:GetNamedChild("Timer")
            local stackLabel = buffIcon:GetNamedChild("Stack")

            local timerBar = buffIcon:GetNamedChild("TimerBar")
            local timerBarBG = buffIcon:GetNamedChild("TimerBarBG")

            if iconControl and buffInfo.iconName then
                iconControl:SetTexture(buffInfo.iconName)
                buffIcon:SetHidden(false)


                if buffInfo.isOffBalanceImmunity then
                    iconControl:SetColor(1, 0.02, 0, 1)
                elseif buffInfo.name == "Off-Balance" then
                    iconControl:SetColor(0, 0.7, 0.5, 1)
                else
                    iconControl:SetColor(1, 1, 1, 1)
                end

                if ShouldIUlt.savedVars.showTimerBar and timerBar and timerBarBG then
                    self:PositionTimerBar(timerBar, timerBarBG, buffIcon)
                    self:UpdateTimerBar(timerBar, timerBarBG, buffInfo)
                else
                    if timerBar then timerBar:SetHidden(true) end
                    if timerBarBG then timerBarBG:SetHidden(true) end
                end


                if timerLabel and ShouldIUlt.savedVars.showTimer then
                    if buffInfo.isPermanent then
                        timerLabel:SetText("")
                    else
                        local remainingTime = buffInfo.endTime - GetGameTimeMilliseconds()
                        if remainingTime > 0 then
                            if remainingTime > 60000 then
                                timerLabel:SetText(string.format("%.1fm", remainingTime / 60000))
                            else
                                timerLabel:SetText(string.format("%.1f", remainingTime / 1000))
                            end
                        else
                            timerLabel:SetText("")
                        end
                    end
                    timerLabel:SetHidden(false)
                else
                    if timerLabel then timerLabel:SetHidden(true) end
                end



                -- Stack count display
                if stackLabel and ShouldIUlt.savedVars.showStacks and buffInfo.stackCount > 1 then
                    stackLabel:SetText(tostring(buffInfo.stackCount))
                    stackLabel:SetHidden(false)
                else
                    if stackLabel then stackLabel:SetHidden(true) end
                end

                index = index + 1
                if index > 14 then break end
            end
        end
    end

    if self:CheckUltConditions() then
        self:ShowUltMessage()
    end
end

function ShouldIUlt:PositionTimerBar(timerBar, timerBarBG, parentIcon)
    local iconSize = ShouldIUlt.savedVars.iconSize
    local barHeight = ShouldIUlt.savedVars.timerBarHeight or 4
    local barWidth = iconSize - 8

    -- Clear existing anchors
    timerBar:ClearAnchors()
    timerBarBG:ClearAnchors()

    -- Set dimensions
    timerBar:SetDimensions(barWidth, barHeight)
    timerBarBG:SetDimensions(barWidth, barHeight)

    local position = ShouldIUlt.savedVars.timerBarPosition or "bottom"

    if position == "bottom" then
        timerBarBG:SetAnchor(BOTTOM, parentIcon, BOTTOM, 0, -2)
        timerBar:SetAnchor(BOTTOM, parentIcon, BOTTOM, 0, -2)
    elseif position == "top" then
        timerBarBG:SetAnchor(TOP, parentIcon, TOP, 0, 2)
        timerBar:SetAnchor(TOP, parentIcon, TOP, 0, 2)
    elseif position == "left" then
        timerBar:SetDimensions(barHeight, barWidth)
        timerBarBG:SetDimensions(barHeight, barWidth)
        timerBarBG:SetAnchor(LEFT, parentIcon, LEFT, 2, 0)
        timerBar:SetAnchor(LEFT, parentIcon, LEFT, 2, 0)
    elseif position == "right" then
        timerBar:SetDimensions(barHeight, barWidth)
        timerBarBG:SetDimensions(barHeight, barWidth)
        timerBarBG:SetAnchor(RIGHT, parentIcon, RIGHT, -2, 0)
        timerBar:SetAnchor(RIGHT, parentIcon, RIGHT, -2, 0)
    end
end

function ShouldIUlt:UpdateTimerBar(timerBar, timerBarBG, buffInfo)
    if buffInfo.isPermanent then
        timerBar:SetHidden(true)
        timerBarBG:SetHidden(true)
        return
    end

    local currentTime = GetGameTimeMilliseconds()
    local remainingTime = buffInfo.endTime - currentTime
    local totalDuration = buffInfo.duration

    if remainingTime <= 0 or totalDuration <= 0 then
        timerBar:SetHidden(true)
        timerBarBG:SetHidden(true)
        return
    end

    timerBar:SetHidden(false)
    timerBarBG:SetHidden(false)

    local percentage = remainingTime / totalDuration
    if percentage > 1 then percentage = 1 end
    if percentage < 0 then percentage = 0 end

    local color = self:GetTimerBarColor(percentage)
    timerBar:SetColor(color.r, color.g, color.b, color.a)

    local position = ShouldIUlt.savedVars.timerBarPosition or "bottom"
    local iconSize = ShouldIUlt.savedVars.iconSize
    local barHeight = ShouldIUlt.savedVars.timerBarHeight or 4

    if position == "bottom" or position == "top" then
        local maxWidth = math.max(10, iconSize - 8)
        local currentWidth = math.max(1, maxWidth * percentage)
        timerBar:SetDimensions(currentWidth, barHeight)
    else
        local maxHeight = math.max(10, iconSize - 8)
        local currentHeight = math.max(1, maxHeight * percentage)
        timerBar:SetDimensions(barHeight, currentHeight)
    end
end

function ShouldIUlt:OnBossEffectChanged(changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount,
                                        iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId,
                                        abilityId,
                                        sourceType)
    if not self:IsTrackedBuff(abilityId) then
        return
    end

    if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
        if not self.bossDebuffData then
            self.bossDebuffData = {}
        end

        local startTimeMs = beginTime * 1000
        local endTimeMs = endTime * 1000
        local durationMs = endTimeMs - startTimeMs

        local isPermanent = (beginTime == endTime) or (durationMs <= 0) or (durationMs > 3600000)
        if isPermanent then
            durationMs = 0
            endTimeMs = 0
        end

        local bossName = GetUnitName(unitTag)
        local isOffBalanceImmunity = (abilityId == 134599)

        self.bossDebuffData[abilityId] = {
            name = effectName,
            iconName = iconName,
            endTime = endTimeMs,
            startTime = startTimeMs,
            stackCount = stackCount or 1,
            duration = durationMs,
            slot = effectSlot,
            unitTag = unitTag,
            bossName = bossName,
            isBossDebuff = true,
            isOffBalanceImmunity = isOffBalanceImmunity,
            isPermanent = isPermanent
        }

        self:UpdateUI()
    elseif changeType == EFFECT_RESULT_FADED then
        if self.bossDebuffData then
            self.bossDebuffData[abilityId] = nil
        end
        self:UpdateUI()
    end
end

function ShouldIUlt:Cleanup()
    -- Unregister all update events to prevent memory leaks
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "TimerUpdate")

    if self.abyssalInkMonitor then
        EVENT_MANAGER:UnregisterForUpdate("AbyssalInkMonitor")
        self.abyssalInkMonitor = false
    end

    -- Clear data
    self.buffData = {}
    if self.bossDebuffData then
        self.bossDebuffData = {}
    end
end

function ShouldIUlt:OnTargetChanged()
    if not ShouldIUlt.savedVars.enableBossScanning then
        return
    end

    if self.targetChangeTimer then
        zo_callLater(function() end, 0)
    end

    self.targetChangeTimer = zo_callLater(function()
        self.targetChangeTimer = nil

        if ShouldIUlt.savedVars.trackBossDebuffs or ShouldIUlt.savedVars.trackAbyssalInk then
            ShouldIUlt:ScanTargetDebuffs()
        end
    end, 200)
end

function ShouldIUlt:StartTimerUpdates()
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "TimerUpdate", 100, function()
        if ShouldIUlt.savedVars.showTimerBar or ShouldIUlt.savedVars.showTimer then
            ShouldIUlt:UpdateTimersOnly()
        end

        if ShouldIUlt:CheckUltConditions() then
            ShouldIUlt:ShowUltMessage()
        end
    end)
end

ShouldIUlt.buffNameCache = {}


ShouldIUlt.trackedBuffsCache = nil
ShouldIUlt.lastSettingsHash = nil


function ShouldIUlt:UpdateTimersOnly()
    local container = BuffTrackerContainer
    if not container then return end

    local displayBuffs = self:GetDisplayBuffs()
    local index = 1

    for abilityId, buffInfo in pairs(displayBuffs) do
        local buffIcon = container:GetNamedChild("BuffIcon" .. index)
        if buffIcon and not buffIcon:IsHidden() then
            local timerLabel = buffIcon:GetNamedChild("Timer")
            local timerBar = buffIcon:GetNamedChild("TimerBar")
            local timerBarBG = buffIcon:GetNamedChild("TimerBarBG")

            -- Only update timer text
            if timerLabel and ShouldIUlt.savedVars.showTimer then
                if buffInfo.isPermanent then
                    timerLabel:SetText("")
                else
                    local remainingTime = buffInfo.endTime - GetGameTimeMilliseconds()
                    if remainingTime > 0 then
                        if remainingTime > 60000 then
                            timerLabel:SetText(string.format("%.1fm", remainingTime / 60000))
                        else
                            timerLabel:SetText(string.format("%.1f", remainingTime / 1000))
                        end
                    else
                        timerLabel:SetText("")
                    end
                end
            end

            -- Only update timer bar
            if timerBar and timerBarBG and ShouldIUlt.savedVars.showTimerBar then
                self:UpdateTimerBar(timerBar, timerBarBG, buffInfo)
            end

            index = index + 1
            if index > 14 then break end
        end
    end
end

-- Get color for timer bar based on percentage remaining
function ShouldIUlt:GetTimerBarColor(percentage)
    -- Color transitions: Green -> Yellow -> Red
    if percentage > 0.5 then
        -- Green to Yellow (100% to 50%)
        local factor = (percentage - 0.5) * 2 -- 0 to 1
        return {
            r = 1 - factor,
            g = 1,
            b = 0,
            a = 0.8
        }
    else
        -- Yellow to Red (50% to 0%)
        local factor = percentage * 2
        return {
            r = 1,
            g = factor,
            b = 0,
            a = 0.8
        }
    end
end

function ShouldIUlt:OnUpdate()
    ShouldIUlt:UpdateUI()
end

---=============================================================================
-- Settings
--=============================================================================
function ShouldIUlt:CreateCombinedBuffToggleOption(settingName, displayName, description, majorBuffs, minorBuffs)
    local tooltip = "\n\n\n\n" .. description .. "\n"

    -- Add major buffs to tooltip with icons
    if majorBuffs and #majorBuffs > 0 then
        tooltip = tooltip .. "\n|cFFD700Major:|r"
        for _, buffName in ipairs(majorBuffs) do
            local iconPath = self:GetBuffIcon(buffName)
            local iconTag = string.format("|t48:48:%s|t", iconPath)
            tooltip = tooltip .. "\n" .. iconTag .. "|cFFFFFF• " .. buffName .. "|r"
        end
    end

    -- Add minor buffs to tooltip with icons
    if minorBuffs and #minorBuffs > 0 then
        tooltip = tooltip .. "\n|c87CEEBMinor:|r"
        for _, buffName in ipairs(minorBuffs) do
            local iconPath = self:GetBuffIcon(buffName)
            local iconTag = string.format("|t48:48:%s|t", iconPath)
            tooltip = tooltip .. "\n" .. iconTag .. "|cFFFFFF• " .. buffName .. "|r"
        end
    end

    -- Add bottom spacing for balance
    tooltip = tooltip .. "\n\n\n\n"

    return {
        type = "checkbox",
        name = displayName,
        tooltip = tooltip,
        getFunc = function() return ShouldIUlt.savedVars[settingName] end,
        setFunc = function(value)
            ShouldIUlt.savedVars[settingName] = value
            ShouldIUlt:SyncCombinedSettings()
            ShouldIUlt:ScanCurrentBuffs()
            ShouldIUlt:UpdateUI()
        end,
    }
end

function ShouldIUlt:CreateSettingsMenu()
    local LAM = LibAddonMenu2
    if not LAM then
        return
    end

    local panelData = {
        type = "panel",
        name = "Buff Tracker",
        displayName = "Buff Tracker",
        author = "YFNatey",
        version = ShouldIUlt.version,
        slashCommand = "/shouldiult",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsData = {
        {
            type = "header",
            name = "Buff Tracking",
        },
        {
            type = "checkbox",
            name = "Hide Permanent Buffs",
            getFunc = function() return ShouldIUlt.savedVars.hidePermanentBuffs end,
            setFunc = function(value)
                ShouldIUlt.savedVars.hidePermanentBuffs = value
                ShouldIUlt:UpdateUI()
            end,
        },
        {
            type = "description",
            text = "|cFF6B6BEnemy Debuffs|r",
        },
        ShouldIUlt:CreateBuffToggleOption("vulnerability", "Vulnerability",
            "|t48:48:/esoui/art/icons/ability_debuff_major_vulnerability.dds|t",
            "|t48:48:/esoui/art/icons/ability_debuff_minor_vulnerability.dds|t"),

        ShouldIUlt:CreateBuffToggleOption("offBalance", "Off-Balance",
            "|t48:48:/esoui/art/icons/ability_debuff_offbalance.dds|t",
            "|t48:48:/esoui/art/icons/ability_debuff_offbalance.dds|t"), -- Same icon for both

        ShouldIUlt:CreateBuffToggleOption("brittle", "Brittle",
            "|t48:48:/esoui/art/icons/ability_debuff_major_brittle.dds|t",
            "|t48:48:/esoui/art/icons/ability_debuff_minor_brittle.dds|t"),

        {
            type = "description",
            text = "|cFFD700Player Damage Buffs|r",
        },

        ShouldIUlt:CreateBuffToggleOption("slayer", "Slayer",
            "|t48:48:/esoui/art/icons/ability_buff_major_slayer.dds|t",
            "|t48:48:/esoui/art/icons/ability_buff_minor_slayer.dds|t"),

        ShouldIUlt:CreateBuffToggleOption("berserk", "Berserk",
            "|t48:48:/esoui/art/icons/ability_buff_major_berserk.dds|t",
            "|t48:48:/esoui/art/icons/ability_buff_minor_berserk.dds|t"),

        ShouldIUlt:CreateBuffToggleOption("force", "Force",
            "|t48:48:/esoui/art/icons/ability_buff_major_force.dds|t",
            "|t48:48:/esoui/art/icons/ability_buff_minor_force.dds|t"),

        ShouldIUlt:CreateBuffToggleOption("PowerfulAssault", "Powerful Assault",
            "|t48:48:/esoui/art/icons/ability_healer_019.dds|t",
            "|t48:48:/esoui/art/icons/ability_healer_019.dds|t"),

        ShouldIUlt:CreateBuffToggleOption("courage", "Courage",
            "|t48:48:/esoui/art/icons/ability_buff_major_courage.dds|t",
            "|t48:48:/esoui/art/icons/ability_buff_minor_courage.dds|t"),

        ShouldIUlt:CreateCombinedBuffToggleOption("trackWeaponSpellDamage", "Weapon & Spell Damage",
            "",
            { "Major Brutality", "Major Sorcery" },
            { "Minor Brutality", "Minor Sorcery" }),

        ShouldIUlt:CreateCombinedBuffToggleOption("trackWeaponSpellCrit", "Weapon & Spell Critical",
            "",
            { "Major Savagery", "Major Prophecy" },
            { "Minor Savagery", "Minor Prophecy" }),

        {
            type = "description",
            text = "|cDDA0DDOther Buffs|r",
        },

        ShouldIUlt:CreateBuffToggleOption("heroism", "Heroism",
            "|t48:48:/esoui/art/icons/ability_buff_major_heroism.dds|t",
            "|t48:48:/esoui/art/icons/ability_buff_minor_heroism.dds|t"),

        ShouldIUlt:CreateBuffToggleOption("resolve", "Resolve",
            "|t48:48:/esoui/art/icons/ability_buff_major_resolve.dds|t",
            "|t48:48:/esoui/art/icons/ability_buff_minor_resolve.dds|t"),

        ShouldIUlt:CreateBuffToggleOption("protection", "Protection",
            "",
            "|t48:48:/esoui/art/icons/ability_buff_minor_protection.dds|t")
        ,

        {
            type = "button",
            name = "Debug: List Current Buffs",
            func = function() ShouldIUlt:DebugListBuffs() end,
            width = "half",
        },
        {
            type = "header",
            name = "Display Settings",
        },
        {
            type = "checkbox",
            name = "Test Display",
            tooltip = "Show simulated buffs instead of real ones (for testing UI layout)",
            getFunc = function() return ShouldIUlt.savedVars.simulationMode end,
            setFunc = function(value)
                ShouldIUlt.savedVars.simulationMode = value
                ShouldIUlt:ScanCurrentBuffs()
                ShouldIUlt:UpdateUI()
            end,
        },
        {
            type = "slider",
            name = "Horizontal Position",
            min = -1960,
            max = 1960,
            step = 10,
            getFunc = function() return ShouldIUlt.savedVars.positionX end,
            setFunc = function(value)
                ShouldIUlt.savedVars.positionX = value
                ShouldIUlt:UpdateUIPosition()
            end,
            width = "half",
        },
        {
            type = "slider",
            name = "Vertical Position",
            min = -1540,
            max = 1540,
            step = 10,
            getFunc = function() return ShouldIUlt.savedVars.positionY end,
            setFunc = function(value)
                ShouldIUlt.savedVars.positionY = value
                ShouldIUlt:UpdateUIPosition()
            end,
            width = "half",
        },
        {
            type = "slider",
            name = "Icon Size",

            min = 30,
            max = 60,
            step = 10,
            getFunc = function() return ShouldIUlt.savedVars.iconSize end,
            setFunc = function(value)
                ShouldIUlt.savedVars.iconSize = value
                ShouldIUlt:UpdateUI()
            end,
            width = "half",
        },
        {
            type = "checkbox",
            name = "Show Timer",
            getFunc = function() return ShouldIUlt.savedVars.showTimer end,
            setFunc = function(value)
                ShouldIUlt.savedVars.showTimer = value
                ShouldIUlt:UpdateUI()
            end,
        },
        {
            type = "header",
            name = "Should I Ult? (Experimental)",
        },
        {
            type = "checkbox",
            name = "Enable Ult Check",
            tooltip = "Enable the 'Should I Ult' feature that shows ULT NOW when your conditions are met",
            getFunc = function() return ShouldIUlt.savedVars.enableUltCheck end,
            setFunc = function(value)
                ShouldIUlt.savedVars.enableUltCheck = value
                ShouldIUlt:UpdateUI()
            end,
        },
        {
            type = "dropdown",
            name = "Ult Check Mode",
            tooltip =
            "ANY = Show ult message when any required buff is active\nALL = Show ult message only when ALL required buffs are active",
            choices = { "Any Required Buff", "All Required Buffs" },
            choicesValues = { "any", "all" },
            getFunc = function()
                return ShouldIUlt.savedVars.ultCheckMode == "any" and "Any Required Buff" or "All Required Buffs"
            end,
            setFunc = function(value)
                ShouldIUlt.savedVars.ultCheckMode = (value == "Any Required Buff") and "any" or "all"
            end,
            disabled = function() return not ShouldIUlt.savedVars.enableUltCheck end,
        },
        {
            type = "slider",
            name = "Message Size",
            tooltip = "Size of the ULT NOW message",
            min = 1,
            max = 4,
            step = 0.5,
            getFunc = function() return ShouldIUlt.savedVars.ultMessageSize end,
            setFunc = function(value)
                ShouldIUlt.savedVars.ultMessageSize = value
            end,
            disabled = function() return not ShouldIUlt.savedVars.enableUltCheck end,
        },

        {
            type = "checkbox",
            name = "Play Sound",
            tooltip = "Play a sound when ult conditions are met",
            getFunc = function() return ShouldIUlt.savedVars.ultMessageSound end,
            setFunc = function(value)
                ShouldIUlt.savedVars.ultMessageSound = value
            end,
            disabled = function() return not ShouldIUlt.savedVars.enableUltCheck end,
        },
        {
            type = "header",
            name = "Ult Required Buffs",
        },

        -- DAMAGE DEBUFFS SECTION
        {
            type = "description",
            text = "|cFF6B6BEnemy Debuffs|r",
        },
        {
            type = "checkbox",
            name = "Major Vulnerability",
            getFunc = function() return ShouldIUlt.savedVars.ultRequiredBuffs.trackMajorVulnerability end,
            setFunc = function(value)
                ShouldIUlt.savedVars.ultRequiredBuffs.trackMajorVulnerability = value
            end,
            disabled = function() return not ShouldIUlt.savedVars.enableUltCheck end,
        },
        {
            type = "checkbox",
            name = "Minor Vulnerability",
            getFunc = function() return ShouldIUlt.savedVars.ultRequiredBuffs.trackMinorVulnerability end,
            setFunc = function(value)
                ShouldIUlt.savedVars.ultRequiredBuffs.trackMinorVulnerability = value
            end,
            disabled = function() return not ShouldIUlt.savedVars.enableUltCheck end,
        },
        {
            type = "checkbox",
            name = "Minor Brittle",
            getFunc = function() return ShouldIUlt.savedVars.ultRequiredBuffs.trackMinorBrittle end,
            setFunc = function(value)
                ShouldIUlt.savedVars.ultRequiredBuffs.trackMinorBrittle = value
            end,
            disabled = function() return not ShouldIUlt.savedVars.enableUltCheck end,
        },
        {
            type = "checkbox",
            name = "Off-Balance",
            getFunc = function() return ShouldIUlt.savedVars.ultRequiredBuffs.trackOffBalance end,
            setFunc = function(value)
                ShouldIUlt.savedVars.ultRequiredBuffs.trackOffBalance = value
            end,
            disabled = function() return not ShouldIUlt.savedVars.enableUltCheck end,
        },

        -- PLAYER DAMAGE BUFFS SECTION
        {
            type = "description",
            text = "|cFFD700Player Damage Buffs|r",
        },
        {
            type = "checkbox",
            name = "Major Slayer",
            getFunc = function() return ShouldIUlt.savedVars.ultRequiredBuffs.trackMajorSlayer end,
            setFunc = function(value)
                ShouldIUlt.savedVars.ultRequiredBuffs.trackMajorSlayer = value
            end,
            disabled = function() return not ShouldIUlt.savedVars.enableUltCheck end,
        },
        {
            type = "checkbox",
            name = "Minor Slayer",
            getFunc = function() return ShouldIUlt.savedVars.ultRequiredBuffs.trackMinorSlayer end,
            setFunc = function(value)
                ShouldIUlt.savedVars.ultRequiredBuffs.trackMinorSlayer = value
            end,
            disabled = function() return not ShouldIUlt.savedVars.enableUltCheck end,
        },
        {
            type = "checkbox",
            name = "Major Berserk",
            getFunc = function() return ShouldIUlt.savedVars.ultRequiredBuffs.trackMajorBerserk end,
            setFunc = function(value)
                ShouldIUlt.savedVars.ultRequiredBuffs.trackMajorBerserk = value
            end,
            disabled = function() return not ShouldIUlt.savedVars.enableUltCheck end,
        },
        {
            type = "checkbox",
            name = "Minor Berserk",
            getFunc = function() return ShouldIUlt.savedVars.ultRequiredBuffs.trackMinorBerserk end,
            setFunc = function(value)
                ShouldIUlt.savedVars.ultRequiredBuffs.trackMinorBerserk = value
            end,
            disabled = function() return not ShouldIUlt.savedVars.enableUltCheck end,
        },
        {
            type = "checkbox",
            name = "Major Force",
            getFunc = function() return ShouldIUlt.savedVars.ultRequiredBuffs.trackMajorForce end,
            setFunc = function(value)
                ShouldIUlt.savedVars.ultRequiredBuffs.trackMajorForce = value
            end,
            disabled = function() return not ShouldIUlt.savedVars.enableUltCheck end,
        },
        {
            type = "checkbox",
            name = "Minor Force",
            getFunc = function() return ShouldIUlt.savedVars.ultRequiredBuffs.trackMinorForce end,
            setFunc = function(value)
                ShouldIUlt.savedVars.ultRequiredBuffs.trackMinorForce = value
            end,
            disabled = function() return not ShouldIUlt.savedVars.enableUltCheck end,
        },
        {
            type = "checkbox",
            name = "Powerful Assault",
            getFunc = function() return ShouldIUlt.savedVars.ultRequiredBuffs.trackPowerfulAssault end,
            setFunc = function(value)
                ShouldIUlt.savedVars.ultRequiredBuffs.trackPowerfulAssault = value
            end,
            disabled = function() return not ShouldIUlt.savedVars.enableUltCheck end,
        },

    }
    LAM:RegisterAddonPanel("ShouldIUltPanel", panelData)
    LAM:RegisterOptionControls("ShouldIUltPanel", optionsData)
end

function ShouldIUlt:CreateBuffLegendTooltip()
    local legendText = "BUFF LEGEND\n\n"

    -- Major Buffs Column
    legendText = legendText .. "|cFFFFFF=== MAJOR BUFFS ===|r\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_debuff_major_vulnerability.dds|t Major Vulnerability\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_buff_major_slayer.dds|t Major Slayer\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_buff_major_brutality.dds|t Major Brutality\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_buff_major_sorcery.dds|t Major Sorcery\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_buff_major_prophecy.dds|t Major Prophecy\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_buff_major_savagery.dds|t Major Savagery\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_buff_major_resolve.dds|t Major Resolve\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_debuff_major_brittle.dds|t Major Brittle\n"

    -- ADD: New Major buffs to the legend
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_buff_major_force.dds|t Major Force\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_buff_major_berserk.dds|t Major Berserk\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_buff_major_heroism.dds|t Major Heroism\n"

    legendText = legendText .. "\n|cFFFFFF=== MINOR BUFFS ===|r\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_debuff_minor_vulnerability.dds|t Minor Vulnerability\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_buff_minor_slayer.dds|t Minor Slayer\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_buff_minor_brutality.dds|t Minor Brutality\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_buff_minor_sorcery.dds|t Minor Sorcery\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_buff_minor_prophecy.dds|t Minor Prophecy\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_buff_minor_savagery.dds|t Minor Savagery\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_buff_minor_resolve.dds|t Minor Resolve\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_debuff_minor_brittle.dds|t Minor Brittle\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_buff_minor_berserk.dds|t Minor Berserk\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_debuff_minor_breach.dds|t Minor Breach\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_buff_minor_courage.dds|t Minor Courage\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_buff_minor_evasion.dds|t Minor Evasion\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_buff_minor_force.dds|t Minor Force\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_buff_minor_fortitude.dds|t Minor Fortitude\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_buff_minor_heroism.dds|t Minor Heroism\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_buff_minor_protection.dds|t Minor Protection\n"

    legendText = legendText .. "\n|cFFFFFF=== OTHER BUFFS ===|r\n"
    legendText = legendText .. "|t24:24:/esoui/art/icons/ability_healer_019.dds|t Powerful Assault\n"
    legendText = legendText .. "|c008FB3|t24:24:/esoui/art/icons/ability_debuff_offbalance.dds|t Off-Balance|r\n"
    legendText = legendText ..
        "|cFF0500|t24:24:/esoui/art/icons/ability_debuff_offbalance.dds|t Off-Balance Immunity|r\n"
    return legendText
end

--=============================================================================
-- Initialize
--=============================================================================
local function Initialize()
    ShouldIUlt.savedVars = ZO_SavedVars:NewAccountWide("ShouldIUltSavedVars", 1, nil, defaults)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_EFFECT_CHANGED,
        function(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName,
                 buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)
            ShouldIUlt:OnEffectChanged(changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount,
                iconName,
                buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)
        end)

    -- Filter to only player effects
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")

    local bossUnitTags = { "boss1", "boss2", "boss3", "boss4", "boss5", "boss6" }
    for _, bossTag in ipairs(bossUnitTags) do
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_" .. bossTag, EVENT_EFFECT_CHANGED,
            function(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName,
                     buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)
                ShouldIUlt:OnBossEffectChanged(changeType, effectSlot, effectName, unitTag, beginTime, endTime,
                    stackCount,
                    iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId,
                    sourceType)
            end)
        EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "_" .. bossTag, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG,
            bossTag)
    end

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Target", EVENT_RETICLE_TARGET_CHANGED,
        function() ShouldIUlt:OnTargetChanged() end)

    -- Initialize functions
    ShouldIUlt:ScanCurrentBuffs()
    ShouldIUlt:CreateSettingsMenu()
    ShouldIUlt:UpdateUIPosition()
    ShouldIUlt:UpdateUI()
    ShouldIUlt:StartTimerUpdates()
end


local function OnAddOnLoaded(event, addonName)
    if addonName == ADDON_NAME then
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
        Initialize()
    end
end


EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)


---=============================================================================
-- Events
--=============================================================================
function ShouldIUlt:OnEffectChanged(changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName,
                                    buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId,
                                    sourceType)
    if not ShouldIUlt:IsTrackedBuff(abilityId) then
        return
    end

    if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
        local startTimeMs = beginTime * 1000
        local endTimeMs = endTime * 1000
        local durationMs = endTimeMs - startTimeMs

        local isPermanent = false

        if beginTime == endTime then
            isPermanent = true
        elseif durationMs <= 0 then
            isPermanent = true
        elseif durationMs > 3600000 then
            isPermanent = true
        end

        if isPermanent then
            durationMs = 0
            endTimeMs = 0
        end

        self.buffData[abilityId] = {
            name = effectName,
            iconName = iconName,
            endTime = endTimeMs,
            startTime = startTimeMs,
            stackCount = stackCount or 1,
            duration = durationMs,
            slot = effectSlot,
            isPermanent = isPermanent
        }

        -- Only call UpdateUI for major changes, not timer updates
        self:UpdateUI()
    elseif changeType == EFFECT_RESULT_FADED then
        self.buffData[abilityId] = nil
        self:UpdateUI()
    end
end

---=============================================================================
-- Debug Simulation
--=============================================================================
ShouldIUlt.lastUltNotification = nil
function ShouldIUlt:GetSimulatedBuffs()
    local simulatedBuffs = {}
    local currentTime = GetGameTimeMilliseconds()
    local buffsToSimulate = {}

    if ShouldIUlt.savedVars.simulateAllTracked then
        -- Simulate all buffs in the database
        for category, categoryData in pairs(self.buffDatabase) do
            if category == "bossDebuffs" then
                for subcat, buffs in pairs(categoryData) do
                    for abilityId, name in pairs(buffs) do
                        if not buffsToSimulate[name] then
                            buffsToSimulate[name] = abilityId
                        end
                    end
                end
            else
                for abilityId, name in pairs(categoryData) do
                    if type(abilityId) == "number" and not buffsToSimulate[name] then
                        buffsToSimulate[name] = abilityId
                    end
                end
            end
        end
    else
        -- Only simulate enabled buffs
        for buffType, data in pairs(self.buffTypeMap) do
            if ShouldIUlt.savedVars[data.setting] then
                if data.major then buffsToSimulate[data.major] = true end
                if data.minor then buffsToSimulate[data.minor] = true end
            end
        end

        -- Find IDs for enabled buffs
        local tempSimulate = {}
        for category, categoryData in pairs(self.buffDatabase) do
            if category == "bossDebuffs" then
                for subcat, buffs in pairs(categoryData) do
                    for abilityId, name in pairs(buffs) do
                        if buffsToSimulate[name] and not tempSimulate[name] then
                            tempSimulate[name] = abilityId
                        end
                    end
                end
            else
                for abilityId, name in pairs(categoryData) do
                    if type(abilityId) == "number" and buffsToSimulate[name] and not tempSimulate[name] then
                        tempSimulate[name] = abilityId
                    end
                end
            end
        end
        buffsToSimulate = tempSimulate
    end

    local index = 1
    for buffName, abilityId in pairs(buffsToSimulate) do
        local baseDuration
        if index <= 3 then
            baseDuration = 5000
        elseif index <= 6 then
            baseDuration = 1500
        else
            baseDuration = 6000
        end

        local isOffBalanceImmunity = (abilityId == 134599)
        local isPermanent = (index % 7 == 0)

        simulatedBuffs[abilityId] = {
            name = buffName,
            iconName = self:GetBuffIcon(buffName),
            endTime = isPermanent and currentTime or (currentTime + baseDuration),
            startTime = currentTime - 1000,
            stackCount = (buffName == "Major Slayer") and 5 or 1,
            duration = isPermanent and 0 or baseDuration,
            slot = index,
            simulated = true,
            isOffBalanceImmunity = isOffBalanceImmunity,
            isPermanent = isPermanent
        }
        index = index + 1
    end

    return simulatedBuffs
end

---=============================================================================
-- Debug
--=============================================================================
function ShouldIUlt:DebugListBuffs()
    d("=== Current Player Buffs ===")
    local numBuffs = GetNumBuffs("player")
    for i = 1, numBuffs do
        local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, abilityId =
            GetUnitBuffInfo("player", i)
        d(string.format("%d. %s (ID: %d) - Duration: %.1fs, Stacks: %d",
            i, buffName, abilityId, (timeEnding - timeStarted) / 1000, stackCount))
    end
    d("=== End of Buff List ===")
end

function ShouldIUlt:DebugDetailedBuffInfo()
    d("=== DETAILED BUFF DEBUG ===")
    d("Game time (ms): " .. GetGameTimeMilliseconds())
    d("Game time (s): " .. (GetGameTimeMilliseconds() / 1000))

    local unitTag = "player"
    local numberOfBuffs = GetNumBuffs(unitTag)
    d(string.format("Player has %d buffs:", numberOfBuffs))


    for i = 0, math.min(numberOfBuffs, 10) do
        local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff, castByPlayer =
            GetUnitBuffInfo(unitTag, i)

        if buffName then
            d(string.format("Buff %d:", i))
            d(string.format("  Name: %s", buffName))
            d(string.format("  ID: %d", abilityId or 0))
            d(string.format("  Raw times - Start: %.3f, End: %.3f", timeStarted, timeEnding))
            d(string.format("  Duration: %.3f seconds", timeEnding - timeStarted))
            d(string.format("  Stack count: %d", stackCount or 0))
            d(string.format("  Icon: %s", iconFilename or "nil"))
            d(string.format("  Cast by player: %s", tostring(castByPlayer)))
            d(string.format("  Can click off: %s", tostring(canClickOff)))


            if abilityId and ShouldIUlt:IsTrackedBuff(abilityId) then
                d("  *** THIS BUFF IS TRACKED ***")
            end
            d("")
        end
    end
    d("=== END DETAILED BUFF DEBUG ===")
end

function ShouldIUlt:TestBuffAPI()
    d("=== TESTING BUFF API ===")

    local unitTag = "player"
    local numberOfBuffs = GetNumBuffs(unitTag)
    d("Number of buffs: " .. numberOfBuffs)

    if numberOfBuffs > 0 then
        local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff, castByPlayer =
            GetUnitBuffInfo(unitTag, 0)

        d("First buff test:")
        d("  Name: " .. (buffName or "nil"))
        d("  ID: " .. (abilityId or "nil"))
        d("  Start time: " .. (timeStarted or "nil"))
        d("  End time: " .. (timeEnding or "nil"))
        d("  Icon: " .. (iconFilename or "nil"))
    else
        d("No buffs found on player")
    end

    d("=== END BUFF API TEST ===")
end

function ShouldIUlt:DebugBossDebuffsDetailed()
    d("=== SIMPLIFIED BOSS DEBUFF DEBUG ===")
    d("trackBossDebuffs setting: " .. tostring(ShouldIUlt.savedVars.trackBossDebuffs))


    local trackedBuffs = self:GetTrackedBuffs()
    d("Tracked buff IDs: " .. table.concat(trackedBuffs, ", "))


    local bossUnitTags = { "boss1", "boss2", "boss3", "boss4", "boss5", "boss6" }

    for _, unitTag in ipairs(bossUnitTags) do
        d(string.format("--- Checking %s ---", unitTag))
        if DoesUnitExist(unitTag) then
            local unitName = GetUnitName(unitTag)
            local isAttackable = IsUnitAttackable(unitTag)

            d(string.format("%s: %s (Attackable: %s)", unitTag, unitName, tostring(isAttackable)))

            if isAttackable then
                local numberOfBuffs = GetNumBuffs(unitTag)
                d(string.format("  Has %d effects:", numberOfBuffs))


                for i = 0, math.min(numberOfBuffs, 10) do
                    local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff, castByPlayer =
                        GetUnitBuffInfo(unitTag, i)

                    if buffName and abilityId then
                        d(string.format("    %d. %s (ID: %d) - Duration: %.1fs",
                            i, buffName, abilityId, (timeEnding - timeStarted)))

                        if self:IsTrackedBuff(abilityId) then
                            d("      *** TRACKED DEBUFF ***")
                        end
                    end
                end
            end
        else
            d(unitTag .. ": Does not exist")
        end
        d("")
    end


    d("--- Checking Current Target ---")
    if DoesUnitExist("reticleover") then
        local targetName = GetUnitName("reticleover")
        local isAttackable = IsUnitAttackable("reticleover")
        d(string.format("Target: %s (Attackable: %s)", targetName, tostring(isAttackable)))

        if isAttackable then
            local numberOfBuffs = GetNumBuffs("reticleover")
            d(string.format("  Target has %d effects:", numberOfBuffs))

            for i = 0, math.min(numberOfBuffs, 5) do
                local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, abilityId =
                    GetUnitBuffInfo("reticleover", i)

                if buffName and abilityId then
                    d(string.format("    %d. %s (ID: %d)", i, buffName, abilityId))

                    if self:IsTrackedBuff(abilityId) then
                        d("      *** TRACKED DEBUFF ***")
                    end
                end
            end
        end
    end

    d("=== END SIMPLIFIED BOSS DEBUFF DEBUG ===")
end
