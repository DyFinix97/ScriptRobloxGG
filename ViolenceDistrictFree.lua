--[[
    ╔══════════════════════════════════════╗
    ║        CrimsonX Hub v6.2             ║
    ║  Fininshline + Auto Open Door        ║
    ║  + Advanced Skill Check Calibration  ║
    ╚══════════════════════════════════════╝
]]

-- =============================================
-- SERVICES & LOCALS
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
-- STATE MANAGER
-- =============================================
local T = {
    AutoFarm=false, AutoHook=false, LoopTele=false,
    SCOffset = 105, -- Default tengah untuk Skill Check
    SCRange = 12    -- Lebar Hitbox Skill Check
}

local ActiveGenerators     = {}
local CompletedGenIDs      = {}
local COMPLETED_LIMIT      = 5
local CurrentGen           = nil

local SCClickDebounce      = false
local HookDebounce         = false
local SelectedTarget       = nil

-- =============================================
-- UTILITIES: UI CLICKER
-- =============================================
local function GetOrangeButton()
    local pg   = LocalPlayer.PlayerGui
    local root = pg:FindFirstChild("Survivor-mob", true)
    if not root then return nil end
    if root:IsA("GuiButton") then return root end
    return root:FindFirstChildWhichIsA("GuiButton", true) or root
end

local function ClickBtn(btn)
    if not btn or not btn.Visible then return end
    local p   = btn.AbsolutePosition
    local s   = btn.AbsoluteSize
    local ins = GuiService:GetGuiInset()
    local cx  = p.X + s.X*0.5 + ins.X
    local cy  = p.Y + s.Y*0.5 + ins.Y
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true,  game, 0)
        task.wait(0.01) -- Dibuat super cepat
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
    end)
end

-- =============================================
-- GENERATOR UTILITIES
-- =============================================
local function RefreshGenerators()
    ActiveGenerators = {}
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name == "Generator" and not CompletedGenIDs[tostring(obj)] then
            table.insert(ActiveGenerators, obj)
        end
    end
end

local function GetGenPart(gen)
    if gen:IsA("BasePart") then return gen end
    return gen:FindFirstChild("HumanoidRootPart")
        or gen:FindFirstChild("Main")
        or gen:FindFirstChildWhichIsA("BasePart", true)
end

local function GetGenProgress(gen)
    for _, n in ipairs({"RepairProgress","Progress","Percent","ProgressValue"}) do
        local a = gen:GetAttribute(n)
        if type(a)=="number" then return math.clamp(math.floor(a), 0, 100) end
        local v = gen:FindFirstChild(n)
        if v and (v:IsA("NumberValue") or v:IsA("IntValue")) then
            return math.clamp(math.floor(v.Value), 0, 100)
        end
    end
    return 0
end

local function CountCompleted()
    local n = 0
    for _ in pairs(CompletedGenIDs) do n = n + 1 end
    return n
end

-- =============================================
-- TELEPORTATIONS
-- =============================================
local function TeleportBesideGen(genPart)
    local char = LocalPlayer.Character; if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    pcall(function() hrp.CFrame = CFrame.new(genPart.Position + Vector3.new(4, 3.5, 0)) end)
end

local function TeleportEvade(genPart)
    local char = LocalPlayer.Character; if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    pcall(function() hrp.CFrame = CFrame.new(genPart.Position + Vector3.new(0, 150, 0)) end)
end

local function SafeTeleport(targetCFrame)
    local char = LocalPlayer.Character; if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    pcall(function() hrp.CFrame = targetCFrame * CFrame.new(0, 3.5, 0) end)
end

local function TeleportToFinishline()
    local char = LocalPlayer.Character; if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    
    local targetPart = nil
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name == "Fininshline" and obj:IsA("BasePart") then
            targetPart = obj
            break 
        end
    end
    
    if targetPart then
        pcall(function() hrp.CFrame = targetPart.CFrame * CFrame.new(0, 3.5, 0) end)
        WindUI:Notify({Title="CrimsonX", Content="Teleport ke Fininshline! Berinteraksi..."})
        
        task.spawn(function()
            for i = 1, 20 do 
                ClickBtn(GetOrangeButton())
                task.wait(0.2)
            end
        end)
    else
        WindUI:Notify({Title="Error", Content="Part 'Fininshline' tidak ditemukan di map!"})
    end
end

local function IsKillerNear(genPart, radius)
    if not genPart then return false end
    for _, p in pairs(Players:GetPlayers()) do
        if p == LocalPlayer or not p.Character then continue end
        if p.Team and p.Team.Name:lower():find("killer") then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position - genPart.Position).Magnitude <= radius then
                return true
            end
        end
    end
    return false
