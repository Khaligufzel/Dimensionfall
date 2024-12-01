extends Node

# Autoload singleton that copies all game data required to run the game from Gamedata
# Accessible via Runtimedata.property
var maps: DMaps
var tacticalmaps: RTacticalmaps
var furnitures: DFurnitures
var items: DItems
var tiles: DTiles
var mobs: DMobs
var itemgroups: DItemgroups
var playerattributes: DPlayerAttributes
var wearableslots: DWearableSlots
var skills: DSkills
var stats: RStats
var quests: DQuests
var overmapareas: DOvermapareas
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
	tacticalmaps = RTacticalmaps.new()
	
	# Populate the gamedata_map with the instantiated objects
	gamedata_map = {
		DMod.ContentType.STATS: stats,
		DMod.ContentType.TACTICALMAPS: tacticalmaps
	}
