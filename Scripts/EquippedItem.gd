class_name EquippedItem
extends Sprite3D


## 🔹 EQUIPPED ITEM HANDLER 🔹 ##
## This script is intended to be used on a node functioning as a held item, which could be a weapon
## This script handles items held by the player, including weapons & tools.
## It tracks ammo, firing, melee combat, and tool functionality.


# --- EXPORTS & REFERENCES ---
@export var projectiles: Node3D # Reference to the node that will hold existing projectiles
@export var bullet_speed: float # Variables to set the bullet speed
@export var bullet_scene: PackedScene # Reference to the scene that will be instantiated for a bullet
# Will keep a weapon from firing when it's cooldown period has not passed yet
@export var attack_cooldown_timer: Timer
@export var slot_idx: int
@export var melee_hitbox: Area3D
@export var melee_collision_shape: CollisionShape3D
@export var default_hand_position: Vector3
@export var melee_attack_z_rotation_offset: float

@export var player: CharacterBody3D # Reference to the player node
@export var hud: NodePath # Reference to the hud node

# Reference to the audio nodes
@export var shoot_audio_player: AudioStreamPlayer3D
@export var shoot_audio_randomizer: AudioStreamRandomizer
@export var reload_audio_player: AudioStreamPlayer3D

@export var flashlight_spotlight: SpotLight3D = null # The light representing the flashlight



# --- VARIABLES ---
var equipped_item: InventoryItem # Can be a weapon (melee or ranged) or some other item
var equipment_slot: Control # The equipment slot that holds this item

var in_cooldown: bool = false
var reload_speed: float = 1.0
var is_using_held_item: bool = false
var entities_in_melee_range: Array = [] # Used to keep track of entities in melee range

# --- RECOIL SETTINGS ---
var default_recoil: float = 0.1
var recoil_modifier: float = 0.0 # Tracks the current level of recoil applied to the weapon.
var max_recoil: float = 0.0 # The maximum recoil value, derived from the Ranged.recoil property of the weapon.
var recoil_increment: float = 0.0 # The amount by which recoil increases per shot, calculated to reach max_recoil after 25% of the max ammo is fired.
var recoil_decrement: float = 0.0 # The amount by which recoil decreases per frame when the mouse button is not pressed.

# --- FIRING SETTINGS ---
var default_firing_speed: float = 0.25
var default_reload_speed: float = 1.0

	
func _ready():
	clear_held_item()
	_setup_signals()


func _setup_signals() -> void:
	melee_hitbox.body_entered.connect(_on_entered_melee_range)
	melee_hitbox.body_exited.connect(_on_exited_melee_range)
	melee_hitbox.body_shape_entered.connect(_on_body_shape_entered_melee_range)
	melee_hitbox.body_shape_exited.connect(_on_body_shape_exited_melee_range)


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
	if not equipped_item:
		return false
	if equipped_item.get_property("Melee") != null:  # Assuming melee weapons have a 'Melee' property
		return General.is_mouse_outside_HUD and not General.is_action_in_progress and equipped_item and not in_cooldown
	return General.is_mouse_outside_HUD and not General.is_action_in_progress and General.is_allowed_to_shoot and equipped_item and not in_cooldown and (get_current_ammo() > 0 or not requires_ammo())


# Function to check if the weapon requires ammo (for ranged weapons)
func requires_ammo() -> bool:
	return not equipped_item.get_property("Ranged") == null


# Function to handle firing logic for a weapon.
func fire_weapon():
	if not can_fire_weapon():
		return  # Return if no weapon is equipped or no ammo.

	if equipped_item.get_property("Melee") != null:
		perform_melee_attack()
	else:
		perform_ranged_attack()
	
	is_using_held_item = true


func add_weapon_xp_on_use():
	if equipped_item.get_property("Melee") != null:
		var melee_properties = equipped_item.get_property("Melee")
		var used_skill = melee_properties.get("used_skill", {})
		var skill_id = used_skill.get("skill_id", "")
		var xp_gain = used_skill.get("xp", 0)
		player.add_skill_xp(skill_id, xp_gain)
	elif equipped_item.get_property("Ranged") != null:
		var rangedproperties = equipped_item.get_property("Ranged")
		if rangedproperties.has("used_skill"):
			var used_skill = rangedproperties.used_skill
			player.add_skill_xp(used_skill.skill_id, used_skill.xp)


