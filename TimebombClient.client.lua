--[[
	Timebomb Duels - Client
	Place in: StarterPlayer > StarterPlayerScripts

	Shows the HUD (fuse timer, round timer, score) and an Auto-Play button
	that hands full control of the character to the pro bot (server-driven).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

-- ---------------------------------------------------------------------------
-- Build HUD
-- ---------------------------------------------------------------------------
local hud = Instance.new("ScreenGui")
hud.Name = "TimebombHud"
hud.ResetOnSpawn = false
hud.Parent = player:WaitForChild("PlayerGui")

local function makeLabel(name, y, size, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.new(0, 220, 0, size)
	label.Position = UDim2.new(0, 10, 0, y)
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = ""
	label.Parent = hud
	return label
end

local fuseLabel = makeLabel("FuseLabel", 40, 30, Color3.new(1, 0.4, 0.2))
local roundLabel = makeLabel("RoundLabel", 80, 30, Color3.new(0.4, 0.8, 1))
local scoreLabel = makeLabel("ScoreLabel", 120, 30, Color3.new(0.4, 1, 0.5))

-- ---------------------------------------------------------------------------
-- Auto-Play button
-- ---------------------------------------------------------------------------
local button = Instance.new("TextButton")
button.Name = "AutoPlayButton"
button.Size = UDim2.new(0, 200, 0, 40)
button.Position = UDim2.new(0, 10, 0, 170)
button.BackgroundColor3 = Color3.new(0.2, 0.2, 0.25)
button.TextColor3 = Color3.new(1, 1, 1)
button.Text = "Auto-Play: ON"
button.TextScaled = true
button.Font = Enum.Font.GothamBold
button.Parent = hud

local autoPlayOn = true

local function setAutoPlay(on)
	autoPlayOn = on
	button.Text = "Auto-Play: " .. (on and "ON" or "OFF")
end

-- Request the server to hand/return this seat to the pro bot.
local function requestAutoplay(on)
	local remote = ReplicatedStorage:FindFirstChild("AutoplayToggle")
	if remote then
		remote:FireServer(on)
	end
end

button.Activated:Connect(function()
	setAutoPlay(not autoPlayOn)
	requestAutoplay(autoPlayOn)
end)

-- ---------------------------------------------------------------------------
-- HUD sync: read server-pushed attributes each frame and render them.
-- ---------------------------------------------------------------------------
local function syncHud()
	local fuseLbl = player:GetAttribute("TimebombFuse")
	if fuseLbl then fuseLabel.Text = fuseLbl end
	local roundLbl = player:GetAttribute("TimebombRound")
	if roundLbl then roundLabel.Text = roundLbl end
	local scoreLbl = player:GetAttribute("TimebombScore")
	if scoreLbl then scoreLabel.Text = scoreLbl end
end

RunService.Heartbeat:Connect(syncHud)

-- Keep Auto-Play state across respawns.
player.CharacterAdded:Connect(function()
	setAutoPlay(autoPlayOn)
end)

-- Fire initial intent to the server.
requestAutoplay(autoPlayOn)
