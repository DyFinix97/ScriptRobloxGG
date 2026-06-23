-- ========================================================== --
-- ||     CRIMSONX HUB - FIXED MOBILE ORANGE BUTTON (V8)   || --
-- ||       MODDED BY GEMINI: LAG PREDICTION & TP FIX      || --
-- ========================================================== --

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService          = game:GetService("GuiService")
local CoreGui             = game:GetService("CoreGui")
local Lighting            = game:GetService("Lighting")
local LocalPlayer         = Players.LocalPlayer

-- // CONFIGURATIONS //
_G.CrimsonX_Config = _G.CrimsonX_Config or {
    Toggles = { AutoFarm = false, AutoFix = false, Esp = false, Predict = false, Speed = false },
    SpeedValue = 16
}
local Toggles = _G.CrimsonX_Config.Toggles

local FinishedGenerators = {}
local CachedHighlights   = {}
local CachedBillboards   = {}
local HeartbeatConn      = nil

-- ==================================================
-- ||    FIX: MOBILE CLICKER UTILITY FUNCTIONS     ||
-- ==================================================
local function ClickMobileOrangeButton()
    local btn = LocalPlayer.PlayerGui:FindFirstChild("Survivor-mob", true) 
        or LocalPlayer.PlayerGui:FindFirstChild("check", true)
        
    if btn then
        if not btn:IsA("GuiButton") then
            btn = btn:FindFirstChildWhichIsA("GuiButton", true) or btn
        end
        
        if btn and btn.Visible then
            local p = btn.AbsolutePosition
            local s = btn.AbsoluteSize
            local i = GuiService:GetGuiInset()
            local cx = p.X + (s.X / 2) + i.X
            local cy = p.Y + (s.Y / 2) + i.Y
            
            VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
            task.wait(0.01)
            VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
            return true
        end
    end
    return false
end

local function ClickMobileSkillCheckButton()
    local btn = LocalPlayer.PlayerGui:FindFirstChild("check", true) 
        or LocalPlayer.PlayerGui:FindFirstChild("Survivor-mob", true)
        
    if btn then
        if not btn:IsA("GuiButton") then
            btn = btn:FindFirstChildWhichIsA("GuiButton", true) or btn
        end
        
        if btn and btn.Visible then
            local p = btn.AbsolutePosition
            local s = btn.AbsoluteSize
            local i = GuiService:GetGuiInset()
            local cx = p.X + (s.X / 2) + i.X
            local cy = p.Y + (s.Y / 2) + i.Y
            
            VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
            task.wait(0.01)
            VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
            return true
        end
    end
    return false
end

local function PressSpace()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
    task.wait(0.01)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
end

-- ==========================================
-- || CORE FUNCTION: GENERATOR & PROGRESS  ||
-- ==========================================
local function GetGeneratorPart(obj)
    if obj.Name == "Generator" then
        if obj:IsA("BasePart") then return obj
        elseif obj:IsA("Model") then
            return obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Main") or obj:FindFirstChildWhichIsA("BasePart", true)
        end
    end
    return nil
end

local function GetGenProgress(obj)
    local progressVal = obj:FindFirstChild("Progress") or obj:FindFirstChild("Percent") or obj:FindFirstChild("ProgressValue")
    if progressVal and (progressVal:IsA("NumberValue") or progressVal:IsA("IntValue")) then
        return math.clamp(math.floor(progressVal.Value), 0, 100)
    end
    local attr = obj:GetAttribute("Progress") or obj:GetAttribute("Percent")
    if attr then return math.clamp(math.floor(attr), 0, 100) end
    return nil
end

-- ==========================================
-- || ADVANCED ESP ENGINE (HEALTH & BG)    ||
-- ==========================================
local function ApplyAdvancedESP(player, character, color)
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    local hrp = character.HumanoidRootPart
    local humanoid = character:FindFirstChildWhichIsA("Humanoid")
    
    if not CachedHighlights[character] then
        local h = Instance.new("Highlight")
        h.Name = "ESP_Highlight"
        h.FillColor = color
        h.OutlineColor = Color3.new(1, 1, 1)
        h.FillTransparency = 0.6
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Parent = character
        CachedHighlights[character] = h
    end

    if not CachedBillboards[character] then
        local bgui = Instance.new("BillboardGui")
        bgui.Size = UDim2.new(0, 130, 0, 45)
        bgui.AlwaysOnTop = true
        bgui.ExtentsOffset = Vector3.new(0, 3, 0)
        bgui.Adornee = hrp
        
        local txt = Instance.new("TextLabel", bgui)
        txt.Size = UDim2.new(1, 0, 0.5, 0)
        txt.BackgroundTransparency = 1
        txt.Text = player.Name .. " [" .. (player.Team and player.Team.Name or "Unknown") .. "]"
        txt.TextColor3 = color
        txt.Font = Enum.Font.GothamBold
        txt.TextSize = 11
        
        local healthBG = Instance.new("Frame", bgui)
        healthBG.Size = UDim2.new(0.8, 0, 0.15, 0)
        healthBG.Position = UDim2.new(0.1, 0, 0.6, 0)
        healthBG.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        
        local healthBar = Instance.new("Frame", healthBG)
        healthBar.Size = UDim2.new(1, 0, 1, 0)
        healthBar.BackgroundColor3 = color
        healthBar.BorderSizePixel = 0
        
        bgui.Parent = CoreGui
        CachedBillboards[character] = {Gui = bgui, Bar = healthBar, Label = txt}
    else
        local data = CachedBillboards[character]
        if humanoid and data then
            local healthRatio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
            data.Bar.Size = UDim2.new(healthRatio, 0, 1, 0)
            data.Label.Text = player.Name .. " (" .. math.floor(humanoid.Health) .. " HP)"
        end
    end
