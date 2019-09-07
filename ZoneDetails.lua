--[[
-- Credit to ckknight for originally writing Cartographer_ZoneDetails
-- Credit to phyber for writing Cromulent
--]]

ZoneDetails = LibStub("AceAddon-3.0"):NewAddon("ZoneDetails", "AceConsole-3.0", "AceEvent-3.0")
_ZoneDetails = {...}

local AceGUI = LibStub("AceGUI-3.0")
local ZoneDetailsDataProviderMixin = CreateFromMixins(MapCanvasDataProviderMixin)
local WORLDMAP_CONTINENT = Enum.UIMapType.Continent
local WORLDMAP_ZONE = Enum.UIMapType.Zone
local WORLDMAP_AZEROTH_ID = 947
local playerLevel =  UnitLevel("player")

local isAlliance, isHorde, isNeutral

do
	local faction = UnitFactionGroup("player")
	isAlliance = faction == "Alliance"
	isHorde = faction == "Horde"
	isNeutral = not isAlliance and not isHorde
end

-- Localized Zone Names
local zones = {}
local instances = {}
local raids = {}
local battlegrounds = {}
local nodes = {}
local herbs = {}
local skins = {}
local fishes = {}
local professions = {}

local profs = {
    "Leatherworking",
    "Tailoring",
    "Alchemy",
    "Engineering",
    "Blacksmithing",
    "Enchanting",
    "Cooking",
    "First Aid",
    "Mining",
    "Skinning",
    "Herbalism",
    "Fishing"
}

local Azeroth = "Azeroth"
local Kalimdor = "Kalimdor"
local Eastern_Kingdoms = "Eastern Kingdoms"

local defaults = {
    profile = {
        message = "Home is where you make it!",
        showInChat = true,
        showHerbs = false,
        showMineNodes = false,
        showFishing = false,
        showSkinning = false,
        showInstances = true,
        showInstanceLevel = true,
        showInstancePins = false,
        showZoneLevel = true,
        showBattlegrounds = true,
        fontSize = 32,
        zoneTextLocation = "TOP",
        nodeTextLocation = "BOTTOMLEFT",
    }
}

local options = {
    name = "ZoneDetails",
    handler = ZoneDetails,
    type = "group",
    args = {
        msg = {
            type = "input",
            name = "Message",
            desc = "The Message to be displayed",
            usage = "<Your message>",
            get = "GetMessage",
            set = "SetMessage",
        },
        showInChat = {
            type = "toggle",
            name = "Show in Chat",
            desc = "Toggles the display of messages in the chat window.",
            get = "IsShowInChat",
            set = "ToggleIsShowInChat",
        },
    }
}