# Return the accuracy based on skill level
func calculate_accuracy() -> float:
	var rangedproperties = equipped_item.get_property("Ranged")
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
	bullet_instance.attack = _calculate_ranged_attack_data()
	# Decrease the y position to ensure proper collision with mobs and furniture
	var spawn_position = global_transform.origin + Vector3(0.0, -0.1, 0.0)
	var cursor_position = get_cursor_world_position()
	var direction = calculate_direction(cursor_position, spawn_position)
	direction.y = 0 # Ensure the bullet moves parallel to the ground.

	Helper.signal_broker.projectile_spawned.emit(bullet_instance, player.get_rid())
	bullet_instance.global_transform.origin = spawn_position
	bullet_instance.set_direction_and_speed(direction, bullet_speed)
	in_cooldown = true
	add_weapon_xp_on_use()
	attack_cooldown_timer.start()


func _subtract_ammo(amount: int):
	var magazine: InventoryItem = ItemManager.get_magazine(equipped_item)
	if magazine:
		# We duplicate() because Gloot might return the original Magazine array from the protoset
		var magazineProperties = magazine.get_property("Magazine").duplicate()
		var ammunition: int = int(magazineProperties["current_ammo"])
		ammunition -= amount
		magazineProperties["current_ammo"] = ammunition
		magazine.set_property("Magazine", magazineProperties)
		Helper.signal_broker.player_ammo_changed.emit(get_current_ammo(), get_max_ammo(), slot_idx)


func get_current_ammo() -> int:
	var magazine: InventoryItem = ItemManager.get_magazine(equipped_item)
	if magazine:
		var magazineProperties = magazine.get_property("Magazine")
		if magazineProperties and magazineProperties.has("current_ammo"):
			return int(magazineProperties["current_ammo"])
		else:
			return 0
	else: 
		return 0


func get_max_ammo() -> int:
	var magazine: InventoryItem = ItemManager.get_magazine(equipped_item)
	if magazine:
		var magazineProperties = magazine.get_property("Magazine")
		return int(magazineProperties["max_ammo"])
	else: 
		return 0

# When the user wants to reload the item
func reload_weapon():
	if equipped_item.get_property("Melee") != null:
		return  # No action needed for melee weapons
	if equipped_item and not equipped_item.get_property("Ranged") == null and not General.is_action_in_progress and not ItemManager.find_compatible_magazine(equipped_item) == null:
		var magazine = ItemManager.get_magazine(equipped_item)
		if not magazine:
			ItemManager.start_reload(equipped_item, reload_speed)
		elif get_current_ammo() < get_max_ammo():
			ItemManager.start_reload(equipped_item, reload_speed)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Check if the left-hand weapon is reloading.
	if is_weapon_reloading() and not reload_audio_player.playing:
		reload_audio_player.play()  # Play reload sound for left-hand weapon.
		
	# Decrease recoil when the mouse button is not pressed
	if equipped_item and equipped_item.get_property("Ranged") != null:
		if not is_using_held_item:
			recoil_modifier = max(recoil_modifier - recoil_decrement * delta, 0.0)
			
	is_using_held_item = false

func try_activate_equipped_item(_slot_idx: int):
	if can_fire_weapon():
		fire_weapon()

# When a magazine is removed
func on_magazine_removed():
	Helper.signal_broker.player_ammo_changed.emit(-1, -1, slot_idx)

# When a magazine is inserted
func on_magazine_inserted():
	if equipped_item:
		var rangedProperties = equipped_item.get_property("Ranged")
		# Update recoil properties
		max_recoil = float(rangedProperties.get("recoil", default_recoil))
		recoil_increment = max_recoil / (get_max_ammo() * 0.25)
		recoil_decrement = 2 * recoil_increment

		Helper.signal_broker.player_ammo_changed.emit(get_current_ammo(), get_max_ammo(), slot_idx)
		
# Function to clear weapon properties for a specified hand
func clear_held_item():
	if equipped_item and equipped_item.properties_changed.is_connected(_on_helditem_properties_changed):
		equipped_item.properties_changed.disconnect(_on_helditem_properties_changed)
		equipped_item.set_property("is_reloading", false)
	disable_melee_collision_shape()
	refresh_flashlight_visibility()
	visible = false
	equipped_item = null
	in_cooldown = false
	Helper.signal_broker.player_ammo_changed.emit(-1, -1, slot_idx)  # Emit signal to indicate no weapon is equipped

