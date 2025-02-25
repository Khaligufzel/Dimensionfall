class_name RAttack
extends RefCounted

# This class represents a attack with its properties
# Only used while the game is running
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

# Properties defined in the attack
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
var parent: RAttacks

# Constructor to initialize attack properties from a dictionary
# myparent: The list containing all attacks for this mod
func _init(myparent: RAttacks, newid: String):
	parent = myparent
	id = newid

func overwrite_from_dattack(dattack: DAttack) -> void:
	if not id == dattack.id:
		print_debug("Cannot overwrite from a different id")
	name = dattack.name
	description = dattack.description
	spriteid = dattack.spriteid
	sprite = dattack.sprite
	type = dattack.type
	range = dattack.range
	cooldown = dattack.cooldown
	knockback = dattack.knockback
	projectile_speed = dattack.projectile_speed
	targetattributes = dattack.targetattributes
	references = dattack.references

func get_attribute_damage() -> int:
	if not targetattributes.has("any_of"):
		return 0
	if targetattributes.any_of.size() < 1:
		return 0
	return targetattributes.any_of[0].damage
