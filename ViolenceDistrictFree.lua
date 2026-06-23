--[[
    ╔══════════════════════════════════════╗
    ║        CrimsonX Hub v5.1             ║
    ║  Violence District • WindUI          ║
    ╚══════════════════════════════════════╝
    v5.1 — Tombol Oren (action.main) pakai SendTouchEvent
    Skill check (action.check) pakai SendTouchEvent TouchID 8822
    Generator cari di workspace.Map
    Semua resolusi HP otomatis (koordinat dinamis)
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
local WindUI = loadstring(
    game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua")
)()

-- =============================================
-- CONFIG
-- =============================================
_G.CX = _G.CX or {
    Toggles = {
        AutoFarm   = false,
        AutoFix    = false,
        AutoHook   = false,
        EspPlayer  = false,
        EspGen     = false,
        EspHook    = false,
        AimLock    = false,
    },
    Aimbot = {
        Target  = "Killer",
        AimPart = "HumanoidRootPart",
        FOV     = 300,
        Predict = 0.04,
    }
}
local T  = _G.CX.Toggles
local AB = _G.CX.Aimbot

-- =============================================
-- CONSTANTS (dari referensi script VD)
-- =============================================
local TOUCH_ID_SKILLCHECK = 8822
local TOUCH_ID_INTERACT   = 8823
local PATH_CHECK  = "Survivor-mob.Controls.action.check"
local PATH_MAIN   = "Survivor-mob.Controls.action.main"
local INTERACT_DISTANCE = 12  -- stud

-- =============================================
-- STATE
-- =============================================
local ActiveGenerators    = {}
local ESPObjects          = {}
local VisibilityConn      = nil
local RenderConn          = nil
local InteractDebounce    = false
local CurrentTargetGen    = nil
local IsAtGenerator       = false
local LastTeleportTime    = 0
local TELE_COOLDOWN       = 2.5

-- =============================================
-- CORE HELPER: Navigasi path PlayerGui
-- Contoh: "Survivor-mob.Controls.action.main"
-- =============================================
local function GetActionTarget(path)
    local pg = LocalPlayer.PlayerGui
    local cur = pg
    for seg in string.gmatch(path, "[^%.]+") do
        cur = cur and cur:FindFirstChild(seg)
    end
    return cur
end

-- =============================================
-- CORE HELPER: SendTouchEvent (resolusi-independent)
-- Cara ini proven work untuk tombol VD di semua HP
-- =============================================
local function TriggerMobileButton(btn, touchID)
    if not btn then return end
    local p   = btn.AbsolutePosition
    local s   = btn.AbsoluteSize
    local ins = GuiService:GetGuiInset()
    local cx  = p.X + (s.X * 0.5) + ins.X
    local cy  = p.Y + (s.Y * 0.5) + ins.Y
    pcall(function()
        VirtualInputManager:SendTouchEvent(touchID, 0, cx, cy)  -- Begin
        task.wait(0.05)
        VirtualInputManager:SendTouchEvent(touchID, 2, cx, cy)  -- End
    end)
end

-- =============================================
-- SKILL CHECK ENGINE (proven dari referensi)
-- GUI: SkillCheckPromptGui > Check > Line + Goal
-- Arc: Goal+102 s/d Goal+114 (dari source resmi VD)
-- Button: action.check via SendTouchEvent TouchID 8822
-- =============================================
local function SetupSkillCheck(pg)
    if VisibilityConn then VisibilityConn:Disconnect(); VisibilityConn = nil end
    if RenderConn     then RenderConn:Disconnect();     RenderConn     = nil end

    task.spawn(function()
        local prompt = pg:WaitForChild("SkillCheckPromptGui", 15)
        if not prompt then return end
        local check = prompt:WaitForChild("Check", 10)
        if not check then return end
        local line = check:WaitForChild("Line", 5)
        local goal = check:WaitForChild("Goal", 5)
        if not line or not goal then return end

        local function LineInGoal()
            local lr = line.Rotation % 360
            local gr = goal.Rotation % 360
            local ss = (gr + 102) % 360
            local se = (gr + 114) % 360
            if ss < se then
                return lr >= ss and lr <= se
            else
                return lr >= ss or lr <= se
            end
        end

        VisibilityConn = check:GetPropertyChangedSignal("Visible"):Connect(function()
            if not T.AutoFix then return end
            if check.Visible then
                if RenderConn then RenderConn:Disconnect() end
                RenderConn = RunService.RenderStepped:Connect(function()
                    if not T.AutoFix then
                        if RenderConn then RenderConn:Disconnect(); RenderConn = nil end
                        return
                    end
                    if LineInGoal() then
                        local btn = GetActionTarget(PATH_CHECK)
                        TriggerMobileButton(btn, TOUCH_ID_SKILLCHECK)
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
-- GENERATOR LIST: ambil dari workspace.Map
-- =============================================
local function RefreshGenerators()
    ActiveGenerators = {}
    local Map = workspace:FindFirstChild("Map")
    if not Map then return end
    for _, obj in ipairs(Map:GetDescendants()) do
        if obj.Name == "Generator" then
            table.insert(ActiveGenerators, obj)
        end
    end
end

local function GetGenProgress(gen)
    for _, name in ipairs({"RepairProgress","Progress","Percent","ProgressValue"}) do
        local attr = gen:GetAttribute(name)
        if type(attr)=="number" then return math.clamp(math.floor(attr),0,100) end
        local v = gen:FindFirstChild(name)
        if v and (v:IsA("NumberValue") or v:IsA("IntValue")) then
            return math.clamp(math.floor(v.Value),0,100)
        end
    end
    return 0
end

local function GetGenPart(gen)
    if gen:IsA("BasePart") then return gen end
    return gen:FindFirstChildWhichIsA("BasePart", true)
end

-- =============================================
-- AUTO FARM
-- 1. Teleport ke generator terdekat (sekali)
-- 2. Tekan tombol Oren (action.main) via SendTouchEvent
-- 3. Skill check ditangani SetupSkillCheck di atas
-- =============================================
task.spawn(function()
    while task.wait(0.5) do
        if not T.AutoFarm then
            IsAtGenerator=false; CurrentTargetGen=nil; continue
        end
        if not (LocalPlayer.Team and LocalPlayer.Team.Name=="Survivors") then continue end
        local char = LocalPlayer.Character; if not char then continue end
        local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then continue end

        -- Cari generator belum selesai yang terdekat
        local bestPart, bestGen, bestDist = nil, nil, math.huge
        pcall(function()
            for _, gen in ipairs(ActiveGenerators) do
                local part = GetGenPart(gen)
                if not part then continue end
                local pct = GetGenProgress(gen)
                if pct >= 100 then continue end
                local d = (part.Position - hrp.Position).Magnitude
                if d < bestDist then bestDist=d; bestPart=part; bestGen=gen end
            end
        end)

        if not bestPart then IsAtGenerator=false; CurrentTargetGen=nil; continue end

        -- Reset state kalau ganti target
        if bestGen ~= CurrentTargetGen then
            CurrentTargetGen=bestGen; IsAtGenerator=false
        end

        -- Cek kalau terdorong keluar
        if IsAtGenerator and (hrp.Position-bestPart.Position).Magnitude > 15 then
            IsAtGenerator=false
        end

        -- Teleport sekali kalau belum di sana
        local now = tick()
        if not IsAtGenerator and bestDist > INTERACT_DISTANCE and (now-LastTeleportTime) >= TELE_COOLDOWN then
            LastTeleportTime = now
            pcall(function() hrp.CFrame = bestPart.CFrame * CFrame.new(0,0,3) end)
            task.wait(0.8)
            IsAtGenerator = true
        end
    end
end)

-- =============================================
-- AUTO INTERACT: Tekan tombol Oren (action.main)
-- Dijalankan di Heartbeat, cek jarak ≤12 stud
-- Skip kalau skill check sedang aktif
-- =============================================
RunService.Heartbeat:Connect(function()
    if not T.AutoFarm then return end
    if InteractDebounce then return end

    -- Jangan pencet kalau skill check lagi muncul
    local promptUI = LocalPlayer.PlayerGui:FindFirstChild("SkillCheckPromptGui")
    local scActive = promptUI and promptUI:FindFirstChild("Check") and promptUI.Check.Visible
    if scActive then return end

    local char = LocalPlayer.Character; if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end

    -- Cek apakah ada generator dalam jarak
    local nearGen = false
    for _, gen in ipairs(ActiveGenerators) do
        local part = GetGenPart(gen)
        if part and (part.Position - hrp.Position).Magnitude <= INTERACT_DISTANCE then
            if GetGenProgress(gen) < 100 then
                nearGen = true
                break
            end
        end
    end
    if not nearGen then return end

    -- Tekan tombol Oren (action.main)
    local btn = GetActionTarget(PATH_MAIN)
    if btn and btn.Visible then
        InteractDebounce = true
        TriggerMobileButton(btn, TOUCH_ID_INTERACT)
        task.wait(0.4)
        InteractDebounce = false
    end
end)

-- =============================================
-- AUTO ESCAPE HOOK
-- =============================================
task.spawn(function()
    while task.wait(0.15) do
        if not T.AutoHook then continue end
        local pg   = LocalPlayer.PlayerGui
        local char = LocalPlayer.Character
        local hooked = false

        -- Deteksi hook lewat berbagai cara
        if char then
            local attr = char:GetAttribute("IsHooked") or char:GetAttribute("Hooked")
            if attr then hooked = true end
        end

        -- Cek GUI yang ada kata "hook"/"escape"/"struggle"
        if not hooked then
            for _, gui in pairs(pg:GetChildren()) do
                local n = gui.Name:lower()
                if (n:find("hook") or n:find("escape") or n:find("struggle")) and gui.Enabled then
                    hooked = true; break
                end
            end
        end

        if hooked then
            -- Coba tekan tombol lepas via action.main
            local btn = GetActionTarget(PATH_MAIN)
            if btn and btn.Visible then
                TriggerMobileButton(btn, TOUCH_ID_INTERACT)
            end
        end
    end
end)

-- =============================================
-- RESPAWN HANDLER
-- =============================================
local function OnCharacterAdded(char)
    IsAtGenerator    = false
    CurrentTargetGen = nil
    if VisibilityConn then VisibilityConn:Disconnect(); VisibilityConn=nil end
    if RenderConn     then RenderConn:Disconnect();     RenderConn=nil end

    task.spawn(function()
        task.wait(2)
        local pg = LocalPlayer:WaitForChild("PlayerGui", 15)
        if pg then SetupSkillCheck(pg) end
        RefreshGenerators()
    end)
end

if LocalPlayer.Character then OnCharacterAdded(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)

-- Refresh generator list tiap Map di-load
workspace.ChildAdded:Connect(function(c)
    if c.Name == "Map" then task.wait(1); RefreshGenerators() end
end)

-- Setup awal
task.spawn(function()
    local pg = LocalPlayer:WaitForChild("PlayerGui", 15)
    if pg then SetupSkillCheck(pg) end
    task.wait(2)
    RefreshGenerators()
end)

-- =============================================
-- ESP
-- =============================================
local function MakeESP(inst, adornee, color, label)
    if not adornee or not adornee.Parent then return end
    local d = ESPObjects[inst]
    if d and d.h and d.h.Parent then
        pcall(function()
            d.h.FillColor=color; d.h.OutlineColor=color
            if d.b and d.b.Parent then
                local l=d.b:FindFirstChildWhichIsA("TextLabel")
                if l then l.Text=label; l.TextColor3=color end
            end
        end)
        return
    end
    local h=Instance.new("Highlight"); h.FillColor=color; h.OutlineColor=color
    h.FillTransparency=0.7; h.OutlineTransparency=0
    h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; h.Adornee=adornee; h.Parent=CoreGui
    local bg=Instance.new("BillboardGui"); bg.AlwaysOnTop=true
    bg.Size=UDim2.new(0,180,0,40); bg.StudsOffset=Vector3.new(0,3.5,0)
    bg.Adornee=adornee; bg.Parent=CoreGui
    local lbl=Instance.new("TextLabel",bg); lbl.Size=UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=color
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=11
    lbl.TextStrokeTransparency=0.4; lbl.TextWrapped=true
    ESPObjects[inst]={h=h,b=bg}
end

local function RemoveESP(inst)
    local d=ESPObjects[inst]; if not d then return end
    pcall(function() if d.h then d.h:Destroy() end end)
    pcall(function() if d.b then d.b:Destroy() end end)
    ESPObjects[inst]=nil
end

RunService.RenderStepped:Connect(function()
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    if T.EspPlayer then
        for _, p in pairs(Players:GetPlayers()) do
            if p==LocalPlayer or not p.Character then continue end
            local hrp=p.Character:FindFirstChild("HumanoidRootPart"); if not hrp then continue end
            local hum=p.Character:FindFirstChildWhichIsA("Humanoid")
            local killer=p.Team and p.Team.Name:lower():find("killer")
            local color=killer and Color3.fromRGB(255,60,60) or Color3.fromRGB(60,220,120)
            local hp=hum and math.floor(hum.Health) or 0
            local mhp=hum and math.max(hum.MaxHealth,1) or 100
            local dist=myHRP and math.floor((hrp.Position-myHRP.Position).Magnitude) or 0
            pcall(MakeESP, p.Character, hrp, color,
                ("%s [%s]\n%d/%dHP  %dm"):format(p.Name,killer and "KILLER" or "Survivor",hp,mhp,dist))
        end
    end

    if T.EspGen then
        for _, obj in ipairs(ActiveGenerators) do
            local part=GetGenPart(obj); if not part then continue end
            local pct=GetGenProgress(obj)
            local c=Color3.fromRGB(150,0,200):Lerp(Color3.fromRGB(0,200,80),pct/100)
            local dist=myHRP and math.floor((part.Position-myHRP.Position).Magnitude) or 0
            pcall(MakeESP, obj, part, c, ("Generator %d%%\n%dm"):format(pct,dist))
        end
    end

    if T.EspHook then
        local Map = workspace:FindFirstChild("Map")
        if Map then
            for _, obj in ipairs(Map:GetDescendants()) do
                if obj.Name~="Hook" then continue end
                local part=obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart",true)
                if not part then continue end
                local occ=obj:GetAttribute("Occupied") or obj:FindFirstChild("Occupied")
                local color=occ and Color3.fromRGB(255,0,0) or Color3.fromRGB(255,165,0)
                local dist=myHRP and math.floor((part.Position-myHRP.Position).Magnitude) or 0
                pcall(MakeESP, obj, part, color, (occ and "Hook [TERISI]\n" or "Hook\n")..dist.."m")
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(p) if p.Character then RemoveESP(p.Character) end end)
Players.PlayerAdded:Connect(function(p) p.CharacterRemoving:Connect(function(c) RemoveESP(c) end) end)
for _, p in pairs(Players:GetPlayers()) do
    p.CharacterRemoving:Connect(function(c) RemoveESP(c) end)
end

-- =============================================
-- SILENT AIMBOT
-- =============================================
local function GetAimbotTarget()
    local myHRP=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end
    local best,bestDist=nil,AB.FOV
    for _, p in pairs(Players:GetPlayers()) do
        if p==LocalPlayer or not p.Character then continue end
        local part=p.Character:FindFirstChild(AB.AimPart); if not part then continue end
        local killer=p.Team and p.Team.Name:lower():find("killer")
        if AB.Target=="Killer"    and not killer then continue end
        if AB.Target=="Survivors" and killer     then continue end
        local d=(part.Position-myHRP.Position).Magnitude
        if d<bestDist then bestDist=d; best=p.Character end
    end
    return best
end

pcall(function()
    local MT=getrawmetatable(game); local OI=MT.__index; local ON=MT.__namecall
    setreadonly(MT,false)
    MT.__index=newcclosure(function(self,key)
        if not checkcaller() and T.AimLock and self==LocalPlayer:GetMouse() then
            local tc=GetAimbotTarget()
            if tc then
                local part=tc:FindFirstChild(AB.AimPart)
                if part then
                    local pred=part.Position+(part.Velocity*AB.Predict)
                    if key=="Hit" or key=="hit" then return CFrame.new(pred) end
                    if key=="Target" or key=="target" then return part end
                end
            end
        end
        return OI(self,key)
    end)
    MT.__namecall=newcclosure(function(self,...)
        local m=getnamecallmethod(); local args={...}
        if not checkcaller() and T.AimLock and (m=="Raycast" or m=="FindPartOnRayWithWhitelist") then
            local tc=GetAimbotTarget()
            if tc then
                local part=tc:FindFirstChild(AB.AimPart)
                if part and args[1] and args[2] then
                    local pred=part.Position+(part.Velocity*AB.Predict)
                    args[2]=(pred-args[1]).Unit*args[2].Magnitude
                    return ON(self,unpack(args))
                end
            end
        end
        return ON(self,...)
    end)
    setreadonly(MT,true)
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
        CornerRadius    = UDim.new(1,0),
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

Window:Tag({ Title="v5.1  |  Violence District", Icon="github", Color=Color3.fromHex("#1c1c1c"), Border=true })

-- TAB: FARM
local FarmTab = Window:Tab({ Title="Farm", Icon="solar:widget-bold", Border=true })

local FarmSec = FarmTab:Section({ Title="Generator" })
FarmSec:Toggle({
    Title    = "Auto Farm Generator",
    Desc     = "Teleport ke gen, tekan tombol Oren otomatis",
    Callback = function(v)
        T.AutoFarm = v
        if not v then IsAtGenerator=false; CurrentTargetGen=nil end
    end,
})

FarmSec:Space()

FarmSec:Toggle({
    Title    = "Auto Perfect Skill Check",
    Desc     = "SendTouchEvent saat jarum di zona 102–114° dari Goal",
    Callback = function(v) T.AutoFix = v end,
})

FarmSec:Space()

FarmSec:Toggle({
    Title    = "Auto Escape Hook",
    Desc     = "Tekan tombol lepas saat di-hook otomatis",
    Callback = function(v) T.AutoHook = v end,
})

-- TAB: ESP
local EspTab = Window:Tab({ Title="ESP", Icon="solar:eye-bold", Border=true })

local EspPS = EspTab:Section({ Title="Player ESP" })
EspPS:Toggle({ Title="Killer & Survivor ESP", Desc="Merah=Killer | Hijau=Survivor + HP + Jarak", Callback=function(v) T.EspPlayer=v end })

EspTab:Space()

local EspOS = EspTab:Section({ Title="Object ESP" })
EspOS:Toggle({ Title="Generator ESP + Progress %", Desc="Ungu→Hijau sesuai % repair", Callback=function(v) T.EspGen=v end })
EspOS:Space()
EspOS:Toggle({ Title="Hook ESP", Desc="Orange=kosong | Merah=ada korban", Callback=function(v) T.EspHook=v end })

-- TAB: SILENT AIM
local AimTab = Window:Tab({ Title="Silent Aim", Icon="solar:target-bold", Border=true })
local AimSec = AimTab:Section({ Title="Aimbot" })

AimSec:Toggle({ Title="Enable Aim Lock", Desc="Silent — tidak terlihat server", Callback=function(v) T.AimLock=v end })
AimSec:Space()
AimSec:Dropdown({
    Title="Target Role", Desc="Siapa yang di-lock",
    Options={"Killer","Survivors"}, Default="Killer",
    Callback=function(v) AB.Target=(type(v)=="table") and v[1] or v end,
})
AimSec:Space()
AimSec:Dropdown({
    Title="Aim Part", Desc="Bagian tubuh target",
    Options={"HumanoidRootPart","Head","UpperTorso","LowerTorso"}, Default="HumanoidRootPart",
    Callback=function(v) AB.AimPart=(type(v)=="table") and v[1] or v end,
})
AimSec:Space()
AimSec:Slider({ Title="FOV Radius", Min=50, Max=1000, Default=300, Callback=function(v) AB.FOV=v end })
AimSec:Space()
AimSec:Slider({ Title="Prediction", Min=0, Max=0.5, Default=0.04, Callback=function(v) AB.Predict=v end })

-- TAB: INFO
local InfoTab = Window:Tab({ Title="Info", Icon="solar:info-square-bold", Border=true })
local InfoSec = InfoTab:Section({ Title="Tools" })

InfoSec:Button({
    Title="Refresh Generator List", Icon="solar:restart-bold", Justify="Center",
    Callback=function()
        RefreshGenerators()
        IsAtGenerator=false; CurrentTargetGen=nil
        WindUI:Notify({ Title="CrimsonX", Content="Generator list diperbarui! ("..#ActiveGenerators.." gen)" })
    end,
})
InfoSec:Space()
InfoSec:Button({
    Title="Hapus Semua ESP", Icon="solar:eye-closed-bold", Justify="Center",
    Color=Color3.fromHex("#C0392B"),
    Callback=function()
        T.EspPlayer=false; T.EspGen=false; T.EspHook=false
        for inst,d in pairs(ESPObjects) do
            pcall(function() if d.h then d.h:Destroy() end end)
            pcall(function() if d.b then d.b:Destroy() end end)
            ESPObjects[inst]=nil
        end
        WindUI:Notify({ Title="CrimsonX", Content="Semua ESP dihapus!" })
    end,
})

print("[CrimsonX v5.1] Semua sistem aktif! Generator: " .. #ActiveGenerators)
