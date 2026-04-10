local _defaults, config = {
	enabled = true,

	nextEggKeybind = Enum.KeyCode.H,
	serverHopKeybind = Enum.KeyCode.P,
	sellSpotTeleportKeybind = Enum.KeyCode.G,
	pauseKeybind = Enum.KeyCode.J,

	autoServerHop = true,
	
	autoSkip = false,
	autoSkipAfter = 10,
	sustainSkippedEgg = 20,

	minPoints = 0,
	maxPoints = math.huge,

	minRarity = 0,
	maxRarity = 4,

	filterEggs = {},
	isBlacklist = true,
	blockOthersIfWhitelist = true,

	espEnabled = true,
	showDistance = true,
	showRarityColor = true,

	teleport = true,
	teleportDelay = 2,
	teleportOffset = Vector3.new(0, 0, 0),
}, table.clone(_G.Egg or {})

local _reloadInterval,_lastReload = 3,0

--------------------------------------------------------------------------------------

repeat task.wait() until game:IsLoaded()

--------------------------------------------------------------------------------------

local teleportService = game:GetService("TeleportService")
local httpService = game:GetService("HttpService")
local userInputService = game:GetService("UserInputService")
local players = game:GetService("Players")

--------------------------------------------------------------------------------------

local _player = players.LocalPlayer
local _searchFolder, _selector = workspace:WaitForChild("World"), ">> Model"

local _character = _player.Character or _player.CharacterAdded:Wait()

local _paused = false

--------------------------------------------------------------------------------------

local _espDistanceFormat = `["%s"] - %s studs`
local _espNoDistanceFormat = `["%s"]`

local _esp = Instance.new("BillboardGui") _esp.Name = "_Gui"
_esp.AlwaysOnTop = true
_esp.Size = UDim2.new(0,500,0,15)
_esp.StudsOffset = Vector3.yAxis*3

local _label = Instance.new("TextLabel") _label.Name = "Label"
_label.BackgroundTransparency = 1
_label.BorderSizePixel = 0
_label.Size = UDim2.new(1,0,1,0)
_label.FontFace = Font.fromName("Inconsolata", Enum.FontWeight.Bold)
_label.TextColor3 = Color3.new(1,1,1)
_label.TextTransparency = 0
_label.TextScaled = true

local _existingEsps = {}

--------------------------------------------------------------------------------------

local _currentEgg = false
local _currentEggSelectedTime = 0

local _lastTeleportTime = 0

local _skipEggs = {}
local _connections = {}

--------------------------------------------------------------------------------------

local _rarities = {
	[0] = {
		Color = Color3.fromRGB(230, 230, 230),
	},
	[1] = {
		Color = Color3.fromRGB(100, 200, 50),
	},
	[2] = {
		Color = Color3.fromRGB(250, 100, 0),
	},
	[3] = {
		Color = Color3.fromRGB(100, 50, 180),
	},
	[4] = {
		Color = Color3.fromRGB(250, 200, 0),
	},
}

local _validEggs = {
	["WhiteEgg"] =			{1, 0},

	["RainbowEgg"] =	{2, 1},
	["StripedEgg"] =	{2, 1},
	["WatermelonEgg"] =	{5, 2},
	["TreeEgg"] =		{15, 3},

	["MagentaEgg"] =	{2, 1},
	["PinkEgg"] =		{2, 1},
	["SwirlyEgg"] =		{5, 2},
	["RabbitEgg"] =		{15, 3},

	["CactusEgg"] =		{2, 1},
	["SandyEgg"] =		{2, 1},
	["DuckEgg"] =		{5, 2},
	["DinoEgg"] =		{15, 3},

	["GreenEgg"] =		{3, 1},
	["CommanderEgg"] =	{3, 1},
	["ZombieEgg"] =		{10, 2},
	["AcidEgg"] =		{30, 3},

	["BlueEgg"] =		{3, 1},
	["PurpleEgg"] =		{3, 1},
	["FrozenEgg"] =		{10, 2},
	["EggcasedEgg"] =	{30, 3},

	["RedEgg"] =		{3, 1},
	["HoleEgg"] =		{3, 1},
	["FireEgg"] =		{10, 2},
	["UnstableEgg"] =	{30, 3},

	["MoonEgg"] =		{10, 4},
	["GurtEgg"] =		{50, 4},
	["GoldEgg"] =		{100, 4},
	["GrudgeEgg"] =		{250, 4},
}

