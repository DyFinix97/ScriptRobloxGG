--[[
    ╔══════════════════════════════════════╗
    ║        CrimsonX Hub v5.3             ║
    ║  Violence District • WindUI          ║
    ╚══════════════════════════════════════╝
    FIX v5.3:
    • Tombol Oren → SendMouseButtonEvent (proven work dari standalone)
    • Find button recursive: FindFirstChild("Survivor-mob", true)
    • ESP Highlight adornee = Model (bukan BasePart) → highlight muncul
    • Dropdown diganti Toggle radio biar pasti muncul di WindUI
]]

-- =============================================
-- SERVICES
-- =============================================
local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService          = game:GetService("GuiService")
local CoreGui             = game:GetService("CoreGui")
local LocalPlayer         = Players.LocalPlayer

-- =============================================
-- LOAD WINDUI
-- =============================================
local WindUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"
))()

-- =============================================
-- CONFIG
-- =============================================
local T = {
    AutoFarm  = false,
    AutoFix   = false,
    AutoHook  = false,
    EspPlayer = false,
    EspGen    = false,
    EspHook   = false,
    AimLock   = false,
}
local AB = {
    Target  = "Killer",
    AimPart = "HumanoidRootPart",
    FOV     = 300,
    Predict = 0.04,
}

-- =============================================
-- STATE
-- =============================================
local ActiveGenerators = {}
local ESPObjects       = {}
local VisibilityConn   = nil
local RenderConn       = nil
local IntDebounce      = false
local HookDebounce     = false
local CurrentTargetGen = nil
local IsAtGenerator    = false
local LastTeleportTime = 0
local TELE_CD          = 2.5

-- =============================================
-- CORE: Cari tombol Oren (Survivor-mob recursive)
-- Ini cara yang PROVEN WORK dari standalone script
-- =============================================
local function GetOrangeButton()
    local pg = LocalPlayer.PlayerGui
    -- Cari "Survivor-mob" recursive di seluruh PlayerGui
    local root = pg:FindFirstChild("Survivor-mob", true)
    if not root then return nil end
    -- Kalau bukan GuiButton, cari anak GuiButton-nya
    if root:IsA("GuiButton") then return root end
    return root:FindFirstChildWhichIsA("GuiButton", true) or root
end

-- =============================================
-- CORE: Cari tombol Skill Check
-- =============================================
local function GetSkillCheckButton()
    local pg = LocalPlayer.PlayerGui
    -- Coba path langsung dulu
    local cur = pg
    for seg in string.gmatch("Survivor-mob.Controls.action.check", "[^%.]+") do
        cur = cur and cur:FindFirstChild(seg)
    end
    if cur then return cur end
    -- Fallback: cari "check" recursive
    return pg:FindFirstChild("check", true)
end

-- =============================================
-- CORE: Klik tombol pakai SendMouseButtonEvent
-- (proven work di VD mobile / Delta)
-- =============================================
local function ClickButton(btn)
    if not btn then return end
    if not btn.Visible then return end
    local p  = btn.AbsolutePosition
    local s  = btn.AbsoluteSize
    local ins = GuiService:GetGuiInset()
    local cx = p.X + s.X * 0.5 + ins.X
    local cy = p.Y + s.Y * 0.5 + ins.Y
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true,  game, 0)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
    end)
end

-- =============================================
-- SKILL CHECK (RenderStepped, arc 102–114°)
-- =============================================
local function SetupSkillCheck(pg)
    if VisibilityConn then VisibilityConn:Disconnect(); VisibilityConn = nil end
    if RenderConn     then RenderConn:Disconnect();     RenderConn = nil end
    task.spawn(function()
        local prompt = pg:WaitForChild("SkillCheckPromptGui", 20)
        if not prompt then return end
        local check = prompt:WaitForChild("Check", 10)
        if not check then return end
        local line = check:WaitForChild("Line", 5)
        local goal = check:WaitForChild("Goal", 5)
        if not line or not goal then return end

        local function InZone()
            local lr = line.Rotation % 360
            local gr = goal.Rotation % 360
            local ss = (gr + 102) % 360
            local se = (gr + 114) % 360
            if ss < se then return lr >= ss and lr <= se
            else return lr >= ss or lr <= se end
        end

        VisibilityConn = check:GetPropertyChangedSignal("Visible"):Connect(function()
            if not T.AutoFix then return end
            if check.Visible then
                if RenderConn then RenderConn:Disconnect() end
                RenderConn = RunService.RenderStepped:Connect(function()
                    if not T.AutoFix then
                        RenderConn:Disconnect(); RenderConn = nil; return
                    end
                    if InZone() then
                        ClickButton(GetSkillCheckButton())
                        if RenderConn then RenderConn:Disconnect(); RenderConn = nil end
                    end
                end)
            else
                if RenderConn then RenderConn:Disconnect(); RenderConn = nil end
            end
        end)
    end)
