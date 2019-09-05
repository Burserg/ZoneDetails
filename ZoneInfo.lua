--[[
-- Credit to ckknight for originally writing Cartographer_ZoneInfo
-- Credit to phyber for writing Cromulent
--]]

ZoneInfo = LibStub("AceAddon-3.0"):NewAddon("ZoneInfo", "AceConsole-3.0", "AceEvent-3.0")
_ZoneInfo = {...}

local AceGUI = LibStub("AceGUI-3.0")
local ZoneInfoDataProviderMixin = CreateFromMixins(MapCanvasDataProviderMixin)
local WORLDMAP_CONTINENT = Enum.UIMapType.Continent
local WORLDMAP_ZONE = Enum.UIMapType.Zone
local WORLDMAP_AZEROTH_ID = 947

local isAlliance, isHorde, isNeutral
do
	local faction = UnitFactionGroup("player")
	isAlliance = faction == "Alliance"
	isHorde = faction == "Horde"
	isNeutral = not isAlliance and not isHorde
end

-- Localized Zone Names
local BZ = {}
local zones = {}
local instances = {}

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
    name = "ZoneInfo",
    handler = ZoneInfo,
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

-- Use Blizzard MixIns function to add a new overlay to the Map Frane
function ZoneInfoDataProviderMixin:OnAdded(mapCanvas)
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

        -- Attach the infotext to the topleft of the frame and scale to 0.5.
        self.InfoText:SetPoint("BOTTOMLEFT", self.Frame, "BOTTOMLEFT", 0, 0)
        self.InfoText:SetScale(0.4)
        self.InfoText:SetJustifyH("LEFT")
    else
        self.Frame:SetParent(self:GetMap():GetCanvasContainer())
    end

    -- Put the frame in the topleft of the world map
    self.Frame:SetPoint(
        "BOTTOMLEFT",
        self:GetMap():GetCanvasContainer(),
        10,
        10
    )

    self.Frame:SetFrameStrata("HIGH")
    self.Frame.dataProvider = self

    -- Ensure everything is shown
    self.Frame:Show()
    self.InfoText:Show()
end

-- When the map changes, update it with the current zone information
function ZoneInfoDataProviderMixin:RefreshAllData(fromOnShow)
    local info = ZoneInfo:GetZoneInfo()

    if info then
        self.InfoText:SetText(info)
    else
        self.InfoText:SetText("")
    end
end

-- When the map is hidden, hide our frame.
function ZoneInfoDataProviderMixin:RemoveAllData()
    self.Frame:Hide()
end

function ZoneInfo:OnEnable()
    WorldMapFrame:AddDataProvider(ZoneInfoDataProviderMixin)
end

function ZoneInfo:OnDisable()
    WorldMapFrame:RemoveDataProvider(ZoneInfoDataProviderMixin)
end

function ZoneInfo:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("ZoneInfoDB", defaults, true)
    -- Called when the addon is loaded
    LibStub("AceConfig-3.0"):RegisterOptionsTable("ZoneInfo", options, {"zoneinfo", "zi"})
    self:RegisterEvent("ZONE_CHANGED")
end


function ZoneInfo:GetMessage(info)
    return self.db.profile.message
end

function ZoneInfo:SetMessage(info, newValue)
    self.db.profile.message = newValue
end

function ZoneInfo:GetZoneInfo()
    local zoneText
     -- Set the text to white and hide the zone info if we're on the Azeroth
    -- continent map.
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
            zoneText = "Level:"..tostring(zones[mapName].low).."-"..tostring(zones[mapName].high)
            -- Do work to get zone name, level, faction, and any instances.
            if zones[mapName].instances then
                for _, instance in ipairs(zones[mapName].instances) do
                    zoneText = zoneText .."\n"..instance
                end
            end
            return zoneText
        end
    end
end

function ZoneInfo:ZoneID()
    local uimap = C_Map.GetBestMapForUnit("player")
    local mapinfo = C_Map.GetMapInfo(uimap)
    self:Print("Current zone is \""..mapinfo.name.."\" with ID: "..mapinfo.mapID)
end


function ZoneInfo:IsShowInChat(info)
    return self.db.profile.showInChat    
end


function ZoneInfo:ToggleIsShowInChat(info, value)
    self.db.profile.showInChat = value
    self:Print("Set Show in Chat to "..tostring(value))
end


function ZoneInfo:ZONE_CHANGED()
    if GetBindLocation() == GetSubZoneText() then
        if self.db.profile.showInChat then
            self:Print(self.db.profile.message)
        end
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
    instances = {"Zul'Farrak"},
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