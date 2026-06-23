-- ========================================================== --
-- ||          CrimsonX Hub - ULTIMATE UPDATE              || --
-- ||     Separated ESP, Persistent Speed, Safe Noclip     || --
-- ========================================================== --

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService          = game:GetService("GuiService")
local CoreGui             = game:GetService("CoreGui")
local LocalPlayer         = Players.LocalPlayer

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

-- =============================================
-- KONFIGURASI GLOBAL
-- =============================================
local T = { 
    AutoFarm = false, 
    AutoFix = false, 
    EspSurvivor = false, 
    EspKiller = false, 
    EspGen = false, 
    EspHook = false,
    AimLock = false,
    SpeedEnabled = false,
    Noclip = false,
    ShiftLock = false
}
local AB = { AimPart = "HumanoidRootPart", FOV = 300, Predict = 0.04 }
local PlayerMod = { TargetSpeed = 16 }

local ActiveGenerators = {}
local ESPObjects       = {}
local VisibilityConn   = nil
local RenderConn       = nil

-- =============================================
-- CORE UTILITIES
-- =============================================
local function GetOrangeButton()
    local root = LocalPlayer.PlayerGui:FindFirstChild("Survivor-mob", true)
    if not root then return nil end
    return root:IsA("GuiButton") and root or root:FindFirstChildWhichIsA("GuiButton", true) or root
end

local function GetSkillCheckButton()
    return LocalPlayer.PlayerGui:FindFirstChild("check", true)
end

local function ClickButton(btn)
    if not btn or not btn.Visible then return end
    local p, s = btn.AbsolutePosition, btn.AbsoluteSize
    local ins = GuiService:GetGuiInset()
    local cx, cy = p.X + s.X * 0.5 + ins.X, p.Y + s.Y * 0.5 + ins.Y
    
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
        task.wait(0.02)
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
    end)
end

-- =============================================
-- PERSISTENT BACKGROUND LOOPS (MAP CHANGE & DEATH PROOF)
-- =============================================
local function RefreshGenerators()
    ActiveGenerators = {}
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name == "Generator" then table.insert(ActiveGenerators, obj) end
    end
end

-- Thread penyegar data otomatis agar ESP & Farm tidak patah saat pindah map
task.spawn(function()
    while true do
        RefreshGenerators()
        task.wait(2)
    end
end)

-- Loop Pengendali Fitur Player (Speed & Noclip Aman)
RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")

    -- 1. Persistent Speed (Mati pun tetap berjalan)
    if T.SpeedEnabled and hum then
        hum.WalkSpeed = tonumber(PlayerMod.TargetSpeed) or 16
    end

    -- 2. Safe Noclip (Menembus objek tapi tidak amblas ke dalam tanah)
    if T.Noclip then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
        
        if hrp then
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {char}
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude
            
            local rayOrigin = hrp.Position + Vector3.new(0, 2, 0)
            local rayDirection = Vector3.new(0, -20, 0)
            local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
            
            if result then
                local groundY = result.Position.Y
                if hrp.Position.Y < groundY + 3.2 then
                    hrp.Velocity = Vector3.new(hrp.Velocity.X, math.max(0, hrp.Velocity.Y), hrp.Velocity.Z)
                    hrp.CFrame = CFrame.new(hrp.Position.X, groundY + 3.3, hrp.Position.Z) * hrp.CFrame.Rotation
                end
            end
        end
    end
end)

-- 3. Force Shiftlock Toggle Loop
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            local pMod = require(LocalPlayer.PlayerScripts:WaitForChild("PlayerModule", 2))
            local cams = pMod:GetCameras()
            if cams and cams.activeMouseLockController then
                cams.activeMouseLockController:EnableMouseLock(T.ShiftLock)
            end
         pcall(function() LocalPlayer.DevEnableMouseLock = T.ShiftLock end)
        end)
    end
end)

-- =============================================
-- AUTO PERFECT SKILL CHECK
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
            local ss = (gr + 104) % 360
            local se = (gr + 112) % 360
            if ss < se then return lr >= ss and lr <= se
            else return lr >= ss or lr <= se end
        end

        VisibilityConn = check:GetPropertyChangedSignal("Visible"):Connect(function()
            if not T.AutoFix then return end
            if check.Visible then
                if RenderConn then RenderConn:Disconnect() end
                
                local hasClicked = false
                RenderConn = RunService.RenderStepped:Connect(function()
                    if not T.AutoFix or hasClicked then return end
                    if InZone() then
                        hasClicked = true
                        ClickButton(GetSkillCheckButton())
                    end
                end)
            else
                if RenderConn then RenderConn:Disconnect(); RenderConn = nil end
            end
        end)
    end)
end