end

-- =============================================
-- GENERATOR HELPERS
-- =============================================
local function RefreshGenerators()
    ActiveGenerators = {}
    -- Cari di seluruh workspace (termasuk Map) seperti standalone script
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name == "Generator" then
            table.insert(ActiveGenerators, obj)
        end
    end
end

local function GetGenPart(gen)
    if gen:IsA("BasePart") then return gen end
    -- Untuk Model: cari HumanoidRootPart, Main, atau BasePart pertama
    return gen:FindFirstChild("HumanoidRootPart")
        or gen:FindFirstChild("Main")
        or gen:FindFirstChildWhichIsA("BasePart", true)
end

local function GetGenProgress(gen)
    for _, n in ipairs({"RepairProgress","Progress","Percent","ProgressValue"}) do
        local a = gen:GetAttribute(n)
        if type(a) == "number" then return math.clamp(math.floor(a),0,100) end
        local v = gen:FindFirstChild(n)
        if v and (v:IsA("NumberValue") or v:IsA("IntValue")) then
            return math.clamp(math.floor(v.Value),0,100)
        end
    end
    return 0
end

-- =============================================
-- HOOK DETECTION
-- =============================================
local function IsNearHook()
    local char = LocalPlayer.Character; if not char then return false end
    local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then return false end
    -- Cek attribute dulu
    if char:GetAttribute("IsHooked") or char:GetAttribute("Hooked") then return true end
    -- Cari Hook object di workspace
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name == "Hook" then
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart",true)
            if part and (part.Position - hrp.Position).Magnitude <= 6 then
                return true
            end
        end
    end
    return false
end

-- =============================================
-- AUTO FARM LOOP
-- =============================================
task.spawn(function()
    while task.wait(0.5) do
        if not T.AutoFarm then
            IsAtGenerator = false; CurrentTargetGen = nil; continue
        end

        local char = LocalPlayer.Character; if not char then continue end
        local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then continue end

        -- Cari generator terdekat yang belum selesai
        local bestPart, bestGen, bestDist = nil, nil, math.huge
        for _, gen in ipairs(ActiveGenerators) do
            if not gen or not gen.Parent then continue end
            local part = GetGenPart(gen); if not part then continue end
            local pct  = GetGenProgress(gen); if pct >= 100 then continue end
            local d    = (part.Position - hrp.Position).Magnitude
            if d < bestDist then bestDist=d; bestPart=part; bestGen=gen end
        end

        if not bestPart then IsAtGenerator=false; CurrentTargetGen=nil; continue end

        if bestGen ~= CurrentTargetGen then
            CurrentTargetGen = bestGen; IsAtGenerator = false
        end
        if IsAtGenerator and (hrp.Position - bestPart.Position).Magnitude > 15 then
            IsAtGenerator = false
        end

        local now = tick()
        if not IsAtGenerator and bestDist > 10 and (now - LastTeleportTime) >= TELE_CD then
            LastTeleportTime = now
            pcall(function() hrp.CFrame = bestPart.CFrame * CFrame.new(0, 0, 3) end)
            task.wait(0.8)
            IsAtGenerator = true
        end
    end
end)

