extends CharacterBody3D

signal update_doll

signal update_stamina_HUD

var is_alive = true

var rng = RandomNumberGenerator.new()

var speed = 2  # speed in meters/sec
var current_speed

var run_multiplier = 1.1
var is_running = false

var left_arm_health = 100
var current_left_arm_health
var right_arm_health = 100
var current_right_arm_health
var head_health = 100
var current_head_health
var torso_health = 100
var current_torso_health
var left_leg_health = 100
var current_left_leg_health
var right_leg_health = 100
var current_right_leg_health

var stamina = 100
var current_stamina
var stamina_lost_while_running_persec = 15
var stamina_regen_while_standing_still = 3

var hunger = 0
var current_hunger

var thirst = 0
var current_thirst

var nutrition = 100
var current_nutrition

var pain
var current_pain = 0

var stats = {}
var skills = {}
var attributes = {}

var time_since_ready = 0.0
var delay_before_movement = 2.0  # 2 second delay
# Variable to store the last recorded y level
var last_y_level: int = 0

@export var sprite : Sprite3D
@export var collisionDetector : Area3D # Used for detecting collision with furniture

@export var interact_range : float = 10

#@export var progress_bar : NodePath
#@export var progress_bar_filling : NodePath
#@export var progress_bar_timer : NodePath

@export var foostep_player : AudioStreamPlayer
@export var foostep_stream_randomizer : AudioStreamRandomizer


# Variables for furniture pushing
var pushing_furniture = false
var furniture_body: RID
#var progress_bar_timer_max_time : float

#var is_progress_bar_well_progressing_i_guess = false


func _ready():
	initialize_health()
	initialize_condition()
	initialize_attributes()
	initialize_stats_and_skills()
	Helper.save_helper.load_player_state(self)
	Helper.signal_broker.food_item_used.connect(_on_food_item_used)
	ItemManager.craft_successful.connect(_on_craft_successful)
	# Connect signals for collisionDetector to detect furniture
	collisionDetector.body_shape_entered.connect(_on_body_entered)
	collisionDetector.body_shape_exited.connect(_on_body_exited)
	Helper.signal_broker.player_spawned.emit(self)
	initialize_y_level_check()


func initialize_health():
	current_left_arm_health = left_arm_health
	current_right_arm_health = right_arm_health
	current_left_leg_health = left_leg_health
	current_right_leg_health = right_leg_health
	current_head_health = head_health
	current_torso_health = torso_health


func initialize_condition():
	current_stamina = stamina
	current_hunger = hunger
	current_thirst = thirst
	current_nutrition = nutrition
	current_pain = pain


# Initializes the playerattributes based on the DPlayerAttribute
# The PlayerAttribute manages the actual control of the attribute while
# DPlayerAttribute only provides the data
func initialize_attributes():
	var playerattributes: Dictionary = Gamedata.playerattributes.get_playerattributes()
	for attribute: DPlayerAttribute in playerattributes.values():
		attributes[attribute.id] = PlayerAttribute.new(attribute, self)


# Initialize skills with level and XP
func initialize_stats_and_skills():
	# Initialize all stats with a value of 5
	for stat in Gamedata.stats.get_stats().values():
		stats[stat.id] = 5
	Helper.signal_broker.player_stat_changed.emit(self)
	
	# Initialize all skills with a value of level 1 and 0 XP
	for skill in Gamedata.skills.get_skills().values():
		skills[skill.id] = {"level": 1, "xp": 0}
	Helper.signal_broker.player_skill_changed.emit(self)


func _process(_delta):
	# Get the 2D screen position of the player
	var camera = get_tree().get_first_node_in_group("Camera")
	var player_screen_pos = camera.unproject_position(global_position)

	# Get the mouse position in 2D screen space
	var mouse_pos_2d = get_viewport().get_mouse_position()

	# Calculate the direction vector from the player to the mouse position
	var dir = (mouse_pos_2d - player_screen_pos).normalized()

	# Calculate the angle between the player and the mouse position
	# Since the sprite is rotating in the opposite direction, change the sign of the angle
	var angle = atan2(-dir.y, -dir.x)  # This negates both components of the direction vector

	sprite.rotation.y = -angle  # Inverts the angle for rotation
	$CollisionShape3D.rotation.y = -angle  # Inverts the angle for rotation


