-- Configuration
local TRIGGER_COMMAND = ".starterboost" -- Changed to dot prefix
local MAX_LEVEL = 10                  -- Maximum level allowed to use the boost
local GOLD_AMOUNT = 250 * 10000       -- 250 gold (in copper: 1g = 10000 copper)
local BAG_ITEM_ID = 41599             -- Frostweave Bag (20 Slot)
local BAG_COUNT = 4

-- Faction Trinket IDs
local ALLIANCE_INSIGNIA = 44098
local HORDE_INSIGNIA = 44097

-- Memory storage to track claims for the session
local ClaimedSessionTracker = {}

-- Heirlooms configured precisely by Class
local CLASS_BOOSTS = {
    [1] = { -- WARRIOR (Plate Melee)
        weapons = {42943},                  -- Bloodied Arcanite Reaper (2H Axe)
        armor = {48685, 42949},             -- Polished Breastplate of Valor, Polished Spaulders of Valor
        trinket = 42991                     -- Swift Hand of Justice (Melee)
    },
    [2] = { -- PALADIN (Plate Melee/Hybrid)
        weapons = {42943},                  -- Bloodied Arcanite Reaper (2H Axe)
        armor = {48685, 42949},             -- Polished Breastplate of Valor, Polished Spaulders of Valor
        trinket = 42991                     -- Swift Hand of Justice (Melee)
    },
    [3] = { -- HUNTER (Mail Physical Ranged)
        weapons = {48714, 42944},           -- Charmed Ancient Bone Bow (Bow), Balanced Heartseeker (Dagger)
        armor = {48677, 42952},             -- Champion's Deathdealer Breastplate, Champion Herod's Shoulder
        trinket = 42991                     -- Swift Hand of Justice (Melee/Ranged Haste)
    },
    [4] = { -- ROGUE (Leather Physical)
        weapons = {42944, 42944},           -- Balanced Heartseeker x2 (Dual Wield Daggers)
        armor = {48689, 42984},             -- Stained Shadowcraft Tunic, Stained Shadowcraft Spaulders
        trinket = 42991                     -- Swift Hand of Justice (Melee)
    },
    [5] = { -- PRIEST (Cloth Spellcaster)
        weapons = {42947},                  -- Dignified Headmaster's Charge (Staff)
        armor = {48691, 42985},             -- Tattered Dreadmist Robe, Tattered Dreadmist Mantle
        trinket = 42992                     -- Discerning Eye of the Beast (Spell)
    },
    [6] = { -- DEATH KNIGHT (Plate Melee)
        weapons = {42943},                  -- Bloodied Arcanite Reaper (2H Axe)
        armor = {48685, 42949},             -- Polished Breastplate of Valor, Polished Spaulders of Valor
        trinket = 42991                     -- Swift Hand of Justice (Melee)
    },
    [7] = { -- SHAMAN (Mail Spell/Hybrid)
        weapons = {48718, 48718},           -- Devout Aurastone Hammer x2 (Main Hand Spell Mace)
        armor = {48683, 42947},             -- Mystical Vest of Elements, Mystical Pauldrons of Elements
        trinket = 42992                     -- Discerning Eye of the Beast (Spell)
    },
    [8] = { -- MAGE (Cloth Spellcaster)
        weapons = {42947},                  -- Dignified Headmaster's Charge (Staff)
        armor = {48691, 42985},             -- Tattered Dreadmist Robe, Tattered Dreadmist Mantle
        trinket = 42992                     -- Discerning Eye of the Beast (Spell)
    },
    [9] = { -- WARLOCK (Cloth Spellcaster)
        weapons = {42947},                  -- Dignified Headmaster's Charge (Staff)
        armor = {48691, 42985},             -- Tattered Dreadmist Robe, Tattered Dreadmist Mantle
        trinket = 42992                     -- Discerning Eye of the Beast (Spell)
    },
    [11] = { -- DRUID (Leather Spell/Hybrid)
        weapons = {42947},                  -- Dignified Headmaster's Charge (Staff)
        armor = {48687, 42986},             -- Preened Ironfeather Breastplate, Preened Ironfeather Shoulders
        trinket = 42992                     -- Discerning Eye of the Beast (Spell)
    }
}

