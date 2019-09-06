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

local Azeroth = "Azeroth"
local Kalimdor = "Kalimdor"
local Eastern_Kingdoms = "Eastern Kingdoms"

local defaults = {
    profile = {
        message = "Home is where you make it!",
        showInChat = true,
    }
}

local options = {
    name = "ZoneDetails",
    handler = ZoneDetails,
    type = "group",
    args = {
        msg = {
            type = "input",
            name = "message",
            desc = "The Message to be displayed",
            usage = "<Your message>",
            get = "GetMessage",
            set = "SetMessage",
        },
        zoneid = {
            type = "execute",
            name = "zoneId",
            desc = "Get the current zone ID",
            func = "ZoneID"
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

    if not self.Frame then
        -- Create the frame and attach it to the WorldMap canvas container
        self.Frame = CreateFrame(
            "Frame",
            nil,
            self:GetMap():GetCanvasContainer()
        )

        -- Set the frame size
        self.Frame:SetSize(400, 128)

        -- Create a font string for the info text, using the WorldMap font
        self.InfoText = self.Frame:CreateFontString(
            nil,
            "OVERLAY",
            "WorldMapTextFont"
        )

        local font, size = WorldMapTextFont:GetFont()
        self.InfoText:SetFont(font, size, "OUTLINE")

        -- Attach the infotext to the top of the frame and scale to 0.4.
        self.InfoText:SetPoint("TOP", self.Frame, "TOP", 0, -35)
        self.InfoText:SetScale(0.4)
        self.InfoText:SetJustifyH("CENTER")
    else
        self.Frame:SetParent(self:GetMap():GetCanvasContainer())
    end

    -- Put the frame in the top of the world map
    self.Frame:SetPoint(
        "TOP",
        self:GetMap():GetCanvasContainer(),
        10,
        10
    )

    self.Frame:SetFrameStrata("FULLSCREEN_DIALOG")
    self.Frame.dataProvider = self

    -- Ensure everything is shown
    self.Frame:Show()
    self.InfoText:Show()
end

-- When the map changes, update it with the current zone information
function ZoneDetailsDataProviderMixin:RefreshAllData(fromOnShow)
    local info = ZoneDetails:GetZoneDetails()
    if info then
        self.InfoText:SetText(info)
    else
        self.InfoText:SetText("")
    end
end

-- When the map is hidden, hide our frame.
function ZoneDetailsDataProviderMixin:RemoveAllData()
    self.Frame:Hide()
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
    LibStub("AceConfig-3.0"):RegisterOptionsTable("ZoneDetails", options, {"ZoneDetails", "zi"})
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
     -- Set the text to white and hide the zone info if we're on the Azeroth continent map.
    local mapID = WorldMapFrame:GetMapID()
    local mapInfo = C_Map.GetMapInfo(mapID)
    local mapName = mapInfo.name
    local zone = mapID

    if mapInfo.mapID == WORLDMAP_AZEROTH_ID then

        if mapInfo.mapType == WORLDMAP_CONTINENT then
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

            if zones[mapName].raids then
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

function ZoneDetails:ZoneID()
    local uimap = C_Map.GetBestMapForUnit("player")
    local mapinfo = C_Map.GetMapInfo(uimap)
    self:Print("Current zone is \""..mapinfo.name.."\" with ID: "..mapinfo.mapID)
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

-- Zone definition

-- Alliance

zones["Elwynn Forest"] = {
    low = 1,
    high = 10,
    instances = {"The Stockade"},
    continent = Eastern_Kingdoms,
    faction = "Alliance",
}
zones["Teldrassil"] = {
    low = 1,
    high = 11,
    continent = Kalimdor,
    faction = "Alliance",
}

zones["Dun Morogh"] = {
    low = 1,
    high = 12,
    continent = Eastern_Kingdoms,
    faction = "Alliance",
}

zones["Westfall"] = {
    low = 9,
    high = 18,
    continent = Eastern_Kingdoms,
    instances = {"The Deadmines"},
    faction = "Alliance",
}

zones["Loch Modan"] = {
    low = 10,
    high = 18,
    continent = Eastern_Kingdoms,
    faction = "Alliance",
}

zones["Darkshore"] = {
    low = 11,
    high = 19,
    continent = Eastern_Kingdoms,
    faction = "Alliance",
}

-- Horde

zones["Durotar"] = {
    low = 1,
    high = 10,
    continent = Kalimdor,
    instances = {"Ragefire Chasm"},
    faction = "Horde",
}

zones["Mulgore"] = {
    low = 1,
    high = 10,
    continent = Kalimdor,
    faction = "Horde",
}

zones["Tirisfal Glades"] = {
    low = 1,
    high = 12,
    continent = Eastern_Kingdoms,
    instances = {"Scarlet Monastery: Graveyard", "Scarlet Monastery: Library", "Scarlet Monastery: Armory", "Scarlet Monastery: Cathedral"},
    faction = "Horde",
}

zones["Silverpine Forest"] = {
    low = 10,
    high = 20,
    instances = {"Shadowfang Keep"},
    continent = Eastern_Kingdoms,
    faction = "Horde",
}

zones["The Barrens"] = {
    low = 10,
    high = 33,
    continent = Kalimdor,
    instances = {"Wailing Caverns", "Razorfen Kraul", "Razorfen Downs"},
    faction = "Horde",
}

-- Contested
zones["Duskwood"] = {
    low = 10,
    high = 30,
    continent = Eastern_Kingdoms,
    faction = "Contested",
}

zones["Moonglade"] = {
    low = 10,
    high = 60,
    continent = Kalimdor,
    faction = "Contested",
}

zones["Stonetalon Mountains"] = {
    low = 15,
    high = 25,
    continent = Kalimdor,
    faction = "Contested",
}

zones["Redridge Mountains"] = {
    low = 15,
    high = 25,
    continent = Eastern_Kingdoms,
    faction = "Contested",
}

zones["Ashenvale"] = {
    low = 19,
    high = 30,
    instances = {"Blackfathom Deeps"},
    continent = Kalimdor,
    faction = "Contested",
}

zones["Wetlands"] = {
    low = 20,
    high = 30,
    continent = Eastern_Kingdoms,
    faction = "Contested",
}

zones["Hillsbrad Foothills"] = {
    low = 20,
    high = 31,
    continent = Eastern_Kingdoms,
    faction = "Contested",
}

zones["Alterac Mountains"] = {
    low = 27,
    high = 39,
    continent = Eastern_Kingdoms,
    faction = "Contested",
}

zones["Thousand Needles"] = {
    low = 24,
    high = 35,
    continent = Kalimdor,
    faction = "Contested",
}

zones["Desolace"] = {
    low = 30,
    high = 39,
    continent = Kalimdor,
    instances = {"Maraudon"},
    faction = "Contested",
}

zones["Arathi Highlands"] = {
    low = 30,
    high = 40,
    continent = Eastern_Kingdoms,
    faction = "Contested",
}

zones["Swamp of Sorrows"] = {
    low = 36,
    high = 43,
    continent = Eastern_Kingdoms,
    instances = {"The Temple of Atal'Hakkar"},
    faction = "Contested",
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
}

zones["Tanaris"] = {
    low = 40,
    high = 50,
    continent = Kalimdor,
    instances = {"Zul'Farrak"},
    faction = "Contested",
}

zones["Dustwallow Marsh"] = {
    low = 33,
    high = 50,
    continent = Kalimdor,
    raids = {"Onyxia's Lair"},
    faction = "Contested",
}

zones["The Hinterlands"] = {
    low = 41,
    high = 49,
    continent = Eastern_Kingdoms,
    faction = "Contested",
}

zones["Feralas"] = {
    low = 41,
    high = 50,
    continent = Kalimdor,
    instances = {"Dire Maul: East", "Dire Maul: North", "Dire Maul: West"},
    faction = "Contested",
}

zones["Azshara"] = {
    low = 42,
    high = 55,
    continent = Kalimdor,
    faction = "Contested",
}

zones["Western Plaguelands"] = {
    low = 43,
    high = 57,
    continent = Eastern_Kingdoms,
    instances = {"Scholomance"},
    faction = "Contested",
}

zones["Burning Steppes"] = {
    low = 50,
    high = 59,
    continent = Eastern_Kingdoms,
    instances = {"Blackrock Depths", "Blackrock Spire"},
    raids = {"Molten Core", "Blackwing Lair"},
    faction = "Contested",
}

zones["Felwood"] = {
    low = 47,
    high = 54,
    continent = Kalimdor,
    faction = "Contested",
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
}

zones["Winterspring"] = {
    low = 55,
    high = 60,
    continent = Kalimdor,
    faction = "Contested",
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
}

zones["Deadwind Pass"] = {
    low = 50,
    high = 60,
    continent = Eastern_Kingdoms,
    faction = "Contested",
}

zones["Silithus"] = {
    low = 55,
    high = 59,
    continent = Kalimdor,
    raids = {"Ruins of Ahn'Qiraj", "Ahn'Qiraj"},
    faction = "Contested",
}

-- City definition
zones["Orgrimmar"] = {
    low = 1,
    high = 60,
    continent = Kalimdor,
    instances = {"Ragefire Chasm"},
    faction = "Horde",
}

zones["Thunder Bluff"] = {
    low = 1,
    high = 60,
    continent = Kalimdor,
    faction = "Horde",
}

zones["Undercity"] = {
    low = 1,
    high = 60,
    continent = Eastern_Kingdoms,
    faction = "Horde",
}

zones["Darnassus"] = {
    low = 1,
    high = 60,
    continent = Kalimdor,
    faction = "Alliance",
}

zones["Ironforge"] = {
    low = 1,
    high = 60,
    continent = Eastern_Kingdoms,
    faction = "Alliance",
}

zones["Stormwind City"] = {
    low = 1,
    high = 60,
    continent = Eastern_Kingdoms,
    instances = {"The Stockade"},
    faction = "Alliance",
}

-- Instance definition

instances["Ragefire Chasm"] = {
    low = 13,
    high = 22,
    continent = Kalimdor,
}

instances["The Deadmines"] = {
    low = 15,
    high = 28,
    continent = Eastern_Kingdoms,
}

instances["Wailing Caverns"] = {
    low = 15,
    high = 28,
    continent = Kalimdor,
}

instances["Shadowfang Keep"] = {
    low = 18,
    high = 32,
    continent = Eastern_Kingdoms,
}

instances["Blackfathom Deeps"] = {
    low = 20,
    high = 35,
    continent = Kalimdor,
}

instances["The Stockade"] = {
    low = 22,
    high = 30,
    continent = Eastern_Kingdoms,
}

instances["Gnomeregan"] = {
    low = 24,
    high = 40,
    continent = Eastern_Kingdoms,
}

instances["Razorfen Kraul"] = {
    low = 24,
    high = 40,
    continent = Kalimdor,
}

instances["Scarlet Monastery: Graveyard"] = {
    low = 26,
    high = 36,
    continent = Eastern_Kingdoms,
}

instances["Scarlet Monastery: Library"] = {
    low = 29,
    high = 39,
    continent = Eastern_Kingdoms,
}

instances["Scarlet Monastery: Armory"] = {
    low = 32,
    high = 42,
    continent = Eastern_Kingdoms,
}

instances["Scarlet Monastery: Cathedral"] = {
    low = 35,
    high = 45,
    continent = Eastern_Kingdoms,
}

instances["Razorfen Downs"] = {
    low = 33,
    high = 47,
    continent = Kalimdor,
}

instances["Uldaman"] = {
    low = 35,
    high = 52,
    continent = Eastern_Kingdoms,
}

instances["Maraudon"] = {
    low = 35,
    high = 52,
    continent = Kalimdor,
}

instances["Zul'Farrak"] = {
    low = 43,
    high = 54,
    continent = Kalimdor,
}

instances["The Temple of Atal'Hakkar"] = {
    low = 44,
    high = 60,
    continent = Eastern_Kingdoms,
}

instances["Blackrock Depths"] = {
    low = 48,
    high = 60,
    continent = Eastern_Kingdoms,
}

instances["Blackrock Spire"] = {
    low = 52,
    high = 60,
    continent = Eastern_Kingdoms,
}

instances["Stratholme"] = {
    low = 56,
    high = 60,
    continent = Eastern_Kingdoms,
}

instances["Dire Maul: East"] = {
    low = 36,
    high = 46,
    continent = Kalimdor,
}

instances["Dire Maul: West"] = {
    low = 39,
    high = 49,
    continent = Kalimdor,
}

instances["Dire Maul: North"] = {
    low = 42,
    high = 52,
    continent = Kalimdor,
}

instances["Scholomance"] = {
    low = 56,
    high = 60,
    continent = Eastern_Kingdoms,
}

-- Raid definition

raids["Molten Core"] = {
    low = 55,
    high = 60,
    players = 40,
    continent = Eastern_Kingdoms,
}

raids["Onyxia's Lair"] = {
    low = 55,
    high = 60,
    players = 40,
    continent = Kalimdor,
}

raids["Blackwing Lair"] = {
    low = 60,
    high = 60,
    players = 40,
    continent = Eastern_Kingdoms,
}

raids["Zul'Gurub"] = {
    low = 60,
    high = 60,
    players = 40,
    continent = Eastern_Kingdoms,
}

raids["Ruins of Ahn'Qiraj"] = {
    low = 60,
    high = 60,
    players = 20,
    continent = Kalimdor,
}

raids["Ahn'Qiraj"] = {
    low = 60,
    high = 60,
    players = 40,
    continent = Kalimdor,
}

raids["Naxxramas"] = {
    low = 60,
    high = 60,
    players = 40,
    continent = Eastern_Kingdoms,
}