-- =============================================
-- DETAILED SEPARATED ESP SYSTEM
-- =============================================
local function GetGenProgress(gen)
    for _, n in ipairs({"RepairProgress","Progress","Percent","ProgressValue"}) do
        local a = gen:GetAttribute(n)
        if type(a) == "number" then return math.clamp(math.floor(a),0,100) end
        local v = gen:FindFirstChild(n)
        if v and (v:IsA("NumberValue") or v:IsA("IntValue")) then return math.clamp(math.floor(v.Value),0,100) end
    end
    return 0
end

local function MakeESP(key, obj, color, label)
    if not obj or not obj.Parent then return end
    
    local d = ESPObjects[key]
    if d then
        if d.h and d.h.Parent then d.h.FillColor = color; d.h.OutlineColor = color end
        if d.b and d.b.Parent then
            local lbl = d.b:FindFirstChildWhichIsA("TextLabel")
            if lbl then lbl.Text = label; lbl.TextColor3 = color end
        end
        return
    end

    local adornee = (obj:IsA("Model") and obj) or obj
    local h = Instance.new("Highlight", CoreGui)
    h.Adornee, h.FillColor, h.OutlineColor, h.FillTransparency, h.DepthMode = adornee, color, color, 0.4, Enum.HighlightDepthMode.AlwaysOnTop
    
    local bg = Instance.new("BillboardGui", CoreGui)
    bg.Size, bg.AlwaysOnTop, bg.StudsOffset = UDim2.new(0, 200, 0, 50), true, Vector3.new(0, 3.5, 0)
    bg.Adornee = (obj:IsA("BasePart") and obj) or obj:FindFirstChildWhichIsA("BasePart", true) or adornee
    
    local lbl = Instance.new("TextLabel", bg)
    lbl.Size, lbl.BackgroundTransparency, lbl.Text, lbl.TextColor3 = UDim2.new(1,0,1,0), 1, label, color
    lbl.Font, lbl.TextSize, lbl.TextStrokeTransparency, lbl.TextWrapped = Enum.Font.GothamBold, 11, 0.4, true
    
    ESPObjects[key] = {h=h, b=bg}
end

local function RemoveESP(key)
    if ESPObjects[key] then
        pcall(function() ESPObjects[key].h:Destroy(); ESPObjects[key].b:Destroy() end)
        ESPObjects[key] = nil
    end
end

local function ClearAllESP()
    for key in pairs(ESPObjects) do RemoveESP(key) end
end

-- Render Stepped Utama untuk Mengatur Macam-Macam ESP Dinamis
RunService.RenderStepped:Connect(function()
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    -- 1. ESP SURVIVOR & ESP KILLER (TERPISAH)
    for _, p in pairs(Players:GetPlayers()) do
        if p == LocalPlayer or not p.Character then continue end
        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        
        local hum = p.Character:FindFirstChildWhichIsA("Humanoid")
        local isKiller = p.Team and p.Team.Name:lower():find("killer")
        local dist = myHRP and math.floor((hrp.Position - myHRP.Position).Magnitude) or 0
        
        if isKiller and T.EspKiller then
            -- Highlight Merah
            MakeESP(p.UserId, p.Character, Color3.fromRGB(255, 40, 40), string.format("%s\n[KILLER]\n%dM", p.Name, dist))
        elseif not isKiller and T.EspSurvivor then
            -- Highlight Hijau
            local hp = hum and math.floor(hum.Health) or 100
            MakeESP(p.UserId, p.Character, Color3.fromRGB(60, 230, 100), string.format("%s\nHealth: %d/100\n%dM", p.Name, hp, dist))
        else
            RemoveESP(p.UserId)
        end
    end

    -- 2. ESP GENERATOR (Biru + Persentase)
    if T.EspGen then
        for _, obj in ipairs(ActiveGenerators) do
            if obj and obj.Parent then
                local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
                if part then
                    local pct = GetGenProgress(obj)
                    local dist = myHRP and math.floor((part.Position - myHRP.Position).Magnitude) or 0
                    MakeESP("gen_"..tostring(obj), obj, Color3.fromRGB(40, 150, 255), string.format("Generator (%d%%)\n%dM", pct, dist))
                end
            end
        end
    else
        for key in pairs(ESPObjects) do if tostring(key):sub(1,4) == "gen_" then RemoveESP(key) end end
    end

    -- 3. ESP HOOK (Kuning)
    if T.EspHook then
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj.Name == "Hook" then
                local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
                if part then
                    local dist = myHRP and math.floor((part.Position - myHRP.Position).Magnitude) or 0
                    MakeESP("hook_"..tostring(obj), obj, Color3.fromRGB(255, 215, 0), string.format("Hook\n%dM", dist))
                end
            end
        end
    else
        for key in pairs(ESPObjects) do if tostring(key):sub(1,5) == "hook_" then RemoveESP(key) end end
    end
end)

-- Handling Respawn & UI Init
local function OnCharacterAdded()
    task.spawn(function()
        task.wait(2)
        local pg = LocalPlayer:WaitForChild("PlayerGui", 15)
        if pg then SetupSkillCheck(pg) end
    end)
end
if LocalPlayer.Character then OnCharacterAdded() end
LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)

