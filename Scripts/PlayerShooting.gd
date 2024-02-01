extends Node3D


# Define properties for left-hand and right-hand weapons.
@export var left_hand_item: Sprite3D
@export var right_hand_item: Sprite3D


@export var player: NodePath
@export var hud: NodePath



func _input(event):
	# Return early if no weapons are equipped
	if not left_hand_item or not right_hand_item:
		return

	if event.is_action_pressed("reload_weapon"):
		if General.is_action_in_progress:
			return
		# Check if both weapons can be reloaded
		if left_hand_item.can_weapon_reload() and right_hand_item.can_weapon_reload():
			# Compare the current ammo to decide which weapon to reload
			if left_hand_item.get_current_ammo() < right_hand_item.get_current_ammo():
				left_hand_item.reload_weapon()
			elif left_hand_item.get_current_ammo() > right_hand_item.get_current_ammo():
				right_hand_item.reload_weapon()
			else:
				# If both have equal ammo, reload the left hand first
				if left_hand_item.can_weapon_reload():
					# Only the left hand weapon can be reloaded
					left_hand_item.reload_weapon()
				elif right_hand_item.can_weapon_reload():
					# Only the right hand weapon can be reloaded
					right_hand_item.reload_weapon()
		else:
			# If both have equal ammo, reload the left hand first
			if left_hand_item.can_weapon_reload():
				# Only the left hand weapon can be reloaded
				left_hand_item.reload_weapon()
			elif right_hand_item.can_weapon_reload():
				# Only the right hand weapon can be reloaded
				right_hand_item.reload_weapon()