-- =============================================
-- AUTO INTERACT HEARTBEAT
-- Sama persis logika standalone yang proven work
-- =============================================
task.spawn(function()
    while task.wait(0.5) do
        -- ESCAPE HOOK (prioritas)
        if T.AutoHook and not HookDebounce and IsNearHook() then
            local btn = GetOrangeButton()
            if btn and btn.Visible then
                HookDebounce = true
                ClickButton(btn)
                task.wait(0.1)
                HookDebounce = false
            end
        end

        -- AUTO FARM GENERATOR
        if not T.AutoFarm or IntDebounce then continue end

        -- Skip kalau skill check aktif
        local promptUI = LocalPlayer.PlayerGui:FindFirstChild("SkillCheckPromptGui", true)
        local scActive = promptUI and promptUI:FindFirstChild("Check") and promptUI.Check.Visible
        if scActive then continue end

        local char = LocalPlayer.Character; if not char then continue end
        local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then continue end

        -- Cek jarak ke generator (sama seperti standalone)
        local isNearGen = false
        for _, gen in ipairs(ActiveGenerators) do
            if not gen or not gen.Parent then continue end
            local part = GetGenPart(gen)
            if part and (part.Position - hrp.Position).Magnitude <= 10 and GetGenProgress(gen) < 100 then
                isNearGen = true; break
            end
        end

        if isNearGen then
            local btn = GetOrangeButton()
            if btn and btn.Visible then
                IntDebounce = true
                ClickButton(btn)
                task.wait(0.4)
                IntDebounce = false
            end
        end
    end
end)

-- =============================================
-- RESPAWN HANDLER
-- =============================================
local function OnCharacterAdded()
    IsAtGenerator = false; CurrentTargetGen = nil
    if VisibilityConn then VisibilityConn:Disconnect(); VisibilityConn = nil end
    if RenderConn     then RenderConn:Disconnect();     RenderConn = nil end
    task.spawn(function()
        task.wait(2)
        local pg = LocalPlayer:WaitForChild("PlayerGui", 15)
        if pg then SetupSkillCheck(pg) end
        RefreshGenerators()
    end)
end

if LocalPlayer.Character then OnCharacterAdded() end
LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)
workspace.ChildAdded:Connect(function(c)
    if c.Name == "Map" then task.wait(1); RefreshGenerators() end
end)

task.spawn(function()
    local pg = LocalPlayer:WaitForChild("PlayerGui", 15)
    if pg then SetupSkillCheck(pg) end
    task.wait(2); RefreshGenerators()
end)

-- =============================================
-- ESP — Highlight parented to game object langsung
-- Adornee = Model (biar seluruh model ke-highlight)
-- =============================================
local function GetAdornee(obj)
    -- Kalau obj adalah Model → highlight seluruh model
    if obj:IsA("Model") then return obj end
    -- Kalau BasePart punya parent Model → pakai Model-nya
    if obj:IsA("BasePart") and obj.Parent and obj.Parent:IsA("Model") then
        return obj.Parent
    end
    return obj
end

local function MakeESP(key, obj, color, label)
    if not obj or not obj.Parent then return end
    local adornee = GetAdornee(obj)
    if not adornee or not adornee.Parent then return end

    -- Kalau sudah ada, update aja
    local d = ESPObjects[key]
    if d then
        if d.h and d.h.Parent then
            d.h.FillColor    = color
            d.h.OutlineColor = color
        end
        if d.b and d.b.Parent then
            local lbl = d.b:FindFirstChildWhichIsA("TextLabel")
            if lbl then lbl.Text = label; lbl.TextColor3 = color end
        end
        return
    end

    -- Highlight
    local h = Instance.new("Highlight")
    h.Name               = "CX_ESP_H"
    h.Adornee            = adornee
    h.FillColor          = color
    h.OutlineColor       = color
    h.FillTransparency   = 0.5
    h.OutlineTransparency = 0
    h.DepthMode          = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent             = CoreGui

    -- Billboard label
    local refPart = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
    local bg = Instance.new("BillboardGui")
    bg.Name         = "CX_ESP_B"
    bg.AlwaysOnTop  = true
    bg.Size         = UDim2.new(0, 180, 0, 40)
    bg.StudsOffset  = Vector3.new(0, 3.5, 0)
    bg.Adornee      = refPart or adornee
    bg.Parent       = CoreGui
    local lbl = Instance.new("TextLabel", bg)
    lbl.Size                = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Text                = label
    lbl.TextColor3          = color
    lbl.Font                = Enum.Font.GothamBold
    lbl.TextSize            = 11
    lbl.TextStrokeTransparency = 0.4
    lbl.TextWrapped         = true

    ESPObjects[key] = {h=h, b=bg}
