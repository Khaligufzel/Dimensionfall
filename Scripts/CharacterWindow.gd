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
	visibility_changed.connect(_on_visibility_changed)


# Utility function to clear all children in a container
func clear_container(container: Control):
	for child in container.get_children():
		child.queue_free()


# Handles the update of the stats display when player stats change
func _on_player_stat_changed(player_node: CharacterBody3D):
	clear_container(statsContainer)  # Clear existing content
	var playerstats = player_node.stats
	for stat_id in playerstats:
		var stat_data: RStat = Runtimedata.stats.by_id(stat_id)
		if stat_data:
			var stat_entry = create_stat_entry(stat_data, playerstats[stat_id])
			statsContainer.add_child(stat_entry)


# Handles the update of the skills display when player skills change
func _on_player_skill_changed(player_node: CharacterBody3D):
	if not visible:
		return
	clear_container(skillsContainer)  # Clear existing content
	for skill_id in player_node.skills:
		var skill_data: RSkill = Runtimedata.skills.by_id(skill_id)
		if skill_data:
			var skill_value = player_node.skills[skill_id]
			var skill_entry = create_skill_entry(skill_data, skill_value)
			skillsContainer.add_child(skill_entry)


# Utility function to create an HBoxContainer for a stat or skill entry
func create_skill_entry(rskill: RSkill, value: Variant) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	var icon = TextureRect.new()
	icon.texture = rskill.sprite
	hbox.add_child(icon)

	var label = Label.new()
	# For skills, display level and XP with a maximum of 2 decimal places
	var xp_value = str(round(value["xp"] * 100) / 100.0)  # Round XP to 2 decimal places
	label.text = rskill.name + ": Level " + str(value["level"]) + ", XP: " + xp_value
	label.tooltip_text = rskill.description
	hbox.add_child(label)

	return hbox


# Utility function to create an HBoxContainer for a stat or skill entry
func create_stat_entry(dstat: RStat, value: Variant) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	var icon = TextureRect.new()
	icon.texture = dstat.sprite
	hbox.add_child(icon)

	var label = Label.new()
	# For stats, display the value directly
	label.text = dstat.name + ": " + str(value)
	label.tooltip_text = dstat.description
	hbox.add_child(label)

	return hbox


# New function to refresh stats and skills when the window becomes visible
func _on_visibility_changed():
	if visible:
		_on_player_stat_changed(playerInstance)
		_on_player_skill_changed(playerInstance)
