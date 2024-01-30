extends Sprite3D


# This script is intended to be used on a node functioning as a held item, which chould be a weapon
# This script will keep track of what is equipped and if it is a weapon
# If has functions to deal with melee weapons and ranged weapons
# For ranged weapons it has functions and properties to keep track of ammunition and reloading
# It has functions to spawn projectiles

signal ammo_changed(current_ammo: int, max_ammo: int, lefthand:bool)
signal fired_weapon(equippedWeapon)

# Reference to the node that will hold existing projectiles
@export var projectiles: Node3D

# Variables to set the bullet speed and damage
@export var bullet_speed: float
@export var bullet_damage: float

# Reference to the scene that will be instantiated for a bullet
@export var bullet_scene: PackedScene

# A timer that will prevent the user from reloading while a reload is happening now
@export var reload_timer: Timer
# Will keep a weapon from firing when it's cooldown period has not passed yet
@export var attack_cooldown_timer: Timer

# Reference to the player node
@export var player: NodePath
# Reference to the hud node
@export var hud: NodePath
# True of this is the left hand. False if this is the right hand
@export var equipped_left: bool

# Reference to the audio nodes
@export var shoot_audio_player : AudioStreamPlayer3D
@export var shoot_audio_randomizer : AudioStreamRandomizer
@export var reload_audio_player : AudioStreamPlayer3D


# Define properties for the item. It can be a weapon (melee or ranged) or some other item
var heldItem: Dictionary
var magazine
var ammo

# Booleans to enforce the reload and cooldown timers
var can_reload: bool = true
var in_cooldown: bool = false

# The current and max ammo
var current_ammo: int = 0
var max_ammo: int = 0
var default_firing_speed: float = 0.25
var default_reload_speed: float = 1.0

# Variables for recoil
var default_recoil: float = 0.1
# Tracks the current level of recoil applied to the weapon.
var recoil_modifier: float = 0.0
# The maximum recoil value, derived from the Ranged.recoil property of the weapon.
var max_recoil: float = 0.0
# The amount by which recoil increases per shot, calculated to reach max_recoil after 25% of the max ammo is fired.
var recoil_increment: float = 0.0
# The amount by which recoil decreases per frame when the mouse button is not pressed.
var recoil_decrement: float = 0.0

# Additional variables to track if buttons are held down
var is_left_button_held: bool = false
var is_right_button_held: bool = false

func _input(event):
	if not heldItem:
		return  # Return early if no weapon is equipped

	# Update the button held state
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_left_button_held = event.pressed
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			is_right_button_held = event.pressed

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


# Helper function to check if the weapon can fire
func can_fire_weapon() -> bool:
	return General.is_mouse_outside_HUD and General.is_allowed_to_shoot and heldItem and not in_cooldown and can_reload and (current_ammo > 0 or !requires_ammo())


# Function to check if the weapon requires ammo (for ranged weapons)
func requires_ammo() -> bool:
	return heldItem.has("Ranged")
	
	
# Function to handle firing logic for a weapon.
func fire_weapon():
	if !can_fire_weapon():
		return  # Return if no weapon is equipped or no ammo.

	# Update ammo and emit signal.
	current_ammo -= 1
	ammo_changed.emit(current_ammo, max_ammo, equipped_left)

	shoot_audio_player.stream = shoot_audio_randomizer
	shoot_audio_player.play()
	
	var bullet_instance = bullet_scene.instantiate()
	# Decrease the y posistion to ensure proper collision with mobs and furniture
	var spawn_position = global_transform.origin + Vector3(0.0, -0.1, 0.0)
	var cursor_position = get_cursor_world_position()
	var direction = (cursor_position - spawn_position).normalized()
	recoil_modifier = min(recoil_modifier + recoil_increment, max_recoil)
	direction = apply_recoil(direction, recoil_modifier) # Apply recoil effect
	direction.y = 0 # Ensure the bullet moves parallel to the ground.

	projectiles.add_child(bullet_instance) # Add bullet to the scene tree.
	bullet_instance.global_transform.origin = spawn_position
	bullet_instance.set_direction_and_speed(direction, bullet_speed)
	in_cooldown = true
	attack_cooldown_timer.start()


# Helper function to check if reload timer is stopped based on the hand.
func on_reload_timer_stopped():
	can_reload = true


# Function to apply recoil effect to the bullet direction
func apply_recoil(direction: Vector3, recoil_value: float) -> Vector3:
	var random_offset = Vector3(randf() - 0.5, 0, randf() - 0.5) * recoil_value / 100
	return (direction + random_offset).normalized()