#	if is_progress_bar_well_progressing_i_guess:
#		get_node(progress_bar_filling).scale.x = lerp(1, 0, get_node(progress_bar_timer).time_left / progress_bar_timer_max_time)



func _physics_process(delta):
	time_since_ready += delta
	if time_since_ready < delay_before_movement:
		# Skip movement updates during the delay period to prevent 
		# the player from falling into the ground while the ground is spawning.
		return

	# Added an arbitrary multiplier because without it, the player will fall slowly
	var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	velocity.y -= gravity * 12 * delta
	move_and_slide()

	if is_alive:
		var input_dir = Input.get_vector("left", "right", "up", "down")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

		# Athletics skill level
		var athletics_level = get_skill_level("athletics")

		# Calculate run multiplier based on athletics skill level
		run_multiplier = 1.1 + (athletics_level / 100.0) * (2.0 - 1.1)

		# Calculate stamina lost while running based on athletics skill level
		stamina_lost_while_running_persec = 15 - (athletics_level / 100.0) * (15 - 5)

		# Calculate stamina regeneration while standing still based on athletics skill level
		stamina_regen_while_standing_still = 3 + (athletics_level / 100.0) * (8 - 3)

		# Check if the player is pushing furniture
		if pushing_furniture and furniture_body:
			# Apply resistance based on the mass of the furniture collider
			var mass = PhysicsServer3D.body_get_param(furniture_body, PhysicsServer3D.BODY_PARAM_MASS)
			var resistance = 1.0 / mass
			velocity = direction * speed * resistance
		else:
			if not is_running or current_stamina <= 0:
				velocity = direction * speed
			elif is_running and current_stamina > 0:
				velocity = direction * speed * run_multiplier

				if velocity.length() > 0:
					current_stamina -= delta * stamina_lost_while_running_persec
					# Add XP for running
					add_skill_xp("athletics", 0.01)

		if velocity.length() < 0.1:
			current_stamina += delta * stamina_regen_while_standing_still
			if current_stamina > stamina:
				current_stamina = stamina

		update_stamina_HUD.emit(current_stamina)

		move_and_slide()


# When a body enters the CollisionDetector area
# This will be a FurniturePhysicsSrv since it's only detecting layer 4
# Layer 4 is the moveable furniture layer
# Since FurniturePhysicsSrv is not in the scene tree, we will have an RID but no body
func _on_body_entered(body_rid: RID, body: Node3D, _body_shape_index: int, _local_shape_index: int):
	if body_rid and not body:
		pushing_furniture = true
		furniture_body = body_rid


func _on_body_exited(body_rid: RID, body: Node3D, _body_shape_index: int, _local_shape_index: int):
	if body_rid and not body:
		pushing_furniture = false


func _input(event):
	if event.is_action_pressed("run"):
		is_running = true
	if event.is_action_released("run"):
		is_running = false
		
	#checking if we can interact with the object
	if event.is_action_pressed("interact"):
		var layer = pow(2, 1-1) + pow(2, 2-1) + pow(2, 3-1)
		var mouse_pos : Vector2 = get_viewport().get_mouse_position()
		var raycast: Dictionary = Helper.raycast_from_mouse(mouse_pos, layer)
		if not raycast.has("position"):
			return
		var world_mouse_position = raycast.position
		var result = Helper.raycast(global_position, global_position + (Vector3(world_mouse_position.x - global_position.x, 0, world_mouse_position.z - global_position.z)).normalized() * interact_range, layer, [self])

		print("Interact button pressed")
		if result:
			print("Found object with collider")
			Helper.signal_broker.player_interacted.emit(result.position, result.rid)
			#var myOwner = result.collider.get_owner()
			#if myOwner:
			#if result.collider.has_method("interact"):
				#print("collider has method")
				#result.collider.interact()
				

