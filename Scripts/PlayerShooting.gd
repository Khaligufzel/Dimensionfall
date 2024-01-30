extends Node3D


# Define properties for left-hand and right-hand weapons.
var left_hand_weapon
var right_hand_weapon
var left_hand_magazine
var right_hand_magazine
var left_hand_ammo
var right_hand_ammo

var current_left_ammo : int
var max_left_ammo : int
var current_right_ammo : int
var max_right_ammo : int

signal ammo_changed(current_ammo: int, max_ammo: int, leftHand: bool)

@export var projectiles: NodePath
@export var bullet_speed: float
@export var bullet_damage: float
#@export var cooldown = 0.25
@export var bullet_scene: PackedScene

@export var bullet_line_scene: PackedScene

@export var left_attack_cooldown : Timer
@export var right_attack_cooldown : Timer
@export var left_reload_timer : Timer
@export var right_reload_timer : Timer


@export var player: NodePath
@export var hud: NodePath

@export var shoot_audio_player : AudioStreamPlayer3D
@export var shoot_audio_randomizer : AudioStreamRandomizer

@export var reload_audio_player : AudioStreamPlayer3D
#@export var reload_audio_randomizer : AudioStreamRandomizer

var damage = 25


func _input(event):
	if not left_hand_weapon and not right_hand_weapon:
		return  # Return early if no weapon is equipped
	
	if event.is_action_pressed("reload_weapon"):
		# Reload logic for both weapons with additional checks.
		if left_hand_weapon and current_left_ammo < max_left_ammo and right_reload_timer.is_stopped():
			reload_left_weapon()
		elif right_hand_weapon and current_right_ammo < max_right_ammo and left_reload_timer.is_stopped():
			reload_right_weapon()

	# Handling left and right click for different weapons.
	if event.is_action_pressed("click_left") and General.is_mouse_outside_HUD and General.is_allowed_to_shoot and left_hand_weapon:
		fire_weapon(left_hand_weapon, current_left_ammo, "LeftHand")

	if event.is_action_pressed("click_right") and General.is_mouse_outside_HUD and General.is_allowed_to_shoot and right_hand_weapon:
		fire_weapon(right_hand_weapon, current_right_ammo, "RightHand")

#
#func get_cursor_world_position() -> Vector3:
	#var camera = get_viewport().get_camera()
	#var mouse_pos = get_viewport().get_mouse_position()
	#var from = camera.project_ray_origin(mouse_pos)
	#var to = from + camera.project_ray_normal(mouse_pos) * 1000
	#var space_state = get_world_3d().direct_space_state
	#var result = space_state.intersect_ray(from, to)
#
	#if result:
		#return result.position
	#else:
		#return to

func get_cursor_world_position() -> Vector3:
	var camera = get_tree().get_first_node_in_group("Camera")
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000

	# Create a PhysicsRayQueryParameters3D object
	var query = PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to

	# Perform the raycast
	var space_state = get_world_3d().direct_space_state
	var result = space_state.intersect_ray(query)

	if result.size() != 0:  # Check if the result dictionary is not empty
		return result.position
	else:
		return to



# New function to handle firing logic for a weapon.
func fire_weapon(weapon, current_ammo, hand):
	if not weapon or current_ammo <= 0:
		return  # Return if no weapon is equipped or no ammo.
	
	
	var cooldown_timer = get_cooldown_timer(hand)
	if cooldown_timer.is_stopped() and reload_timer_is_stopped(hand):
		cooldown_timer.start()
		# Update ammo and emit signal.
		if hand == "LeftHand":
			current_left_ammo -= 1
			ammo_changed.emit(current_left_ammo, max_left_ammo, true)
		elif hand == "RightHand":
			current_right_ammo -= 1
			ammo_changed.emit(current_right_ammo, max_right_ammo, false)
			
		
		shoot_audio_player.stream = shoot_audio_randomizer
		shoot_audio_player.play()
		#
			#
		#var projectile = bullet_scene.instantiate()
		#get_parent().add_child(projectile)  # Add the projectile to the scene
#
		##
		##var space_state = get_world_3d().direct_space_state
		##var mouse_pos : Vector2 = get_viewport().get_mouse_position()
		#
		#var direction = (get_cursor_world_position() - global_transform.origin).normalized()
		##projectile.global_transform.origin = muzzle_position
		#projectile.set_direction_and_speed(direction, 100)


		var bullet_instance = bullet_scene.instantiate()
		var spawn_position = global_transform.origin + Vector3(0, 0.5, 0) # Slight elevation above ground.
		var cursor_position = get_cursor_world_position()
		var direction = (cursor_position - spawn_position).normalized()
		direction.y = 0 # Ensure the bullet moves parallel to the ground.

		bullet_instance.global_transform.origin = spawn_position
		bullet_instance.set_direction_and_speed(direction, bullet_speed)
		get_node(projectiles).add_child(bullet_instance) # Add bullet to the scene tree.

		#
		#var layer = pow(2, 1-1) + pow(2, 2-1) + pow(2, 3-1)
		#var mouse_pos_in_world = Helper.raycast_from_mouse(mouse_pos, layer).position
		#var query = PhysicsRayQueryParameters3D.create(global_position, global_position + (Vector3(mouse_pos_in_world.x - global_position.x, 0, mouse_pos_in_world.z - global_position.z)).normalized() * 10000, layer, [self])
