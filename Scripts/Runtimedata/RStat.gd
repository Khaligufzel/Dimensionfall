class_name RStat
extends RefCounted

# This class represents a stat with its properties
# Only used while the game is running
# Example stat data:
#	{
#		"description": "Represents the character's agility, reflexes, and balance...",
#		"id": "dexterity",
#		"name": "Dexterity",
#		"sprite": "dexterity_32.png"
#	}

# Properties defined in the stat
var id: String
var name: String
var description: String
var spriteid: String
var sprite: Texture
var references: Dictionary = {}
var parent: RStats

# Constructor to initialize stat properties from a dictionary
# data: the data as loaded from json
# myparent: The list containing all stats for this mod
func _init(myparent: RStats, newid: String):
	parent = myparent
	id = newid

func overwrite_from_dstat(dstat: DStat) -> void:
	if not id == dstat.id:
		print_debug("Cannot overwrite from a different id")
	name = dstat.name
	description = dstat.description
	spriteid = dstat.spriteid
	sprite = dstat.sprite
	references = dstat.references