end

local function RemoveESP(key)
    local d = ESPObjects[key]; if not d then return end
    if d.h then pcall(function() d.h:Destroy() end) end
    if d.b then pcall(function() d.b:Destroy() end) end
    ESPObjects[key] = nil
end

local function ClearAllESP()
    for key in pairs(ESPObjects) do RemoveESP(key) end
end

-- Render ESP
RunService.RenderStepped:Connect(function()
    local myHRP = LocalPlayer.Character
        and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    -- PLAYER ESP
    if T.EspPlayer then
        for _, p in pairs(Players:GetPlayers()) do
            if p == LocalPlayer or not p.Character then continue end
            local hrp = p.Character:FindFirstChild("HumanoidRootPart"); if not hrp then continue end
            local hum = p.Character:FindFirstChildWhichIsA("Humanoid")
            local killer = p.Team and p.Team.Name:lower():find("killer")
            local color  = killer and Color3.fromRGB(255,60,60) or Color3.fromRGB(60,220,120)
            local hp     = hum and math.floor(hum.Health) or 0
            local mhp    = hum and math.max(hum.MaxHealth, 1) or 100
            local dist   = myHRP and math.floor((hrp.Position - myHRP.Position).Magnitude) or 0
            MakeESP(p.UserId, p.Character, color,
                ("%s [%s]\n%d/%d HP  %dm"):format(
                    p.Name, killer and "KILLER" or "Survivor", hp, mhp, dist))
        end
    end

    -- GENERATOR ESP
    if T.EspGen then
        for _, obj in ipairs(ActiveGenerators) do
            if not obj or not obj.Parent then continue end
            local part = GetGenPart(obj); if not part then continue end
            local pct  = GetGenProgress(obj)
            local c    = Color3.fromRGB(150,0,200):Lerp(Color3.fromRGB(0,200,80), pct/100)
            local dist = myHRP and math.floor((part.Position - myHRP.Position).Magnitude) or 0
            MakeESP("gen_"..tostring(obj), obj, c,
                ("Generator %d%%\n%dm"):format(pct, dist))
        end
    end

    -- HOOK ESP
    if T.EspHook then
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj.Name ~= "Hook" then continue end
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart",true)
            if not part then continue end
            local occ   = obj:GetAttribute("Occupied") or obj:FindFirstChild("Occupied")
            local color = occ and Color3.fromRGB(255,0,0) or Color3.fromRGB(255,165,0)
            local dist  = myHRP and math.floor((part.Position - myHRP.Position).Magnitude) or 0
            MakeESP("hook_"..tostring(obj), obj, color,
                (occ and "Hook [ISI]\n" or "Hook\n") .. dist .. "m")
        end
    end
end)

-- Cleanup ESP saat player keluar
Players.PlayerRemoving:Connect(function(p)
    RemoveESP(p.UserId)
end)
Players.PlayerAdded:Connect(function(p)
    p.CharacterRemoving:Connect(function()
        RemoveESP(p.UserId)
    end)
end)
for _, p in pairs(Players:GetPlayers()) do
    p.CharacterRemoving:Connect(function() RemoveESP(p.UserId) end)
end

