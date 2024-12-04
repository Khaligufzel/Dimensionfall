class_name RSkill
extends RefCounted

# This class represents a skill with its properties
# Only used while the game is running
# Example skill data:
# {
#     "description": "Skill in crafting objects from raw materials, including tools, weapons, and other gear, often essential for survival.",
#     "id": "fabrication",
#     "name": "Fabrication",
#     "sprite": "crafting_32.png",
#     "references": {
#         "core": {
#             "items": [
#                 "pistol_magazine",
#                 "cutting_board"
#             ]
#         }
#     }
# }

# Properties defined in the skill
var id: String
var name: String
var description: String
var spriteid: String
var sprite: Texture
var parent: RSkills  # Reference to the list containing all runtime skills for this mod

# Constructor to initialize skill properties from a dictionary
# myparent: The list containing all skills for this mod
# newid: The ID of the skill being created
func _init(myparent: RSkills, newid: String):
	parent = myparent
	id = newid

# Overwrite this skill's properties using a DSkill
func overwrite_from_dskill(dskill: DSkill) -> void:
	if not id == dskill.id:
		print_debug("Cannot overwrite from a different id")
	name = dskill.name
	description = dskill.description
	spriteid = dskill.spriteid
	sprite = dskill.sprite

# Get data function to return a dictionary with all properties
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"sprite": spriteid
	}
	return data
