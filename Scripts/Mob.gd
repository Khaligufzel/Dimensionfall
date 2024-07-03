class_name Mob
extends CharacterBody3D

var original_scale
var mobPosition: Vector3 # The position it will move to when it is created
var mobRotation: int # The rotation it will rotate to when the it is created
var mobJSON: Dictionary # The json that defines this mob
var meshInstance: MeshInstance3D # This mob's mesh instance
var nav_agent: NavigationAgent3D # Used for pathfinding
var last_position: Vector3 = Vector3()
var last_rotation: int
var last_chunk: Vector2
var current_chunk: Vector2


var melee_damage: float = 20.0
var melee_range: float = 1.5
var health: float = 100.0
var current_health: float
var moveSpeed: float = 1.0
var current_move_speed: float
var idle_move_speed: float = 0.5
var current_idle_move_speed: float
var sightRange: float = 200.0
var senseRange: float = 50.0
var hearingRange: float = 1000.0

var is_blinking: bool = false # flag to prevent multiple blink actions
var original_material: StandardMaterial3D # To return to normal after blinking


func _ready():
	current_health = health
	current_move_speed = moveSpeed
	current_idle_move_speed = idle_move_speed
	position = mobPosition
	last_position = mobPosition
	meshInstance.position.y = -0.2
	current_chunk = get_chunk_from_position(global_transform.origin)
	update_navigation_agent_map(current_chunk)


func _physics_process(_delta):
	if global_transform.origin != last_position:
		last_position = global_transform.origin
		# Check if the mob has crossed into a new chunk
		current_chunk = get_chunk_from_position(global_transform.origin)
		if current_chunk != last_chunk:
			last_chunk = current_chunk
			# We have crossed over to another chunk so we use that navigationmap now.
			update_navigation_agent_map(current_chunk)

	var current_rotation = int(rotation_degrees.y)
	if current_rotation != last_rotation:
		last_rotation = current_rotation


func update_navigation_agent_map(chunk_position: Vector2):
	# Assume 'chunk_navigation_maps' is a global dictionary mapping chunk positions to navigation map IDs
	var navigation_map_id = Helper.chunk_navigation_maps.get(chunk_position)
	if navigation_map_id:
		nav_agent.set_navigation_map(navigation_map_id)


func get_hit(damage):
	current_health -= damage
	if current_health <= 0:
		_die()
	else:
		if not is_blinking:
			start_blinking()
	
func _die():
	Helper.signal_broker.mob_killed.emit(self)
	add_corpse.call_deferred(global_position)
	queue_free()


func add_corpse(pos: Vector3):
	var newItem: ContainerItem = ContainerItem.new()
	
	# Retrieve mob data from Gamedata
	var mob_data = Gamedata.get_data_by_id(Gamedata.data.mobs, mobJSON.id)
	if mob_data.is_empty():
		print_debug("No mob data found for ID: " + str(mobJSON.id))
		return

	# Check if the mob data has a 'loot_group' property
	if "loot_group" in mob_data:
		# Set the itemgroup property of the new ContainerItem
		newItem.itemgroup = mob_data["loot_group"]
	else:
		print_debug("No loot_group found for mob ID: " + str(mobJSON.id))
	
	newItem.add_to_group("mapitems")
	var itemdata: Dictionary = {}
	itemdata["global_position_x"] = pos.x
	itemdata["global_position_y"] = pos.y
	itemdata["global_position_z"] = pos.z
	newItem.construct_self(itemdata)
	# Finally add the new item with possibly set loot group to the tree
	get_tree().get_root().add_child.call_deferred(newItem)


# Sets the sprite to the mob
# TODO: In order to optimize this, instead of calling original_mesh.duplicate()
# We should keep track of every unique mesh (one for each type of mob)
# THen we check if there has already been a mesh created for a mob with this
# id and assign that mesh. Right now every mob has it's own unique mesh
func set_sprite(newSprite: Resource):
	var original_mesh = meshInstance.mesh
	var new_mesh = original_mesh.duplicate()  # Clone the mesh
	var material := StandardMaterial3D.new()
	material.albedo_texture = newSprite
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	new_mesh.surface_set_material(0, material)
	meshInstance.mesh = new_mesh  # Set the new mesh to MeshInstance3D
	# Save the original material
	original_material = material.duplicate()


