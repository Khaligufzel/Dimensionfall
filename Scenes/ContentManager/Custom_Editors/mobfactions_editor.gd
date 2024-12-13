extends Control

# This scene is intended to be used inside the content editor
# It is supposed to edit exactly one Mobfaction
# It expects to save the data to a JSON file
# To load data, provide the name of the mobfaction data file and an ID
# Example mob faction JSON:
# {
# 	"id": "undead",
# 	"name": "The Undead",
# 	"description": "The unholy remainders of our past sins.",
#	"relations": [
#			{
#				"relation_type": "core"
#				"mobgroup": ["basic_zombies", "basic_vampires"],
#				"mobs": ["small slime", "big slime"],
#				"factions": ["human_faction", "animal_faction"]
#			},
#			{
#				"relation_type": "hostile"
#				"mobgroup": ["security_robots", "national_guard"],
#				"mobs": ["jabberwock", "cerberus"],
#				"factions": ["human_faction", "animal_faction"]
#			}
#		]
#	}

@export var IDTextLabel: Label = null
@export var NameTextEdit: TextEdit = null
@export var DescriptionTextEdit: TextEdit = null
@export var friendly_grid_container: GridContainer = null
@export var neutral_grid_container: GridContainer = null
@export var hostile_grid_container: GridContainer = null


# This signal will be emitted when the user presses the save button
# This signal should alert Gamedata that the mobfaction data array should be saved to disk
signal data_changed()

var olddata: DMobfaction # Remember what the value of the data was before editing

# The data that represents this mobfaction
# The data is selected from the dmobfaction.parent
# based on the ID that the user has selected in the content editor
var dmobfaction: DMobfaction = null:
	set(value):
		dmobfaction = value
		load_mobfaction_data()
		olddata = DMobfaction.new(dmobfaction.get_data().duplicate(true), null)


func _ready() -> void:
	if friendly_grid_container:
		friendly_grid_container.set_drag_forwarding(Callable(), _can_entity_drop.bind("friendly"), _entity_drop.bind("friendly"))
	if neutral_grid_container:
		neutral_grid_container.set_drag_forwarding(Callable(), _can_entity_drop.bind("neutral"), _entity_drop.bind("neutral"))
	if hostile_grid_container:
		hostile_grid_container.set_drag_forwarding(Callable(), _can_entity_drop.bind("hostile"), _entity_drop.bind("hostile"))


# The editor is closed, destroy the instance
# TODO: Check for unsaved changes
func _on_close_button_button_up() -> void:
	queue_free()

func load_mobfaction_data() -> void:
	if IDTextLabel != null:
		IDTextLabel.text = str(dmobfaction.id)
	if NameTextEdit != null:
		NameTextEdit.text = dmobfaction.name
	if DescriptionTextEdit != null:
		DescriptionTextEdit.text = dmobfaction.description
	
	# Clear existing children in each GridContainer
	if friendly_grid_container:
		Helper.free_all_children(friendly_grid_container)
	if neutral_grid_container:
		Helper.free_all_children(neutral_grid_container)
	if hostile_grid_container:
		Helper.free_all_children(hostile_grid_container)

	# Add relations to the corresponding container
	for relation: DMobfaction.Relation in dmobfaction.relations:
		process_relation_and_add_entities(relation.get_data())


# This function takes all data from the form elements and stores them in the DMobfaction instance
# Since dmobfaction is a reference to an item in Gamedata.mods.by_id("Core").mobfactions
# the central array for mobfaction data is updated with the changes as well
# The function will signal to Gamedata that the data has changed and needs to be saved
# This function takes all data from the form elements and stores them in the DMobfaction instance.
func _on_save_button_button_up() -> void:
	dmobfaction.name = NameTextEdit.text
	dmobfaction.description = DescriptionTextEdit.text
	dmobfaction.relations = []

	# Extract relations from the GridContainers.
	if friendly_grid_container:
		dmobfaction.relations.append(DMobfaction.Relation.new(extract_relation_from_grid(friendly_grid_container, "friendly")))
	if neutral_grid_container:
		dmobfaction.relations.append(DMobfaction.Relation.new(extract_relation_from_grid(neutral_grid_container, "neutral")))
	if hostile_grid_container:
		dmobfaction.relations.append(DMobfaction.Relation.new(extract_relation_from_grid(hostile_grid_container, "hostile")))

	dmobfaction.changed(olddata)
	data_changed.emit()
	olddata = DMobfaction.new(dmobfaction.get_data().duplicate(true), null)



# The user drops some kind of entity on the control. Hopefully it's a mob or mobgroup
# dropped_data: A dictionary like this:
#	{
#		"id": selected_item_id,
#		"text": selected_item_text,
#		"mod_id": mod_id,
#		"contentType": contentType
#	}
func _entity_drop(_newpos, dropped_data: Dictionary, relation_type: String) -> void:
	var entity: RefCounted = null
	if dropped_data and dropped_data.has("id"):
		var droppedcontenttype: DMod.ContentType = dropped_data.get("contentType", -1)
		if droppedcontenttype == DMod.ContentType.MOBS:
			entity = Gamedata.mods.by_id(dropped_data["mod_id"]).mobs.by_id(dropped_data["id"])
		elif droppedcontenttype == DMod.ContentType.MOBGROUPS:
			entity = Gamedata.mods.by_id(dropped_data["mod_id"]).mobgroups.by_id(dropped_data["id"])
		elif droppedcontenttype == DMod.ContentType.MOBFACTIONS:
			entity = Gamedata.mods.by_id(dropped_data["mod_id"]).mobfactions.by_id(dropped_data["id"])
		if entity:
			# Call add_entity_entry_to_container with the resolved entity and relation type
			add_entity_entry_to_container(entity, relation_type)


