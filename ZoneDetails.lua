--[[
-- Credit to ckknight for originally writing Cartographer_ZoneDetails
-- Credit to phyber for maintaining Cromulent
--]]
print("Addon loaded")
ZoneDetails = LibStub("AceAddon-3.0"):NewAddon("ZoneDetails", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")
ZoneDetailsGlobalPinMixin = BaseMapPoiPinMixin:CreateSubPin("PIN_FRAME_LEVEL_DUNGEON_ENTRANCE")

local L = LibStub("AceLocale-3.0"):GetLocale("ZoneDetails")
local AceGUI = LibStub("AceGUI-3.0")
local ZoneDetailsDataProviderMixin = CreateFromMixins(MapCanvasDataProviderMixin)
local ZoneDetailsPinDataProviderMixin = CreateFromMixins(MapCanvasDataProviderMixin)
local WORLDMAP_CONTINENT = Enum.UIMapType.Continent
local WORLDMAP_ZONE = Enum.UIMapType.Zone
local WORLDMAP_AZEROTH_ID = 947
local playerLevel =  UnitLevel("player")
local db
local GAME_LOCALE = GetLocale()

-- Localized Zone and Localized Zone Reverse Lookup tables
local Z = {}
local ZR = {}


-- Came from LibTourist.

-- Map ID / Locale lookup.
local MapIdLookupTable = {
    [947] = "Azeroth",
    [1411] = "Durotar",
    [1412] = "Mulgore",
    [1413] = "The Barrens",
    [1414] = "Kalimdor",
    [1415] = "Eastern Kingdoms",
    [1416] = "Alterac Mountains",
    [1417] = "Arathi Highlands",
    [1418] = "Badlands",
    [1419] = "Blasted Lands",
    [1420] = "Tirisfal Glades",
    [1421] = "Silverpine Forest",
    [1422] = "Western Plaguelands",
    [1423] = "Eastern Plaguelands",
    [1424] = "Hillsbrad Foothills",
    [1425] = "The Hinterlands",
    [1426] = "Dun Morogh",
    [1427] = "Searing Gorge",
    [1428] = "Burning Steppes",
    [1429] = "Elwynn Forest",
    [1430] = "Deadwind Pass",
    [1431] = "Duskwood",
    [1432] = "Loch Modan",
    [1433] = "Redridge Mountains",
    [1434] = "Stranglethorn Vale",
    [1435] = "Swamp of Sorrows",
    [1436] = "Westfall",
    [1437] = "Wetlands",
    [1438] = "Teldrassil",
    [1439] = "Darkshore",
    [1440] = "Ashenvale",
    [1441] = "Thousand Needles",
    [1442] = "Stonetalon Mountains",
    [1443] = "Desolace",
    [1444] = "Feralas",
    [1445] = "Dustwallow Marsh",
    [1446] = "Tanaris",
    [1447] = "Azshara",
    [1448] = "Felwood",
    [1449] = "Un'Goro Crater",
    [1450] = "Moonglade",
    [1451] = "Silithus",
    [1452] = "Winterspring",
    [1453] = "Stormwind City",
    [1454] = "Orgrimmar",
    [1455] = "Ironforge",
    [1456] = "Thunder Bluff",
    [1457] = "Darnassus",
    [1458] = "Undercity",
    [1459] = "Alterac Valley",
    [1460] = "Warsong Gulch",
    [1461] = "Arathi Basin",
    [1463] = "Eastern Kingdoms",
    [1464] = "Kalimdor",

-- NOTE: The following are InstanceIDs, as Instances do not have a uiMapID in Classic
    [30] = "Alteric Valley",
    [33] = "Shadowfang Keep",
    [34] = "The Stockade",
    [36] = "The Deadmines",
    [43] = "Wailing Caverns",
    [47] = "Razorfen Kraul",
    [48] = "Blackfathom Deeps",
    [70] = "Uldaman",
    [90] = "Gnomeregan",
    [109] = "The Temple of Atal'Hakkar",
    [129] = "Razorfen Downs",
    [209] = "Zul'Farrak",
    [229] = "Blackrock Spire",
    [230] = "Blackrock Depths",
    [329] = "Stratholme",
    [349] = "Maraudon",
    [369] = "Deeprun Tram",
    [389] = "Ragefire Chasm",
    [409] = "Molten Core",
    [429] = "Dire Maul",
    [469] = "Blackwing Lair",
    [489] = "Warsong Gulch",
    [509] = "Ruins of Ahn'Qiraj",
    [529] = "Arathi Basin",
    [531] = "Ahn'Qiraj Temple",
    [533] = "Naxxramas",
    [1004] = "Scarlet Monastery",
    [1007] = "Scholomance",
}

-- Translate instances that we don't have details on. This came from LibTourist3.0
local zoneTranslation = {
	enUS = {
		-- Dungeons
		[5914] = "Dire Maul - East",
		[5913] = "Dire Maul - North",
		[5915] = "Dire Maul - West",
	},
	deDE = {
		-- Dungeons
		[5914] = "Düsterbruch - Ost",
		[5913] = "Düsterbruch - Nord",
		[5915] = "Düsterbruch - West",
	},
	esES = {
		-- Dungeons
		[5914] = "La Masacre: Este",
		[5913] = "La Masacre: Norte",
		[5915] = "La Masacre: Oeste",
	},
	esMX = {
		-- Dungeons
		[5914] = "La Masacre: Este",
		[5913] = "La Masacre: Norte",
		[5915] = "La Masacre: Oeste",
	},
	frFR = {
		-- Dungeons
		[5914] = "Haches-Tripes - Est",
		[5913] = "Haches-Tripes - Nord",
		[5915] = "Haches-Tripes - Ouest",
	},
	itIT = {
		-- Dungeons
		[5914] = "Maglio Infausto - Est",
		[5913] = "Maglio Infausto - Nord",
		[5915] = "Maglio Infausto - Ovest",
	},
	koKR = {
		-- Dungeons
		[5914] = "혈투의 전장 - 동쪽",
		[5913] = "혈투의 전장 - 북쪽",
		[5915] = "혈투의 전장 - 서쪽",
	},
	ptBR = {
		-- Dungeons
		[5914] = "Gládio Cruel – Leste",
		[5913] = "Gládio Cruel – Norte",
		[5915] = "Gládio Cruel – Oeste",
	},
	ruRU = {
		-- Dungeons
		[5914] = "Забытый город – восток",
		[5913] = "Забытый город – север",
		[5915] = "Забытый город – запад",
	},
	zhCN = {
		-- Dungeons
		[5914] = "厄运之槌 - 东",
		[5913] = "厄运之槌 - 北",
		[5915] = "厄运之槌 - 西",
	},
	zhTW = {
		-- Dungeons
		[5914] = "厄運之槌 - 東方",
		[5913] = "厄運之槌 - 北方",
		[5915] = "厄運之槌 - 西方",
	},
}

local function dbg(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end

local function CreateLocalizedZoneNameLookups()
	local uiMapID
	local mapInfo
	local localizedZoneName
	local englishZoneName

-- Goes through all map IDs and fills any that are missing.. This came from LibTourist3.0 (incompatible with Classic)
	for uiMapID = 900, 1500, 1 do
		mapInfo = C_Map.GetMapInfo(uiMapID)
		if mapInfo then
			localizedZoneName = mapInfo.name
			englishZoneName = MapIdLookupTable[uiMapID]

			if englishZoneName then
				-- Add combination of English and localized name to lookup tables
				if not Z[englishZoneName] then
					Z[englishZoneName] = localizedZoneName
				end
				if not ZR[localizedZoneName] then
					ZR[localizedZoneName] = englishZoneName
				end
			else
				-- Not in lookup
				dbg("|r|cffff4422! -- ZoneDetails:|r English name not found in lookup for uiMapID "..tostring(uiMapID).." ("..tostring(localizedZoneName)..")" )
			end
		end
	end

	for instanceID = 1, 1100, 1 do
		localizedZoneName = GetRealZoneText(instanceID);
		if localizedZoneName then
			englishZoneName = MapIdLookupTable[instanceID]

			if englishZoneName then
				-- Add combination of English and localized name to lookup tables
				if not Z[englishZoneName] then
					Z[englishZoneName] = localizedZoneName
				end
				if not ZR[localizedZoneName] then
					ZR[localizedZoneName] = englishZoneName
				end
			else
				-- Not in lookup
				dbg("|r|cffff4422! -- ZoneDetails:|r English name not found in lookup for instanceID "..tostring(instanceID).." ("..tostring(localizedZoneName)..")" )
			end
		end
	end

	-- Load from zoneTranslation
	local GAME_LOCALE = GetLocale()
	for key, localizedZoneName in pairs(zoneTranslation[GAME_LOCALE]) do
		local englishName = zoneTranslation["enUS"][key]
		if not Z[englishName] then
			Z[englishName] = localizedZoneName
		end
		if not ZR[localizedZoneName] then
			ZR[localizedZoneName] = englishName
		end
	end
end

local isAlliance, isHorde, isNeutral

do
    CreateLocalizedZoneNameLookups()
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

local profs = {
    L["Leatherworking"],
    L["Tailoring"],
    L["Alchemy"],
    L["Engineering"],
    L["Blacksmithing"],
    L["Enchanting"],
    L["Cooking"],
    L["First Aid"],
    L["Mining"],
    L["Skinning"],
    L["Herbalism"],
    L["Fishing"]
}

local Azeroth = "Azeroth"
local Kalimdor = "Kalimdor"
local Eastern_Kingdoms = "Eastern Kingdoms"

local defaults = {
    profile = {
        -- General Options
        message = "Home is where you make it!",
        showInChat = true,

        -- Tradeskill Map Options
        showHerbs = true,
        showMineNodes = true,
        showFishing = true,
        showSkinning = false,

        -- Instance/Raid/ BGs Map Options
        showInstances = true,
        showInstancePins = true,
        showRaidPins = true,
        showZoneLevel = true,
        showBattlegrounds = true,
        showRaids = true,

        -- Zone Text Map Options
        zoneTextFontSize = 32,
        zoneTextLocation = "TOP",

        -- Profession Text Map Options
        profTextFontSize = 32,
        profTextLocation = "BOTTOMLEFT",
    }
}


local options = {
    name = "ZoneDetails",
    handler = ZoneDetails,
    type = "group",
    childGroups = "tab",
    get = function(k) return db[k.arg] end,
    set = function(k, v) db[k.arg] = v end,
    args = {
        msgSettings = {
            type = "group",
            name = L["Greetings Message"],
            desc = L["Display settings for Hearth greeting"],
            order = 0,
            args = {
                msgHeader = {
                    type = "header",
                    name = L["Greetings Message"],
                    order = 0,
                },
                showmsg = {
                    type = "input",
                    name = L["Message"],
                    order = 1,
                    arg = "message",
                    desc = L["The Message to be displayed when you enter the area where your Hearthstone is set."],
                    width = "full"
                },
                showInChat = {
                    type = "toggle",
                    name = L["Show Message"],
                    order = 2,
                    arg = "showInChat",
                    desc = L["Toggles the display of greeting message."],
                },
            }
        },
        mapSettings = {
            type = "group",
            name = L["Map Settings"],
            desc = L["Items displayed on the map"],
            order = 1,
            args = {
                mapHeader = {
                    type = "header",
                    name = L["Map Settings"],
                    order = 0,
                },
                showInstances = {
                    type = "toggle",
                    order = 1,
                    name = L["Show Instance Text"],
                    arg = "showInstances",
                    desc = L["Toggles the display of instances that can be found in current zone."],
                    width = "full",
                },
                showInstancePins = {
                    type = "toggle",
                    order = 2,
                    name = L["Show Instance Entrance"],
                    arg = "showInstancePins",
                    desc = L["Toggles the display of instance entrance."],
                    width = "full",
                },
                showRaids = {
                    type = "toggle",
                    order = 3,
                    name = L["Show Raid Text"],
                    arg = "showRaids",
                    desc = L["Toggles the display of raids."],
                    width = "full",
                },
                showRaidPins = {
                    type = "toggle",
                    order = 4,
                    name = L["Show Raid Entrance"],
                    arg = "showRaidPins",
                    desc = L["Toggles the display of raid entrance."],
                    width = "full",
                },
                showBattlegrounds = {
                    type = "toggle",
                    order = 5,
                    name = L["Show Battlegrounds"],
                    arg = "showBattlegrounds",
                    desc = L["Toggles the display of battlegrounds."],
                    width = "full",
                },
            }
        },
        professionOptions = {
            type = "group",
            name = L["Profession Settings"],
            desc = L["Profession details displayed on the map"],
            order = 2,
            args = {
                profHeader = {
                    type = "header",
                    name = L["Profession Settings"],
                    order = 0,
                },
                showFishing = {
                    type = "toggle",
                    order = 1,
                    name = L["Show Fishing"],
                    arg = "showFishing",
                    desc = L["Toggles the display of Fishing Skill on the map."],
                    width = "full",
                },
                showHerbs = {
                    type = "toggle",
                    order = 2,
                    name = L["Show Herbs"],
                    arg = "showHerbs",
                    desc = L["Toggles the display of herbs that can be found in current zone."],
                    width = "full",
                },
                showMineNodes = {
                    type = "toggle",
                    order = 3,
                    name = L["Show Minerals"],
                    arg = "showMineNodes",
                    desc = L["Toggles the display of minerals that can be found in current zone."],
                    width = "full",
                },
                showSkinning = {
                    type = "toggle",
                    order = 4,
                    name = L["Show Skins (NYI)"],
                    arg = "showSkinning",
                    desc = L["Toggles the display of skins that can be found in current zone."],
                    width = "full",
                },
            }
        },
    }
}


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

function ZoneDetailsPinDataProviderMixin:RefreshAllData(fromOnShow)
    -- Remove existing pins
    self:GetMap():RemoveAllPinsByTemplate("ZoneDetailsGlobalPinTemplate")

    local pins = ZoneDetails:GetPins()

    -- Add returned pins
    if pins then
        for _, pin in ipairs(pins) do
            self:GetMap():AcquirePin("ZoneDetailsGlobalPinTemplate", pin)
        end
    end
end

function ZoneDetailsGlobalPinMixin:OnAcquired(myInfo)
    BaseMapPoiPinMixin.OnAcquired(self, myInfo)
end

function ZoneDetailsGlobalPinMixin:OnMouseUp(btn)
    if btn == "RightButton" then
        WorldMapFrame:NavigateToParentMap()
    end
end

function ZoneDetails:OnEnable()

    WorldMapFrame:AddDataProvider(ZoneDetailsDataProviderMixin)
    WorldMapFrame:AddDataProvider(ZoneDetailsPinDataProviderMixin)
end

function ZoneDetails:OnDisable()
    WorldMapFrame:RemoveDataProvider(ZoneDetailsDataProviderMixin)
    WorldMapFrame:RemoveDataProvider(ZoneDetailsPinDataProviderMixin)
end

function ZoneDetails:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("ZoneDetailsDB", defaults)
    db = self.db.profile
    -- Called when the addon is loaded
    LibStub("AceConfig-3.0"):RegisterOptionsTable("ZoneDetails", options)
    options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ZoneDetails", "ZoneDetails")
    self:RegisterChatCommand("zonedetails", function() InterfaceOptionsFrame_OpenToCategory(self.optionsFrame) end)
    self:RegisterChatCommand("zd", function() InterfaceOptionsFrame_OpenToCategory(self.optionsFrame) end)
    self:RegisterEvent("ZONE_CHANGED")
    self:RegisterEvent('PLAYER_LEVEL_CHANGED')

    self.db.RegisterCallback(self, "OnProfileChanged", "Refresh")
	self.db.RegisterCallback(self, "OnProfileCopied", "Refresh")
    self.db.RegisterCallback(self, "OnProfileReset", "Refresh")
end

function ZoneDetails:Refresh()
    db = self.db.profile
end

function ZoneDetails:GetZoneDetails()
    local zoneText

    local mapID = WorldMapFrame:GetMapID()
    local mapInfo = C_Map.GetMapInfo(mapID)
    local mapName = mapInfo.name

    if mapInfo.mapType == WORLDMAP_CONTINENT then
        -- Try to get the hovered zone name or uiMapID.
        -- local map = WorldMapFrame:GetMapID()
        -- local uiMapID_old
        -- WorldMapFrame.ScrollContainer:HookScript("OnUpdate", function(self)
        --     local curX, curY = WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition()
        --     local vec2d = {curX, curY}
        --     local uiMapID, mapPosition = C_Map.GetMapInfoAtPosition(map, vec2d[1], vec2d[2])
            
        --     if uiMapID then
        --         if uiMapID == uiMapID_old then
        --             return
        --         else
        --             ZoneDetails:Print(uiMapID.name)
        --             uiMapID_old = uiMapID
        --         end
        --     end
            
        -- end)
        return nil

    else
        if mapInfo.mapType == WORLDMAP_ZONE then
            if db.showZoneLevel then
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
                else
                    zoneText = ""
                end
            -- Do work to get zone name, level, faction, and any instances/raids.
            if db.showInstances then
                if zones[mapName].instances then
                    zoneText = zoneText..("\n|cffffff00%s:|r"):format(L["Instances"])
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
            end
            
            if db.showBattlegrounds then
                if zones[mapName].battlegrounds then
                    zoneText = zoneText..("\n|cffffff00%s:|r"):format(L["Battlegrounds"])
                    for _, battleground in ipairs(zones[mapName].battlegrounds) do
                        local r2, g2, b2 = ZoneDetails:LevelColor(battlegrounds[battleground].low, battlegrounds[battleground].high, playerLevel)
                        local r1, g1, b1 = ZoneDetails:GetFactionColor(mapName)
                        zoneText = zoneText ..("\n|cff%02x%02x%02x%s|r |cff%02x%02x%02x[%d-%d]|r   %s-%s"):format(
                            r1*255,
                            g1*255,
                            b2*255,
                            battleground,
                            r2*255,
                            g2*255,
                            b2*255,                        
                            battlegrounds[battleground].low,
                            battlegrounds[battleground].high,
                            battlegrounds[battleground].players,
                            L["Man"]
                        )
                    end
                end
            end

            if db.showRaids then
                if zones[mapName].raids then
                    zoneText = zoneText..("\n|cffffff00%s:|r"):format(L["Raids"])
                    for _, raid in ipairs(zones[mapName].raids) do
                        local r2, g2, b2 = ZoneDetails:LevelColor(raids[raid].low, raids[raid].high, playerLevel)
                        local r1, g1, b1 = ZoneDetails:GetFactionColor(mapName)
                        zoneText = zoneText ..("\n|cff%02x%02x%02x%s|r |cff%02x%02x%02x[%d]|r   %s-%s"):format(
                            r1*255,
                            g1*255,
                            b2*255,
                            raid,
                            r2*255,
                            g2*255,
                            b2*255,                        
                            raids[raid].high,
                            raids[raid].players,
                            L["Man"]
                        )
                    end
                end
            end
            return zoneText
        end
    end
end

function ZoneDetails:GetProfessions()
    local professions = {}
    for skillIndex = 1, GetNumSkillLines() do
        local skillName, isHeader, _, skillRank, _, _, _, _, _, _, _, _, skillDescription = GetSkillLineInfo(skillIndex)
        if not isHeader then
            for _,v in pairs(profs) do
                if v == skillName then
                    professions[skillName] = skillRank
                end
            end
        end
    end
    return professions
end


function ZoneDetails:GetProfessionDetails()
    -- Final profession text
    local profText

    -- Get current profession skills and rank
    local profs = self.GetProfessions()

    local mapID = WorldMapFrame:GetMapID()
    local mapInfo = C_Map.GetMapInfo(mapID)
    local mapName = mapInfo.name
    local zone = mapID

    if mapInfo.mapID == WORLDMAP_AZEROTH_ID then

        if mapInfo.mapType == WORLDMAP_CONTINENT then
            -- Future use. We'll add the zone info on hover
            profText = ""
            return nil
        end

    else
        if mapInfo.mapType == WORLDMAP_ZONE  then
            if profs[L["Mining"]] or profs[L["Herbalism"]] or profs[L["Fishing"]] then
                profText = ("\n|cffffff00%s:|r"):format("Professions")
            else
                profText = ""
            end
            if db.showFishing and zones[mapName].fishing_min then
                if profs[L["Fishing"]] then
                    local r, g, b = ZoneDetails:FishingColor(zones[mapName].fishing_min, profs[L["Fishing"]])
                    profText = profText ..("\n|cffffff00%s|r |cff%02x%02x%02x[%d]|r\n"):format(
                        L["Fishing Minimum"],
                        r*255,
                        g*255,
                        b*255,
                        zones[mapName].fishing_min
                    )
                end
            end

            if db.showHerbs and zones[mapName].herbs then
                if profs[L["Herbalism"]] then
                    profText = profText..("\n|cffffff00%s:|r"):format(L["Herbs"])
                    for _, herb in ipairs(zones[mapName].herbs) do
                        local r, g, b = ZoneDetails:LevelColor(herbs[herb].low, herbs[herb].high, profs[L["Herbalism"]])
                        profText = profText ..("\n%s |cff%02x%02x%02x[%d-%d]|r"):format(
                            herb,
                            r*255,
                            g*255,
                            b*255,
                            herbs[herb].low, 
                            herbs[herb].high
                        )
                    end
                end
            end

            if db.showMineNodes and zones[mapName].nodes then
                if profs[L["Mining"]] then
                    profText = profText..("\n|cffffff00%s:|r"):format(L["Nodes"])
                    for _, node in ipairs(zones[mapName].nodes) do
                        local r, g, b = ZoneDetails:LevelColor(nodes[node].low, nodes[node].high, profs[L["Mining"]])
                        profText = profText ..("\n%s |cff%02x%02x%02x[%d-%d]|r"):format(
                            node,
                            r*255,
                            g*255,
                            b*255,
                            nodes[node].low, 
                            nodes[node].high
                        )
                    end
                end
            end
        end
        return profText
    end
end

function ZoneDetails:GetPins()

    -- Show pins if options are enabled
    local mapID = WorldMapFrame:GetMapID()
    local mapInfo = C_Map.GetMapInfo(mapID)
    local mapName = mapInfo.name
    local myPOIList = {}
    local count = 0
    
    -- If we're on the zone map, show the pins.
    if mapInfo.mapType == WORLDMAP_ZONE then
        if zones[mapName].instances then

            if db.showInstancePins then
                if zones[mapName].instances then
                    for _, instance in ipairs(zones[mapName].instances) do
                        local r2, g2, b2 = ZoneDetails:LevelColor(instances[instance].low, instances[instance].high, playerLevel)
                        local r1, g1, b1 = ZoneDetails:GetFactionColor(mapName)
                        local name = ("|cff%02x%02x%02x%s|r"):format(
                            r1*255, 
                            g1*255, 
                            b1*255, 
                            instance
                        )
                        local description = ("|cff%02x%02x%02x[%d-%d]|r "):format(
                            r2*255,
                            g2*255,
                            b2*255,
                            instances[instance].low, 
                            instances[instance].high
                        )
                        local myPOI = {}
                        myPOI["position"] = CreateVector2D(instances[instance].entrance[1] / 100, instances[instance].entrance[2] / 100)
                        myPOI["name"] = name
                        myPOI["description"] = description
                        myPOI["atlasName"] = "Dungeon"
                        count = count + 1
                        myPOIList[count] = myPOI
                    end
                end
            end

            if db.showRaidPins then
                if zones[mapName].raids then
                    for _, raid in ipairs(zones[mapName].raids) do
                        local r2, g2, b2 = ZoneDetails:LevelColor(raids[raid].low, raids[raid].high, playerLevel)
                        local r1, g1, b1 = ZoneDetails:GetFactionColor(mapName)
                        local name = ("|cff%02x%02x%02x%s|r %s-Man"):format(
                            r1*255, 
                            g1*255, 
                            b1*255, 
                            raid,
                            raids[raid].players
                        )
                        local description = ("|cff%02x%02x%02x[%d-%d]|r"):format(
                            r2*255,
                            g2*255,
                            b2*255,
                            raids[raid].low, 
                            raids[raid].high
                        )
                        local myPOI = {}
                        myPOI["position"] = CreateVector2D(raids[raid].entrance[1] / 100, raids[raid].entrance[2] / 100)
                        myPOI["name"] = name
                        myPOI["description"] = description
                        myPOI["atlasName"] = "Raid"
                        count = count + 1
                        myPOIList[count] = myPOI
                    end
                end
            end

            return myPOIList  
        end
    end
end

function ZoneDetails:ZONE_CHANGED()
    if GetBindLocation() == GetSubZoneText() then
        if db.showInChat then
            self:Print(db.message)
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

zones[Z["Elwynn Forest"]] = {
    low = 1,
    high = 10,
    continent = Eastern_Kingdoms,
    faction = "Alliance",
    fishing_min = 1,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot"},
    nodes = {"Copper Vein"}
}
zones[Z["Teldrassil"]] = {
    low = 1,
    high = 11,
    continent = Kalimdor,
    faction = "Alliance",
    fishing_min = 1,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot"}
}

zones[Z["Dun Morogh"]] = {
    low = 1,
    high = 12,
    continent = Eastern_Kingdoms,
    faction = "Alliance",
    fishing_min = 1,
    instances = {"Gnomeregan"},
    herbs = {"Peacebloom", "Silverleaf", "Earthroot"},
    nodes = {"Copper Vein"}
}

zones[Z["Westfall"]] = {
    low = 9,
    high = 18,
    continent = Eastern_Kingdoms,
    instances = {"The Deadmines"},
    faction = "Alliance",
    fishing_min = 55,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Bruiseweed"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"}
}

zones[Z["Loch Modan"]] = {
    low = 10,
    high = 18,
    continent = Eastern_Kingdoms,
    faction = "Alliance",
    fishing_min = 20,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Bruiseweed"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"}
}