end

-- =============================================
-- [STEP 4] AUTO PERFECT SKILL CHECK (ADJUSTABLE)
-- =============================================
local function GetSkillCheckGui()
    local pg = LocalPlayer.PlayerGui
    local prompt = pg:FindFirstChild("SkillCheckPromptGui", true)
    if not prompt then return nil, nil, nil end
    local check = prompt:FindFirstChild("Check")
    if not check or not check.Visible then return nil, nil, nil end
    local line = check:FindFirstChild("Line")
    local goal = check:FindFirstChild("Goal")
    if not line or not goal then return nil, nil, nil end
    return check, line, goal
end

local function IsNeedleInArc(line, goal)
    local lr = line.Rotation % 360
    local gr = goal.Rotation % 360
    
    -- Menggunakan sistem offset dinamis agar bisa diatur di UI
    local center = (gr + T.SCOffset) % 360
    local ss = (center - T.SCRange) % 360
    local se = (center + T.SCRange) % 360
    
    if ss < se then 
        return lr >= ss and lr <= se 
    else 
        return lr >= ss or lr <= se 
    end
end

RunService.Heartbeat:Connect(function()
    if not T.AutoFarm or SCClickDebounce then return end
    local check, line, goal = GetSkillCheckGui()
    if not check then return end
    
    if IsNeedleInArc(line, goal) then
        SCClickDebounce = true
        ClickBtn(GetOrangeButton()) 
        task.wait(0.2) -- Turunkan delay sedikit biar cepat respons kalau ada double skill check
        SCClickDebounce = false
    end
end)

-- =============================================
-- MAIN AUTO FARM LOOP
-- =============================================
task.spawn(function()
    local lastPct = 0
    local lastTime = tick()
    local hasTeleportedToGen = false
    local hasStartedRepair = false

    while task.wait(0.05) do
        if not T.AutoFarm then 
            CurrentGen = nil; hasTeleportedToGen = false; hasStartedRepair = false; continue 
        end

        if CountCompleted() >= COMPLETED_LIMIT then
            T.AutoFarm = false
            WindUI:Notify({Title="CrimsonX", Content="5 Generator Selesai! Menuju Fininshline."})
            TeleportToFinishline()
            continue 
        end

        local char = LocalPlayer.Character; if not char then continue end
        local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then continue end

        if not CurrentGen or GetGenProgress(CurrentGen) >= 100 then
            if CurrentGen then 
                CompletedGenIDs[tostring(CurrentGen)] = true 
                WindUI:Notify({Title="CrimsonX", Content="Gen Selesai: " .. CountCompleted() .. "/5"})
            end
            RefreshGenerators()
            
            local bestGen, bestDist = nil, math.huge
            for _, gen in ipairs(ActiveGenerators) do
                if GetGenProgress(gen) < 100 then
                    local part = GetGenPart(gen)
                    if part then
                        local d = (part.Position - hrp.Position).Magnitude
                        if d < bestDist then bestDist = d; bestGen = gen end
                    end
                end
            end
            
            CurrentGen = bestGen
            hasTeleportedToGen = false
            hasStartedRepair = false
            lastPct = 0
        end

        if not CurrentGen then continue end
        local genPart = GetGenPart(CurrentGen)
        if not genPart then continue end

        if IsKillerNear(genPart, 25) then
            TeleportEvade(genPart)
            hasTeleportedToGen = false 
            hasStartedRepair = false
            continue
        end

        local dist = (hrp.Position - genPart.Position).Magnitude
        if dist > 8 and not hasTeleportedToGen then
            TeleportBesideGen(genPart)
            hasTeleportedToGen = true
            hasStartedRepair = false
            task.wait(0.5) 
            continue
        end

        if GetSkillCheckGui() or SCClickDebounce then 
            lastTime = tick() 
            continue 
        end

        local now = tick()
        if now - lastTime >= 0.6 then
            local currentPct = GetGenProgress(CurrentGen)

            if not hasStartedRepair then
                ClickBtn(GetOrangeButton())
                hasStartedRepair = true
            else
                if currentPct > lastPct then
                    -- Diam
                elseif currentPct <= lastPct and currentPct < 100 then
                    ClickBtn(GetOrangeButton())
                end
            end

            lastPct = currentPct
            lastTime = now
        end
    end
end)