-- =============================================
-- AUTO FARM & SILENT AIM CORE (Sama seperti sebelumnya)
-- =============================================
task.spawn(function()
    local safePart = Instance.new("Part")
    safePart.Size = Vector3.new(10, 1, 10)
    safePart.Anchored = true
    safePart.Transparency = 1
    safePart.CanCollide = true
    safePart.Parent = workspace

    while task.wait(0.5) do
        if not T.AutoFarm then continue end
        local char = LocalPlayer.Character; if not char then continue end
        local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then continue end

        local bestPart, bestDist = nil, math.huge
        for _, gen in ipairs(ActiveGenerators) do
            if gen and gen.Parent and GetGenProgress(gen) < 100 then
                local part = gen:IsA("BasePart") and gen or gen:FindFirstChildWhichIsA("BasePart", true)
                if part then
                    local d = (part.Position - hrp.Position).Magnitude
                    if d < bestDist then bestDist = d; bestPart = part end
                end
            end
        end

        if bestPart then
            if bestDist > 8 then
                pcall(function() hrp.CFrame = bestPart.CFrame * CFrame.new(0, 0, 3) end)
                task.wait(0.8)
            else
                local promptUI = LocalPlayer.PlayerGui:FindFirstChild("SkillCheckPromptGui", true)
                local scActive = promptUI and promptUI:FindFirstChild("Check") and promptUI.Check.Visible
                if not scActive then
                    local btn = GetOrangeButton()
                    if btn and btn.Visible then ClickButton(btn); task.wait(0.4) end
                end
            end
        end
    end
end)

-- =============================================
-- WINDUI WINDOW BUILDER
-- =============================================
local Window = WindUI:CreateWindow({Title = "CrimsonX Hub (Ultimate)", Icon = "solar:skull-bold"})

-- TAB 1: FARMING
local FarmTab = Window:Tab({Title="Farm", Icon="solar:widget-bold"})
FarmTab:Toggle({Title="Auto Farm Generator", Callback = function(v) T.AutoFarm = v end})
FarmTab:Toggle({Title="Auto Perfect Skill Check", Callback = function(v) T.AutoFix = v end})

-- TAB 2: SEPARATED ESP LISTS
local EspTab = Window:Tab({Title="ESP Visuals", Icon="solar:eye-bold"})
EspTab:Toggle({Title="ESP Survivor (Hijau + HP)", Callback = function(v) T.EspSurvivor = v end})
EspTab:Toggle({Title="ESP Killer (Merah)", Callback = function(v) T.EspKiller = v end})
EspTab:Toggle({Title="ESP Generator (Biru + %)", Callback = function(v) T.EspGen = v end})
EspTab:Toggle({Title="ESP Hook (Kuning)", Callback = function(v) T.EspHook = v end})
EspTab:Button({Title="Clear Semua ESP Manual", Callback = function() ClearAllESP() end})

-- TAB 3: SILENT AIM
local AimTab = Window:Tab({Title="Silent Aim", Icon="solar:target-bold"})
local AimSec = AimTab:Section({Title="Aimbot Settings (KILLER ONLY)"})
AimSec:Toggle({Title = "Enable Aim Lock", Callback = function(v) T.AimLock = v end})
AimSec:Dropdown({Title = "Aim Part", Options = {"HumanoidRootPart", "Head"}, Default = "HumanoidRootPart", Callback = function(v) AB.AimPart = v end})
AimSec:Slider({Title = "FOV Radius", Min = 50, Max = 1000, Default = 300, Callback = function(v) AB.FOV = v end})
AimSec:Slider({Title = "Prediction", Min = 0, Max = 0.5, Default = 0.04, Increment = 0.01, Callback = function(v) AB.Predict = v end})

-- TAB 4: PLAYER CONTROLS (FITUR BARU)
local PlayerTab = Window:Tab({Title="Player", Icon="solar:user-bold"})

-- Section Tab 1: Speed Input
local SpeedSec = PlayerTab:Section({Title="Tab 1: Custom WalkSpeed"})
SpeedSec:Input({
    Title = "Masukkan Nilai Speed",
    Default = "16",
    Callback = function(v) PlayerMod.TargetSpeed = tonumber(v) or 16 end
})
SpeedSec:Toggle({
    Title = "Aktifkan Speed Modifier",
    Callback = function(v) T.SpeedEnabled = v end
})

-- Section Tab 2: Noclip
local NoclipSec = PlayerTab:Section({Title="Tab 2: Noclip Mode"})
NoclipSec:Toggle({
    Title = "Noclip (Anti Amblas Tanah)",
    Callback = function(v) T.Noclip = v end
})

-- Section Tab 3: Shiftlock
local LockSec = PlayerTab:Section({Title="Tab 3: ShiftLock Force"})
LockSec:Toggle({
    Title = "Force ShiftLock",
    Callback = function(v) T.ShiftLock = v end
})

print("[CrimsonX] Full Updated Engine Ready!")
