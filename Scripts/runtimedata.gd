extends Node

# Autoload singleton that copies all game data required to run the game from Gamedata
# Accessible via Runtimedata.property
var maps: RMaps
var tacticalmaps: RTacticalmaps
var furnitures: RFurnitures
var items: RItems
var tiles: RTiles
var mobs: RMobs
var itemgroups: RItemgroups
var playerattributes: RPlayerAttributes
var wearableslots: RWearableSlots
var skills: RSkills
var stats: RStats
var quests: RQuests
var overmapareas: ROvermapareas
var mobgroups: RMobgroups
var mobfactions: RMobfactions

# Dictionary to map content types to Gamedata variables
var gamedata_map: Dictionary = {}

# Returns one of the D- data types. We return it as refcounted since every class differs
func get_data_of_type(type: DMod.ContentType) -> RefCounted:
	return gamedata_map[type]


# Reconstruct function to reset and initialize stats
# Reconstruct function to reset and initialize stats
# Optional parameter to specify enabled mods manually. If empty, uses mods in state order.
func reconstruct(enabled_mods: Array[DMod] = []) -> void:
	if enabled_mods.is_empty():
		enabled_mods = Gamedata.mods.get_mods_in_state_order(true)

	# Clear the stats by resetting the instance
	stats = RStats.new(enabled_mods)
	skills = RSkills.new(enabled_mods)
	tacticalmaps = RTacticalmaps.new(enabled_mods)
	maps = RMaps.new(enabled_mods)
	tiles = RTiles.new(enabled_mods)
	overmapareas = ROvermapareas.new(enabled_mods)
	quests = RQuests.new(enabled_mods)
	playerattributes = RPlayerAttributes.new(enabled_mods)
	wearableslots = RWearableSlots.new(enabled_mods)
	mobs = RMobs.new(enabled_mods)
	mobgroups = RMobgroups.new(enabled_mods)
	itemgroups = RItemgroups.new(enabled_mods)
	furnitures = RFurnitures.new(enabled_mods)
	items = RItems.new(enabled_mods)
	mobfactions = RMobfactions.new(enabled_mods)

	# Populate the gamedata_map with the instantiated objects
	gamedata_map = {
		DMod.ContentType.STATS: stats,
		DMod.ContentType.SKILLS: skills,
		DMod.ContentType.MAPS: maps,
		DMod.ContentType.TACTICALMAPS: tacticalmaps,
		DMod.ContentType.TILES: tiles,
		DMod.ContentType.OVERMAPAREAS: overmapareas,
		DMod.ContentType.QUESTS: quests,
		DMod.ContentType.PLAYERATTRIBUTES: playerattributes,
		DMod.ContentType.WEARABLESLOTS: wearableslots,
		DMod.ContentType.MOBS: mobs,
		DMod.ContentType.MOBGROUPS: mobgroups,
		DMod.ContentType.ITEMGROUPS: itemgroups,
		DMod.ContentType.FURNITURES: furnitures,
		DMod.ContentType.ITEMS: items,
		DMod.ContentType.MOBFACTIONS: mobfactions
	}


func reset() -> void:
	gamedata_map.clear()
