--[[
    ╔══════════════════════════════════════╗
    ║        CrimsonX Hub v3.0             ║
    ║    Violence District • Mobile        ║
    ╚══════════════════════════════════════╝
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
local Camera              = workspace.CurrentCamera

-- =============================================
-- CONFIG GLOBAL
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

-- =============================================
-- STORAGE
-- =============================================
local FinishedGenerators = {}
local ESPObjects         = {}  -- [instance] = {highlight, billboard}
local HeartbeatConn      = nil
local LastTeleport       = 0
local TELE_CD            = 1.2

-- =============================================
-- 1. LOAD WINDUI (ANTI-CRASH)
-- =============================================
local WindUI
do
    local urls = {
        "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua",
        "https://raw.githubusercontent.com/Footagesus/WindUI/refs/heads/main/dist/main.lua",
    }
    for _, url in ipairs(urls) do
        local ok = pcall(function()
            WindUI = loadstring(game:HttpGet(url, true))()
        end)
        if ok and WindUI then break end
    end
    if not WindUI then
        warn("[CrimsonX] GAGAL LOAD WINDUI!")
        return
    end
end

-- =============================================
-- 2. UI WINDOW
-- =============================================
local Window = WindUI:CreateWindow({
    Title        = "CrimsonX Hub",
    Icon         = "skull",
    Transparency = 0.15,
    Theme        = "Dark",
})
if Window.Open then Window:Open() elseif Window.Show then Window:Show() end

local TabFarm  = Window:Tab({ Title = "Auto Farm",     Icon = "wrench"    })
local TabESP   = Window:Tab({ Title = "ESP",           Icon = "eye"       })
local TabAim   = Window:Tab({ Title = "Silent Aim",    Icon = "crosshair" })
local TabInfo  = Window:Tab({ Title = "Info",          Icon = "info"      })

-- =============================================
-- 3. CLICK ENGINE (VIOLENCE DISTRICT SPECIFIC)
-- =============================================
-- Path yang benar dari reference script: Survivor-mob > Controls > action > check
local function FindRepairButton()
    -- Metode 1: Path spesifik Violence District
    local mob = LocalPlayer.PlayerGui:FindFirstChild("Survivor-mob", true)
    if mob then
        local btn = mob:FindFirstChild("check", true)
            or mob:FindFirstChild("action", true)
        if btn and btn:IsA("GuiButton") and btn.Visible then
            return btn
        end
        -- Cari button di dalam Controls
        local controls = mob:FindFirstChild("Controls", true)
        if controls then
            local action = controls:FindFirstChild("action", true)
            if action then
                local check = action:FindFirstChild("check")
                if check and check:IsA("GuiButton") and check.Visible then
                    return check
                end
                -- Ambil button pertama yang visible di dalam action
                for _, v in pairs(action:GetDescendants()) do
                    if v:IsA("GuiButton") and v.Visible then return v end
                end
            end
        end
    end

    -- Metode 2: Cari button orange/kuning (tombol repair) di semua PlayerGui
    local bestBtn = nil
    for _, gui in pairs(LocalPlayer.PlayerGui:GetChildren()) do
        -- Skip WindUI sendiri
        if gui.Name:find("Wind") or gui.Name:find("Crimson") then continue end
        for _, v in pairs(gui:GetDescendants()) do
            if v:IsA("GuiButton") and v.Visible and v.Active ~= false then
                local r = v.BackgroundColor3.R
                local g = v.BackgroundColor3.G
                local b = v.BackgroundColor3.B
                -- Orange / kuning = tombol repair
                if r > 0.55 and g > 0.25 and b < 0.35 then
                    return v
                end
                if not bestBtn then bestBtn = v end
            end
        end
    end
    return bestBtn
end

local function ClickButton(btn)
    if not btn then return false end

    -- Cara 1: firesignal (paling reliable di Delta)
    if type(firesignal) == "function" then
        pcall(firesignal, btn.MouseButton1Click)
        pcall(firesignal, btn.Activated)
        return true
    end

    -- Cara 2: getconnections + Fire
    if type(getconnections) == "function" then
        pcall(function()
            for _, c in pairs(getconnections(btn.MouseButton1Click)) do pcall(c.Fire, c) end
            for _, c in pairs(getconnections(btn.Activated))         do pcall(c.Fire, c) end
        end)
        return true
    end

    -- Cara 3: VirtualInputManager fallback
    pcall(function()
        local pos   = btn.AbsolutePosition
        local size  = btn.AbsoluteSize
        local inset = GuiService:GetGuiInset()
        local cx = pos.X + size.X * 0.5 + inset.X
        local cy = pos.Y + size.Y * 0.5 + inset.Y + 36
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true,  game, 0)
        task.wait(0.015)
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
    end)
    return true
end

local function DoRepair()
    local btn = FindRepairButton()
    return ClickButton(btn)
end

-- =============================================
-- 4. SKILL CHECK ENGINE (FPS-INDEPENDENT PERFECT)
-- =============================================
-- Cari skill check widget secara dinamis
local function FindSkillCheck()
    for _, gui in pairs(LocalPlayer.PlayerGui:GetChildren()) do
        if gui.Name:find("Wind") or gui.Name:find("Crimson") then continue end
        local check = gui:FindFirstChild("Check", true)
            or gui:FindFirstChild("SkillCheck", true)
            or gui:FindFirstChild("RepairCheck", true)
        if check and check.Visible then
            -- Needle: jarum yang berputar
            local needle = check:FindFirstChild("Line")
                or check:FindFirstChild("Needle")
                or check:FindFirstChild("Arrow")
            -- Goal: zona putih target
            local goal = check:FindFirstChild("Goal")
                or check:FindFirstChild("Target")
                or check:FindFirstChild("Zone")
                or check:FindFirstChild("Perfect")
            if needle and goal then
                return check, needle, goal
            end
        end
    end
    return nil, nil, nil
end

-- Cek apakah angle berada dalam arc (searah jarum jam)
local function InArc(angle, aStart, aEnd)
    angle  = angle  % 360
    aStart = aStart % 360
    aEnd   = aEnd   % 360
    if aStart <= aEnd then
        return angle >= aStart and angle <= aEnd
    else
        return angle >= aStart or angle <= aEnd
    end
end

-- Ukur kecepatan angular needle (derajat/detik)
local NeedleVelocity = 0
local LastNeedleAngle = nil
local LastNeedleTime  = nil

local function UpdateNeedleVelocity(needle)
    local now = tick()
    local ang = needle.Rotation % 360
    if LastNeedleAngle then
        local dt   = now - LastNeedleTime
        local dAng = (ang - LastNeedleAngle + 360) % 360
        if dAng > 180 then dAng = dAng - 360 end  -- handle wrap
        NeedleVelocity = dt > 0 and (dAng / dt) or NeedleVelocity
    end
    LastNeedleAngle = ang
    LastNeedleTime  = now
end

-- Heartbeat: cek setiap frame
local function OnHeartbeat()
    if not T.AutoFix then return end

    local check, needle, goal = FindSkillCheck()
    if not check or not needle or not goal then return end

    -- Update velocity untuk prediksi
    UpdateNeedleVelocity(needle)

    local needleAng = needle.Rotation % 360
    local goalAng   = goal.Rotation   % 360

    -- Estimasi ukuran zona putih dari AbsoluteSize goal
    -- Zona putih biasanya ~15-20 derajat
    local goalHalf = 10  -- derajat setengah arc

    -- Prediksi posisi needle di frame berikutnya (kompensasi latency ~2 frame)
    local frameTime = 1/60
    local predictedAngle = (needleAng + NeedleVelocity * frameTime * 2) % 360

    local arcS = (goalAng - goalHalf) % 360
    local arcE = (goalAng + goalHalf) % 360

    -- Klik saat needle (atau prediksinya) masuk zona
    if InArc(needleAng, arcS, arcE) or InArc(predictedAngle, arcS, arcE) then
        DoRepair()
        -- Reset dan disconnect setelah klik
        LastNeedleAngle = nil
        LastNeedleTime  = nil
        if HeartbeatConn then
            HeartbeatConn:Disconnect()
            HeartbeatConn = nil
        end
    end
end

-- Loop monitor skill check widget
task.spawn(function()
    while task.wait(0.05) do
        if T.AutoFix then
            local check, needle, goal = FindSkillCheck()
            if check and needle and goal then
                if not HeartbeatConn then
                    HeartbeatConn = RunService.Heartbeat:Connect(OnHeartbeat)
                end
            else
                if HeartbeatConn then
                    HeartbeatConn:Disconnect()
                    HeartbeatConn = nil
                end
            end
        else
            if HeartbeatConn then
                HeartbeatConn:Disconnect()
                HeartbeatConn = nil
            end
        end
