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
  #"homepage": "https://github.com/Khaligufzel/Dimensionfall",
  #"license": "GPL-3.0 License",
  #"tags": ["core", "base", "foundation"]
#}


@export var mods_item_list: ItemList = null
@export var id_text_edit: TextEdit = null
@export var name_text_edit: TextEdit = null
@export var description_text_edit: TextEdit = null
@export var author_text_edit: TextEdit = null
@export var dependencies_item_list: Control = null
@export var homepage_text_edit: TextEdit = null
@export var license_option_button: OptionButton = null
@export var tags_editable_item_list: Control = null

@export var pupup_ID: Popup = null
@export var popup_textedit: TextEdit = null


func _ready():
	populate_mods_item_list()
	mods_item_list.set_drag_forwarding(_create_drag_data, Callable(), Callable())

# The user pressed the "add" button
func _on_add_button_button_up() -> void:
	popup_textedit.text = ""
	pupup_ID.show()


# The user pressed the "remove" button
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


# When the user presses "ok" after entering an ID on the ID popup menu
func _on_ok_button_up() -> void:
	pupup_ID.hide()
	var mod_id = popup_textedit.text

	# Validate the entered ID
	if mod_id == "":
		print_debug("Mod ID cannot be empty.")
		return

	# Check if a mod with this ID already exists
	
	var existing_mods = []
	for item in mods_item_list.item_count:
		existing_mods.append(mods_item_list.get_item_text(item))
	if existing_mods.has(mod_id):
		print_debug("A mod with this ID already exists.")
		return

	# Create the mod folder and modinfo.json
	var mod_path = "./Mods/" + mod_id
	Helper.json_helper.create_new_json_file(mod_path + "/modinfo.json", false)

	# Default modinfo content
	var modinfo = {
		"id": mod_id,
		"name": mod_id.capitalize(),
		"version": "1.0.0",
		"description": "A new mod for the game.",
		"author": "Default Author",
		"dependencies": [],  # No dependencies by default
		"mod_type": "custom",  # Assume all new mods are custom
		"homepage": "https://example.com",
		"license": "GPL-3.0 License",
		"tags": [] # example: "custom", "mod", "default"
	}

	# Save modinfo.json
	if Helper.json_helper.write_json_file(mod_path + "/modinfo.json", JSON.stringify(modinfo, "\t")) != OK:
		print_debug("Failed to save modinfo.json for mod: " + mod_id)
		return

	# Add the mod to the mods_item_list
	mods_item_list.add_item(modinfo["name"])
	mods_item_list.set_item_metadata(mods_item_list.get_item_count() - 1, mod_id)

	Gamedata.mods.add_new(mod_id, modinfo)
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

	# Remove the mod from Gamedata.mods
	if Gamedata.mods.has_id(mod_id):
		Gamedata.mods.delete_by_id(mod_id)

	# Delete the mod folder
	var mod_path = "./Mods/" + mod_id
	Helper.json_helper.delete_json_file(mod_path + "/modinfo.json")

	var dir = DirAccess.open(mod_path)
	if dir and dir.dir_exists(mod_path):
		if dir.remove(mod_path) != OK:
			print_debug("Failed to delete mod folder: " + mod_path)
			return
	else:
		print_debug("Mod folder does not exist: " + mod_path)

	# Remove the mod from the mods_item_list
	for i in range(mods_item_list.get_item_count()):
		if mods_item_list.get_item_metadata(i) == mod_id:
			mods_item_list.remove_item(i)
			break

	print_debug("Removed mod: " + mod_id)


func populate_mods_item_list() -> void:
	# Clear the mods_item_list
	mods_item_list.clear()

	# Iterate through Gamedata.mods to populate the mods_item_list
	for mod: DMod in Gamedata.mods.get_all_mods():
		mods_item_list.add_item(mod.name)
		mods_item_list.set_item_metadata(mods_item_list.get_item_count() - 1, mod.id)


