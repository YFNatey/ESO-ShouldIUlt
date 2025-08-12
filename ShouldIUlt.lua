local ADDON_NAME = "ShouldIUlt"


ShouldIUlt = {}
ShouldIUlt.savedVars = nil
ShouldIUlt.buffData = {}
ShouldIUlt.isInitialized = false
ShouldIUlt.lastScanTime = 0
ShouldIUlt.scanThrottle = 250
ShouldIUlt.lastUltCheck = 0
ShouldIUlt.ultCheckThrottle = 500

ShouldIUlt.offBalanceImmunityTimer = nil
ShouldIUlt.offBalanceImmunityEndTime = 0
ShouldIUlt.offBalanceImmunityDuration = 15000

ShouldIUlt.cachedSimulatedBuffs = nil
ShouldIUlt.simulationCacheTime = 0


---=============================================================================
-- Scan Boss Debuffs and player Buffs
--=============================================================================

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

    -- Remove expired debuffs
    for abilityId in pairs(existingDebuffs) do
        self.bossDebuffData[abilityId] = nil
    end
end

function ShouldIUlt:GetDisplayBuffs()
    if ShouldIUlt.savedVars.simulationMode then
        return self:GetSimulatedBuffs()
    else
        local allBuffs = {}

        -- Player buffs
        for abilityId, buffInfo in pairs(self.buffData) do
            if not (ShouldIUlt.savedVars.hidePermanentBuffs and buffInfo.isPermanent) then
                allBuffs[abilityId] = buffInfo
            end
        end

        -- Boss Debuffs
        if self.bossDebuffData then
            local shouldShowBossDebuffs = ShouldIUlt.savedVars.trackAbyssalInk or
                ShouldIUlt.savedVars.trackVulnerability or
                ShouldIUlt.savedVars.trackOffBalance or
                ShouldIUlt.savedVars.trackBrittle or
                ShouldIUlt.savedVars.trackBreach
            if shouldShowBossDebuffs then
                for abilityId, debuffInfo in pairs(self.bossDebuffData) do
                    if not (ShouldIUlt.savedVars.hidePermanentBuffs and debuffInfo.isPermanent) then
                        allBuffs[abilityId] = debuffInfo
                    end
                end
            end
        end

        -- Off-balance immunity timer
        if self:IsOffBalanceImmunityActive() and ShouldIUlt.savedVars.showOffBalanceImmunity and ShouldIUlt.savedVars.trackOffBalance then
            local hasRealOffBalance = false
            for abilityId, buffInfo in pairs(allBuffs) do
                if self:IsOffBalanceBuff(abilityId) then
                    hasRealOffBalance = true
                    break
                end
            end

            if not hasRealOffBalance then
                -- Fake ability ID for the immunity timer
                local immunityId = 999999
                allBuffs[immunityId] = {
                    name = "Off-Balance",
                    iconName = "/esoui/art/icons/ability_debuff_offbalance.dds",
                    endTime = self.offBalanceImmunityEndTime,
                    startTime = self.offBalanceImmunityEndTime - self.offBalanceImmunityDuration,
                    stackCount = 1,
                    duration = self.offBalanceImmunityDuration,
                    slot = 999,
                    isOffBalanceImmunity = true,
                    isPermanent = false,
                    isImmunityTimer = true
                }
            end
        end

        return allBuffs
    end
end

function ShouldIUlt:GetTrackedBuffs()
    local trackedBuffs = {}

    -- Search for all IDs that match target buff names
    for buffType, data in pairs(self.buffTypeMap) do
        if ShouldIUlt.savedVars[data.setting] then
            for category, categoryData in pairs(self.buffDatabase) do
                if category == "bossDebuffs" then
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

function ShouldIUlt:IsTrackedBuff(abilityId)
    local trackedBuffs = ShouldIUlt:GetTrackedBuffs()
    for _, trackedId in ipairs(trackedBuffs) do
        if trackedId == abilityId then
            return true
        end
    end
    return false
end