end

local function ApplyGeneratorESP(genPart, progress)
    if not genPart then return end
    if not CachedBillboards[genPart] then
        local bgui = Instance.new("BillboardGui")
        bgui.Size = UDim2.new(0, 100, 0, 30)
        bgui.AlwaysOnTop = true
        bgui.ExtentsOffset = Vector3.new(0, 4, 0)
        bgui.Adornee = genPart
        
        local txt = Instance.new("TextLabel", bgui)
        txt.Size = UDim2.new(1, 0, 1, 0)
        txt.BackgroundTransparency = 1
        txt.Text = "Generator\nProgress: " .. (progress or 0) .. "%"
        txt.TextColor3 = Color3.fromRGB(255, 170, 0)
        txt.Font = Enum.Font.GothamBold
        txt.TextSize = 11
        
        bgui.Parent = CoreGui
        CachedBillboards[genPart] = txt
        
        local h = Instance.new("Highlight")
        h.FillColor = Color3.fromRGB(150, 0, 255)
        h.FillTransparency = 0.6
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Adornee = genPart
        h.Parent = genPart
    else
        if progress then CachedBillboards[genPart].Text = "Generator\nProgress: " .. progress .. "%" end
    end
end

local function GetKillerHRP()
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Team and p.Team.Name:lower():find("killer") and p.Character then
            return p.Character:FindFirstChild("HumanoidRootPart")
        end
    end
    return nil
end

-- ==========================================
-- || UI WINDOW SETUP                      ||
-- ==========================================
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
local Window = WindUI:CreateWindow({Title = "CrimsonX Hub 🩸 (Lag Bypass)", Icon = "gamepad-2", Transparency = 0.2})
local Tab1 = Window:Tab({Title = "Main Hub", Icon = "home"})

local SecFarm = Tab1:Section({Title = "Farming System", TitleAlignment = "Left"})
SecFarm:Toggle({Title = "Auto Farm (Teleport Nempel & Fix)", Callback = function(v) Toggles.AutoFarm = v end})

local SecFix = Tab1:Section({Title = "Skill Check Logic", TitleAlignment = "Left"})
SecFix:Toggle({Title = "100% Predict Fix (Anti FPS Drop)", Callback = function(v) Toggles.AutoFix = v end})

local SecVis = Tab1:Section({Title = "Visuals (ESP)", TitleAlignment = "Left"})
SecVis:Toggle({Title = "Enable ESP (Custom Features)", Callback = function(v) Toggles.Esp = v end})

local SecEx = Tab1:Section({Title = "Player Exploits", TitleAlignment = "Left"})
SecEx:Toggle({Title = "Speed Hack", Callback = function(v) Toggles.Speed = v end})

-- ====================================================
-- || ENGINE 1: 100% PREDICT FIX (FPS DROP BYPASS)   ||
-- ====================================================
-- Helper untuk membaca zona melingkar 360 derajat
local function IsInAngleZone(target, startAngle, endAngle)
    if startAngle < endAngle then
        return target >= startAngle and target <= endAngle
    else
        return target >= startAngle or target <= endAngle
    end
end

-- dt (DeltaTime) berisi durasi ngelag frame terakhir (dibaca langsung dari sistem)
local function HeartbeatCheck(dt)
    if not Toggles.AutoFix then return end
    
    local prompt = LocalPlayer.PlayerGui:FindFirstChild("SkillCheckPromptGui", true)
    local check = prompt and prompt:FindFirstChild("Check")
    if check and check.Visible and LocalPlayer.Team and LocalPlayer.Team.Name == "Survivors" then
        local line = check:FindFirstChild("Line")
        local goal = check:FindFirstChild("Goal")
        if line and goal then
            local lr = line.Rotation % 360
            local gr = goal.Rotation % 360
            
            -- Zona asli Perfect (Telah dilebarkan sedikit 102 - 116 agar margin error aman)
            local gs = (gr + 102) % 360
            local ge = (gr + 116) % 360

            -- [LAG PREDICTION ENGINE]
            -- Menghitung jarum akan lompat ke mana di frame berikutnya akibat HP ngelag
            local needleSpeed = 190 -- Perkiraan rotasi jarum per detik
            local lagCompensation = (dt * needleSpeed) 
            local predictedRot = (lr + lagCompensation) % 360

            -- Pengecekan Ganda: Cek posisi SAAT INI atau prediksi posisi SAAT LAG
            if IsInAngleZone(lr, gs, ge) or IsInAngleZone(predictedRot, gs, ge) then
                PressSpace()
                ClickMobileSkillCheckButton()
                
                -- Putuskan loop saat berhasil tekan agar tidak double click
                if HeartbeatConn then 
                    HeartbeatConn:Disconnect() 
                    HeartbeatConn = nil 
                end
            end
        end
    end
