extends Node

# Autoload singleton that copies all game data required to run the game from Gamedata
# Accessible via Runtimedata.property
var maps: RMaps
var tacticalmaps: RTacticalmaps
var furnitures: DFurnitures
var items: DItems
var tiles: RTiles
var mobs: DMobs
var itemgroups: DItemgroups
var playerattributes: DPlayerAttributes
var wearableslots: DWearableSlots
var skills: RSkills
var stats: RStats
var quests: DQuests
var overmapareas: ROvermapareas
var mobgroups: DMobgroups

# Dictionary to map content types to Gamedata variables
var gamedata_map: Dictionary = {}

# Returns one of the D- data types. We return it as refcounted since every class differs
func get_data_of_type(type: DMod.ContentType) -> RefCounted:
	return gamedata_map[type]


# Reconstruct function to reset and initialize stats
func reconstruct() -> void:
	# Clear the stats by resetting the instance
	stats = RStats.new()
	skills = RSkills.new()
	tacticalmaps = RTacticalmaps.new()
	maps = RMaps.new()
	tiles = RTiles.new()
	overmapareas = ROvermapareas.new()
	
	# Populate the gamedata_map with the instantiated objects
	gamedata_map = {
		DMod.ContentType.STATS: stats,
		DMod.ContentType.SKILLS: skills,
		DMod.ContentType.MAPS: maps,
		DMod.ContentType.TACTICALMAPS: tacticalmaps,
		DMod.ContentType.TILES: tiles,
		DMod.ContentType.OVERMAPAREAS: overmapareas
	}
