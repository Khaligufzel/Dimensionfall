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

var time_since_ready = 0.0
var delay_before_movement = 2.0  # 2 second delay

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
var furniture_body: RigidBody3D = null
#var progress_bar_timer_max_time : float

#var is_progress_bar_well_progressing_i_guess = false

func _ready():
	initialize_health()
	initialize_condition()
	initialize_stats_and_skills()
	Helper.save_helper.load_player_state(self)
	Helper.signal_broker.health_item_used.connect(_on_health_item_used)
	ItemManager.craft_successful.connect(_on_craft_successful)
	# Connect signals for collisionDetector to detect furniture
	collisionDetector.body_entered.connect(_on_body_entered)
	collisionDetector.body_exited.connect(_on_body_exited)
	Helper.signal_broker.player_spawned.emit(self)


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


# Initialize skills with level and XP
func initialize_stats_and_skills():
	# Initialize all stats with a value of 5
	for stat in Gamedata.data.stats.data:
		stats[stat["id"]] = 5
	Helper.signal_broker.player_stat_changed.emit(self)
	
	# Initialize all skills with a value of level 1 and 0 XP
	for skill in Gamedata.data.skills.data:
		skills[skill["id"]] = {"level": 1, "xp": 0}
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
			# Apply resistance based on the mass of the RigidBody3D
			var resistance = 1.0 / furniture_body.mass
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




func _on_body_entered(body):
	if body is RigidBody3D:
		pushing_furniture = true
		furniture_body = body


func _on_body_exited(body):
	if body is RigidBody3D:
		pushing_furniture = false
		furniture_body = null


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
			print("Found object")
			#var myOwner = result.collider.get_owner()
			#if myOwner:
			if result.collider.has_method("interact"):
				print("collider has method")
				result.collider.interact()
				

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
func _on_health_item_used(usedItem: InventoryItem) -> void:
	var health: int = int(ItemManager.get_nested_property(usedItem, "Food.health"))
	if health:
		var spent_health = heal_player(health)
		if not spent_health == health:
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
func _on_craft_successful(_item: Dictionary, recipe: Dictionary):
	var skill_id = Helper.json_helper.get_nested_data(recipe, "skill_progression.id")
	var xp = Helper.json_helper.get_nested_data(recipe, "skill_progression.xp")
	if skill_id and xp:
		add_skill_xp(skill_id, xp)