zones[Z["Darkshore"]] = {
    low = 11,
    high = 19,
    continent = Eastern_Kingdoms,
    faction = "Alliance",
    fishing_min = 20,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"}
}

-- Horde 

zones[Z["Durotar"]] = {
    low = 1,
    high = 10,
    continent = Kalimdor,
    faction = "Horde",
    fishing_min = 1,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal"},
    nodes = {"Copper Vein"}
}

zones[Z["Mulgore"]] = {
    low = 1,
    high = 10,
    continent = Kalimdor,
    faction = "Horde",
    fishing_min = 1,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot"},
    nodes = {"Copper Vein"}
}

zones[Z["Tirisfal Glades"]] = {
    low = 1,
    high = 12,
    continent = Eastern_Kingdoms,
    instances = {"Scarlet Monastery: Graveyard", "Scarlet Monastery: Library", "Scarlet Monastery: Armory", "Scarlet Monastery: Cathedral"},
    faction = "Horde",
    fishing_min = 1,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot"},
    nodes = {"Copper Vein"}
}

zones[Z["Silverpine Forest"]] = {
    low = 10,
    high = 20,
    instances = {"Shadowfang Keep"},
    continent = Eastern_Kingdoms,
    faction = "Horde",
    fishing_min = 20,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"}
}

