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


# Takes a multiplier and returns the calculated amount of damage for a random attribute
func get_scaled_attribute_damage(multiplier: float) -> Dictionary:
	# Ensure 'any_of' attributes exist
	if not targetattributes.has("any_of") or targetattributes.any_of.is_empty():
		return {}

	# Pick a random attribute from 'any_of'
	var selected_attribute = targetattributes.any_of[randi() % targetattributes.any_of.size()]

	# Apply the multiplier to the damage
	var scaled_damage = selected_attribute.damage * multiplier

	# Return the result as a dictionary
	return {
		"id": selected_attribute.id,
		"damage": scaled_damage
	}

# Takes a multiplier and returns a list of attributes that are hit by the multiplied damage.
func get_scaled_all_of_attribute_damage(multiplier: float) -> Array:
	# Ensure 'all_of' attributes exist
	if not targetattributes.has("all_of") or targetattributes.all_of.is_empty():
		return []

	var scaled_attributes = []

	# Loop over each attribute in 'all_of'
	for attribute in targetattributes.all_of:
		scaled_attributes.append({
			"id": attribute.id,
			"damage": attribute.damage * multiplier
		})

	return scaled_attributes

# Takes a multipler and returns the amount of damage and knockback
func get_scaled_attack_effects(multiplier: float) -> Dictionary:
	var scaled_attributes: Array = [get_scaled_attribute_damage(multiplier)]
	scaled_attributes.append_array(get_scaled_all_of_attribute_damage(multiplier))

	return {
		"attributes": scaled_attributes,
		"knockback": knockback
	}