# Determines if the dropped data can be accepted
# dropped_data: A dictionary like this:
#	{
#		"id": selected_item_id,
#		"text": selected_item_text,
#		"mod_id": mod_id,
#		"contentType": contentType
#	}
func _can_entity_drop(_newpos, dropped_data: Dictionary, _relation_type: String) -> bool:
	if not dropped_data or not dropped_data.has("id"):
		return false
	
	# We check to see if the mod that contains the dropped dat does indeed have the id included in the dropped data
	# The contenttype will tell us what kind of entity it is
	var droppedcontenttype = dropped_data["contentType"]
	var valid_data = false
	if droppedcontenttype == DMod.ContentType.MOBS:
		valid_data = Gamedata.mods.by_id(dropped_data["mod_id"]).mobs.has_id(dropped_data["id"])
	elif droppedcontenttype == DMod.ContentType.MOBGROUPS:
		valid_data = Gamedata.mods.by_id(dropped_data["mod_id"]).mobgroups.has_id(dropped_data["id"])
	elif droppedcontenttype == DMod.ContentType.MOBFACTIONS:
		valid_data = Gamedata.mods.by_id(dropped_data["mod_id"]).mobfactions.has_id(dropped_data["id"])
	return valid_data


# Extracts relation data from a GridContainer.
# container: The GridContainer holding the relation data.
# relation_type: The type of relation ("friendly", "neutral", "hostile").
func extract_relation_from_grid(container: GridContainer, relation_type: String) -> Dictionary:
	var relation = {"relation_type": relation_type, "mobs": [], "mobgroup": [], "factions": []}

	# Iterate through the children in the container.
	var num_children = container.get_child_count()
	for i in range(0, num_children, 3):  # Each entity is represented by 3 children: icon, label, button.
		var entity_label: Label = container.get_child(i + 1) as Label
		var entity: RefCounted = entity_label.get_meta("entity")  # Retrieve the entity metadata.

		# Categorize the entity based on its type.
		if entity is DMob:
			relation["mobs"].append(entity.id)
		elif entity is DMobgroup:
			relation["mobgroup"].append(entity.id)
		elif entity is DMobfaction:
			relation["factions"].append(entity.id)

	# Remove empty keys.
	for key in ["mobs","mobgroup","factions"]:
		if relation[key] == []:
			relation.erase(key)

	return relation



# Add a new entry to one of the containers
# entity: One of DMob, DMobgroup or DMobfaction
# Add a new entry to one of the containers.
# entity: One of DMob, DMobgroup, or DMobfaction.
func add_entity_entry_to_container(entity: RefCounted, container_type: String):
	var grid_container: GridContainer = null
	match container_type:
		"friendly":
			grid_container = friendly_grid_container
		"neutral":
			grid_container = neutral_grid_container
		"hostile":
			grid_container = hostile_grid_container
	
	if grid_container:
		# Create the entity icon.
		var entity_icon = TextureRect.new()
		if entity.get("sprite"):
			entity_icon.texture = entity.sprite
		entity_icon.custom_minimum_size = Vector2(16, 16)

		# Create the entity label and store the entity in metadata.
		var entity_label = Label.new()
		entity_label.text = entity.id if entity.id else "Unknown"  # Fallback to "Unknown" if ID is not present
		entity_label.set_meta("entity", entity)  # Store the refcounted entity in metadata

		# Create the delete button.
		var delete_button = Button.new()
		delete_button.text = "X"
		# Pass all associated controls to the delete function.
		delete_button.button_up.connect(_on_delete_entity_button_pressed.bind([entity_icon, entity_label, delete_button]))

		# Add components to the GridContainer.
		grid_container.add_child(entity_icon)
		grid_container.add_child(entity_label)
		grid_container.add_child(delete_button)


# Retrieves an entity based on its type and ID.
# entity_type: One of "mobs", "mobgroup", or "factions".
# entity_id: The ID of the entity to retrieve.
func get_entity_by_type_and_id(entity_type: String, entity_id: String) -> RefCounted:
	var content_type: DMod.ContentType
	match entity_type:
		"mobs": content_type = DMod.ContentType.MOBS
		"mobgroup": content_type = DMod.ContentType.MOBGROUPS
		"factions": content_type = DMod.ContentType.MOBFACTIONS
		_:
			return null  # Invalid entity type
	
	# Attempt to retrieve the entity by its ID.
	return Gamedata.mods.get_content_by_id(content_type, entity_id)


# Processes a relation dictionary and adds its entities to the appropriate container.
# relation: A dictionary containing the relation data.
func process_relation_and_add_entities(relation: Dictionary) -> void:
	# Determine which container type to use based on the relation type.
	var container_type: String = relation.get("relation_type", "neutral")
	
	# Process each entity type in the relation.
	for entity_type in ["mobs", "mobgroup", "factions"]:
		if relation.has(entity_type):
			for entity_id in relation[entity_type]:
				var entity: RefCounted = get_entity_by_type_and_id(entity_type, entity_id)
				if entity:
					# Add the entity to the appropriate container.
					add_entity_entry_to_container(entity, container_type)


# Handles the deletion of an entity.
# controls: An array of UI controls (icon, label, button) to remove.
func _on_delete_entity_button_pressed(controls: Array) -> void:
	for control in controls:
		control.queue_free()
