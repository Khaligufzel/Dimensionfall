extends Control



# This script belongs to the `addremovemods.tscn` scene. It allows you to add and remove mods
# Mods are loaded as modinfo.json files and added to mods_item_list
# Each modinfo.json file is located in the respective mods folder
# For example, the modinfo.json for the "Core" mod is located in ./Mods/Core/modinfo.json

# When a mod is added, a new folder is created in ./Mods
# In the new folder, a new modinfo.json file is created with default values
# For example, adding a new mod will create ./Mods/Myarcherymod/modinfo.json

# When a mod is deleted, it will delete the mod folder from ./Mods

# Example mod json:
#{
  #"id": "core",
  #"name": "Core",
  #"version": "1.0.0",
  #"description": "This is the core mod of the game. It provides the foundational systems and data required for other mods to function.",
  #"author": "Your Name or Studio Name",
  #"dependencies": [],
  #"mod_type": "core",
  #"homepage": "https://github.com/Khaligufzel/Dimensionfall",
  #"license": "GPL-3.0 License",
  #"tags": ["core", "base", "foundation"]
#}


@export var mods_item_list: ItemList = null
@export var id_text_edit: TextEdit = null
@export var name_text_edit: TextEdit = null
@export var description_text_edit: TextEdit = null
@export var author_text_edit: TextEdit = null
@export var dependencies_item_list: ItemList = null
@export var homepage_text_edit: TextEdit = null
@export var license_option_button: OptionButton = null
@export var tags_editable_item_list: Control = null

@export var pupup_ID: Popup = null
@export var popup_textedit: TextEdit = null


func _on_add_button_button_up() -> void:
	popup_textedit.text = ""
	pupup_ID.show()


func _on_remove_button_button_up() -> void:
	# Get the selected mod
	var selected_index = mods_item_list.get_selected_items()
	if selected_index.size() == 0:
		print_debug("No mod selected for removal.")
		return
	selected_index = selected_index[0]

	var mod_id = mods_item_list.get_item_metadata(selected_index)

	# Use the delete_mod function to handle the deletion
	delete_mod(mod_id)


func _on_back_button_button_up():
	get_tree().change_scene_to_file("res://Scenes/ContentManager/modmanager.tscn")


func _on_ok_button_up() -> void:
	pupup_ID.hide()
	var mod_id = popup_textedit.text

	# Validate the entered ID
	if mod_id == "":
		print_debug("Mod ID cannot be empty.")
		return

	# Check if a mod with this ID already exists
	var existing_mods = mods_item_list.get_items()
	if existing_mods.has(mod_id):
		print_debug("A mod with this ID already exists.")
		return

	# Create the mod folder and modinfo.json
	var mod_path = "./Mods/" + mod_id
	if !Helper.json_helper.create_new_json_file(mod_path + "/modinfo.json", false):
		print_debug("Failed to create modinfo.json for mod: " + mod_id)
		return

	# Default modinfo content
	var modinfo = {
		"id": mod_id,
		"name": "New Mod - " + mod_id.capitalize(),
		"version": "1.0.0",
		"description": "A new mod for the game.",
		"author": "Default Author",
		"dependencies": [],  # No dependencies by default
		"mod_type": "custom",  # Assume all new mods are custom
		"homepage": "https://example.com",
		"license": "GPL-3.0 License",
		"tags": ["custom", "mod", "default"]
	}

	# Save modinfo.json
	if Helper.json_helper.write_json_file(mod_path + "/modinfo.json", JSON.stringify(modinfo, "\t")) != OK:
		print_debug("Failed to save modinfo.json for mod: " + mod_id)
		return

	# Add the mod to the mods_item_list
	mods_item_list.add_item(modinfo["name"])
	mods_item_list.set_item_metadata(mods_item_list.get_item_count() - 1, mod_id)

	print_debug("Added new mod: " + mod_id)


# Called after the users presses cancel on the popup asking for an ID
func _on_cancel_button_up():
	pupup_ID.hide()


# Function to delete a mod by its ID
func delete_mod(mod_id: String) -> void:
	# Prevent the "Core" mod from being deleted
	if mod_id == "Core":
		print_debug("The 'Core' mod cannot be deleted.")
		return

	var mod_path = "./Mods/" + mod_id

	# Delete the modinfo.json file
	if !Helper.json_helper.delete_json_file(mod_path + "/modinfo.json"):
		print_debug("Failed to delete modinfo.json for mod: " + mod_id)
		return

	# Delete the mod folder
	var dir = DirAccess.open("./Mods")
	if dir and dir.dir_exists(mod_path.get_base_dir()):
		if dir.remove(mod_path.get_base_dir()) != OK:
			print_debug("Failed to delete mod folder: " + mod_path)
			return
	else:
		print_debug("Mod folder does not exist: " + mod_path)
		return

	# Remove the mod from the mods_item_list
	for i in range(mods_item_list.get_item_count()):
		if mods_item_list.get_item_metadata(i) == mod_id:
			mods_item_list.remove_item(i)
			break

	print_debug("Removed mod: " + mod_id)
