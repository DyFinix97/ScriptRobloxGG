--[[
    ╔══════════════════════════════════════╗
    ║        CrimsonX Hub v3.1             ║
    ║  Violence District • Delta Mobile    ║
    ║  No UI Library — Pure ScreenGui      ║
    ╚══════════════════════════════════════╝
]]

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService          = game:GetService("GuiService")
local CoreGui             = game:GetService("CoreGui")
local TweenService        = game:GetService("TweenService")
local UIS                 = game:GetService("UserInputService")
local LocalPlayer         = Players.LocalPlayer

print("[CrimsonX] Script dimulai...")

-- =============================================
-- CONFIG
-- =============================================
_G.CX = _G.CX or {
    Toggles = {
        AutoFarm  = false,
        AutoFix   = false,
        EspPlayer = false,
        EspGen    = false,
        EspHook   = false,
        AimLock   = false,
    },
    Aimbot = {
        Target  = "Killer",
        AimPart = "HumanoidRootPart",
        FOV     = 300,
        Predict = 0.04,
    }
}
local T = _G.CX.Toggles

local FinishedGenerators = {}
local ESPObjects         = {}
local HeartbeatConn      = nil
local LastTeleport       = 0
local TELE_CD            = 1.2
local NeedleVelocity     = 0
local LastNeedleAngle    = nil
local LastNeedleTime     = nil

-- =============================================
-- WARNA
-- =============================================
local CLR = {
    BG       = Color3.fromRGB(15,  15,  20 ),
    HEADER   = Color3.fromRGB(180, 30,  30 ),
    BTN_ON   = Color3.fromRGB(180, 30,  30 ),
    BTN_OFF  = Color3.fromRGB(40,  40,  50 ),
    TEXT     = Color3.fromRGB(255, 255, 255),
    SUBTEXT  = Color3.fromRGB(160, 160, 170),
    TAB_ACT  = Color3.fromRGB(180, 30,  30 ),
    TAB_IDLE = Color3.fromRGB(30,  30,  40 ),
    SEP      = Color3.fromRGB(50,  50,  65 ),
}

-- =============================================
-- BERSIHKAN INSTANCE LAMA
-- =============================================
local oldGui = CoreGui:FindFirstChild("CrimsonXHub")
if oldGui then oldGui:Destroy() end

-- =============================================
-- BUAT SCREENGUI
-- =============================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name             = "CrimsonXHub"
ScreenGui.ResetOnSpawn     = false
ScreenGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder     = 999
ScreenGui.IgnoreGuiInset   = true
ScreenGui.Parent           = CoreGui

-- Window utama
local Window = Instance.new("Frame")
Window.Name               = "Window"
Window.Size               = UDim2.new(0, 310, 0, 430)
Window.Position           = UDim2.new(0.5, -155, 0.5, -215)
Window.BackgroundColor3   = CLR.BG
Window.BorderSizePixel    = 0
Window.Active             = true
Window.Draggable          = true
Window.Parent             = ScreenGui
Instance.new("UICorner", Window).CornerRadius = UDim.new(0, 10)

-- Stroke border
local Stroke = Instance.new("UIStroke", Window)
Stroke.Color     = CLR.HEADER
Stroke.Thickness = 1.5
Stroke.Transparency = 0.5

-- Header
local Header = Instance.new("Frame")
Header.Name               = "Header"
Header.Size               = UDim2.new(1, 0, 0, 44)
Header.BackgroundColor3   = CLR.HEADER
Header.BorderSizePixel    = 0
Header.ZIndex             = 2
Header.Parent             = Window
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

-- Fix sudut bawah header agar tidak ada gap
local HeaderFix = Instance.new("Frame")
HeaderFix.Size             = UDim2.new(1, 0, 0, 10)
HeaderFix.Position         = UDim2.new(0, 0, 1, -10)
HeaderFix.BackgroundColor3 = CLR.HEADER
HeaderFix.BorderSizePixel  = 0
HeaderFix.ZIndex           = 2
HeaderFix.Parent           = Header

local Title = Instance.new("TextLabel")
Title.Size                  = UDim2.new(1, -50, 1, 0)
Title.Position              = UDim2.new(0, 14, 0, 0)
Title.BackgroundTransparency = 1
Title.Text                  = "💀 CrimsonX Hub"
Title.TextColor3            = CLR.TEXT
Title.Font                  = Enum.Font.GothamBold
Title.TextSize              = 15
Title.TextXAlignment        = Enum.TextXAlignment.Left
Title.ZIndex                = 3
Title.Parent                = Header

