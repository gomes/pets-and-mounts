--[[-------------------------------------------------------------------------------
    Pets & Mounts
    Auto and random summon highly customizable for your pets and mounts, with Data Broker support.
    By: Shenton

    Buttons.lua
-------------------------------------------------------------------------------]]--

local A = _G["PetsAndMountsGlobal"];
local L = A.L;

-- Globals to locals
local pairs = pairs;
local _G = _G;
local type = type;
local select = select;
local loadstring = loadstring;
local tContains = tContains;
local string = string;
local ipairs = ipairs;
local tonumber = tonumber;

-- GLOBALS: BINDING_HEADER_PETSANDMOUNTS, InCombatLockdown, GetSpellInfo, IsFlyableArea, IsSpellKnown
-- GLOBALS: IsShiftKeyDown, IsControlKeyDown, GetItemCount, GetItemInfo, UIDropDownMenu_SetAnchor
-- GLOBALS: ToggleDropDownMenu, GameTooltip, PetsAndMountsSecureButtonMounts, PetsAndMountsSecureButtonPets
-- GLOBALS: GetScreenWidth, IsMounted, GetUnitSpeed, IsPlayerMoving, GetTalentInfo, GetTalentRowSelectionInfo, GetInstanceInfo
-- GLOBALS: GetGlyphSocketInfo, IsFalling, NUM_GLYPH_SLOTS, GetShapeshiftForm, IsEquippedItemType
-- GLOBALS: ShentonFishingGlobal, GetActiveSpecGroup, IsIndoors, IsAltKeyDown, PlayerHasToy, GetCVarBool

--[[-------------------------------------------------------------------------------
    Bindings
-------------------------------------------------------------------------------]]--

-- Bindings list
A.bindingsTable =
{
    {
        name = "CLICK PetsAndMountsSecureButtonPets:LeftButton",
        localized = L["Random companion"],
        configDesc = L["Bind a key to summon a random companion."],
    },
    {
        name = "CLICK PetsAndMountsSecureButtonMounts:LeftButton",
        localized = L["Random mount"],
        configDesc = L["Bind a key to summon a random mount."],
    },
    {
        name = "CLICK PetsAndMountsSecureButtonPassengers:LeftButton",
        localized = L["Random passengers mount"],
        configDesc = L["Bind a key to summon a random mount."],
    },
    {
        name = "CLICK PetsAndMountsSecureButtonFlying:LeftButton",
        localized = L["Random flying mount"],
        configDesc = L["Bind a key to summon a random mount."],
    },
    {
        name = "CLICK PetsAndMountsSecureButtonGround:LeftButton",
        localized = L["Random ground mount"],
        configDesc = L["Bind a key to summon a random mount."],
    },
    {
        name = "CLICK PetsAndMountsSecureButtonAquatic:LeftButton",
        localized = L["Random aquatic mount"],
        configDesc = L["Bind a key to summon a random mount."],
    },
    {
        name = "CLICK PetsAndMountsSecureButtonSurface:LeftButton",
        localized = L["Random surface mount"],
        configDesc = L["Bind a key to summon a random mount."],
    },
    {
        name = "CLICK PetsAndMountsSecureButtonRepair:LeftButton",
        localized = L["Random repair mount"],
        configDesc = L["Bind a key to summon a random mount."],
    },
    {
        name = "CLICK PetsAndMountsSecureButtonHybrid:LeftButton",
        localized = L["Random hybrid mount"],
        configDesc = L["Bind a key to summon a random mount."],
    },
};

-- Binding UI localization
BINDING_HEADER_PETSANDMOUNTS = L["Pets & Mounts"];

do
    for k,v in ipairs(A.bindingsTable) do
        _G["BINDING_NAME_"..v.name] = v.localized;
    end
end

--[[-------------------------------------------------------------------------------
    Global methods
-------------------------------------------------------------------------------]]--

-- Global macro dismount string
function A:SetMacroDismountString()
    if ( A.db.profile.dismountFlying ) then
        A.macroDismountString = "/dismount [mounted]";
    else
        A.macroDismountString = "/dismount [mounted,noflying]";
    end

    if ( A.db.profile.vehicleExit ) then
        A.macroDismountString = A.macroDismountString.."\n/leavevehicle [vehicleui]";
    end
end

--- Check if we got at least one mount for the given cat, check all tables after restriction
function A:GotMountAllTable(cat)
    if ( A.db.profile.forceOne.mount[cat]
    or A.db.profile.mountByMapID[cat][A.currentMapID]
    or A.db.profile.areaMounts and A.uniqueAreaMounts[cat][A.currentMapID]
    or A:GotRandomMount(A.currentMountsSet[cat])
    or A:GotRandomMount(A.pamTable.mountsIds[cat]) ) then
        return 1;
    end

    return nil;
end

--- IsEquippedItemType with a check on A.fishingPole subType
function A:IsEquippedFishingPole()
    if ( A.fishingPoleSubType ) then
        return IsEquippedItemType(A.fishingPoleSubType);
    end

    return nil;
end

--- Get the mount summon command according to button name
A.mountButtonCommands =
{
    ["PetsAndMountsSecureButtonPassengers"] = "/pampassengers",
    ["PetsAndMountsSecureButtonFlying"] = "/pamfly",
    ["PetsAndMountsSecureButtonGround"] = "/pamground",
    ["PetsAndMountsSecureButtonAquatic"] = "/pamaquatic",
    ["PetsAndMountsSecureButtonSurface"] = "/pamsurface",
    ["PetsAndMountsSecureButtonRepair"] = "/pamrepair",
    ["PetsAndMountsSecureButtonHybrid"] = "/pamhybrid",
};

--- Slash command for the configured Shift+Click mount category
A.shiftClickMountCommands =
{
    [1] = "/pamground",
    [2] = "/pamfly",
    [3] = "/pamhybrid",
    [4] = "/pamaquatic",
    [5] = "/pampassengers",
    [6] = "/pamsurface",
    [7] = "/pamrepair",
};

function A:GetShiftClickMountCommand()
    local cat = tonumber(A.db.profile.mountButtonshiftClickCat) or 5;
    return A.shiftClickMountCommands[cat] or "/pampassengers";
end

--- Apply or clear secure shift-click overrides (no Lua IsShiftKeyDown — avoids stealing normal clicks)
function A:ApplyShiftClickMountAttributes(button)
    if ( A.db.profile.mountButtonshiftClickEnabled ) then
        local cmd = A:GetShiftClickMountCommand();
        button:SetAttribute("shift-type*", "macro");
        button:SetAttribute("shift-macrotext*", cmd);
    else
        button:SetAttribute("shift-type*", nil);
        button:SetAttribute("shift-macrotext*", nil);
    end
end

function A:GetMountCommand(button)
    button = button:GetName();

    local command = A.mountButtonCommands[button];

    if ( command ) then
        return command, 1;
    end

    return "/pammount", nil;
end

--- Is the player a boomkin?
function A:IsBoomkin()
    if ( A.playerCurrentSpecID ~= 102 ) then
        A:DebugMessage("IsBoomkin() - false");
        return nil;
    end

    local form = GetShapeshiftForm(1);

    -- if ( A:IsGlyphed(114338) ) then -- Glyph of the Stag - Offset by one druid's forms
        -- if ( form ~= 5 ) then
            -- A:DebugMessage("IsBoomkin() - false");
            -- return nil;
        -- end
    -- else
        if ( form ~= 4 ) then
            A:DebugMessage("IsBoomkin() - false");
            return nil;
        end
    -- end

    A:DebugMessage("IsBoomkin() - true");
    return 1;
end

--- Is the player able to use the Telaari Talbuk or the Frostwolf War Wolf
-- Zone ability 161691 overrides to 165803 (Alliance) / 164222 (Horde) only in Draenor.
-- Must resolve by spell NAME so we get the active override spellID, not a static lookup.
function A:IsTelaariTalbukUsable()
    if ( not A.draenorZoneAbilityBaseName ) then
        local spellInfo = C_Spell.GetSpellInfo(161691);
        A.draenorZoneAbilityBaseName = spellInfo and spellInfo.name;
    end

    if ( not A.draenorZoneAbilityBaseName ) then return nil; end

    local active = C_Spell.GetSpellInfo(A.draenorZoneAbilityBaseName);
    local activeSpellID = active and active.spellID;

    if ( A.playerFaction == "Alliance" ) then
        if ( activeSpellID == 165803 ) then
            return 1;
        end
    elseif ( A.playerFaction == "Horde" ) then
        if ( activeSpellID == 164222 ) then
            return 1;
        end
    end

    return nil;
end

--- Set the spells names for the player's class
-- This will check if the spell name is not nil
-- it is required as for some ppl they are not available on login
-- latency || bad config + cache deleting = no names from server || client
A.classesSpellsTable =
{
    DEATHKNIGHT =
    {
        deathKnightPathOfFrost = 3714, -- lvl 66
        deathKnightWraithWalk = 212552, -- lvl 60
    },
    DRUID =
    {
        druidCatForm = 768, -- lvl 6
        druidTravelForm = 783, -- lvl 16
        druidFlightForm = 165962; -- lvl 58
    },
    HUNTER =
    {
        hunterAspectCheetah = 186257, -- lvl 5
    },
    MAGE =
    {
        mageSlowFall = 130, -- lvl 32
        mageBlink = 1953, -- lvl 7
        --mageBlazingSpeed = 108843, -- lvl 15 - tier 1 row 2 - id 2
    },
    MONK =
    {
        monkRoll = 109132, -- lvl 5
        monkFlyingSerpentKick = 101545, -- lvl 18
        monkZenFlight = 125883, -- lvl 25 - Learnable with a book 125893
    },
    PALADIN =
    {
        --paladinSpeedOfLight = 85499, -- lvl 15 - tier 1 row 1 - id 1
        paladinDivineSteed = 190784, -- lvl 28
    },
    PRIEST =
    {
        priestPowerWordShield = 17, -- Body and Soul
        priestAngelicFeather = 121536,
        priestLevitate = 1706, -- lvl 34
        -- priestBodyAndMind = 214121, -- removed from game (was Holy talent)
    },
    ROGUE =
    {
        rogueSprint = 2983, -- lvl 26
    },
    SHAMAN =
    {
        shamanGhostWolf = 2645, -- lvl 15
        shamanWaterWalking = 546, -- lvl 24
    },
    WARLOCK =
    {
        warlockDemonicCircle = 48020, -- lvl 76
        warlockBurningRush = 111400, -- lvl 60 - id 11
    },
    WARRIOR =
    {
        warriorCharge = 100, -- lvl 3
        warriorIntercept = 198304, -- lvl 72
        warriorHeroicLeap = 6544, -- lvl 85
    },
};