func _get_hit(damage: float):
	var limb_number = rng.randi_range(0,5)
	
	match limb_number:
		0:
			current_head_health -= damage
			if current_head_health <= 0:
				current_head_health = 0
				check_if_alive()
		1:
			if current_right_arm_health <= 0:
				transfer_damage_to_torso(damage)
			else: 
				current_right_arm_health -= damage
				if current_right_arm_health < 0:
					current_right_arm_health = 0
		2:
			if current_left_arm_health <= 0:
				transfer_damage_to_torso(damage)
			else: 
				current_left_arm_health -= damage
				if current_left_arm_health < 0:
					current_left_arm_health = 0
		3:
			current_torso_health -= damage
			if current_torso_health <= 0:
				current_torso_health = 0
				check_if_alive()
		4:
			if current_right_leg_health <= 0:
				transfer_damage_to_torso(damage)
			else: 
				current_right_leg_health -= damage
				if current_right_leg_health < 0:
					current_right_leg_health = 0
		5:
			if current_left_leg_health <= 0:
				transfer_damage_to_torso(damage)
			else: 
				current_left_leg_health -= damage
				if current_left_leg_health < 0:
					current_left_leg_health = 0
			
	update_doll.emit(current_head_health, current_right_arm_health, current_left_arm_health, current_torso_health, current_right_leg_health, current_left_leg_health)

func check_if_alive():
	if current_torso_health <= 0:
		current_torso_health = 0
		die()
	elif current_head_health <= 0:
		current_head_health = 0
		die()

#
#func check_if_visible(target_position: Vector3):
	#
	#var space_state = get_world_3d().direct_space_state
	## TO-DO Change playerCol to group of players
	#var query = PhysicsRayQueryParameters3D.create(global_position, target_position, pow(2, 1-1) + pow(2, 3-1) + pow(2, 2-1),[self])
	#var result = space_state.intersect_ray(query)
	#
	#if result:
		#print("I see something!")
		#return false
	#else:
		#print("I see nothing!")
		#return true

func die():
	if is_alive:
		print("Player died")
		is_alive = false
		$"../../../HUD".get_node("GameOver").show()

func transfer_damage_to_torso(damage: float):
	current_torso_health -= damage
	check_if_alive()


func play_footstep_audio():
	foostep_player.stream = foostep_stream_randomizer
	foostep_player.play()


# The player has selected one or more items in the inventory and selected
# 'use' from the context menu.
func _on_food_item_used(usedItem: InventoryItem) -> void:
	var food = DItem.Food.new(usedItem.get_property("Food"))
	var was_used: bool = false
	if food.health:
		var spent_health = heal_player(food.health)
		if not spent_health == food.health:
			was_used = true

	for attribute in food.attributes:
		attributes[attribute.id].modify_current_amount(attribute.amount)
		was_used = true

	if was_used:
		ItemManager.remove_inventory_item(usedItem)


# Heal the player by the specified amount. We prioritize the head and torso for healing
# After that, we prioritize the most damaged part
# It returns the remaining amount that wasn't spent on healing
# You can use this to see if the healing item is depleted or used at all
func heal_player(amount: int) -> int:
	# Create a dictionary with part names and their current/max health
	var body_parts = {
		"head": {"current": current_head_health, "max": head_health},
		"torso": {"current": current_torso_health, "max": torso_health},
		"left_arm": {"current": current_left_arm_health, "max": left_arm_health},
		"right_arm": {"current": current_right_arm_health, "max": right_arm_health},
		"left_leg": {"current": current_left_leg_health, "max": left_leg_health},
		"right_leg": {"current": current_right_leg_health, "max": right_leg_health}
	}

	# Gather keys, filter, and sort. We prioritize the head and torso
	var other_parts = body_parts.keys().filter(
		func(k): return k != "head" and k != "torso"
	)
	other_parts.sort_custom(
		func(a, b): return body_parts[a]["current"] > body_parts[b]["current"]
	)

	# Create a priority list with head and torso first, then the sorted other parts
	var priority_parts = ["head", "torso"] + other_parts

	# Distribute healing points
	for part in priority_parts:
		if amount <= 0:
			break
		var heal = min(amount, body_parts[part]["max"] - body_parts[part]["current"])
		body_parts[part]["current"] += heal
		amount -= heal

	# Update health variables
	current_head_health = body_parts["head"]["current"]
	current_torso_health = body_parts["torso"]["current"]
	current_left_arm_health = body_parts["left_arm"]["current"]
	current_right_arm_health = body_parts["right_arm"]["current"]
	current_left_leg_health = body_parts["left_leg"]["current"]
	current_right_leg_health = body_parts["right_leg"]["current"]

	# Emit signals to update the UI or other systems
	update_doll.emit(
		current_head_health, current_right_arm_health, current_left_arm_health,
		current_torso_health, current_right_leg_health, current_left_leg_health
	)
	return amount