-- Tombol minimize
local MinBtn = Instance.new("TextButton")
MinBtn.Size                 = UDim2.new(0, 30, 0, 30)
MinBtn.Position             = UDim2.new(1, -38, 0.5, -15)
MinBtn.BackgroundColor3     = Color3.fromRGB(60, 60, 75)
MinBtn.Text                 = "—"
MinBtn.TextColor3           = CLR.TEXT
MinBtn.Font                 = Enum.Font.GothamBold
MinBtn.TextSize             = 14
MinBtn.BorderSizePixel      = 0
MinBtn.ZIndex               = 4
MinBtn.Parent               = Header
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

-- Content area
local Content = Instance.new("Frame")
Content.Size                = UDim2.new(1, 0, 1, -44)
Content.Position            = UDim2.new(0, 0, 0, 44)
Content.BackgroundTransparency = 1
Content.ClipsDescendants    = true
Content.Parent              = Window

-- Tab bar
local TabBar = Instance.new("Frame")
TabBar.Size                 = UDim2.new(1, 0, 0, 38)
TabBar.BackgroundColor3     = Color3.fromRGB(20, 20, 28)
TabBar.BorderSizePixel      = 0
TabBar.Parent               = Content
local TabBarLayout = Instance.new("UIListLayout")
TabBarLayout.FillDirection  = Enum.FillDirection.Horizontal
TabBarLayout.Parent         = TabBar

-- Scroll area konten
local TabContent = Instance.new("ScrollingFrame")
TabContent.Size              = UDim2.new(1, 0, 1, -38)
TabContent.Position          = UDim2.new(0, 0, 0, 38)
TabContent.BackgroundTransparency = 1
TabContent.BorderSizePixel   = 0
TabContent.ScrollBarThickness = 3
TabContent.ScrollBarImageColor3 = CLR.HEADER
TabContent.CanvasSize        = UDim2.new(0, 0, 0, 0)
TabContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
TabContent.Parent            = Content
local TabContentLayout = Instance.new("UIListLayout")
TabContentLayout.Padding     = UDim.new(0, 0)
TabContentLayout.Parent      = TabContent
local TCP = Instance.new("UIPadding")
TCP.PaddingTop    = UDim.new(0, 10)
TCP.PaddingBottom = UDim.new(0, 14)
TCP.PaddingLeft   = UDim.new(0, 10)
TCP.PaddingRight  = UDim.new(0, 10)
TCP.Parent        = TabContent

-- =============================================
-- TAB SYSTEM
-- =============================================
local Tabs    = {}
local TabBtns = {}

local function SelectTab(name)
    for tName, frame in pairs(Tabs) do
        frame.Visible = (tName == name)
    end
    for tName, btn in pairs(TabBtns) do
        btn.BackgroundColor3 = (tName == name) and CLR.TAB_ACT or CLR.TAB_IDLE
        btn.TextColor3       = (tName == name) and CLR.TEXT or CLR.SUBTEXT
        btn.Font             = (tName == name) and Enum.Font.GothamBold or Enum.Font.Gotham
    end
end

local function AddTab(name, icon)
    local btn = Instance.new("TextButton")
    btn.Size                = UDim2.new(0.25, 0, 1, 0)
    btn.BackgroundColor3    = CLR.TAB_IDLE
    btn.Text                = icon .. "\n" .. name
    btn.TextColor3          = CLR.SUBTEXT
    btn.Font                = Enum.Font.Gotham
    btn.TextSize            = 9
    btn.BorderSizePixel     = 0
    btn.ZIndex              = 2
    btn.AutoButtonColor     = false
    btn.Parent              = TabBar

    local frame = Instance.new("Frame")
    frame.Size              = UDim2.new(1, 0, 0, 0)
    frame.BackgroundTransparency = 1
    frame.AutomaticSize     = Enum.AutomaticSize.Y
    frame.Visible           = false
    frame.Parent            = TabContent
    local fl = Instance.new("UIListLayout")
    fl.Padding              = UDim.new(0, 6)
    fl.Parent               = frame

    Tabs[name]    = frame
    TabBtns[name] = btn
    btn.MouseButton1Click:Connect(function() SelectTab(name) end)
    return frame
end

-- =============================================
-- WIDGET BUILDERS
-- =============================================
local function MakeSep(parent)
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(1, 0, 0, 1)
    f.BackgroundColor3 = CLR.SEP
    f.BorderSizePixel  = 0
    f.Parent           = parent
end

local function MakeLabel(parent, text)
    local l = Instance.new("TextLabel")
    l.Size               = UDim2.new(1, 0, 0, 20)
    l.BackgroundTransparency = 1
    l.Text               = "  " .. text
    l.TextColor3         = CLR.SUBTEXT
    l.Font               = Enum.Font.Gotham
    l.TextSize           = 11
    l.TextXAlignment     = Enum.TextXAlignment.Left
    l.Parent             = parent
    return l
