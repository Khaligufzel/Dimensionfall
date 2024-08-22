extends Sprite3D

# This script is intended to be used on a node functioning as a held item, which could be a weapon
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
@export var melee_attack_area: Area3D
@export var melee_collision_shape: CollisionShape3D

# Reference to the player node
@export var player: CharacterBody3D
# The visual representation of the player that will actually rotate over the y axis
@export var playerSprite: Sprite3D 
# Reference to the hud node
@export var hud: NodePath
# True if this is the left hand. False if this is the right hand
@export var equipped_left: bool

# Reference to the audio nodes
@export var shoot_audio_player : AudioStreamPlayer3D
@export var shoot_audio_randomizer : AudioStreamRandomizer
@export var reload_audio_player : AudioStreamPlayer3D

# Define properties for the item. It can be a weapon (melee or ranged) or some other item
var heldItem: InventoryItem

# The equipment slot that holds this item
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

var entities_in_melee_range = [] # Used to keep track of entities in melee range

signal ammo_changed(current_ammo: int, max_ammo: int, lefthand: bool)

# Called when the node enters the scene tree for the first time.
func _ready():
	clear_held_item()
	melee_attack_area.body_entered.connect(_on_entered_melee_range)
	melee_attack_area.body_exited.connect(_on_exited_melee_range)
	melee_attack_area.body_shape_entered.connect(_on_body_shape_entered_melee_range)
	melee_attack_area.body_shape_exited.connect(_on_body_shape_exited_melee_range)
	# We connect to the inventory visibility change to interrupt shooting
	Helper.signal_broker.inventory_window_visibility_changed.connect(_on_inventory_visibility_change)
	Helper.signal_broker.item_was_equipped.connect(_on_hud_item_was_equipped)
	Helper.signal_broker.item_was_unequipped.connect(_on_hud_item_equipment_slot_was_cleared)

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
	if not heldItem:
		return false
	if heldItem.get_property("Melee") != null:  # Assuming melee weapons have a 'Melee' property
		return General.is_mouse_outside_HUD and not General.is_action_in_progress and heldItem and not in_cooldown
	return General.is_mouse_outside_HUD and not General.is_action_in_progress and General.is_allowed_to_shoot and heldItem and not in_cooldown and (get_current_ammo() > 0 or not requires_ammo())


# Function to check if the weapon requires ammo (for ranged weapons)
func requires_ammo() -> bool:
	return not heldItem.get_property("Ranged") == null


# Function to handle firing logic for a weapon.
func fire_weapon():
	if not can_fire_weapon():
		return  # Return if no weapon is equipped or no ammo.

	if heldItem.get_property("Melee") != null:
		perform_melee_attack()
	else:
		perform_ranged_attack()


func add_weapon_xp_on_use():
	if heldItem.get_property("Melee") != null:
		var melee_properties = heldItem.get_property("Melee")
		var used_skill = melee_properties.get("used_skill", {})
		var skill_id = used_skill.get("skill_id", "")
		var xp_gain = used_skill.get("xp", 0)
		player.add_skill_xp(skill_id, xp_gain)
	elif heldItem.get_property("Ranged") != null:
		var rangedproperties = heldItem.get_property("Ranged")
		if rangedproperties.has("used_skill"):
			var used_skill = rangedproperties.used_skill
			player.add_skill_xp(used_skill.skill_id, used_skill.xp)


# Return the accuracy based on skill level
func calculate_accuracy() -> float:
	var rangedproperties = heldItem.get_property("Ranged")
	var skillid = Helper.json_helper.get_nested_data(rangedproperties, "used_skill.skill_id")
	var skill_level = player.get_skill_level(skillid)
	# Minimum accuracy is 25%, maximum is 100% at level 30
	var min_accuracy = 0.25
	var max_accuracy = 1.0
	var required_level = 30

	if skill_level >= required_level:
		return max_accuracy
	else:
		return min_accuracy + (max_accuracy - min_accuracy) * (skill_level / required_level)


