-- ========================================================== --
-- ||          CrimsonX Hub - FULL FIX EDITION             || --
-- ||   Auto Farm Evade, Smart Aim, Fixed ESP, Safe Noclip || --
-- ========================================================== --

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService          = game:GetService("GuiService")
local CoreGui             = game:GetService("CoreGui")
local LocalPlayer         = Players.LocalPlayer
local Camera              = workspace.CurrentCamera

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

-- =============================================
-- KONFIGURASI GLOBAL
-- =============================================
local T = { 
    AutoFarm = false, 
    EspSurvivor = false, 
    EspKiller = false, 
    EspGen = false, 
    EspHook = false,
    AimLock = false,
    AimbotCamera = false,
    SpeedEnabled = false,
    Noclip = false,
    ShiftLock = false
}
local PlayerMod = { TargetSpeed = 16 }

local ActiveGenerators = {}
local ESPObjects       = {}
local CompletedGens    = 0
local Evading          = false
local EvadeGen         = nil

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
        task.wait(0.01)
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
    end)
end

local function GetKiller()
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Team and p.Team.Name:lower():find("killer") then
            return p.Character
        end
    end
    return nil
end

local function GetGenProgress(gen)
    for _, n in ipairs({"RepairProgress","Progress","Percent","ProgressValue"}) do
        local a = gen:GetAttribute(n)
        if type(a) == "number" then return math.clamp(math.floor(a),0,100) end
        local v = gen:FindFirstChild(n)
        if v and (v:IsA("NumberValue") or v:IsA("IntValue")) then return math.clamp(math.floor(v.Value),0,100) end
    end
    return 0
end

local function RefreshGenerators()
    ActiveGenerators = {}
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name == "Generator" then table.insert(ActiveGenerators, obj) end
    end
end

-- =============================================
-- ESP SYSTEM (ANTI BUG & LAG)
-- =============================================
local function MakeESP(key, obj, color, label)
    if not obj or not obj.Parent then return end
    local adornee = (obj:IsA("Model") and obj) or obj
    
    if ESPObjects[key] then
        if ESPObjects[key].h then ESPObjects[key].h.FillColor = color; ESPObjects[key].h.OutlineColor = color end
        if ESPObjects[key].b then
            local lbl = ESPObjects[key].b:FindFirstChildWhichIsA("TextLabel")
            if lbl then lbl.Text = label; lbl.TextColor3 = color end
        end
        return
    end

    local h = Instance.new("Highlight", CoreGui)
    h.Adornee, h.FillColor, h.OutlineColor, h.FillTransparency, h.DepthMode = adornee, color, color, 0.4, Enum.HighlightDepthMode.AlwaysOnTop
    
    local bg = Instance.new("BillboardGui", CoreGui)
    bg.Size, bg.AlwaysOnTop, bg.StudsOffset = UDim2.new(0, 200, 0, 50), true, Vector3.new(0, 3.5, 0)
    bg.Adornee = (obj:IsA("BasePart") and obj) or obj:FindFirstChildWhichIsA("BasePart", true) or adornee
    
    local lbl = Instance.new("TextLabel", bg)
    lbl.Size, lbl.BackgroundTransparency, lbl.Text, lbl.TextColor3 = UDim2.new(1,0,1,0), 1, label, color
    lbl.Font, lbl.TextSize, lbl.TextStrokeTransparency = Enum.Font.GothamBold, 11, 0.4
    
    ESPObjects[key] = {h=h, b=bg}
end

local function RemoveESP(key)
    if ESPObjects[key] then
        pcall(function() ESPObjects[key].h:Destroy(); ESPObjects[key].b:Destroy() end)
        ESPObjects[key] = nil
    end
end

RunService.RenderStepped:Connect(function()
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    -- ESP Player & Killer
    for _, p in pairs(Players:GetPlayers()) do
        if p == LocalPlayer or not p.Character then continue end
        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        
        local isKiller = p.Team and p.Team.Name:lower():find("killer")
        local dist = myHRP and math.floor((hrp.Position - myHRP.Position).Magnitude) or 0
        
        if isKiller and T.EspKiller then
            MakeESP(p.UserId, p.Character, Color3.fromRGB(255, 40, 40), string.format("%s\n[KILLER]\n%dM", p.Name, dist))
        elseif not isKiller and T.EspSurvivor then
            local hum = p.Character:FindFirstChildWhichIsA("Humanoid")
            local hp = hum and math.floor(hum.Health) or 100
            MakeESP(p.UserId, p.Character, Color3.fromRGB(60, 230, 100), string.format("%s\nHealth: %d/100\n%dM", p.Name, hp, dist))
        else
            RemoveESP(p.UserId)
        end
    end

    -- ESP Generator
    if T.EspGen then
        for i, obj in ipairs(ActiveGenerators) do
            if obj and obj.Parent then
                local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
                if part then
                    local dist = myHRP and math.floor((part.Position - myHRP.Position).Magnitude) or 0
                    MakeESP("gen_"..i, obj, Color3.fromRGB(40, 150, 255), string.format("Generator (%d%%)\n%dM", GetGenProgress(obj), dist))
                end
            end
        end
    else
        for key in pairs(ESPObjects) do if tostring(key):sub(1,4) == "gen_" then RemoveESP(key) end end
    end

    -- ESP Hook
    if T.EspHook then
        local hookCount = 0
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj.Name == "Hook" then
                hookCount = hookCount + 1
                local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
                if part then
                    local dist = myHRP and math.floor((part.Position - myHRP.Position).Magnitude) or 0
                    MakeESP("hook_"..hookCount, obj, Color3.fromRGB(255, 215, 0), string.format("Hook\n%dM", dist))
                end
            end
        end
    else
        for key in pairs(ESPObjects) do if tostring(key):sub(1,5) == "hook_" then RemoveESP(key) end end
    end
end)

