# oak-egghax-v2

```lua
_G.Egg = {
	enabled = true,

	nextEggKeybind = Enum.KeyCode.H,
	serverHopKeybind = Enum.KeyCode.P,
	sellSpotTeleportKeybind = Enum.KeyCode.G,
	pauseKeybind = Enum.KeyCode.J,

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
}

wait() loadstring(game:HttpGet("https://raw.githubusercontent.com/DisobedientToast99/oak-egghax-v2/refs/heads/main/main.lua"))()
```
