extends Control

# This script controls the attribute window
# The attribute window shows stats about the player like food, water, stamina

# These are references to the containers in the UI where stats and skills are displayed
@export var attributeContainer: VBoxContainer
var playerInstance: CharacterBody3D

# Called when the node enters the scene tree for the first time.
func _ready():
	Helper.signal_broker.player_attribute_changed.connect(_on_player_attribute_changed)
	playerInstance = get_tree().get_first_node_in_group("Players")
	_on_player_attribute_changed(playerInstance)
	visibility_changed.connect(_on_visibility_changed)


# Utility function to clear all children in a container
func clear_container(container: Control):
	for child in container.get_children():
		child.queue_free()


# Handles the update of the stats display when player stats change
func _on_player_attribute_changed(player_node: CharacterBody3D):
	clear_container(attributeContainer)  # Clear existing content
	var playerattributes = player_node.attributes
	for attribute: PlayerAttribute in playerattributes.values():
		attributeContainer.add_child(create_attribute_entry(attribute))


# Utility function to create an HBoxContainer for a stat or skill entry
func create_attribute_entry(attribute: PlayerAttribute) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	
	# Add the icon (TextureRect) for the attribute
	var icon = TextureRect.new()
	icon.texture = attribute.sprite
	icon.custom_minimum_size = Vector2(16, 16)
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	hbox.add_child(icon)

	# Create the ProgressBar to represent the current amount
	var progress_bar = ProgressBar.new()
	progress_bar.min_value = attribute.min_amount
	progress_bar.max_value = attribute.max_amount
	progress_bar.value = attribute.current_amount

	# Set the minimum size of the ProgressBar
	progress_bar.custom_minimum_size = Vector2(100, 16)

	# Convert ui_color to a Color object
	var ui_color = Color.html(attribute.attribute_data.ui_color)
	
	# Calculate a darker version of the ui_color for the background
	var darker_color = ui_color.darkened(0.4)  # Adjust the 0.3 to control how much darker the background should be

	# Create and set the background stylebox
	var background_stylebox = progress_bar.get_theme_stylebox("background").duplicate()
	background_stylebox.set_bg_color(darker_color)  # Set the background color to the darker version of ui_color
	progress_bar.add_theme_stylebox_override("background", background_stylebox)

	# Create and set the fill stylebox
	var fill_stylebox = progress_bar.get_theme_stylebox("fill").duplicate()
	fill_stylebox.set_bg_color(ui_color)  # Set the fill color to ui_color
	progress_bar.add_theme_stylebox_override("fill", fill_stylebox)

	progress_bar.tooltip_text = attribute.description
	hbox.add_child(progress_bar)

	return hbox





# New function to refresh stats and skills when the window becomes visible
func _on_visibility_changed():
	if visible:
		_on_player_attribute_changed(playerInstance)