# Called when the left weapon is reloaded
# Since only one reload action can run at a time, 
# We check that the right reload timer is stopped
func reload_weapon():
	if can_reload:
		can_reload = false
		current_ammo = max_ammo
		reload_timer.start()  # Start the left reload timer
		# Start HUD progress bar for left-hand weapon
		get_node(hud).start_progress_bar(reload_timer.time_left)  


# Called when the node enters the scene tree for the first time.
func _ready():
	clear_held_item()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Check if the left-hand weapon is reloading.
	if not can_reload and reload_timer.time_left <= reload_audio_player.stream.get_length() and not reload_audio_player.playing:
		reload_audio_player.play()  # Play reload sound for left-hand weapon.

	# Check if the left mouse button is held, a weapon is in the left hand, and is ready to fire
	if is_left_button_held and equipped_left and can_fire_weapon():
		fire_weapon()

	# The right mouse button is held, a weapon is in the right hand, and is ready to fire
	if is_right_button_held and !equipped_left and can_fire_weapon():
		fire_weapon()
		
	# Decrease recoil when the mouse button is not pressed
	if not is_left_button_held and not is_right_button_held:
		recoil_modifier = max(recoil_modifier - recoil_decrement * delta, 0.0)



func _on_reload_timer_timeout():
	if heldItem and not can_reload:
		can_reload = true
		current_ammo = max_ammo
		ammo_changed.emit(current_ammo, max_ammo, equipped_left)



# The player has equipped an item in one of the equipmentslots
# equippedItem is an InventoryItem
# slotName is a string, for example "LeftHand" or "RightHand"
func equip_item(equippedItem: InventoryItem):
	var weaponID = equippedItem.prototype_id
	var weaponData: Dictionary = Gamedata.get_data_by_id(Gamedata.data.items, weaponID)
	if weaponData.has("Ranged"):
		var newMagazineID = weaponData.Ranged.used_magazine
		var newAmmoID = weaponData.Ranged.used_ammo	
		# Set the weapon for the corresponding hand.
		heldItem = weaponData
		
		# Read firing speed and set cooldown timer duration
		var firing_speed = float(heldItem.Ranged.firing_speed) if "firing_speed" in heldItem.Ranged else default_firing_speed
		attack_cooldown_timer.wait_time = firing_speed
		
		# Reload speed setup
		var reload_speed = heldItem.Ranged.reload_speed if "reload_speed" in heldItem.Ranged else default_reload_speed
		reload_timer.wait_time = float(reload_speed)
		
		magazine = Gamedata.get_data_by_id(Gamedata.data.items, newMagazineID)
		ammo = Gamedata.get_data_by_id(Gamedata.data.items, newAmmoID)
		max_ammo = int(magazine.Magazine["max_ammo"])
		current_ammo = max_ammo
		ammo_changed.emit(current_ammo, max_ammo, equipped_left)
		
		# Read recoil and set it
		max_recoil = float(weaponData.Ranged.recoil) if "recoil" in weaponData.Ranged else default_recoil
		recoil_modifier = 0.0
		recoil_increment = max_recoil / (max_ammo * 0.25)  # 25% of max ammo
		recoil_decrement = 4 * recoil_increment
		
		visible = true
	else:
		# Reset weapon, magazine, and ammo if the equipped item is not a weapon.
		clear_held_item()


# Function to clear weapon properties for a specified hand
func clear_held_item():
	visible = false
	heldItem = {}
	magazine = null
	ammo = null
	current_ammo = 0
	max_ammo = 0
	in_cooldown = false
	can_reload = true
	ammo_changed.emit(-1, -1, equipped_left)  # Emit signal to indicate no weapon is equipped


func _on_left_attack_cooldown_timeout():
	in_cooldown = false


func _on_right_attack_cooldown_timeout():
	in_cooldown = false


func _on_hud_item_equipment_slot_was_cleared(slotName):
	if slotName == "LeftHand" and equipped_left:
		clear_held_item()
	elif slotName == "RightHand" and !equipped_left:
		clear_held_item()


func _on_hud_item_was_equipped(equippedItem, slotName):
	if slotName == "LeftHand" and equipped_left:
		equip_item(equippedItem)
	elif slotName == "RightHand" and !equipped_left:
		equip_item(equippedItem)


func can_weapon_reload() -> bool:
	return heldItem and current_ammo < max_ammo and can_reload

# When the inventory is opened or closed, stop firing
# Optionally we can check inventoryWindow.visible to add more control
func _on_hud_inventory_visibility_changed(_inventoryWindow):
	is_left_button_held = false
	is_right_button_held = false
