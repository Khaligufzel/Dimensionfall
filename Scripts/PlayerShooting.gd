extends Node3D


# Define properties for left-hand and right-hand weapons.
@export var left_hand_item: Sprite3D
@export var right_hand_item: Sprite3D


@export var player: NodePath
@export var hud: NodePath




func _input(event):
	if not left_hand_item and not right_hand_item:
		return  # Return early if no weapon is equipped
	
	if event.is_action_pressed("reload_weapon"):
		if left_hand_item.can_reload and right_hand_item.can_reload:
			left_hand_item.reload_weapon()
		elif right_hand_item.can_reload and left_hand_item.can_reload:
			right_hand_item.reload_weapon()