end

local function WatchSkillCheckVisibility()
    task.spawn(function()
        while task.wait(0.1) do
            if Toggles.AutoFix and LocalPlayer.Team and LocalPlayer.Team.Name == "Survivors" then
                local prompt = LocalPlayer.PlayerGui:FindFirstChild("SkillCheckPromptGui", true)
                local check = prompt and prompt:FindFirstChild("Check")
                
                if check and check.Visible then
                    if not HeartbeatConn then
                        HeartbeatConn = RunService.Heartbeat:Connect(HeartbeatCheck)
                    end
                else
                    if HeartbeatConn then HeartbeatConn:Disconnect() HeartbeatConn = nil end
                end
            else
                if HeartbeatConn then HeartbeatConn:Disconnect() HeartbeatConn = nil end
            end
        end
    end)
end
WatchSkillCheckVisibility()

-- ESP Loop
RunService.RenderStepped:Connect(function()
    if Toggles.Esp then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local isKiller = p.Team and p.Team.Name:lower():find("killer")
                local color = isKiller and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 0)
                ApplyAdvancedESP(p, p.Character, color)
            end
        end
        for _, obj in pairs(workspace:GetDescendants()) do
            local genPart = GetGeneratorPart(obj)
            if genPart then ApplyGeneratorESP(genPart, GetGenProgress(obj) or 0) end
        end
    else
        for char, data in pairs(CachedBillboards) do
            if data.Gui then data.Gui:Destroy() end
            CachedBillboards[char] = nil
        end
        for char, h in pairs(CachedHighlights) do
            if h then h:Destroy() end
            CachedHighlights[char] = nil
        end
    end
end)

-- ==========================================
-- || ENGINE 2: SMART AUTO FARM (CLOSE TP) ||
-- ==========================================
task.spawn(function()
    while task.wait(0.5) do
        if Toggles.AutoFarm and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = LocalPlayer.Character.HumanoidRootPart
            
            -- [1] EVASION SYSTEM (Kabur dari killer)
            local killerHRP = GetKillerHRP()
            if killerHRP then
                local distToKiller = (hrp.Position - killerHRP.Position).Magnitude
                if distToKiller <= 18 then
                    hrp.CFrame = hrp.CFrame * CFrame.new(0, 150, 150)
                    task.wait(2)
                    continue
                end
            end

            -- [2] FARMING & TELEPORT LOGIC
            local closestGenPart = nil
            local distGen = math.huge
            local targetObj = nil
            
            for _, obj in pairs(workspace:GetDescendants()) do
                local genPart = GetGeneratorPart(obj)
                if genPart and not table.find(FinishedGenerators, genPart) then
                    local d = (genPart.Position - hrp.Position).Magnitude
                    if d < distGen then
                        distGen = d
                        closestGenPart = genPart
                        targetObj = obj
                    end
                end
            end
            
            if closestGenPart and targetObj then
                -- [MODIFIKASI TP]: CFrame.new(0, 0, 1.8) -> Bikin sangat menempel di depan generator!
                hrp.CFrame = closestGenPart.CFrame * CFrame.new(0, 0, 1.8)
                task.wait(0.4)
                
                local progress = GetGenProgress(targetObj) or 0
                if progress >= 100 then
                    table.insert(FinishedGenerators, closestGenPart)
                    continue
                end
                
                local promptUI = LocalPlayer.PlayerGui:FindFirstChild("SkillCheckPromptGui", true)
                local isFixing = promptUI and promptUI:FindFirstChild("Check") and promptUI.Check.Visible
                
                if not isFixing then
                    local clicked = ClickMobileOrangeButton()
                    task.wait(1)
                    
                    if not clicked then
                        local checkBtnAgain = LocalPlayer.PlayerGui:FindFirstChild("Survivor-mob", true)
                        if not (checkBtnAgain and checkBtnAgain.Visible) or progress >= 100 then
                            table.insert(FinishedGenerators, closestGenPart)
                        end
                    end
                end
            end
        end
    end
end)

-- ==========================================
-- || ENGINE 3: SPEED HACK                 ||
-- ==========================================
RunService.Heartbeat:Connect(function()
    if Toggles.Speed and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = _G.CrimsonX_Config.SpeedValue
    end
end)