-- =============================================
-- AUTO FARM (FIXED PERFECT SKILL CHECK + EVADE)
-- =============================================
task.spawn(function()
    RefreshGenerators()
    while task.wait(0.1) do -- Dipercepat agar lebih responsif terhadap skill check
        if not T.AutoFarm or CompletedGens >= 5 then 
            Evading = false
            continue 
        end
        
        local char = LocalPlayer.Character; if not char then continue end
        local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then continue end

        local killerChar = GetKiller()
        local killerHRP = killerChar and killerChar:FindFirstChild("HumanoidRootPart")

        -- Cari target Generator
        local bestPart, bestDist, bestObj = nil, math.huge, nil
        for _, gen in ipairs(ActiveGenerators) do
            if gen and gen.Parent and GetGenProgress(gen) < 100 then
                local part = gen:IsA("BasePart") and gen or gen:FindFirstChildWhichIsA("BasePart", true)
                if part then
                    local d = (part.Position - hrp.Position).Magnitude
                    if d < bestDist then bestDist = d; bestPart = part; bestObj = gen end
                end
            end
        end

        -- Update kalau Generator sudah selesai
        if bestObj and GetGenProgress(bestObj) >= 100 then
            CompletedGens = CompletedGens + 1
            if CompletedGens >= 5 then
                WindUI:Notify({Title="CrimsonX", Content="5 Generator Selesai! Auto Farm Dihentikan."})
                T.AutoFarm = false
            end
            continue
        end

        if bestPart then
            local distToKillerFromGen = killerHRP and (killerHRP.Position - bestPart.Position).Magnitude or math.huge

            -- LOGIKA EVADE
            if distToKillerFromGen <= 18 then
                Evading = true
                EvadeGen = bestPart
                -- Teleport ke langit dengan offset random sedikit agar tidak stuck
                hrp.CFrame = CFrame.new(bestPart.Position + Vector3.new(0, 300, 0))
                hrp.Velocity = Vector3.new(0,0,0)
                continue
            elseif Evading and EvadeGen then
                -- Cek apakah Killer sudah jauh dari mesin (25 studs)
                local distToKillerFromEvadeGen = killerHRP and (killerHRP.Position - EvadeGen.Position).Magnitude or math.huge
                if distToKillerFromEvadeGen > 25 then
                    Evading = false -- Balik ke mesin
                else
                    continue -- Tetap nangkring di atas
                end
            end

            -- LOGIKA KERJA
            if bestDist > 8 then
                -- Teleport
                hrp.CFrame = bestPart.CFrame * CFrame.new(0, 0, 3)
                task.wait(0.5)
            else
                -- Baca Skill Check
                local promptUI = LocalPlayer.PlayerGui:FindFirstChild("SkillCheckPromptGui", true)
                local check = promptUI and promptUI:FindFirstChild("Check")
                
                if check and check.Visible then
                    local line = check:FindFirstChild("Line")
                    local goal = check:FindFirstChild("Goal")
                    if line and goal then
                        local lr = line.Rotation % 360
                        local gr = goal.Rotation % 360
                        -- Margin dipepetkan agar 100% kena tengah
                        local ss = (gr + 104) % 360
                        local se = (gr + 110) % 360
                        
                        local inZone = false
                        if ss < se then inZone = (lr >= ss and lr <= se)
                        else inZone = (lr >= ss or lr <= se) end
                        
                        if inZone then
                            ClickButton(GetSkillCheckButton())
                            task.wait(0.3) -- Anti Spam agar tidak gagal
                        end
                    end
                else
                    -- Kalau jarum ga ada, pencet oren
                    local btn = GetOrangeButton()
                    if btn and btn.Visible then ClickButton(btn); task.wait(0.5) end
                end
            end
        end
    end
end)

-- =============================================
-- SILENT AIM (SMART PREDICT) & AIMBOT CAMERA
-- =============================================
local Mouse = LocalPlayer:GetMouse()