local function CanClaimBoost(player)
    local guid = player:GetGUIDLow()

    -- 1. Level Check
    if player:GetLevel() > MAX_LEVEL then
        player:SendBroadcastMessage("|cffff0000Error: You must be level " .. MAX_LEVEL .. " or lower to use this command.|r")
        return false
    end

    -- 2. Session Memory Check
    if ClaimedSessionTracker[guid] then
        player:SendBroadcastMessage("|cffff0000Error: You have already claimed your starter boost!|r")
        return false
    end

    -- 3. Inventory Space Check (ALE-Native Implementation)
    local freeSlots = 0

    -- Check Backpack slots (Backpack is container slot 23, with slots 0 to 15)
    for slot = 0, 15 do
        if not player:GetItemByPos(23, slot) then
            freeSlots = freeSlots + 1
        end
    end

    -- Check Equipped Bag Bags (Bags 1 through 4 are stored in inventory container 23, slots 19 to 22)
    for bagSlot = 19, 22 do
        local bag = player:GetItemByPos(23, bagSlot)
        if bag and bag:IsContainer() then
            -- Get the number of total slots this specific bag offers
            local totalBagSlots = bag:GetBagSlots()
            if totalBagSlots and totalBagSlots > 0 then
                -- Check empty spaces inside this specific sub-container (using its item entry identifier)
                local bagEntryId = bag:GetEntry()
                for slot = 0, totalBagSlots - 1 do
                    if not player:GetItemByPos(bagEntryId, slot) then
                        freeSlots = freeSlots + 1
                    end
                end
            end
        end
    end

    if freeSlots < 10 then
        player:SendBroadcastMessage("|cffff0000Error: You need at least 10 free inventory slots to claim this boost (You have " .. freeSlots .. ").|r")
        return false
    end

    return true
end

local function GiveStarterBoost(player)
    local guid = player:GetGUIDLow()
    local class = player:GetClass()
    local faction = player:GetTeam() -- 0 = Alliance, 1 = Horde

    -- 1. Grant Gold
    player:ModifyMoney(GOLD_AMOUNT)

    -- 2. Grant Bags
    for i = 1, BAG_COUNT do
        player:AddItem(BAG_ITEM_ID, 1)
    end

    -- 3. Grant Class Heirlooms
    local boostData = CLASS_BOOSTS[class]
    if boostData then
        for _, itemId in ipairs(boostData.weapons) do
            player:AddItem(itemId, 1)
        end

        for _, itemId in ipairs(boostData.armor) do
            player:AddItem(itemId, 1)
        end

        player:AddItem(boostData.trinket, 1)

        if faction == 0 then
            player:AddItem(ALLIANCE_INSIGNIA, 1)
        else
            player:AddItem(HORDE_INSIGNIA, 1)
        end
    else
        player:SendBroadcastMessage("|cff00ff00Your gold and bags were delivered, but no heirloom profile was found for your class.|r")
    end

    -- 4. Mark as claimed
    ClaimedSessionTracker[guid] = true
    
    player:CastSpell(player, 63660, true) 
    player:SendBroadcastMessage("|cff00ff00Starter Boost Applied! Check your bags. Good luck out there!|r")
end

-- Main command handler hook
local function OnPlayerCommand(event, player, command)
    -- Grab the first element to process the trigger
    local trigger = command:match("%S+")
    if not trigger then return end

    trigger = trigger:lower()

    -- Check for ".starterboost" or "starterboost" (if core strips the prefix)
    if trigger == ".starterboost" or trigger == "starterboost" then
        if CanClaimBoost(player) then
            GiveStarterBoost(player)
        end
        return false -- Interrupts core processing, suppressing "Command not found" box errors
    end
end

-- Cleanup session tracker maps safely on character logout
local function OnLogout(event, player)
    local guid = player:GetGUIDLow()
    if ClaimedSessionTracker[guid] then
        ClaimedSessionTracker[guid] = nil
    end
end

-- Hook into command processing (PLAYER_EVENT_ON_COMMAND = 42)
RegisterPlayerEvent(42, OnPlayerCommand)

-- Register player logout event (PLAYER_EVENT_ON_LOGOUT = 4)
RegisterPlayerEvent(4, OnLogout)

print("[ALE] Starter Boost Enabled via .starterboost (Max level " .. MAX_LEVEL .. ")")
