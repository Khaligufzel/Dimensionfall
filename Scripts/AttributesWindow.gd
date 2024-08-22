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
	var icon = TextureRect.new()
	icon.texture = attribute.sprite
	hbox.add_child(icon)

	var label = Label.new()
	label.text = attribute.name + ": " + str(attribute.current_amount)
	label.tooltip_text = attribute.description
	hbox.add_child(label)

	return hbox


# New function to refresh stats and skills when the window becomes visible
func _on_visibility_changed():
	if visible:
		_on_player_attribute_changed(playerInstance)