# Function to calculate direction with accuracy and recoil applied
func calculate_direction(target_position: Vector3, spawn_position: Vector3) -> Vector3:
	var accuracy = calculate_accuracy()
	var direction = (target_position - spawn_position).normalized()
	var random_offset = Vector3(randf() - 0.5, 0, randf() - 0.5) * (1.0 - accuracy) * 0.5
	random_offset *= (1.0 - accuracy)
	var recoil_offset = Vector3(randf() - 0.5, 0, randf() - 0.5) * recoil_modifier / 100
	recoil_modifier = min(recoil_modifier + recoil_increment, max_recoil)  # Update recoil_modifier
	return (direction + random_offset + recoil_offset).normalized()
	

# The user performs a ranged attack
func perform_ranged_attack():
	# Update ammo and emit signal.
	_subtract_ammo(1)

	shoot_audio_player.stream = shoot_audio_randomizer
	shoot_audio_player.play()
	
	var bullet_instance = bullet_scene.instantiate()
	# Decrease the y position to ensure proper collision with mobs and furniture
	var spawn_position = global_transform.origin + Vector3(0.0, -0.1, 0.0)
	var cursor_position = get_cursor_world_position()
	var direction = calculate_direction(cursor_position, spawn_position)
	direction.y = 0 # Ensure the bullet moves parallel to the ground.

	projectiles.add_child(bullet_instance) # Add bullet to the scene tree.
	bullet_instance.global_transform.origin = spawn_position
	bullet_instance.set_direction_and_speed(direction, bullet_speed)
	in_cooldown = true
	add_weapon_xp_on_use()
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

# When the user wants to reload the item
func reload_weapon():
	if heldItem.get_property("Melee") != null:
		return  # No action needed for melee weapons
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
	if is_right_button_held and not equipped_left and can_fire_weapon():
		fire_weapon()
		
	# Decrease recoil when the mouse button is not pressed
	if heldItem and heldItem.get_property("Ranged") != null:
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

# Function to clear weapon properties for a specified hand
func clear_held_item():
	if heldItem and heldItem.properties_changed.is_connected(_on_helditem_properties_changed):
		heldItem.properties_changed.disconnect(_on_helditem_properties_changed)
		heldItem.set_property("is_reloading", false)
	disable_melee_collision_shape()
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

# Something has entered melee range
func _on_entered_melee_range(body):
	if body.is_in_group("mobs") or body.is_in_group("furniture"):  # Check if the body is a mob or furniture
		entities_in_melee_range.append(body)

# Something left melee range
func _on_exited_melee_range(body):
	if body in entities_in_melee_range:
		entities_in_melee_range.erase(body)

func _on_body_shape_entered_melee_range(body_rid: RID, body: Node, _body_shape_index: int, _local_shape_index: int):
	# Body will have a value if the body shape is in the scene tree. This function should
	# only handle shapes that are outside the scene tree, like StaticFurnitureSrv
	if body:
		return
	entities_in_melee_range.append(body_rid)
	
func _on_body_shape_exited_melee_range(body_rid: RID, _body: Node, _body_shape_index: int, _local_shape_index: int):
	if entities_in_melee_range.has(body_rid):
		entities_in_melee_range.erase(body_rid)