func _on_left_attack_cooldown_timeout():
	in_cooldown = false

func _on_right_attack_cooldown_timeout():
	in_cooldown = false

func _on_hud_item_equipment_slot_was_cleared(_slot_idx: int, _equippedItem: InventoryItem, _slot: Control):
	clear_held_item()

# The slot has equipped something and we store it in the correct EquippedItem
func _on_hud_item_was_equipped(_slot_idx: int, equippedItem: InventoryItem, slot: Control):
	equip_item(equippedItem, slot)

# Function to check if the weapon can be reloaded
func can_weapon_reload() -> bool:
	# Check if the weapon is a ranged weapon
	if equipped_item and equipped_item.get_property("Ranged"):
		# Check if neither mouse button is pressed
		if not is_using_held_item:
			# Check if the weapon is not currently reloading and if a compatible magazine is available in the inventory
			if not is_weapon_reloading() and not ItemManager.find_compatible_magazine(equipped_item) == null:
				# Additional checks can be added here if needed
				return true
	return false

# When the properties of the held item change
func _on_helditem_properties_changed():
	if equipped_item and equipped_item.get_property("Ranged"):
		if equipped_item.get_property("current_magazine") == null:
			on_magazine_removed()
		else:
			on_magazine_inserted()

func is_weapon_reloading() -> bool:
	if equipped_item and equipped_item.get_property("Ranged"):
		if equipped_item.get_property("is_reloading") == null:
			return false
		else:
			return bool(equipped_item.get_property("is_reloading"))
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

	position = default_hand_position
	target_position.x -= 0.2  # Move forward by 0.2 units
	tween.tween_property(self, "rotation_degrees:z", rotation_degrees.z + melee_attack_z_rotation_offset, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

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
	if not equipped_item or equipped_item.get_property("Melee") == null:
		print_debug("Error: No melee weapon equipped.")
		return

	# Start cooldown to prevent spamming attacks
	_start_attack_cooldown()

	# Prepare attack parameters
	var attack_data = _calculate_melee_attack_data()

	# Iterate through all entities in melee range and process attacks
	for entity in entities_in_melee_range:
		_attempt_melee_attack(entity, attack_data)

	# Play attack animation and grant XP
	animate_attack()
	add_weapon_xp_on_use()


# --------------------------
# 🔹 HELPER FUNCTIONS BELOW
# --------------------------

# Start cooldown after an attack
func _start_attack_cooldown() -> void:
	in_cooldown = true
	attack_cooldown_timer.start()


# Calculate melee attack damage and hit chance
func _calculate_melee_attack_data() -> Dictionary:
	var melee_properties = equipped_item.get_property("Melee")
	var damage = melee_properties.get("damage", 0)
	var skill_id = melee_properties.get("used_skill", {}).get("skill_id", "")
	var skill_level = player.get_skill_level(skill_id)
	var hit_chance = 0.65 + (skill_level / 100.0) * (1.0 - 0.65)  # Scales up to 100% with skill level

	return {"damage": damage, "hit_chance": hit_chance}

# Calculate ranged attack damage and hit chance
# TODO: Have variation in damage, maybe by gunn or projectile
func _calculate_ranged_attack_data() -> Dictionary:
	return {"damage": 10, "hit_chance": 100}


# Attempts to hit an entity, ensuring no obstacles are in the way
func _attempt_melee_attack(entity, attack_data: Dictionary) -> void:
	var target_position: Vector3
	var target_rid: RID

	# Determine the entity's position and physics RID
	if entity is Node3D:
		target_position = entity.global_position
		target_rid = entity.get_rid()
	elif entity is RID:
		target_position = PhysicsServer3D.body_get_state(entity, PhysicsServer3D.BODY_STATE_TRANSFORM).origin
		target_rid = entity
	else:
		return  # Skip unknown entity types

	# Check if an obstacle blocks the attack
	if _is_obstacle_between(target_position, target_rid):
		return  # Skip attack if something is in the way

	# Apply attack to the entity
	if entity is RID:
		Helper.signal_broker.melee_attacked_rid.emit(entity, attack_data)
	else:
		entity.get_hit(attack_data)


# Checks if an obstacle is between the player and the target
func _is_obstacle_between(target_position: Vector3, target_rid: RID) -> bool:
	var obstacle_layers = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 6)  # Layers to check for obstacles
	var adjusted_player_position = player.global_position - Vector3(0, 0.5, 0)  # Adjust height for short objects

	var result = Helper.raycast(adjusted_player_position, target_position, obstacle_layers, [player])

	return result and result.rid != target_rid  # True if something else is blocking the attack


