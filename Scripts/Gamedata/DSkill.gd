class_name DSkill
extends RefCounted

# This class represents a skill with its properties
# Example skill data:
#	{
#		"description": "Skill in crafting objects from raw materials, including tools, weapons, and other gear, often essential for survival.",
#		"id": "fabrication",
#		"name": "Fabrication",
#		"sprite": "crafting_32.png",
#		"references": {
#			"core": {
#				"items": [
#					"pistol_magazine",
#					"cutting_board"
#				]
#			}
#		}
#	}

# Properties defined in the skill
var id: String
var name: String
var description: String
var spriteid: String
var sprite: Texture
var parent: DSkills

# Constructor to initialize skill properties from a dictionary
# myparent: The list containing all skills for this mod
func _init(data: Dictionary, myparent: DSkills):
	parent = myparent
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	spriteid = data.get("sprite", "")


# Get data function to return a dictionary with all properties
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"sprite": spriteid
	}
	return data

# Method to save any changes to the skill back to disk
func save_to_disk():
	parent.save_skills_to_disk()

# Some skill has been changed
# INFO if the skill references other entities, update them here
func changed(_olddata: DSkill):
	parent.save_skills_to_disk()

# A skill is being deleted from the data
# We have to remove it from everything that references it
func delete():
	var changes: Dictionary = {"made":false}
	
	# This callable will remove this skill from items that reference this skill.
	var myfunc: Callable = func (item_id):
		var item_data: DItem = Gamedata.items.by_id(item_id)
		item_data.remove_skill(id)
		changes.made = true
	
	# Pass the callable to every item in the skill's references
	# It will call myfunc on every item in skill_data.references.core.items
	execute_callable_on_references_of_type(DMod.ContentType.ITEMS, myfunc)
	
	# Save changes to the data file if any changes were made
	if changes.made:
		Gamedata.items.save_items_to_disk()
	else:
		print_debug("No changes needed for skill", id)


# Executes a callable function on each reference of the given type
# type: The type of entity that you want to execute the callable for
# callable: The function that will be executed for every entity of this type
func execute_callable_on_references_of_type(type: DMod.ContentType, callable: Callable):
	# myreferences will ba dictionary that contains entity types that have references to this skill's id
	# See DMod.add_reference for an example structure of references
	var myreferences: Dictionary = parent.references.get(id, {})
	var type_string: String = DMod.get_content_type_string(type)
	# Check if it contains the specified 'module' and 'type'
	if myreferences.has(type_string):
		# If the type exists, execute the callable on each ID found under this type
		for ref_id in myreferences[type_string]:
			callable.call(ref_id)