-- =============================================
-- AUTO ESCAPE HOOK
-- =============================================
task.spawn(function()
    while task.wait(0.4) do
        if not T.AutoHook or HookDebounce then continue end
        local char = LocalPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local hooked = (char:GetAttribute("IsHooked") or char:GetAttribute("Hooked")) ~= nil
        if not hooked then
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj.Name == "Hook" then
                    local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
                    if part and (part.Position - hrp.Position).Magnitude <= 6 then
                        hooked = true; break
                    end
                end
            end
        end
        if hooked then
            HookDebounce = true; ClickBtn(GetOrangeButton()); task.wait(0.1); HookDebounce = false
        end
    end
end)

-- =============================================
-- PLAYER TELEPORT LOGIC
-- =============================================
local function GetPlayerNames()
    local names = {}
    for _,p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(names, p.Name) end
    end
    return #names > 0 and names or {"(tidak ada player)"}
end

local function TeleportToTarget()
    if not SelectedTarget then return end
    local tp = Players:FindFirstChild(SelectedTarget)
    if not tp or not tp.Character then return end
    local tHRP = tp.Character:FindFirstChild("HumanoidRootPart"); if not tHRP then return end
    SafeTeleport(tHRP.CFrame)
end

task.spawn(function()
    while task.wait(1) do if T.LoopTele and SelectedTarget then TeleportToTarget() end end
end)

-- =============================================
-- UI / WINDUI CONSTRUCTION
-- =============================================
local Window = WindUI:CreateWindow({
    Title="CrimsonX Hub", Icon="solar:skull-bold", Folder="CrimsonX", NewElements=true,
    OpenButton={
        Title="CrimsonX", CornerRadius=UDim.new(1,0), StrokeThickness=2,
        Enabled=true, Draggable=true, OnlyMobile=false, Scale=0.5,
        Color=ColorSequence.new(Color3.fromHex("#C0392B"), Color3.fromHex("#8E44AD")),
    },
    Topbar={Height=44, ButtonsType="Mac"},
})

-- ── TAB FARM ────────────────────────────────
local FarmTab = Window:Tab({Title="Farm", Icon="solar:widget-bold", Border=true})
local FarmSec = FarmTab:Section({Title="Generator Farm"})

FarmSec:Toggle({
    Title="Auto Farm Generator (5 Gen)",
    Callback=function(v)
        T.AutoFarm = v
        if not v then CurrentGen = nil end
    end,
})

FarmSec:Button({
    Title="Reset Counter Generator (0/5)", Icon="solar:restart-bold",
    Callback=function()
        CompletedGenIDs={}; CurrentGen=nil
        RefreshGenerators()
        WindUI:Notify({Title="CrimsonX", Content="Counter reset menjadi 0/5!"})
    end,
})

FarmSec:Toggle({ Title="Auto Escape Hook", Callback=function(v) T.AutoHook=v end })

FarmSec:Space()
FarmSec:Slider({
    Title="Timing Skill Check (Atur Jika Meleset)",
    Min=50, Max=160, Default=105, Step=1,
    Callback=function(v) 
        T.SCOffset = v 
    end
})

FarmSec:Slider({
    Title="Lebar Area Hitbox",
    Min=5, Max=30, Default=12, Step=1,
    Callback=function(v) 
        T.SCRange = v 
    end
})

-- ── TAB MISC ────────────────────────────────
local MiscTab = Window:Tab({Title="Misc", Icon="solar:settings-bold", Border=true})

local TeleSec = MiscTab:Section({Title="Teleport Player"}) 
local playerListCache = GetPlayerNames()
SelectedTarget = playerListCache[1] ~= "(tidak ada player)" and playerListCache[1] or nil

local TeleDropdown = TeleSec:Dropdown({ Title="Pilih Target", Options=playerListCache, Default=playerListCache[1], Multi=false, Callback=function(v) local name = (type(v)=="table") and v[1] or tostring(v); if name ~= "(tidak ada player)" then SelectedTarget = name end end })
task.defer(function() pcall(function() TeleDropdown:Refresh(playerListCache) end) end)

local function RefreshPlayerDrop()
    local names = GetPlayerNames(); playerListCache = names
    if SelectedTarget and not table.find(names, SelectedTarget) then SelectedTarget = names[1] ~= "(tidak ada player)" and names[1] or nil end
    pcall(function() TeleDropdown:Refresh(names) end)
end

Players.PlayerAdded:Connect(function() task.wait(1); RefreshPlayerDrop() end)
Players.PlayerRemoving:Connect(function() task.wait(0.5); RefreshPlayerDrop() end)

TeleSec:Button({ Title="Teleport Sekarang", Icon="solar:map-arrow-right-bold", Callback=function() if not SelectedTarget then return end TeleportToTarget(); WindUI:Notify({Title="CrimsonX", Content="Teleport ke "..SelectedTarget}) end })
