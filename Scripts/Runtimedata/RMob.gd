class_name RMob
extends RefCounted

# This class represents a mob with its properties
# Only used while the game is running
# Example mob data:
# {
#     "description": "A small robot",
#     "health": 80,
#     "hearing_range": 1000,
#     "id": "scrapwalker",
#     "idle_move_speed": 0.5,
#     "loot_group": "mob_loot",
#     "move_speed": 2.1,
#     "melee_range": 1.5,
#     "melee_knockback": 2.0,
#     "melee_cooldown": 2.0,
#     "name": "Scrap walker",
#     "sprite": "scrapwalker64.png",
#     "special_moves": {
#         "dash": {"speed_multiplier":2,"cooldown":5,"duration":0.5}
#     },
#     "targetattributes": {
#         "any_of": [
#             {"id": "head_health", "damage": 10},
#             {"id": "torso_health", "damage": 10}
#         ],
#         "all_of": [
#             {"id": "poison", "damage": 10},
#             {"id": "stun", "damage": 10}
#         ]
#     }
# }

# Properties defined in the mob
var id: String
var name: String
var description: String
var default_faction: String
var health: int
var hearing_range: int
var idle_move_speed: float
var loot_group: String
var melee_range: float
var melee_knockback: float
var melee_cooldown: float
var move_speed: float
var sense_range: int
var sight_range: int
var special_moves: Dictionary = {}
var spriteid: String
var sprite: Texture
var targetattributes: Dictionary = {}
var referenced_maps: Array[String]
var parent: RMobs  # Reference to the list containing all runtime mobs for this mod

# Constructor to initialize mob properties from a dictionary
# myparent: The list containing all mobs for this mod
# newid: The ID of the mob being created
func _init(myparent: RMobs, newid: String):
	parent = myparent
	id = newid

# Overwrite this mob's properties using a DMob
func overwrite_from_dmob(dmob: DMob) -> void:
	if not id == dmob.id:
		print_debug("Cannot overwrite from a different id")
	name = dmob.name
	description = dmob.description
	default_faction = dmob.default_faction
	health = dmob.health
	hearing_range = dmob.hearing_range
	idle_move_speed = dmob.idle_move_speed
	loot_group = dmob.loot_group
	melee_range = dmob.melee_range
	melee_knockback = dmob.melee_knockback
	melee_cooldown = dmob.melee_cooldown
	move_speed = dmob.move_speed
	sense_range = dmob.sense_range
	sight_range = dmob.sight_range
	special_moves = dmob.special_moves.duplicate(true)
	spriteid = dmob.spriteid
	sprite = dmob.sprite
	targetattributes = dmob.targetattributes.duplicate(true)
	# Append each value from mobmaps to referenced_maps
	var mobmaps: Array = dmob.get_maps()
	for map_id in mobmaps:
		if map_id not in referenced_maps:
			referenced_maps.append(map_id)

# Get data function to return a dictionary with all properties
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"default_faction": default_faction,
		"health": health,
		"hearing_range": hearing_range,
		"idle_move_speed": idle_move_speed,
		"loot_group": loot_group,
		"melee_range": melee_range,
		"melee_knockback": melee_knockback,
		"melee_cooldown": melee_cooldown,
		"move_speed": move_speed,
		"sense_range": sense_range,
		"sight_range": sight_range,
		"sprite": spriteid
	}
	if not special_moves.is_empty():
		data["special_moves"] = special_moves
	if not targetattributes.is_empty():
		data["targetattributes"] = targetattributes
	if not referenced_maps.is_empty():
		data["referenced_maps"] = referenced_maps
	return data


# Function to retrieve referenced_maps
func get_maps() -> Array:
	# Return the map data, or an empty array if no data is found
	return referenced_maps if referenced_maps else []