end

local function MakeSection(parent, text)
    local l = Instance.new("TextLabel")
    l.Size               = UDim2.new(1, 0, 0, 26)
    l.BackgroundTransparency = 1
    l.Text               = "  ── " .. text
    l.TextColor3         = CLR.HEADER
    l.Font               = Enum.Font.GothamBold
    l.TextSize           = 12
    l.TextXAlignment     = Enum.TextXAlignment.Left
    l.Parent             = parent
    return l
end

local function MakeToggle(parent, text, callback)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 38)
    row.BackgroundColor3 = Color3.fromRGB(24, 24, 33)
    row.BorderSizePixel  = 0
    row.Parent           = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size               = UDim2.new(1, -58, 1, 0)
    lbl.Position           = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text               = text
    lbl.TextColor3         = CLR.TEXT
    lbl.Font               = Enum.Font.Gotham
    lbl.TextSize           = 12
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.TextWrapped        = true
    lbl.Parent             = row

    -- Pill toggle
    local pill = Instance.new("Frame")
    pill.Size              = UDim2.new(0, 42, 0, 24)
    pill.Position          = UDim2.new(1, -50, 0.5, -12)
    pill.BackgroundColor3  = CLR.BTN_OFF
    pill.BorderSizePixel   = 0
    pill.Parent            = row
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

    local dot = Instance.new("Frame")
    dot.Size               = UDim2.new(0, 18, 0, 18)
    dot.Position           = UDim2.new(0, 3, 0.5, -9)
    dot.BackgroundColor3   = Color3.new(1, 1, 1)
    dot.BorderSizePixel    = 0
    dot.Parent             = pill
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local state = false
    local function toggle()
        state = not state
        local goalPos = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        local goalClr = state and CLR.BTN_ON or CLR.BTN_OFF
        TweenService:Create(dot,  TweenInfo.new(0.15), { Position = goalPos }):Play()
        TweenService:Create(pill, TweenInfo.new(0.15), { BackgroundColor3 = goalClr }):Play()
        callback(state)
    end

    row.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            toggle()
        end
    end)
    return row
end