function dbg(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end

-- Use Blizzard MixIns function to add a new overlay to the Map Frane
function ZoneDetailsDataProviderMixin:OnAdded(mapCanvas)
    MapCanvasDataProviderMixin.OnAdded(self, mapCanvas)

    if not self.ZoneTxtFrame then
        -- Create the frame and attach it to the WorldMap canvas container
        self.ZoneTxtFrame = CreateFrame("Frame", nil, self:GetMap():GetCanvasContainer())

        -- Set the frame size
        self.ZoneTxtFrame:SetSize(400, 128)

        -- Create a font string for the info text, using the WorldMap font
        self.ZoneText = self.ZoneTxtFrame:CreateFontString(nil, "OVERLAY", "WorldMapTextFont")

        -- Set font for Text
        local font, size = WorldMapTextFont:GetFont()
        self.ZoneText:SetFont(font, size, "OUTLINE")

        -- Attach the ZoneText to the top of the frame and scale to 0.4.
        self.ZoneText:SetPoint("TOP", self.ZoneTxtFrame, "TOP", 0, -35)
        self.ZoneText:SetScale(0.4)
        self.ZoneText:SetJustifyH("CENTER")


    else
        self.ZoneTxtFrame:SetParent(self:GetMap():GetCanvasContainer())
    end

    -- Setup Profession Text Frame
    if not self.ProfTxtFrame then
        -- Create the frame and attach it to the WorldMap canvas container
        self.ProfTxtFrame = CreateFrame("Frame", nil, self:GetMap():GetCanvasContainer())

        -- Set the frame size
        self.ProfTxtFrame:SetSize(400, 128)

        -- Create a font string for the info text, using the WorldMap font
        self.ProfessionText = self.ProfTxtFrame:CreateFontString(nil, "OVERLAY", "WorldMapTextFont")

        -- Set font for Text
        local font, size = WorldMapTextFont:GetFont()
        self.ProfessionText:SetFont(font, size, "OUTLINE")

         -- Attach the ProfessionText to the Bottom Left of the frame and scale to 0.4
        self.ProfessionText:SetPoint("BOTTOMLEFT", self.ProfTxtFrame, "BOTTOMLEFT", 0, 0)
        self.ProfessionText:SetScale(0.4)
        self.ProfessionText:SetJustifyH("LEFT")

    else
        self.ProfTxtFrame:SetParent(self:GetMap():GetCanvasContainer())
    end

    -- Put the frame in the top of the world map
    self.ZoneTxtFrame:SetPoint("TOP", self:GetMap():GetCanvasContainer(), 10, 10)
    self.ProfTxtFrame:SetPoint("BOTTOMLEFT", self:GetMap():GetCanvasContainer(), 10, 10)

    self.ZoneTxtFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    self.ZoneTxtFrame.dataProvider = self

    self.ProfTxtFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    self.ProfTxtFrame.dataProvider = self

    -- Ensure everything is shown
    self.ZoneTxtFrame:Show()
    self.ProfTxtFrame:Show()
    self.ZoneText:Show()
    self.ProfessionText:Show()
end

-- When the map changes, update it with the current zone information
function ZoneDetailsDataProviderMixin:RefreshAllData(fromOnShow)
    local info = ZoneDetails:GetZoneDetails()
    local prof = ZoneDetails:GetProfessionDetails()

    if info then
        self.ZoneText:SetText(info)
    else
        self.ZoneText:SetText("")
    end

    if prof then
        self.ProfessionText:SetText(prof)
    else
        self.ProfessionText:SetText("")
    end
end

-- When the map is hidden, hide our frame.
function ZoneDetailsDataProviderMixin:RemoveAllData()
    self.ZoneTxtFrame:Hide()
end

function ZoneDetails:OnEnable()
    WorldMapFrame:AddDataProvider(ZoneDetailsDataProviderMixin)
end

function ZoneDetails:OnDisable()
    WorldMapFrame:RemoveDataProvider(ZoneDetailsDataProviderMixin)
end

function ZoneDetails:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("ZoneDetailsDB", defaults, true)
    -- Called when the addon is loaded
    LibStub("AceConfig-3.0"):RegisterOptionsTable("ZoneDetails", options, {"ZoneDetails", "zd"})
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ZoneDetails", "ZoneDetails")
    self:RegisterEvent("ZONE_CHANGED")
    self:RegisterEvent('PLAYER_LEVEL_CHANGED')
end


function ZoneDetails:GetMessage(info)
    return self.db.profile.message
end

function ZoneDetails:SetMessage(info, newValue)
    self.db.profile.message = newValue
end

function ZoneDetails:GetZoneDetails()
    local zoneText

    local mapID = WorldMapFrame:GetMapID()
    local mapInfo = C_Map.GetMapInfo(mapID)
    local mapName = mapInfo.name
    local zone = mapID

    if mapInfo.mapID == WORLDMAP_AZEROTH_ID then

        if mapInfo.mapType == WORLDMAP_CONTINENT then
            -- Future use. We'll add the zone info on hover
            return nil
        end

    else
        if mapInfo.mapType == WORLDMAP_ZONE then
            local r2, g2, b2 = ZoneDetails:LevelColor(zones[mapName].low, zones[mapName].high, playerLevel)
            local r1, g1, b1 = ZoneDetails:GetFactionColor(mapName)
            zoneText = ("|cff%02x%02x%02x%s|r |cff%02x%02x%02x[%d-%d]|r\n\n"):format(
                r1*255,
                g1*255,
                b1*255,
                mapName,
                r2*255,
                g2*255,
                b2*255,
                zones[mapName].low,
                zones[mapName].high
                )
            -- Do work to get zone name, level, faction, and any instances/raids.
            if zones[mapName].instances then
                zoneText = zoneText..("\n|cffffff00%s:|r"):format("Instances")
                for _, instance in ipairs(zones[mapName].instances) do
                    local r2, g2, b2 = ZoneDetails:LevelColor(instances[instance].low, instances[instance].high, playerLevel)
                    local r1, g1, b1 = ZoneDetails:GetFactionColor(mapName)
                    zoneText = zoneText..("\n|cff%02x%02x%02x%s|r |cff%02x%02x%02x[%d-%d]|r"):format(
                        r1*255, 
                        g1*255, 
                        b1*255, 
                        instance,
                        r2*255,
                        g2*255,
                        b2*255,
                        instances[instance].low, 
                        instances[instance].high
                    )
                end
            end
            
            if zones[mapName].battlegrounds then
                zoneText = zoneText..("\n|cffffff00%s:|r"):format("Battlegrounds")
                for _, battleground in ipairs(zones[mapName].battlegrounds) do
                    local r2, g2, b2 = ZoneDetails:LevelColor(battlegrounds[battleground].low, battlegrounds[battleground].high, playerLevel)
                    local r1, g1, b1 = ZoneDetails:GetFactionColor(mapName)
                    zoneText = zoneText ..("\n|cff%02x%02x%02x%s|r |cff%02x%02x%02x[%d-%d]|r   %s-Man"):format(
                        r1*255,
                        g1*255,
                        b2*255,
                        battleground,
                        r2*255,
                        g2*255,
                        b2*255,                        
                        battlegrounds[battleground].low,
                        battlegrounds[battleground].high,
                        battlegrounds[battleground].players
                    )
                end
            end

            if zones[mapName].raids then
                zoneText = zoneText..("\n|cffffff00%s:|r"):format("Raids")
                for _, raid in ipairs(zones[mapName].raids) do
                    local r2, g2, b2 = ZoneDetails:LevelColor(raids[raid].low, raids[raid].high, playerLevel)
                    local r1, g1, b1 = ZoneDetails:GetFactionColor(mapName)
                    zoneText = zoneText ..("\n|cff%02x%02x%02x%s|r |cff%02x%02x%02x[%d]|r   %s-Man"):format(
                        r1*255,
                        g1*255,
                        b2*255,
                        raid,
                        r2*255,
                        g2*255,
                        b2*255,                        
                        raids[raid].high,
                        raids[raid].players
                    )
                end
            end
            return zoneText
        end
    end
end

function ZoneDetails:GetProfessionDetails()
    -- Final profession text
    local profText

    -- Get current profession skills and rank
    for skillIndex = 1, GetNumSkillLines() do
        local skillName, isHeader, _, skillRank, _, _, _, _, _, _, _, _,
        skillDescription = GetSkillLineInfo(skillIndex)
        if not isHeader then
            for _,v in pairs(profs) do
                if v == skillName then
                    professions[skillName] = skillRank
                end
            end
        end
    end

    local mapID = WorldMapFrame:GetMapID()
    local mapInfo = C_Map.GetMapInfo(mapID)
    local mapName = mapInfo.name
    local zone = mapID

    if mapInfo.mapID == WORLDMAP_AZEROTH_ID then

        if mapInfo.mapType == WORLDMAP_CONTINENT then
            -- Future use. We'll add the zone info on hover
            return nil
        end

    else
        if professions["Fishing"] then
            if mapInfo.mapType == WORLDMAP_ZONE then
                local r, g, b = ZoneDetails:FishingColor(zones[mapName].fishing_min, professions["Fishing"])
                profText = ("|cffffff00%s|r |cff%02x%02x%02x[%d]|r\n\n"):format(
                    "Fishing Minimum",
                    r*255,
                    g*255,
                    b*255,
                    zones[mapName].fishing_min
                )
            end
        return profText
        end
    end
end
            


function ZoneDetails:IsShowInChat(info)
    return self.db.profile.showInChat    
end


function ZoneDetails:ToggleIsShowInChat(info, value)
    self.db.profile.showInChat = value
    self:Print("Set Show in Chat to "..tostring(value))
end


function ZoneDetails:ZONE_CHANGED()
    if GetBindLocation() == GetSubZoneText() then
        if self.db.profile.showInChat then
            self:Print(self.db.profile.message)
        end
    end
end

function ZoneDetails:PLAYER_LEVEL_CHANGED(oldLevel, newLevel)
    playerLevel = newLevel
end

-- Pulled from LibTourist
-- Returns an r, g and b value representing a color, depending on the given zone and the current character's faction.
function ZoneDetails:GetFactionColor(zone)
	zone = zones[zone]

	if zone.faction == "Contested" then
		-- Orange
		return 1, 0.7, 0
	elseif zone.faction == (isHorde and "Alliance" or "Horde") then
		-- Red
		return 1, 0, 0
	elseif zone.faction == (isHorde and "Horde" or "Alliance") then
		-- Green
		return 0, 1, 0
	else
		-- Yellow
		return 1, 1, 0
	end
end

-- Pulled from LibTourist
-- Returns an r, g and b value representing a color ranging from grey (too low) via 
-- green, yellow and orange to red (too high) depending on the player level within 
-- the given range. Returns white if no level is applicable, like in cities.	
function ZoneDetails:LevelColor(low, high, currentLevel)
	local midBracket = (low + high) / 2

	if low <= 0 and high <= 0 then
		-- City or level unknown -> White
		return 1, 1, 1
	elseif currentLevel == low and currentLevel == high then
		-- Exact match, one-level bracket -> Yellow
		return 1, 1, 0
	elseif currentLevel <= low - 3 then
		-- Player is three or more levels short of Low -> Red
		return 1, 0, 0
	elseif currentLevel < low then
		-- Player is two or less levels short of Low -> sliding scale between Red and Orange
		-- Green component goes from 0 to 0.5
		local greenComponent = (currentLevel - low + 3) / 6
		return 1, greenComponent, 0
	elseif currentLevel == low then
		-- Player is at low, at least two-level bracket -> Orange
		return 1, 0.5, 0
	elseif currentLevel < midBracket then
		-- Player is between low and the middle of the bracket -> sliding scale between Orange and Yellow
		-- Green component goes from 0.5 to 1
		local halfBracketSize = (high - low) / 2
		local posInBracketHalf = currentLevel - low
		local greenComponent = 0.5 + (posInBracketHalf / halfBracketSize) * 0.5
		return 1, greenComponent, 0
	elseif currentLevel == midBracket then
		-- Player is at the middle of the bracket -> Yellow
		return 1, 1, 0
	elseif currentLevel < high then
		-- Player is between the middle of the bracket and High -> sliding scale between Yellow and Green
		-- Red component goes from 1 to 0
		local halfBracketSize = (high - low) / 2
		local posInBracketHalf = currentLevel - midBracket
		local redComponent = 1 - (posInBracketHalf / halfBracketSize)
		return redComponent, 1, 0
	elseif currentLevel == high then
		-- Player is at High, at least two-level bracket -> Green
		return 0, 1, 0
	elseif currentLevel < high + 3 then
		-- Player is up to three levels above High -> sliding scale between Green and Gray
		-- Red and Blue components go from 0 to 0.5
		-- Green component goes from 1 to 0.5
		local pos = (currentLevel - high) / 3
		local redAndBlueComponent = pos * 0.5
		local greenComponent = 1 - redAndBlueComponent
		return redAndBlueComponent, greenComponent, redAndBlueComponent
	else
		-- Player is at High + 3 or above -> Gray
		return 0.5, 0.5, 0.5
	end
end


function ZoneDetails:FishingColor(fish_min, current)

    if fish_min <= 0 and current <= 0 then
        -- Unknown level
        return 1,1,1
    elseif fish_min > current then
        -- Returns red, Player isnt high enough to fish here
        return 1, 0, 0
    elseif fish_min == current then
        -- Return Yellow, Player is Exactly Min
        return 1, 1, 0
    else
        -- Return Green as player can fish here.
        return 0, 1, 0
    end
end

-- Zone definition ---------------------------------------------------------------------------------------

-- Alliance

zones["Elwynn Forest"] = {
    low = 1,
    high = 10,
    instances = {"The Stockade"},
    continent = Eastern_Kingdoms,
    faction = "Alliance",
    fishing_min = 1
}
zones["Teldrassil"] = {
    low = 1,
    high = 11,
    continent = Kalimdor,
    faction = "Alliance",
    fishing_min = 1
}

zones["Dun Morogh"] = {
    low = 1,
    high = 12,
    continent = Eastern_Kingdoms,
    faction = "Alliance",
    fishing_min = 1
}

zones["Westfall"] = {
    low = 9,
    high = 18,
    continent = Eastern_Kingdoms,
    instances = {"The Deadmines"},
    faction = "Alliance",
    fishing_min = 55
}

zones["Loch Modan"] = {
    low = 10,
    high = 18,
    continent = Eastern_Kingdoms,
    faction = "Alliance",
    fishing_min = 20
}

zones["Darkshore"] = {
    low = 11,
    high = 19,
    continent = Eastern_Kingdoms,
    faction = "Alliance",
    fishing_min = 20
}

-- Horde 

zones["Durotar"] = {
    low = 1,
    high = 10,
    continent = Kalimdor,
    instances = {"Ragefire Chasm"},
    faction = "Horde",
    fishing_min = 1
}

zones["Mulgore"] = {
    low = 1,
    high = 10,
    continent = Kalimdor,
    faction = "Horde",
    fishing_min = 1
}

zones["Tirisfal Glades"] = {
    low = 1,
    high = 12,
    continent = Eastern_Kingdoms,
    instances = {"Scarlet Monastery: Graveyard", "Scarlet Monastery: Library", "Scarlet Monastery: Armory", "Scarlet Monastery: Cathedral"},
    faction = "Horde",
    fishing_min = 1
}

zones["Silverpine Forest"] = {
    low = 10,
    high = 20,
    instances = {"Shadowfang Keep"},
    continent = Eastern_Kingdoms,
    faction = "Horde",
    fishing_min = 20
}

zones["The Barrens"] = {
    low = 10,
    high = 33,
    continent = Kalimdor,
    instances = {"Wailing Caverns", "Razorfen Kraul", "Razorfen Downs"},
    battlegrounds = {"Warsong Gulch"},
    faction = "Horde",
    fishing_min = 20
}

-- Contested

zones["Duskwood"] = {
    low = 10,
    high = 30,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    fishing_min = 55
}

zones["Moonglade"] = {
    low = 10,
    high = 60,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 205
}

zones["Stonetalon Mountains"] = {
    low = 15,
    high = 25,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 55
}

zones["Redridge Mountains"] = {
    low = 15,
    high = 25,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    fishing_min = 55
}

zones["Ashenvale"] = {
    low = 19,
    high = 30,
    instances = {"Blackfathom Deeps"},
    battlegrounds = {"Warsong Gulch"},
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 55
}

zones["Wetlands"] = {
    low = 20,
    high = 30,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    fishing_min = 55
}

zones["Hillsbrad Foothills"] = {
    low = 20,
    high = 31,
    continent = Eastern_Kingdoms,
    battlegrounds = {"Alterac Valley"},
    faction = "Contested",
    fishing_min = 55
}

zones["Alterac Mountains"] = {
    low = 27,
    high = 39,
    continent = Eastern_Kingdoms,
    battlegrounds = {"Alterac Valley"},
    faction = "Contested",
    fishing_min = 130
}

zones["Thousand Needles"] = {
    low = 24,
    high = 35,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 130
}

zones["Desolace"] = {
    low = 30,
    high = 39,
    continent = Kalimdor,
    instances = {"Maraudon"},
    faction = "Contested",
    fishing_min = 130
}

zones["Arathi Highlands"] = {
    low = 30,
    high = 40,
    continent = Eastern_Kingdoms,
    battlegrounds = {"Arathi Basin"},
    faction = "Contested",
    fishing_min = 130
}

zones["Swamp of Sorrows"] = {
    low = 36,
    high = 43,
    continent = Eastern_Kingdoms,
    instances = {"The Temple of Atal'Hakkar"},
    faction = "Contested",
    fishing_min = 130
}

zones["Badlands"] = {
    low = 36,
    high = 45,
    continent = Eastern_Kingdoms,
    faction = "Contested",
}

zones["Stranglethorn Vale"] = {
    low = 30,
    high = 50,
    continent = Eastern_Kingdoms,
    raids = {"Zul'Gurub"},
    faction = "Contested",
    fishing_min = 130
}

zones["Tanaris"] = {
    low = 40,
    high = 50,
    continent = Kalimdor,
    instances = {"Zul'Farrak"},
    faction = "Contested",
    fishing_min = 205
}

zones["Dustwallow Marsh"] = {
    low = 33,
    high = 50,
    continent = Kalimdor,
    raids = {"Onyxia's Lair"},
    faction = "Contested",
    fishing_min = 130
}

zones["The Hinterlands"] = {
    low = 41,
    high = 49,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    fishing_min = 205
}

zones["Feralas"] = {
    low = 41,
    high = 50,
    continent = Kalimdor,
    instances = {"Dire Maul: East", "Dire Maul: North", "Dire Maul: West"},
    faction = "Contested",
    fishing_min = 205
}

zones["Azshara"] = {
    low = 42,
    high = 55,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 205
}

zones["Western Plaguelands"] = {
    low = 43,
    high = 57,
    continent = Eastern_Kingdoms,
    instances = {"Scholomance"},
    faction = "Contested",
    fishing_min = 205
}

zones["Burning Steppes"] = {
    low = 50,
    high = 59,
    continent = Eastern_Kingdoms,
    instances = {"Blackrock Depths", "Blackrock Spire"},
    raids = {"Molten Core", "Blackwing Lair"},
    faction = "Contested",
    fishing_min = 330
}

zones["Felwood"] = {
    low = 47,
    high = 54,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 205
}

zones["Searing Gorge"] = {
    low = 43,
    high = 56,
    continent = Eastern_Kingdoms,
    instances = {"Blackrock Depths", "Blackrock Spire"},
    raids = {"Molten Core", "Blackwing Lair"},
    faction = "Contested",
}

zones["Un'Goro Crater"] = {
    low = 48,
    high = 55,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 205
}

zones["Winterspring"] = {
    low = 55,
    high = 60,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 330
}

zones["Blasted Lands"] = {
    low = 46,
    high = 60,
    continent = Eastern_Kingdoms,
    faction = "Contested",
}

zones["Eastern Plaguelands"] = {
    low = 54,
    high = 59,
    continent = Eastern_Kingdoms,
    instances = {"Stratholme"},
    raids = {"Naxxramas"},
    faction = "Contested",
    fishing_min = 330
}

zones["Deadwind Pass"] = {
    low = 50,
    high = 60,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    fishing_min = 330
}

zones["Silithus"] = {
    low = 55,
    high = 59,
    continent = Kalimdor,
    raids = {"Ruins of Ahn'Qiraj", "Ahn'Qiraj"},
    faction = "Contested",
    fishing_min = 330
}

-- City definition ---------------------------------------------------------------------------------------

zones["Orgrimmar"] = {
    low = 1,
    high = 60,
    continent = Kalimdor,
    instances = {"Ragefire Chasm"},
    faction = "Horde",
    fishing_min = 1
}

zones["Thunder Bluff"] = {
    low = 1,
    high = 60,
    continent = Kalimdor,
    faction = "Horde",
    fishing_min = 1
}

zones["Undercity"] = {
    low = 1,
    high = 60,
    continent = Eastern_Kingdoms,
    faction = "Horde",
    fishing_min = 1
}

zones["Darnassus"] = {
    low = 1,
    high = 60,
    continent = Kalimdor,
    faction = "Alliance",
    fishing_min = 1
}

zones["Ironforge"] = {
    low = 1,
    high = 60,
    continent = Eastern_Kingdoms,
    faction = "Alliance",
    fishing_min = 1
}

zones["Stormwind City"] = {
    low = 1,
    high = 60,
    continent = Eastern_Kingdoms,
    instances = {"The Stockade"},
    faction = "Alliance",
    fishing_min = 1
}

-- Instance definition ---------------------------------------------------------------------------------------

instances["Ragefire Chasm"] = {
    low = 13,
    high = 22,
    continent = Kalimdor,
    entrance = {52, 49},
}

instances["The Deadmines"] = {
    low = 15,
    high = 28,
    continent = Eastern_Kingdoms,
    entrance = {42, 72},
    fishing_min = 20
}

instances["Wailing Caverns"] = {
    low = 15,
    high = 28,
    continent = Kalimdor,
    entrance = {46, 36},
    fishing_min = 20
}

instances["Shadowfang Keep"] = {
    low = 18,
    high = 32,
    continent = Eastern_Kingdoms,
    entrance = {42.7, 67.7},
}

instances["Blackfathom Deeps"] = {
    low = 20,
    high = 35,
    continent = Kalimdor,
    entrance = {14, 14},
    fishing_min = 20
}

instances["The Stockade"] = {
    low = 22,
    high = 30,
    continent = Eastern_Kingdoms,
    entrance = {41, 57}
}

instances["Gnomeregan"] = {
    low = 24,
    high = 40,
    continent = Eastern_Kingdoms,
    entrance = {24, 40}
}

instances["Razorfen Kraul"] = {
    low = 24,
    high = 40,
    continent = Kalimdor,
    entrance = {42, 90}
}

instances["Scarlet Monastery: Graveyard"] = {
    low = 26,
    high = 36,
    continent = Eastern_Kingdoms,
    entrance = {84.88, 30.63}
}

instances["Scarlet Monastery: Library"] = {
    low = 29,
    high = 39,
    continent = Eastern_Kingdoms,
    entrance = {85.30, 32.17}
}

instances["Scarlet Monastery: Armory"] = {
    low = 32,
    high = 42,
    continent = Eastern_Kingdoms,
    entrance = {85.63, 31.62}
}

instances["Scarlet Monastery: Cathedral"] = {
    low = 35,
    high = 45,
    continent = Eastern_Kingdoms,
    entrance = {85.35, 30.57}
}

instances["Razorfen Downs"] = {
    low = 33,
    high = 47,
    continent = Kalimdor,
    entrance = {49, 96}
}

instances["Uldaman"] = {
    low = 35,
    high = 52,
    continent = Eastern_Kingdoms,
    entrance = {43, 14}
}

instances["Maraudon"] = {
    low = 35,
    high = 52,
    continent = Kalimdor,
    entrance = {29, 63},
    fishing_min = 205
}

instances["Zul'Farrak"] = {
    low = 43,
    high = 54,
    continent = Kalimdor,
    entrance = {39, 20}
}

instances["The Temple of Atal'Hakkar"] = {
    low = 44,
    high = 60,
    continent = Eastern_Kingdoms,
    entrance = {70, 54},
    fishing_min = 205
}

instances["Blackrock Depths"] = {
    low = 48,
    high = 60,
    continent = Eastern_Kingdoms,
    entrance = {29, 38}
}

instances["Blackrock Spire"] = {
    low = 52,
    high = 60,
    continent = Eastern_Kingdoms,
    entrance = {29, 38}
}

instances["Stratholme"] = {
    low = 56,
    high = 60,
    continent = Eastern_Kingdoms,
    entrance = {31, 13},
    fishing_min = 330
}

instances["Dire Maul: East"] = {
    low = 36,
    high = 46,
    continent = Kalimdor,
    entrance = {58, 44}
}

instances["Dire Maul: West"] = {
    low = 39,
    high = 49,
    continent = Kalimdor,
    entrance = {58, 44}
}

instances["Dire Maul: North"] = {
    low = 42,
    high = 52,
    continent = Kalimdor,
    entrance = {58, 44}
}

instances["Scholomance"] = {
    low = 56,
    high = 60,
    continent = Eastern_Kingdoms,
    entrance = {69, 73},
    fishing_min = 330
}

-- Raid definition ---------------------------------------------------------------------------------------

raids["Molten Core"] = {
    low = 55,
    high = 60,
    players = 40,
    continent = Eastern_Kingdoms,
    entrance = {29, 38}
}

raids["Onyxia's Lair"] = {
    low = 55,
    high = 60,
    players = 40,
    continent = Kalimdor,
    entrance = {56, 71}
}

raids["Blackwing Lair"] = {
    low = 60,
    high = 60,
    players = 40,
    continent = Eastern_Kingdoms,
    entrance = {29, 38}
}

raids["Zul'Gurub"] = {
    low = 60,
    high = 60,
    players = 40,
    continent = Eastern_Kingdoms,
    entrance = {51, 17},
    fishing_min = 330
}

raids["Ruins of Ahn'Qiraj"] = {
    low = 60,
    high = 60,
    players = 20,
    continent = Kalimdor,
    entrance = {29, 93}
}

raids["Ahn'Qiraj"] = {
    low = 60,
    high = 60,
    players = 40,
    continent = Kalimdor,
    entrance = {29, 93}
}

raids["Naxxramas"] = {
    low = 60,
    high = 60,
    players = 40,
    continent = Eastern_Kingdoms,
    entrance = {39, 26}
}

-- Battlegrounds ---------------------------------------------------------------------------------------
battlegrounds["Warsong Gulch"] = {
    low = 10,
    high = 60,
    horde_entrance = {},
    alliance_entrance = {},
    players = 10
}

battlegrounds["Arathi Basin"] = {
    low = 20,
    high = 60,
    horde_entrance = {},
    alliance_entrance = {},
    players = 15
}

battlegrounds["Alterac Valley"] = {
    low = 51,
    high = 60,
    horde_entrance = {},
    alliance_entrance = {},
    players = 40
}


-- Herb Definitions ---------------------------------------------------------------------------------------
herbs["Peacebloom"] = {
    low = 1,
    high = 100,
}

herbs["Silverleaf"] = {
    low = 1,
    high = 100,
}

herbs["Earthroot"] = {
    low = 15,
    high = 115,
}

herbs["Mageroyal"] = {
    low = 50,
    high = 150,
    alt = {"Swiftthistle"},
}

herbs["Briarthorn"] = {
    low = 70,
    high = 170,
    alt = {"Swiftthistle"},
}

herbs["Stranglekelp"] = {
    low = 85,
    high = 185,
}

herbs["Bruiseweed"] = {
    low = 100,
    high = 200,
}

herbs["Wild Steelbloom"] = {
    low = 115,
    high = 215,
}

herbs["Grave Moss"] = {
    low = 120,
    high = 220,
}

herbs["Kingsblood"] = {
    low = 125,
    high = 225,
}

herbs["Liferoot"] = {
    low = 150,
    high = 250,
}

herbs["Fadeleaf"] = {
    low = 160,
    high = 260,
}

herbs["Goldthorn"] = {
    low = 170,
    high = 270,
}

herbs["Khadgar's Whisker"] = {
    low = 185,
    high = 285,
}

herbs["Wintersbite"] = {
    low = 195,
    high = 295,
}

herbs["Firebloom"] = {
    low = 205,
    high = 305,
}

herbs["Purple Lotus"] = {
    low = 210,
    high = 310,
    alt = {"Wildvine", "Bloodvine"},
}

herbs["Arthas' Tears"] = {
    low = 220,
    high = 325,
}

herbs["Sungrass"] = {
    low = 220,
    high = 325,
    alt = {"Bloodvine"},
}

herbs["Blindweed"] = {
    low = 235,
    high = 325,
}

herbs["Ghost Mushroom"] = {
    low = 245,
    high = 325,
}

herbs["Gromsblood"] = {
    low = 250,
    high = 325,
}

herbs["Golden Sansam"] = {
    low = 260,
    high = 325,
    alt = {"Bloodvine"},
}

herbs["Dreamfoil"] = {
    low = 270,
    high = 325,
    alt = {"Bloodvine"},
}

herbs["Mountain Silversage"] = {
    low = 280,
    high = 325,
    alt = {"Bloodvine"},
}

herbs["Plaguebloom"] = {
    low = 285,
    high = 325,
}

herbs["Icecap"] = {
    low = 290,
    high = 325,
}

herbs["Black Lotus"] = {
    low = 300,
    high = 325,
}

-- Mining Node Definitions ---------------------------------------------------------------------------------------
nodes["Copper Vein"] = {
    low = 1,
    high = 100,
    ore = {"Copper Ore"},
    alt = {"Rough Stone", "Malachite", "Tigerseye", "Shadowgem"}
}

nodes["Tin Vein"] = {
    low = 65,
    high = 165,
    ore = {"Tin Ore"},
    alt = {"Coarse Stone", "Moss Agate", "Shadowgem", "Jade", "Lesser Moonstone"}
}

nodes["Silver Vein"] = {
    low = 75,
    high = 175,
    ore = {"Silver Ore"},
    alt = {"Moss Agate", "Shadowgem", "Lesser Moonstone"}
}

nodes["Iron Deposit"] = {
    low = 125,
    high = 225,
    ore = {"Iron Ore"},
    alt = {"Heavy Stone", "Jade", "Lesser Moonstone", "Citrine", "Aquamarine"}
}

nodes["Gold Vein"] = {
    low = 155,
    high = 255,
    ore = {"Gold Ore"},
    alt = {"Jade", "Lesser Moonstone", "Citrine"}
}

nodes["Mithril Deposit"] = {
    low = 175,
    high = 275,
    ore = {"Mithril Ore"},
    alt = {"Solid Stone", "Aquamarine", "Star Ruby", "Black Vitriol"}
}

nodes["Ooze Covered Mithril Deposit"] = {
    low = 175,
    high = 275,
    ore = {"Mithril Ore"},
    alt = {"Solid Stone", "Aquamarine", "Star Ruby", "Black Vitriol"}
}

nodes["Truesilver Deposit"] = {
    low = 230,
    high = 310,
    ore = {"Truesilver Ore"},
    alt = {"Citrine", "Aquamarine", "Star Ruby"}
}

nodes["Ooze Covered Truesilver Deposit"] = {
    low = 230,
    high = 310,
    ore = {"Truesilver Ore"},
    alt = {"Citrine", "Aquamarine", "Star Ruby"}
}

nodes["Dark Iron Deposit"] = {
    low = 230,
    high = 310,
    ore = {"Dark Iron Ore"},
    alt = {"Black Vitriol", "Blood of the Mountain", "Black Diamond"}
}

nodes["Small Thorium Vein"] = {
    low = 250,
    high = 310,
    ore = {"Thorium Ore"},
    alt = {"Star Ruby", "Black Vitriol", "Blue Sapphire", "Large Opal"}
}

nodes["Small Thorium Vein"] = {
    low = 250,
    high = 310,
    ore = {"Thorium Ore"},
    alt = {"Dense Stone", "Star Ruby", "Black Vitriol", "Blue Sapphire", "Large Opal"}
}

nodes["Ooze Covered Thorium Vein"] = {
    low = 250,
    high = 310,
    ore = {"Thorium Ore"},
    alt = {"Dense Stone", "Star Ruby", "Black Vitriol", "Blue Sapphire", "Large Opal"}
}

nodes["Rich Thorium Vein"] = {
    low = 275,
    high = 310,
    ore = {"Thorium Ore"},
    alt = {"Dense Stone", "Star Ruby", "Blue Sapphire", "Large Opal", "Arcane Crystal", "Huge Emerald", "Azerothian Diamond"}
}

nodes["Ooze Covered Rich Thorium Vein"] = {
    low = 275,
    high = 310,
    ore = {"Thorium Ore"},
    alt = {"Dense Stone", "Star Ruby", "Blue Sapphire", "Large Opal", "Arcane Crystal", "Huge Emerald", "Azerothian Diamond"}
}

nodes["Hakkari Thorium Vein"] = {
    low = 275,
    high = 310,
    ore = {"Thorium Ore"},
    alt = {"Dense Stone", "Star Ruby", "Blue Sapphire", "Large Opal", "Arcane Crystal", "Huge Emerald", "Azerothian Diamond", "Souldarite"}
}

nodes["Small Obsidian Chunk"] = {
    low = 305,
    high = 310,
    ore = {"Small Obsidian Shard", "Large Obsidian Shard"},
    alt = {"Essence of Earth", "Huge Emerald", "Arcane Crystal", "Azerothian Diamond"}
}

nodes["Large Obsidian Chunk"] = {
    low = 305,
    high = 310,
    ore = {"Small Obsidian Shard", "Large Obsidian Shard"},
    alt = {"Essence of Earth", "Huge Emerald", "Arcane Crystal", "Azerothian Diamond"}
}

-- Skinning definitions ---------------------------------------------------------------------------------------
-- Trying decide if I want to map out the hides or just leave the zone minimum.
-- Might be nice to have level/zone by skins obtainable.


-- Fishing definitions ---------------------------------------------------------------------------------------
-- Trying decide if I want to map out the fish or just leave the zone minimum.
-- Might be nice to have fish by level/zone
