extends Control

# These are references to the containers in the UI where stats and skills are displayed
@export var statsContainer: VBoxContainer
@export var skillsContainer: GridContainer
var playerInstance: CharacterBody3D

# Called when the node enters the scene tree for the first time.
func _ready():
	Helper.signal_broker.player_stat_changed.connect(_on_player_stat_changed)
	Helper.signal_broker.player_skill_changed.connect(_on_player_skill_changed)
	playerInstance = get_tree().get_first_node_in_group("Players")
	_on_player_stat_changed(playerInstance)
	_on_player_skill_changed(playerInstance)


# Handles the update of the stats display when player stats change
func _on_player_stat_changed(player_node: CharacterBody3D):
	clear_container(statsContainer)  # Clear existing content
	for stat_id in player_node.stats:
		var stat_data = Gamedata.get_data_by_id(Gamedata.data.stats, stat_id)
		if stat_data:
			var stat_entry = create_stat_or_skill_entry(stat_data, player_node.stats[stat_id], "stats")
			statsContainer.add_child(stat_entry)


# Handles the update of the skills display when player skills change
func _on_player_skill_changed(player_node: CharacterBody3D):
	clear_container(skillsContainer)  # Clear existing content
	for skill_id in player_node.skills:
		var skill_data = Gamedata.get_data_by_id(Gamedata.data.skills, skill_id)
		if skill_data:
			var skill_entry = create_stat_or_skill_entry(skill_data, player_node.skills[skill_id], "skills")
			skillsContainer.add_child(skill_entry)


# Utility function to create an HBoxContainer for a stat or skill entry
func create_stat_or_skill_entry(data: Dictionary, value: int, type: String) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	var icon = TextureRect.new()
	icon.texture = Gamedata.get_sprite_by_id(Gamedata.data[type], data["id"])  # Fetch sprite using the ID
	hbox.add_child(icon)

	var label = Label.new()
	label.text = data["name"] + ": " + str(value)
	label.tooltip_text = data["description"]
	hbox.add_child(label)

	return hbox


# Utility function to clear all children in a container
func clear_container(container: Control):
	for child in container.get_children():
		child.queue_free()