# Applies it's own data from the dictionary it received
# If it is created as a new mob, it will spawn with the default stats
# If it is created from a saved game, it might have lower health for example
func apply_stats_from_json() -> void:
	var json_data = Gamedata.get_data_by_id(Gamedata.data.mobs, mobJSON.id)
	set_sprite(Gamedata.get_sprite_by_id(Gamedata.data.mobs,json_data.id))
	if json_data.has("melee_damage"):
		melee_damage = float(json_data["melee_damage"])
	if json_data.has("melee_range"):
		melee_range = float(json_data["melee_range"])
	if json_data.has("health"):
		health = float(json_data["health"])
		if json_data.has("current_health"):
			current_health =  float(json_data["current_health"])
		else: # Reset current health to max health
			current_health = health
	if json_data.has("move_speed"):
		moveSpeed = float(json_data["move_speed"])
		if json_data.has("current_move_speed"):
			current_move_speed =  float(json_data["current_move_speed"])
		else: # Reset current moveSpeed to max moveSpeed
			current_move_speed = moveSpeed
	if json_data.has("idle_move_speed"):
		idle_move_speed = float(json_data["idle_move_speed"])
		if json_data.has("current_idle_move_speed"):
			current_idle_move_speed =  float(json_data["current_idle_move_speed"])
		else: # Reset current idle_move_speed to max idle_move_speed
			current_idle_move_speed = idle_move_speed
	if json_data.has("sight_range"):
		sightRange = float(json_data["sight_range"])
	if json_data.has("sense_range"):
		senseRange = float(json_data["sense_range"])
	if json_data.has("hearing_range"):
		hearingRange = float(json_data["hearing_range"])


# Previously the Mob node was configured in the node editor
# This function tries to re-create that node structure and properties
func construct_self(mobpos: Vector3, newMobJSON: Dictionary):
	mobJSON = newMobJSON
	mobPosition = mobpos
	# Set the properties of the mob node itself
	wall_min_slide_angle = 0
	floor_constant_speed = true
	
	# Set to layer 2 (enemy layer)
	collision_layer = 1 << 1  # Layer 2 is 1 << 1 (bit shift by 1)

	# Set mask for layers 1 (player layer), 2 (enemy layer), 3 (static obstacles layer), and 5 (friendly projectiles layer)
	collision_mask = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 4)
	# Explanation:
	# - 1 << 0: Layer 1 (player layer)
	# - 1 << 1: Layer 2 (enemy layer)
	# - 1 << 2: Layer 3 (static obstacles layer)
	# - 1 << 4: Layer 5 (friendly projectiles layer)
	
	add_to_group("mobs")
	if newMobJSON.has("rotation"):
		mobRotation = newMobJSON.rotation

	# Create and configure NavigationAgent3D
	nav_agent = NavigationAgent3D.new()
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	nav_agent.path_max_distance = 0.5
	nav_agent.avoidance_enabled = true
	nav_agent.debug_enabled = true
	add_child.call_deferred(nav_agent)
	
	# Create and configure StateMachine
	var state_machine = StateMachine.new()
	add_child.call_deferred(state_machine)
	
	# Create and configure MobAttack
	var mob_attack = MobAttack.new()
	mob_attack.name = "MobAttack"
	state_machine.add_child.call_deferred(mob_attack)
	
	# Create and configure AttackCooldown Timer
	var attack_cooldown = Timer.new()
	mob_attack.attack_timer = attack_cooldown
	mob_attack.mob = self
	mob_attack.add_child.call_deferred(attack_cooldown)
	
	# Create and configure MobIdle
	var mob_idle = MobIdle.new()
	mob_idle.name = "MobIdle"
	mob_idle.nav_agent = nav_agent
	mob_idle.mob = self
	state_machine.initial_state = mob_idle
	state_machine.add_child.call_deferred(mob_idle)
	
	# Create and configure MovingCooldown Timer
	var moving_cooldown = Timer.new()
	moving_cooldown.wait_time = 4
	mob_idle.moving_timer = moving_cooldown
	mob_idle.add_child.call_deferred(moving_cooldown)
	
	# Create and configure MobFollow
	var mob_follow = MobFollow.new()
	mob_follow.name = "MobFollow"
	mob_follow.nav_agent = nav_agent
	mob_follow.mob = self
	state_machine.add_child.call_deferred(mob_follow)
	
	# Create and configure Follow Timer
	var follow_timer = Timer.new()
	follow_timer.wait_time = 0.2
	follow_timer.autostart = true
	mob_follow.pathfinding_timer = follow_timer
	mob_follow.add_child.call_deferred(follow_timer)
	
	# Create and configure Detection
	var detection = Detection.new()
	detection.state_nodes = [mob_attack,mob_idle,mob_follow]
	detection.mob = self
	add_child.call_deferred(detection)
	
	# Create and configure CollisionShape3D
	# Update the collision shape
	var new_shape = BoxShape3D.new()
	new_shape.size = Vector3(0.35,0.35,0.35)
	var collision_shape_3d = CollisionShape3D.new()
	collision_shape_3d.shape = new_shape
	mob_follow.mobCol = collision_shape_3d
	add_child.call_deferred(collision_shape_3d)

	# Create and configure MeshInstance3D
	meshInstance = MeshInstance3D.new()
	# Set the layers to layer 5
	meshInstance.layers = 1 << 4 # Layer numbers start at 0, so layer 5 is 1 shifted 4 times to the left
	#meshInstance.skeleton = self
	meshInstance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	meshInstance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

	# Give the mesh instance a quadmesh
	var quadmesh: QuadMesh = QuadMesh.new()
	quadmesh.size = Vector2(0.5,0.5)
	quadmesh.orientation = PlaneMesh.FACE_Y
	quadmesh.lightmap_size_hint = Vector2(7,7)
	meshInstance.mesh = quadmesh
	add_child.call_deferred(meshInstance)
	
	apply_stats_from_json()