# Animates a melee attack by moving the weapon sprite forward and then back
func animate_attack():
	var tween = get_tree().create_tween().set_loops(1)  # Create tween and set loops
	var original_position = position  # Use local position
	var target_position = position  # Initialize target position

	# Set the default positions for right and left hands
	var default_right_hand_position = Vector3(-0.191, -0.123, 0)
	var default_left_hand_position = Vector3(-0.195, 0.117, 0)

	# Adjust position and calculate target based on equipped hand
	if equipped_left:
		position = default_left_hand_position
		target_position.x -= 0.2  # Move forward by 0.2 units
		tween.tween_property(self, "rotation_degrees:z", rotation_degrees.z + 15, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	else:
		position = default_right_hand_position
		target_position.x -= 0.2  # Move forward by 0.2 units
		tween.tween_property(self, "rotation_degrees:z", rotation_degrees.z - 15, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	# Animate the position
	tween.tween_property(self, "position", target_position, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	# Add a callback to reset position and rotation
	tween.tween_callback(reset_attack_position.bind(original_position, rotation_degrees))

# Return the weapon sprite to its original position after animating
func reset_attack_position(original_position, original_rotation_degrees):
	position = original_position
	rotation_degrees = original_rotation_degrees

# Function to perform a melee attack
func perform_melee_attack():
	var melee_properties = heldItem.get_property("Melee")
	if melee_properties == null:
		print_debug("Error: Melee properties not found.")
		return
		
	in_cooldown = true
	attack_cooldown_timer.start()
	
	var melee_damage = melee_properties.get("damage", 0)
	var melee_skill_id = melee_properties.get("used_skill", {}).get("skill_id", "")
	var skill_level = player.get_skill_level(melee_skill_id)
	var hit_chance = 0.65 + (skill_level / 100.0) * (1.0 - 0.65)

	var attack: Dictionary = {"damage": melee_damage, "hit_chance": hit_chance}
	# Each mob in range will get hit with the weapon
	# TODO: Hit only one entity each swing unless the weapon has some kind of flag
	# TODO: Check if the entity is behind an obstacle
	for entity in entities_in_melee_range:
		if entity is RID:
			Helper.signal_broker.melee_attacked_rid.emit(entity, attack)
		else:
			entity.get_hit(attack)

	animate_attack()
	add_weapon_xp_on_use()


# The player has equipped an item in one of the equipment slots
# equippedItem is an InventoryItem
# slot is a Control node that represents the equipment slot
func equip_item(equippedItem: InventoryItem, slot: Control):
	heldItem = equippedItem
	equipmentSlot = slot
	equipmentSlot.equippedItem = self

	# Clear any existing configurations
	clear_melee_collision_shape()

	# Check if the equipped item is a ranged weapon
	if equippedItem.get_property("Ranged") != null:
		# Set properties specific to ranged weapons
		setup_ranged_weapon_properties(equippedItem)

	elif equippedItem.get_property("Melee") != null:
		# Set properties specific to melee weapons
		setup_melee_weapon_properties(equippedItem)

	else:
		# If the item is neither melee nor ranged, handle as a generic item
		visible = false
		clear_held_item()  # Clears any existing setup if the item is not a weapon

# Setup the properties for ranged weapons
func setup_ranged_weapon_properties(equippedItem: InventoryItem):
	var ranged_properties = equippedItem.get_property("Ranged")
	var firing_speed = ranged_properties.get("firing_speed", default_firing_speed)
	attack_cooldown_timer.wait_time = float(firing_speed)
	reload_speed = float(ranged_properties.get("reload_speed", default_reload_speed))
	visible = true
	ammo_changed.emit(0, 0, equipped_left)  # Signal to update ammo display for ranged weapons
	heldItem.properties_changed.connect(_on_helditem_properties_changed)

# Setup the properties for melee weapons
func setup_melee_weapon_properties(equippedItem: InventoryItem):
	var melee_properties = equippedItem.get_property("Melee")
	visible = true
	ammo_changed.emit(-1, -1, equipped_left)  # Indicate no ammo needed for melee weapons

	var reach = melee_properties.get("reach", 0)  # Default reach to 0 if not specified
	if reach > 0:
		configure_melee_collision_shape(reach)
	else:
		disable_melee_collision_shape()

	var melee_skill_id = melee_properties.get("used_skill", {}).get("skill_id", "")
	var skill_level = player.get_skill_level(melee_skill_id)
	var cooldown_time = 1.5 - (skill_level / 100.0) * (1.5 - 0.5)
	attack_cooldown_timer.wait_time = cooldown_time


# Configure the melee collision shape based on the weapon's reach
# This creates two triangles on top of each other in front of the player and pointing to the player
# When an entity enters the boundary of the stacked triangles, it is considered within reach
# Increasing the reach will extend the shape
func configure_melee_collision_shape(reach: float):
	var shape = ConvexPolygonShape3D.new()
	var points = [
		Vector3(0, 0, 0.325),        # First point
		Vector3(0, 0, -0.325),       # Second point
		Vector3(-reach, -1, 0.325),  # Third point
		Vector3(-reach, 1, 0.325),   # Fourth point
		Vector3(-reach, -1, -0.325), # Fifth point
		Vector3(-reach, 1, -0.325)   # Sixth point
	]
	shape.points = points
	melee_collision_shape.shape = shape

# Disable the melee collision detection by setting an invalid shape or disabling it
func disable_melee_collision_shape():
	melee_collision_shape.disabled = true  # Disable the collision shape

# Clear any configurations on the melee collision shape
func clear_melee_collision_shape():
	melee_collision_shape.disabled = false  # Ensure it's not disabled when changing weapons
	melee_collision_shape.shape = null  # Clear the previous shape to reset its configuration
