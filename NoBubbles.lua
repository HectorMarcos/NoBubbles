-- NoBubbles - WotLK 3.3.5
-- Removes chat bubble graphics and shows only the text.
-- Includes Ace3 options panel and /nb command.

-------------------------------------------------
-- AceAddon
-------------------------------------------------
local NoBubbles = LibStub("AceAddon-3.0"):NewAddon("NoBubbles", "AceConsole-3.0")

-------------------------------------------------
-- Defaults and constants
-------------------------------------------------
local defaults = {
    profile = {
        fontSize = 14,
        font = "FRIZQT",        -- FRIZQT, ARIALN, MORPHEUS, SKURRI
        flags = "OUTLINE",      -- "", OUTLINE, THICKOUTLINE
        color = {1, 1, 1},      -- RGB
    }
}

local FONTS = {
    FRIZQT   = { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    ARIALN   = { name = "Arial Narrow",  path = "Fonts\\ARIALN.TTF"  },
    MORPHEUS = { name = "Morpheus",      path = "Fonts\\MORPHEUS.TTF"},
    SKURRI   = { name = "Skurri",        path = "Fonts\\SKURRI.TTF"  },
}

local FLAG_LABELS = {
    [""]             = "None",
    ["OUTLINE"]      = "Outline",
    ["THICKOUTLINE"] = "Thick Outline",
}

-------------------------------------------------
-- UI helpers
-------------------------------------------------
local function fontValues()
    local t = {}
    for k, v in pairs(FONTS) do t[k] = v.name end
    return t
end

function NoBubbles:StyleText(fs)
    local prof = self.db and self.db.profile
    if not (prof and fs) then return end

    local fontPath = (FONTS[prof.font] and FONTS[prof.font].path) or FONTS.FRIZQT.path
    local flags = prof.flags ~= "" and prof.flags or nil

    fs:SetFont(fontPath, prof.fontSize, flags)
    fs:SetTextColor(unpack(prof.color))
    fs:SetJustifyH("LEFT")
end

function NoBubbles:ApplySettings()
    -- Re-apply settings to active bubbles
    for i = 1, WorldFrame:GetNumChildren() do
        local frame = select(i, WorldFrame:GetChildren())
        if frame and frame.text and frame.inUse then
            self:StyleText(frame.text)
        end
    end
end

-------------------------------------------------
-- Bubble skinning
-------------------------------------------------
local function SkinFrame(frame)
    -- Remove all textures (background, borders, tails)
    for i = 1, select("#", frame:GetRegions()) do
        local region = select(i, frame:GetRegions())
        if region and region:GetObjectType() == "Texture" then
            region:SetTexture(nil)
        end
    end

    -- Find the FontString
    for i = 1, select("#", frame:GetRegions()) do
        local region = select(i, frame:GetRegions())
        if region and region:GetObjectType() == "FontString" then
            frame.text = region
            break
        end
    end

    if frame.text then
        NoBubbles:StyleText(frame.text)
    end

    frame.inUse = true
    frame:HookScript("OnHide", function() frame.inUse = false end)
end

local function UpdateFrame(frame)
    if not frame.text then
        SkinFrame(frame)
    else
        NoBubbles:StyleText(frame.text)
    end
end

local function FindFrame(msg)
    for i = 1, WorldFrame:GetNumChildren() do
        local frame = select(i, WorldFrame:GetChildren())
        if frame and not frame:GetName() and not frame.inUse then
            for j = 1, select("#", frame:GetRegions()) do
                local region = select(j, frame:GetRegions())
                if region and region:GetObjectType() == "FontString" and region:GetText() == msg then
                    return frame
                end
            end
        end
    end
end

-------------------------------------------------
-- Chat events to detect bubbles
-------------------------------------------------
local events = {
    CHAT_MSG_SAY = true,
    CHAT_MSG_YELL = true,
    CHAT_MSG_PARTY = true,
    CHAT_MSG_PARTY_LEADER = true,
    CHAT_MSG_MONSTER_SAY = true,
    CHAT_MSG_MONSTER_YELL = true,
    CHAT_MSG_MONSTER_PARTY = true,
}

local evtFrame

-------------------------------------------------
-- Ace3 lifecycle
-------------------------------------------------
function NoBubbles:OnInitialize()
    -- Ace libs
    local AceConfig       = LibStub("AceConfig-3.0")
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    local AceDB           = LibStub("AceDB-3.0")
    local AceReg          = LibStub("AceConfigRegistry-3.0")

    -- Database
    self.db = AceDB:New("NoBubblesDB", defaults)


    -- Options table
    local options = {
        type = "group",
        name = "NoBubbles",
        args = {
            header = { type="header", name="NoBubbles Settings", order=0 },
            fontSize = {
                type = "range", name = "Font Size",
                min = 8, max = 32, step = 1,
                get = function() return NoBubbles.db.profile.fontSize end,
                set = function(_, v)
                    NoBubbles.db.profile.fontSize = v
                    NoBubbles:ApplySettings()
                    AceReg:NotifyChange("NoBubbles")
                end,
                order = 1,
            },
            font = {
                type = "select", name = "Font Face",
                values = fontValues(),
                get = function() return NoBubbles.db.profile.font end,
                set = function(_, v)
                    NoBubbles.db.profile.font = v
                    NoBubbles:ApplySettings()
                    AceReg:NotifyChange("NoBubbles")
                end,
                order = 2,
            },
            flags = {
                type = "select", name = "Outline",
                values = FLAG_LABELS,
                get = function() return NoBubbles.db.profile.flags end,
                set = function(_, v)
                    NoBubbles.db.profile.flags = v
                    NoBubbles:ApplySettings()
                    AceReg:NotifyChange("NoBubbles")
                end,
                order = 3,
            },
            color = {
                type = "color", name = "Text Color", hasAlpha = false,
                get = function()
                    local c = NoBubbles.db.profile.color
                    return c[1], c[2], c[3]
                end,
                set = function(_, r, g, b)
                    NoBubbles.db.profile.color = {r, g, b}
                    NoBubbles:ApplySettings()
                    AceReg:NotifyChange("NoBubbles")
                end,
                order = 4,
            },
        },
    }

    AceConfig:RegisterOptionsTable("NoBubbles", options)
    AceConfigDialog:AddToBlizOptions("NoBubbles", "NoBubbles")

    -- Slash commands
    self:RegisterChatCommand("nb", "OpenConfig")
    self:RegisterChatCommand("nobubbles", "OpenConfig")
end

function NoBubbles:OnEnable()
    -- Chat event listener
    evtFrame = evtFrame or CreateFrame("Frame")
    for event in pairs(events) do
        evtFrame:RegisterEvent(event)
    end
    evtFrame:SetScript("OnEvent", function(self, event, msg)
        if GetCVarBool("chatBubbles") or GetCVarBool("chatBubblesParty") then
            self.elapsed = 0
            self:SetScript("OnUpdate", function(self, elapsed)
                self.elapsed = self.elapsed + elapsed
                local frame = FindFrame(msg)
                if frame or self.elapsed > 0.3 then
                    self:SetScript("OnUpdate", nil)
                    if frame then UpdateFrame(frame) end
                end
            end)
        end
    end)

    print("|cFF33FF99NoBubbles|r loaded - type /nb for options.")
end

-------------------------------------------------
-- Open config panel
-------------------------------------------------
function NoBubbles:OpenConfig()
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    AceConfigDialog:Open("NoBubbles")

    -- Blizzard fallback (sometimes AceConfigDialog doesn't focus properly)
    if InterfaceOptionsFrame and InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame:Show()
        InterfaceOptionsFrame_OpenToCategory("NoBubbles")
        InterfaceOptionsFrame_OpenToCategory("NoBubbles") -- twice due to Blizzard bug
    end
end