# The player has equipped an item in one of the equipment slots
# equippedItem is an InventoryItem
# slot is a Control node that represents the equipment slot
func equip_item(equippedItem: InventoryItem, slot: Control):
	equipped_item = equippedItem
	equipment_slot = slot
	equipment_slot.equippedItem = self

	# Clear any existing configurations
	clear_melee_collision_shape()

	# Check if the equipped item is a ranged weapon
	if equippedItem.get_property("Ranged") != null:
		# Set properties specific to ranged weapons
		setup_ranged_weapon_properties(equippedItem)

	elif equippedItem.get_property("Melee") != null:
		# Set properties specific to melee weapons
		setup_melee_weapon_properties(equippedItem)

	elif equippedItem.get_property("Tool") != null:
		# Set properties specific to tool items
		setup_tool_item_properties(equippedItem)

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
	Helper.signal_broker.player_ammo_changed.emit(0, 0, slot_idx)  # Signal to update ammo display for ranged weapons
	equipped_item.properties_changed.connect(_on_helditem_properties_changed)

# Setup the properties for melee weapons
func setup_melee_weapon_properties(equippedItem: InventoryItem):
	var melee_properties = equippedItem.get_property("Melee")
	visible = true
	Helper.signal_broker.player_ammo_changed.emit(-1, -1, slot_idx)  # Indicate no ammo needed for melee weapons

	var reach = melee_properties.get("reach", 0)  # Default reach to 0 if not specified
	if reach > 0:
		configure_melee_collision_shape(reach)
	else:
		disable_melee_collision_shape()

	var melee_skill_id = melee_properties.get("used_skill", {}).get("skill_id", "")
	var skill_level = player.get_skill_level(melee_skill_id)
	var cooldown_time = 1.5 - (skill_level / 100.0) * (1.5 - 0.5)
	attack_cooldown_timer.wait_time = cooldown_time


# Setup the properties for tool items
func setup_tool_item_properties(_equippedItem: InventoryItem):
	refresh_flashlight_visibility()
	visible = true


func refresh_flashlight_visibility():
	flashlight_spotlight.visible = get_highest_tool_quality("flashlight") > -1


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
	
func scale_melee_texture(reach: float):
	# TODO figure out what this scale should actually be, and offset to a better pivot (or scale from pivot?)
	self.scale = Vector3(reach, 1.0, 1.0)

# Disable the melee collision detection by setting an invalid shape or disabling it
func disable_melee_collision_shape():
	melee_collision_shape.disabled = true  # Disable the collision shape

# Clear any configurations on the melee collision shape
func clear_melee_collision_shape():
	melee_collision_shape.disabled = false  # Ensure it's not disabled when changing weapons
	melee_collision_shape.shape = null  # Clear the previous shape to reset its configuration


# Returns all EquippedItems of the player excluding the one with the given slot_idx
func get_other_equipped_items() -> Array[EquippedItem]:
	if not player:
		print_debug("get_other_equipped_items: No player reference found.")
		return []

	# Filter out the equipped items that do not match the given slot index
	var other_equipped_items: Array[EquippedItem] = []
	for item in player.held_item_slots:
		if item.slot_idx != slot_idx:
			other_equipped_items.append(item)
	return other_equipped_items


# Returns the level of the specified tool quality for the equipped item.
# If the tool does not have the quality, returns -1.
func get_tool_quality(tool_quality: String) -> int:
	if not equipped_item:
		return -1
	var tool_properties = equipped_item.get_property("Tool") or {}
	return tool_properties.get("tool_qualities", {}).get(tool_quality, -1)


# Returns the highest tool quality level among all equipped items.
# If no equipped item has the given tool quality, returns -1.
func get_highest_tool_quality(tool_quality: String) -> int:
	if not player:
		print_debug("get_highest_tool_quality: No player reference found.")
		return -1
	var highest_quality: int = -1

	# Loop over all equipped items and check tool quality
	for item in player.held_item_slots:
		var quality_level = item.get_tool_quality(tool_quality)
		if quality_level > highest_quality:
			highest_quality = quality_level
	return highest_quality
