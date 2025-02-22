class_name DAttack
extends RefCounted

# This class represents an attack with its properties
# Example attack data:
#	{
#		"description": "Common melee attack",
#		"id": "melee_basic",
#		"name": "Basic melee attack",
#		"type": "melee", // can be "melee" or "ranged"
#		"range": 10,
#		"cooldown": 1,
#		"knockback": 2,
#		"projectile_speed": 20, // Only applies to the "ranged" type
#		"sprite": "projectile_bullet.png" // Only applies to the "ranged" type
#	"targetattributes": {
#		"any_of": [
#			{
#				"id": "head_health", // Refers to the id of an PlayerAttribute
#				"damage": 10
#			},
#			{
#				"id": "torso_health",
#				"damage": 10
#			}
#		],
#		"all_of": [
#			{
#				"id": "poison", // Refers to the id of an PlayerAttribute
#				"damage": 10
#			},
#			{
#				"id": "stun",
#				"damage": 10
#			}
#		]
#	}
#	}

# Properties defined in the stat
var id: String
var name: String
var description: String
var spriteid: String
var sprite: Texture
var type: String # Can be "melee" or "ranged"
var range: float # The attack will start when the enemy is within this range
var cooldown: float # The time between attacks
var knockback: float # The amount of tiles that the enemy is pushed back
var projectile_speed: float  # Only relevant for ranged attacks
var targetattributes: Dictionary = {"any_of": [], "all_of": []}
var references: Dictionary = {}
var parent: DAttacks

# Constructor to initialize stat properties from a dictionary
# data: the data as loaded from json
# myparent: The list containing all stats for this mod
func _init(data: Dictionary, myparent: DAttacks):
	parent = myparent
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	spriteid = data.get("sprite", "")
	sprite = null  # The sprite will be loaded later from the mod's assets
	type = data.get("type", "melee")  # Default to melee if not specified
	range = data.get("range", 0.0)
	cooldown = data.get("cooldown", 0.0)
	knockback = data.get("knockback", 0.0)
	projectile_speed = data.get("projectile_speed", 0.0)  # Only for ranged attacks
	targetattributes = data.get("targetattributes", {"any_of": [], "all_of": []})
	references = data.get("references", {})

# Get data function to return a dictionary with all properties
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"type": type,
		"range": range,
		"cooldown": cooldown,
		"knockback": knockback,
		"targetattributes": targetattributes
	}
	
	# Only include "sprite" and "projectile_speed" for ranged attacks
	if type == "ranged":
		data["sprite"] = spriteid
		data["projectile_speed"] = projectile_speed
	
	if not references.is_empty():
		data["references"] = references
	
	return data


# Ensure saving reflects the attack data
func save_to_disk():
	parent.save_attacks_to_disk()  # Update method name to match attack terminology

# An attack has been changed; update it
func changed(_olddata: DAttack):
	parent.save_attacks_to_disk()

# An attack is being deleted; remove references
func delete():
	print_debug("No changes needed for attack", id)

# Executes a callable function on each reference of the given type
func execute_callable_on_references_of_type(module: String, type: String, callable: Callable):
	# Check if it contains the specified 'module' and 'type'
	if references.has(module) and references[module].has(type):
		# If the type exists, execute the callable on each ID found under this type
		for ref_id in references[module][type]:
			callable.call(ref_id)