---=============================================================================
-- Off-Balance and Immunity Timer
--=============================================================================
function ShouldIUlt:IsOffBalanceBuff(abilityId)
    local buffName = self:FindBuffNameInDatabase(abilityId)
    return buffName == "Off-Balance"
end

-- Start timer
function ShouldIUlt:StartOBImmunityTimer()
    local currentTime = GetGameTimeMilliseconds()
    self.offBalanceImmunityEndTime = currentTime + self.offBalanceImmunityDuration

    -- Clear any existing timer
    if self.offBalanceImmunityTimer then
        EVENT_MANAGER:UnregisterForUpdate(self.offBalanceImmunityTimer)
        self.offBalanceImmunityTimer = nil
    end

    -- Create a unique timer name
    local timerName = ADDON_NAME .. "OffBalanceImmunity" .. tostring(currentTime)
    self.offBalanceImmunityTimer = timerName
    EVENT_MANAGER:RegisterForUpdate(timerName, 100, function()
        local now = GetGameTimeMilliseconds()
        if now >= self.offBalanceImmunityEndTime then
            self:ClearOffBalanceImmunityTimer()
            self:UpdateUI()
        end
    end)
    self:UpdateUI()
end

-- Timer update
function ShouldIUlt:UpdateOBImmunityTimer()
    if not self:IsOffBalanceImmunityActive() then
        return 0
    end
    return self.offBalanceImmunityEndTime - GetGameTimeMilliseconds()
end

-- Clear Timer
function ShouldIUlt:ClearOffBalanceImmunityTimer()
    if self.offBalanceImmunityTimer then
        EVENT_MANAGER:UnregisterForUpdate(self.offBalanceImmunityTimer)
        self.offBalanceImmunityTimer = nil
    end
    self.offBalanceImmunityEndTime = 0
end

-- Check for Immunity
function ShouldIUlt:IsOffBalanceImmunityActive()
    return self.offBalanceImmunityEndTime > 0 and GetGameTimeMilliseconds() < self.offBalanceImmunityEndTime
end

---=============================================================================
-- Ulti Indicator
--=============================================================================
function ShouldIUlt:CheckUltConditions()
    local currentTime = GetGameTimeMilliseconds()
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

--=============================================================================
-- Initialize
--=============================================================================
local function Initialize()
    ShouldIUlt.savedVars = ZO_SavedVars:NewAccountWide("ShouldIUltSavedVars", 1, nil, ShouldIUlt.defaults)

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

        -- If off-balance is gained, clear any immunity timer
        if self:IsOffBalanceBuff(abilityId) then
            self:ClearOffBalanceImmunityTimer()
        end

        self:UpdateUI()
    elseif changeType == EFFECT_RESULT_FADED then
        -- Check if this is an off-balance effect that just faded
        if self:IsOffBalanceBuff(abilityId) and ShouldIUlt.savedVars.showOffBalanceImmunity then
            self:StartOBImmunityTimer()
        end

        self.buffData[abilityId] = nil
        self:UpdateUI()
    end
end