-- =============================================
-- SILENT AIMBOT
-- =============================================
local function GetAimbotTarget()
    local myHRP = LocalPlayer.Character
        and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end
    local best, bestDist = nil, AB.FOV
    for _, p in pairs(Players:GetPlayers()) do
        if p == LocalPlayer or not p.Character then continue end
        local part = p.Character:FindFirstChild(AB.AimPart); if not part then continue end
        local killer = p.Team and p.Team.Name:lower():find("killer")
        if AB.Target == "Killer"    and not killer then continue end
        if AB.Target == "Survivors" and killer     then continue end
        local d = (part.Position - myHRP.Position).Magnitude
        if d < bestDist then bestDist=d; best=p.Character end
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
            local tc = GetAimbotTarget()
            if tc then
                local part = tc:FindFirstChild(AB.AimPart)
                if part then
                    local pred = part.Position + (part.Velocity * AB.Predict)
                    if key=="Hit"    or key=="hit"    then return CFrame.new(pred) end
                    if key=="Target" or key=="target" then return part end
                end
            end
        end
        return OI(self, key)
    end)
    MT.__namecall = newcclosure(function(self, ...)
        local m = getnamecallmethod()
        local args = {...}
        if not checkcaller() and T.AimLock
            and (m=="Raycast" or m=="FindPartOnRayWithWhitelist") then
            local tc = GetAimbotTarget()
            if tc then
                local part = tc:FindFirstChild(AB.AimPart)
                if part and args[1] and args[2] then
                    local pred = part.Position + (part.Velocity * AB.Predict)
                    args[2] = (pred - args[1]).Unit * args[2].Magnitude
                    return ON(self, unpack(args))
                end
            end
        end
        return ON(self, ...)
    end)
    setreadonly(MT, true)
end)

-- =============================================
-- WINDUI WINDOW
-- =============================================
local Window = WindUI:CreateWindow({
    Title       = "CrimsonX Hub",
    Icon        = "solar:skull-bold",
    Folder      = "CrimsonX",
    NewElements = true,
    OpenButton  = {
        Title           = "CrimsonX",
        CornerRadius    = UDim.new(1, 0),
        StrokeThickness = 2,
        Enabled         = true,
        Draggable       = true,
        OnlyMobile      = false,
        Scale           = 0.5,
        Color           = ColorSequence.new(
            Color3.fromHex("#C0392B"),
            Color3.fromHex("#8E44AD")
        ),
    },
    Topbar = { Height=44, ButtonsType="Mac" },
})
Window:Tag({
    Title  = "v5.3  |  Violence District",
    Icon   = "github",
    Color  = Color3.fromHex("#1c1c1c"),
    Border = true,
})

-- =============================================
-- TAB: FARM
-- =============================================
local FarmTab = Window:Tab({ Title="Farm", Icon="solar:widget-bold", Border=true })

FarmTab:Section({ Title="Generator" }):Toggle({
    Title    = "Auto Farm Generator",
    Desc     = "Teleport ke gen + tekan tombol Oren otomatis",
    Callback = function(v)
        T.AutoFarm = v
        if not v then IsAtGenerator=false; CurrentTargetGen=nil end
    end,
})

FarmTab:Space()

FarmTab:Section({ Title="Skill Check" }):Toggle({
    Title    = "Auto Perfect Skill Check",
    Desc     = "Klik otomatis saat jarum di arc 102–114° dari Goal",
    Callback = function(v) T.AutoFix = v end,
})

FarmTab:Space()

FarmTab:Section({ Title="Hook" }):Toggle({
    Title    = "Auto Escape Hook",
    Desc     = "Klik tombol Oren saat karakter dekat Hook (≤6 stud)",
    Callback = function(v) T.AutoHook = v end,
})

-- =============================================
-- TAB: ESP
-- =============================================
local EspTab = Window:Tab({ Title="ESP", Icon="solar:eye-bold", Border=true })

EspTab:Section({ Title="Player" }):Toggle({
    Title    = "Player ESP",
    Desc     = "Merah=Killer | Hijau=Survivor + HP + Jarak",
    Callback = function(v)
        T.EspPlayer = v
        if not v then
            for _, p in pairs(Players:GetPlayers()) do
                RemoveESP(p.UserId)
            end
        end
    end,
})

EspTab:Space()

local ObjSec = EspTab:Section({ Title="Object" })

ObjSec:Toggle({
    Title    = "Generator ESP",
    Desc     = "Ungu→Hijau sesuai % repair + jarak",
    Callback = function(v)
        T.EspGen = v
        if not v then
            for _, obj in ipairs(ActiveGenerators) do
                RemoveESP("gen_"..tostring(obj))
            end
        end
    end,
})

ObjSec:Space()

