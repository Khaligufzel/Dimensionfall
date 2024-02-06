extends Sprite3D


# This script is intended to be used on a node functioning as a held item, which chould be a weapon
# This script will keep track of what is equipped and if it is a weapon
# If has functions to deal with melee weapons and ranged weapons
# For ranged weapons it has functions and properties to keep track of ammunition and reloading
# It has functions to spawn projectiles

# Reference to the node that will hold existing projectiles
@export var projectiles: Node3D

# Variables to set the bullet speed and damage
@export var bullet_speed: float
@export var bullet_damage: float

# Reference to the scene that will be instantiated for a bullet
@export var bullet_scene: PackedScene

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
var heldItem: InventoryItem

# The equipmentslot that holds this item
var equipmentSlot: Control

# Booleans to enforce the reload and cooldown timers
var in_cooldown: bool = false
var reload_speed: float = 1.0

# The current and max ammo
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


signal ammo_changed(current_ammo: int, max_ammo: int, lefthand:bool)
signal fired_weapon(equippedWeapon)


# Called when the node enters the scene tree for the first time.
func _ready():
	clear_held_item()
	
	# We connect to the inventory visibility change to interrupt shooting
	Helper.signal_broker.inventory_window_visibility_changed.connect(_on_inventory_visibility_change)
	Helper.signal_broker.item_was_equipped.connect(_on_hud_item_was_equipped)
	Helper.signal_broker.item_slot_cleared.connect(_on_hud_item_equipment_slot_was_cleared)


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
	return General.is_mouse_outside_HUD and not General.is_action_in_progress and General.is_allowed_to_shoot and heldItem and not in_cooldown and (get_current_ammo() > 0 or !requires_ammo())


# Function to check if the weapon requires ammo (for ranged weapons)
func requires_ammo() -> bool:
	return not heldItem.get_property("Ranged") == null
	
	
# Function to handle firing logic for a weapon.
func fire_weapon():
	if !can_fire_weapon():
		return  # Return if no weapon is equipped or no ammo.

	# Update ammo and emit signal.
	_subtract_ammo(1)

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


func _subtract_ammo(amount: int):
	var magazine: InventoryItem = ItemManager.get_magazine(heldItem)
	if magazine:
		# We duplicate() because Gloot might return the original Magazine array from the protoset
		var magazineProperties = magazine.get_property("Magazine").duplicate()
		var ammunition: int = int(magazineProperties["current_ammo"])
		ammunition -= amount
		magazineProperties["current_ammo"] = ammunition
		magazine.set_property("Magazine", magazineProperties)
		ammo_changed.emit(get_current_ammo(), get_max_ammo(), equipped_left)


func get_current_ammo() -> int:
	var magazine: InventoryItem = ItemManager.get_magazine(heldItem)
	if magazine:
		var magazineProperties = magazine.get_property("Magazine")
		if magazineProperties and magazineProperties.has("current_ammo"):
			return int(magazineProperties["current_ammo"])
		else:
			return 0
	else: 
		return 0


func get_max_ammo() -> int:
	var magazine: InventoryItem = ItemManager.get_magazine(heldItem)
	if magazine:
		var magazineProperties = magazine.get_property("Magazine")
		return int(magazineProperties["max_ammo"])
	else: 
		return 0


# Function to apply recoil effect to the bullet direction
func apply_recoil(direction: Vector3, recoil_value: float) -> Vector3:
	var random_offset = Vector3(randf() - 0.5, 0, randf() - 0.5) * recoil_value / 100
	return (direction + random_offset).normalized()



# When the user wants to reload the item
func reload_weapon():
	if heldItem and not heldItem.get_property("Ranged") == null and not General.is_action_in_progress and not ItemManager.find_compatible_magazine(heldItem) == null:
		var magazine = ItemManager.get_magazine(heldItem)
		if not magazine:
			ItemManager.start_reload(heldItem, reload_speed)
		elif get_current_ammo() < get_max_ammo():
			ItemManager.start_reload(heldItem, reload_speed)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Check if the left-hand weapon is reloading.
	if is_weapon_reloading() and not reload_audio_player.playing:
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