function ShouldIUlt:OnBossEffectChanged(changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount,
                                        iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId,
                                        abilityId, sourceType)
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

        -- If off-balance is gained, clear any immunity timer
        if self:IsOffBalanceBuff(abilityId) then
            self:ClearOffBalanceImmunityTimer()
        end

        self:UpdateUI()
    elseif changeType == EFFECT_RESULT_FADED then
        -- Check if this is an off-balance effect that just faded
        if self:IsOffBalanceBuff(abilityId) and ShouldIUlt.savedVars.showOffBalanceImmunity then
            self:StartOBImmunityTimer()
        end

        if self.bossDebuffData then
            self.bossDebuffData[abilityId] = nil
        end
        self:UpdateUI()
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
        if ShouldIUlt.savedVars.showTimer then
            ShouldIUlt:UpdateTimersOnly()
        end

        if ShouldIUlt:CheckUltConditions() then
            ShouldIUlt:ShowUltMessage()
        end
    end)
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
    local layoutDirection = ShouldIUlt.savedVars.layoutDirection or "horizontal"

    -- Calculate layout dimensions based on direction
    local maxIcons = 14
    local cols, rows

    if layoutDirection == "horizontal" then
        cols = ShouldIUlt.savedVars.maxIconsPerRow or 7
        rows = math.ceil(maxIcons / cols)
    else -- vertical
        rows = ShouldIUlt.savedVars.maxIconsPerColumn or 7
        cols = math.ceil(maxIcons / rows)
    end

    -- Position icons based on layout
    for i = 1, maxIcons do
        local buffIcon = container:GetNamedChild("BuffIcon" .. i)
        if buffIcon then
            buffIcon:SetHidden(true)
            buffIcon:SetDimensions(iconSize, iconSize)

            local row, col
            if layoutDirection == "horizontal" then
                row = math.floor((i - 1) / cols)
                col = (i - 1) % cols
            else -- vertical
                col = math.floor((i - 1) / rows)
                row = (i - 1) % rows
            end

            local x = col * (iconSize + adjustedSpacing)
            local y = row * (iconSize + adjustedSpacing)

            buffIcon:ClearAnchors()
            buffIcon:SetAnchor(TOPLEFT, container, TOPLEFT, x, y)
        end
    end

    -- Update container dimensions
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

            if iconControl and buffInfo.iconName then
                iconControl:SetTexture(buffInfo.iconName)
                buffIcon:SetHidden(false)

                -- Color the icon based on buff type
                if buffInfo.isOffBalanceImmunity or buffInfo.isImmunityTimer then
                    iconControl:SetColor(1, 0.02, 0, 1)  -- Red for immunity
                elseif buffInfo.name == "Off-Balance" and not buffInfo.isImmunityTimer then
                    iconControl:SetColor(0, 0.7, 0.5, 1) -- Green for active off-balance
                else
                    iconControl:SetColor(1, 1, 1, 1)     -- Normal color
                end

                -- Timer display
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
                if index > maxIcons then break end
            end
        end
    end

    if self:CheckUltConditions() then
        self:ShowUltMessage()
    end
end

function ShouldIUlt:Cleanup()
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "TimerUpdate")
    self:ClearOffBalanceImmunityTimer()
    self.buffData = {}
    if self.bossDebuffData then
        self.bossDebuffData = {}
    end
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
            index = index + 1
            if index > 14 then break end
        end
    end
end

function ShouldIUlt:OnUpdate()
    ShouldIUlt:UpdateUI()
end

---=============================================================================
-- Debug Simulation
--=============================================================================
ShouldIUlt.lastUltNotification = nil
function ShouldIUlt:GetSimulatedBuffs()
    local currentTime = GetGameTimeMilliseconds()

    if not self.cachedSimulatedBuffs or (currentTime - self.simulationCacheTime) > 5000 then
        local simulatedBuffs = {}
        local buffsToSimulate = {}

        -- Simulate all buffs in the database
        if ShouldIUlt.savedVars.simulateAllTracked then
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

        -- Cache the results
        self.cachedSimulatedBuffs = simulatedBuffs
        self.simulationCacheTime = currentTime
    else
        -- Update timestamps on cached buffs to keep timers working
        for abilityId, buffInfo in pairs(self.cachedSimulatedBuffs) do
            if not buffInfo.isPermanent then
                local originalDuration = buffInfo.duration
                buffInfo.startTime = currentTime - 1000
                buffInfo.endTime = currentTime + originalDuration - 1000
            end
        end
    end

    return self.cachedSimulatedBuffs
end

function ShouldIUlt:SetSimulationMode(value)
    ShouldIUlt.savedVars.simulationMode = value

    -- Clear cache when disabling simulation mode
    if not value then
        self.cachedSimulatedBuffs = nil
        self.simulationCacheTime = 0
    end

    ShouldIUlt:ScanCurrentBuffs()
    ShouldIUlt:UpdateUI()
end

---=============================================================================
-- Buffs Database
--=============================================================================
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