# When the user presses the save button
func _on_save_button_button_up() -> void:
	# Get the selected mod
	var selected_index = mods_item_list.get_selected_items()
	if selected_index.size() == 0:
		print_debug("No mod selected for saving.")
		return
	selected_index = selected_index[0]
	var mod_id = mods_item_list.get_item_metadata(selected_index)

	# Create a dictionary with the updated modinfo data
	var modinfo = {
		"id": id_text_edit.text.strip_edges(),
		"name": name_text_edit.text.strip_edges(),
		"description": description_text_edit.text.strip_edges(),
		"author": author_text_edit.text.strip_edges(),
		"homepage": homepage_text_edit.text.strip_edges(),
		"license": license_option_button.get_item_text(license_option_button.get_selected_id()),
		"dependencies": [],
		"tags": []
	}

	# Add dependencies, ensuring no circular dependencies
	for mydep: String in dependencies_item_list.get_items():
		if mydep == mod_id:
			# Mark as invalid dependency
			print_debug("Removed circular dependency: " + mydep)
		else:
			# Add valid dependency to modinfo
			modinfo["dependencies"].append(mydep)

	# Remove invalid dependencies from dependencies_item_list
	dependencies_item_list.set_items(modinfo["dependencies"])

	# Add tags
	if tags_editable_item_list.has_method("get_items"):
		modinfo["tags"] = tags_editable_item_list.get_items()

	# Update modinfo in Gamedata.mods
	if mod_id in Gamedata.mods:
		Gamedata.mods[mod_id]["modinfo"] = modinfo

	# Save the updated modinfo to the JSON file
	var modinfo_path = "./Mods/" + mod_id + "/modinfo.json"
	if Helper.json_helper.write_json_file(modinfo_path, JSON.stringify(modinfo, "\t")) == OK:
		print_debug("Successfully saved modinfo for mod: " + mod_id)
	else:
		print_debug("Failed to save modinfo for mod: " + mod_id)


# Called when a user clicks on an item in the mods_item_list
func _on_mods_item_list_item_selected(index: int) -> void:
	# Get the selected mod's ID
	var mod_id = mods_item_list.get_item_metadata(index)
	var modinfo_path = "./Mods/" + mod_id + "/modinfo.json"

	# Check if the modinfo.json file exists
	if FileAccess.file_exists(modinfo_path):
		var modinfo = Helper.json_helper.load_json_dictionary_file(modinfo_path)

		# Populate the controls with modinfo data
		id_text_edit.text = modinfo.get("id", "")
		name_text_edit.text = modinfo.get("name", "")
		description_text_edit.text = modinfo.get("description", "")
		author_text_edit.text = modinfo.get("author", "")
		homepage_text_edit.text = modinfo.get("homepage", "")
		
		# Populate license_option_button
		var license = modinfo.get("license", "")
		for i in range(license_option_button.get_item_count()):
			if license_option_button.get_item_text(i) == license:
				license_option_button.select(i)
				break

		# Populate dependencies_item_list
		dependencies_item_list.clear_list()
		for dependency in modinfo.get("dependencies", []):
			dependencies_item_list.add_item(dependency)

		# Populate tags_editable_item_list
		tags_editable_item_list.set_items(modinfo.get("tags", []))

		print_debug("Loaded modinfo for mod: " + mod_id)
	else:
		print_debug("modinfo.json not found for mod: " + mod_id)


# Called when a drag event is initiated on the mods_item_list
func _create_drag_data(_at_position: Vector2) -> Variant:
	# Get the index of the item being dragged
	var selected_index = mods_item_list.get_selected_items()
	if selected_index.size() == 0:
		return null  # No item selected, so nothing to drag
	
	selected_index = selected_index[0]
	var mod_id = mods_item_list.get_item_metadata(selected_index)

	# Create a Label for the drag preview
	var preview_label = Label.new()
	preview_label.text = mod_id
	preview_label.add_theme_color_override("font_color", Color(1, 1, 1))
	preview_label.add_theme_color_override("background_color", Color(0, 0, 0, 0.8))
	preview_label.size = Vector2(100, 30)  # Adjust the size as needed
	set_drag_preview(preview_label)  # Attach the preview to the drag event

	# Return the data associated with the dragged mod
	return mod_id
