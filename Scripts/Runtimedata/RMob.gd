class_name RMob
extends RefCounted

# This class represents a mob with its properties
# Only used while the game is running
# Example mob data:
# {
# 	"description": "A small robot",
# 	"health": 80,
# 	"hearing_range": 1000,
# 	"id": "scrapwalker",
# 	"idle_move_speed": 0.5,
# 	"loot_group": "mob_loot",
# 	"move_speed": 2.1,
# 	"name": "Scrap walker",
# 	"references": {
# 		"core": {
# 			"maps": [
# 				"Generichouse",
# 				"store_electronic_clothing"
# 			],
# 			"quests": [
# 				"starter_tutorial_00"
# 			]
# 		}
# 	},
# 	"sense_range": 50,
# 	"sight_range": 200,
# 	"special_moves": {
# 		"dash": {"speed_multiplier":2,"cooldown":5,"duration":0.5}
# 	},
#	"attacks": {
#		"melee": [
#			{
#				"id": "basic_melee",
#				"multiplier": 1.1
#			},
#			{
#				"id": "advanced_melee",
#				"multiplier": 1.0
#			}
#		],
#		"ranged": [
#			{
#				"id": "basic_ranged",
#				"multiplier": 1.0
#			},
#			{
#				"id": "advanced_ranged",
#				"multiplier": 1.0
#			}
#		]
#	}
# 	"spriteid": "scrapwalker64.png"
# }

# Properties defined in the mob
var id: String
var name: String
var faction_id: String
var description: String
var default_faction: String
var health: int
var hearing_range: int
var idle_move_speed: float
var loot_group: String
var move_speed: float
var sense_range: int
var sight_range: int
var special_moves: Dictionary = {}
var spriteid: String
var sprite: Texture
var attacks: Dictionary = {}
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
	faction_id = dmob.faction_id
	description = dmob.description
	default_faction = dmob.default_faction
	health = dmob.health
	hearing_range = dmob.hearing_range
	idle_move_speed = dmob.idle_move_speed
	loot_group = dmob.loot_group
	move_speed = dmob.move_speed
	sense_range = dmob.sense_range
	sight_range = dmob.sight_range
	special_moves = dmob.special_moves.duplicate(true)
	spriteid = dmob.spriteid
	sprite = dmob.sprite
	attacks = dmob.attacks.duplicate(true)
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
		"faction_id": faction_id,
		"description": description,
		"default_faction": default_faction,
		"health": health,
		"hearing_range": hearing_range,
		"idle_move_speed": idle_move_speed,
		"loot_group": loot_group,
		"move_speed": move_speed,
		"sense_range": sense_range,
		"sight_range": sight_range,
		"sprite": spriteid
	}
	if not special_moves.is_empty():
		data["special_moves"] = special_moves
	if not attacks.is_empty():
		data["attacks"] = attacks
	if not referenced_maps.is_empty():
		data["referenced_maps"] = referenced_maps
	return data


# Function to retrieve referenced_maps
func get_maps() -> Array:
	# Return the map data, or an empty array if no data is found
	return referenced_maps if referenced_maps else []
