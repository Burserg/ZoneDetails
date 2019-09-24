--[[
-- Credit to ckknight for originally writing Cartographer_ZoneDetails
-- Credit to phyber for writing Cromulent
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
local complexes = {}
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
                local r2, g2, b2 = ZoneDetails:LevelColor(zones[mapID].low, zones[mapID].high, playerLevel)
                local r1, g1, b1 = ZoneDetails:GetFactionColor(mapID)
                zoneText = ("|cff%02x%02x%02x%s|r |cff%02x%02x%02x[%d-%d]|r\n\n"):format(
                    r1*255,
                    g1*255,
                    b1*255,
                    mapName,
                    r2*255,
                    g2*255,
                    b2*255,
                    zones[mapID].low,
                    zones[mapID].high
                    )
                else
                    zoneText = ""
                end
            -- Do work to get zone name, level, faction, and any instances/raids.
            if db.showInstances then
                if zones[mapID].instances then
                    zoneText = zoneText..("\n|cffffff00%s:|r"):format(L["Instances"])
                    for _, instance in ipairs(zones[mapID].instances) do
                        local r2, g2, b2 = ZoneDetails:LevelColor(instances[instance].low, instances[instance].high, playerLevel)
                        local r1, g1, b1 = ZoneDetails:GetFactionColor(mapID)
                        zoneText = zoneText..("\n|cff%02x%02x%02x%s|r |cff%02x%02x%02x[%d-%d]|r"):format(
                            r1*255, 
                            g1*255, 
                            b1*255, 
                            GetRealZoneText(instance),
                            r2*255,
                            g2*255,
                            b2*255,
                            instances[instance].low, 
                            instances[instance].high
                        )
                    end
                end
                if zones[mapID].complexes then
                    zoneText = zoneText..("\n|cffffff00%s:|r"):format(L["Instances"])
                    for _, complex in ipairs(zones[mapID].complexes) do
                        for _, instance in ipairs(complexes[complex].instances) do
                            local r2, g2, b2 = ZoneDetails:LevelColor(instances[instance].low, instances[instance].high, playerLevel)
                            local r1, g1, b1 = ZoneDetails:GetFactionColor(mapID)
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
            end
            
            if db.showBattlegrounds then
                if zones[mapID].battlegrounds then
                    zoneText = zoneText..("\n|cffffff00%s:|r"):format(L["Battlegrounds"])
                    for _, battleground in ipairs(zones[mapID].battlegrounds) do
                        local r2, g2, b2 = ZoneDetails:LevelColor(battlegrounds[battleground].low, battlegrounds[battleground].high, playerLevel)
                        local r1, g1, b1 = ZoneDetails:GetFactionColor(mapID)
                        zoneText = zoneText ..("\n|cff%02x%02x%02x%s|r |cff%02x%02x%02x[%d-%d]|r   %s-%s"):format(
                            r1*255,
                            g1*255,
                            b2*255,
                            GetRealZoneText(battleground),
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
                if zones[mapID].raids then
                    zoneText = zoneText..("\n|cffffff00%s:|r"):format(L["Raids"])
                    for _, raid in ipairs(zones[mapID].raids) do
                        local r2, g2, b2 = ZoneDetails:LevelColor(raids[raid].low, raids[raid].high, playerLevel)
                        local r1, g1, b1 = ZoneDetails:GetFactionColor(mapID)
                        zoneText = zoneText ..("\n|cff%02x%02x%02x%s|r |cff%02x%02x%02x[%d]|r   %s-%s"):format(
                            r1*255,
                            g1*255,
                            b2*255,
                            GetRealZoneText(raid),
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
            if db.showFishing and zones[mapID].fishing_min then
                if profs[L["Fishing"]] then
                    local r, g, b = ZoneDetails:FishingColor(zones[mapID].fishing_min, profs[L["Fishing"]])
                    profText = profText ..("\n|cffffff00%s|r |cff%02x%02x%02x[%d]|r\n"):format(
                        L["Fishing Minimum"],
                        r*255,
                        g*255,
                        b*255,
                        zones[mapID].fishing_min
                    )
                end
            end

            if db.showHerbs and zones[mapID].herbs then
                if profs[L["Herbalism"]] then
                    profText = profText..("\n|cffffff00%s:|r"):format(L["Herbs"])
                    for _, herb in ipairs(zones[mapID].herbs) do
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

            if db.showMineNodes and zones[mapID].nodes then
                if profs[L["Mining"]] then
                    profText = profText..("\n|cffffff00%s:|r"):format(L["Nodes"])
                    for _, node in ipairs(zones[mapID].nodes) do
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
            if db.showInstancePins then
                if zones[mapID].instances then
                    for _, instance in ipairs(zones[mapID].instances) do
                        local r2, g2, b2 = ZoneDetails:LevelColor(instances[instance].low, instances[instance].high, playerLevel)
                        local r1, g1, b1 = ZoneDetails:GetFactionColor(mapID)
                        local name = ("|cff%02x%02x%02x%s|r"):format(
                            r1*255, 
                            g1*255, 
                            b1*255, 
                            GetRealZoneText(instance)
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
                if zones[mapID].complexes then
                    for _, complex in ipairs(zones[mapID].complexes) do
                        for _, instance in ipairs(complexes[complex].instances) do
                            local r2, g2, b2 = ZoneDetails:LevelColor(instances[instance].low, instances[instance].high, playerLevel)
                            local r1, g1, b1 = ZoneDetails:GetFactionColor(mapID)
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
            end

            if db.showRaidPins then
                if zones[mapID].raids then
                    for _, raid in ipairs(zones[mapID].raids) do
                        local r2, g2, b2 = ZoneDetails:LevelColor(raids[raid].low, raids[raid].high, playerLevel)
                        local r1, g1, b1 = ZoneDetails:GetFactionColor(mapID)
                        local name = ("|cff%02x%02x%02x%s|r %s-Man"):format(
                            r1*255, 
                            g1*255, 
                            b1*255, 
                            GetRealZoneText(raid),
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

-- Elwynn Forest
zones[1429] = {
    low = 1,
    high = 10,
    continent = Eastern_Kingdoms,
    faction = "Alliance",
    fishing_min = 1,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot"},
    nodes = {"Copper Vein"}
}
-- Teldrassil

zones[1438] = {
    low = 1,
    high = 11,
    continent = Kalimdor,
    faction = "Alliance",
    fishing_min = 1,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot"}
}
-- Dun Morogh
zones[1426] = {
    low = 1,
    high = 12,
    continent = Eastern_Kingdoms,
    faction = "Alliance",
    fishing_min = 1,
    instances = {90},
    herbs = {"Peacebloom", "Silverleaf", "Earthroot"},
    nodes = {"Copper Vein"}
}
-- Westfall

zones[1436] = {
    low = 9,
    high = 18,
    continent = Eastern_Kingdoms,
    instances = {36},
    faction = "Alliance",
    fishing_min = 55,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Bruiseweed"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"}
}
-- Loch Modan
zones[1432] = {
    low = 10,
    high = 18,
    continent = Eastern_Kingdoms,
    faction = "Alliance",
    fishing_min = 20,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Bruiseweed"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"}
}

-- Darkshore
zones[1439] = {
    low = 11,
    high = 19,
    continent = Eastern_Kingdoms,
    faction = "Alliance",
    fishing_min = 20,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"}
}

-- Horde 

-- Durotar
zones[1411] = {
    low = 1,
    high = 10,
    continent = Kalimdor,
    faction = "Horde",
    fishing_min = 1,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal"},
    nodes = {"Copper Vein"}
}

-- Mulgore
zones[1412] = {
    low = 1,
    high = 10,
    continent = Kalimdor,
    faction = "Horde",
    fishing_min = 1,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot"},
    nodes = {"Copper Vein"}
}
-- Tirisfal Glades
zones[1420] = {
    low = 1,
    high = 12,
    continent = Eastern_Kingdoms,
    complexes = {189},
    faction = "Horde",
    fishing_min = 1,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot"},
    nodes = {"Copper Vein"}
}
-- Silverpine Forest
zones[1421] = {
    low = 10,
    high = 20,
    instances = {33},
    continent = Eastern_Kingdoms,
    faction = "Horde",
    fishing_min = 20,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"}
}
-- The Barrens
zones[1413] = {
    low = 10,
    high = 33,
    continent = Kalimdor,
    instances = {43, 47, 129},
    battlegrounds = {489},
    faction = "Horde",
    fishing_min = 20,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Grave Moss", "Kingsblood"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"}
}

-- Contested

-- Duskwood
zones[1431] = {
    low = 10,
    high = 30,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    fishing_min = 55,
    herbs = {"Mageroyal", "Briarthorn", "Wild Steelbloom", "Grave Moss", "Kingsblood"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein"}
}
-- Moonglade
zones[1450] = {
    low = 10,
    high = 60,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 205
}
-- Stonetalon Mountains
zones[1442] = {
    low = 15,
    high = 25,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 55,
    herbs = {"Mageroyal", "Bruiseweed", "Wild Steelbloom", "Kingsblood"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"}
}
-- Redridge Mountains
zones[1433] = {
    low = 15,
    high = 25,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    fishing_min = 55,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Bruiseweed"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"}
}
-- Ashenvale
zones[1440] = {
    low = 19,
    high = 30,
    instances = {48},
    battlegrounds = {489},
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 55,
    herbs = {"Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Kingsblood", "Liferoot"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein"}
}
-- Wetlands
zones[1437] = {
    low = 20,
    high = 30,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    fishing_min = 55,
    herbs = {"Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Grave Moss", "Kingsblood", "Liferoot"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein"}
}
-- Hillsbrad Foothills
zones[1424] = {
    low = 20,
    high = 31,
    continent = Eastern_Kingdoms,
    battlegrounds = {30},
    faction = "Contested",
    fishing_min = 55,
    herbs = {"Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Kingsblood", "Liferoot"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit"}
}

-- Alterac Mountains
zones[1416] = {
    low = 27,
    high = 39,
    continent = Eastern_Kingdoms,
    battlegrounds = {30},
    faction = "Contested",
    fishing_min = 130,
    herbs = {"Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Grave Moss", "Kingsblood", "Liferoot", "Fadeleaf", "Goldthorn", "Khadgar's Whisker", "Wintersbite"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"}
}

-- Thousand Needles
zones[1441] = {
    low = 24,
    high = 35,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 130,
    herbs = {"Bruiseweed", "Wild Steelbloom", "Kingsblood"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Ooze Covered Silver Vein", "Iron Deposit", "Gold Vein", "Ooze Covered Gold Vein", "Mithril Deposit", "Ooze Covered Mithril Deposit"}
}
-- Desolace
zones[1443] = {
    low = 30,
    high = 39,
    continent = Kalimdor,
    instances = {349},
    faction = "Contested",
    fishing_min = 130,
    herbs = {"Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Grave Moss", "Kingsblood", "Liferoot", "Gromsblood"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"}
}
-- Arathi Highlands
zones[1417] = {
    low = 30,
    high = 40,
    continent = Eastern_Kingdoms,
    battlegrounds = {529},
    faction = "Contested",
    fishing_min = 130,
    herbs = {"Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Grave Moss", "Kingsblood", "Liferoot", "Fadeleaf", "Goldthorn", "Khadgar's Whisker"},
    nodes = {"Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"}
}
-- Swamp of Sorrows
zones[1435] = {
    low = 36,
    high = 43,
    continent = Eastern_Kingdoms,
    instances = {109},
    faction = "Contested",
    fishing_min = 130,
    herbs = {"Stranglekelp", "Kingsblood", "Fadeleaf", "Goldthorn", "Khadgar's Whisker", "Blindweed"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein"}
}
-- Badlands
zones[1418] = {
    low = 36,
    high = 45,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    herbs = {"Wild Steelbloom", "Kingsblood", "Fadeleaf", "Goldthorn", "Khadgar's Whisker", "Firebloom", "Purple Lotus"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"}
}
--Stranglethorn Vale
zones[1434] = {
    low = 30,
    high = 50,
    continent = Eastern_Kingdoms,
    raids = {309},
    faction = "Contested",
    fishing_min = 130,
    herbs = {"Stranglekelp", "Wild Steelbloom", "Kingsblood", "Liferoot", "Fadeleaf", "Goldthorn", "Khadgar's Whisker", "Purple Lotus"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"}
}
--Tanaris
zones[1446] = {
    low = 40,
    high = 50,
    continent = Kalimdor,
    instances = {209},
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Stranglekelp", "Firebloom", "Purple Lotus"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein"}
}
-- Dustwallow Marsh
zones[1445] = {
    low = 33,
    high = 50,
    continent = Kalimdor,
    raids = {249},
    faction = "Contested",
    fishing_min = 130,
    herbs = {"Stranglekelp", "Kingsblood", "Liferoot", "Fadeleaf", "Goldthorn", "Khadgar's Whisker"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"}
}
-- The Hinterlands
zones[1425] = {
    low = 41,
    high = 49,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Stranglekelp", "Liferoot", "Fadeleaf", "Goldthorn", "Khadgar's Whisker", "Purple Lotus", "Sungrass", "Ghost Mushroom", "Golden Sansam"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein"}
}
-- Feralas
zones[1444] = {
    low = 41,
    high = 50,
    continent = Kalimdor,
    complexes = {429},
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Stranglekelp", "Liferoot", "Goldthorn", "Khadgar's Whisker", "Purple Lotus", "Sungrass", "Golden Sansam"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Ooze Covered Gold Vein", "Mithril Deposit", "Ooze Covered Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein", "Ooze Covered Thorium Vein"}
}
-- Azshara
zones[1447] = {
    low = 42,
    high = 55,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Stranglekelp", "Goldthorn", "Khadgar's Whisker", "Purple Lotus", "Sungrass", "Golden Sansam", "Mountain Silversage"},
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Rich Thorium Vein"}
}
-- Western Plaguelands
zones[1422] = {
    low = 43,
    high = 57,
    continent = Eastern_Kingdoms,
    instances = {289},
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Arthas' Tears", "Sungrass", "Dreamfoil", "Mountain Silversage", "Plaguebloom"},
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit","Small Thorium Vein", "Rich Thorium Vein"}
}
-- Burning Steppes
zones[1428] = {
    low = 50,
    high = 59,
    continent = Eastern_Kingdoms,
    instances = {230, 229},
    raids = {409, 469},
    faction = "Contested",
    fishing_min = 330,
    herbs = {"Sungrass", "Golden Sansam", "Dreamfoil", "Mountain Silversage", "Black Lotus"},
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit","Dark Iron Deposit", "Small Thorium Vein", "Rich Thorium Vein"}
}
-- Felwood
zones[1448] = {
    low = 47,
    high = 54,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Arthas' Tears", "Sungrass", "Gromsblood", "Golden Sansam", "Dreamfoil", "Mountain Silversage", "Plaguebloom"},
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit","Small Thorium Vein"}
}
-- Searing Gorge
zones[1427] = {
    low = 43,
    high = 56,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    herbs = {"Firebloom"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit","Dark Iron Deposit", "Small Thorium Vein"}
}
-- Un'Goro Crater
zones[1449] = {
    low = 48,
    high = 55,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Sungrass", "Blindweed", "Golden Sansam", "Dreamfoil", "Mountain Silversage"},
    nodes = {"Truesilver Deposit", "Ooze Covered Truesilver Deposit", "Small Thorium Vein", "Ooze Covered Thorium Vein", "Rich Thorium Vein", "Ooze Covered Rich Thorium Vein"}
}
-- Winterspring
zones[1452] = {
    low = 55,
    high = 60,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 330,
    herbs = {"Mountain Silversage", "Icecap", "Black Lotus"},
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit","Small Thorium Vein", "Rich Thorium Vein"}
}
-- Blasted Lands
zones[1419] = {
    low = 46,
    high = 60,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    herbs = {"Goldthorn", "Firebloom", "Sungrass", "Gromsblood"},
    nodes = {"Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein"}
}
-- Eastern Plaguelands
zones[1423] = {
    low = 54,
    high = 59,
    continent = Eastern_Kingdoms,
    instances = {329},
    raids = {533},
    faction = "Contested",
    fishing_min = 330,
    herbs = {"Arthas' Tears", "Sungrass", "Golden Sansam", "Dreamfoil", "Mountain Silversage", "Plaguebloom", "Black Lotus"},
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit","Small Thorium Vein", "Rich Thorium Vein"}
}
-- Deadwind Pass
zones[1430] = {
    low = 50,
    high = 60,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    fishing_min = 330
}
-- Silithus
zones[1451] = {
    low = 55,
    high = 59,
    continent = Kalimdor,
    raids = {509, 531},
    faction = "Contested",
    fishing_min = 330,
    herbs = {"Sungrass", "Golden Sansam", "Dreamfoil", "Mountain Silversage", "Black Lotus"},
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein", "Rich Thorium Vein", "Ooze Covered Rich Thorium Vein"}
}

-- City definition ---------------------------------------------------------------------------------------
-- Orgrimmar
zones[1454] = {
    low = 1,
    high = 60,
    continent = Kalimdor,
    instances = {389},
    faction = "Horde",
    fishing_min = 1
}
-- Thunder Bluff
zones[1456] = {
    low = 1,
    high = 60,
    continent = Kalimdor,
    faction = "Horde",
    fishing_min = 1
}
-- Undercity
zones[1458] = {
    low = 1,
    high = 60,
    continent = Eastern_Kingdoms,
    faction = "Horde",
    fishing_min = 1
}
-- Darnassus
zones[1457] = {
    low = 1,
    high = 60,
    continent = Kalimdor,
    faction = "Alliance",
    fishing_min = 1
}
-- Ironforge
zones[1455] = {
    low = 1,
    high = 60,
    continent = Eastern_Kingdoms,
    faction = "Alliance",
    fishing_min = 1
}
-- Stormwind City
zones[1453] = {
    low = 1,
    high = 60,
    continent = Eastern_Kingdoms,
    instances = {34},
    faction = "Alliance",
    fishing_min = 1
}

-- Instance definition ---------------------------------------------------------------------------------------
-- Ragefire Chasm
instances[389] = {
    low = 13,
    high = 22,
    continent = Kalimdor,
    entrance = {52, 49},
}
-- The Deadmines
instances[36] = {
    low = 15,
    high = 28,
    continent = Eastern_Kingdoms,
    entrance = {42, 72},
    fishing_min = 20
}
-- Wailing Caverns
instances[43] = {
    low = 15,
    high = 28,
    continent = Kalimdor,
    entrance = {46, 36},
    fishing_min = 20
}
-- Shadowfang Keep
instances[33] = {
    low = 18,
    high = 32,
    continent = Eastern_Kingdoms,
    entrance = {42.7, 67.7},
}
-- Blackfathom Deeps
instances[48] = {
    low = 20,
    high = 35,
    continent = Kalimdor,
    entrance = {14, 14},
    fishing_min = 20
}
-- The Stockade
instances[34] = {
    low = 22,
    high = 30,
    continent = Eastern_Kingdoms,
    entrance = {41, 57}
}
-- Gnomeregan
instances[90] = {
    low = 24,
    high = 40,
    continent = Eastern_Kingdoms,
    entrance = {24, 40}
}
-- Razorfen Kraul
instances[47] = {
    low = 24,
    high = 40,
    continent = Kalimdor,
    entrance = {42, 90}
}
-- Razorfen Down
instances[129] = {
    low = 33,
    high = 47,
    continent = Kalimdor,
    entrance = {49, 96}
}
-- Uldaman
instances[70] = {
    low = 35,
    high = 52,
    continent = Eastern_Kingdoms,
    entrance = {43, 14}
}
-- Maraudon
instances[349] = {
    low = 35,
    high = 52,
    continent = Kalimdor,
    entrance = {29, 63},
    fishing_min = 205
}
-- Zul'Farrak
instances[209] = {
    low = 43,
    high = 54,
    continent = Kalimdor,
    entrance = {39, 20}
}
-- The Temple of Atal'Hakkar / Sunken Temple
instances[109] = {
    low = 44,
    high = 60,
    continent = Eastern_Kingdoms,
    entrance = {70, 54},
    fishing_min = 205
}
-- Blackrock Depths
instances[230] = {
    low = 48,
    high = 60,
    continent = Eastern_Kingdoms,
    entrance = {29, 38}
}
-- Blackrock Spire
instances[229] = {
    low = 52,
    high = 60,
    continent = Eastern_Kingdoms,
    entrance = {28, 38}
}
-- Stratholme
instances[329] = {
    low = 56,
    high = 60,
    continent = Eastern_Kingdoms,
    entrance = {31, 13},
    fishing_min = 330
}

-- Scholomance
instances[289] = {
    low = 56,
    high = 60,
    continent = Eastern_Kingdoms,
    entrance = {69, 73},
    fishing_min = 330
}

-- Dire Maul
instances[L["Dire Maul: East"]] = {
    low = 36,
    high = 46,
    continent = Kalimdor,
    entrance = {59.5, 44}
}

instances[L["Dire Maul: West"]] = {
    low = 39,
    high = 49,
    continent = Kalimdor,
    entrance = {58, 44}
}

instances[L["Dire Maul: North"]] = {
    low = 42,
    high = 52,
    continent = Kalimdor,
    entrance = {58.9, 41.5}
}

-- Scarlet Monastery

instances[L["Scarlet Monastery: Graveyard"]] = {
    low = 26,
    high = 36,
    continent = Eastern_Kingdoms,
    entrance = {84.28, 30.63}
}

instances[L["Scarlet Monastery: Library"]] = {
    low = 29,
    high = 39,
    continent = Eastern_Kingdoms,
    entrance = {85.30, 33}
}

instances[L["Scarlet Monastery: Armory"]] = {
    low = 32,
    high = 42,
    continent = Eastern_Kingdoms,
    entrance = {85.83, 31.62}
}

instances[L["Scarlet Monastery: Cathedral"]] = {
    low = 35,
    high = 45,
    continent = Eastern_Kingdoms,
    entrance = {85.35, 30.57}
}

-- Raid definition ---------------------------------------------------------------------------------------
-- Molten Core
raids[409] = {
    low = 55,
    high = 60,
    players = 40,
    continent = Eastern_Kingdoms,
    entrance = {30.5, 38}
}
-- Onyxia's Lair
raids[249] = {
    low = 55,
    high = 60,
    players = 40,
    continent = Kalimdor,
    entrance = {52, 76}
}
-- Blackwing Lair
raids[469] = {
    low = 60,
    high = 60,
    players = 40,
    continent = Eastern_Kingdoms,
    entrance = {29, 34}
}
-- Zul'Gurub
raids[309] = {
    low = 60,
    high = 60,
    players = 40,
    continent = Eastern_Kingdoms,
    entrance = {53.9, 17.6}
}
-- Ruins of Ahn'Qiraj
raids[509] = {
    low = 60,
    high = 60,
    players = 20,
    continent = Kalimdor,
    entrance = {29, 93}
}
-- Ahn'Qiraj Temple
raids[531] = {
    low = 60,
    high = 60,
    players = 40,
    continent = Kalimdor,
    entrance = {28.6, 92.4}
}
-- Naxxramas
raids[533] = {
    low = 60,
    high = 60,
    players = 40,
    continent = Eastern_Kingdoms,
    entrance = {39, 26}
}

-- Battlegrounds ---------------------------------------------------------------------------------------
-- Warsong Gulch
battlegrounds[489] = {
    low = 10,
    high = 60,
    horde_entrance = {},
    alliance_entrance = {},
    players = 10
}
-- Arathi Basin
battlegrounds[529] = {
    low = 20,
    high = 60,
    horde_entrance = {},
    alliance_entrance = {},
    players = 15
}
-- Alterac Valley
battlegrounds[30] = {
    low = 51,
    high = 60,
    horde_entrance = {},
    alliance_entrance = {},
    players = 40
}

-- Complexes ---------------------------------------------------------------------------------------

-- Scarlet Monastery
complexes[189] = {
    instances = {
        L["Scarlet Monastery: Graveyard"],
        L["Scarlet Monastery: Library"],
        L["Scarlet Monastery: Armory"],
        L["Scarlet Monastery: Cathedral"]
    },
}

-- Dire Maul
complexes[429] = {
    instances = {
        L["Dire Maul: East"],
        L["Dire Maul: West"],
        L["Dire Maul: North"]
    },
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