-- Dropdown — muncul sebagai popup di atas ScreenGui agar tidak terpotong ScrollingFrame
local function MakeDropdown(parent, labelText, options, default, callback)
    local wrap = Instance.new("Frame")
    wrap.Size              = UDim2.new(1, 0, 0, 62)
    wrap.BackgroundTransparency = 1
    wrap.Parent            = parent
    local wl = Instance.new("UIListLayout")
    wl.Padding             = UDim.new(0, 4)
    wl.Parent              = wrap

    local topLbl = Instance.new("TextLabel")
    topLbl.Size              = UDim2.new(1, 0, 0, 20)
    topLbl.BackgroundTransparency = 1
    topLbl.Text              = "  " .. labelText
    topLbl.TextColor3        = CLR.SUBTEXT
    topLbl.Font              = Enum.Font.Gotham
    topLbl.TextSize          = 11
    topLbl.TextXAlignment    = Enum.TextXAlignment.Left
    topLbl.Parent            = wrap

    local selBtn = Instance.new("TextButton")
    selBtn.Size              = UDim2.new(1, 0, 0, 34)
    selBtn.BackgroundColor3  = Color3.fromRGB(28, 28, 42)
    selBtn.Text              = "  ▾  " .. (default or options[1])
    selBtn.TextColor3        = CLR.TEXT
    selBtn.Font              = Enum.Font.Gotham
    selBtn.TextSize          = 12
    selBtn.TextXAlignment    = Enum.TextXAlignment.Left
    selBtn.BorderSizePixel   = 0
    selBtn.AutoButtonColor   = false
    selBtn.Parent            = wrap
    Instance.new("UICorner", selBtn).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", selBtn).Color = CLR.SEP

    -- Popup list (parent ke ScreenGui biar tidak terpotong)
    local popup = Instance.new("Frame")
    popup.Size              = UDim2.new(0, 1, 0, #options * 34)
    popup.BackgroundColor3  = Color3.fromRGB(22, 22, 34)
    popup.BorderSizePixel   = 0
    popup.ZIndex            = 50
    popup.Visible           = false
    popup.Parent            = ScreenGui
    Instance.new("UICorner", popup).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", popup).Color = CLR.SEP
    local pl = Instance.new("UIListLayout")
    pl.Parent              = popup

    callback(default or options[1])

    for _, opt in ipairs(options) do
        local item = Instance.new("TextButton")
        item.Size              = UDim2.new(1, 0, 0, 34)
        item.BackgroundTransparency = 1
        item.Text              = "  " .. opt
        item.TextColor3        = CLR.TEXT
        item.Font              = Enum.Font.Gotham
        item.TextSize          = 12
        item.TextXAlignment    = Enum.TextXAlignment.Left
        item.ZIndex            = 51
        item.AutoButtonColor   = false
        item.Parent            = popup

        item.MouseEnter:Connect(function()
            TweenService:Create(item, TweenInfo.new(0.1), { BackgroundTransparency = 0.7 }):Play()
        end)
        item.MouseLeave:Connect(function()
            TweenService:Create(item, TweenInfo.new(0.1), { BackgroundTransparency = 1 }):Play()
        end)
        item.MouseButton1Click:Connect(function()
            selBtn.Text   = "  ▾  " .. opt
            popup.Visible = false
            callback(opt)
        end)
    end

    selBtn.MouseButton1Click:Connect(function()
        -- Hitung posisi absolut selBtn untuk tempatkan popup di bawahnya
        local absPos  = selBtn.AbsolutePosition
        local absSize = selBtn.AbsoluteSize
        popup.Position = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 4)
        popup.Size     = UDim2.new(0, absSize.X, 0, #options * 34)
        popup.Visible  = not popup.Visible
    end)

    -- Tutup popup kalau klik di luar
    UIS.InputBegan:Connect(function(i)
        if popup.Visible then
            if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
                task.wait(0.05)
                local pos = i.Position
                local p   = popup.AbsolutePosition
                local s   = popup.AbsoluteSize
                if pos.X < p.X or pos.X > p.X + s.X or pos.Y < p.Y or pos.Y > p.Y + s.Y then
                    popup.Visible = false
                end
            end
        end
    end)

    return wrap
end

local function MakeSlider(parent, labelText, min, max, default, callback)
    local wrap = Instance.new("Frame")
    wrap.Size              = UDim2.new(1, 0, 0, 58)
    wrap.BackgroundTransparency = 1
    wrap.Parent            = parent
    local wl = Instance.new("UIListLayout")
    wl.Padding             = UDim.new(0, 4)
    wl.Parent              = wrap

    local topRow = Instance.new("Frame")
    topRow.Size            = UDim2.new(1, 0, 0, 20)
    topRow.BackgroundTransparency = 1
    topRow.Parent          = wrap

    local lbl = Instance.new("TextLabel")
    lbl.Size               = UDim2.new(0.65, 0, 1, 0)
    lbl.Position           = UDim2.new(0, 2, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text               = labelText
    lbl.TextColor3         = CLR.SUBTEXT
    lbl.Font               = Enum.Font.Gotham
    lbl.TextSize           = 11
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.Parent             = topRow

    local valLbl = Instance.new("TextLabel")
    valLbl.Size            = UDim2.new(0.35, -4, 1, 0)
    valLbl.Position        = UDim2.new(0.65, 0, 0, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Text            = tostring(default)
    valLbl.TextColor3      = CLR.HEADER
    valLbl.Font            = Enum.Font.GothamBold
    valLbl.TextSize        = 11
    valLbl.TextXAlignment  = Enum.TextXAlignment.Right
    valLbl.Parent          = topRow

    local trackWrap = Instance.new("Frame")
    trackWrap.Size         = UDim2.new(1, 0, 0, 30)
    trackWrap.BackgroundTransparency = 1
    trackWrap.Parent       = wrap

    local track = Instance.new("Frame")
    track.Size             = UDim2.new(1, 0, 0, 8)
    track.Position         = UDim2.new(0, 0, 0.5, -4)
    track.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    track.BorderSizePixel  = 0
    track.Parent           = trackWrap
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local initRatio = (default - min) / math.max(max - min, 0.001)
    local fill = Instance.new("Frame")
    fill.Size              = UDim2.new(initRatio, 0, 1, 0)
    fill.BackgroundColor3  = CLR.HEADER
    fill.BorderSizePixel   = 0
    fill.Parent            = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size              = UDim2.new(0, 16, 0, 16)
    knob.Position          = UDim2.new(initRatio, -8, 0.5, -8)
    knob.BackgroundColor3  = Color3.new(1, 1, 1)
    knob.BorderSizePixel   = 0
    knob.Parent            = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local function update(x)
        local trackAbs = track.AbsolutePosition.X
        local trackW   = track.AbsoluteSize.X
        local ratio    = math.clamp((x - trackAbs) / trackW, 0, 1)
        local isFloat  = (max - min) <= 1
        local val = isFloat
            and (math.floor((min + ratio * (max - min)) * 100 + 0.5) / 100)
            or  math.round(min + ratio * (max - min))
        fill.Size      = UDim2.new(ratio, 0, 1, 0)
        knob.Position  = UDim2.new(ratio, -8, 0.5, -8)
        valLbl.Text    = tostring(val)
        callback(val)
    end

    local dragging = false
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; update(i.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            update(i.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    callback(default)
    return wrap
end

-- =============================================
-- MINIMIZE LOGIC
-- =============================================
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Content.Visible  = not minimized
    Window.Size      = minimized and UDim2.new(0, 310, 0, 44) or UDim2.new(0, 310, 0, 430)
    MinBtn.Text      = minimized and "+" or "—"
end)

-- =============================================
-- BUAT TABS
-- =============================================
local FarmTab = AddTab("Farm",  "🔧")
local EspTab  = AddTab("ESP",   "👁")
local AimTab  = AddTab("Aim",   "🎯")
local InfoTab = AddTab("Info",  "ℹ")

-- =============================================
-- FARM TAB
-- =============================================
MakeSection(FarmTab, "Generator System")
MakeToggle(FarmTab, "Auto Farm Generator", function(v)
    T.AutoFarm = v
    if not v then FinishedGenerators = {} end
end)
MakeSep(FarmTab)
MakeSection(FarmTab, "Skill Check Engine")
MakeToggle(FarmTab, "Auto Perfect Fix  (FPS-Independent)", function(v)
    T.AutoFix = v
    if not v then
        LastNeedleAngle = nil
        LastNeedleTime  = nil
        NeedleVelocity  = 0
        if HeartbeatConn then HeartbeatConn:Disconnect(); HeartbeatConn = nil end
    end
end)
MakeSep(FarmTab)
MakeLabel(FarmTab, "▸ Farm + Fix bisa aktif bersamaan")
MakeLabel(FarmTab, "▸ Setelah semua gen 100% farm berhenti")

-- =============================================
-- ESP TAB
-- =============================================
MakeSection(EspTab, "Player")
MakeToggle(EspTab, "Killer ESP  (merah)", function(v) T.EspPlayer = v end)
MakeToggle(EspTab, "Survivor ESP  (hijau)", function(v) T.EspPlayer = v end)
MakeSep(EspTab)
MakeSection(EspTab, "Object")
MakeToggle(EspTab, "Generator ESP  + Progress %", function(v)
    T.EspGen = v
    if not v then
        for inst, d in pairs(ESPObjects) do
            if inst.Name == "Generator" then
                pcall(function() if d.h then d.h:Destroy() end end)
                pcall(function() if d.b then d.b:Destroy() end end)
                ESPObjects[inst] = nil
            end
        end
    end
end)
MakeToggle(EspTab, "Hook ESP  (orange / merah jika terisi)", function(v)
    T.EspHook = v
    if not v then
        for inst, d in pairs(ESPObjects) do
            if inst.Name == "Hook" then
                pcall(function() if d.h then d.h:Destroy() end end)
                pcall(function() if d.b then d.b:Destroy() end end)
                ESPObjects[inst] = nil
            end
        end
    end
end)

-- =============================================
-- AIM TAB
-- =============================================
MakeSection(AimTab, "Silent Aimbot")
MakeToggle(AimTab, "Enable Aim Lock", function(v) T.AimLock = v end)
MakeSep(AimTab)
MakeDropdown(AimTab, "Target Role", {"Killer", "Survivors"}, "Killer", function(v)
    _G.CX.Aimbot.Target = v
end)
MakeDropdown(AimTab, "Aim Part", {"HumanoidRootPart","Head","Torso","UpperTorso","LowerTorso"}, "HumanoidRootPart", function(v)
    _G.CX.Aimbot.AimPart = v
end)
MakeSep(AimTab)
MakeSlider(AimTab, "FOV Radius", 50, 1000, 300, function(v) _G.CX.Aimbot.FOV = v end)
MakeSlider(AimTab, "Prediction", 0, 0.5, 0.04, function(v) _G.CX.Aimbot.Predict = v end)

-- =============================================
-- INFO TAB
-- =============================================
MakeSection(InfoTab, "CrimsonX Hub v3.1")
MakeLabel(InfoTab, "Game : Violence District")
MakeLabel(InfoTab, "UI   : Pure ScreenGui (no library)")
MakeLabel(InfoTab, "Mode : Delta Mobile Compatible")
MakeLabel(InfoTab, "Fix  : FPS-Independent Heartbeat")
MakeLabel(InfoTab, "")
MakeLabel(InfoTab, "Drag window untuk pindahkan UI")
MakeLabel(InfoTab, "Tombol — untuk minimize")

SelectTab("Farm")
print("[CrimsonX] UI berhasil dimuat!")

-- =============================================
-- ESP FUNCTIONS
-- =============================================
local function MakeESP(inst, adornee, color, label)
    if not adornee or not adornee.Parent then return end
    local d = ESPObjects[inst]
    if d and d.h and d.h.Parent then
        pcall(function()
            d.h.FillColor    = color
            d.h.OutlineColor = color
            if d.b and d.b.Parent then
                local l = d.b:FindFirstChildWhichIsA("TextLabel")
                if l then l.Text = label; l.TextColor3 = color end
            end
        end)
        return
    end

    local h = Instance.new("Highlight")
    h.FillColor           = color
    h.OutlineColor        = color
    h.FillTransparency    = 0.6
    h.OutlineTransparency = 0
    h.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee             = adornee
    h.Parent              = CoreGui

    local bg = Instance.new("BillboardGui")
    bg.AlwaysOnTop  = true
    bg.Size         = UDim2.new(0, 175, 0, 40)
    bg.StudsOffset  = Vector3.new(0, 3.5, 0)
    bg.Adornee      = adornee
    bg.Parent       = CoreGui

    local lbl = Instance.new("TextLabel", bg)
    lbl.Size                   = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = label
    lbl.TextColor3             = color
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextSize               = 11
    lbl.TextStrokeTransparency = 0.4
    lbl.TextWrapped            = true

    ESPObjects[inst] = { h = h, b = bg }
end

local function RemoveESP(inst)
    local d = ESPObjects[inst]
    if not d then return end
    pcall(function() if d.h then d.h:Destroy() end end)
    pcall(function() if d.b then d.b:Destroy() end end)
    ESPObjects[inst] = nil
end

-- =============================================
-- GENERATOR HELPERS
-- =============================================
local function GetGenProgress(gen)
    for _, name in ipairs({"RepairProgress","Progress","Percent","ProgressValue"}) do
        local attr = gen:GetAttribute(name)
        if type(attr) == "number" then return math.clamp(math.floor(attr), 0, 100) end
        local v = gen:FindFirstChild(name)
        if v and (v:IsA("NumberValue") or v:IsA("IntValue")) then
            return math.clamp(math.floor(v.Value), 0, 100)
        end
    end
    return 0
end

local function GetGenPart(gen)
    if gen:IsA("BasePart") then return gen end
    return gen:FindFirstChild("Main")
        or gen:FindFirstChild("HumanoidRootPart")
        or gen:FindFirstChildWhichIsA("BasePart", true)
end

-- =============================================
-- ESP RENDER LOOP
-- =============================================
RunService.RenderStepped:Connect(function()
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    -- Player ESP
    if T.EspPlayer then
        for _, p in pairs(Players:GetPlayers()) do
            if p == LocalPlayer or not p.Character then continue end
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildWhichIsA("Humanoid")
            if not hrp then continue end
            local isKiller = p.Team and p.Team.Name:lower():find("killer")
            local color    = isKiller and Color3.fromRGB(255,60,60) or Color3.fromRGB(60,220,120)
            local hp       = hum and math.floor(hum.Health)         or 0
            local maxHp    = hum and math.max(hum.MaxHealth, 1)     or 100
            local dist     = myHRP and math.floor((hrp.Position - myHRP.Position).Magnitude) or 0
            local role     = isKiller and "KILLER" or "Survivor"
            local lbl      = string.format("%s [%s]\n%d/%dHP  %dm", p.Name, role, hp, maxHp, dist)
            pcall(MakeESP, p.Character, hrp, color, lbl)
        end
    end

    -- Generator ESP
    if T.EspGen then
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj.Name ~= "Generator" then continue end
            local part = GetGenPart(obj)
            if not part then continue end
            local pct   = GetGenProgress(obj)
            local t     = math.clamp(pct / 100, 0, 1)
            local color = Color3.fromRGB(150,0,200):Lerp(Color3.fromRGB(0,200,80), t)
            local dist  = myHRP and math.floor((part.Position - myHRP.Position).Magnitude) or 0
            local lbl   = string.format("Generator  %d%%\n%dm", pct, dist)
            pcall(MakeESP, obj, part, color, lbl)
        end
    end

    -- Hook ESP
    if T.EspHook then
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj.Name ~= "Hook" then continue end
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
            if not part then continue end
            local occ   = obj:GetAttribute("Occupied") or obj:FindFirstChild("Occupied")
            local color = occ and Color3.fromRGB(255,0,0) or Color3.fromRGB(255,165,0)
            local dist  = myHRP and math.floor((part.Position - myHRP.Position).Magnitude) or 0
            local lbl   = (occ and "Hook [TERISI]\n" or "Hook\n") .. dist .. "m"
            pcall(MakeESP, obj, part, color, lbl)
        end
    end
end)

Players.PlayerRemoving:Connect(function(p) if p.Character then RemoveESP(p.Character) end end)
Players.PlayerAdded:Connect(function(p) p.CharacterRemoving:Connect(function(c) RemoveESP(c) end) end)
for _, p in pairs(Players:GetPlayers()) do
    p.CharacterRemoving:Connect(function(c) RemoveESP(c) end)
end

-- =============================================
-- CLICK ENGINE (VIOLENCE DISTRICT)
-- =============================================
local function FindRepairButton()
    -- Metode 1: path spesifik VD
    local mob = LocalPlayer.PlayerGui:FindFirstChild("Survivor-mob", true)
    if mob then
        local c = mob:FindFirstChild("check", true)
        if c and c:IsA("GuiButton") and c.Visible then return c end
        for _, v in pairs(mob:GetDescendants()) do
            if v:IsA("GuiButton") and v.Visible and v.Active ~= false then return v end
        end
    end
    -- Metode 2: cari button orange
    for _, gui in pairs(LocalPlayer.PlayerGui:GetChildren()) do
        if gui.Name == "CrimsonXHub" then continue end
        for _, v in pairs(gui:GetDescendants()) do
            if v:IsA("GuiButton") and v.Visible and v.Active ~= false then
                local r, g, b = v.BackgroundColor3.R, v.BackgroundColor3.G, v.BackgroundColor3.B
                if r > 0.55 and g > 0.25 and b < 0.35 then return v end
            end
        end
    end
    return nil
end

local function ClickButton(btn)
    if not btn then return false end
    if type(firesignal) == "function" then
        pcall(firesignal, btn.MouseButton1Click)
        pcall(firesignal, btn.Activated)
        return true
    end
    if type(getconnections) == "function" then
        pcall(function()
            for _, c in pairs(getconnections(btn.MouseButton1Click)) do pcall(c.Fire, c) end
            for _, c in pairs(getconnections(btn.Activated))         do pcall(c.Fire, c) end
        end)
        return true
    end
    pcall(function()
        local p = btn.AbsolutePosition; local s = btn.AbsoluteSize
        local ins = GuiService:GetGuiInset()
        local cx = p.X + s.X * .5 + ins.X
        local cy = p.Y + s.Y * .5 + ins.Y + 36
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true,  game, 0)
        task.wait(0.015)
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
    end)
    return true
end

local function DoRepair()
    return ClickButton(FindRepairButton())
end

-- =============================================
-- SKILL CHECK ENGINE (FPS-INDEPENDENT)
-- =============================================
local function FindSkillCheck()
    for _, gui in pairs(LocalPlayer.PlayerGui:GetChildren()) do
        if gui.Name == "CrimsonXHub" then continue end
        local check = gui:FindFirstChild("Check", true)
            or gui:FindFirstChild("SkillCheck", true)
            or gui:FindFirstChild("RepairCheck", true)
        if check and check.Visible then
            local needle = check:FindFirstChild("Line")
                or check:FindFirstChild("Needle")
                or check:FindFirstChild("Arrow")
            local goal   = check:FindFirstChild("Goal")
                or check:FindFirstChild("Target")
                or check:FindFirstChild("Zone")
                or check:FindFirstChild("Perfect")
                or check:FindFirstChild("White")
            if needle and goal then return check, needle, goal end
        end
    end
    return nil, nil, nil
end

local function InArc(a, s, e)
    a, s, e = a % 360, s % 360, e % 360
    if s <= e then return a >= s and a <= e
    else           return a >= s or  a <= e end
end

local function OnHeartbeat()
    if not T.AutoFix then return end
    local _, needle, goal = FindSkillCheck()
    if not needle or not goal then return end

    local now = tick()
    local ang = needle.Rotation % 360

    -- Ukur kecepatan angular (derajat/detik)
    if LastNeedleAngle and LastNeedleTime then
        local dt   = now - LastNeedleTime
        local dAng = (ang - LastNeedleAngle + 360) % 360
        if dAng > 180 then dAng = dAng - 360 end
        if dt > 0 then NeedleVelocity = dAng / dt end
    end
    LastNeedleAngle = ang
    LastNeedleTime  = now

    local goalAng = goal.Rotation % 360
    -- Prediksi posisi needle 2 frame ke depan (kompensasi latensi)
    local pred    = (ang + NeedleVelocity * (1 / 60) * 2) % 360
    local s       = (goalAng - 10) % 360
    local e       = (goalAng + 10) % 360

    if InArc(ang, s, e) or InArc(pred, s, e) then
        DoRepair()
        LastNeedleAngle = nil
        LastNeedleTime  = nil
        NeedleVelocity  = 0
        if HeartbeatConn then HeartbeatConn:Disconnect(); HeartbeatConn = nil end
    end
end

task.spawn(function()
    while task.wait(0.05) do
        if T.AutoFix then
            local c, n, g = FindSkillCheck()
            if c and n and g then
                if not HeartbeatConn then
                    HeartbeatConn = RunService.Heartbeat:Connect(OnHeartbeat)
                end
            else
                if HeartbeatConn then HeartbeatConn:Disconnect(); HeartbeatConn = nil end
            end
        else
            if HeartbeatConn then HeartbeatConn:Disconnect(); HeartbeatConn = nil end
        end
    end
end)

-- =============================================
-- AUTO FARM ENGINE
-- =============================================
task.spawn(function()
    while task.wait(0.4) do
        if not T.AutoFarm then continue end
        local char = LocalPlayer.Character; if not char then continue end
        local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then continue end

        local closestPart, closestGen, closestDist = nil, nil, math.huge

        pcall(function()
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj.Name ~= "Generator" then continue end
                local part = GetGenPart(obj)
                if not part or table.find(FinishedGenerators, obj) then continue end
                local pct = GetGenProgress(obj)
                if pct >= 100 then
                    if not table.find(FinishedGenerators, obj) then
                        table.insert(FinishedGenerators, obj)
                    end
                    continue
                end
                local d = (part.Position - hrp.Position).Magnitude
                if d < closestDist then
                    closestDist = d
                    closestPart = part
                    closestGen  = obj
                end
            end
        end)

        if not closestPart then continue end  -- Semua gen selesai

        -- Teleport dengan cooldown anti-jitter
        local now = tick()
        if closestDist > 5 and (now - LastTeleport) >= TELE_CD then
            LastTeleport = now
            pcall(function()
                hrp.CFrame = closestPart.CFrame * CFrame.new(0, 0, 3.5)
            end)
            task.wait(0.35)
        end

        -- Repair hanya jika skill check tidak sedang tampil
        local c, _, _ = FindSkillCheck()
        if not c then DoRepair() end
    end
end)

-- =============================================
-- SILENT AIMBOT
-- =============================================
local function GetAimbotTarget()
    local cfg   = _G.CX.Aimbot
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end

    local best, bestDist = nil, cfg.FOV
    for _, p in pairs(Players:GetPlayers()) do
        if p == LocalPlayer or not p.Character then continue end
        local part = p.Character:FindFirstChild(cfg.AimPart)
        if not part then continue end
        local isKiller   = p.Team and p.Team.Name:lower():find("killer")
        local wantKiller = cfg.Target == "Killer"
        if wantKiller and not isKiller   then continue end
        if not wantKiller and isKiller   then continue end
        local d = (part.Position - myHRP.Position).Magnitude
        if d < bestDist then bestDist = d; best = p.Character end
    end
    return best
end

pcall(function()
    local MT = getrawmetatable(game)
    local OI = MT.__index
    local ON = MT.__namecall
    setreadonly(MT, false)

    MT.__index = newcclosure(function(self, key)
        if not checkcaller() and T.AimLock and self == LocalPlayer:GetMouse() then
            local cfg = _G.CX.Aimbot
            local tc  = GetAimbotTarget()
            if tc then
                local part = tc:FindFirstChild(cfg.AimPart)
                if part then
                    local pred = part.Position + (part.Velocity * cfg.Predict)
                    if key == "Hit"    or key == "hit"    then return CFrame.new(pred) end
                    if key == "Target" or key == "target" then return part end
                end
            end
        end
        return OI(self, key)
    end)

    MT.__namecall = newcclosure(function(self, ...)
        local m    = getnamecallmethod()
        local args = {...}
        if not checkcaller() and T.AimLock
            and (m == "Raycast" or m == "FindPartOnRayWithWhitelist") then
            local cfg = _G.CX.Aimbot
            local tc  = GetAimbotTarget()
            if tc then
                local part = tc:FindFirstChild(cfg.AimPart)
                if part and args[1] and args[2] then
                    local pred = part.Position + (part.Velocity * cfg.Predict)
                    args[2]    = (pred - args[1]).Unit * args[2].Magnitude
                    return ON(self, unpack(args))
                end
            end
        end
        return ON(self, ...)
    end)

    setreadonly(MT, true)
end)

print("[CrimsonX] Semua sistem aktif!")
