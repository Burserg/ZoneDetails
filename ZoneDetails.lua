--[[
-- ZoneDetails - Multi-Expansion Classic Edition
-- Credit to ckknight for originally writing Cartographer_ZoneDetails
-- Credit to phyber for writing Cromulent
--]]
ZoneDetails = LibStub("AceAddon-3.0"):NewAddon("ZoneDetails", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")
ZoneDetailsGlobalPinMixin = BaseMapPoiPinMixin:CreateSubPin("PIN_FRAME_LEVEL_DUNGEON_ENTRANCE")

local L = LibStub("AceLocale-3.0"):GetLocale("ZoneDetails")
local AceGUI = LibStub("AceGUI-3.0")
local ZoneDetailsDataProviderMixin = CreateFromMixins(MapCanvasDataProviderMixin)
local ZoneDetailsPinDataProviderMixin = CreateFromMixins(MapCanvasDataProviderMixin)
local WORLDMAP_CONTINENT = Enum.UIMapType.Continent
local WORLDMAP_ZONE = Enum.UIMapType.Zone
local WORLDMAP_AZEROTH_ID = 947
local playerLevel = UnitLevel("player")
local db

local isAlliance, isHorde, isNeutral

do
    local faction = UnitFactionGroup("player")
    isAlliance = faction == "Alliance"
    isHorde = faction == "Horde"
    isNeutral = not isAlliance and not isHorde
end

local zones = {}
local instances = {}
local raids = {}
local battlegrounds = {}
local complexes = {}
local nodes = {}
local herbs = {}

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
    L["Fishing"],
    L["Jewelcrafting"],
}

local tocVersion = select(4, GetBuildInfo())
local isVanilla = tocVersion < 20000
local isTBC = tocVersion >= 20000 and tocVersion < 30000
local isWrath = tocVersion >= 30000 and tocVersion < 40000
local isCata = tocVersion >= 40000 and tocVersion < 50000
local isMoP = tocVersion >= 50000 and tocVersion < 60000

-- Season of Discovery runs on the Era client, so tocVersion can't distinguish it.
-- Guard every step: on clients without the seasons API the chain short-circuits to
-- falsy with no error, and on a non-seasonal Era realm GetActiveSeason returns a
-- non-SoD value.
local isSoD = isVanilla and C_Seasons and C_Seasons.GetActiveSeason
    and Enum and Enum.SeasonID and Enum.SeasonID.SeasonOfDiscovery
    and C_Seasons.GetActiveSeason() == Enum.SeasonID.SeasonOfDiscovery

local MAX_LEVEL = isMoP and 90 or (isTBC and 70 or 60)

local Azeroth = "Azeroth"
local Kalimdor = "Kalimdor"
local Eastern_Kingdoms = "Eastern Kingdoms"
local Outland = "Outland"
local Pandaria = "Pandaria"

local WORLDMAP_OUTLAND_ID = isMoP and 101 or 1945
local WORLDMAP_PANDARIA_ID = 424

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

        -- Instance/Raid/BG Map Options
        showInstances = true,
        showInstancePins = true,
        showRaidPins = true,
        showZoneLevel = true,
        showBattlegrounds = true,
        showRaids = true,
        showContinentHover = true,

        -- Zone Text Map Options
        zoneTextFontSize = 32,
        zoneTextLocation = "TOP",

        -- Instance Text Map Options
        instanceTextFontSize = 32,

        -- On-Hover (pin) Text Options
        hoverTextFontSize = 16,

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
    set = function(k, v)
        db[k.arg] = v
        -- Re-render the map text so toggles and size changes apply immediately.
        ZoneDetails:RefreshMapText()
    end,
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
                showContinentHover = {
                    type = "toggle",
                    order = 6,
                    name = L["Show Continent Hover"],
                    arg = "showContinentHover",
                    desc = L["Toggles showing a zone's details in the corner overlay when you hover it on a continent map."],
                    width = "full",
                },
                textSizeHeader = {
                    type = "header",
                    name = L["Text Size"],
                    order = 10,
                },
                zoneTextFontSize = {
                    type = "range",
                    order = 11,
                    name = L["Zone Text Size"],
                    arg = "zoneTextFontSize",
                    desc = L["Adjusts the size of the zone name text shown on the map."],
                    min = 12,
                    max = 64,
                    step = 1,
                    width = "full",
                },
                instanceTextFontSize = {
                    type = "range",
                    order = 12,
                    name = L["Instance Text Size"],
                    arg = "instanceTextFontSize",
                    desc = L["Adjusts the size of the static instance, raid, and battleground block shown on the map."],
                    min = 12,
                    max = 64,
                    step = 1,
                    width = "full",
                },
                hoverTextFontSize = {
                    type = "range",
                    order = 13,
                    name = L["Hover Text Size"],
                    arg = "hoverTextFontSize",
                    desc = L["Adjusts the size of the instance/raid details shown above the cursor when hovering their map icons."],
                    min = 12,
                    max = 64,
                    step = 1,
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
                profTextSizeHeader = {
                    type = "header",
                    name = L["Text Size"],
                    order = 10,
                },
                profTextFontSize = {
                    type = "range",
                    order = 11,
                    name = L["Profession Text Size"],
                    arg = "profTextFontSize",
                    desc = L["Adjusts the size of the profession text shown on the map."],
                    min = 12,
                    max = 64,
                    step = 1,
                    width = "full",
                },
            }
        },
    }
}

-- Debug helper
local function dbg(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end

-- ============================================================================
-- Map Data Provider Mixins
-- ============================================================================

-- Returns a font path whose glyphs are guaranteed to already be loaded.
-- WorldMapTextFont's font file is not loaded into the glyph cache until the
-- game's own on-screen zone text (or another frame) renders with it, so a
-- FontString using it can stay invisible until then. GameFontNormal uses the
-- standard UI font, which is always loaded.
local function GetMapFontPath()
    local path = GameFontNormal and GameFontNormal:GetFont()
    if path then return path end
    return "Fonts\\FRIZQT__.TTF"
end

-- The overlay text lives on frames parented to UIParent, anchored over the map
-- canvas. The hover tooltip uses the same parenting and composites reliably;
-- frames parented to the map canvas itself did not draw until an unrelated
-- frame forced a render pass. This keeps the text off the map's pin/canvas
-- pipeline entirely (and away from the player-position pin).
function ZoneDetailsDataProviderMixin:EnsureFrames()
    if self.overlay then return end

    local container = self:GetMap():GetCanvasContainer()

    -- Captured so the OnUpdate closure (whose self is the frame, not the data
    -- provider) can read the provider's hover state.
    local provider = self

    local overlay = CreateFrame("Frame", nil, UIParent)
    overlay:SetFrameStrata("FULLSCREEN_DIALOG")
    overlay:SetAllPoints(container)
    overlay:Hide()
    -- Track the map: stay anchored over the canvas, and hide when it closes. On
    -- continent maps the overlay also drives the cursor-zone hover (see
    -- ContinentHoverTick); the overlay must stay shown there or this never runs.
    overlay:SetScript("OnUpdate", function(self, elapsed)
        if not WorldMapFrame:IsShown() then
            self:Hide()
            return
        end
        if not provider.hoverMode then return end
        provider.hoverAccum = (provider.hoverAccum or 0) + elapsed
        if provider.hoverAccum < 0.05 then return end
        provider.hoverAccum = 0
        provider:ContinentHoverTick()
    end)

    local function makeText(point, justify)
        local fs = overlay:CreateFontString(nil, "OVERLAY")
        fs:SetScale(0.4)
        fs:SetJustifyH(justify)
        fs:SetPoint(point, overlay, point, point == "TOP" and 0 or (justify == "RIGHT" and -10 or 10),
            point == "TOP" and -35 or 10)
        return fs
    end

    self.overlay = overlay
    self.zoneText = makeText("TOP", "CENTER")
    self.instanceText = makeText("BOTTOMRIGHT", "RIGHT")
    self.profText = makeText("BOTTOMLEFT", "LEFT")
end

-- Remove the color escape sequences Blizzard embeds in some area-label names so we
-- can compare against the plain zone name.
local function StripColors(s)
    if not s then return "" end
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- Apply a header string to our zone text, scaled to the current setting.
local function SetZoneHeaderText(prov, text)
    prov.zoneText:SetFont(GetMapFontPath(), (db and db.zoneTextFontSize) or 32, "OUTLINE")
    prov.zoneText:SetText(text or "")
end

-- Post-hook for Blizzard's area-label frame. Runs every frame after Blizzard's
-- EvaluateLabels sets the text. While we own the shown/hovered zone, suppress the
-- native top-center label and fold what it would show into our single header:
--   * open ground -> "Zone [low-high]"
--   * a named subzone (same map) -> "Zone - Subzone [low-high]"
--   * an adjacent zone (a different map at the edge) -> that zone's own header
--     "Adjacent [its-low-high]" with its level colour, replacing the title.
-- The adjacent vs. subzone distinction comes from C_Map.GetMapInfoAtPosition (the same
-- call Blizzard uses), not from parsing the label text, so adjacent zones get their
-- correct level range even when Blizzard didn't append one.
local function AreaLabelPostHook(labelFrame)
    if not ZoneDetails:IsEnabled() then return end

    local prov = ZoneDetailsDataProviderMixin
    if not prov.zoneText or not labelFrame.Name then return end
    if not (db and db.showZoneLevel) then prov.lastRawNative = nil; return end

    local raw = labelFrame.Name:GetText() or ""

    -- Continent map: the hover tick already resolved the hovered child zone.
    if prov.hoverMode then
        local id = prov.lastHoveredID
        if not (id and zones[id]) then prov.lastRawNative = nil; return end
        labelFrame.Name:SetText("")
        if raw == prov.lastRawNative and id == prov.lastHeaderId then return end
        prov.lastRawNative, prov.lastHeaderId = raw, id
        local ok, header = pcall(ZoneDetails.GetZoneHeader, ZoneDetails, id)
        SetZoneHeaderText(prov, ok and header or "")
        return
    end

    -- Zone map: only take over when the shown map is a zone we track.
    local displayedMapID = WorldMapFrame:GetMapID()
    if not (displayedMapID and zones[displayedMapID]) then prov.lastRawNative = nil; return end

    labelFrame.Name:SetText("")  -- our header carries the (sub)zone instead

    -- Resolve what the cursor is over via C_Map.GetMapInfoAtPosition (not the label
    -- text): an adjacent zone is a different map and must be recognised even when
    -- Blizzard shows the same text for it as for somewhere in the current zone.
    local headerID, subzone = displayedMapID, nil
    if WorldMapFrame:IsCanvasMouseFocus() then
        local nx, ny = WorldMapFrame:GetNormalizedCursorPosition()
        local posInfo = C_Map.GetMapInfoAtPosition(displayedMapID, nx, ny)
        if posInfo and posInfo.mapID and posInfo.mapID ~= displayedMapID then
            -- Cursor is over a different map (an adjacent zone): replace the title.
            headerID = posInfo.mapID
        else
            -- Same map: a non-zone-name label is a subzone to fold in.
            local dispInfo = C_Map.GetMapInfo(displayedMapID)
            local stripped = StripColors(raw)
            if dispInfo and stripped ~= "" and stripped ~= dispInfo.name then
                subzone = stripped
            end
        end
    end

    -- Rebuild only when the resolved zone/subzone (or the fallback text) changes.
    if headerID == prov.lastHeaderId and subzone == prov.lastSub and raw == prov.lastRawNative then
        return
    end
    prov.lastHeaderId, prov.lastSub, prov.lastRawNative = headerID, subzone, raw

    local header
    if zones[headerID] then
        local ok, h = pcall(ZoneDetails.GetZoneHeader, ZoneDetails, headerID, subzone)
        header = ok and h or nil
    end
    -- Untracked adjacent zone: relocate Blizzard's own label so its name still shows
    -- in place of (rather than overlapping) our header.
    SetZoneHeaderText(prov, header or raw)
end

-- Find Blizzard's area-label frame among the World Map's data providers and install
-- the post-hook once. If the layout differs on some client the frame just isn't
-- found and the native zone name keeps showing (no error).
function ZoneDetailsDataProviderMixin:EnsureAreaLabelHook()
    if self.areaLabelHooked then return end
    if not WorldMapFrame.dataProviders then return end

    for dp in pairs(WorldMapFrame.dataProviders) do
        if type(dp) == "table" and dp.Label and dp.Label.EvaluateLabels and dp.Label.Name then
            hooksecurefunc(dp.Label, "EvaluateLabels", AreaLabelPostHook)
            self.areaLabelHooked = true
            return
        end
    end
end

-- Render the three corner strings from an explicit zone id. A nil mapID resolves
-- to the map currently shown (the static zone-map overlay); an id with no zones[]
-- entry yields nil from every getter, which clears the strings. pcall keeps a data
-- error from breaking the per-frame hover loop.
function ZoneDetailsDataProviderMixin:ApplyTexts(mapID)
    -- Invalidate the area-label hook's header cache so it rebuilds (with any subzone)
    -- on the next frame rather than leaving the base header we set here.
    self.lastRawNative = nil

    local font = GetMapFontPath()
    local function query(fn)
        local ok, res = pcall(fn, ZoneDetails, mapID)
        return ok and res or nil
    end

    self.zoneText:SetFont(font, (db and db.zoneTextFontSize) or 32, "OUTLINE")
    self.zoneText:SetText(query(ZoneDetails.GetZoneHeader) or "")

    self.instanceText:SetFont(font, (db and db.instanceTextFontSize) or 32, "OUTLINE")
    self.instanceText:SetText(query(ZoneDetails.GetInstanceDetails) or "")

    self.profText:SetFont(font, (db and db.profTextFontSize) or 32, "OUTLINE")
    self.profText:SetText(query(ZoneDetails.GetProfessionDetails) or "")
end

-- Throttled from the overlay OnUpdate while on a continent map: find the zone under
-- the cursor and render its details into the corner overlay.
function ZoneDetailsDataProviderMixin:ContinentHoverTick()
    -- Cursor over the sidebar/options/pins or off the canvas: clear once.
    if not WorldMapFrame:IsCanvasMouseFocus() then
        if self.lastHoveredID ~= nil then
            self.lastHoveredID = nil
            self:ApplyTexts(nil)
        end
        return
    end

    local nx, ny = WorldMapFrame:GetNormalizedCursorPosition()
    local hovered = C_Map.GetMapInfoAtPosition(WorldMapFrame:GetMapID(), nx, ny)
    -- Return shape varies across Classic clients: a table or a bare id.
    local id = type(hovered) == "table" and hovered.mapID or hovered

    if id == self.lastHoveredID then return end
    self.lastHoveredID = id
    self:ApplyTexts(id)
end

function ZoneDetailsDataProviderMixin:RefreshAllData(fromOnShow)
    if not self:GetMap() then return end
    self:EnsureFrames()
    self:EnsureAreaLabelHook()

    local mapInfo = C_Map.GetMapInfo(WorldMapFrame:GetMapID())
    local mapType = mapInfo and mapInfo.mapType

    -- On a continent map (with the toggle on) the corner overlay is driven by the
    -- cursor-zone hover; start blank and let ContinentHoverTick fill it in. Any
    -- other map renders its own zone statically (or stays blank if it has no data).
    self.hoverMode = (mapType == WORLDMAP_CONTINENT and db and db.showContinentHover) and true or false
    self.hoverAccum = 0
    self.lastHoveredID = nil

    self:ApplyTexts(nil)
    self.overlay:Show()
end

function ZoneDetailsDataProviderMixin:RemoveAllData()
    if self.overlay then
        self.overlay:Hide()
    end
end

function ZoneDetailsPinDataProviderMixin:RefreshAllData(fromOnShow)
    self:GetMap():RemoveAllPinsByTemplate("ZoneDetailsGlobalPinTemplate")

    local pins = ZoneDetails:GetPins()
    if pins then
        for _, pin in ipairs(pins) do
            self:GetMap():AcquirePin("ZoneDetailsGlobalPinTemplate", pin)
        end
    end
end

-- Cursor-following frame used to show an instance/raid's details just above the
-- mouse pointer while its map icon is hovered. Created lazily and reused.
local pinHoverFrame
local function GetPinHoverFrame()
    if pinHoverFrame then return pinHoverFrame end

    local f = CreateFrame("Frame", "ZoneDetailsPinHoverFrame", UIParent)
    f:SetFrameStrata("TOOLTIP")
    f:SetSize(1, 1)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.text:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
    f.text:SetJustifyH("LEFT")
    f:Hide()

    -- Keep the frame anchored just above the cursor while it is shown, and hide
    -- it if the world map closes without a mouse-leave firing on the pin.
    f:SetScript("OnUpdate", function(self)
        if not WorldMapFrame:IsShown() then
            self:Hide()
            return
        end
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        self:ClearAllPoints()
        self:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", x / scale, (y / scale) + 20)
    end)

    pinHoverFrame = f
    return f
end

function ZoneDetailsGlobalPinMixin:OnAcquired(myInfo)
    BaseMapPoiPinMixin.OnAcquired(self, myInfo)
    self.zdHoverText = myInfo.zdHoverText
    -- Draw above Blizzard's native entrance markers (same MEDIUM strata). Use
    -- FULLSCREEN_DIALOG so the pins also clear the maximized world map, which sits at a
    -- higher strata than the windowed map (plain HIGH stayed behind it). This matches the
    -- zone-name overlay's strata, which already renders correctly in both map modes.
    self:SetFrameStrata("FULLSCREEN_DIALOG")
end

function ZoneDetailsGlobalPinMixin:OnMouseEnter()
    if not self.zdHoverText then return end

    -- Pins are rebuilt when the pin toggles change (see RefreshMapText), so a pin only
    -- exists for currently-enabled content; just show its (possibly multi-line) hover.
    local f = GetPinHoverFrame()
    f.text:SetFont(GetMapFontPath(), db.hoverTextFontSize, "OUTLINE")
    f.text:SetText(self.zdHoverText)
    f:SetWidth(f.text:GetStringWidth() + 16)
    f:SetHeight(f.text:GetStringHeight() + 8)
    f:Show()
end

function ZoneDetailsGlobalPinMixin:OnMouseLeave()
    if pinHoverFrame then
        pinHoverFrame:Hide()
    end
end

function ZoneDetailsGlobalPinMixin:OnMouseUp(btn)
    if btn == "RightButton" then
        WorldMapFrame:NavigateToParentMap()
    end
end

-- ============================================================================
-- Addon Lifecycle
-- ============================================================================

function ZoneDetails:OnEnable()
    WorldMapFrame:AddDataProvider(ZoneDetailsDataProviderMixin)
    WorldMapFrame:AddDataProvider(ZoneDetailsPinDataProviderMixin)
    -- Maximizing/minimizing the map resizes the canvas without firing a zone change, so
    -- the pins keep their old layout until you navigate. Re-acquire them on the mode
    -- switch so they re-render immediately for the new canvas size.
    for _, method in ipairs({ "Maximize", "Minimize" }) do
        if type(WorldMapFrame[method]) == "function" then
            hooksecurefunc(WorldMapFrame, method, function()
                if WorldMapFrame:IsShown() then
                    ZoneDetailsPinDataProviderMixin:RefreshAllData()
                end
            end)
        end
    end
    -- The map's own refresh can run before the canvas finishes sizing (notably when it
    -- opens already maximized), leaving pins stale until a zone change. Re-acquire on the
    -- next frame after the map shows, once the canvas has settled.
    WorldMapFrame:HookScript("OnShow", function()
        C_Timer.After(0, function()
            if WorldMapFrame:IsShown() then
                ZoneDetailsPinDataProviderMixin:RefreshAllData()
            end
        end)
    end)
