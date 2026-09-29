local ADDON, ns = ...

local controls = {}
local ddCount = 0

local function Track(w) controls[#controls + 1] = w; return w end

function ns.RefreshOptions()
    for _, w in ipairs(controls) do if w.Refresh then w:Refresh() end end
end

------------------------------------------------------------------------
-- Widgets
------------------------------------------------------------------------
local function Check(parent, label, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    local fs = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0); fs:SetText(label)
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    cb.Refresh = function(self) self:SetChecked(get()) end
    return Track(cb)
end

local function Slider(parent, label, minV, maxV, step, get, set)
    local s = CreateFrame("Slider", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    s:SetOrientation("HORIZONTAL"); s:SetSize(200, 16)
    s:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    s:SetMinMaxValues(minV, maxV); s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end

    s.label = s:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    s.label:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 3)

    s:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / step + 0.5) * step
        self.label:SetText(label .. ": " .. v)
        if not self.updating and v ~= get() then set(v) end
    end)
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(self, d) self:SetValue(self:GetValue() + d * step) end)
    s.Refresh = function(self)
        self.updating = true
        self:SetValue(get()); self.label:SetText(label .. ": " .. get())
        self.updating = false
    end
    return Track(s)
end

local function Dropdown(parent, label, width, getList, get, set)
    ddCount = ddCount + 1
    local dd = CreateFrame("Frame", "RaidFrameTextDD" .. ddCount, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dd, width)
    local fs = dd:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fs:SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 18, 2); fs:SetText(label)
    UIDropDownMenu_Initialize(dd, function(_, level)
        for _, v in ipairs(getList()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.value, info.checked = v, v, (get() == v)
            info.func = function() set(v); UIDropDownMenu_SetText(dd, v) end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    dd.Refresh = function(self) UIDropDownMenu_SetText(self, get()) end
    return Track(dd)
end

local function OpenColor(r, g, b, cb)
    local function apply() local nr, ng, nb = ColorPickerFrame:GetColorRGB(); cb(nr, ng, nb) end
    local function cancel() cb(r, g, b) end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = apply, cancelFunc = cancel })
    else
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.func, ColorPickerFrame.cancelFunc = apply, cancel
        ColorPickerFrame.previousValues = { r, g, b }
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide(); ColorPickerFrame:Show()
    end
end

local function Swatch(parent, label, get, set)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(18, 18)
    local border = b:CreateTexture(nil, "BACKGROUND"); border:SetAllPoints(); border:SetColorTexture(1, 1, 1)
    local tex = b:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", 1, -1); tex:SetPoint("BOTTOMRIGHT", -1, 1)
    local fs = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("LEFT", b, "RIGHT", 6, 0); fs:SetText(label)
    b.Refresh = function() local c = get(); tex:SetColorTexture(c[1], c[2], c[3]) end
    b:SetScript("OnClick", function()
        local c = get()
        OpenColor(c[1], c[2], c[3], function(r, g, bb) set({ r, g, bb }); b.Refresh() end)
    end)
    return Track(b)
end

------------------------------------------------------------------------
-- Column builder
------------------------------------------------------------------------
local function BuildColumn(parent, key, title, x, top)
    local y = top
    local function place(w, h, dx) w:SetPoint("TOPLEFT", parent, "TOPLEFT", x + (dx or 0), y); y = y - h end
    local function cfg() return ns.db[key] end
    local function get(f) return function() return cfg()[f] end end
    local function set(f) return function(v) cfg()[f] = v; ns.ApplyAll() end end
    local function list(t) return function() return t end end

    local hdr = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    hdr:SetText(title); place(hdr, 28)

    place(Check(parent, "Enabled", get("enabled"), function(v)
        cfg().enabled = v; ns.ApplyAll()
        if not v then print("|cff33ff99RaidFrameText|r: /reload to restore Blizzard's " .. title:lower() .. " layout.") end
    end), 44)

    place(Dropdown(parent, "Font", 160, ns.FontList, get("font"), set("font")), 50, -16)
    place(Dropdown(parent, "Outline", 160, list(ns.OUTLINES), get("outline"), set("outline")), 50, -16)
    place(Slider(parent, "Size", 6, 32, 1, get("size"), set("size")), 30)
    place(Check(parent, "Shadow", get("shadow"), set("shadow")), 44)
    place(Dropdown(parent, "Anchor", 160, list(ns.ANCHORS), get("anchor"), set("anchor")), 50, -16)
    place(Dropdown(parent, "Justify", 160, list(ns.JUSTIFY), get("justify"), set("justify")), 44, -16)
    place(Slider(parent, "X offset", -60, 60, 1, get("x"), set("x")), 40)
    place(Slider(parent, "Y offset", -60, 60, 1, get("y"), set("y")), 40)
    place(Slider(parent, "Width padding", 0, 60, 1, get("widthPad"), set("widthPad")), 30)

    if key == "name" then
        place(Check(parent, "Class color", get("classColor"), set("classColor")), 28)
        place(Swatch(parent, "Color (non-class)", get("color"), set("color")), 28, 4)
        place(Check(parent, "Strip realm", get("stripRealm"), set("stripRealm")), 44)
        place(Slider(parent, "Max characters (0 = off)", 0, 24, 1, get("maxChars"), set("maxChars")), 30)
    end
    return y
end

------------------------------------------------------------------------
-- Panel
------------------------------------------------------------------------
local category, panel

function ns.BuildOptions()
    if panel then return end
    panel = CreateFrame("Frame")
    panel.name = "RaidFrameText"

    local scroll = CreateFrame("ScrollFrame", "RaidFrameTextScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -4); scroll:SetPoint("BOTTOMRIGHT", -28, 4)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(600, 800)
    scroll:SetScrollChild(content)

    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 12, -12); title:SetText("RaidFrameText")

    local reset = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    reset:SetSize(120, 22); reset:SetPoint("TOPRIGHT", -12, -12); reset:SetText("Reset defaults")
    reset:SetScript("OnClick", function()
        ns.ResetDB(); ns.ApplyAll(); ns.RefreshOptions()
    end)

    local h1 = BuildColumn(content, "name", "Player Name", 16, -56)
    local h2 = BuildColumn(content, "status", "Status Text", 316, -56)
    content:SetHeight(-math.min(h1, h2) + 20)

    panel:SetScript("OnShow", ns.RefreshOptions)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

function ns.OpenOptions()
    if category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end
