local ADDON, ns = ...

------------------------------------------------------------------------
-- Defaults / constants
------------------------------------------------------------------------
ns.DEFAULTS = {
    name = {
        enabled = true,
        font = "Friz Quadrata", size = 11, outline = "NONE", shadow = true,
        anchor = "TOPLEFT", x = 3, y = -3, justify = "AUTO", widthPad = 6,
        classColor = true, color = { 1, 1, 1 },
        stripRealm = true, maxChars = 0,
    },
    status = {
        enabled = true,
        font = "Friz Quadrata", size = 10, outline = "NONE", shadow = true,
        anchor = "BOTTOM", x = 0, y = 3, justify = "AUTO", widthPad = 6,
    },
}

ns.FONTS = {
    { "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
    { "Arial Narrow",  "Fonts\\ARIALN.TTF" },
    { "Morpheus",      "Fonts\\MORPHEUS.TTF" },
    { "Skurri",        "Fonts\\SKURRI.TTF" },
}
ns.OUTLINES = { "NONE", "OUTLINE", "THICKOUTLINE", "MONOCHROME" }
ns.ANCHORS  = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
ns.JUSTIFY  = { "AUTO", "LEFT", "CENTER", "RIGHT" }

local function LSM() return LibStub and LibStub("LibSharedMedia-3.0", true) end

function ns.FontList()
    local list, seen = {}, {}
    for _, f in ipairs(ns.FONTS) do list[#list + 1] = f[1]; seen[f[1]] = true end
    local lsm = LSM()
    if lsm then
        for _, n in ipairs(lsm:List("font")) do
            if not seen[n] then list[#list + 1] = n; seen[n] = true end
        end
    end
    return list
end

function ns.FontPath(name)
    for _, f in ipairs(ns.FONTS) do if f[1] == name then return f[2] end end
    local lsm = LSM()
    return (lsm and lsm:Fetch("font", name, true)) or STANDARD_TEXT_FONT
end

local function Merge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            Merge(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
local known      = setmetatable({}, { __mode = "k" })
local sizeHooked = setmetatable({}, { __mode = "k" })

local function IsTarget(frame)
    if type(frame) ~= "table" or not frame.GetName then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    local n = frame:GetName()
    return n ~= nil and (n:find("^CompactRaid") or n:find("^CompactParty")) ~= nil
end

local function Utf8Sub(s, n)
    local count, i, len = 0, 1, #s
    while i <= len do
        count = count + 1
        if count > n then return s:sub(1, i - 1) end
        local c = s:byte(i)
        i = i + ((c >= 240 and 4) or (c >= 224 and 3) or (c >= 192 and 2) or 1)
    end
    return s
end

local function Justify(cfg)
    if cfg.justify ~= "AUTO" then return cfg.justify end
    if cfg.anchor:find("LEFT") then return "LEFT" end
    if cfg.anchor:find("RIGHT") then return "RIGHT" end
    return "CENTER"
end

local function StyleText(frame, fs, cfg)
    local flags = (cfg.outline == "NONE") and "" or cfg.outline
    fs:SetFont(ns.FontPath(cfg.font), cfg.size, flags)
    if not fs:GetFont() then fs:SetFont(STANDARD_TEXT_FONT, cfg.size, flags) end

    if cfg.shadow then
        fs:SetShadowColor(0, 0, 0, 1); fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowOffset(0, 0)
    end

    fs:ClearAllPoints()
    fs:SetPoint(cfg.anchor, frame, cfg.anchor, cfg.x, cfg.y)
    local w = frame:GetWidth() - cfg.widthPad
    if w > 1 then fs:SetWidth(w) end
    fs:SetJustifyH(Justify(cfg))
    fs:SetWordWrap(false)
    if fs.SetMaxLines then fs:SetMaxLines(1) end
end

------------------------------------------------------------------------
-- Core
------------------------------------------------------------------------
local function Layout(frame)
    if not ns.db or not IsTarget(frame) then return end
    known[frame] = true
    if not sizeHooked[frame] then
        sizeHooked[frame] = true
        frame:HookScript("OnSizeChanged", Layout)
    end
    if ns.db.name.enabled and frame.name then StyleText(frame, frame.name, ns.db.name) end
    if ns.db.status.enabled and frame.statusText then StyleText(frame, frame.statusText, ns.db.status) end
end

local function UpdateName(frame)
    if not ns.db or not IsTarget(frame) then return end
    if not known[frame] then Layout(frame) end

    local cfg, fs, unit = ns.db.name, frame.name, frame.unit
    if not cfg.enabled or not fs or not unit or not UnitExists(unit) then return end

    if cfg.stripRealm or cfg.maxChars > 0 then
        local text = GetUnitName(unit, not cfg.stripRealm)
        if text then
            if cfg.maxChars > 0 then text = Utf8Sub(text, cfg.maxChars) end
            fs:SetText(text)
        end
    end

    local r, g, b = cfg.color[1], cfg.color[2], cfg.color[3]
    if cfg.classColor and UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        local c = class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
        if c then r, g, b = c.r, c.g, c.b end
    end
    fs:SetTextColor(r, g, b)
end

local function Scan()
    for i = 1, 40 do Layout(_G["CompactRaidFrame" .. i]) end
    for g = 1, 8 do for m = 1, 5 do Layout(_G["CompactRaidGroup" .. g .. "Member" .. m]) end end
    for i = 1, 5 do
        Layout(_G["CompactPartyFrameMember" .. i])
        Layout(_G["CompactPartyFramePet" .. i])
    end
end

function ns.ApplyAll()
    if not ns.db then return end
    Scan()
    for frame in pairs(known) do
        Layout(frame)
        UpdateName(frame)
    end
end

local hooked = {}
local function InstallHooks()
    local map = {
        DefaultCompactUnitFrameSetup = Layout,
        DefaultCompactMiniFrameSetup = Layout,
        CompactUnitFrame_UpdateName  = UpdateName,
    }
    for fn, handler in pairs(map) do
        if not hooked[fn] and type(_G[fn]) == "function" then
            hooksecurefunc(fn, handler)
            hooked[fn] = true
        end
    end
end
InstallHooks()

function ns.ResetDB()
    RaidFrameTextDB = Merge({}, ns.DEFAULTS)
    ns.db = RaidFrameTextDB
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        InstallHooks()
        if arg1 == ADDON then
            RaidFrameTextDB = Merge(RaidFrameTextDB or {}, ns.DEFAULTS)
            ns.db = RaidFrameTextDB
            if ns.BuildOptions then ns.BuildOptions() end
        end
    else
        C_Timer.After(0, ns.ApplyAll)
    end
end)

------------------------------------------------------------------------
-- Slash
------------------------------------------------------------------------
SLASH_RAIDFRAMETEXT1 = "/rft"
SlashCmdList.RAIDFRAMETEXT = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "reset" then
        ns.ResetDB(); ns.ApplyAll()
        if ns.RefreshOptions then ns.RefreshOptions() end
        print("|cff33ff99RaidFrameText|r: settings reset. /reload to fully restore Blizzard layout.")
    elseif msg == "apply" then
        ns.ApplyAll()
    else
        if ns.OpenOptions then ns.OpenOptions() end
    end
end
