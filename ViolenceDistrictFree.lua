--[[
    ╔══════════════════════════════════════╗
    ║        CrimsonX Hub v4.0             ║
    ║  Violence District • WindUI Proper   ║
    ╚══════════════════════════════════════╝
    - WindUI by Footagesus (API sesuai contoh resmi)
    - OpenButton: floating button buat buka UI di mobile
    - Anti teleport spam, anti emote, FPS-independent skill check
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
-- LOAD WINDUI  (cara resmi sesuai contoh)
-- =============================================
local WindUI = loadstring(
    game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua")
)()

-- =============================================
-- CONFIG / STATE
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
local T  = _G.CX.Toggles
local AB = _G.CX.Aimbot

local FinishedGenerators = {}
local ESPObjects         = {}
local HeartbeatConn      = nil
local NeedleVelocity     = 0
local LastNeedleAngle    = nil
local LastNeedleTime     = nil

-- Anti-spam teleport
local CurrentTargetGen   = nil
local IsAtGenerator      = false
local LastTeleportTime   = 0
local TELE_COOLDOWN      = 2.5

-- =============================================
-- BUAT WINDOW  (sesuai API contoh resmi)
-- =============================================
local Window = WindUI:CreateWindow({
    Title       = "CrimsonX Hub",
    Icon        = "solar:skull-bold",
    Folder      = "CrimsonX",
    NewElements = true,

    -- Floating open-button — penting untuk mobile/Delta
    OpenButton = {
        Title         = "CrimsonX Hub",
        CornerRadius  = UDim.new(1, 0),
        StrokeThickness = 2,
        Enabled       = true,
        Draggable     = true,
        OnlyMobile    = false,
        Scale         = 0.5,
        Color         = ColorSequence.new(
            Color3.fromHex("#C0392B"),
            Color3.fromHex("#8E44AD")
        ),
    },

    Topbar = {
        Height      = 44,
        ButtonsType = "Mac",
    },
})

-- Version tag
Window:Tag({
    Title  = "v4.0  Violence District",
    Icon   = "github",
    Color  = Color3.fromHex("#1c1c1c"),
    Border = true,
})

-- =============================================
-- TAB: FARM
-- =============================================
local FarmTab = Window:Tab({
    Title  = "Farm",
    Icon   = "solar:widget-bold",
    Border = true,
})

local GenSection = FarmTab:Section({ Title = "Generator" })

GenSection:Toggle({
    Title    = "Auto Farm Generator",
    Desc     = "Teleport ke generator terdekat & repair otomatis",
    Callback = function(v)
        T.AutoFarm = v
        if not v then
            FinishedGenerators = {}
            IsAtGenerator      = false
            CurrentTargetGen   = nil
        end
    end,
})

GenSection:Space()

GenSection:Toggle({
    Title    = "Auto Perfect Skill Check",
    Desc     = "FPS-independent, prediksi 2 frame ke depan",
    Callback = function(v)
        T.AutoFix = v
        if not v and HeartbeatConn then
            HeartbeatConn:Disconnect()
            HeartbeatConn   = nil
            LastNeedleAngle = nil
            LastNeedleTime  = nil
            NeedleVelocity  = 0
        end
    end,
})

-- =============================================
-- TAB: ESP
-- =============================================
local EspTab = Window:Tab({
    Title  = "ESP",
    Icon   = "solar:eye-bold",
    Border = true,
})

local EspPlayerSection = EspTab:Section({ Title = "Player" })

EspPlayerSection:Toggle({
    Title    = "Killer & Survivor ESP",
    Desc     = "Killer = merah  |  Survivor = hijau",
    Callback = function(v) T.EspPlayer = v end,
})

EspTab:Space()

local EspObjSection = EspTab:Section({ Title = "Object" })

EspObjSection:Toggle({
    Title    = "Generator ESP  +  Progress %",
    Desc     = "Warna ungu → hijau sesuai % repair",
    Callback = function(v) T.EspGen = v end,
})

EspObjSection:Space()

EspObjSection:Toggle({
    Title    = "Hook ESP",
    Desc     = "Orange = kosong  |  Merah = ada korban",
    Callback = function(v) T.EspHook = v end,
})

-- =============================================
-- TAB: SILENT AIM
-- =============================================
local AimTab = Window:Tab({
    Title  = "Silent Aim",
    Icon   = "solar:target-bold",
    Border = true,
})

local AimSection = AimTab:Section({ Title = "Aimbot" })

AimSection:Toggle({
    Title    = "Enable Aim Lock",
    Desc     = "Silent — tidak kelihatan dari sisi server",
    Callback = function(v) T.AimLock = v end,
})

AimSection:Space()

AimSection:Dropdown({
    Title    = "Target Role",
    Desc     = "Pilih siapa yang di-lock",
    Options  = { "Killer", "Survivors" },
    Default  = "Killer",
    Callback = function(v) AB.Target = v end,
})

AimSection:Space()

AimSection:Dropdown({
    Title    = "Aim Part",
    Desc     = "Bagian tubuh yang ditarget",
    Options  = { "HumanoidRootPart", "Head", "UpperTorso", "LowerTorso" },
    Default  = "HumanoidRootPart",
    Callback = function(v) AB.AimPart = v end,
})

AimSection:Space()

AimSection:Slider({
    Title    = "FOV Radius",
    Desc     = "Radius deteksi target",
    Min      = 50,
    Max      = 1000,
    Default  = 300,
    Callback = function(v) AB.FOV = v end,
})

AimSection:Space()

AimSection:Slider({
    Title    = "Prediction",
    Desc     = "Kompensasi pergerakan target",
    Min      = 0,
    Max      = 0.5,
    Default  = 0.04,
    Callback = function(v) AB.Predict = v end,
})

-- =============================================
-- TAB: INFO
-- =============================================
local InfoTab = Window:Tab({
    Title  = "Info",
    Icon   = "solar:info-square-bold",
    Border = true,
})

local InfoSection = InfoTab:Section({ Title = "CrimsonX Hub  v4.0" })

InfoSection:Button({
    Title    = "Reset Finished Generators",
    Desc     = "Paksa ulang semua generator (kalau stuck)",
    Icon     = "solar:restart-bold",
    Justify  = "Center",
    Callback = function()
        FinishedGenerators = {}
        IsAtGenerator      = false
        CurrentTargetGen   = nil
        WindUI:Notify({ Title = "CrimsonX", Content = "Generator list direset!" })
    end,
})

InfoSection:Space()

InfoSection:Button({
    Title    = "Hapus Semua ESP",
    Icon     = "solar:eye-closed-bold",
    Justify  = "Center",
    Color    = Color3.fromHex("#C0392B"),
    Callback = function()
        T.EspPlayer = false
        T.EspGen    = false
        T.EspHook   = false
        for inst, d in pairs(ESPObjects) do
            pcall(function() if d.h then d.h:Destroy() end end)
            pcall(function() if d.b then d.b:Destroy() end end)
            ESPObjects[inst] = nil
        end
        WindUI:Notify({ Title = "CrimsonX", Content = "Semua ESP dihapus!" })
    end,
})

-- =============================================
-- CLICK ENGINE  (spesifik VD, anti-emote)
-- Path: Survivor-mob > Controls > action > check
-- TIDAK ada fallback ke GuiButton random
-- =============================================
local function FindRepairButton()
    local pg  = LocalPlayer.PlayerGui
    local mob = pg:FindFirstChild("Survivor-mob") or pg:FindFirstChild("Survivor-mob", true)
    if not mob then return nil end

    local controls = mob:FindFirstChild("Controls")
    if controls then
        local action = controls:FindFirstChild("action")
        if action then
            local check = action:FindFirstChild("check")
            if check and check:IsA("GuiButton") and check.Visible then return check end
            for _, v in pairs(action:GetChildren()) do
                if v:IsA("GuiButton") and v.Visible then return v end
            end
        end
    end

    local check = mob:FindFirstChild("check", true)
    if check and check:IsA("GuiButton") and check.Visible then return check end
    return nil
end

local function ClickRepairButton()
    local btn = FindRepairButton()
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
        local p   = btn.AbsolutePosition
        local s   = btn.AbsoluteSize
        local ins = GuiService:GetGuiInset()
        VirtualInputManager:SendMouseButtonEvent(p.X+s.X*.5+ins.X, p.Y+s.Y*.5+ins.Y, 0, true,  game, 0)
        task.wait(0.02)
        VirtualInputManager:SendMouseButtonEvent(p.X+s.X*.5+ins.X, p.Y+s.Y*.5+ins.Y, 0, false, game, 0)
    end)
    return true
end

-- =============================================
-- GENERATOR HELPERS
-- =============================================
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
    return gen:FindFirstChild("Main")
        or gen:FindFirstChild("HumanoidRootPart")
        or gen:FindFirstChildWhichIsA("BasePart",true)
end

local function GetAllGenerators()
    local r = {}
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name=="Generator" and (obj:IsA("Model") or obj:IsA("BasePart")) then
            table.insert(r, obj)
        end
    end
    return r
end

-- =============================================
-- SKILL CHECK  (FPS-independent heartbeat)
-- =============================================
local function FindSkillCheck()
    for _, gui in pairs(LocalPlayer.PlayerGui:GetChildren()) do
        for _, name in ipairs({"Check","SkillCheck","RepairCheck","CheckUI"}) do
            local check = gui:FindFirstChild(name,true)
            if check and check.Visible then
                local needle = check:FindFirstChild("Line") or check:FindFirstChild("Needle") or check:FindFirstChild("Arrow")
                local goal   = check:FindFirstChild("Goal") or check:FindFirstChild("Target") or check:FindFirstChild("Zone") or check:FindFirstChild("Perfect") or check:FindFirstChild("White")
                if needle and goal then return check, needle, goal end
            end
        end
    end
    return nil, nil, nil
end

local function InArc(a,s,e)
    a,s,e = a%360,s%360,e%360
    if s<=e then return a>=s and a<=e else return a>=s or a<=e end
end

local function OnHeartbeat()
    if not T.AutoFix then return end
    local _, needle, goal = FindSkillCheck()
    if not needle or not goal then return end
    local now = tick()
    local ang = needle.Rotation % 360
    if LastNeedleAngle and LastNeedleTime then
        local dt   = now - LastNeedleTime
        local dAng = (ang - LastNeedleAngle + 360) % 360
        if dAng > 180 then dAng = dAng - 360 end
        if dt > 0 then NeedleVelocity = dAng / dt end
    end
    LastNeedleAngle = ang; LastNeedleTime = now
    local goalAng = goal.Rotation % 360
    local pred    = (ang + NeedleVelocity * (1/60) * 2) % 360
    local s,e     = (goalAng-10)%360, (goalAng+10)%360
    if InArc(ang,s,e) or InArc(pred,s,e) then
        ClickRepairButton()
        LastNeedleAngle=nil; LastNeedleTime=nil; NeedleVelocity=0
        if HeartbeatConn then HeartbeatConn:Disconnect(); HeartbeatConn=nil end
    end
end

task.spawn(function()
    while task.wait(0.05) do
        if T.AutoFix then
            local c,n,g = FindSkillCheck()
            if c and n and g then
                if not HeartbeatConn then HeartbeatConn = RunService.Heartbeat:Connect(OnHeartbeat) end
            else
                if HeartbeatConn then HeartbeatConn:Disconnect(); HeartbeatConn=nil end
            end
        else
            if HeartbeatConn then HeartbeatConn:Disconnect(); HeartbeatConn=nil end
        end
    end
end)

-- =============================================
-- AUTO FARM  (anti teleport spam)
-- =============================================
task.spawn(function()
    while task.wait(0.5) do
        if not T.AutoFarm then
            IsAtGenerator=false; CurrentTargetGen=nil; continue
        end
        local char = LocalPlayer.Character; if not char then continue end
        local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then continue end

        local bestPart, bestGen, bestDist = nil, nil, math.huge
        pcall(function()
            for _, gen in pairs(GetAllGenerators()) do
                local part = GetGenPart(gen)
                if not part or table.find(FinishedGenerators,gen) then continue end
                local pct = GetGenProgress(gen)
                if pct >= 100 then
                    if not table.find(FinishedGenerators,gen) then table.insert(FinishedGenerators,gen) end
                    continue
                end
                local d = (part.Position - hrp.Position).Magnitude
                if d < bestDist then bestDist=d; bestPart=part; bestGen=gen end
            end
        end)

        if not bestPart then IsAtGenerator=false; CurrentTargetGen=nil; continue end

        if bestGen ~= CurrentTargetGen then
            CurrentTargetGen=bestGen; IsAtGenerator=false
        end

        if IsAtGenerator then
            if (hrp.Position - bestPart.Position).Magnitude > 8 then IsAtGenerator=false end
        end

        local now = tick()
        if not IsAtGenerator and bestDist > 5 and (now-LastTeleportTime) >= TELE_COOLDOWN then
            LastTeleportTime = now
            pcall(function() hrp.CFrame = bestPart.CFrame * CFrame.new(0,0,3.5) end)
            task.wait(0.6)
            IsAtGenerator = true
        end

        local sc = FindSkillCheck()
        if not sc then ClickRepairButton() end
    end
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
    local h=Instance.new("Highlight"); h.FillColor=color; h.OutlineColor=color; h.FillTransparency=0.6; h.OutlineTransparency=0; h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; h.Adornee=adornee; h.Parent=CoreGui
    local bg=Instance.new("BillboardGui"); bg.AlwaysOnTop=true; bg.Size=UDim2.new(0,175,0,40); bg.StudsOffset=Vector3.new(0,3.5,0); bg.Adornee=adornee; bg.Parent=CoreGui
    local lbl=Instance.new("TextLabel",bg); lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=color; lbl.Font=Enum.Font.GothamBold; lbl.TextSize=11; lbl.TextStrokeTransparency=0.4; lbl.TextWrapped=true
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
            local hp=hum and math.floor(hum.Health) or 0; local mhp=hum and math.max(hum.MaxHealth,1) or 100
            local dist=myHRP and math.floor((hrp.Position-myHRP.Position).Magnitude) or 0
            pcall(MakeESP, p.Character, hrp, color, ("%s [%s]\n%d/%dHP  %dm"):format(p.Name, killer and "KILLER" or "Survivor", hp, mhp, dist))
        end
    end
    if T.EspGen then
        for _, obj in pairs(GetAllGenerators()) do
            local part=GetGenPart(obj); if not part then continue end
            local pct=GetGenProgress(obj)
            local c=Color3.fromRGB(150,0,200):Lerp(Color3.fromRGB(0,200,80),pct/100)
            local dist=myHRP and math.floor((part.Position-myHRP.Position).Magnitude) or 0
            pcall(MakeESP, obj, part, c, ("Generator %d%%\n%dm"):format(pct,dist))
        end
    end
    if T.EspHook then
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj.Name~="Hook" then continue end
            local part=obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart",true); if not part then continue end
            local occ=obj:GetAttribute("Occupied") or obj:FindFirstChild("Occupied")
            local color=occ and Color3.fromRGB(255,0,0) or Color3.fromRGB(255,165,0)
            local dist=myHRP and math.floor((part.Position-myHRP.Position).Magnitude) or 0
            pcall(MakeESP, obj, part, color, (occ and "Hook [TERISI]\n" or "Hook\n")..dist.."m")
        end
    end
end)

Players.PlayerRemoving:Connect(function(p) if p.Character then RemoveESP(p.Character) end end)
Players.PlayerAdded:Connect(function(p) p.CharacterRemoving:Connect(function(c) RemoveESP(c) end) end)
for _, p in pairs(Players:GetPlayers()) do p.CharacterRemoving:Connect(function(c) RemoveESP(c) end) end

-- =============================================
-- SILENT AIMBOT
-- =============================================
local function GetAimbotTarget()
    local myHRP=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); if not myHRP then return nil end
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

print("[CrimsonX v4.0] Semua sistem aktif!")