--------------------------------------------------------------------------------------

local function serverHop()
	local servers = {}
	local success, result = pcall(function()
		return httpService:JSONDecode(game:HttpGet(
			string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
			))
	end)

	if success and result and result.data then
		for _, server in pairs(result.data) do
			if server.playing < server.maxPlayers and server.id ~= game.JobId then
				table.insert(servers, server.id)
			end
		end

		if #servers > 0 then
			local randomServerId = servers[math.random(1, #servers)]
			teleportService:TeleportToPlaceInstance(game.PlaceId, randomServerId, _player)
		end
	end
end

--------------------------------------------------------------------------------------

local function isEgg(egg: Instance)
	local valid = true

	if not _validEggs[egg.Name] then
		return false
	end

	if (not egg:FindFirstChild("Owner")) or egg:FindFirstChild("Owner").Value then
		return false
	end

	if _skipEggs[egg] then
		return false
	end

	if (_validEggs[egg.Name][1] < config.minPoints) or (_validEggs[egg.Name][1] > config.maxPoints) then 
		valid = false
	end

	if (_validEggs[egg.Name][2] < config.minRarity) or (_validEggs[egg.Name][2] > config.maxRarity) then 
		valid = false
	end

	if config.isBlacklist == true and table.find(config.filterEggs, egg.Name) then
		valid = false
	elseif (config.isBlacklist == false and not table.find(config.filterEggs, egg.Name)) and config.blockOthersIfWhitelist then
		valid = false
	end

	return valid or (config.isBlacklist == false and table.find(config.filterEggs, egg.Name))
end

local function getEggs(): ({Total: number, Lists: {[string]: {Instance}}})
	local items = _searchFolder:QueryDescendants(_selector)
	local found = {Total=0,Lists={}}

	for _,item in pairs(items) do
		if not isEgg(item) then continue end

		if not found.Lists[item.Name] then
			found.Lists[item.Name] = {}
		end

		table.insert(found.Lists[item.Name], item)
		found.Total +=1
	end

	return found
end

local function makeEsp(egg)
	if not _validEggs[egg.Name] then return false end

	local newEsp = _esp:Clone() table.insert(_existingEsps, newEsp)
	local newLabel = _label:Clone() newLabel.Parent = newEsp

	newEsp.Adornee = egg.PrimaryPart or egg:FindFirstChildOfClass("BasePart")
	if not newEsp.Adornee then newEsp:Destroy() return end
	newEsp:SetAttribute("Name", egg.Name)

	if config.showRarityColor then
		newLabel.TextColor3 = _rarities[_validEggs[egg.Name][2]].Color
	end

	if config.showDistance and _character then
		newLabel.Text = string.format(_espDistanceFormat, egg.Name, string.format("%.1f",(_character.PrimaryPart.Position - newEsp.Adornee.Position).Magnitude))
	else
		newLabel.Text = string.format(_espNoDistanceFormat, egg.Name)
	end

	return newEsp
end

local function updateEsps()
	for i,esp in pairs(_existingEsps) do
		if not esp then
			table.remove(_existingEsps, i)
			continue
		end

		if config.showDistance and _character then
			esp.Label.Text = string.format(_espDistanceFormat, esp:GetAttribute("Name"), string.format("%.1f",(_character.PrimaryPart.Position - esp.Adornee.Position).Magnitude))
		else
			esp.Label.Text = string.format(_espNoDistanceFormat, esp:GetAttribute("Name"))
		end
	end
end

local function clearEsps()
	for i,esp in pairs(_existingEsps) do
		if not esp then continue end

		esp:Destroy()
	end

	table.clear(_existingEsps)
end

--------------------------------------------------------------------------------------

local function _load()
	if not _G.Egg then
		config = _defaults
	else
		for i,v in pairs(_defaults) do
			if not _G.Egg[i] then
				config[i] = v
			elseif typeof(_G.Egg[i]) ~= typeof(v) then
				warn(`['_G.Egg.{i}'] is an invalid type, expected '{typeof(v)}', got '{typeof(_G.Egg[i])}', replacing with default: [{v}]`)
				config[i] = v
			else
				config[i] = _G.Egg[i]
			end
		end
	end
end

local function _loadConnections()
	for _,ctn in pairs(_connections) do
		ctn:Disconnect()
	end

	table.insert(_connections, userInputService.InputBegan:Connect(function(input,gpe)
		if gpe then return end

		if input.KeyCode == config.nextEggKeybind then
			_paused = false

			if _currentEgg then
				_skipEggs[_currentEgg] = os.clock()
			end
			_lastTeleportTime = 0
			_currentEgg,_currentEggSelectedTime = nil,0
		elseif input.KeyCode == config.sellSpotTeleportKeybind then
			_paused = true
			_character:MoveTo(Vector3.new(390, 75, -40))
		elseif input.KeyCode == config.serverHopKeybind then
			serverHop()
		elseif input.KeyCode == config.pauseKeybind then
			_paused = not _paused
		end
	end))
end

--------------------------------------------------------------------------------------

local function espFrame(eggs)
	if not config.espEnabled then if #_existingEsps>0 then clearEsps() end return end

	clearEsps()

	for name,list in pairs(eggs.Lists) do
		for i,egg in pairs(list) do
			local esp = makeEsp(egg)

			if esp then
				esp.Parent = _player.PlayerGui
			end

			esp = nil
		end
	end
end

local function gotoFrame(eggs)
	if not config.teleport or _paused then return end

	local ct = os.clock()

	if config.autoSkip then
		if _currentEgg and (ct - _currentEggSelectedTime) > config.autoSkipAfter then
			_lastTeleportTime = 0

			_skipEggs[_currentEgg] = ct
			_currentEgg,_currentEggSelectedTime = nil
		end
	end

	if _currentEgg and _currentEgg.Parent and _currentEgg:IsDescendantOf(_searchFolder) then
		if ct-_lastTeleportTime >= config.teleportDelay then
			_character:MoveTo(_currentEgg:GetPivot().Position +
				((Vector3.new(0, _character:GetExtentsSize().Y/2, 0)) +
					(Vector3.new(0, _currentEgg:GetExtentsSize().Y/2, 0))) +
				config.teleportOffset
			)

			_lastTeleportTime = ct
		end
	else
		_lastTeleportTime = 0

		local allEggs = {}

		for _,list in pairs(eggs.Lists) do
			table.move(
				list, 1,
				#list,
				#allEggs+1,
				allEggs
			)
		end

		table.sort(allEggs, function(a,b)
			return _validEggs[a.Name][1] > _validEggs[b.Name][1]
		end)

		_currentEgg = allEggs[1]
		_currentEggSelectedTime = os.clock()
	end
end

local function cleanFrame()
	local ct = os.clock()

	for egg,t in pairs(_skipEggs) do
		if ct-t <= config.sustainSkippedEgg then continue end
		_skipEggs[egg] = nil
	end

	if ct-_lastTeleportTime >= _reloadInterval then
		_load()
		_loadConnections()
	end
end

--------------------------------------------------------------------------------------

_load()
_loadConnections()

while task.wait() do
	if not config.enabled then task.wait() end

	local eggs = getEggs()
	_character = _player.Character

	if eggs.Total == 0 and config.autoServerHop then
		serverHop()
		break
	end
	
	gotoFrame(eggs)
	espFrame(eggs)
	cleanFrame()

	eggs = nil

	task.wait(0.1)
end