#
		#var result = space_state.intersect_ray(query)
		#
		#if result:
			#print("hit")
			#Helper.line(global_position, result.position)
			#
			#if result.collider.has_method("_get_hit"):
				#result.collider._get_hit(damage)


# Helper function to get the appropriate cooldown timer based on the hand.
func get_cooldown_timer(hand: String) -> Timer:
	if hand == "LeftHand":
		return left_attack_cooldown
	else:
		return right_attack_cooldown

# Helper function to check if reload timer is stopped based on the hand.
func reload_timer_is_stopped(hand: String) -> bool:
	if hand == "LeftHand":
		return left_reload_timer.is_stopped()
	else:
		return right_reload_timer.is_stopped()

# Called when the left weapon is reloaded
# Since only one reload action can run at a time, 
# We check that the right reload timer is stopped
func reload_left_weapon():
	if right_reload_timer.is_stopped():
		current_left_ammo = max_left_ammo
		left_reload_timer.start()  # Start the left reload timer
		get_node(hud).start_progress_bar(left_reload_timer.time_left)  # Start HUD progress bar for left-hand weapon

# Called when the right weapon is reloaded
# Since only one reload action can run at a time, 
# We check that the left reload timer is stopped
func reload_right_weapon():
	if left_reload_timer.is_stopped():
		current_right_ammo = max_right_ammo
		right_reload_timer.start()  # Start the right reload timer
		get_node(hud).start_progress_bar(right_reload_timer.time_left)  # Start HUD progress bar for right-hand weapon


# Called when the node enters the scene tree for the first time.
func _ready():
	clear_weapon_properties("LeftHand")
	clear_weapon_properties("RightHand")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	# Check if the left-hand weapon is reloading.
	if not left_reload_timer.is_stopped() and left_reload_timer.time_left <= reload_audio_player.stream.get_length() and not reload_audio_player.playing:
		reload_audio_player.play()  # Play reload sound for left-hand weapon.

	# Check if the right-hand weapon is reloading.
	if not right_reload_timer.is_stopped() and right_reload_timer.time_left <= reload_audio_player.stream.get_length() and not reload_audio_player.playing:
		reload_audio_player.play()  # Play reload sound for right-hand weapon.



# The weapon is reloaded once the timer has stopped
func _on_left_reload_time_timeout():
	if left_hand_weapon:
		current_left_ammo = max_left_ammo
		ammo_changed.emit(current_left_ammo, max_left_ammo, true)

func _on_right_reload_time_timeout():
	if right_hand_weapon:
		current_right_ammo = max_right_ammo
		ammo_changed.emit(current_right_ammo, max_right_ammo, false)


# The player has equipped an item in one of the equipmentslots
# equippedItem is an InventoryItem
# slotName is a string, for example "LeftHand" or "RightHand"
func _on_hud_item_was_equipped(equippedItem: InventoryItem, slotName: String):
	# Adjust this function to handle dual-wielding.
	var weaponID = equippedItem.prototype_id
	var weaponData = Gamedata.get_data_by_id(Gamedata.data.items, weaponID)
	if weaponData.has("Ranged"):
		var newMagazineID = weaponData.Ranged.used_magazine
		var newAmmoID = weaponData.Ranged.used_ammo
		# Set the weapon for the corresponding hand.
		if slotName == "LeftHand":
			left_hand_weapon = weaponData
			left_hand_magazine = Gamedata.get_data_by_id(Gamedata.data.items, newMagazineID)
			left_hand_ammo = Gamedata.get_data_by_id(Gamedata.data.items, newAmmoID)
			max_left_ammo = int(left_hand_magazine.Magazine["max_ammo"])
			current_left_ammo = max_left_ammo
			ammo_changed.emit(current_left_ammo, max_left_ammo, true)
		elif slotName == "RightHand":
			right_hand_weapon = weaponData
			right_hand_magazine = Gamedata.get_data_by_id(Gamedata.data.items, newMagazineID)
			right_hand_ammo = Gamedata.get_data_by_id(Gamedata.data.items, newAmmoID)
			max_right_ammo = int(right_hand_magazine.Magazine["max_ammo"])
			current_right_ammo = max_right_ammo
			ammo_changed.emit(current_right_ammo, max_right_ammo, false)
	else:
		# Reset weapon, magazine, and ammo if the equipped item is not a weapon.
		if slotName == "LeftHand":
			left_hand_weapon = null
			left_hand_magazine = null
			left_hand_ammo = null
			current_left_ammo = 0
			max_left_ammo = 0
			ammo_changed.emit(-1,-1, false)
		elif slotName == "RightHand":
			right_hand_weapon = null
			right_hand_magazine = null
			right_hand_ammo = null
			current_right_ammo = 0
			max_right_ammo = 0
			ammo_changed.emit(-1,-1, true)

# Called when an equipment slot was cleared
# slotName can be "LeftHand" or "RightHand"
func _on_hud_item_equipment_slot_was_cleared(slotName):
	clear_weapon_properties(slotName)

# Function to clear weapon properties for a specified hand
func clear_weapon_properties(hand: String):
	if hand == "LeftHand":
		left_hand_weapon = null
		left_hand_magazine = null
		left_hand_ammo = null
		current_left_ammo = 0
		max_left_ammo = 0
	elif hand == "RightHand":
		right_hand_weapon = null
		right_hand_magazine = null
		right_hand_ammo = null
		current_right_ammo = 0
		max_right_ammo = 0
	ammo_changed.emit(-1, -1, hand == "LeftHand")  # Emit signal to indicate no weapon is equipped