zones[Z["The Barrens"]] = {
    low = 10,
    high = 33,
    continent = Kalimdor,
    instances = {"Wailing Caverns", "Razorfen Kraul", "Razorfen Downs"},
    battlegrounds = {"Warsong Gulch"},
    faction = "Horde",
    fishing_min = 20,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Grave Moss", "Kingsblood"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"}
}

-- Contested

zones[Z["Duskwood"]] = {
    low = 10,
    high = 30,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    fishing_min = 55,
    herbs = {"Mageroyal", "Briarthorn", "Wild Steelbloom", "Grave Moss", "Kingsblood"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein"}
}

zones[Z["Moonglade"]] = {
    low = 10,
    high = 60,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 205
}

zones[Z["Stonetalon Mountains"]] = {
    low = 15,
    high = 25,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 55,
    herbs = {"Mageroyal", "Bruiseweed", "Wild Steelbloom", "Kingsblood"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"}
}

zones[Z["Redridge Mountains"]] = {
    low = 15,
    high = 25,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    fishing_min = 55,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Bruiseweed"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"}
}

zones[Z["Ashenvale"]] = {
    low = 19,
    high = 30,
    instances = {"Blackfathom Deeps"},
    battlegrounds = {"Warsong Gulch"},
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 55,
    herbs = {"Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Kingsblood", "Liferoot"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein"}
}

zones[Z["Wetlands"]] = {
    low = 20,
    high = 30,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    fishing_min = 55,
    herbs = {"Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Grave Moss", "Kingsblood", "Liferoot"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein"}
}

zones[Z["Hillsbrad Foothills"]] = {
    low = 20,
    high = 31,
    continent = Eastern_Kingdoms,
    battlegrounds = {"Alterac Valley"},
    faction = "Contested",
    fishing_min = 55,
    herbs = {"Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Kingsblood", "Liferoot"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit"}
}

zones[Z["Alterac Mountains"]] = {
    low = 27,
    high = 39,
    continent = Eastern_Kingdoms,
    battlegrounds = {"Alterac Valley"},
    faction = "Contested",
    fishing_min = 130,
    herbs = {"Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Grave Moss", "Kingsblood", "Liferoot", "Fadeleaf", "Goldthorn", "Khadgar's Whisker", "Wintersbite"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"}
}

zones[Z["Thousand Needles"]] = {
    low = 24,
    high = 35,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 130,
    herbs = {"Bruiseweed", "Wild Steelbloom", "Kingsblood"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Ooze Covered Silver Vein", "Iron Deposit", "Gold Vein", "Ooze Covered Gold Vein", "Mithril Deposit", "Ooze Covered Mithril Deposit"}
}

zones[Z["Desolace"]] = {
    low = 30,
    high = 39,
    continent = Kalimdor,
    instances = {"Maraudon"},
    faction = "Contested",
    fishing_min = 130,
    herbs = {"Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Grave Moss", "Kingsblood", "Liferoot", "Gromsblood"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"}
}

zones[Z["Arathi Highlands"]] = {
    low = 30,
    high = 40,
    continent = Eastern_Kingdoms,
    battlegrounds = {"Arathi Basin"},
    faction = "Contested",
    fishing_min = 130,
    herbs = {"Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Grave Moss", "Kingsblood", "Liferoot", "Fadeleaf", "Goldthorn", "Khadgar's Whisker"},
    nodes = {"Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"}
}

zones[Z["Swamp of Sorrows"]] = {
    low = 36,
    high = 43,
    continent = Eastern_Kingdoms,
    instances = {"The Temple of Atal'Hakkar"},
    faction = "Contested",
    fishing_min = 130,
    herbs = {"Stranglekelp", "Kingsblood", "Fadeleaf", "Goldthorn", "Khadgar's Whisker", "Blindweed"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein"}
}

zones[Z["Badlands"]] = {
    low = 36,
    high = 45,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    herbs = {"Wild Steelbloom", "Kingsblood", "Fadeleaf", "Goldthorn", "Khadgar's Whisker", "Firebloom", "Purple Lotus"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"}
}

zones[Z["Stranglethorn Vale"]] = {
    low = 30,
    high = 50,
    continent = Eastern_Kingdoms,
--    raids = {"Zul'Gurub"},
    faction = "Contested",
    fishing_min = 130,
    herbs = {"Stranglekelp", "Wild Steelbloom", "Kingsblood", "Liferoot", "Fadeleaf", "Goldthorn", "Khadgar's Whisker", "Purple Lotus"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"}
}

zones[Z["Tanaris"]] = {
    low = 40,
    high = 50,
    continent = Kalimdor,
    instances = {"Zul'Farrak"},
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Stranglekelp", "Firebloom", "Purple Lotus"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein"}
}

zones[Z["Dustwallow Marsh"]] = {
    low = 33,
    high = 50,
    continent = Kalimdor,
    raids = {"Onyxia's Lair"},
    faction = "Contested",
    fishing_min = 130,
    herbs = {"Stranglekelp", "Kingsblood", "Liferoot", "Fadeleaf", "Goldthorn", "Khadgar's Whisker"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"}
}

zones[Z["The Hinterlands"]] = {
    low = 41,
    high = 49,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Stranglekelp", "Liferoot", "Fadeleaf", "Goldthorn", "Khadgar's Whisker", "Purple Lotus", "Sungrass", "Ghost Mushroom", "Golden Sansam"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein"}
}

zones[Z["Feralas"]] = {
    low = 41,
    high = 50,
    continent = Kalimdor,
    instances = {"Dire Maul: East", "Dire Maul: North", "Dire Maul: West"},
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Stranglekelp", "Liferoot", "Goldthorn", "Khadgar's Whisker", "Purple Lotus", "Sungrass", "Golden Sansam"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Ooze Covered Gold Vein", "Mithril Deposit", "Ooze Covered Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein", "Ooze Covered Thorium Vein"}
}

zones[Z["Azshara"]] = {
    low = 42,
    high = 55,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Stranglekelp", "Goldthorn", "Khadgar's Whisker", "Purple Lotus", "Sungrass", "Golden Sansam", "Mountain Silversage"},
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Rich Thorium Vein"}
}

zones[Z["Western Plaguelands"]] = {
    low = 43,
    high = 57,
    continent = Eastern_Kingdoms,
    instances = {"Scholomance"},
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Arthas' Tears", "Sungrass", "Dreamfoil", "Mountain Silversage", "Plaguebloom"},
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit","Small Thorium Vein", "Rich Thorium Vein"}
}

zones[Z["Burning Steppes"]] = {
    low = 50,
    high = 59,
    continent = Eastern_Kingdoms,
    instances = {"Blackrock Depths", "Blackrock Spire"},
    raids = {"Molten Core", "Blackwing Lair"},
    faction = "Contested",
    fishing_min = 330,
    herbs = {"Sungrass", "Golden Sansam", "Dreamfoil", "Mountain Silversage", "Black Lotus"},
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit","Dark Iron Deposit", "Small Thorium Vein", "Rich Thorium Vein"}
}

zones[Z["Felwood"]] = {
    low = 47,
    high = 54,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Arthas' Tears", "Sungrass", "Gromsblood", "Golden Sansam", "Dreamfoil", "Mountain Silversage", "Plaguebloom"},
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit","Small Thorium Vein"}
}

zones[Z["Searing Gorge"]] = {
    low = 43,
    high = 56,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    herbs = {"Firebloom"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit","Dark Iron Deposit", "Small Thorium Vein"}
}

zones[Z["Un'Goro Crater"]] = {
    low = 48,
    high = 55,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Sungrass", "Blindweed", "Golden Sansam", "Dreamfoil", "Mountain Silversage"},
    nodes = {"Truesilver Deposit", "Ooze Covered Truesilver Deposit", "Small Thorium Vein", "Ooze Covered Thorium Vein", "Rich Thorium Vein", "Ooze Covered Rich Thorium Vein"}
}

zones[Z["Winterspring"]] = {
    low = 55,
    high = 60,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 330,
    herbs = {"Mountain Silversage", "Icecap", "Black Lotus"},
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit","Small Thorium Vein", "Rich Thorium Vein"}
}

zones[Z["Blasted Lands"]] = {
    low = 46,
    high = 60,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    herbs = {"Goldthorn", "Firebloom", "Sungrass", "Gromsblood"},
    nodes = {"Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein"}
}

zones[Z["Eastern Plaguelands"]] = {
    low = 54,
    high = 59,
    continent = Eastern_Kingdoms,
    instances = {"Stratholme"},
    raids = {"Naxxramas"},
    faction = "Contested",
    fishing_min = 330,
    herbs = {"Arthas' Tears", "Sungrass", "Golden Sansam", "Dreamfoil", "Mountain Silversage", "Plaguebloom", "Black Lotus"},
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit","Small Thorium Vein", "Rich Thorium Vein"}
}

zones[Z["Deadwind Pass"]] = {
    low = 50,
    high = 60,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    fishing_min = 330
}

zones[Z["Silithus"]] = {
    low = 55,
    high = 59,
    continent = Kalimdor,
--    raids = {"Ruins of Ahn'Qiraj", "Ahn'Qiraj"},
    faction = "Contested",
    fishing_min = 330,
    herbs = {"Sungrass", "Golden Sansam", "Dreamfoil", "Mountain Silversage", "Black Lotus"},
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein", "Rich Thorium Vein", "Ooze Covered Rich Thorium Vein"}
}

-- City definition ---------------------------------------------------------------------------------------

zones[Z["Orgrimmar"]] = {
    low = 1,
    high = 60,
    continent = Kalimdor,
    instances = {"Ragefire Chasm"},
    faction = "Horde",
    fishing_min = 1
}

zones[Z["Thunder Bluff"]] = {
    low = 1,
    high = 60,
    continent = Kalimdor,
    faction = "Horde",
    fishing_min = 1
}

zones[Z["Undercity"]] = {
    low = 1,
    high = 60,
    continent = Eastern_Kingdoms,
    faction = "Horde",
    fishing_min = 1
}

zones[Z["Darnassus"]] = {
    low = 1,
    high = 60,
    continent = Kalimdor,
    faction = "Alliance",
    fishing_min = 1
}

zones[Z["Ironforge"]] = {
    low = 1,
    high = 60,
    continent = Eastern_Kingdoms,
    faction = "Alliance",
    fishing_min = 1
}

zones[Z["Stormwind City"]] = {
    low = 1,
    high = 60,
    continent = Eastern_Kingdoms,
    instances = {"The Stockade"},
    faction = "Alliance",
    fishing_min = 1
}

-- Instance definition ---------------------------------------------------------------------------------------

instances[Z["Ragefire Chasm"]] = {
    low = 13,
    high = 22,
    continent = Kalimdor,
    entrance = {52, 49},
}

instances[Z["The Deadmines"]] = {
    low = 15,
    high = 28,
    continent = Eastern_Kingdoms,
    entrance = {42, 72},
    fishing_min = 20
}

instances[Z["Wailing Caverns"]] = {
    low = 15,
    high = 28,
    continent = Kalimdor,
    entrance = {46, 36},
    fishing_min = 20
}

instances[Z["Shadowfang Keep"]] = {
    low = 18,
    high = 32,
    continent = Eastern_Kingdoms,
    entrance = {42.7, 67.7},
}

instances[Z["Blackfathom Deeps"]] = {
    low = 20,
    high = 35,
    continent = Kalimdor,
    entrance = {14, 14},
    fishing_min = 20
}

instances[Z["The Stockade"]] = {
    low = 22,
    high = 30,
    continent = Eastern_Kingdoms,
    entrance = {41, 57}
}

instances[Z["Gnomeregan"]] = {
    low = 24,
    high = 40,
    continent = Eastern_Kingdoms,
    entrance = {24, 40}
}

instances[Z["Razorfen Kraul"]] = {
    low = 24,
    high = 40,
    continent = Kalimdor,
    entrance = {42, 90}
}

instances[Z["Scarlet Monastery"]..": Graveyard"] = {
    low = 26,
    high = 36,
    continent = Eastern_Kingdoms,
    entrance = {84.28, 30.63}
}

instances[Z["Scarlet Monastery"]..": Library"] = {
    low = 29,
    high = 39,
    continent = Eastern_Kingdoms,
    entrance = {85.30, 33}
}

instances[Z["Scarlet Monastery"]..": Armory"] = {
    low = 32,
    high = 42,
    continent = Eastern_Kingdoms,
    entrance = {85.83, 31.62}
}

instances[Z["Scarlet Monastery"]..": Cathedral"] = {
    low = 35,
    high = 45,
    continent = Eastern_Kingdoms,
    entrance = {85.35, 30.57}
}

instances[Z["Razorfen Downs"]] = {
    low = 33,
    high = 47,
    continent = Kalimdor,
    entrance = {49, 96}
}

instances[Z["Uldaman"]] = {
    low = 35,
    high = 52,
    continent = Eastern_Kingdoms,
    entrance = {43, 14}
}

instances[Z["Maraudon"]] = {
    low = 35,
    high = 52,
    continent = Kalimdor,
    entrance = {29, 63},
    fishing_min = 205
}

instances[Z["Zul'Farrak"]] = {
    low = 43,
    high = 54,
    continent = Kalimdor,
    entrance = {39, 20}
}

instances[Z["The Temple of Atal'Hakkar"]] = {
    low = 44,
    high = 60,
    continent = Eastern_Kingdoms,
    entrance = {70, 54},
    fishing_min = 205
}

instances[Z["Blackrock Depths"]] = {
    low = 48,
    high = 60,
    continent = Eastern_Kingdoms,
    entrance = {29, 38}
}

instances[Z["Blackrock Spire"]] = {
    low = 52,
    high = 60,
    continent = Eastern_Kingdoms,
    entrance = {28, 38}
}

instances[Z["Stratholme"]] = {
    low = 56,
    high = 60,
    continent = Eastern_Kingdoms,
    entrance = {31, 13},
    fishing_min = 330
}

instances[Z["Dire Maul"]..": East"] = {
    low = 36,
    high = 46,
    continent = Kalimdor,
    entrance = {59.5, 44}
}

instances[Z["Dire Maul"]..": West"] = {
    low = 39,
    high = 49,
    continent = Kalimdor,
    entrance = {58, 44}
}

instances[Z["Dire Maul"]..": North"] = {
    low = 42,
    high = 52,
    continent = Kalimdor,
    entrance = {58.9, 41.5}
}

instances[Z["Scholomance"]] = {
    low = 56,
    high = 60,
    continent = Eastern_Kingdoms,
    entrance = {69, 73},
    fishing_min = 330
}

-- Raid definition ---------------------------------------------------------------------------------------

raids[Z["Molten Core"]] = {
    low = 55,
    high = 60,
    players = 40,
    continent = Eastern_Kingdoms,
    entrance = {30.5, 38}
}

-- raids[Z["Onyxia's Lair"]] = {
--     low = 55,
--     high = 60,
--     players = 40,
--     continent = Kalimdor,
--     entrance = {56, 71}
-- }

raids[Z["Blackwing Lair"]] = {
    low = 60,
    high = 60,
    players = 40,
    continent = Eastern_Kingdoms,
    entrance = {29, 34}
}

-- raids[Z["Zul'Gurub"]] = {
--     low = 60,
--     high = 60,
--     players = 40,
--     continent = Eastern_Kingdoms,
--     entrance = {53.9, 17.6}
-- }

raids[Z["Ruins of Ahn'Qiraj"]] = {
    low = 60,
    high = 60,
    players = 20,
    continent = Kalimdor,
    entrance = {29, 93}
}

-- raids[Z["Ahn'Qiraj"]] = {
--     low = 60,
--     high = 60,
--     players = 40,
--     continent = Kalimdor,
--     entrance = {28.6, 92.4}
-- }

raids[Z["Naxxramas"]] = {
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

nodes["Ooze Covered Silver Vein"] = {
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

nodes["Ooze Covered Gold Vein"] = {
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

-- Cloth definition ---------------------------------------------------------------------------------------
-- Might be nice to have cloth drops mapped as well. Not sure if this is possible though.