local function GetAimTarget()
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end
    local best, bestDist = nil, math.huge
    
    local killer = GetKiller()
    if killer then
        local part = killer:FindFirstChild("HumanoidRootPart")
        if part then
            local d = (part.Position - myHRP.Position).Magnitude
            if d < bestDist then bestDist = d; best = part end
        end
    end
    return best
end

-- Aimbot Camera Lock (Kamera muter ngunci musuh)
RunService.RenderStepped:Connect(function()
    if T.AimbotCamera then
        local target = GetAimTarget()
        if target then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Position)
        end
    end
end)

-- Silent Aim (Peluru belok otomatis 360 derajat)
pcall(function()
    local MT = getrawmetatable(game)
    local OI = MT.__index
    local ON = MT.__namecall
    setreadonly(MT, false)
    
    MT.__index = newcclosure(function(self, key)
        if not checkcaller() and T.AimLock and self == Mouse then
            local k = tostring(key):lower()
            if k == "hit" or k == "target" then
                local target = GetAimTarget()
                if target then
                    -- Smart Prediction otomatis berdasarkan kecepatan (Velocity)
                    local predPos = target.Position + (target.AssemblyLinearVelocity * 0.065)
                    if k == "hit" then return CFrame.new(predPos) end
                    if k == "target" then return target end
                end
            end
        end
        return OI(self, key)
    end)
    
    MT.__namecall = newcclosure(function(self, ...)
        local m = getnamecallmethod()
        local args = {...}
        if not checkcaller() and T.AimLock and (m == "Raycast" or m == "FindPartOnRayWithWhitelist") then
            local target = GetAimTarget()
            if target and args[1] and args[2] then
                local predPos = target.Position + (target.AssemblyLinearVelocity * 0.065)
                args[2] = (predPos - args[1]).Unit * args[2].Magnitude
                return ON(self, unpack(args))
            end
        end
        return ON(self, ...)
    end)
    setreadonly(MT, true)
end)

-- =============================================
-- PLAYER CONTROLS (NOCLIP & SPEED)
-- =============================================
RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")

    -- Speed
    if T.SpeedEnabled and hum then
        hum.WalkSpeed = tonumber(PlayerMod.TargetSpeed) or 16
    end

    -- Noclip Dex Style (Anti Amblas)
    if T.Noclip then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then 
                part.CanCollide = false 
            end
        end
    end
end)

-- Shiftlock
task.spawn(function()
    while task.wait(0.5) do
        pcall(function() LocalPlayer.DevEnableMouseLock = T.ShiftLock end)
    end
end)

-- =============================================
-- WINDUI WINDOW BUILDER
-- =============================================
local Window = WindUI:CreateWindow({Title = "CrimsonX Hub (Ultimate)", Icon = "solar:skull-bold"})

-- TAB 1: FARMING
local FarmTab = Window:Tab({Title="Farm", Icon="solar:widget-bold"})
FarmTab:Toggle({Title="Auto Farm & Fix (Limit 5 Gen & Evade)", Callback = function(v) 
    T.AutoFarm = v 
    if v then CompletedGens = 0 end -- Reset hitungan saat dinyalakan ulang
end})

-- TAB 2: ESP (DIPISAH)
local EspTab = Window:Tab({Title="ESP Visuals", Icon="solar:eye-bold"})
EspTab:Toggle({Title="ESP Survivor (Hijau + HP)", Callback = function(v) T.EspSurvivor = v end})
EspTab:Toggle({Title="ESP Killer (Merah)", Callback = function(v) T.EspKiller = v end})
EspTab:Toggle({Title="ESP Generator (Biru + %)", Callback = function(v) T.EspGen = v end})
EspTab:Toggle({Title="ESP Hook (Kuning)", Callback = function(v) T.EspHook = v end})

-- TAB 3: AIMBOT & SILENT AIM
local AimTab = Window:Tab({Title="Aimbot", Icon="solar:target-bold"})
AimTab:Toggle({Title = "Silent Aim (Peluru Belok ke Killer)", Callback = function(v) T.AimLock = v end})
AimTab:Toggle({Title = "Aimbot (Kamera Kunci ke Killer)", Callback = function(v) T.AimbotCamera = v end})

-- TAB 4: PLAYER
local PlayerTab = Window:Tab({Title="Player", Icon="solar:user-bold"})

PlayerTab:Input({
    Title = "Masukkan Speed (Speed Hack)",
    Default = "16",
    Callback = function(v) PlayerMod.TargetSpeed = tonumber(v) or 16 end
})
PlayerTab:Toggle({Title = "Aktifkan Speed", Callback = function(v) T.SpeedEnabled = v end})
PlayerTab:Toggle({Title = "Noclip (Tembus Tembok)", Callback = function(v) T.Noclip = v end})
PlayerTab:Toggle({Title = "Force ShiftLock", Callback = function(v) T.ShiftLock = v end})

print("[CrimsonX] Full Updated Engine Ready!")