end

-- Force an immediate re-render of the overlay text (used for live option
-- changes). The map's own refresh cycle handles normal opens and zone navigation.
function ZoneDetails:RefreshMapText()
    if WorldMapFrame:IsShown() then
        ZoneDetailsDataProviderMixin:RefreshAllData()
        -- Rebuild pins too so pin toggles take effect immediately and clustered pins
        -- only ever contain currently-enabled content.
        ZoneDetailsPinDataProviderMixin:RefreshAllData()
    end
end

function ZoneDetails:OnDisable()
    WorldMapFrame:RemoveDataProvider(ZoneDetailsDataProviderMixin)
    WorldMapFrame:RemoveDataProvider(ZoneDetailsPinDataProviderMixin)
end

function ZoneDetails:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("ZoneDetailsDB", defaults)
    db = self.db.profile
    LibStub("AceConfig-3.0"):RegisterOptionsTable("ZoneDetails", options)
    options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ZoneDetails", "ZoneDetails")
    local function chatCommand(input)
        if input and input:lower():match("^%s*validate%s*$") then
            ZoneDetails:ValidateData()
        else
            InterfaceOptionsFrame_OpenToCategory(ZoneDetails.optionsFrame)
        end
    end
    self:RegisterChatCommand("zonedetails", chatCommand)
    self:RegisterChatCommand("zd", chatCommand)
    self:RegisterEvent("ZONE_CHANGED")
    self:RegisterEvent("PLAYER_LEVEL_CHANGED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    self.db.RegisterCallback(self, "OnProfileChanged", "Refresh")
    self.db.RegisterCallback(self, "OnProfileCopied", "Refresh")
    self.db.RegisterCallback(self, "OnProfileReset", "Refresh")
end

function ZoneDetails:Refresh()
    db = self.db.profile
end

-- ============================================================================
-- Debug / validation
-- ============================================================================

-- Show text in a window whose contents can be selected and copied (Ctrl+A / Ctrl+C).
-- The default chat frame can't be copied, so debug output uses this. Built once, reused.
function ZoneDetails:ShowCopyWindow(title, text)
    if not self.copyWindow then
        local frame = AceGUI:Create("Frame")
        frame:SetLayout("Fill")
        frame:SetWidth(620)
        frame:SetHeight(520)
        frame:SetCallback("OnClose", function(widget) widget:Hide() end)  -- hide, don't release (reused)

        local edit = AceGUI:Create("MultiLineEditBox")
        edit:SetLabel("")
        edit:DisableButton(true)
        edit:SetFullWidth(true)
        edit:SetFullHeight(true)
        frame:AddChild(edit)

        self.copyWindow = frame
        self.copyEdit = edit
    end

    self.copyWindow:SetTitle(title or "ZoneDetails")
    self.copyEdit:SetText(text or "")
    self.copyWindow:Show()
    if self.copyEdit.editBox then
        self.copyEdit.editBox:SetFocus()
        self.copyEdit.editBox:HighlightText()
    end
end

-- Dump every loaded instance/raid for the current client into a copyable window so the
-- data can be validated per expansion/season. Flags numeric keys that don't resolve
-- (UNRESOLVED) and entries no zone references (ORPHAN).
function ZoneDetails:ValidateData()
    -- Keys referenced by some zone (directly or via a complex).
    local referenced = {}
    for _, zone in pairs(zones) do
        if type(zone) == "table" then
            if zone.instances then for _, k in ipairs(zone.instances) do referenced[k] = true end end
            if zone.raids then for _, k in ipairs(zone.raids) do referenced[k] = true end end
            if zone.complexes then
                for _, c in ipairs(zone.complexes) do
                    local complex = complexes[c]
                    if complex and complex.instances then
                        for _, k in ipairs(complex.instances) do referenced[k] = true end
                    end
                end
            end
        end
    end

    local function keySort(a, b)
        local na, nb = type(a) == "number", type(b) == "number"
        if na ~= nb then return na end
        if na then return a < b end
        return tostring(a) < tostring(b)
    end

    local lines = {}
    local function dump(kind, tbl)
        local keys = {}
        for k in pairs(tbl) do keys[#keys + 1] = k end
        table.sort(keys, keySort)
        for _, key in ipairs(keys) do
            local data = tbl[key]
            local name = type(key) == "number" and GetRealZoneText(key) or key
            local flags = ""
            if type(key) == "number" and (not name or name == "") then
                name = "?"
                flags = flags .. " UNRESOLVED"
            end
            if not referenced[key] then flags = flags .. " ORPHAN" end
            lines[#lines + 1] = ("[%s] %s -> %s [%d-%d]%s"):format(
                kind, tostring(key), name, data.low or 0, data.high or 0, flags)
        end
        return #keys
    end

    local nInst = dump("inst", instances)
    local nRaid = dump("raid", raids)
    local client = isMoP and "MoP" or isWrath and "Wrath" or isTBC and "TBC" or isSoD and "SoD" or "Vanilla"
    local report = ("ZoneDetails validate — %s (tocVersion %d) — %d instances, %d raids\n\n"):format(
        client, tocVersion, nInst, nRaid) .. table.concat(lines, "\n")

    self:ShowCopyWindow("ZoneDetails - Validate", report)
end

-- ============================================================================
-- Zone Details Display
-- ============================================================================

-- mapID is optional: when omitted it resolves to the map currently shown on the
-- World Map (the static zone-map overlay). The continent hover passes an explicit
-- zone id so the same builder can render whichever zone the cursor is over. The
-- guards below validate the resolved id either way (a continent/world id has no
-- zones[] entry and is rejected). subzone is optional: when the cursor is over a
-- named subzone, the header reads "Zone - Subzone [low-high]".
function ZoneDetails:GetZoneHeader(mapID, subzone)
    mapID = mapID or WorldMapFrame:GetMapID()
    local mapInfo = C_Map.GetMapInfo(mapID)
    if not mapInfo then return nil end
    if mapInfo.mapType ~= WORLDMAP_ZONE then return nil end
    if not zones[mapID] then return nil end
    if not db.showZoneLevel then return nil end

    local mapName = mapInfo.name
    if subzone and subzone ~= "" then
        mapName = mapName .. " - " .. subzone
    end
    local r2, g2, b2 = self:LevelColor(zones[mapID].low, zones[mapID].high, playerLevel)
    local r1, g1, b1 = self:GetFactionColor(mapID)
    return ("|cff%02x%02x%02x%s|r |cff%02x%02x%02x[%d-%d]|r"):format(
        r1 * 255, g1 * 255, b1 * 255, mapName,
        r2 * 255, g2 * 255, b2 * 255,
        zones[mapID].low, zones[mapID].high
    )
end

-- GetRealZoneText can return nil before instance/raid map data is cached (e.g.
-- right after a login or reload). Fall back to a non-nil value so string.format
-- never errors and blanks the whole overlay.
local function SafeZoneText(id)
    return GetRealZoneText(id) or tostring(id)
end

-- Resolve an instance/raid key to a display name, or nil if it isn't present on the
-- running client. Numeric keys are client mapIDs; if GetRealZoneText can't resolve
-- one, that instance/raid doesn't exist on this client (e.g. a TBC instance on a
-- Classic Era / SoD client) and the caller skips it instead of showing a nameless
-- entry. String keys are intentional custom content and are always kept.
-- Successful resolutions are cached so a valid instance that briefly fails to resolve
-- (GetRealZoneText can return nil just after login/reload) doesn't flicker out; a
-- wrong-expansion key never resolves on this client, so it is never cached.
local resolvedInstanceNames = {}
local function ResolveInstanceName(key)
    if type(key) ~= "number" then return key end
    local cached = resolvedInstanceNames[key]
    if cached then return cached end
    local name = GetRealZoneText(key)
    if name and name ~= "" then
        resolvedInstanceNames[key] = name
        return name
    end
    return nil
end

-- Player-count label shared by raids and battlegrounds, e.g. "40 Player" or, for a
-- flexible raid, "20-40 Player".
local function PlayerCountText(data)
    return tostring(data.players) .. " " .. L["Player"]
end

function ZoneDetails:GetInstanceDetails(mapID)
    mapID = mapID or WorldMapFrame:GetMapID()
    local mapInfo = C_Map.GetMapInfo(mapID)
    if not mapInfo then return nil end
    if mapInfo.mapType ~= WORLDMAP_ZONE then return nil end
    if not zones[mapID] then return nil end

    local zone = zones[mapID]
    local fr, fg, fb = self:GetFactionColor(mapID)
    local text = ""

    -- Instances (plain + complex sub-instances) share one header. Each numeric entry
    -- is skipped if it doesn't exist on this client (ResolveInstanceName), so e.g. TBC
    -- instances don't show up nameless on a Classic Era / SoD client. Hovering an
    -- entrance pin additionally pops the details up above the cursor (see pin handlers).
    local function addInstanceLine(instance, lines)
        local instData = instances[instance]
        if not instData then return end
        local instName = ResolveInstanceName(instance)
        if not instName then return end
        local r2, g2, b2 = self:LevelColor(instData.low, instData.high, playerLevel)
        lines[#lines + 1] = ("\n|cff%02x%02x%02x%s|r |cff%02x%02x%02x[%d-%d]|r"):format(
            fr * 255, fg * 255, fb * 255, instName,
            r2 * 255, g2 * 255, b2 * 255, instData.low, instData.high
        )
    end

    if db.showInstances then
        local lines = {}
        if zone.instances then
            for _, instance in ipairs(zone.instances) do addInstanceLine(instance, lines) end
        end
        if zone.complexes then
            for _, complex in ipairs(zone.complexes) do
                if complexes[complex] then
                    for _, instance in ipairs(complexes[complex].instances) do addInstanceLine(instance, lines) end
                end
            end
        end
        if #lines > 0 then
            text = text .. ("\n|cffffff00%s:|r"):format(L["Instances"]) .. table.concat(lines)
        end
    end

    if db.showBattlegrounds and zone.battlegrounds then
        local lines = {}
        for _, battleground in ipairs(zone.battlegrounds) do
            local bgData = battlegrounds[battleground]
            if bgData then
                local r2, g2, b2 = self:LevelColor(bgData.low, bgData.high, playerLevel)
                lines[#lines + 1] = ("\n|cff%02x%02x%02x%s|r |cff%02x%02x%02x[%d-%d]|r   %s"):format(
                    fr * 255, fg * 255, fb * 255, SafeZoneText(battleground),
                    r2 * 255, g2 * 255, b2 * 255, bgData.low, bgData.high, PlayerCountText(bgData)
                )
            end
        end
        if #lines > 0 then
            text = text .. ("\n|cffffff00%s:|r"):format(L["Battlegrounds"]) .. table.concat(lines)
        end
    end

    if db.showRaids and zone.raids then
        local lines = {}
        for _, raid in ipairs(zone.raids) do
            local raidData = raids[raid]
            if raidData then
                local raidName = ResolveInstanceName(raid)
                if raidName then
                    local r2, g2, b2 = self:LevelColor(raidData.low, raidData.high, playerLevel)
                    lines[#lines + 1] = ("\n|cff%02x%02x%02x%s|r |cff%02x%02x%02x[%d]|r   %s"):format(
                        fr * 255, fg * 255, fb * 255, raidName,
                        r2 * 255, g2 * 255, b2 * 255, raidData.high, PlayerCountText(raidData)
                    )
                end
            end
        end
        if #lines > 0 then
            text = text .. ("\n|cffffff00%s:|r"):format(L["Raids"]) .. table.concat(lines)
        end
    end

    if text == "" then return nil end
    return text
end

-- ============================================================================
-- Profession Details Display
-- ============================================================================

function ZoneDetails:GetProfessions()
    local professions = {}

    if isMoP or isCata then
        -- MoP/Cata Classic use the retail-style profession API
        local prof1, prof2, archaeology, fishing, cooking = GetProfessions()
        local profIDs = {prof1, prof2, archaeology, fishing, cooking}
        for _, profID in pairs(profIDs) do
            if profID then
                local name, _, skillLevel = GetProfessionInfo(profID)
                if name and skillLevel then
                    for _, v in pairs(profs) do
                        if v == name then
                            professions[name] = skillLevel
                        end
                    end
                end
            end
        end
    else
        -- Classic/TBC use the skill line API
        for skillIndex = 1, GetNumSkillLines() or 0 do
            local skillName, isHeader, _, skillRank = GetSkillLineInfo(skillIndex)
            if not isHeader then
                for _, v in pairs(profs) do
                    if v == skillName then
                        professions[skillName] = skillRank
                    end
                end
            end
        end
    end

    return professions
end

function ZoneDetails:GetProfessionDetails(mapID)
    mapID = mapID or WorldMapFrame:GetMapID()
    local mapInfo = C_Map.GetMapInfo(mapID)
    if not mapInfo then return nil end

    if mapInfo.mapType == WORLDMAP_CONTINENT then
        return nil
    end

    if mapInfo.mapType ~= WORLDMAP_ZONE then
        return nil
    end

    if not zones[mapID] then
        return nil
    end

    local playerProfs = self:GetProfessions()
    local profText = ""
    local hasRelevantProf = playerProfs[L["Mining"]] or playerProfs[L["Herbalism"]] or playerProfs[L["Fishing"]]

    if hasRelevantProf then
        profText = ("\n|cffffff00%s:|r"):format(L["Professions"])
    end

    -- Fishing
    if db.showFishing and zones[mapID].fishing_min and playerProfs[L["Fishing"]] then
        local r, g, b = self:FishingColor(zones[mapID].fishing_min, playerProfs[L["Fishing"]])
        profText = profText .. ("\n|cffffff00%s|r |cff%02x%02x%02x[%d]|r\n"):format(
            L["Fishing Minimum"],
            r * 255, g * 255, b * 255,
            zones[mapID].fishing_min
        )
    end

    -- Herbs
    if db.showHerbs and zones[mapID].herbs and playerProfs[L["Herbalism"]] then
        profText = profText .. ("\n|cffffff00%s:|r"):format(L["Herbs"])
        for _, herb in ipairs(zones[mapID].herbs) do
            if herbs[herb] then
                local r, g, b = self:LevelColor(herbs[herb].low, herbs[herb].high, playerProfs[L["Herbalism"]])
                profText = profText .. ("\n%s |cff%02x%02x%02x[%d-%d]|r"):format(
                    herb, r * 255, g * 255, b * 255,
                    herbs[herb].low, herbs[herb].high
                )
            end
        end
    end

    -- Mining Nodes
    if db.showMineNodes and zones[mapID].nodes and playerProfs[L["Mining"]] then
        profText = profText .. ("\n|cffffff00%s:|r"):format(L["Nodes"])
        for _, node in ipairs(zones[mapID].nodes) do
            if nodes[node] then
                local r, g, b = self:LevelColor(nodes[node].low, nodes[node].high, playerProfs[L["Mining"]])
                profText = profText .. ("\n%s |cff%02x%02x%02x[%d-%d]|r"):format(
                    node, r * 255, g * 255, b * 255,
                    nodes[node].low, nodes[node].high
                )
            end
        end
    end

    return profText
end

-- ============================================================================
-- Map Pin Display
-- ============================================================================

-- Entrances that sit on (or near) the same spot are merged into a single pin whose
-- hover lists every dungeon/raid there. Two POIs cluster if they belong to the same
-- complex (e.g. Scarlet Monastery's wings) or their entrances are within this many
-- map units (0-100 scale) of each other.
local PIN_CLUSTER_EPSILON = 3.0

function ZoneDetails:GetPins()
    local mapID = WorldMapFrame:GetMapID()
    local mapInfo = C_Map.GetMapInfo(mapID)
    if not mapInfo or mapInfo.mapType ~= WORLDMAP_ZONE then
        return nil
    end

    local zone = zones[mapID]
    if not zone then
        return nil
    end

    -- Faction colour is zone-wide; compute it once.
    local fr, fg, fb = self:GetFactionColor(mapID)

    -- Step 1: collect candidate POIs as { x, y, line, isRaid, group }.
    local items = {}

    local function addInstance(instance, group)
        local instData = instances[instance]
        if not (instData and instData.entrance) then return end
        local instName = ResolveInstanceName(instance)
        if not instName then return end  -- not present on this client; skip
        -- A zone may override an instance's pin position on its own map -- used when an
        -- entrance physically sits in a sub-zone with its own coordinate system (the
        -- base instances[].entrance serves the zone the entrance is keyed to).
        local ov = zone.instanceCoords and zone.instanceCoords[instance]
        local r2, g2, b2 = self:LevelColor(instData.low, instData.high, playerLevel)
        items[#items + 1] = {
            x = (ov and ov[1]) or instData.entrance[1],
            y = (ov and ov[2]) or instData.entrance[2],
            group = group,
            isRaid = false,
            line = ("|cff%02x%02x%02x%s|r |cff%02x%02x%02x[%d-%d]|r"):format(
                fr * 255, fg * 255, fb * 255, instName,
                r2 * 255, g2 * 255, b2 * 255, instData.low, instData.high
            ),
        }
    end

    if db.showInstancePins then
        if zone.instances then
            for _, instance in ipairs(zone.instances) do
                addInstance(instance, nil)
            end
        end
        if zone.complexes then
            for _, complex in ipairs(zone.complexes) do
                if complexes[complex] then
                    for _, instance in ipairs(complexes[complex].instances) do
                        addInstance(instance, "complex:" .. complex)
                    end
                end
            end
        end
    end

    if db.showRaidPins and zone.raids then
        for _, raid in ipairs(zone.raids) do
            local raidData = raids[raid]
            local raidName = raidData and raidData.entrance and ResolveInstanceName(raid)
            if raidName then
                local r2, g2, b2 = self:LevelColor(raidData.low, raidData.high, playerLevel)
                items[#items + 1] = {
                    x = raidData.entrance[1],
                    y = raidData.entrance[2],
                    group = nil,
                    isRaid = true,
                    line = ("|cff%02x%02x%02x%s|r |cff%02x%02x%02x[%d-%d]|r %s"):format(
                        fr * 255, fg * 255, fb * 255, raidName,
                        r2 * 255, g2 * 255, b2 * 255, raidData.low, raidData.high, PlayerCountText(raidData)
                    ),
                }
            end
        end
    end

    if #items == 0 then
        return nil
    end

    -- Step 2: cluster. Complex members always merge by group; everything else merges
    -- into the nearest existing cluster within the epsilon, otherwise starts its own.
    local clusters = {}
    local byGroup = {}
    local eps2 = PIN_CLUSTER_EPSILON * PIN_CLUSTER_EPSILON

    for _, it in ipairs(items) do
        local target
        if it.group then
            target = byGroup[it.group]
        end
        if not target then
            for _, cl in ipairs(clusters) do
                local dx, dy = it.x - cl.x, it.y - cl.y
                if (dx * dx + dy * dy) <= eps2 then
                    target = cl
                    break
                end
            end
        end
        if not target then
            target = { x = it.x, y = it.y, lines = {}, hasRaid = false }
            clusters[#clusters + 1] = target
            if it.group then byGroup[it.group] = target end
        end
        target.lines[#target.lines + 1] = it.line
        if it.isRaid then target.hasRaid = true end
    end

    -- Step 3: one pin per cluster, hover lists every member.
    local myPOIList = {}
    for i, cl in ipairs(clusters) do
        local hoverText = table.concat(cl.lines, "\n")
        myPOIList[i] = {
            position = CreateVector2D(cl.x / 100, cl.y / 100),
            name = cl.lines[1],
            description = "",
            atlasName = cl.hasRaid and "Raid" or "Dungeon",
            zdHoverText = hoverText,
        }
    end

    return myPOIList
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

function ZoneDetails:ZONE_CHANGED()
    if GetBindLocation() == GetSubZoneText() then
        if db.showInChat then
            self:Print(db.message)
        end
    end
end

function ZoneDetails:PLAYER_LEVEL_CHANGED(event, oldLevel, newLevel)
    playerLevel = newLevel
end

-- Fired after a login/reload once the player's world data is available. At addon
-- load UnitLevel/UnitFactionGroup can be unset, so refresh them and repopulate
-- the map text now that the zone information has actually loaded.
function ZoneDetails:PLAYER_ENTERING_WORLD()
    playerLevel = UnitLevel("player") or playerLevel

    local faction = UnitFactionGroup("player")
    if faction then
        isAlliance = faction == "Alliance"
        isHorde = faction == "Horde"
        isNeutral = not isAlliance and not isHorde
    end

    self:RefreshMapText()
end

-- ============================================================================
-- Color Utility Functions (derived from LibTourist)
-- ============================================================================

-- Returns r, g, b based on zone faction relative to the player
function ZoneDetails:GetFactionColor(zone)
    local zoneData = zones[zone]
    if not zoneData then
        return 1, 1, 0
    end

    if zoneData.faction == "Contested" then
        return 1, 0.7, 0
    elseif zoneData.faction == (isHorde and "Alliance" or "Horde") then
        return 1, 0, 0
    elseif zoneData.faction == (isHorde and "Horde" or "Alliance") then
        return 0, 1, 0
    else
        return 1, 1, 0
    end
end

-- Returns r, g, b color based on level range vs current level
function ZoneDetails:LevelColor(low, high, currentLevel)
    local midBracket = (low + high) / 2

    if low <= 0 and high <= 0 then
        return 1, 1, 1
    elseif currentLevel == low and currentLevel == high then
        return 1, 1, 0
    elseif currentLevel <= low - 3 then
        return 1, 0, 0
    elseif currentLevel < low then
        local greenComponent = (currentLevel - low + 3) / 6
        return 1, greenComponent, 0
    elseif currentLevel == low then
        return 1, 0.5, 0
    elseif currentLevel < midBracket then
        local halfBracketSize = (high - low) / 2
        local posInBracketHalf = currentLevel - low
        local greenComponent = 0.5 + (posInBracketHalf / halfBracketSize) * 0.5
        return 1, greenComponent, 0
    elseif currentLevel == midBracket then
        return 1, 1, 0
    elseif currentLevel < high then
        local halfBracketSize = (high - low) / 2
        local posInBracketHalf = currentLevel - midBracket
        local redComponent = 1 - (posInBracketHalf / halfBracketSize)
        return redComponent, 1, 0
    elseif currentLevel == high then
        return 0, 1, 0
    elseif currentLevel < high + 3 then
        local pos = (currentLevel - high) / 3
        local redAndBlueComponent = pos * 0.5
        local greenComponent = 1 - redAndBlueComponent
        return redAndBlueComponent, greenComponent, redAndBlueComponent
    else
        return 0.5, 0.5, 0.5
    end
end

-- Returns r, g, b for fishing skill comparison
function ZoneDetails:FishingColor(fish_min, current)
    if fish_min <= 0 and current <= 0 then
        return 1, 1, 1
    elseif fish_min > current then
        return 1, 0, 0
    elseif fish_min == current then
        return 1, 1, 0
    else
        return 0, 1, 0
    end
end

-- ============================================================================
-- ZONE DATA
-- ============================================================================

-- ============================================================================
-- Alliance Starting Zones
-- ============================================================================

-- Elwynn Forest
zones[1429] = {
    low = 1,
    high = 10,
    continent = Eastern_Kingdoms,
    faction = "Alliance",
    fishing_min = 1,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot"},
    nodes = {"Copper Vein"},
}

-- Teldrassil
zones[1438] = {
    low = 1,
    high = 11,
    continent = Kalimdor,
    faction = "Alliance",
    fishing_min = 1,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot"},
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
    nodes = {"Copper Vein"},
}

-- Azuremyst Isle (TBC)
zones[1943] = {
    low = 1,
    high = 10,
    continent = Kalimdor,
    faction = "Alliance",
    fishing_min = 1,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot"},
    nodes = {"Copper Vein"},
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
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"},
}

-- Loch Modan
zones[1432] = {
    low = 10,
    high = 18,
    continent = Eastern_Kingdoms,
    faction = "Alliance",
    fishing_min = 20,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Bruiseweed"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"},
}

-- Darkshore
zones[1439] = {
    low = 11,
    high = 19,
    continent = Kalimdor,
    faction = "Alliance",
    fishing_min = 20,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"},
}

-- Bloodmyst Isle (TBC)
zones[1950] = {
    low = 10,
    high = 20,
    continent = Kalimdor,
    faction = "Alliance",
    fishing_min = 20,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"},
}

-- ============================================================================
-- Horde Starting Zones
-- ============================================================================

-- Durotar
zones[1411] = {
    low = 1,
    high = 10,
    continent = Kalimdor,
    faction = "Horde",
    fishing_min = 1,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal"},
    nodes = {"Copper Vein"},
}

-- Mulgore
zones[1412] = {
    low = 1,
    high = 10,
    continent = Kalimdor,
    faction = "Horde",
    fishing_min = 1,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot"},
    nodes = {"Copper Vein"},
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
    nodes = {"Copper Vein"},
}

-- Eversong Woods (TBC)
zones[1941] = {
    low = 1,
    high = 10,
    continent = Eastern_Kingdoms,
    faction = "Horde",
    fishing_min = 1,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot"},
    nodes = {"Copper Vein"},
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
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"},
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
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"},
}

-- Ghostlands (TBC)
zones[1942] = {
    low = 10,
    high = 20,
    continent = Eastern_Kingdoms,
    raids = {568},
    faction = "Horde",
    fishing_min = 20,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"},
}

-- ============================================================================
-- Contested Zones (Eastern Kingdoms)
-- ============================================================================

-- Duskwood
zones[1431] = {
    low = 10,
    high = 30,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    fishing_min = 55,
    herbs = {"Mageroyal", "Briarthorn", "Wild Steelbloom", "Grave Moss", "Kingsblood"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein"},
}

-- Redridge Mountains
zones[1433] = {
    low = 15,
    high = 25,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    fishing_min = 55,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Bruiseweed"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"},
}

-- Wetlands
zones[1437] = {
    low = 20,
    high = 30,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    fishing_min = 55,
    herbs = {"Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Grave Moss", "Kingsblood", "Liferoot"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein"},
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
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit"},
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
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"},
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
    nodes = {"Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"},
}

-- Stranglethorn Vale
zones[1434] = {
    low = 30,
    high = 50,
    continent = Eastern_Kingdoms,
    raids = {309},
    faction = "Contested",
    fishing_min = 130,
    herbs = {"Stranglekelp", "Wild Steelbloom", "Kingsblood", "Liferoot", "Fadeleaf", "Goldthorn", "Khadgar's Whisker", "Purple Lotus"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"},
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
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein"},
}

-- Badlands
zones[1418] = {
    low = 36,
    high = 45,
    continent = Eastern_Kingdoms,
    instances = {70},
    faction = "Contested",
    herbs = {"Wild Steelbloom", "Kingsblood", "Fadeleaf", "Goldthorn", "Khadgar's Whisker", "Firebloom", "Purple Lotus"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"},
}

-- The Hinterlands
zones[1425] = {
    low = 41,
    high = 49,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Stranglekelp", "Liferoot", "Fadeleaf", "Goldthorn", "Khadgar's Whisker", "Purple Lotus", "Sungrass", "Ghost Mushroom", "Golden Sansam"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein"},
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
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein", "Rich Thorium Vein"},
}

-- Searing Gorge
zones[1427] = {
    low = 43,
    high = 56,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    herbs = {"Firebloom"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Dark Iron Deposit", "Small Thorium Vein"},
}

-- Blasted Lands
zones[1419] = {
    low = 46,
    high = 60,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    herbs = {"Goldthorn", "Firebloom", "Sungrass", "Gromsblood"},
    nodes = {"Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein"},
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
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Dark Iron Deposit", "Small Thorium Vein", "Rich Thorium Vein"},
}

-- Deadwind Pass
zones[1430] = {
    low = 50,
    high = MAX_LEVEL,
    continent = Eastern_Kingdoms,
    raids = {532},
    faction = "Contested",
    fishing_min = 330,
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
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein", "Rich Thorium Vein"},
}

-- ============================================================================
-- Contested Zones (Kalimdor)
-- ============================================================================

-- Moonglade
zones[1450] = {
    low = 10,
    high = MAX_LEVEL,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 205,
}

-- Stonetalon Mountains
zones[1442] = {
    low = 15,
    high = 25,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 55,
    herbs = {"Mageroyal", "Bruiseweed", "Wild Steelbloom", "Kingsblood"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"},
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
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein"},
}

-- Thousand Needles
zones[1441] = {
    low = 24,
    high = 35,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 130,
    herbs = {"Bruiseweed", "Wild Steelbloom", "Kingsblood"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Ooze Covered Silver Vein", "Iron Deposit", "Gold Vein", "Ooze Covered Gold Vein", "Mithril Deposit", "Ooze Covered Mithril Deposit"},
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
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"},
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
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"},
}

-- Tanaris
zones[1446] = {
    low = 40,
    high = 50,
    continent = Kalimdor,
    instances = {209},
    complexes = {2367},
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Stranglekelp", "Firebloom", "Purple Lotus"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein"},
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
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Ooze Covered Gold Vein", "Mithril Deposit", "Ooze Covered Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein", "Ooze Covered Thorium Vein"},
}

-- Azshara
zones[1447] = {
    low = 42,
    high = 55,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Stranglekelp", "Goldthorn", "Khadgar's Whisker", "Purple Lotus", "Sungrass", "Golden Sansam", "Mountain Silversage"},
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Rich Thorium Vein"},
}

-- Felwood
zones[1448] = {
    low = 47,
    high = 54,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Arthas' Tears", "Sungrass", "Gromsblood", "Golden Sansam", "Dreamfoil", "Mountain Silversage", "Plaguebloom"},
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein"},
}

-- Un'Goro Crater
zones[1449] = {
    low = 48,
    high = 55,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Sungrass", "Blindweed", "Golden Sansam", "Dreamfoil", "Mountain Silversage"},
    nodes = {"Truesilver Deposit", "Ooze Covered Truesilver Deposit", "Small Thorium Vein", "Ooze Covered Thorium Vein", "Rich Thorium Vein", "Ooze Covered Rich Thorium Vein"},
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
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein", "Rich Thorium Vein", "Ooze Covered Rich Thorium Vein"},
}

-- Winterspring
zones[1452] = {
    low = 55,
    high = 60,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 330,
    herbs = {"Mountain Silversage", "Icecap", "Black Lotus"},
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein", "Rich Thorium Vein"},
}

-- ============================================================================
-- Outland Zones (TBC)
-- ============================================================================

-- Hellfire Peninsula
zones[1944] = {
    low = 58,
    high = 63,
    continent = Outland,
    instances = {543, 542, 540},
    raids = {544},
    faction = "Contested",
    fishing_min = 280,
    herbs = {"Felweed", "Dreaming Glory", "Flame Cap"},
    nodes = {"Fel Iron Deposit", "Adamantite Deposit"},
}

-- Zangarmarsh
zones[1946] = {
    low = 60,
    high = 64,
    continent = Outland,
    instances = {546, 545, 547},
    raids = {548},
    faction = "Contested",
    fishing_min = 305,
    herbs = {"Felweed", "Dreaming Glory", "Ragveil", "Flame Cap"},
    nodes = {"Fel Iron Deposit", "Adamantite Deposit"},
}

-- Terokkar Forest
zones[1952] = {
    low = 62,
    high = 65,
    continent = Outland,
    complexes = {3790},
    faction = "Contested",
    fishing_min = 355,
    herbs = {"Felweed", "Dreaming Glory", "Terocone"},
    nodes = {"Fel Iron Deposit", "Adamantite Deposit", "Rich Adamantite Deposit"},
}

-- Nagrand
zones[1951] = {
    low = 64,
    high = 67,
    continent = Outland,
    faction = "Contested",
    fishing_min = 380,
    herbs = {"Felweed", "Dreaming Glory", "Terocone"},
    nodes = {"Fel Iron Deposit", "Adamantite Deposit", "Rich Adamantite Deposit"},
}

-- Blade's Edge Mountains
zones[1949] = {
    low = 65,
    high = 68,
    continent = Outland,
    raids = {565},
    faction = "Contested",
    fishing_min = 355,
    herbs = {"Felweed", "Dreaming Glory", "Flame Cap", "Netherbloom"},
    nodes = {"Fel Iron Deposit", "Adamantite Deposit", "Rich Adamantite Deposit", "Khorium Vein"},
}

-- Netherstorm
zones[1953] = {
    low = 67,
    high = 70,
    continent = Outland,
    instances = {554, 553, 552},
    raids = {550},
    battlegrounds = {566},
    faction = "Contested",
    fishing_min = 380,
    herbs = {"Felweed", "Dreaming Glory", "Netherbloom", "Nightmare Vine", "Mana Thistle"},
    nodes = {"Fel Iron Deposit", "Adamantite Deposit", "Rich Adamantite Deposit", "Khorium Vein"},
}

-- Shadowmoon Valley
zones[1948] = {
    low = 67,
    high = 70,
    continent = Outland,
    raids = {564},
    faction = "Contested",
    fishing_min = 380,
    herbs = {"Felweed", "Dreaming Glory", "Terocone", "Nightmare Vine", "Ancient Lichen"},
    nodes = {"Fel Iron Deposit", "Adamantite Deposit", "Rich Adamantite Deposit", "Khorium Vein"},
}

-- Isle of Quel'Danas (TBC Phase 5)
zones[1957] = {
    low = 70,
    high = 70,
    continent = Eastern_Kingdoms,
    instances = {585},
    raids = {580},
    faction = "Contested",
    fishing_min = 405,
}

-- ============================================================================
-- Cities
-- ============================================================================

-- Orgrimmar
zones[1454] = {
    low = 1,
    high = MAX_LEVEL,
    continent = Kalimdor,
    instances = {389},
    faction = "Horde",
    fishing_min = 1,
}

-- Thunder Bluff
zones[1456] = {
    low = 1,
    high = MAX_LEVEL,
    continent = Kalimdor,
    faction = "Horde",
    fishing_min = 1,
}

-- Undercity
zones[1458] = {
    low = 1,
    high = MAX_LEVEL,
    continent = Eastern_Kingdoms,
    faction = "Horde",
    fishing_min = 1,
}

-- Silvermoon City (TBC)
zones[1954] = {
    low = 1,
    high = MAX_LEVEL,
    continent = Eastern_Kingdoms,
    faction = "Horde",
}

-- Darnassus
zones[1457] = {
    low = 1,
    high = MAX_LEVEL,
    continent = Kalimdor,
    faction = "Alliance",
    fishing_min = 1,
}

-- Ironforge
zones[1455] = {
    low = 1,
    high = MAX_LEVEL,
    continent = Eastern_Kingdoms,
    faction = "Alliance",
    fishing_min = 1,
}

-- Stormwind City
zones[1453] = {
    low = 1,
    high = MAX_LEVEL,
    continent = Eastern_Kingdoms,
    instances = {34},
    faction = "Alliance",
    fishing_min = 1,
}

-- The Exodar (TBC)
zones[1947] = {
    low = 1,
    high = MAX_LEVEL,
    continent = Kalimdor,
    faction = "Alliance",
}

-- Shattrath City (TBC)
zones[1955] = {
    low = 1,
    high = MAX_LEVEL,
    continent = Outland,
    faction = "Contested",
}

-- ============================================================================
-- INSTANCE DATA
-- ============================================================================

-- ============================================================================
-- Classic Instances
-- ============================================================================

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
    fishing_min = 20,
}

-- Wailing Caverns
instances[43] = {
    low = 15,
    high = 28,
    continent = Kalimdor,
    entrance = {46, 36},
    fishing_min = 20,
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
    fishing_min = 20,
}

-- The Stockade
instances[34] = {
    low = 22,
    high = 30,
    continent = Eastern_Kingdoms,
    entrance = {41, 57},
}

-- Gnomeregan
instances[90] = {
    low = 24,
    high = 40,
    continent = Eastern_Kingdoms,
    entrance = {24, 40},
}

-- Razorfen Kraul
instances[47] = {
    low = 24,
    high = 40,
    continent = Kalimdor,
    entrance = {42, 90},
}

-- Razorfen Downs
instances[129] = {
    low = 33,
    high = 47,
    continent = Kalimdor,
    entrance = {49, 96},
}

-- Uldaman
instances[70] = {
    low = 35,
    high = 52,
    continent = Eastern_Kingdoms,
    entrance = {43, 14},
}

-- Maraudon
instances[349] = {
    low = 35,
    high = 52,
    continent = Kalimdor,
    entrance = {29, 63},
    fishing_min = 205,
}

-- Zul'Farrak
instances[209] = {
    low = 43,
    high = 54,
    continent = Kalimdor,
    entrance = {39, 20},
}

-- The Temple of Atal'Hakkar (Sunken Temple)
instances[109] = {
    low = 44,
    high = 60,
    continent = Eastern_Kingdoms,
    entrance = {70, 54},
    fishing_min = 205,
}

-- Blackrock Depths
instances[230] = {
    low = 48,
    high = 60,
    continent = Eastern_Kingdoms,
    entrance = {29, 38},
}

-- Blackrock Spire
instances[229] = {
    low = 52,
    high = 60,
    continent = Eastern_Kingdoms,
    entrance = {28, 38},
}

-- Stratholme
instances[329] = {
    low = 56,
    high = 60,
    continent = Eastern_Kingdoms,
    entrance = {31, 13},
    fishing_min = 330,
}

-- Scholomance
instances[289] = {
    low = 56,
    high = 60,
    continent = Eastern_Kingdoms,
    entrance = {69, 73},
    fishing_min = 330,
}

-- Dire Maul
instances[L["Dire Maul: East"]] = {
    low = 36,
    high = 46,
    continent = Kalimdor,
    entrance = {59.5, 44},
}

instances[L["Dire Maul: West"]] = {
    low = 39,
    high = 49,
    continent = Kalimdor,
    entrance = {58, 44},
}

instances[L["Dire Maul: North"]] = {
    low = 42,
    high = 52,
    continent = Kalimdor,
    entrance = {58.9, 41.5},
}

-- Scarlet Monastery
instances[L["Scarlet Monastery: Graveyard"]] = {
    low = 26,
    high = 36,
    continent = Eastern_Kingdoms,
    entrance = {84.28, 30.63},
}

instances[L["Scarlet Monastery: Library"]] = {
    low = 29,
    high = 39,
    continent = Eastern_Kingdoms,
    entrance = {85.30, 33},
}

instances[L["Scarlet Monastery: Armory"]] = {
    low = 32,
    high = 42,
    continent = Eastern_Kingdoms,
    entrance = {85.83, 31.62},
}

instances[L["Scarlet Monastery: Cathedral"]] = {
    low = 35,
    high = 45,
    continent = Eastern_Kingdoms,
    entrance = {85.35, 30.57},
}

-- ============================================================================
-- TBC Instances
-- ============================================================================

-- Hellfire Citadel
-- Hellfire Ramparts
instances[543] = {
    low = 59,
    high = 67,
    continent = Outland,
    entrance = {47.5, 53.6},
}

-- The Blood Furnace
instances[542] = {
    low = 60,
    high = 68,
    continent = Outland,
    entrance = {46.0, 51.8},
}

-- The Shattered Halls
instances[540] = {
    low = 69,
    high = 70,
    continent = Outland,
    entrance = {47.7, 52.0},
}

-- Coilfang Reservoir
-- The Slave Pens
instances[547] = {
    low = 61,
    high = 69,
    continent = Outland,
    entrance = {50.2, 41.0},
}

-- The Underbog
instances[546] = {
    low = 62,
    high = 70,
    continent = Outland,
    entrance = {52.7, 36.2},
}

-- The Steamvault
instances[545] = {
    low = 69,
    high = 70,
    continent = Outland,
    entrance = {50.3, 33.3},
}

-- Auchindoun
-- Mana-Tombs
instances[557] = {
    low = 63,
    high = 70,
    continent = Outland,
    entrance = {39.6, 58.5},
}

-- Auchenai Crypts
instances[558] = {
    low = 64,
    high = 70,
    continent = Outland,
    entrance = {35.0, 65.7},
}

-- Sethekk Halls
instances[556] = {
    low = 66,
    high = 70,
    continent = Outland,
    entrance = {44.9, 65.6},
}

-- Shadow Labyrinth
instances[555] = {
    low = 69,
    high = 70,
    continent = Outland,
    entrance = {39.6, 71.0},
}

-- Tempest Keep
-- The Mechanar
instances[554] = {
    low = 68,
    high = 70,
    continent = Outland,
    entrance = {70.6, 69.7},
}

-- The Botanica
instances[553] = {
    low = 69,
    high = 70,
    continent = Outland,
    entrance = {71.7, 55.0},
}

-- The Arcatraz
instances[552] = {
    low = 69,
    high = 70,
    continent = Outland,
    entrance = {74.4, 57.7},
}

-- Caverns of Time (Old Hillsbrad Foothills, The Black Morass) + Hyjal Summit are
-- defined string-keyed in the gated block after the MoP data (TBC/Wrath/MoP only),
-- so GetRealZoneText's campaign names don't show and they never leak onto Era/SoD.

-- Magisters' Terrace (TBC Phase 5)
instances[585] = {
    low = 69,
    high = 70,
    continent = Eastern_Kingdoms,
    entrance = {61.3, 30.9},
}

-- ============================================================================
-- RAID DATA
-- ============================================================================

-- ============================================================================
-- Classic Raids
-- ============================================================================

-- Molten Core
raids[409] = {
    low = 55,
    high = 60,
    players = 40,
    continent = Eastern_Kingdoms,
    entrance = {30.5, 38},
}

-- Onyxia's Lair
raids[249] = {
    low = 55,
    high = 60,
    players = 40,
    continent = Kalimdor,
    entrance = {52, 76},
}
-- WotLK patch 3.2.2 reissued Onyxia's Lair as a level-80 10/25 raid (persists through
-- Cataclysm and MoP). Pre-Wrath clients keep the original level-60 40-player version;
-- SoD applies its own flexible tuning above.
if isWrath or isCata or isMoP then
    raids[249].low = 80
    raids[249].high = 80
    raids[249].players = "10/25"
end

-- Blackwing Lair
raids[469] = {
    low = 60,
    high = 60,
    players = 40,
    continent = Eastern_Kingdoms,
    entrance = {29, 34},
}

-- Zul'Gurub
raids[309] = {
    low = 60,
    high = 60,
    players = 20,
    continent = Eastern_Kingdoms,
    entrance = {53.9, 17.6},
}

-- Ruins of Ahn'Qiraj
raids[509] = {
    low = 60,
    high = 60,
    players = 20,
    continent = Kalimdor,
    entrance = {29, 93},
}

-- Ahn'Qiraj Temple
raids[531] = {
    low = 60,
    high = 60,
    players = 40,
    continent = Kalimdor,
    entrance = {28.6, 92.4},
}

-- Naxxramas
raids[533] = {
    low = 60,
    high = 60,
    players = 40,
    continent = Eastern_Kingdoms,
    entrance = {39, 26},
}

-- ============================================================================
-- TBC Raids
-- ============================================================================

-- Karazhan
raids[532] = {
    low = 70,
    high = 70,
    players = 10,
    continent = Eastern_Kingdoms,
    entrance = {46.9, 74.7},
}

-- Magtheridon's Lair
raids[544] = {
    low = 70,
    high = 70,
    players = 25,
    continent = Outland,
    entrance = {46.4, 54.8},
}

-- Gruul's Lair
raids[565] = {
    low = 70,
    high = 70,
    players = 25,
    continent = Outland,
    entrance = {68.5, 24.3},
}

-- Serpentshrine Cavern
raids[548] = {
    low = 70,
    high = 70,
    players = 25,
    continent = Outland,
    entrance = {50.3, 32.8},
}

-- Tempest Keep (The Eye)
raids[550] = {
    low = 70,
    high = 70,
    players = 25,
    continent = Outland,
    entrance = {73.7, 63.7},
}

-- Hyjal Summit is defined in the gated Caverns-of-Time block after the MoP data.

-- Black Temple
raids[564] = {
    low = 70,
    high = 70,
    players = 25,
    continent = Outland,
    entrance = {71.0, 46.4},
}

-- Zul'Aman
raids[568] = {
    low = 70,
    high = 70,
    players = 10,
    continent = Eastern_Kingdoms,
    entrance = {82.0, 64.3},
}

-- Sunwell Plateau (TBC Phase 5)
raids[580] = {
    low = 70,
    high = 70,
    players = 25,
    continent = Eastern_Kingdoms,
    entrance = {44.3, 45.6},
}

-- ============================================================================
-- BATTLEGROUND DATA
-- ============================================================================

-- Warsong Gulch
battlegrounds[489] = {
    low = 10,
    high = MAX_LEVEL,
    horde_entrance = {},
    alliance_entrance = {},
    players = 10,
}

-- Arathi Basin
battlegrounds[529] = {
    low = 20,
    high = MAX_LEVEL,
    horde_entrance = {},
    alliance_entrance = {},
    players = 15,
}

-- Alterac Valley
battlegrounds[30] = {
    low = 51,
    high = MAX_LEVEL,
    horde_entrance = {},
    alliance_entrance = {},
    players = 40,
}

-- Eye of the Storm (TBC)
battlegrounds[566] = {
    low = 61,
    high = MAX_LEVEL,
    horde_entrance = {},
    alliance_entrance = {},
    players = 15,
}

-- ============================================================================
-- COMPLEX DATA (multi-instance zones)
-- ============================================================================

-- Scarlet Monastery
complexes[189] = {
    instances = {
        L["Scarlet Monastery: Graveyard"],
        L["Scarlet Monastery: Library"],
        L["Scarlet Monastery: Armory"],
        L["Scarlet Monastery: Cathedral"],
    },
}

-- Dire Maul
complexes[429] = {
    instances = {
        L["Dire Maul: East"],
        L["Dire Maul: West"],
        L["Dire Maul: North"],
    },
}

-- Caverns of Time (complexes[2367]) is defined in the gated block after the MoP data.

-- Auchindoun
complexes[3790] = {
    instances = {557, 558, 556, 555},
}

-- ============================================================================
-- HERB DATA
-- ============================================================================

-- Classic Herbs
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
}

herbs["Briarthorn"] = {
    low = 70,
    high = 170,
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
}

herbs["Arthas' Tears"] = {
    low = 220,
    high = 325,
}

herbs["Sungrass"] = {
    low = 220,
    high = 325,
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
}

herbs["Dreamfoil"] = {
    low = 270,
    high = 325,
}

herbs["Mountain Silversage"] = {
    low = 280,
    high = 325,
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

-- TBC Herbs
herbs["Felweed"] = {
    low = 300,
    high = 400,
}

herbs["Dreaming Glory"] = {
    low = 315,
    high = 400,
}

herbs["Ragveil"] = {
    low = 325,
    high = 400,
}

herbs["Flame Cap"] = {
    low = 335,
    high = 400,
}

herbs["Terocone"] = {
    low = 325,
    high = 400,
}

herbs["Ancient Lichen"] = {
    low = 340,
    high = 400,
}

herbs["Netherbloom"] = {
    low = 350,
    high = 400,
}

herbs["Nightmare Vine"] = {
    low = 365,
    high = 400,
}

herbs["Mana Thistle"] = {
    low = 375,
    high = 400,
}

herbs["Fel Lotus"] = {
    low = 375,
    high = 400,
}

-- ============================================================================
-- MINING NODE DATA
-- ============================================================================

-- Classic Nodes
nodes["Copper Vein"] = {
    low = 1,
    high = 100,
}

nodes["Tin Vein"] = {
    low = 65,
    high = 165,
}

nodes["Silver Vein"] = {
    low = 75,
    high = 175,
}

nodes["Ooze Covered Silver Vein"] = {
    low = 75,
    high = 175,
}

nodes["Iron Deposit"] = {
    low = 125,
    high = 225,
}

nodes["Gold Vein"] = {
    low = 155,
    high = 255,
}

nodes["Ooze Covered Gold Vein"] = {
    low = 155,
    high = 255,
}

nodes["Mithril Deposit"] = {
    low = 175,
    high = 275,
}

nodes["Ooze Covered Mithril Deposit"] = {
    low = 175,
    high = 275,
}

nodes["Truesilver Deposit"] = {
    low = 230,
    high = 310,
}

nodes["Ooze Covered Truesilver Deposit"] = {
    low = 230,
    high = 310,
}

nodes["Dark Iron Deposit"] = {
    low = 230,
    high = 310,
}

nodes["Small Thorium Vein"] = {
    low = 250,
    high = 310,
}

nodes["Ooze Covered Thorium Vein"] = {
    low = 250,
    high = 310,
}

nodes["Rich Thorium Vein"] = {
    low = 275,
    high = 310,
}

nodes["Ooze Covered Rich Thorium Vein"] = {
    low = 275,
    high = 310,
}

nodes["Hakkari Thorium Vein"] = {
    low = 275,
    high = 310,
}

nodes["Small Obsidian Chunk"] = {
    low = 305,
    high = 310,
}

nodes["Large Obsidian Chunk"] = {
    low = 305,
    high = 310,
}

-- TBC Nodes
nodes["Fel Iron Deposit"] = {
    low = 275,
    high = 375,
}

nodes["Adamantite Deposit"] = {
    low = 325,
    high = 400,
}

nodes["Rich Adamantite Deposit"] = {
    low = 350,
    high = 400,
}

nodes["Khorium Vein"] = {
    low = 375,
    high = 400,
}

-- ============================================================================
-- Season of Discovery Data (Era client with an active SoD season only)
-- ============================================================================

if isSoD then
    -- Demon Fall Canyon: SoD-only dungeon in southeast Ashenvale (Felfire Hill).
    instances[L["Demon Fall Canyon"]] = {
        low = 57,
        high = 60,
        continent = Kalimdor,
        entrance = {84.5, 75.0},
    }
    if zones[1440] then
        zones[1440].instances = zones[1440].instances or {}
        table.insert(zones[1440].instances, L["Demon Fall Canyon"])
    end

    -- Scarlet Enclave: SoD-only 20-40 player raid in far-eastern Eastern Plaguelands.
    raids[L["Scarlet Enclave"]] = {
        low = 60,
        high = 60,
        players = "20-40",
        continent = Eastern_Kingdoms,
        entrance = {67, 85},
    }
    if zones[1423] then
        zones[1423].raids = zones[1423].raids or {}
        table.insert(zones[1423].raids, L["Scarlet Enclave"])
    end

    -- Register a SoD raid and attach it to a zone's raid list.
    local function addSoDRaid(zoneID, raidKey, data)
        raids[raidKey] = data
        if zones[zoneID] then
            zones[zoneID].raids = zones[zoneID].raids or {}
            table.insert(zones[zoneID].raids, raidKey)
        end
    end

    -- Dungeons reworked into raids. Keyed by the dungeon's numeric instance mapID so the
    -- name resolves via GetRealZoneText, and reusing the dungeon's existing entrance so the
    -- raid pin stacks onto the dungeon pin.
    addSoDRaid(1440, 48,  { low = 25, high = 25, players = 10, continent = Kalimdor,         entrance = {14, 14} })  -- Blackfathom Deeps (Ashenvale)
    addSoDRaid(1426, 90,  { low = 40, high = 40, players = 10, continent = Eastern_Kingdoms, entrance = {24, 40} })  -- Gnomeregan (Dun Morogh)
    addSoDRaid(1435, 109, { low = 50, high = 50, players = 20, continent = Eastern_Kingdoms, entrance = {70, 54} })  -- Sunken Temple (Swamp of Sorrows)
    -- Upper Blackrock Spire shares Blackrock Spire's door (instance 229) in Burning Steppes.
    addSoDRaid(1428, L["Upper Blackrock Spire"], { low = 56, high = 60, players = 10, continent = Eastern_Kingdoms, entrance = {28, 38} })

    -- New SoD dungeon: Karazhan Crypts at Morgan's Plot, Deadwind Pass.
    instances[L["Karazhan Crypts"]] = {
        low = 60,
        high = 60,
        continent = Eastern_Kingdoms,
        entrance = {39, 68},  -- approximate (NW of Karazhan); verify in-game
    }
    if zones[1430] then
        zones[1430].instances = zones[1430].instances or {}
        table.insert(zones[1430].instances, L["Karazhan Crypts"])
    end

    -- Endgame raids are flexible-size on SoD; override the shared entries.
    for _, id in ipairs({ 409, 249, 469, 533, 531 }) do  -- Molten Core, Onyxia, BWL, Naxxramas, AQ40
        if raids[id] then raids[id].players = "20-40" end
    end
    if raids[509] then raids[509].players = "10-20" end  -- Ruins of Ahn'Qiraj
    if raids[309] then                                   -- Zul'Gurub (retuned to 58-60)
        raids[309].players = "10-20"
        raids[309].low = 58
    end
end

-- ============================================================================
-- Cataclysm+ Data (retail-style uiMapIDs, gated by expansion)
-- The post-Cataclysm revamped old world, Cata zones, and (where present on the
-- running client) MoP content. Pre-Cata clients use the base combined zones above.
-- ============================================================================

if isMoP or isCata then

-- ============================================================================
-- MoP: Azeroth/Outland Zones (retail uiMapIDs)
-- ============================================================================

-- Alliance Starting Zones
-- Elwynn Forest
zones[37] = {
    low = 1,
    high = 10,
    continent = Eastern_Kingdoms,
    faction = "Alliance",
    fishing_min = 1,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot"},
    nodes = {"Copper Vein"},
}

-- Teldrassil
zones[57] = {
    low = 1,
    high = 11,
    continent = Kalimdor,
    faction = "Alliance",
    fishing_min = 1,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot"},
}

-- Dun Morogh
zones[27] = {
    low = 1,
    high = 12,
    continent = Eastern_Kingdoms,
    faction = "Alliance",
    fishing_min = 1,
    instances = {90},
    herbs = {"Peacebloom", "Silverleaf", "Earthroot"},
    nodes = {"Copper Vein"},
}

-- Azuremyst Isle
zones[97] = {
    low = 1,
    high = 10,
    continent = Kalimdor,
    faction = "Alliance",
    fishing_min = 1,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot"},
    nodes = {"Copper Vein"},
}

-- Westfall
zones[52] = {
    low = 9,
    high = 18,
    continent = Eastern_Kingdoms,
    instances = {36},
    faction = "Alliance",
    fishing_min = 55,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Bruiseweed"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"},
}

-- Loch Modan
zones[48] = {
    low = 10,
    high = 18,
    continent = Eastern_Kingdoms,
    faction = "Alliance",
    fishing_min = 20,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Bruiseweed"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"},
}

-- Darkshore
zones[62] = {
    low = 11,
    high = 19,
    continent = Kalimdor,
    faction = "Alliance",
    fishing_min = 20,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"},
}

-- Bloodmyst Isle
zones[106] = {
    low = 10,
    high = 20,
    continent = Kalimdor,
    faction = "Alliance",
    fishing_min = 20,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"},
}

-- Horde Starting Zones
-- Durotar
zones[1] = {
    low = 1,
    high = 10,
    continent = Kalimdor,
    faction = "Horde",
    fishing_min = 1,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal"},
    nodes = {"Copper Vein"},
}

-- Mulgore
zones[7] = {
    low = 1,
    high = 10,
    continent = Kalimdor,
    faction = "Horde",
    fishing_min = 1,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot"},
    nodes = {"Copper Vein"},
}

-- Tirisfal Glades
zones[18] = {
    low = 1,
    high = 12,
    continent = Eastern_Kingdoms,
    instances = {1001, 1004},
    faction = "Horde",
    fishing_min = 1,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot"},
    nodes = {"Copper Vein"},
}

-- Eversong Woods
zones[94] = {
    low = 1,
    high = 10,
    continent = Eastern_Kingdoms,
    faction = "Horde",
    fishing_min = 1,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot"},
    nodes = {"Copper Vein"},
}

-- Silverpine Forest
zones[21] = {
    low = 10,
    high = 20,
    instances = {33},
    continent = Eastern_Kingdoms,
    faction = "Horde",
    fishing_min = 20,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"},
}

-- Northern Barrens
zones[10] = {
    low = 10,
    high = 33,
    continent = Kalimdor,
    instances = {43},
    battlegrounds = {489},
    faction = "Horde",
    fishing_min = 20,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Grave Moss", "Kingsblood"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"},
}

-- Southern Barrens (Cataclysm split from The Barrens; holds Razorfen Kraul/Downs)
zones[199] = {
    low = 30,
    high = 35,
    continent = Kalimdor,
    instances = {47, 129},
    faction = "Contested",
    fishing_min = 20,
    herbs = {"Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Kingsblood", "Liferoot"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit"},
}

-- Cata+ map positions for the Barrens-split dungeons. The base instances[] entries
-- hold the pre-Cataclysm combined-Barrens coordinates (used by Vanilla/TBC/Wrath);
-- on the split maps these entrances sit at different positions.
instances[43].entrance = {38.9, 69.2}   -- Wailing Caverns on Northern Barrens (10)
instances[47].entrance = {40.8, 94.5}   -- Razorfen Kraul on Southern Barrens (199)
instances[129].entrance = {42.7, 94.5}  -- Razorfen Downs on Southern Barrens (199)

-- Ghostlands
zones[95] = {
    low = 10,
    high = 20,
    continent = Eastern_Kingdoms,
    faction = "Horde",
    fishing_min = 20,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"},
}

-- Contested Zones (Eastern Kingdoms)
-- Duskwood
zones[47] = {
    low = 10,
    high = 30,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    fishing_min = 55,
    herbs = {"Mageroyal", "Briarthorn", "Wild Steelbloom", "Grave Moss", "Kingsblood"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein"},
}

-- Redridge Mountains
zones[49] = {
    low = 15,
    high = 25,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    fishing_min = 55,
    herbs = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Bruiseweed"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein"},
}

-- Wetlands
zones[56] = {
    low = 20,
    high = 30,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    fishing_min = 55,
    herbs = {"Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Grave Moss", "Kingsblood", "Liferoot"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein"},
}

-- Hillsbrad Foothills
zones[25] = {
    low = 20,
    high = 31,
    continent = Eastern_Kingdoms,
    battlegrounds = {30},
    faction = "Contested",
    fishing_min = 55,
    herbs = {"Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Kingsblood", "Liferoot"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit"},
}

-- Arathi Highlands
zones[14] = {
    low = 30,
    high = 40,
    continent = Eastern_Kingdoms,
    battlegrounds = {529},
    faction = "Contested",
    fishing_min = 130,
    herbs = {"Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Grave Moss", "Kingsblood", "Liferoot", "Fadeleaf", "Goldthorn", "Khadgar's Whisker"},
    nodes = {"Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"},
}

-- Northern Stranglethorn
zones[50] = {
    low = 30,
    high = 50,
    continent = Eastern_Kingdoms,
    instances = {859},
    faction = "Contested",
    fishing_min = 130,
    herbs = {"Stranglekelp", "Wild Steelbloom", "Kingsblood", "Liferoot", "Fadeleaf", "Goldthorn", "Khadgar's Whisker", "Purple Lotus"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"},
}

-- Stranglethorn Vale (overview map over Northern Stranglethorn / Cape of Stranglethorn;
-- shows the Zul'Gurub entrance at its overview-relative position)
zones[224] = {
    low = 30,
    high = 50,
    continent = Eastern_Kingdoms,
    instances = {859},
    instanceCoords = { [859] = {61.9, 22.2} },
    faction = "Contested",
    fishing_min = 130,
    herbs = {"Stranglekelp", "Wild Steelbloom", "Kingsblood", "Liferoot", "Fadeleaf", "Goldthorn", "Khadgar's Whisker", "Purple Lotus"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"},
}

-- Swamp of Sorrows
zones[51] = {
    low = 36,
    high = 43,
    continent = Eastern_Kingdoms,
    instances = {109},
    faction = "Contested",
    fishing_min = 130,
    herbs = {"Stranglekelp", "Kingsblood", "Fadeleaf", "Goldthorn", "Khadgar's Whisker", "Blindweed"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein"},
}

-- Badlands
zones[15] = {
    low = 36,
    high = 45,
    continent = Eastern_Kingdoms,
    instances = {70},
    faction = "Contested",
    herbs = {"Wild Steelbloom", "Kingsblood", "Fadeleaf", "Goldthorn", "Khadgar's Whisker", "Firebloom", "Purple Lotus"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"},
}

-- The Hinterlands
zones[26] = {
    low = 41,
    high = 49,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Stranglekelp", "Liferoot", "Fadeleaf", "Goldthorn", "Khadgar's Whisker", "Purple Lotus", "Sungrass", "Ghost Mushroom", "Golden Sansam"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein"},
}

-- Western Plaguelands
zones[22] = {
    low = 43,
    high = 57,
    continent = Eastern_Kingdoms,
    instances = {1007},
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Arthas' Tears", "Sungrass", "Dreamfoil", "Mountain Silversage", "Plaguebloom"},
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein", "Rich Thorium Vein"},
}

-- Searing Gorge
zones[32] = {
    low = 43,
    high = 56,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    herbs = {"Firebloom"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Dark Iron Deposit", "Small Thorium Vein"},
}

-- Blasted Lands
zones[17] = {
    low = 46,
    high = 60,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    herbs = {"Goldthorn", "Firebloom", "Sungrass", "Gromsblood"},
    nodes = {"Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein"},
}

-- Burning Steppes
zones[36] = {
    low = 50,
    high = 59,
    continent = Eastern_Kingdoms,
    instances = {230, 229},
    raids = {409, 469, 669},
    faction = "Contested",
    fishing_min = 330,
    herbs = {"Sungrass", "Golden Sansam", "Dreamfoil", "Mountain Silversage", "Black Lotus"},
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Dark Iron Deposit", "Small Thorium Vein", "Rich Thorium Vein"},
}

-- Deadwind Pass
zones[42] = {
    low = 50,
    high = MAX_LEVEL,
    continent = Eastern_Kingdoms,
    raids = {532},
    faction = "Contested",
    fishing_min = 330,
}

-- Eastern Plaguelands
zones[23] = {
    low = 54,
    high = 59,
    continent = Eastern_Kingdoms,
    instances = {329},
    faction = "Contested",
    fishing_min = 330,
    herbs = {"Arthas' Tears", "Sungrass", "Golden Sansam", "Dreamfoil", "Mountain Silversage", "Plaguebloom", "Black Lotus"},
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein", "Rich Thorium Vein"},
}

-- Contested Zones (Kalimdor)
-- Moonglade
zones[80] = {
    low = 10,
    high = MAX_LEVEL,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 205,
}

-- Stonetalon Mountains
zones[65] = {
    low = 15,
    high = 25,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 55,
    herbs = {"Mageroyal", "Bruiseweed", "Wild Steelbloom", "Kingsblood"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"},
}

-- Ashenvale
zones[63] = {
    low = 19,
    high = 30,
    instances = {48},
    battlegrounds = {489},
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 55,
    herbs = {"Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Kingsblood", "Liferoot"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein"},
}

-- Thousand Needles
zones[64] = {
    low = 24,
    high = 35,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 130,
    herbs = {"Bruiseweed", "Wild Steelbloom", "Kingsblood"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit"},
}

-- Desolace
zones[66] = {
    low = 30,
    high = 39,
    continent = Kalimdor,
    instances = {349},
    faction = "Contested",
    fishing_min = 130,
    herbs = {"Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Grave Moss", "Kingsblood", "Liferoot", "Gromsblood"},
    nodes = {"Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"},
}

-- Dustwallow Marsh
zones[70] = {
    low = 33,
    high = 50,
    continent = Kalimdor,
    raids = {249},
    faction = "Contested",
    fishing_min = 130,
    herbs = {"Stranglekelp", "Kingsblood", "Liferoot", "Fadeleaf", "Goldthorn", "Khadgar's Whisker"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit"},
}

-- Tanaris
zones[71] = {
    low = 40,
    high = 50,
    continent = Kalimdor,
    instances = {209},
    complexes = {2367},
    raids = {967},
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Stranglekelp", "Firebloom", "Purple Lotus"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein"},
}

-- Feralas
zones[69] = {
    low = 41,
    high = 50,
    continent = Kalimdor,
    complexes = {429},
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Stranglekelp", "Liferoot", "Goldthorn", "Khadgar's Whisker", "Purple Lotus", "Sungrass", "Golden Sansam"},
    nodes = {"Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein"},
}

-- Azshara
zones[76] = {
    low = 42,
    high = 55,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Stranglekelp", "Goldthorn", "Khadgar's Whisker", "Purple Lotus", "Sungrass", "Golden Sansam", "Mountain Silversage"},
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Rich Thorium Vein"},
}

-- Felwood
zones[77] = {
    low = 47,
    high = 54,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Arthas' Tears", "Sungrass", "Gromsblood", "Golden Sansam", "Dreamfoil", "Mountain Silversage", "Plaguebloom"},
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein"},
}

-- Un'Goro Crater
zones[78] = {
    low = 48,
    high = 55,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 205,
    herbs = {"Sungrass", "Blindweed", "Golden Sansam", "Dreamfoil", "Mountain Silversage"},
    nodes = {"Truesilver Deposit", "Small Thorium Vein", "Rich Thorium Vein"},
}

-- Silithus
zones[81] = {
    low = 55,
    high = 59,
    continent = Kalimdor,
    raids = {509, 531},
    faction = "Contested",
    fishing_min = 330,
    herbs = {"Sungrass", "Golden Sansam", "Dreamfoil", "Mountain Silversage", "Black Lotus"},
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein", "Rich Thorium Vein"},
}

-- Winterspring
zones[83] = {
    low = 55,
    high = 60,
    continent = Kalimdor,
    faction = "Contested",
    fishing_min = 330,
    herbs = {"Mountain Silversage", "Icecap", "Black Lotus"},
    nodes = {"Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Small Thorium Vein", "Rich Thorium Vein"},
}

-- Outland Zones
-- Hellfire Peninsula
zones[100] = {
    low = 58,
    high = 63,
    continent = Outland,
    instances = {543, 542, 540},
    raids = {544},
    faction = "Contested",
    fishing_min = 280,
    herbs = {"Felweed", "Dreaming Glory", "Flame Cap"},
    nodes = {"Fel Iron Deposit", "Adamantite Deposit"},
}

-- Zangarmarsh
zones[102] = {
    low = 60,
    high = 64,
    continent = Outland,
    instances = {546, 545, 547},
    raids = {548},
    faction = "Contested",
    fishing_min = 305,
    herbs = {"Felweed", "Dreaming Glory", "Ragveil", "Flame Cap"},
    nodes = {"Fel Iron Deposit", "Adamantite Deposit"},
}

-- Terokkar Forest
zones[108] = {
    low = 62,
    high = 65,
    continent = Outland,
    complexes = {3790},
    faction = "Contested",
    fishing_min = 355,
    herbs = {"Felweed", "Dreaming Glory", "Terocone"},
    nodes = {"Fel Iron Deposit", "Adamantite Deposit", "Rich Adamantite Deposit"},
}

-- Nagrand
zones[107] = {
    low = 64,
    high = 67,
    continent = Outland,
    faction = "Contested",
    fishing_min = 380,
    herbs = {"Felweed", "Dreaming Glory", "Terocone"},
    nodes = {"Fel Iron Deposit", "Adamantite Deposit", "Rich Adamantite Deposit"},
}

-- Blade's Edge Mountains
zones[105] = {
    low = 65,
    high = 68,
    continent = Outland,
    raids = {565},
    faction = "Contested",
    fishing_min = 355,
    herbs = {"Felweed", "Dreaming Glory", "Flame Cap", "Netherbloom"},
    nodes = {"Fel Iron Deposit", "Adamantite Deposit", "Rich Adamantite Deposit", "Khorium Vein"},
}

-- Netherstorm
zones[109] = {
    low = 67,
    high = 70,
    continent = Outland,
    instances = {554, 553, 552},
    raids = {550},
    battlegrounds = {566},
    faction = "Contested",
    fishing_min = 380,
    herbs = {"Felweed", "Dreaming Glory", "Netherbloom", "Nightmare Vine", "Mana Thistle"},
    nodes = {"Fel Iron Deposit", "Adamantite Deposit", "Rich Adamantite Deposit", "Khorium Vein"},
}

-- Shadowmoon Valley
zones[104] = {
    low = 67,
    high = 70,
    continent = Outland,
    raids = {564},
    faction = "Contested",
    fishing_min = 380,
    herbs = {"Felweed", "Dreaming Glory", "Terocone", "Nightmare Vine", "Ancient Lichen"},
    nodes = {"Fel Iron Deposit", "Adamantite Deposit", "Rich Adamantite Deposit", "Khorium Vein"},
}

-- ============================================================================
-- MoP: Northrend Zones (WotLK, retail uiMapIDs)
-- ============================================================================

local Northrend = "Northrend"

-- Borean Tundra
zones[114] = {
    low = 68,
    high = 72,
    continent = Northrend,
    instances = {576, 578},
    raids = {616},
    faction = "Contested",
    fishing_min = 380,
    herbs = {"Goldclover", "Tiger Lily"},
    nodes = {"Cobalt Deposit", "Rich Cobalt Deposit"},
}

-- Howling Fjord
zones[117] = {
    low = 68,
    high = 72,
    continent = Northrend,
    instances = {574, 575},
    faction = "Contested",
    fishing_min = 380,
    herbs = {"Goldclover", "Tiger Lily"},
    nodes = {"Cobalt Deposit", "Rich Cobalt Deposit"},
}

-- Dragonblight
zones[115] = {
    low = 71,
    high = 75,
    continent = Northrend,
    instances = {601, 619},
    raids = {533, 615, 724},
    faction = "Contested",
    fishing_min = 405,
    herbs = {"Goldclover", "Tiger Lily", "Talandra's Rose"},
    nodes = {"Cobalt Deposit", "Rich Cobalt Deposit", "Saronite Deposit"},
}

-- Grizzly Hills
zones[116] = {
    low = 73,
    high = 75,
    continent = Northrend,
    faction = "Contested",
    fishing_min = 405,
    herbs = {"Goldclover", "Tiger Lily", "Talandra's Rose"},
    nodes = {"Cobalt Deposit", "Rich Cobalt Deposit", "Saronite Deposit"},
}

-- Zul'Drak
zones[121] = {
    low = 74,
    high = 77,
    continent = Northrend,
    instances = {600, 604},
    faction = "Contested",
    fishing_min = 430,
    herbs = {"Goldclover", "Tiger Lily", "Talandra's Rose", "Adder's Tongue"},
    nodes = {"Cobalt Deposit", "Rich Cobalt Deposit", "Saronite Deposit"},
}

-- Sholazar Basin
zones[119] = {
    low = 76,
    high = 78,
    continent = Northrend,
    faction = "Contested",
    fishing_min = 430,
    herbs = {"Goldclover", "Tiger Lily", "Adder's Tongue"},
    nodes = {"Saronite Deposit", "Rich Saronite Deposit", "Titanium Vein"},
}

-- The Storm Peaks
zones[120] = {
    low = 77,
    high = 80,
    continent = Northrend,
    instances = {599, 602},
    raids = {603},
    faction = "Contested",
    fishing_min = 455,
    herbs = {"Lichbloom", "Icethorn", "Frost Lotus"},
    nodes = {"Saronite Deposit", "Rich Saronite Deposit", "Titanium Vein"},
}

-- Icecrown
zones[118] = {
    low = 77,
    high = 80,
    continent = Northrend,
    instances = {632, 658, 668},
    raids = {631, 649},
    faction = "Contested",
    fishing_min = 455,
    herbs = {"Lichbloom", "Icethorn", "Frost Lotus"},
    nodes = {"Saronite Deposit", "Rich Saronite Deposit", "Titanium Vein"},
}

-- Crystalsong Forest
zones[127] = {
    low = 77,
    high = 80,
    continent = Northrend,
    faction = "Contested",
    fishing_min = 430,
    herbs = {"Goldclover", "Talandra's Rose"},
    nodes = {"Saronite Deposit", "Rich Saronite Deposit"},
}

-- Wintergrasp
zones[123] = {
    low = 77,
    high = 80,
    continent = Northrend,
    raids = {624},
    faction = "Contested",
    fishing_min = 455,
    herbs = {"Goldclover", "Tiger Lily", "Lichbloom", "Icethorn", "Frost Lotus"},
    nodes = {"Cobalt Deposit", "Rich Cobalt Deposit", "Saronite Deposit", "Rich Saronite Deposit", "Titanium Vein"},
}

-- Dalaran (Northrend)
zones[125] = {
    low = 1,
    high = MAX_LEVEL,
    continent = Northrend,
    instances = {608, 650},
    faction = "Contested",
    fishing_min = 430,
}

-- ============================================================================
-- MoP: Cataclysm Zones (retail uiMapIDs)
-- ============================================================================

-- Mount Hyjal
zones[198] = {
    low = 80,
    high = 82,
    continent = Kalimdor,
    raids = {720},
    faction = "Contested",
    fishing_min = 480,
    herbs = {"Cinderbloom", "Stormvine", "Heartblossom"},
    nodes = {"Obsidium Deposit", "Rich Obsidium Deposit"},
}

-- Vashj'ir (overview map; Throne of the Tides' portal is in the Abyssal Depths
-- sub-zone, so its pin needs an overview-relative position override here)
zones[203] = {
    low = 80,
    high = 82,
    continent = Eastern_Kingdoms,
    instances = {643},
    instanceCoords = { [643] = {49.3, 43.1} },
    faction = "Contested",
    fishing_min = 480,
    herbs = {"Azshara's Veil", "Stormvine"},
    nodes = {"Obsidium Deposit", "Rich Obsidium Deposit"},
}

-- Abyssal Depths (Vashj'ir sub-zone; holds the Throne of the Tides entrance)
zones[204] = {
    low = 80,
    high = 82,
    continent = Eastern_Kingdoms,
    instances = {643},
    faction = "Contested",
    fishing_min = 480,
    herbs = {"Azshara's Veil", "Stormvine"},
    nodes = {"Obsidium Deposit", "Rich Obsidium Deposit"},
}

-- Deepholm
zones[207] = {
    low = 82,
    high = 83,
    continent = Eastern_Kingdoms,
    instances = {725},
    faction = "Contested",
    herbs = {"Heartblossom", "Cinderbloom"},
    nodes = {"Elementium Vein", "Rich Elementium Vein"},
}

-- Uldum
zones[249] = {
    low = 83,
    high = 84,
    continent = Kalimdor,
    instances = {755, 644, 657},
    raids = {754},
    faction = "Contested",
    fishing_min = 530,
    herbs = {"Whiptail", "Cinderbloom"},
    nodes = {"Elementium Vein", "Rich Elementium Vein", "Pyrite Deposit"},
}

-- Twilight Highlands
zones[241] = {
    low = 84,
    high = 85,
    continent = Eastern_Kingdoms,
    instances = {670, 645},
    raids = {671},
    faction = "Contested",
    fishing_min = 530,
    herbs = {"Twilight Jasmine", "Cinderbloom", "Heartblossom"},
    nodes = {"Elementium Vein", "Rich Elementium Vein", "Pyrite Deposit", "Rich Pyrite Deposit"},
}

-- Tol Barad Peninsula
zones[245] = {
    low = 85,
    high = 85,
    continent = Eastern_Kingdoms,
    faction = "Contested",
    fishing_min = 555,
    herbs = {"Whiptail", "Azshara's Veil"},
    nodes = {"Elementium Vein", "Rich Elementium Vein"},
}

-- Tol Barad
zones[244] = {
    low = 85,
    high = 85,
    continent = Eastern_Kingdoms,
    raids = {757},
    faction = "Contested",
    fishing_min = 555,
    herbs = {"Whiptail", "Azshara's Veil"},
    nodes = {"Elementium Vein", "Rich Elementium Vein"},
}

-- Molten Front
zones[338] = {
    low = 85,
    high = 85,
    continent = Kalimdor,
    faction = "Contested",
    herbs = {"Cinderbloom"},
    nodes = {"Elementium Vein", "Rich Elementium Vein", "Pyrite Deposit"},
}

-- ============================================================================
-- MoP: WotLK/Cata Cities
-- ============================================================================

-- Orgrimmar
zones[85] = {
    low = 1,
    high = MAX_LEVEL,
    continent = Kalimdor,
    instances = {389},
    faction = "Horde",
    fishing_min = 1,
}

-- Thunder Bluff
zones[88] = {
    low = 1,
    high = MAX_LEVEL,
    continent = Kalimdor,
    faction = "Horde",
    fishing_min = 1,
}

-- Undercity
zones[90] = {
    low = 1,
    high = MAX_LEVEL,
    continent = Eastern_Kingdoms,
    faction = "Horde",
    fishing_min = 1,
}

-- Silvermoon City
zones[110] = {
    low = 1,
    high = MAX_LEVEL,
    continent = Eastern_Kingdoms,
    faction = "Horde",
}

-- Darnassus
zones[89] = {
    low = 1,
    high = MAX_LEVEL,
    continent = Kalimdor,
    faction = "Alliance",
    fishing_min = 1,
}

-- Ironforge
zones[87] = {
    low = 1,
    high = MAX_LEVEL,
    continent = Eastern_Kingdoms,
    faction = "Alliance",
    fishing_min = 1,
}

-- Stormwind City
zones[84] = {
    low = 1,
    high = MAX_LEVEL,
    continent = Eastern_Kingdoms,
    instances = {34},
    faction = "Alliance",
    fishing_min = 1,
}

-- The Exodar
zones[103] = {
    low = 1,
    high = MAX_LEVEL,
    continent = Kalimdor,
    faction = "Alliance",
}

-- Shattrath City
zones[111] = {
    low = 1,
    high = MAX_LEVEL,
    continent = Outland,
    faction = "Contested",
}

-- ============================================================================
-- MoP: Pandaria Zones
-- ============================================================================

-- The Jade Forest
zones[371] = {
    low = 85,
    high = 86,
    continent = Pandaria,
    instances = {960},
    faction = "Contested",
    fishing_min = 650,
    herbs = {"Green Tea Leaf", "Rain Poppy", "Silkweed"},
    nodes = {"Ghost Iron Deposit", "Rich Ghost Iron Deposit"},
}

-- Valley of the Four Winds
zones[376] = {
    low = 86,
    high = 87,
    continent = Pandaria,
    instances = {961},
    faction = "Contested",
    fishing_min = 700,
    herbs = {"Green Tea Leaf", "Silkweed", "Rain Poppy", "Golden Lotus"},
    nodes = {"Ghost Iron Deposit", "Rich Ghost Iron Deposit"},
}

-- Krasarang Wilds
zones[418] = {
    low = 86,
    high = 87,
    continent = Pandaria,
    faction = "Contested",
    fishing_min = 700,
    herbs = {"Green Tea Leaf", "Silkweed", "Rain Poppy", "Golden Lotus"},
    nodes = {"Ghost Iron Deposit", "Rich Ghost Iron Deposit"},
}

-- Kun-Lai Summit
zones[379] = {
    low = 87,
    high = 88,
    continent = Pandaria,
    instances = {959},
    raids = {1008},
    faction = "Contested",
    fishing_min = 750,
    herbs = {"Snow Lily", "Green Tea Leaf", "Silkweed", "Golden Lotus"},
    nodes = {"Ghost Iron Deposit", "Rich Ghost Iron Deposit", "Trillium Vein", "Rich Trillium Vein"},
}

-- Townlong Steppes
zones[388] = {
    low = 88,
    high = 89,
    continent = Pandaria,
    instances = {1011},
    faction = "Contested",
    fishing_min = 800,
    herbs = {"Snow Lily", "Fool's Cap", "Green Tea Leaf", "Golden Lotus"},
    nodes = {"Ghost Iron Deposit", "Rich Ghost Iron Deposit", "Trillium Vein", "Rich Trillium Vein"},
}

-- Dread Wastes
zones[422] = {
    low = 89,
    high = 90,
    continent = Pandaria,
    instances = {962},
    raids = {1009},
    faction = "Contested",
    fishing_min = 825,
    herbs = {"Fool's Cap", "Snow Lily", "Green Tea Leaf", "Golden Lotus"},
    nodes = {"Ghost Iron Deposit", "Rich Ghost Iron Deposit", "Trillium Vein", "Rich Trillium Vein", "Kyparite Deposit", "Rich Kyparite Deposit"},
}

-- Vale of Eternal Blossoms
zones[390] = {
    low = 90,
    high = 90,
    continent = Pandaria,
    instances = {994},
    raids = {1136},
    faction = "Contested",
    fishing_min = 825,
    herbs = {"Green Tea Leaf", "Snow Lily", "Fool's Cap", "Golden Lotus"},
    nodes = {"Ghost Iron Deposit", "Rich Ghost Iron Deposit", "Trillium Vein", "Rich Trillium Vein"},
}

-- The Veiled Stair
zones[433] = {
    low = 87,
    high = 90,
    continent = Pandaria,
    raids = {996},
    faction = "Contested",
}

-- Isle of Thunder (Patch 5.2)
zones[504] = {
    low = 90,
    high = 90,
    continent = Pandaria,
    raids = {1098},
    faction = "Contested",
    fishing_min = 825,
    herbs = {"Snow Lily", "Fool's Cap", "Golden Lotus"},
    nodes = {"Ghost Iron Deposit", "Rich Ghost Iron Deposit", "Trillium Vein", "Rich Trillium Vein"},
}

-- Timeless Isle (Patch 5.4)
zones[554] = {
    low = 90,
    high = 90,
    continent = Pandaria,
    faction = "Contested",
    fishing_min = 825,
}

-- ============================================================================
-- MoP: Dungeon Instance Data
-- ============================================================================

-- Temple of the Jade Serpent
instances[960] = {
    low = 85,
    high = 90,
    continent = Pandaria,
    entrance = {56.8, 58.2},
}

-- Stormstout Brewery
instances[961] = {
    low = 86,
    high = 90,
    continent = Pandaria,
    entrance = {36.1, 69.1},
}

-- Shado-Pan Monastery
instances[959] = {
    low = 87,
    high = 90,
    continent = Pandaria,
    entrance = {36.8, 47.5},
}

-- Gate of the Setting Sun
instances[962] = {
    low = 90,
    high = 90,
    continent = Pandaria,
    entrance = {15.8, 74.3},
}

-- Mogu'shan Palace
instances[994] = {
    low = 87,
    high = 90,
    continent = Pandaria,
    entrance = {80.7, 32.8},
}

-- Siege of Niuzao Temple
instances[1011] = {
    low = 90,
    high = 90,
    continent = Pandaria,
    entrance = {34.6, 81.4},
}

-- Scarlet Halls (MoP revamp)
instances[1001] = {
    low = 26,
    high = 90,
    continent = Eastern_Kingdoms,
    entrance = {84.3, 30.6},
}

-- Scarlet Monastery (MoP revamp)
instances[1004] = {
    low = 28,
    high = 90,
    continent = Eastern_Kingdoms,
    entrance = {85.3, 30.6},
}

-- Scholomance (MoP revamp)
instances[1007] = {
    low = 38,
    high = 90,
    continent = Eastern_Kingdoms,
    entrance = {69, 73},
}

-- ============================================================================
-- MoP: WotLK Dungeon Instance Data
-- ============================================================================

-- Utgarde Keep
instances[574] = {
    low = 69,
    high = 72,
    continent = Northrend,
    entrance = {57.3, 46.7},
}

-- The Nexus
instances[576] = {
    low = 69,
    high = 73,
    continent = Northrend,
    entrance = {27.5, 26.0},
}

-- Azjol-Nerub
instances[601] = {
    low = 72,
    high = 74,
    continent = Northrend,
    entrance = {26.0, 50.8},
}

-- Ahn'kahet: The Old Kingdom
instances[619] = {
    low = 73,
    high = 75,
    continent = Northrend,
    entrance = {28.5, 51.5},
}

-- Drak'Tharon Keep
instances[600] = {
    low = 74,
    high = 76,
    continent = Northrend,
    entrance = {28.6, 86.8},
}

-- The Violet Hold
instances[608] = {
    low = 75,
    high = 77,
    continent = Northrend,
    entrance = {66.8, 68.2},
}

-- Gundrak
instances[604] = {
    low = 76,
    high = 78,
    continent = Northrend,
    entrance = {76.1, 20.7},
}

-- Halls of Stone
instances[599] = {
    low = 77,
    high = 79,
    continent = Northrend,
    entrance = {39.5, 26.9},
}

-- Halls of Lightning
instances[602] = {
    low = 79,
    high = 80,
    continent = Northrend,
    entrance = {45.4, 21.4},
}

-- The Oculus
instances[578] = {
    low = 79,
    high = 80,
    continent = Northrend,
    entrance = {27.5, 27.0},
}

-- Utgarde Pinnacle
instances[575] = {
    low = 79,
    high = 80,
    continent = Northrend,
    entrance = {57.3, 46.5},
}

-- The Culling of Stratholme
instances[595] = {
    low = 79,
    high = 80,
    continent = Kalimdor,
    entrance = {66.0, 49.0},
}

-- Trial of the Champion
instances[650] = {
    low = 80,
    high = 80,
    continent = Northrend,
    entrance = {74.2, 20.5},
}

-- The Forge of Souls
instances[632] = {
    low = 80,
    high = 80,
    continent = Northrend,
    entrance = {52.6, 89.4},
}

-- Pit of Saron
instances[658] = {
    low = 80,
    high = 80,
    continent = Northrend,
    entrance = {52.6, 89.2},
}

-- Halls of Reflection
instances[668] = {
    low = 80,
    high = 80,
    continent = Northrend,
    entrance = {52.6, 89.0},
}

-- ============================================================================
-- MoP: Cataclysm Dungeon Instance Data
-- ============================================================================

-- Blackrock Caverns
instances[645] = {
    low = 80,
    high = 85,
    continent = Eastern_Kingdoms,
    entrance = {66.4, 62.0},
}

-- Throne of the Tides
instances[643] = {
    low = 80,
    high = 85,
    continent = Eastern_Kingdoms,
    entrance = {69.4, 25.4},  -- on the Abyssal Depths (204) map, where the portal is
}

-- The Stonecore
instances[725] = {
    low = 82,
    high = 85,
    continent = Eastern_Kingdoms,
    entrance = {47.7, 52.0},
}

-- The Vortex Pinnacle
instances[657] = {
    low = 82,
    high = 85,
    continent = Kalimdor,
    entrance = {76.5, 84.3},
}

-- Lost City of the Tol'vir
instances[755] = {
    low = 83,
    high = 85,
    continent = Kalimdor,
    entrance = {60.5, 64.2},
}

-- Halls of Origination
instances[644] = {
    low = 83,
    high = 85,
    continent = Kalimdor,
    entrance = {71.7, 52.1},
}

-- Grim Batol
instances[670] = {
    low = 84,
    high = 85,
    continent = Eastern_Kingdoms,
    entrance = {19.1, 53.8},
}

-- Zul'Aman (Cata)
instances[568] = {
    low = 85,
    high = 85,
    continent = Eastern_Kingdoms,
    entrance = {81.8, 64.3},
}

-- Zul'Gurub (Cata)
instances[859] = {
    low = 85,
    high = 85,
    continent = Eastern_Kingdoms,
    entrance = {68.4, 32.9},
}

-- End Time
instances[938] = {
    low = 85,
    high = 85,
    continent = Kalimdor,
    entrance = {66.0, 49.0},
}

-- Well of Eternity
instances[939] = {
    low = 85,
    high = 85,
    continent = Kalimdor,
    entrance = {66.0, 49.0},
}

-- Hour of Twilight
instances[940] = {
    low = 85,
    high = 85,
    continent = Kalimdor,
    entrance = {66.0, 49.0},
}

-- ============================================================================
-- MoP: WotLK Raid Instance Data
-- ============================================================================

-- Naxxramas (WotLK)
raids[533] = {
    low = 80,
    high = 80,
    players = "10/25",
    continent = Northrend,
    entrance = {87.3, 51.0},
}

-- The Obsidian Sanctum
raids[615] = {
    low = 80,
    high = 80,
    players = "10/25",
    continent = Northrend,
    entrance = {60.0, 57.0},
}

-- The Eye of Eternity
raids[616] = {
    low = 80,
    high = 80,
    players = "10/25",
    continent = Northrend,
    entrance = {27.5, 26.0},
}

-- Ulduar
raids[603] = {
    low = 80,
    high = 80,
    players = "10/25",
    continent = Northrend,
    entrance = {41.6, 17.8},
}

-- Trial of the Crusader
raids[649] = {
    low = 80,
    high = 80,
    players = "10/25",
    continent = Northrend,
    entrance = {75.1, 21.8},
}

-- Vault of Archavon
raids[624] = {
    low = 80,
    high = 80,
    players = "10/25",
    continent = Northrend,
    entrance = {50.0, 11.4},
}

-- Icecrown Citadel
raids[631] = {
    low = 80,
    high = 80,
    players = "10/25",
    continent = Northrend,
    entrance = {53.9, 87.3},
}

-- The Ruby Sanctum
raids[724] = {
    low = 80,
    high = 80,
    players = "10/25",
    continent = Northrend,
    entrance = {60.0, 57.0},
}

-- ============================================================================
-- MoP: Cataclysm Raid Instance Data
-- ============================================================================

-- Blackwing Descent
raids[669] = {
    low = 85,
    high = 85,
    players = "10/25",
    continent = Eastern_Kingdoms,
    entrance = {29.0, 35.0},
}

-- The Bastion of Twilight
raids[671] = {
    low = 85,
    high = 85,
    players = "10/25",
    continent = Eastern_Kingdoms,
    entrance = {33.8, 78.2},
}

-- Throne of the Four Winds
raids[754] = {
    low = 85,
    high = 85,
    players = "10/25",
    continent = Kalimdor,
    entrance = {38.4, 80.6},
}

-- Firelands
raids[720] = {
    low = 85,
    high = 85,
    players = "10/25",
    continent = Kalimdor,
    entrance = {47.3, 78.3},
}

-- Dragon Soul
raids[967] = {
    low = 85,
    high = 85,
    players = "10/25",
    continent = Kalimdor,
    entrance = {66.0, 49.0},
}

-- Baradin Hold
raids[757] = {
    low = 85,
    high = 85,
    players = "10/25",
    continent = Eastern_Kingdoms,
    entrance = {46.3, 47.5},
}

-- ============================================================================
-- MoP: WotLK/Cata Battleground Data
-- ============================================================================

-- Strand of the Ancients
battlegrounds[607] = {
    low = 71,
    high = MAX_LEVEL,
    horde_entrance = {},
    alliance_entrance = {},
    players = 15,
}

-- Isle of Conquest
battlegrounds[628] = {
    low = 75,
    high = MAX_LEVEL,
    horde_entrance = {},
    alliance_entrance = {},
    players = 40,
}

-- Twin Peaks
battlegrounds[726] = {
    low = 85,
    high = MAX_LEVEL,
    horde_entrance = {},
    alliance_entrance = {},
    players = 10,
}

-- Battle for Gilneas
battlegrounds[761] = {
    low = 85,
    high = MAX_LEVEL,
    horde_entrance = {},
    alliance_entrance = {},
    players = 10,
}

-- ============================================================================
-- MoP: Raid Instance Data
-- ============================================================================

-- Mogu'shan Vaults
raids[1008] = {
    low = 90,
    high = 90,
    players = "10/25",
    continent = Pandaria,
    entrance = {59.6, 39.2},
}

-- Heart of Fear
raids[1009] = {
    low = 90,
    high = 90,
    players = "10/25",
    continent = Pandaria,
    entrance = {39.0, 35.0},
}

-- Terrace of Endless Spring
raids[996] = {
    low = 90,
    high = 90,
    players = "10/25",
    continent = Pandaria,
    entrance = {47.9, 61.3},
}

-- Throne of Thunder
raids[1098] = {
    low = 90,
    high = 90,
    players = "10/25",
    continent = Pandaria,
    entrance = {63.5, 32.2},
}

-- Siege of Orgrimmar
raids[1136] = {
    low = 90,
    high = 90,
    players = "10/25",
    continent = Pandaria,
    entrance = {74.0, 42.2},
}

-- ============================================================================
-- MoP: Battleground Data
-- ============================================================================

-- Temple of Kotmogu
battlegrounds[998] = {
    low = 90,
    high = 90,
    horde_entrance = {},
    alliance_entrance = {},
    players = 10,
}

-- Silvershard Mines
battlegrounds[727] = {
    low = 90,
    high = 90,
    horde_entrance = {},
    alliance_entrance = {},
    players = 10,
}

-- Deepwind Gorge
battlegrounds[1105] = {
    low = 90,
    high = 90,
    horde_entrance = {},
    alliance_entrance = {},
    players = 15,
}

-- ============================================================================
-- MoP: Herb Data
-- ============================================================================

herbs["Green Tea Leaf"] = {
    low = 500,
    high = 575,
}

herbs["Silkweed"] = {
    low = 500,
    high = 575,
}

herbs["Rain Poppy"] = {
    low = 525,
    high = 575,
}

herbs["Snow Lily"] = {
    low = 550,
    high = 600,
}

herbs["Fool's Cap"] = {
    low = 575,
    high = 600,
}

herbs["Golden Lotus"] = {
    low = 550,
    high = 600,
}

-- WotLK Herbs
herbs["Goldclover"] = {
    low = 350,
    high = 450,
}

herbs["Tiger Lily"] = {
    low = 375,
    high = 450,
}

herbs["Talandra's Rose"] = {
    low = 385,
    high = 450,
}

herbs["Adder's Tongue"] = {
    low = 400,
    high = 450,
}

herbs["Lichbloom"] = {
    low = 425,
    high = 450,
}

herbs["Icethorn"] = {
    low = 435,
    high = 450,
}

herbs["Frost Lotus"] = {
    low = 450,
    high = 450,
}

-- Cataclysm Herbs
herbs["Cinderbloom"] = {
    low = 425,
    high = 525,
}

herbs["Stormvine"] = {
    low = 425,
    high = 525,
}

herbs["Azshara's Veil"] = {
    low = 450,
    high = 525,
}

herbs["Heartblossom"] = {
    low = 475,
    high = 525,
}

herbs["Whiptail"] = {
    low = 500,
    high = 525,
}

herbs["Twilight Jasmine"] = {
    low = 525,
    high = 525,
}

-- ============================================================================
-- MoP: Mining Node Data
-- ============================================================================

-- WotLK Nodes
nodes["Cobalt Deposit"] = {
    low = 350,
    high = 400,
}

nodes["Rich Cobalt Deposit"] = {
    low = 375,
    high = 425,
}

nodes["Saronite Deposit"] = {
    low = 400,
    high = 450,
}

nodes["Rich Saronite Deposit"] = {
    low = 425,
    high = 450,
}

nodes["Titanium Vein"] = {
    low = 450,
    high = 450,
}

-- Cataclysm Nodes
nodes["Obsidium Deposit"] = {
    low = 425,
    high = 500,
}

nodes["Rich Obsidium Deposit"] = {
    low = 450,
    high = 525,
}

nodes["Elementium Vein"] = {
    low = 475,
    high = 525,
}

nodes["Rich Elementium Vein"] = {
    low = 500,
    high = 525,
}

nodes["Pyrite Deposit"] = {
    low = 525,
    high = 525,
}

nodes["Rich Pyrite Deposit"] = {
    low = 525,
    high = 525,
}

-- MoP Nodes
nodes["Ghost Iron Deposit"] = {
    low = 500,
    high = 575,
}

nodes["Rich Ghost Iron Deposit"] = {
    low = 550,
    high = 600,
}

nodes["Trillium Vein"] = {
    low = 575,
    high = 600,
}

nodes["Rich Trillium Vein"] = {
    low = 600,
    high = 600,
}

nodes["Kyparite Deposit"] = {
    low = 550,
    high = 600,
}

nodes["Rich Kyparite Deposit"] = {
    low = 575,
    high = 600,
}

end -- if isMoP or isCata

-- ============================================================================
-- Caverns of Time (TBC / Wrath / MoP only)
-- ============================================================================
-- String-keyed so the display names are the zone names (GetRealZoneText returns the
-- campaign names "The Escape From Durnholde" / "The Opening of the Dark Portal" for
-- these instanceIDs). Gated so they never leak onto Classic Era / Season of Discovery
-- (string keys bypass the GetRealZoneText presence filter). Placed after the MoP block
-- so both Tanaris zones (1446 pre-MoP, 71 on MoP) exist. Both already reference complex
-- 2367 statically; on Era complexes[2367] is left undefined, which the render loops skip.
if isTBC or isWrath or isMoP then
    instances[L["Old Hillsbrad Foothills"]] = { low = 66, high = 70, continent = Kalimdor, entrance = {66, 49} }
    instances[L["The Black Morass"]]        = { low = 69, high = 70, continent = Kalimdor, entrance = {66, 49} }
    raids[L["Hyjal Summit"]]                = { low = 70, high = 70, players = 25, continent = Kalimdor, entrance = {66, 49} }
    complexes[2367] = { instances = { L["Old Hillsbrad Foothills"], L["The Black Morass"], 595, 938, 939, 940 } }

    -- Hyjal Summit shares the Caverns of Time entrance; attach it to whichever Tanaris
    -- zone the running client uses.
    for _, tanaris in ipairs({ 1446, 71 }) do
        if zones[tanaris] then
            zones[tanaris].raids = zones[tanaris].raids or {}
            table.insert(zones[tanaris].raids, L["Hyjal Summit"])
        end
    end
end
