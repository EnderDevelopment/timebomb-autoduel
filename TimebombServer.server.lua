--[[
	Timebomb Duels - Server
	Place in: ServerScriptService

	Two-player arena duels around a timebomb. Auto-Play ("pro bot") takes
	over any empty seat so the game always plays itself like a pro.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Remote used by clients to toggle Auto-Play for their seat.
local autoplayRemote = Instance.new("RemoteEvent")
autoplayRemote.Name = "AutoplayToggle"
autoplayRemote.Parent = ReplicatedStorage

-- ---------------------------------------------------------------------------
-- Settings (tune these)
-- ---------------------------------------------------------------------------
local settings = {
	roundLength = 60,        -- seconds a round must survive
	fuseTime = 12,           -- seconds of bomb fuse
	blastRadius = 18,        -- radius of the blast
	winScore = 3,            -- points needed to win the match
	botThinkInterval = 0.25, -- seconds between bot decisions
}

-- Arena parts
local ARENA_MODEL = "Arena"
local P1_NAME = "Player1Pos"
local P2_NAME = "Player2Pos"
local BOMB_NAME = "BombSpawn"
local BOMB_PART_NAME = "Bomb"

local arenaModel = workspace:WaitForChild(ARENA_MODEL)
local p1Pad = arenaModel:WaitForChild(P1_NAME)
local p2Pad = arenaModel:WaitForChild(P2_NAME)
local bombSpawn = arenaModel:WaitForChild(BOMB_NAME)

local bomb
local fuse = bombSpawn.Position

local points = {}          -- [userId] = score
local seatOwner = {}       -- seat: 1 or 2 -> player
local botSeat = 0          -- seat controlled by the pro bot
local roundActive = false
local roundTimer = 0
local fuseActive = false
local fuseTimer = 0
local matchOver = false

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function makeBomb()
	if bomb then bomb:Destroy() end
	bomb = Instance.new("Part")
	bomb.Name = BOMB_PART_NAME
	bomb.Anchored = true
	bomb.CanCollide = false
	bomb.Material = Enum.Material.Neon
	bomb.BrickColor = BrickColor.new("Institutional white")
	bomb.Size = Vector3.new(3, 3, 3)
	bomb.Shape = Enum.PartType.Ball
	bomb.Position = bombSpawn.Position
	bomb.Parent = workspace

	local light = Instance.new("PointLight")
	light.Brightness = 1
	light.Range = 14
	light.Color = Color3.new(1, 0.3, 0.1)
	light.Parent = bomb

	fuse = bombSpawn.Position
end

local function rootOf(avatar)
	local root = avatar and (avatar:FindFirstChild("HumanoidRootPart")
		or avatar:FindFirstChild("Torso"))
	return root
end

local function avatarOf(player)
	if not player then return nil end
	local char = player.Character
	if not char then return nil end
	return rootOf(char)
end

local function dist2D(a, b)
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function inBlast(pos)
	return dist2D(pos, fuse) <= settings.blastRadius
end

local function inArena(pos)
	local minX = math.min(p1Pad.Position.X, p2Pad.Position.X) - 2
	local maxX = math.max(p1Pad.Position.X, p2Pad.Position.X) + 2
	local minZ = math.min(p1Pad.Position.Z, p2Pad.Position.Z) - 10
	local maxZ = math.max(p1Pad.Position.Z, p2Pad.Position.Z) + 10
	return pos.X >= minX and pos.X <= maxX
		and pos.Z >= minZ and pos.Z <= maxZ
end

local function seatOf(player)
	for seat, p in pairs(seatOwner) do
		if p == player then return seat end
	end
	return 0
end

local function otherSeat(seat)
	return seat == 1 and 2 or 1
end

local function seatSpawnPos(seat)
	return seat == 1 and p1Pad.Position or p2Pad.Position
end

local function updateHud(player, fuseSecs, roundSecs, scoreText)
	if not player then return end
	if fuseSecs then player:SetAttribute("TimebombFuse", ("Fuse %d"):format(math.ceil(fuseSecs))) end
	if roundSecs then player:SetAttribute("TimebombRound", ("Round %d"):format(math.ceil(roundSecs))) end
	if scoreText then player:SetAttribute("TimebombScore", scoreText) end
end

local function updateAllHud(scoreOverride)
	for _, p in pairs(seatOwner) do
		local score = points[p.UserId] or 0
		updateHud(p, fuseActive and fuseTimer or nil,
			roundActive and roundTimer or nil, scoreOverride or ("Score " .. score))
	end
end

-- ---------------------------------------------------------------------------
-- Round / match control
-- ---------------------------------------------------------------------------
local function forceRespawn(player)
	local seat = seatOf(player)
	if seat == 0 then return end
	if not player.Character then
		player:LoadCharacter()
		task.wait(0.2)
	end
	local root = avatarOf(player)
	if root then
		root.CFrame = CFrame.new(seatSpawnPos(seat))
		local hum = player.Character:FindFirstChild("Humanoid")
		if hum then hum.Health = hum.MaxHealth end
	end
end

local function resetRound(reason)
	print(("[Timebomb] %s"):format(reason))
	makeBomb()
	roundActive = true
	roundTimer = settings.roundLength
	fuseActive = false
	fuseTimer = 0
	for _, p in pairs(seatOwner) do
		forceRespawn(p)
	end
	updateAllHud()
end

local function endMatch(winner)
	matchOver = true
	roundActive = false
	fuseActive = false
	print(("[Timebomb] MATCH WON by %s!"):format(winner.Name))
	updateAllHud(winner.Name .. " WINS")
	task.wait(8)
	-- Restart fresh
	points = {}
	for _, p in pairs(Players:GetPlayers()) do
		points[p.UserId] = 0
	end
	matchOver = false
	resetRound("new match")
end

local function checkWinner()
	for userId, score in pairs(points) do
		if score >= settings.winScore then
			for _, p in pairs(seatOwner) do
				if p.UserId == userId then
					endMatch(p)
					return true
				end
			end
		end
	end
	return false
end

-- ---------------------------------------------------------------------------
-- Pro Bot ("Auto Play")
-- ---------------------------------------------------------------------------
local function botPlayer()
	return seatOwner[botSeat]
end

local function botMove(root, target)
	if not root then return end
	local look = CFrame.lookAt(root.Position,
		Vector3.new(target.X, root.Position.Y, target.Z))
	root.CFrame = look
	local diff = target - root.Position
	root.CFrame = root.CFrame + diff * 0.35
end

local function botThink()
	local player = botPlayer()
	if not player then return end
	local root = avatarOf(player)

	-- Ensure the bot has a character to move
	if not root then
		local dummy = workspace:FindFirstChild("BotDummy_" .. botSeat)
		if not dummy then
			dummy = Instance.new("Model")
			dummy.Name = "BotDummy_" .. botSeat
			local hrp = Instance.new("Part")
			hrp.Name = "HumanoidRootPart"
			hrp.Anchored = true
			hrp.CanCollide = false
			hrp.Transparency = 0.5
			hrp.Size = Vector3.new(2, 2, 1)
			hrp.CFrame = CFrame.new(seatSpawnPos(botSeat))
			hrp.Parent = dummy
			local hum = Instance.new("Humanoid")
			hum.Parent = dummy
			dummy.Parent = workspace
		end
		root = dummy:FindFirstChild("HumanoidRootPart")
	end
	if not root then return end

	-- Pro strategy
	local target
	if fuseActive and fuseTimer > 0 and roundActive then
		-- Sit just outside the blast radius but inside the arena
		local safeDist = settings.blastRadius + 2.5
		local offset = root.Position - fuse
		local dir = Vector3.new(offset.X, 0, offset.Z)
		if dir.Magnitude < 0.1 then dir = Vector3.new(1, 0, 0) end
		dir = dir.Unit
		target = fuse + dir * safeDist

		-- Stay inbounds
		target = Vector3.new(
			math.clamp(target.X, p1Pad.Position.X + 2, p2Pad.Position.X - 2),
			root.Position.Y,
			math.clamp(target.Z, p1Pad.Position.Z - 6, p2Pad.Position.Z + 6)
		)
	elseif roundActive then
		-- No threat: hold the best spot in the center
		local center = (p1Pad.Position + p2Pad.Position) / 2
		target = Vector3.new(center.X, root.Position.Y, center.Z)
	end

	if target then
		botMove(root, target)
	end
end

-- ---------------------------------------------------------------------------
-- Seat management
-- ---------------------------------------------------------------------------
local function manageSeats()
	-- Assign humans to empty seats
	for _, p in ipairs(Players:GetPlayers()) do
		if not p:IsA("Player") then continue end
		local assigned = seatOf(p) ~= 0
		if not assigned then
			for _, seat in ipairs({1, 2}) do
				if seatOwner[seat] == nil then
					seatOwner[seat] = p
					print(("[Timebomb] %s took seat %d"):format(p.Name, seat))
					break
				end
			end
		end
	end
	-- Bot fills any remaining empty seat
	if botSeat == 0 then
		for _, seat in ipairs({1, 2}) do
			if seatOwner[seat] == nil then
				botSeat = seat
				print(("[Timebomb] Auto-Play pro bot controls seat %d"):format(seat))
				break
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Player events
-- ---------------------------------------------------------------------------
local function onPlayerAdded(player)
	points[player.UserId] = 0
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		forceRespawn(player)
	end)
	player:LoadCharacter()
	manageSeats()
	if not roundActive and not matchOver then
		resetRound("starting round")
	end
end

local function onPlayerRemoving(player)
	local seat = seatOf(player)
	seatOwner[seat] = nil
	if seat == botSeat then botSeat = 0 end
	task.wait(1)
	manageSeats()
end

-- Handle Auto-Play toggle: hand the player's seat to the pro bot when ON.
autoplayRemote.OnServerEvent:Connect(function(player, on)
	local seat = seatOf(player)
	if seat == 0 then return end
	if on then
		-- The bot takes over this seat; the human char becomes the bot dummy.
		if botSeat ~= 0 and botSeat ~= seat then
			-- Only one bot at a time: keep current bot.
			return
		end
		botSeat = seat
		print(("[Timebomb] %s enabled Auto-Play (seat %d)"):format(player.Name, seat))
	else
		-- Return seat to the human if the bot currently owns it.
		if botSeat == seat then
			botSeat = 0
			print(("[Timebomb] %s disabled Auto-Play (seat %d)"):format(player.Name, seat))
		end
	end
	manageSeats()
end)

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayerAdded(p)
end
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- ---------------------------------------------------------------------------
-- Main loop
-- ---------------------------------------------------------------------------
makeBomb()
resetRound("start")

game:GetService("RunService").Heartbeat:Connect(function()
	if matchOver then return end
	manageSeats()

	if not roundActive then return end

	if fuseActive then
		fuseTimer -= task.wait()
		-- Survive check: anyone in the blast at the end dies, other scores
		if fuseTimer <= 0 then
			fuseTimer = 0
			fuseActive = false
			local survived = {}
			for seat, p in pairs(seatOwner) do
				local root = avatarOf(p)
				if root and not inBlast(root.Position) then
					survived[seat] = p
				end
			end
			-- The survivors each score a point
			for seat, p in pairs(survived) do
				local score = (points[p.UserId] or 0) + 1
				points[p.UserId] = score
				print(("[Timebomb] %s scored (blast). Score %d"):format(p.Name, score))
			end
			updateAllHud()
			if not checkWinner() then
				resetRound("blast resolved")
			end
			return
		end
		updateAllHud()
	else
		roundTimer -= task.wait()
		if roundTimer <= 0 then
			roundTimer = 0
			-- Round time over: whoever is out of the arena loses a point (other scores)
			for seat, p in pairs(seatOwner) do
				local root = avatarOf(p)
				if root and not inArena(root.Position) then
					local other = seatOwner[otherSeat(seat)]
					if other then
						local score = (points[other.UserId] or 0) + 1
						points[other.UserId] = score
						print(("[Timebomb] %s scored (inbounds). Score %d"):format(other.Name, score))
					end
				end
			end
			updateAllHud()
			if not checkWinner() then
				-- Now start the fuse phase
				fuseActive = true
				fuseTimer = settings.fuseTime
				roundActive = false
				roundTimer = 0
			end
			return
		end
	end

	if botSeat ~= 0 then
		botThink()
	end
end)