# Method to get the current level of a skill
func get_skill_level(skill_id: String) -> int:
	if skills.has(skill_id):
		return skills[skill_id]["level"]
	else:
		push_error("Skill ID not found: %s" % skill_id)
		return 0  # Return 0 or an appropriate default value if the skill is not found


# Method to get the current amount of XP for a skill
func get_skill_xp(skill_id: String) -> int:
	if skills.has(skill_id):
		return skills[skill_id]["xp"]
	else:
		push_error("Skill ID not found: %s" % skill_id)
		return 0  # Return 0 or an appropriate default value if the skill is not found


# Method to set the level of a skill
func set_skill_level(skill_id: String, level: int) -> void:
	if skills.has(skill_id):
		skills[skill_id]["level"] = level
		Helper.signal_broker.player_skill_changed.emit(self)
	else:
		push_error("Skill ID not found: %s" % skill_id)


# Method to set the amount of XP for a skill
func set_skill_xp(skill_id: String, xp: int) -> void:
	if skills.has(skill_id):
		skills[skill_id]["xp"] = xp
		Helper.signal_broker.player_skill_changed.emit(self)
	else:
		push_error("Skill ID not found: %s" % skill_id)


# Method to add an amount of levels to a skill
func add_skill_level(skill_id: String, levels: int) -> void:
	if skills.has(skill_id):
		skills[skill_id]["level"] += levels
		Helper.signal_broker.player_skill_changed.emit(self)
	else:
		push_error("Skill ID not found: %s" % skill_id)


# Method to add an amount of XP to a skill
# This also increases the skill level when the XP reaches 100
func add_skill_xp(skill_id: String, xp: float) -> void:
	if skills.has(skill_id):
		var current_xp = skills[skill_id]["xp"]
		var current_level = skills[skill_id]["level"]
		current_xp += xp
		
		# Check if XP exceeds 100 and handle level up
		while current_xp >= 100:
			current_xp -= 100
			current_level += 1
		
		skills[skill_id]["xp"] = current_xp
		skills[skill_id]["level"] = current_level
		Helper.signal_broker.player_skill_changed.emit(self)
	else:
		push_error("Skill ID not found: %s" % skill_id)


# The player has succesfully crafted an item. Get the skill id and xp from
# the recipe and add it to the player's skill xp
func _on_craft_successful(_item: DItem, recipe: DItem.CraftRecipe):
	if recipe.skill_progression:
		add_skill_xp(recipe.skill_progression.id, recipe.skill_progression.xp)


# Function to initialize the timer for checking Y level changes
func initialize_y_level_check():
	var y_check_timer = Timer.new()
	y_check_timer.wait_time = 0.5
	y_check_timer.autostart = true
	y_check_timer.one_shot = false
	y_check_timer.timeout.connect(_emit_y_level)
	add_child(y_check_timer)

# Function to emit the current Y level
func _emit_y_level():
	var current_y_level = global_position.y
	Helper.signal_broker.player_y_level_updated.emit(current_y_level)