# Returns which chunk the mob is in right now. for example 0,0 or 0,32 or 96,32
func get_chunk_from_position(chunkposition: Vector3) -> Vector2:
	var chunk_x = floor(chunkposition.x / 32) * 32
	var chunk_z = floor(chunkposition.z / 32) * 32
	return Vector2(chunk_x, chunk_z)


# The mob will blink once to indicate that it's hit
# We enable emission and tween it to a white color so it's entirely white
# Then we tween back to the normal emission color
func start_blinking():
	is_blinking = true
	var blink_material = original_material.duplicate()
	blink_material.set_feature(BaseMaterial3D.FEATURE_EMISSION, true)
	var surfacemesh = meshInstance.mesh
	var surfacematerial = surfacemesh.surface_get_material(0)
	surfacematerial.set_feature(BaseMaterial3D.FEATURE_EMISSION, true)

	var tween = create_tween()
	tween.tween_property(surfacematerial, "emission", Color(1, 1, 1), 0.125).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(surfacematerial, "emission", original_material.emission, 0.125).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT).set_delay(0.125)

	tween.finished.connect(_on_tween_finished)


# The mob is done blinkinig so we reset the relevant variables
func _on_tween_finished():
	var surfacemesh = meshInstance.mesh
	var surfacematerial = surfacemesh.surface_get_material(0)
	surfacematerial.set_feature(BaseMaterial3D.FEATURE_EMISSION, false)
	is_blinking = false


func get_data() -> Dictionary:
	var newMobData = {
				"id": mobJSON.id,
				"global_position_x": last_position.x,
				"global_position_y": last_position.y,
				"global_position_z": last_position.z,
				"rotation": last_rotation,
				"melee_damage": melee_damage,
				"melee_range": melee_range,
				"health": health,
				"current_health": current_health,
				"move_speed": moveSpeed,
				"current_move_speed": current_move_speed,
				"idle_move_speed": idle_move_speed,
				"current_idle_move_speed": current_idle_move_speed,
				"sight_range": sightRange,
				"sense_range": senseRange,
				"hearing_range": hearingRange
			}
	return newMobData