--- Locale-safe class spell ID (from classesSpellsTable, never a translated name)
function A:GetClassSpellID(key)
    local classTable = A.classesSpellsTable[A.playerClass];
    return classTable and classTable[key] or nil;
end

--- Resolve spell ID to the client's localized macro name (with subtext when needed)
-- Prefer the name cached by SetClassSpells; never use hardcoded English fallbacks.
function A:GetMacroSpellName(spellID)
    if ( not spellID ) then
        return nil;
    end

    local classTable = A.classesSpellsTable[A.playerClass];
    if ( classTable ) then
        for key, id in pairs(classTable) do
            if ( id == spellID and type(A[key]) == "string" and A[key] ~= "" ) then
                return A[key];
            end
        end
    end

    local spellInfo = C_Spell.GetSpellInfo(spellID);
    local name = spellInfo and spellInfo.name;
    if ( not name or name == "" ) then
        return nil;
    end

    local subtext = C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(spellID) or nil;
    if ( subtext and subtext ~= "" ) then
        name = name.."("..subtext..")";
    end

    return name;
end

--- Build /cast using the localized spell name (locale-safe via GetSpellInfo / SetClassSpells)
-- opts.prefix = optional lines before cast (e.g. dismount)
-- opts.condition = e.g. "[nomounted]" or "[nomounted,indoors]"
-- opts.bang = true for /cast !
function A:FormatMacroCast(spellID, opts)
    opts = opts or {};
    local name = A:GetMacroSpellName(spellID);
    if ( not name ) then
        return opts.prefix or "/pammount";
    end

    local castLine;
    local condition = opts.condition;

    if ( opts.bang ) then
        if ( condition and condition ~= "" ) then
            castLine = ("/cast !%s %s"):format(condition, name);
        else
            castLine = ("/cast !%s"):format(name);
        end
    elseif ( condition and condition ~= "" ) then
        castLine = ("/cast %s %s"):format(condition, name);
    else
        castLine = ("/cast %s"):format(name);
    end

    if ( opts.prefix and opts.prefix ~= "" ) then
        return opts.prefix.."\n"..castLine;
    end

    return castLine;
end