# When a magazine is removed
func on_magazine_removed():
	ammo_changed.emit(-1, -1, equipped_left)


# When a magazine is inserted
func on_magazine_inserted():
	if heldItem:
		var rangedProperties = heldItem.get_property("Ranged")

		# Update recoil properties
		max_recoil = float(rangedProperties.get("recoil", default_recoil))
		recoil_increment = max_recoil / (get_max_ammo() * 0.25)
		recoil_decrement = 2 * recoil_increment

		heldItem.set_property("is_reloading", false)
		ammo_changed.emit(get_current_ammo(), get_max_ammo(), equipped_left)


# The player has equipped an item in one of the equipmentslots
# equippedItem is an InventoryItem
# slotName is a string, for example "LeftHand" or "RightHand"
func equip_item(equippedItem: InventoryItem, slot: Control):
	heldItem = equippedItem
	equipmentSlot = slot
	equipmentSlot.equippedItem = self
	var rangedProperties = heldItem.get_property("Ranged")
	if rangedProperties:
		# Set weapon properties
		var firing_speed = rangedProperties.get("firing_speed", default_firing_speed)
		attack_cooldown_timer.wait_time = float(firing_speed)
		
		reload_speed = float(rangedProperties.get("reload_speed", default_reload_speed))
		
		visible = true
		ammo_changed.emit(0, 0, equipped_left)  # Emit signal to indicate no weapon is equipped
		heldItem.properties_changed.connect(_on_helditem_properties_changed)
	else:
		clear_held_item()


# Function to clear weapon properties for a specified hand
func clear_held_item():
	if heldItem and heldItem.properties_changed.is_connected(_on_helditem_properties_changed):
		heldItem.properties_changed.disconnect(_on_helditem_properties_changed)
		heldItem.set_property("is_reloading", false)
	visible = false
	heldItem = null
	in_cooldown = false
	ammo_changed.emit(-1, -1, equipped_left)  # Emit signal to indicate no weapon is equipped


func _on_left_attack_cooldown_timeout():
	in_cooldown = false


func _on_right_attack_cooldown_timeout():
	in_cooldown = false


func _on_hud_item_equipment_slot_was_cleared(_equippedItem, slot):
	if slot.is_left_slot and equipped_left:
		clear_held_item()
	elif not slot.is_left_slot and not equipped_left:
		clear_held_item()


# The slot has equipped something and we store it in the correct EquippedItem
func _on_hud_item_was_equipped(equippedItem, slot):
	if slot.is_left_slot and equipped_left:
		equip_item(equippedItem, slot)
	elif not slot.is_left_slot and not equipped_left:
		equip_item(equippedItem, slot)


# When the inventory is opened or closed, stop firing
# Optionally we can check inventoryWindow.visible to add more control
func _on_inventory_visibility_change(_inventoryWindow):
	is_left_button_held = false
	is_right_button_held = false



# Function to check if the weapon can be reloaded
func can_weapon_reload() -> bool:
	# Check if the weapon is a ranged weapon
	if heldItem and heldItem.get_property("Ranged"):
		# Check if neither mouse button is pressed
		if not is_left_button_held and not is_right_button_held:
			# Check if the weapon is not currently reloading and if a compatible magazine is available in the inventory
			if not is_weapon_reloading() and not ItemManager.find_compatible_magazine(heldItem) == null:
				# Additional checks can be added here if needed
				return true
	return false


# When the properties of the held item change
func _on_helditem_properties_changed():
	if heldItem and heldItem.get_property("Ranged"):
		if heldItem.get_property("current_magazine") == null:
			on_magazine_removed()
		else:
			on_magazine_inserted()


func is_weapon_reloading() -> bool:
	if heldItem and heldItem.get_property("Ranged"):
		if heldItem.get_property("is_reloading") == null:
			return false
		else:
			return bool(heldItem.get_property("is_reloading"))
	return false
	