ObjSec:Toggle({
    Title    = "Hook ESP",
    Desc     = "Orange=kosong | Merah=ada korban",
    Callback = function(v)
        T.EspHook = v
        if not v then
            -- Bersihkan semua key hook
            for key in pairs(ESPObjects) do
                if tostring(key):sub(1,5) == "hook_" then RemoveESP(key) end
            end
        end
    end,
})

-- =============================================
-- TAB: SILENT AIM
-- Dropdown diganti Toggle radio (pasti muncul)
-- =============================================
local AimTab = Window:Tab({ Title="Silent Aim", Icon="solar:target-bold", Border=true })

AimTab:Section({ Title="Aimbot" }):Toggle({
    Title    = "Enable Aim Lock",
    Desc     = "Silent aimbot — tidak terlihat server",
    Callback = function(v) T.AimLock = v end,
})

AimTab:Space()

-- TARGET ROLE (radio toggle)
local TargetSec = AimTab:Section({ Title="Target Role  —  aktifkan salah satu" })

local killerToggleRef, survivorToggleRef

TargetSec:Toggle({
    Title    = "Lock: Killer",
    Desc     = "Aktif = aim ke Killer",
    Default  = true,
    Callback = function(v)
        if v then
            AB.Target = "Killer"
        else
            if AB.Target == "Killer" then AB.Target = "None" end
        end
    end,
})

TargetSec:Space()

TargetSec:Toggle({
    Title    = "Lock: Survivors",
    Desc     = "Aktif = aim ke Survivor lain",
    Default  = false,
    Callback = function(v)
        if v then
            AB.Target = "Survivors"
        else
            if AB.Target == "Survivors" then AB.Target = "None" end
        end
    end,
})

AimTab:Space()

-- AIM PART (radio toggle)
local PartSec = AimTab:Section({ Title="Aim Part  —  aktifkan salah satu" })

PartSec:Toggle({
    Title    = "HumanoidRootPart (Body)",
    Desc     = "Paling stabil, default",
    Default  = true,
    Callback = function(v) if v then AB.AimPart = "HumanoidRootPart" end end,
})

PartSec:Space()

PartSec:Toggle({
    Title    = "Head",
    Desc     = "Headshot — lebih sulit kena",
    Default  = false,
    Callback = function(v) if v then AB.AimPart = "Head" end end,
})

PartSec:Space()

PartSec:Toggle({
    Title    = "UpperTorso",
    Default  = false,
    Callback = function(v) if v then AB.AimPart = "UpperTorso" end end,
})

AimTab:Space()

AimTab:Section({ Title="Settings" }):Slider({
    Title    = "FOV Radius",
    Desc     = "Radius deteksi target (stud)",
    Min      = 50, Max=1000, Default=300,
    Callback = function(v) AB.FOV = v end,
})

AimTab:Space()

AimTab:Section({}):Slider({
    Title    = "Prediction",
    Desc     = "Kompensasi gerak target",
    Min      = 0, Max=0.5, Default=0.04,
    Callback = function(v) AB.Predict = v end,
})

-- =============================================
-- TAB: INFO
-- =============================================
local InfoTab = Window:Tab({ Title="Info", Icon="solar:info-square-bold", Border=true })
local InfoSec = InfoTab:Section({ Title="Utilities" })

InfoSec:Button({
    Title    = "Refresh Generator List",
    Icon     = "solar:restart-bold",
    Justify  = "Center",
    Callback = function()
        RefreshGenerators(); IsAtGenerator=false; CurrentTargetGen=nil
        WindUI:Notify({
            Title   = "CrimsonX",
            Content = "Ketemu " .. #ActiveGenerators .. " generator!",
        })
    end,
})

InfoSec:Space()

InfoSec:Button({
    Title    = "Clear Semua ESP",
    Icon     = "solar:eye-closed-bold",
    Justify  = "Center",
    Color    = Color3.fromHex("#C0392B"),
    Callback = function()
        T.EspPlayer=false; T.EspGen=false; T.EspHook=false
        ClearAllESP()
        WindUI:Notify({ Title="CrimsonX", Content="Semua ESP dihapus!" })
    end,
})

-- =============================================
-- DONE
-- =============================================
print("[CrimsonX v5.3] Aktif! Generator: " .. #ActiveGenerators)