--- Multi-option /cast with localized spell names
-- parts = { { condition = "[swimming]", id = 783 }, { condition = "[indoors]", id = 768 }, { id = 783 } }
function A:FormatMacroCastChain(parts, opts)
    opts = opts or {};
    if ( not parts or #parts == 0 ) then
        return opts.prefix or "/pammount";
    end

    local segments = {};
    for _, part in ipairs(parts) do
        local name = A:GetMacroSpellName(part.id);
        if ( name ) then
            if ( part.condition and part.condition ~= "" ) then
                segments[#segments + 1] = ("%s %s"):format(part.condition, name);
            else
                segments[#segments + 1] = name;
            end
        end
    end

    if ( #segments == 0 ) then
        return opts.prefix or "/pammount";
    end

    local castLine = "/cast "..table.concat(segments, "; ");
    if ( opts.prefix and opts.prefix ~= "" ) then
        return opts.prefix.."\n"..castLine;
    end

    return castLine;
end

function A:SetClassSpells()
    A.setClassSpellsRetries = A.setClassSpellsRetries or 0;
    local missing;

    if ( A.classesSpellsTable[A.playerClass] ) then
        for k,v in pairs(A.classesSpellsTable[A.playerClass]) do
            local spellInfo = C_Spell.GetSpellInfo(v);
            local name = spellInfo and spellInfo.name or nil;
            -- subtext is not on GetSpellInfo's table in modern API
            local subtext = C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(v) or nil;

            if ( not name or name == "" ) then
                missing = missing or {};
                missing[#missing + 1] = v;
                A[k] = nil;
            else
                if ( subtext and subtext ~= "" ) then
                    name = name.."("..subtext..")";
                end

                A[k] = name;
            end
        end
    end

    -- Retry a few times for login cache lag; never loop forever on removed spells
    if ( missing and #missing > 0 and A.setClassSpellsRetries < 5 ) then
        A.setClassSpellsRetries = A.setClassSpellsRetries + 1;
        A:ScheduleTimer("SetClassSpells", 0.5);
        A:DebugMessage(("SetClassSpells() - Waiting for spell data (%s), retry %d/5"):format(table.concat(missing, ", "), A.setClassSpellsRetries));
    elseif ( missing and #missing > 0 ) then
        A:DebugMessage(("SetClassSpells() - Skipping unknown/removed spells: %s"):format(table.concat(missing, ", ")));
    else
        A.setClassSpellsRetries = 0;
    end

    A.classSpellsOK = 1;
    A:SetPostClickMacro();
    A:SetPreClickFunction();
end

function A:IsModifierDown(mod)
    if ( mod == "shift" ) then
        if ( IsShiftKeyDown() ) then
            return 1;
        end
    elseif ( mod == "ctrl" ) then
        if ( IsControlKeyDown() ) then
            return 1;
        end
    elseif ( mod == "alt" ) then
        if ( IsAltKeyDown() ) then
            return 1;
        end
    end

    return nil
end

--[[-------------------------------------------------------------------------------
    Pre clicks classes methods
-------------------------------------------------------------------------------]]--

--- Death Knight preclick macro
-- For DK we handle Death's Advance and Unholy Presence when moving
function A:SetDeathKnightPreClickMacro()
    if ( A.playerLevel >= 60 and A:IsPlayerMovingForMountFallback() ) then
        return A:FormatMacroCast(A:GetClassSpellID("deathKnightWraithWalk"), { prefix = A.macroDismountString });
    else
        return "/pammount";
    end
end

--- Druid pre click macro
-- For Druids we handle flight forms
function A:SetDruidPreClickMacro()
    local cat = A:GetClassSpellID("druidCatForm");
    local travel = A:GetClassSpellID("druidTravelForm");

    if ( A.db.profile.druidWantFormsOnMove ) then
        if ( A:IsPlayerMovingForMountFallback() ) then
            if ( A.playerLevel >= 16 and not IsMounted() ) then
                return A:FormatMacroCastChain({
                    { condition = "[swimming]", id = travel },
                    { condition = "[indoors]", id = cat },
                    { id = travel },
                }, { prefix = A.macroDismountString });
            elseif ( A.playerLevel >= 6 and not IsMounted() ) then
                return A:FormatMacroCast(cat, { prefix = A.macroDismountString });
            else
                return "/pammount";
            end
        elseif ( IsIndoors() ) then
            return A:FormatMacroCastChain({
                { condition = "[swimming]", id = travel },
                { id = cat },
            }, { prefix = A.macroDismountString });
        elseif ( GetShapeshiftForm(1) > 0 and not A:IsBoomkin() ) then
            if ( A.db.profile.noMountAfterCancelForm ) then
                return "/cancelform [form]";
            else
                return "/cancelform [form]\n/pammount";
            end
        else
            return "/pammount";
        end
    else
        if ( A.playerLevel >= 58 and A:IsFlyable() and not IsMounted() ) then
            return A:FormatMacroCastChain({
                { condition = "[swimming]", id = travel },
                { condition = "[indoors]", id = cat },
                { id = travel },
            }, { prefix = A.macroDismountString });
        elseif ( A.playerLevel >= 20 and A:CanRide() and not IsMounted() ) then
            if ( A:IsPlayerMovingForMountFallback() ) then
                return A:FormatMacroCastChain({
                    { condition = "[swimming]", id = travel },
                    { condition = "[indoors]", id = cat },
                    { id = travel },
                }, { prefix = A.macroDismountString });
            elseif ( IsIndoors() ) then
                return A:FormatMacroCastChain({
                    { condition = "[swimming]", id = travel },
                    { id = cat },
                }, { prefix = A.macroDismountString });
            elseif ( GetShapeshiftForm(1) > 0 and not A:IsBoomkin() ) then
                if ( A.db.profile.noMountAfterCancelForm ) then
                    return "/cancelform [form]";
                else
                    return "/cancelform [form]\n/pammount";
                end
            else
                return "/pammount";
            end
        elseif ( A.playerLevel >= 16 and not IsMounted() ) then
            return A:FormatMacroCastChain({
                { condition = "[swimming]", id = travel },
                { condition = "[indoors]", id = cat },
                { id = travel },
            }, { prefix = A.macroDismountString });
        elseif ( A.playerLevel >= 6 and not IsMounted() ) then
            return A:FormatMacroCast(cat, { prefix = A.macroDismountString });
        else
            return "/pammount";
        end
    end
end

--- Hunter pre click macro
-- For Hunters we handle speed aspects when moving
function A:SetHunterPreClickMacro()
    if ( A.playerLevel >= 5 and A:IsPlayerMovingForMountFallback() ) then
        return A:FormatMacroCast(A:GetClassSpellID("hunterAspectCheetah"), { prefix = A.macroDismountString });
    else
        return "/pammount";
    end
end

--- Mage pre click macro
-- For Mages we handle Blink when moving and Slow Fall when falling
function A:SetMagePreClickMacro()
    if ( A.db.profile.mageSlowFall and IsFalling() and A.playerLevel >= 32 ) then
        return A:FormatMacroCast(A:GetClassSpellID("mageSlowFall"), { prefix = A.macroDismountString });
    elseif ( A:IsPlayerMovingForMountFallback() ) then
        if ( A.playerLevel >= 7 ) then
            return A:FormatMacroCast(A:GetClassSpellID("mageBlink"), { prefix = A.macroDismountString });
        else
            return "/pammount";
        end
    else
        return "/pammount";
    end
end

--- Monk pre click macro
-- For monks we handle Roll and Flying Serpent Kick
function A:SetMonkPreClickMacro()
    if ( IsFalling() and IsSpellKnown(125883, false) ) then
        return A:FormatMacroCast(A:GetClassSpellID("monkZenFlight"), { prefix = A.macroDismountString });
    elseif ( A:IsPlayerMovingForMountFallback() ) then
        if ( A.db.profile.monkPreferSerpentKick and A.playerLevel >= 18 and A.playerSpecTalentsInfos["spec"] == 3 ) then
            return A:FormatMacroCast(A:GetClassSpellID("monkFlyingSerpentKick"), { prefix = A.macroDismountString });
        elseif ( A.playerLevel >= 5 ) then
            return A:FormatMacroCast(A:GetClassSpellID("monkRoll"), { prefix = A.macroDismountString });
        else
            return "/pammount";
        end
    else
        return "/pammount";
    end
end

--- Paladin pre click macro
-- For Paladins we handle Speed of Light when moving
function A:SetPaladinPreClickMacro()
    if ( A:IsPlayerMovingForMountFallback() ) then
        if ( A.playerLevel >= 28 ) then
            return A:FormatMacroCast(A:GetClassSpellID("paladinDivineSteed"), { prefix = A.macroDismountString });
        else
            return "/pammount";
        end
    else
        return "/pammount";
    end
end

--- Priest pre click macro
-- For Priests we handle Body and Soul and Angelic Feather when moving
function A:SetPriestPreClickMacro()
    if ( A.db.profile.priestLevitate and IsFalling() and A.playerLevel >= 34 ) then
        return A:FormatMacroCast(A:GetClassSpellID("priestLevitate"), { prefix = A.macroDismountString });
    elseif ( A:IsPlayerMovingForMountFallback() ) then
        if ( (A.playerSpecTalentsInfos["spec"] == 1 or A.playerSpecTalentsInfos["spec"] == 3) and A.playerSpecTalentsInfos["row2"] == 2) then -- Body And Soul
            return A:FormatMacroCast(A:GetClassSpellID("priestPowerWordShield"), { prefix = A.macroDismountString });
        elseif ( (A.playerSpecTalentsInfos["spec"] == 1 or A.playerSpecTalentsInfos["spec"] == 2) and A.playerSpecTalentsInfos["row2"] == 1) then -- Angelic Feather
            return A:FormatMacroCast(A:GetClassSpellID("priestAngelicFeather"), { prefix = A.macroDismountString });
        else
            return "/pammount";
        end
    else
        return "/pammount";
    end
end

--- Rogue pre click macro
-- For Rogues we handle Sprint when moving
function A:SetRoguePreClickMacro()
    if ( A:IsPlayerMovingForMountFallback() ) then
        if ( A.playerLevel >= 26 ) then
            return A:FormatMacroCast(A:GetClassSpellID("rogueSprint"), { prefix = A.macroDismountString });
        else
            return "/pammount";
        end
    else
        return "/pammount";
    end
end

--- Shaman pre click: Ghost Wolf (2645) toggles like the default spell button.
-- Enter via type=spell; exit via /cancelform when already in form.
-- Otherwise try RandomMount in PreClick; on failure cast Ghost Wolf on the same click.
A.SHAMAN_GHOST_WOLF_SPELL_ID = 2645;

function A:IsShamanInGhostWolf()
    if ( GetShapeshiftForm(1) > 0 ) then
        return 1;
    end

    if ( C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID ) then
        if ( C_UnitAuras.GetPlayerAuraBySpellID(A.SHAMAN_GHOST_WOLF_SPELL_ID) ) then
            return 1;
        end
    end

    return nil;
end

function A:SetMountButtonGhostWolf(button)
    button:SetAttribute("type", "spell");
    button:SetAttribute("spell", A.SHAMAN_GHOST_WOLF_SPELL_ID);
    A:DebugMessage("Preclick set to spell: Ghost Wolf (2645)");
end

function A:SetMountButtonCancelGhostWolf(button)
    button:SetAttribute("type", "macro");
    button:SetAttribute("macrotext", "/cancelform");
    A:DebugMessage("Preclick set to /cancelform (exit Ghost Wolf)");
end

function A:SetMountButtonIdle(button)
    -- No secure action after PreClick (RandomMount already ran in Lua)
    button:SetAttribute("type", "macro");
    button:SetAttribute("macrotext", nil);
end

--- Returns true when Shaman should use Ghost Wolf instead of trying a mount first
function A:ShamanPreferGhostWolf()
    if ( A.playerLevel < 15 ) then return nil; end
    if ( A:IsShamanInGhostWolf() ) then return nil; end

    if ( A:IsPlayerMovingForMountFallback() ) then
        return 1;
    end

    if ( IsIndoors() ) then
        return 1;
    end

    return nil;
end

--- Shaman left-click mount button (class macros enabled)
function A:PreClickMountShaman(button)
    -- Same as Blizzard spell button: second click exits the form
    if ( A:IsShamanInGhostWolf() ) then
        A:SetMountButtonCancelGhostWolf(button);
        return;
    end

    if ( A:ShamanPreferGhostWolf() ) then
        A:SetMountButtonGhostWolf(button);
        return;
    end

    -- Attempt mount in PreClick Lua; on failure cast Ghost Wolf on this same click
    A:SetMountButtonIdle(button);

    if ( A:RandomMount() ) then
        return;
    end

    if ( not IsMounted() ) then
        A:SetMountButtonGhostWolf(button);
    end
end

--- Legacy string-based shaman macro (kept for water-walking / custom callers)
function A:SetShamanPreClickMacro()
    if ( A:IsShamanInGhostWolf() ) then
        return "/cancelform";
    end

    if ( A:ShamanPreferGhostWolf() ) then
        return A:FormatMacroCast(A.SHAMAN_GHOST_WOLF_SPELL_ID, { prefix = A.macroDismountString or "/dismount [mounted]" });
    end

    return "/pammount";
end

--- Warlock pre click macro
-- For Warlocks we handle teleport and Burning Rush
function A:SetWarlockPreClickMacro()
    local demonicCircle = A:GetClassSpellID("warlockDemonicCircle");
    local burningRush = A:GetClassSpellID("warlockBurningRush");

    if ( A.playerSpecTalentsInfos["row5"] == 1 and not IsMounted() ) then
        if (  A:IsModifierDown(A.db.profile.warlockDemonicCircleModifier) ) then
            return A:FormatMacroCast(demonicCircle);
        elseif ( A:IsPlayerMovingForMountFallback() ) then
            return A:FormatMacroCast(demonicCircle, { prefix = A.macroDismountString });
        else
            return "/pammount";
        end
    elseif ( A.playerSpecTalentsInfos["row5"] == 2 ) then
        if ( A:IsPlayerMovingForMountFallback() ) then
            if ( A.db.profile.warlockWantModifier and burningRush ) then
                local rushName = A:GetMacroSpellName(burningRush);
                if ( rushName ) then
                    return ("/cancelaura [mod:%s] %s\n/stopmacro [mod:%s]\n%s\n/cast !%s")
                    :format(A.db.profile.warlockModifier, rushName, A.db.profile.warlockModifier, A.macroDismountString, rushName);
                end
            end
            return A:FormatMacroCast(burningRush, { prefix = A.macroDismountString });
        else
            return "/pammount";
        end
    else
        return "/pammount";
    end
end

--- Warrior pre click macro
-- For Warriors we handle Heroic Leap, Charge and Intervene
function A:SetWarriorPreClickMacro()
    if ( A:IsPlayerMovingForMountFallback() and A.playerLevel >= 76 ) then
        return A:FormatMacroCast(A:GetClassSpellID("warriorHeroicLeap"), { prefix = A.macroDismountString });
    else
        return "/pammount";
    end
end

--- Default pre click macro
function A:SetDefaultPreClickMacro()
    return "/pammount";
end

--[[-------------------------------------------------------------------------------
    Very basic anti grief protection (custom macro/lua)
-------------------------------------------------------------------------------]]--

-- Macro mode
A.basicProtectionCommands = { SLASH_CLICK1, SLASH_CLICK2, SLASH_CONSOLE1, SLASH_CONSOLE2, SLASH_GUILD_DISBAND1, SLASH_GUILD_DISBAND2, SLASH_GUILD_DISBAND3, SLASH_GUILD_DISBAND4,
SLASH_GUILD_LEADER1, SLASH_GUILD_LEADER2, SLASH_GUILD_LEADER3, SLASH_GUILD_LEADER4, SLASH_GUILD_LEADER_REPLACE1, SLASH_GUILD_LEADER_REPLACE2,  SLASH_GUILD_LEAVE1,
SLASH_GUILD_LEAVE2, SLASH_GUILD_LEAVE3, SLASH_GUILD_LEAVE4, SLASH_GUILD_PROMOTE1, SLASH_GUILD_PROMOTE2, SLASH_GUILD_PROMOTE3, SLASH_GUILD_PROMOTE4, SLASH_GUILD_UNINVITE1,
SLASH_GUILD_UNINVITE2, SLASH_GUILD_UNINVITE3, SLASH_GUILD_UNINVITE4, SLASH_LOGOUT1, SLASH_LOGOUT2, SLASH_LOGOUT3, SLASH_LOGOUT4, SLASH_PVP1, SLASH_PVP2, SLASH_QUIT1,
SLASH_QUIT2, SLASH_QUIT3, SLASH_QUIT4, SLASH_RELOAD1, SLASH_RELOAD2, SLASH_SCRIPT1, SLASH_SCRIPT2, SLASH_SCRIPT3, SLASH_SCRIPT4 };
function A:BasicProtectionMacro(code)
    if ( type(code) ~= "string" ) then
        return "NOT A STRING";
    end

    code = string.lower(code);

    for k,v in ipairs(A.basicProtectionCommands) do
        if ( string.find(code, v) ) then
            return v;
        end
    end

    return nil;
end

-- LUA mode
A.basicProtectionFunctions = { "Click", "SetCVar", "ConsoleExec", "GuildDisband", "GuildSetLeader", "GuildLeave", "GuildPromote", "GuildUninvite", "Logout", "Quit",
"ForceQuit", "StartAuction", "PlaceAuctionBid", "ClickAuctionSellItemButton", "SaveBindings", "PickupBagFromSlot", "PickupContainerItem", "SplitContainerItem", "DeleteCursorItem",
"DropCursorMoney", "PickupInventoryItem", "PickupItem", "PickupPlayerMoney", "PickupTradeMoney", "SetGuildBankTabPermissions", "SetGuildBankWithdrawGoldLimit", "ConfirmBindOnUse",
"AcceptSockets", "ConfirmLootRoll", "CreateMacro", "EditMacro", "DeleteInboxItem", "ReturnInboxItem", "SendMail", "BuyMerchantItem", "PickupMerchantItem", "RepairAllItems",
"DropItemOnUnit", "PetRename", "PetAbandon", "ReleasePetByID", "AbandonSkill", "RunScript", "DoTradeSkill", "AcceptTrade", "InitiateTrade", "AddTradeMoney", "PickupPlayerMoney",
"PickupTradeMoney", "SetTradeMoney", "hooksecurefunc", "loadstring" };
function A:BasicProtectionLUA(code)
    if ( type(code) ~= "string" ) then
        return "NOT A STRING";
    end

    --code = string.lower(code);

    for k,v in ipairs(A.basicProtectionFunctions) do
        if ( string.find(code, v) ) then
            return v;
        end
    end

    return nil;
end

--[[-------------------------------------------------------------------------------
    Pre click methods
-------------------------------------------------------------------------------]]--

--- Set the pre click method
function A:SetPreClickFunction(noCustom)
    if ( A.db.profile.customMountMacrosEnabled and not noCustom) then
        local name, where = GetInstanceInfo();

        -- Area types macros
        if ( tContains(A.areaTypes, where) ) then
            if ( A.db.profile.customMountMacros[where].luaMode ) then
                if ( A.db.profile.customMountMacros[where].lua.pre and A.db.profile.customMountMacros[where].lua.pre ~= "" ) then
                    local prot;

                    if ( A.db.profile.customMacrosLUAProtectionEnabled ) then
                        prot = A:BasicProtectionLUA(A.db.profile.customMountMacros[where].lua.pre);
                    end

                    if ( prot ) then
                        A:PopMessageFrame("griefScamProtectionMessageLUA", {prot, A.areaTypesLocales[where], "pre"});
                    else
                        local func, errorString = loadstring(A.db.profile.customMountMacros[where].lua.pre);

                        if ( func ) then
                            A:DebugMessage(("SetPreClickFunction() - Custom pre macro set - Mode: %s - Where: %s"):format("LUA", where));
                            A.PreClickFunc = func;
                            return;
                        else
                            A:Message(L["Your LUA custom %s macro for %s got an error. Error: %s"]:format("pre", A.areaTypesLocales[where], errorString));
                        end
                    end
                end
            else
                if ( A.db.profile.customMountMacros[where].macro.pre and A.db.profile.customMountMacros[where].macro.pre ~= "" ) then
                    local prot;

                    if ( A.db.profile.customMacrosMacroProtectionEnabled ) then
                        prot = A:BasicProtectionMacro(A.db.profile.customMountMacros[where].macro.pre);
                    end

                    if ( prot ) then
                        A:PopMessageFrame("griefScamProtectionMessageMacro", {prot, where, "pre"});
                    else
                        A.PreClickFunc = function() return A.db.profile.customMountMacros[where].macro.pre; end;
                        A:DebugMessage(("SetPreClickFunction() - Custom pre macro set - Mode: %s - Where: %s"):format("Macro", where));
                        return;
                    end
                end
            end
        end

        -- Default custom macro
        if ( A.db.profile.customMountMacros.default.luaMode ) then
            if ( A.db.profile.customMountMacros.default.lua.pre and A.db.profile.customMountMacros.default.lua.pre ~= "" ) then
                local prot;

                if ( A.db.profile.customMacrosLUAProtectionEnabled ) then
                    prot = A:BasicProtectionLUA(A.db.profile.customMountMacros.default.lua.pre);
                end

                if ( prot ) then
                    A:PopMessageFrame("griefScamProtectionMessageLUA", {prot, L["Default"], "pre"});
                else
                    local func, errorString = loadstring(A.db.profile.customMountMacros.default.lua.pre);

                    if ( func ) then
                        A:DebugMessage(("SetPreClickFunction() - Custom pre macro set - Mode: %s - Where: %s"):format("LUA", "default"));
                        A.PreClickFunc = func;
                        return;
                    else
                        A:Message(L["Your LUA custom %s macro for %s got an error. Error: %s"]:format("pre", L["Default"], errorString));
                    end
                end
            end
        else
            if ( A.db.profile.customMountMacros.default.macro.pre and A.db.profile.customMountMacros.default.macro.pre ~= "" ) then
                local prot;

                if ( A.db.profile.customMacrosMacroProtectionEnabled ) then
                    prot = A:BasicProtectionMacro(A.db.profile.customMountMacros.default.macro.pre);
                end

                if ( prot ) then
                    A:PopMessageFrame("griefScamProtectionMessageMacro", {prot, L["Default"], "pre"});
                else
                    A.PreClickFunc = function() return A.db.profile.customMountMacros.default.macro.pre; end;
                    A:DebugMessage(("SetPreClickFunction() - Custom pre macro set - Mode: %s - Where: %s"):format("Macro", "Default"));
                    return;
                end
            end
        end
    end

    if ( A.db.profile.classesMacrosEnabled and A.classSpellsOK ) then
        -- Death Knight
        if ( A.playerClass == "DEATHKNIGHT" ) then
            A.PreClickFunc = A.SetDeathKnightPreClickMacro;
        -- Druid
        elseif ( A.playerClass == "DRUID" ) then
            A.PreClickFunc = A.SetDruidPreClickMacro;
        -- Hunter
        elseif ( A.playerClass == "HUNTER" ) then
            A.PreClickFunc = A.SetHunterPreClickMacro;
        -- Mage
        elseif ( A.playerClass == "MAGE" ) then
            A.PreClickFunc = A.SetMagePreClickMacro;
        -- Monk
        elseif ( A.playerClass == "MONK" ) then
            A.PreClickFunc = A.SetMonkPreClickMacro;
        -- Paladin
        elseif ( A.playerClass == "PALADIN" ) then
            A.PreClickFunc = A.SetPaladinPreClickMacro;
        -- Priest
        elseif ( A.playerClass == "PRIEST" ) then
            A.PreClickFunc = A.SetPriestPreClickMacro;
        -- Rogue
        elseif ( A.playerClass == "ROGUE" ) then
            A.PreClickFunc = A.SetRoguePreClickMacro;
        -- Shaman
        elseif ( A.playerClass == "SHAMAN" ) then
            A.PreClickFunc = A.SetShamanPreClickMacro;
        -- Warlock
        elseif ( A.playerClass == "WARLOCK" ) then
            A.PreClickFunc = A.SetWarlockPreClickMacro;
        -- Warrior
        elseif ( A.playerClass == "WARRIOR" ) then
            A.PreClickFunc = A.SetWarriorPreClickMacro;
        -- Just in case
        else
            A.PreClickFunc = A.SetDefaultPreClickMacro;
        end
    else
        A.PreClickFunc = A.SetDefaultPreClickMacro;
    end
end

--- True when unmounted and moving (class mount-button fallbacks).
-- Prefer IsPlayerMoving(): GetUnitSpeed can be a secret value in Midnight and fail comparisons.
function A:IsPlayerMovingForMountFallback()
    if ( IsMounted() ) then
        return nil;
    end

    if ( IsPlayerMoving and IsPlayerMoving() ) then
        return 1;
    end

    local speed = GetUnitSpeed("player");
    if ( type(speed) == "number" and speed > 0 ) then
        return 1;
    end

    return nil;
end

--- Apply class fallback while moving (or shaman Ghost Wolf toggle). Returns 1 if handled.
function A:ApplyClassMovementFallback(button)
    if ( not A.db.profile.classesMacrosEnabled or A.db.profile.customMountMacrosEnabled ) then
        return nil;
    end

    -- Shaman: exit Ghost Wolf on second click even while standing still
    if ( A.playerClass == "SHAMAN" and A:IsShamanInGhostWolf() ) then
        A:PreClickMountShaman(button);
        return 1;
    end

    if ( not A:IsPlayerMovingForMountFallback() ) then
        return nil;
    end

    if ( A.playerClass == "SHAMAN" ) then
        A:PreClickMountShaman(button);
        return 1;
    end

    -- Other classes: PreClickFunc already returns the movement ability when moving
    if ( A.PreClickFunc and A.PreClickFunc ~= A.SetDefaultPreClickMacro ) then
        local macro = A:PreClickFunc();
        if ( macro and macro ~= "/pammount" ) then
            button:SetAttribute("type", "macro");
            button:SetAttribute("macrotext", macro);
            A:DebugMessage(("Preclick movement fallback: %s"):format(macro));
            return 1;
        end
    end

    return nil;
end

--- True when this PreClick phase matches ActionButtonUseKeyDown (avoid double-fire)
function A:ShouldHandleSecurePreClick(down)
    local useKeyDown = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown");
    if ( useKeyDown ) then
        return down and true or nil;
    end

    return (not down) and true or nil;
end

--- Apply a pre-click mount macro. Plain /pammount runs in Lua (reliable);
-- cast/dismount macros stay on the secure button for the same click.
function A:ApplyMountPreClickMacro(button, macro)
    if ( not macro or macro == "" or macro == "/pammount" ) then
        button:SetAttribute("type", "macro");
        button:SetAttribute("macrotext", nil);
        A:RandomMount();
        A:DebugMessage("Preclick: RandomMount() via Lua");
        return;
    end

    button:SetAttribute("type", "macro");
    button:SetAttribute("macrotext", macro);
    A:DebugMessage(("Preclick macro set to: %s"):format(tostring(macro)));
end

--- PreClick callback
-- @param down true on mouse/key down, false on up (SecureActionButton fires both when registered)
function A:PreClickMount(button, clickedBy, down)
    if ( not A.addonRunning or InCombatLockdown() ) then return; end
    if ( not A:ShouldHandleSecurePreClick(down) ) then return; end

    if ( clickedBy == "LeftButton" ) then
        -- Shift+Click: summon category in Lua
        if ( A.db.profile.mountButtonshiftClickEnabled and IsShiftKeyDown() ) then
            local cat = tonumber(A.db.profile.mountButtonshiftClickCat) or 5;
            button:SetAttribute("type", "macro");
            button:SetAttribute("macrotext", nil);
            A:ApplyShiftClickMountAttributes(button);
            A:RandomMount(cat);
            A:DebugMessage(("Preclick shift-click RandomMount(%s)"):format(tostring(cat)));
            return;
        end

        if ( A.db.profile.mountButtonControlLock and IsControlKeyDown() ) then
            button:SetAttribute("type", "macro");
            button:SetAttribute("macrotext", nil);
            A:ApplyShiftClickMountAttributes(button);
            A:ToggleButtonLock(button:GetName());
        elseif ( A:ApplyClassMovementFallback(button) ) then
            -- Moving (or shaman leaving Ghost Wolf): class ability, skip mount logic
            A:ApplyShiftClickMountAttributes(button);
            return;
        elseif ( IsMounted() ) then
            -- Still mounted (e.g. flyer in water): dismount via Lua RandomMount
            button:SetAttribute("type", "macro");
            button:SetAttribute("macrotext", nil);
            A:ApplyShiftClickMountAttributes(button);
            A:RandomMount();
            A:DebugMessage("Preclick mounted -> RandomMount() (dismount)");
        else
            -- Special mounts
            if ( A.db.profile.telaariTalbuk and A:IsTelaariTalbukUsable() and not A:IsSwimming() and not A:IsFlyable() and not IsIndoors() and not (A.db.profile.vehicleExit and A:IsPlayerInVehicle()) ) then -- 165803 - Telaari Talbuk / 164222 - Frostwolf War Wolf
                if ( A.playerFaction == "Alliance" ) then
                    if ( not A.telaariTalbukName ) then
                        local spellInfo = C_Spell.GetSpellInfo(165803);
                        A.telaariTalbukName = spellInfo and spellInfo.name;
                    end

                    button:SetAttribute("type", "macro");
                    button:SetAttribute("macrotext", ("/use %s"):format(A.telaariTalbukName or "Telaari Talbuk"));
                else
                    if ( not A.telaariTalbukName ) then
                        local spellInfo = C_Spell.GetSpellInfo(164222);
                        A.telaariTalbukName = spellInfo and spellInfo.name;
                    end

                    button:SetAttribute("type", "macro");
                    button:SetAttribute("macrotext", ("/use %s"):format(A.telaariTalbukName or "Frostwolf War Wolf"));
                end
            elseif ( A.db.profile.shimmeringMoonstone and GetItemCount(101675, nil, nil) > 0 and not A:IsSwimming() and not A:IsFlyable() and not (A.db.profile.vehicleExit and A:IsPlayerInVehicle()) ) then -- 37011 - Shimmering Moonstone from Darkmoon fair (Moonfang drop)
                if ( not A.shimmeringMoonstoneName ) then A.shimmeringMoonstoneName = GetItemInfo(101675); end

                button:SetAttribute("type", "macro");
                button:SetAttribute("macrotext", ("/use %s"):format(A.shimmeringMoonstoneName or "Shimmering Moonstone"));
            elseif ( A.db.profile.magicBroom and GetItemCount(37011, nil, nil) > 0 and (A:IsSwimming() == 2 or not A:IsSwimming()) and not (A.db.profile.vehicleExit and A:IsPlayerInVehicle()) ) then -- 37011 - Magic Broom from Hallow's End
                if ( not A.magicBroomName ) then A.magicBroomName = GetItemInfo(37011); end

                button:SetAttribute("type", "macro");
                button:SetAttribute("macrotext", ("/use %s"):format(A.magicBroomName or "Magic Broom"));
            elseif ( A.db.profile.anglersFishingRaft and PlayerHasToy(85500) and A:IsSwimming() == 2 and (A:IsEquippedFishingPole() or (ShentonFishingGlobal and ShentonFishingGlobal.isFishing)) and not (A.db.profile.vehicleExit and A:IsPlayerInVehicle()) ) then -- 85500 - Anglers Fishing Raft
                if ( not A.anglersFishingRaft ) then A.anglersFishingRaft = GetItemInfo(85500); end

                button:SetAttribute("type", "macro");
                button:SetAttribute("macrotext", ("/use %s"):format(A.anglersFishingRaft or "Anglers Fishing Raft"));
            elseif ( A.db.profile.oculusDrakes and (GetItemCount(37815, nil, nil) > 0 or GetItemCount(37859, nil, nil) > 0 or GetItemCount(37860, nil, nil) > 0)
            and (A.currentMapID == "143") and not (A.db.profile.vehicleExit and A:IsPlayerInVehicle()) ) then -- Oculus drakes: 37815 Emerald Essence - 37859 Amber Essence - 37860 Ruby Essence
                if ( GetItemCount(37815, nil, nil) > 0 ) then
                    A.oculusDrake = GetItemInfo(37815);
                elseif ( GetItemCount(37859, nil, nil) > 0 ) then
                    A.oculusDrake = GetItemInfo(37859);
                elseif ( GetItemCount(37860, nil, nil) > 0 ) then
                    A.oculusDrake = GetItemInfo(37860);
                end

                button:SetAttribute("type", "macro");
                button:SetAttribute("macrotext", ("/use %s"):format(A.oculusDrake or "Amber Essence"));
            -- Water walking spells
            elseif ( A.db.profile.surfaceMount and ((A.playerClass == "DEATHKNIGHT" and A.playerLevel >= 66)
            or (A.playerClass == "SHAMAN" and A.playerLevel >= 24)) and A:IsSwimming() == 2 and A.classSpellsOK ) then
                if ( A.db.profile.preferSurfaceSpell or (not A.db.profile.preferSurfaceSpell and not A:GotMountAllTable(6)) ) then
                    if ( A.playerClass == "DEATHKNIGHT" and not A:PlayerGotBuff(A:GetClassSpellID("deathKnightPathOfFrost")) ) then
                        local macro = A:FormatMacroCast(A:GetClassSpellID("deathKnightPathOfFrost"), { bang = true });
                        button:SetAttribute("type", "macro");
                        button:SetAttribute("macrotext", macro);
                        A:DebugMessage(("Preclick macro set to: %s"):format(macro));
                    elseif ( A.playerClass == "SHAMAN" ) then
                        local waterWalkingID = A:GetClassSpellID("shamanWaterWalking");
                        if ( A:PlayerGotBuff(waterWalkingID) ) then
                            if ( A.db.profile.classesMacrosEnabled ) then
                                A:PreClickMountShaman(button);
                            else
                                A:ApplyMountPreClickMacro(button, A:PreClickFunc());
                            end
                        else
                            local macro = A:FormatMacroCast(waterWalkingID);
                            button:SetAttribute("type", "macro");
                            button:SetAttribute("macrotext", macro);
                            A:DebugMessage(("Preclick macro set to: %s"):format(macro));
                        end
                    else
                        A:ApplyMountPreClickMacro(button, A:PreClickFunc());
                    end
                else
                    if ( A.playerClass == "SHAMAN" and A.db.profile.classesMacrosEnabled ) then
                        A:PreClickMountShaman(button);
                    else
                        A:ApplyMountPreClickMacro(button, A:PreClickFunc());
                    end
                end
            else
                if ( A.playerClass == "SHAMAN" and A.db.profile.classesMacrosEnabled and not A.db.profile.customMountMacrosEnabled ) then
                    A:PreClickMountShaman(button);
                else
                    A:ApplyMountPreClickMacro(button, A:PreClickFunc());
                end
            end

            A:ApplyShiftClickMountAttributes(button);
        end
    elseif ( clickedBy == "RightButton" ) then
        button:SetAttribute("type", "macro");
        button:SetAttribute("macrotext", nil);
        A:ApplyShiftClickMountAttributes(button);

        local point, relativePoint = A:GetMenuButtonAnchor();

        UIDropDownMenu_SetAnchor(A.menuFrame, 0, 0, point, button, relativePoint);
        ToggleDropDownMenu(1, nil, A.menuFrame, button);
        GameTooltip:Hide();
    elseif ( clickedBy == "MiddleButton" ) then
        button:SetAttribute("type", "macro");
        button:SetAttribute("macrotext", nil);
        A:ApplyShiftClickMountAttributes(button);
        A:OpenConfigPanel();
    end
end

function A:PreClickMountForced(button, clickedBy, down)
    if ( not A.addonRunning or InCombatLockdown() ) then return; end
    if ( not A:ShouldHandleSecurePreClick(down) ) then return; end

    -- Get mount summon command
    local command, isCustom = A:GetMountCommand(button);

    -- Death Knight
    --if ( A.playerClass == "DEATHKNIGHT" ) then
    -- Druid
    if ( A.playerClass == "DRUID" ) then
        if ( GetShapeshiftForm(1) > 0 and not A:IsBoomkin() ) then
            if ( A.db.profile.noMountAfterCancelForm ) then
                command = "/cancelform [form]";
            else
                command = ("/cancelform [form]\n%s"):format(command);
            end
        end
    -- Shaman
    elseif ( A.playerClass == "SHAMAN" ) then
        if ( A.db.profile.noMountAfterCancelForm ) then
            command = "/cancelform [form]";
        else
            command = ("/cancelform [form]\n%s"):format(command);
        end
    end

    -- Prefer Lua summon for plain /pam* commands (same KeyDown reliability as /pammount)
    local catByCommand =
    {
        ["/pammount"] = true,
        ["/pamground"] = 1,
        ["/pamfly"] = 2,
        ["/pamhybrid"] = 3,
        ["/pamaquatic"] = 4,
        ["/pampassengers"] = 5,
        ["/pamsurface"] = 6,
        ["/pamrepair"] = 7,
    };
    local cat = catByCommand[command];
    if ( cat ~= nil ) then
        button:SetAttribute("type", "macro");
        button:SetAttribute("macrotext", nil);
        if ( cat == true ) then
            A:RandomMount();
        else
            A:RandomMount(cat);
        end
        A:DebugMessage(("Preclick forced: RandomMount(%s)"):format(tostring(cat == true and "auto" or cat)));
        return;
    end

    button:SetAttribute("type", "macro");
    button:SetAttribute("macrotext", command);
end

--[[-------------------------------------------------------------------------------
    Post clicks methods
-------------------------------------------------------------------------------]]--

-- Post click macro
function A:SetPostClickMacro(noCustom)
    if ( A.db.profile.customMountMacrosEnabled and not noCustom) then
        local name, where = GetInstanceInfo();

        -- Area types macros
        if ( tContains(A.areaTypes, where) ) then
            if ( A.db.profile.customMountMacros[where].luaMode ) then
                if ( A.db.profile.customMountMacros[where].lua.post and A.db.profile.customMountMacros[where].lua.post ~= "" ) then
                    local prot;

                    if ( A.db.profile.customMacrosLUAProtectionEnabled ) then
                        prot = A:BasicProtectionLUA(A.db.profile.customMountMacros[where].lua.post);
                    end

                    if ( prot ) then
                        A:PopMessageFrame("griefScamProtectionMessageLUA", {prot, A.areaTypesLocales[where], "post"});
                    else
                        local func, errorString = loadstring(A.db.profile.customMountMacros[where].lua.post);

                        if ( func ) then
                            A:DebugMessage(("SetPreClickFunction() - Custom post macro set - Mode: %s - Where: %s"):format("LUA", where));
                            A.postClickMacro =  func();
                            return;
                        else
                            A:Message(L["Your LUA custom %s macro for %s got an error. Error: %s"]:format("post", A.areaTypesLocales[where], errorString));
                        end
                    end
                end
            else
                if ( A.db.profile.customMountMacros[where].macro.post and A.db.profile.customMountMacros[where].macro.post ~= "" ) then
                    local prot;

                    if ( A.db.profile.customMacrosMacroProtectionEnabled ) then
                        prot = A:BasicProtectionMacro(A.db.profile.customMountMacros[where].macro.post);
                    end

                    if ( prot ) then
                        A:PopMessageFrame("griefScamProtectionMessageMacro", {prot, where, "post"});
                    else
                        A:DebugMessage(("SetPreClickFunction() - Custom post macro set - Mode: %s - Where: %s"):format("Macro", where));
                        A.postClickMacro = A.db.profile.customMountMacros[where].macro.post;
                        return;
                    end
                end
            end
        end

        -- Default custom macro
        if ( A.db.profile.customMountMacros.default.luaMode ) then
            if ( A.db.profile.customMountMacros.default.lua.post and A.db.profile.customMountMacros.default.lua.post ~= "" ) then
                if ( A.db.profile.customMountMacros[where].lua.post and A.db.profile.customMountMacros[where].lua.post ~= "" ) then
                    local prot;

                    if ( A.db.profile.customMacrosLUAProtectionEnabled ) then
                        prot = A:BasicProtectionLUA(A.db.profile.customMountMacros.default.lua.post);
                    end

                    if ( prot ) then
                        A:PopMessageFrame("griefScamProtectionMessageLUA", {prot, L["Default"], "post"});
                    else
                        local func, errorString = loadstring(A.db.profile.customMountMacros.default.lua.post);

                        if ( func ) then
                            A:DebugMessage(("SetPreClickFunction() - Custom post macro set - Mode: %s - Where: default"):format("LUA"));
                            A.postClickMacro =  func();
                            return;
                        else
                            A:Message(L["Your LUA custom %s macro for %s got an error. Error: %s"]:format("post", L["Default"], errorString));
                        end
                    end
                end
            end
        else
            if ( A.db.profile.customMountMacros.default.macro.post and A.db.profile.customMountMacros.default.macro.post ~= "" ) then
                local prot;

                if ( A.db.profile.customMacrosMacroProtectionEnabled ) then
                    prot = A:BasicProtectionMacro(A.db.profile.customMountMacros.default.macro.post);
                end

                if ( prot ) then
                    A:PopMessageFrame("griefScamProtectionMessageMacro", {prot, L["Default"], "post"});
                else
                    A:DebugMessage(("SetPreClickFunction() - Custom post macro set - Mode: %s - Where: %s"):format("Macro", "default"));
                    A.postClickMacro = A.db.profile.customMountMacros.default.macro.post;
                    return;
                end
            end
        end
    end

    if ( A.db.profile.classesMacrosEnabled and A.classSpellsOK ) then
        -- Death Knight
        if ( A.playerClass == "DEATHKNIGHT" ) then
            if ( A.playerLevel >= 60 ) then
                A.postClickMacro = A:FormatMacroCast(A:GetClassSpellID("deathKnightWraithWalk"), {
                    prefix = A.macroDismountString,
                    condition = "[nomounted]",
                });
            else
                A.postClickMacro = A.macroDismountString;
            end
        -- Druid
        elseif ( A.playerClass == "DRUID" ) then
            if ( A.playerLevel >= 16 ) then
                A.postClickMacro = A:FormatMacroCastChain({
                    { condition = "[nomounted,indoors]", id = A:GetClassSpellID("druidCatForm") },
                    { condition = "[nomounted]", id = A:GetClassSpellID("druidTravelForm") },
                }, { prefix = A.macroDismountString });
            elseif ( A.playerLevel >= 6 ) then
                A.postClickMacro = A:FormatMacroCast(A:GetClassSpellID("druidCatForm"), { prefix = A.macroDismountString });
            else
                A.postClickMacro = A.macroDismountString;
            end
        -- Hunter
        elseif ( A.playerClass == "HUNTER" ) then
            if ( A.playerLevel >= 5 ) then
                A.postClickMacro = A:FormatMacroCast(A:GetClassSpellID("hunterAspectCheetah"), {
                    prefix = A.macroDismountString,
                    condition = "[nomounted]",
                });
            else
                A.postClickMacro = A.macroDismountString;
            end
        -- Mage
        elseif ( A.playerClass == "MAGE" ) then
            if ( A.db.profile.mageForceSlowFall ) then
                A.postClickMacro = A:FormatMacroCast(A:GetClassSpellID("mageSlowFall"), {
                    prefix = A.macroDismountString,
                    condition = "[nomounted]",
                });
            else
                if ( A.playerLevel >= 7 ) then
                    A.postClickMacro = A:FormatMacroCast(A:GetClassSpellID("mageBlink"), {
                        prefix = A.macroDismountString,
                        condition = "[nomounted]",
                    });
                else
                    A.postClickMacro = A.macroDismountString;
                end
            end
        -- Monk
        elseif ( A.playerClass == "MONK" ) then
            if ( A.db.profile.monkPreferSerpentKick and A.playerLevel >= 18 and A.playerSpecTalentsInfos["spec"] == 3 ) then
                A.postClickMacro = A:FormatMacroCast(A:GetClassSpellID("monkFlyingSerpentKick"), {
                    prefix = A.macroDismountString,
                    condition = "[nomounted]",
                });
            elseif ( A.playerLevel >= 5 ) then
                A.postClickMacro = A:FormatMacroCast(A:GetClassSpellID("monkRoll"), {
                    prefix = A.macroDismountString,
                    condition = "[nomounted]",
                });
            else
                A.postClickMacro = A.macroDismountString;
            end
        -- Paladin
        elseif ( A.playerClass == "PALADIN" ) then
            if ( A.playerLevel >= 28 ) then
                A.postClickMacro = A:FormatMacroCast(A:GetClassSpellID("paladinDivineSteed"), {
                    prefix = A.macroDismountString,
                    condition = "[nomounted]",
                });
            else
                A.postClickMacro = A.macroDismountString;
            end
        -- Priest
        elseif ( A.playerClass == "PRIEST" ) then
            if ( A.db.profile.priestForceLevitate ) then
                A.postClickMacro = A:FormatMacroCast(A:GetClassSpellID("priestLevitate"), {
                    prefix = A.macroDismountString,
                    condition = "[nomounted]",
                });
            else
                if ( (A.playerSpecTalentsInfos["spec"] == 1 or A.playerSpecTalentsInfos["spec"] == 3) and A.playerSpecTalentsInfos["row2"] == 2) then -- Body And Soul
                    A.postClickMacro = A:FormatMacroCast(A:GetClassSpellID("priestPowerWordShield"), {
                        prefix = A.macroDismountString,
                        condition = "[nomounted]",
                    });
                elseif ( (A.playerSpecTalentsInfos["spec"] == 1 or A.playerSpecTalentsInfos["spec"] == 2) and A.playerSpecTalentsInfos["row2"] == 1) then -- Angelic Feather
                    A.postClickMacro = A:FormatMacroCast(A:GetClassSpellID("priestAngelicFeather"), {
                        prefix = A.macroDismountString,
                        condition = "[nomounted]",
                    });
                else
                    A.postClickMacro = A.macroDismountString;
                end
            end
        -- Rogue
        elseif ( A.playerClass == "ROGUE" ) then
            if ( A.playerLevel >= 26 ) then
                A.postClickMacro = A:FormatMacroCast(A:GetClassSpellID("rogueSprint"), {
                    prefix = A.macroDismountString,
                    condition = "[nomounted]",
                });
            else
                A.postClickMacro = A.macroDismountString;
            end
        -- Shaman
        elseif ( A.playerClass == "SHAMAN" ) then
            if ( A.playerLevel >= 15 ) then
                A.postClickMacro = A:FormatMacroCast(A:GetClassSpellID("shamanGhostWolf"), {
                    prefix = A.macroDismountString,
                    condition = "[nomounted]",
                });
            else
                A.postClickMacro = A.macroDismountString;
            end
        -- Warlock
        elseif ( A.playerClass == "WARLOCK" ) then
            local demonicCircle = A:GetClassSpellID("warlockDemonicCircle");
            local burningRush = A:GetClassSpellID("warlockBurningRush");

            if ( A.playerSpecTalentsInfos["row5"] == 1 ) then
                A.postClickMacro = A:FormatMacroCast(demonicCircle, {
                    prefix = A.macroDismountString,
                    condition = "[nomounted]",
                });
            elseif ( A.playerSpecTalentsInfos["row5"] == 2 ) then
                if ( A.db.profile.warlockWantModifier and burningRush ) then
                    local rushName = A:GetMacroSpellName(burningRush);
                    if ( rushName ) then
                        A.postClickMacro = ("%s\n/cast [nomounted,novehicleui,nomod] !%s\n/cancelaura [nomounted,novehicleui,mod:%s] %s")
                        :format(A.macroDismountString, rushName, A.db.profile.warlockModifier, rushName);
                    else
                        A.postClickMacro = A:FormatMacroCast(burningRush, {
                            prefix = A.macroDismountString,
                            condition = "[nomounted]",
                        });
                    end
                else
                    A.postClickMacro = A:FormatMacroCast(burningRush, {
                        prefix = A.macroDismountString,
                        condition = "[nomounted]",
                    });
                end
            else
                A.postClickMacro = A.macroDismountString;
            end
        -- Warrior
        elseif ( A.playerClass == "WARRIOR" ) then
            if ( A.db.profile.warriorForceHeroicLeap and A.playerLevel >= 76 ) then
                A.postClickMacro = A:FormatMacroCast(A:GetClassSpellID("warriorHeroicLeap"), {
                    prefix = A.macroDismountString,
                    condition = "[nomounted]",
                });
            else
                if ( A.playerSpecTalentsInfos["spec"] == 3 and A.playerLevel >= 72 ) then
                    A.postClickMacro = A:FormatMacroCast(A:GetClassSpellID("warriorIntercept"), {
                        prefix = A.macroDismountString,
                        condition = "[nomounted]",
                    });
                elseif ( (A.playerSpecTalentsInfos["spec"] == 1 or A.playerSpecTalentsInfos["spec"] == 2) and A.playerLevel >= 3 ) then
                    A.postClickMacro = A:FormatMacroCast(A:GetClassSpellID("warriorCharge"), {
                        prefix = A.macroDismountString,
                        condition = "[nomounted]",
                    });
                else
                    A.postClickMacro = A.macroDismountString;
                end
            end
        else
            A.postClickMacro = A.macroDismountString;
        end
    else
        A.postClickMacro = A.macroDismountString;
    end

    -- Fire the Post Click callback to update the button macro
    A:PostClickMount(PetsAndMountsSecureButtonMounts);

    A:DebugMessage(("Postclick macro set to: %s"):format(A.postClickMacro));
end

--- PostClick callback
-- Applies A.postClickMacro for the *next* click. Out of combat, PreClick usually
-- overwrites macrotext again; this mainly matters in combat (PreClick cannot change attributes).
function A:PostClickMount(button, clickedBy)
    if ( not A.addonRunning or InCombatLockdown() ) then return; end

    button:SetAttribute("type", "macro");
    button:SetAttribute("macrotext", A.postClickMacro);
end

--[[-------------------------------------------------------------------------------
    Pets button pre & post clicks
-------------------------------------------------------------------------------]]--

--- PreClick callback
function A:PreClickPet(button, clickedBy, down)
    if ( not A.addonRunning or InCombatLockdown() ) then return; end
    if ( not A:ShouldHandleSecurePreClick(down) ) then return; end

    if ( clickedBy == "LeftButton" ) then
        if ( IsShiftKeyDown() ) then
            button:SetAttribute("type", "macro");
            button:SetAttribute("macrotext", nil);
            A:RevokePet(1);
        elseif ( IsControlKeyDown() ) then
            button:SetAttribute("type", "macro");
            button:SetAttribute("macrotext", nil);
            A:ToggleButtonLock(button:GetName());
        else
            button:SetAttribute("type", "macro");
            button:SetAttribute("macrotext", nil);
            A:RandomPet(1);
            A:DebugMessage("Preclick pet: RandomPet() via Lua");
        end
    elseif ( clickedBy == "RightButton" ) then
        button:SetAttribute("type", "macro");
        button:SetAttribute("macrotext", nil);

        local point, relativePoint = A:GetMenuButtonAnchor();

        UIDropDownMenu_SetAnchor(A.menuFrame, 0, 0, point, button, relativePoint);
        ToggleDropDownMenu(1, nil, A.menuFrame, button);

        GameTooltip:Hide();
    elseif ( clickedBy == "MiddleButton" ) then
        button:SetAttribute("type", "macro");
        button:SetAttribute("macrotext", nil);
        A:OpenConfigPanel();
    end
end

--[[-------------------------------------------------------------------------------
    Pets and Mounts clickable buttons methods
-------------------------------------------------------------------------------]]--

--- Set button position
function A:SetButtonPos(button)
    if ( InCombatLockdown() ) then
        A:Message(L["Unable to edit buttons while in combat."], 1);
        return;
    end

    if ( type(button) ~= "string" ) then
        button = button:GetName();
    end

    _G[button]:ClearAllPoints();
    _G[button]:SetPoint(A.db.profile[button].anchor.point, A.db.profile[button].anchor.relativeTo, A.db.profile[button].anchor.relativePoint, A.db.profile[button].anchor.offX, A.db.profile[button].anchor.offY);
end

--- Lock button
function A:LockButton(button)
    if ( InCombatLockdown() ) then
        A:Message(L["Unable to edit buttons while in combat."], 1);
        return;
    end

    if ( type(button) ~= "string" ) then
        button = button:GetName();
    end

    local b = _G[button];
    b:SetMovable(false);
    b:RegisterForDrag();
    b:SetScript("OnDragStart", nil);
    b:SetScript("OnDragStop", nil);
    A.db.profile[button].lock = true;

    if ( A.AceConfigRegistry ) then
        A:NotifyChangeForAll();
    end
end

--- Unlock button, saving position
function A:UnlockButton(button)
    if ( InCombatLockdown() ) then
        A:Message(L["Unable to edit buttons while in combat."], 1);
        return;
    end

    if ( type(button) ~= "string" ) then
        button = button:GetName();
    end

    if ( A.db.profile.dockButton and button == "PetsAndMountsSecureButtonPets" ) then return; end

    local b = _G[button];
    b:SetMovable(true);
    b:RegisterForDrag("LeftButton");
    b:SetScript("OnDragStart", b.StartMoving);
    b:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing();

        local point, relativeTo, relativePoint, offX, offY = self:GetPoint(1);

        A.db.profile[button].anchor.point = point;
        A.db.profile[button].anchor.relativeTo = relativeTo;
        A.db.profile[button].anchor.relativePoint = relativePoint;
        A.db.profile[button].anchor.offX = offX;
        A.db.profile[button].anchor.offY = offY;
    end);
    A.db.profile[button].lock = nil;

    if ( A.AceConfigRegistry ) then
        A:NotifyChangeForAll();
    end
end

--- Toggle lock button
function A:ToggleButtonLock(button)
    if ( InCombatLockdown() ) then
        A:Message(L["Unable to edit buttons while in combat."], 1);
        return;
    end

    if ( type(button) ~= "string" ) then
        button = button:GetName();
    end

    if ( _G[button]:IsMovable() ) then
        A:LockButton(button);
    else
        A:UnlockButton(button);
    end
end

--- Button hide/show toggle
function A:ToggleButtonHideShow(button)
    if ( InCombatLockdown() ) then
        A:Message(L["Unable to edit buttons while in combat."], 1);
        return;
    end

    if ( type(button) ~= "string" ) then
        button = button:GetName();
    end

    if ( _G[button]:IsShown() ) then
        _G[button]:Hide();
        A.db.profile[button].hide = 1;
    else
        _G[button]:Show();
        A.db.profile[button].hide = nil;
    end

    if ( A.AceConfigRegistry ) then
        A:NotifyChangeForAll();
    end
end

--- Dock buttons together
function A:DockButton()
    if ( InCombatLockdown() ) then
        A:Message(L["Unable to edit buttons while in combat."], 1);
        return;
    end

    A.db.profile.PetsAndMountsSecureButtonPets.anchor =
    {
        point = A.dockButtonsAnchors[A.db.profile.dockAnchor][1],
        relativeTo = "PetsAndMountsSecureButtonMounts",
        relativePoint = A.dockButtonsAnchors[A.db.profile.dockAnchor][2],
        offX = A.dockButtonsAnchors[A.db.profile.dockAnchor][3],
        offY = A.dockButtonsAnchors[A.db.profile.dockAnchor][4],
    };

    A:LockButton("PetsAndMountsSecureButtonPets")
    A:SetButtonPos("PetsAndMountsSecureButtonPets");
end

--- Dock buttons together
function A:UnDockButton()
    if ( InCombatLockdown() ) then
        A:Message(L["Unable to edit buttons while in combat."], 1);
        return;
    end

    local point, relativeTo, relativePoint, offX, offY = PetsAndMountsSecureButtonMounts:GetPoint(1);

    offX = offX + 40

    A.db.profile.PetsAndMountsSecureButtonPets.anchor =
    {
        point = point,
        relativeTo = relativeTo,
        relativePoint = relativePoint,
        offX = offX,
        offY = offY,
    };

    A:SetButtonPos("PetsAndMountsSecureButtonPets");
end

--- Reset button
function A:ResetButton(button)
    if ( InCombatLockdown() ) then
        A:Message(L["Unable to edit buttons while in combat."], 1);
        return;
    end

    if ( type(button) ~= "string" ) then
        button = button:GetName();
    end

    local offX;

    if ( button == "PetsAndMountsSecureButtonPets" ) then
        offX = 20;
        A.db.profile.dockButton = nil;
    elseif ( button == "PetsAndMountsSecureButtonMounts" ) then
        offX = -20
    else
        offX = 0;
    end

    A.db.profile[button] =
    {
        hide = nil,
        lock = nil,
        tooltip = 1,
        scale = 1,
        anchor =
        {
            point = "CENTER",
            relativeTo = "UIParent",
            relativePoint = "CENTER",
            offX = offX,
            offY = 0,
        },
    };

    A:SetButtons();
end

function A:SetButtonsIcons()
    if ( InCombatLockdown() ) then
        A:Message(L["Unable to edit buttons while in combat."], 1);
        return;
    end

    if ( A.db.profile.petButtonIconCurrent and A.currentPetIcon ) then
        PetsAndMountsSecureButtonPets.icon:SetTexture(A.currentPetIcon);
    else
        PetsAndMountsSecureButtonPets.icon:SetTexture("Interface\\ICONS\\"..A.db.profile.petButtonIcon);
    end

    if ( A.db.profile.mountButtonIconCurrent and A.currentMountIcon ) then
        PetsAndMountsSecureButtonMounts.icon:SetTexture(A.currentMountIcon);
    else
        PetsAndMountsSecureButtonMounts.icon:SetTexture("Interface\\ICONS\\"..A.db.profile.mountButtonIcon);
    end
end

--- Set buttons on login
function A:SetButtons()
    if ( InCombatLockdown() ) then
        A:Message(L["Unable to edit buttons while in combat."], 1);
        return;
    end

    -- Position
    A:SetButtonPos("PetsAndMountsSecureButtonPets");
    A:SetButtonPos("PetsAndMountsSecureButtonMounts");

    -- Scale
    PetsAndMountsSecureButtonPets:SetScale(A.db.profile.PetsAndMountsSecureButtonPets.scale);
    PetsAndMountsSecureButtonMounts:SetScale(A.db.profile.PetsAndMountsSecureButtonMounts.scale);

    -- Visibility
    if ( A.db.profile.PetsAndMountsSecureButtonPets.hide ) then
        PetsAndMountsSecureButtonPets:Hide();

        if (  A.db.profile.dockButton ) then
            A.db.profile.dockButton = nil;
            A:UnDockButton();
        end
    else
        PetsAndMountsSecureButtonPets:Show();
    end

    if ( A.db.profile.PetsAndMountsSecureButtonMounts.hide ) then
        PetsAndMountsSecureButtonMounts:Hide();

        if (  A.db.profile.dockButton ) then
            A.db.profile.dockButton = nil;
            A:UnDockButton();

            if ( not A.db.profile.PetsAndMountsSecureButtonMounts.lock and A.db.profile.PetsAndMountsSecureButtonPets.lock ) then
                A.db.profile.PetsAndMountsSecureButtonPets.lock = nil;
                A:SetButtons();
                return;
            end
        end
    else
        PetsAndMountsSecureButtonMounts:Show();
    end

    -- Movable
    if ( A.db.profile.PetsAndMountsSecureButtonPets.lock ) then
        A:LockButton("PetsAndMountsSecureButtonPets");
    else
        A:UnlockButton("PetsAndMountsSecureButtonPets");
    end

    if ( A.db.profile.PetsAndMountsSecureButtonMounts.lock ) then
        A:LockButton("PetsAndMountsSecureButtonMounts");
    else
        A:UnlockButton("PetsAndMountsSecureButtonMounts");
    end

    -- Icon

    -- Explicit SetScript + SetAttribute required for SecureActionButtonTemplate (WoW 12.0+)
    PetsAndMountsSecureButtonPets:RegisterForClicks("AnyUp", "AnyDown");
    PetsAndMountsSecureButtonPets:SetScript("PreClick", function(self, button, down)
        A:PreClickPet(self, button, down);
    end);
    PetsAndMountsSecureButtonPets:SetAttribute("type", "macro");
    PetsAndMountsSecureButtonPets:SetAttribute("macrotext", "/pampet");

    PetsAndMountsSecureButtonMounts:RegisterForClicks("AnyUp", "AnyDown");
    PetsAndMountsSecureButtonMounts:SetScript("PreClick", function(self, button, down)
        A:PreClickMount(self, button, down);
    end);
    PetsAndMountsSecureButtonMounts:SetScript("PostClick", function(self, button, down)
        if ( not A:ShouldHandleSecurePreClick(down) ) then return; end
        A:PostClickMount(self, button);
    end);
    PetsAndMountsSecureButtonMounts:SetAttribute("type", "macro");
    PetsAndMountsSecureButtonMounts:SetAttribute("macrotext", "/pammount");
    A:ApplyShiftClickMountAttributes(PetsAndMountsSecureButtonMounts);

    -- Other mount buttons too
    local forcedButtons = {
        PetsAndMountsSecureButtonPassengers,
        PetsAndMountsSecureButtonFlying,
        PetsAndMountsSecureButtonGround,
        PetsAndMountsSecureButtonAquatic,
        PetsAndMountsSecureButtonSurface,
        PetsAndMountsSecureButtonRepair,
        PetsAndMountsSecureButtonHybrid,
    };
    for _, forcedButton in ipairs(forcedButtons) do
        forcedButton:RegisterForClicks("AnyUp", "AnyDown");
        forcedButton:SetScript("PreClick", function(self, button, down)
            A:PreClickMountForced(self, button, down);
        end);
    end

    -- Refresh config panel
    A:NotifyChangeForAll();
end

--[[-------------------------------------------------------------------------------
    Tooltips
-------------------------------------------------------------------------------]]--

--- Display button tooltip
function A:SetTooltip(frame)
    if ( not A.db.profile.PetsAndMountsSecureButtonPets.tooltip and frame:GetName() == "PetsAndMountsSecureButtonPets" ) then return; end
    if ( not A.db.profile.PetsAndMountsSecureButtonMounts.tooltip and frame:GetName() == "PetsAndMountsSecureButtonMounts" ) then return; end

    local currentSet, forcedInfo1, forcedInfo2, forcedInfo3, forcedInfo4, forcedInfo5;

    if ( frame:GetRight() >= ( GetScreenWidth() / 2 ) ) then
        GameTooltip:SetOwner(frame, "ANCHOR_LEFT");
    else
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT");
    end

    GameTooltip:AddDoubleLine(A.color["WHITE"]..L["Pets & Mounts"], A.color["GREEN"].."v"..A.version);
    GameTooltip:AddLine(" ");

    if ( frame:GetName() == "PetsAndMountsSecureButtonPets" ) then
        currentSet = A:GetSetsInUse("PETS");

        if ( currentSet == L["None"] ) then
            currentSet = A.color["RED"]..currentSet;
        else
            currentSet = A.color["GREEN"]..currentSet;
        end

        if ( A.db.profile.forceOne.pet and A:GetPetNameByID(A.db.profile.forceOne.pet) ) then
            forcedInfo1 = A.color["GREEN"]..A:GetPetNameByID(A.db.profile.forceOne.pet);
        else
            forcedInfo1 = A.color["RED"]..L["None"];
        end

        GameTooltip:AddLine(L["Companions set in use: %s."]:format(currentSet));
        GameTooltip:AddLine(L["Auto summon companion is %s."]:format(A:IsAutoPetEnabled() and A.color["GREEN"]..L["On"] or A.color["RED"]..L["Off"]));
        GameTooltip:AddLine(L["Not when stealthed is %s."]:format(A:IsNotWhenStealthedEnabled() and A.color["GREEN"]..L["On"] or A.color["RED"]..L["Off"]));
        GameTooltip:AddLine(L["Forced companion: %s"]:format(forcedInfo1));
        GameTooltip:AddLine(" ");
        GameTooltip:AddLine(L["|cFFC79C6ELeft-Click: |cFF33FF99Summon a random companion.\n|cFFC79C6EShift+Left-Click: |cFF33FF99Revoke current companion.\n|cFFC79C6EControl+Left-Click: |cFF33FF99Toggle button lock.\n|cFFC79C6ERight-Click: |cFF33FF99Open the menu.\n|cFFC79C6EMiddle-Click: |cFF33FF99Open configuration panel."]);
    elseif ( frame:GetName() == "PetsAndMountsSecureButtonMounts" ) then
        currentSet = A:GetSetsInUse("MOUNTS");

        if ( currentSet == L["None"] ) then
            currentSet = A.color["RED"]..currentSet;
        else
            currentSet = A.color["GREEN"]..currentSet;
        end

        if ( A.db.profile.forceOne.mount[4] and A:GetMountNameBySpellID(A.db.profile.forceOne.mount[4]) ) then
            forcedInfo1 = A.color["GREEN"]..A:GetMountNameBySpellID(A.db.profile.forceOne.mount[4]);
        else
            forcedInfo1 = A.color["RED"]..L["None"];
        end

        if ( A.db.profile.forceOne.mount[1] and A:GetMountNameBySpellID(A.db.profile.forceOne.mount[1]) ) then
            forcedInfo2 = A.color["GREEN"]..A:GetMountNameBySpellID(A.db.profile.forceOne.mount[1]);
        else
            forcedInfo2 = A.color["RED"]..L["None"];
        end

        if ( A.db.profile.forceOne.mount[2] and A:GetMountNameBySpellID(A.db.profile.forceOne.mount[2]) ) then
            forcedInfo3 = A.color["GREEN"]..A:GetMountNameBySpellID(A.db.profile.forceOne.mount[2]);
        else
            forcedInfo3 = A.color["RED"]..L["None"];
        end

        if ( A.db.profile.forceOne.mount[3] and A:GetMountNameBySpellID(A.db.profile.forceOne.mount[3]) ) then
            forcedInfo4 = A.color["GREEN"]..A:GetMountNameBySpellID(A.db.profile.forceOne.mount[3]);
        else
            forcedInfo4 = A.color["RED"]..L["None"];
        end

        if ( A.db.profile.forceOne.mount[5] and A:GetMountNameBySpellID(A.db.profile.forceOne.mount[5]) ) then
            forcedInfo5 = A.color["GREEN"]..A:GetMountNameBySpellID(A.db.profile.forceOne.mount[5]);
        else
            forcedInfo5 = A.color["RED"]..L["None"];
        end
        GameTooltip:AddLine(L["Mounts set in use: %s."]:format(currentSet));
        GameTooltip:AddLine(L["Forced aquatic mount: %s"]:format(forcedInfo1));
        GameTooltip:AddLine(L["Forced ground mount: %s"]:format(forcedInfo2));
        GameTooltip:AddLine(L["Forced fly mount: %s"]:format(forcedInfo3));
        GameTooltip:AddLine(L["Forced hybrid mount: %s"]:format(forcedInfo4));
        GameTooltip:AddLine(L["Forced passenger mount: %s"]:format(forcedInfo5));
        GameTooltip:AddLine(" ");

        if ( A.db.profile.dockButton ) then
            GameTooltip:AddLine(L["Use me to move both buttons."]);
            GameTooltip:AddLine(" ");
        end

        if ( A.db.profile.mountButtonshiftClickEnabled and A.db.profile.mountButtonControlLock) then
            GameTooltip:AddLine(L["|cFFC79C6ELeft-Click: |cFF33FF99Summon a random mount.\n|cFFC79C6EShift+Left-Click: |cFF33FF99Summon a %s mount.\n|cFFC79C6EControl+Click: |cFF33FF99Lock or unlock the button\n|cFFC79C6ERight-Click: |cFF33FF99Open the menu.\n|cFFC79C6EMiddle-Click: |cFF33FF99Open configuration panel."]:format(A.mountCat[A.db.profile.mountButtonshiftClickCat]));
        elseif ( A.db.profile.mountButtonControlLock ) then
            GameTooltip:AddLine(L["|cFFC79C6ELeft-Click: |cFF33FF99Summon a random mount.\n|cFFC79C6EControl+Click: |cFF33FF99Lock or unlock the button\n|cFFC79C6ERight-Click: |cFF33FF99Open the menu.\n|cFFC79C6EMiddle-Click: |cFF33FF99Open configuration panel."]);
        elseif ( A.db.profile.mountButtonshiftClickEnabled ) then
            GameTooltip:AddLine(L["|cFFC79C6ELeft-Click: |cFF33FF99Summon a random mount.\n|cFFC79C6EShift+Left-Click: |cFF33FF99Summon a %s mount.\n|cFFC79C6ERight-Click: |cFF33FF99Open the menu.\n|cFFC79C6EMiddle-Click: |cFF33FF99Open configuration panel."]:format(A.mountCat[A.db.profile.mountButtonshiftClickCat]));
        else
            GameTooltip:AddLine(L["|cFFC79C6ELeft-Click: |cFF33FF99Summon a random mount.\n|cFFC79C6ERight-Click: |cFF33FF99Open the menu.\n|cFFC79C6EMiddle-Click: |cFF33FF99Open configuration panel."]);
        end
    end

    GameTooltip:Show();
end

--[[-------------------------------------------------------------------------------
    Masque support
-------------------------------------------------------------------------------]]--

local MasqueLoaded = false;

local function SetupMasque()
    if ( MasqueLoaded ) then return; end
    local masque = LibStub("Masque", true);
    if ( not masque ) then return; end
    MasqueLoaded = true;
    masque:Group(L["Pets & Mounts"], L["Mounts button"]):AddButton(PetsAndMountsSecureButtonMounts);
    masque:Group(L["Pets & Mounts"], L["Companions button"]):AddButton(PetsAndMountsSecureButtonPets);
end

local masqueFrame = CreateFrame("Frame");
masqueFrame:RegisterEvent("ADDON_LOADED");
masqueFrame:SetScript("OnEvent", function(self, event, addonName)
    if ( addonName == "PetsAndMounts" ) then
        SetupMasque();
    end
end);
