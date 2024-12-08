class_name Mob
extends CharacterBody3D

var original_scale
var mobPosition: Vector3 # The position it will move to when it is created
var mobRotation: int # The rotation it will rotate to when it is created
var mobJSON: Dictionary # The json that defines this mob
var rmob: RMob # The data that defines this mob in general
var meshInstance: MeshInstance3D # This mob's mesh instance
var nav_agent: NavigationAgent3D # Used for pathfinding
var collision_shape_3d = CollisionShape3D
var last_position: Vector3 = Vector3()
var last_rotation: int
var last_chunk: Vector2
var current_chunk: Vector2

var melee_range: float = 1.5
var health: float = 100.0
var current_health: float
var move_speed: float = 1.0
var current_move_speed: float
var idle_move_speed: float = 0.5
var current_idle_move_speed: float
var sight_range: float = 200.0
var sense_range: float = 50.0
var hearing_range: float = 1000.0
var dash: Dictionary = {} # to enable dash move. something like {"speed_multiplier":2,"cooldown":5,"duration":0.5}

var is_blinking: bool = false # flag to prevent multiple blink actions
var original_material: StandardMaterial3D # To return to normal after blinking

# State machine variables:
var state_machine: StateMachine
var terminated: bool = false


# Previously the Mob node was configured in the node editor
# This function tries to re-create that node structure and properties
func _init(mobpos: Vector3, newMobJSON: Dictionary):
	mobJSON = newMobJSON
	# Retrieve mob data from Runtimedata
	rmob = Runtimedata.mobs.by_id(mobJSON.id)
	mobPosition = mobpos
	setup_mob_properties()
	setup_collision_layers_and_masks()
	create_navigation_agent()
	create_state_machine()
	create_detection()
	create_collision_shape()
	create_mesh_instance()
	apply_stats_from_dmob()
	Helper.signal_broker.game_terminated.connect(terminate)

# Set basic properties of the mob
func setup_mob_properties():
	wall_min_slide_angle = 0
	floor_constant_speed = true
	add_to_group("mobs")
	if mobJSON.has("rotation"):
		mobRotation = mobJSON.rotation

# Set collision layers and masks
func setup_collision_layers_and_masks():
	collision_layer = 1 << 1  # Layer 2 is 1 << 1 (bit shift by 1)
	collision_mask = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 4)
	# Explanation:
	# - 1 << 0: Layer 1 (player layer)
	# - 1 << 1: Layer 2 (enemy layer)
	# - 1 << 2: Layer 3 (static obstacles layer)
	# - 1 << 4: Layer 5 (friendly projectiles layer)


# Create and configure NavigationAgent3D
func create_navigation_agent():
	nav_agent = NavigationAgent3D.new()
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	nav_agent.path_max_distance = 0.5
	nav_agent.avoidance_enabled = true
	nav_agent.debug_enabled = false
	add_child.call_deferred(nav_agent)

# Create and configure StateMachine
func create_state_machine():
	state_machine = StateMachine.new()
	state_machine.mob = self
	add_child.call_deferred(state_machine)


# Create and configure Detection
func create_detection():
	var detection = Detection.new()
	detection.state_machine = state_machine
	detection.mob = self
	add_child.call_deferred(detection)


# Create and configure CollisionShape3D
func create_collision_shape():
	var new_shape = BoxShape3D.new()
	new_shape.size = Vector3(0.35, 0.35, 0.35)
	collision_shape_3d = CollisionShape3D.new()
	collision_shape_3d.shape = new_shape
	add_child.call_deferred(collision_shape_3d)


# Create and configure MeshInstance3D
func create_mesh_instance():
	meshInstance = MeshInstance3D.new()
	# Set the layers to layer 5
	meshInstance.layers = 1 << 4 # Layer numbers start at 0, so layer 5 is 1 shifted 4 times to the left
	meshInstance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	meshInstance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

	# Give the mesh instance a quadmesh
	var quadmesh: QuadMesh = QuadMesh.new()
	quadmesh.size = Vector2(0.5, 0.5)
	quadmesh.orientation = PlaneMesh.FACE_Y
	quadmesh.lightmap_size_hint = Vector2(7, 7)
	meshInstance.mesh = quadmesh
	add_child.call_deferred(meshInstance)

func _ready():
	current_health = health
	current_move_speed = move_speed
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
			# We have crossed over to another chunk so we use that navigationmap now.
			update_navigation_agent_map(current_chunk)
			last_chunk = current_chunk

	var current_rotation = int(rotation_degrees.y)
	if current_rotation != last_rotation:
		last_rotation = current_rotation


func update_navigation_agent_map(chunk_position: Vector2):
	# Assume 'chunk_navigation_maps' is a global dictionary mapping chunk positions to navigation map IDs
	var navigation_map_id = Helper.chunk_navigation_maps.get(chunk_position)
	if navigation_map_id:
		nav_agent.set_navigation_map(navigation_map_id)
	else:
		print_debug("Tried to set navigation_map_id at "+str(chunk_position)+", but it was null. last_position = " + str(last_position) + ", last_chunk = " + str(last_chunk))
		# Set the last chunk to one that doesn't exist so it will try to get a new map
		last_chunk = Vector2(0.1,0.1)

# When the mob gets hit by an attack
# attack: a dictionary with the "damage" and "hit_chance" properties
func get_hit(attack: Dictionary):
	# Extract damage and hit_chance from the dictionary
	var damage = attack.damage
	var hit_chance = attack.hit_chance

	# Calculate actual hit chance considering mob bonus
	# We may increase or decrease the hit chance based on mob or weapon stats
	var actual_hit_chance = hit_chance + 0.0 # Boost hit chance by 0%

	# Determine if the attack hits
	if randf() <= actual_hit_chance:
		# Attack hits
		current_health -= damage
		if current_health <= 0:
			_die()
		else:
			if not is_blinking:
				start_blinking()
	else:
		# Attack misses, create a visual indicator
		show_miss_indicator()

# Function to show a miss indicator
func show_miss_indicator():
	var miss_label = Label3D.new()
	miss_label.text = "Miss!"
	miss_label.modulate = Color(1, 0, 0)
	miss_label.font_size = 64
	get_tree().get_root().add_child(miss_label)
	miss_label.position = position
	miss_label.position.y += 2
	miss_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	miss_label.render_priority = 10

	# Animate the miss indicator to disappear quickly
	var tween = create_tween()
	tween.tween_property(miss_label, "modulate:a", 0, 0.5).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func():
		miss_label.queue_free()  # Properly free the miss_label node
	)

func _die():
	Helper.signal_broker.mob_killed.emit(self)
	add_corpse.call_deferred(global_position)
	queue_free()

func add_corpse(pos: Vector3):
	var itemdata: Dictionary = {}
	itemdata["global_position_x"] = pos.x
	itemdata["global_position_y"] = pos.y
	itemdata["global_position_z"] = pos.z

	# Check if the mob data has a 'loot_group' property
	if rmob.loot_group and not rmob.loot_group == "":
		# Set the itemgroup property of the new ContainerItem
		itemdata["itemgroups"] = [rmob.loot_group]
	else:
		print_debug("No loot_group found for mob ID: " + str(mobJSON.id))

	var newItem: ContainerItem = ContainerItem.new(itemdata)
	newItem.add_to_group("mapitems")
	# Finally add the new item with possibly set loot group to the tree
	get_tree().get_root().add_child.call_deferred(newItem)

# Sets the sprite to the mob
# TODO: In order to optimize this, instead of calling original_mesh.duplicate()
# We should keep track of every unique mesh (one for each type of mob)
# Then we check if there has already been a mesh created for a mob with this
# id and assign that mesh. Right now every mob has its own unique mesh
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

# Applies its own data from the DMob instance it received
# If it is created as a new mob, it will spawn with the default stats
# If it is created from a saved game, it might have lower health for example
func apply_stats_from_dmob() -> void:
	set_sprite(rmob.sprite)
	melee_range = rmob.melee_range
	health = rmob.health
	current_health = rmob.health
	move_speed = rmob.move_speed
	current_move_speed = rmob.move_speed
	idle_move_speed = rmob.idle_move_speed
	current_idle_move_speed = rmob.idle_move_speed
	sight_range = rmob.sight_range
	sense_range = rmob.sense_range
	hearing_range = rmob.hearing_range
	dash = rmob.special_moves.get("dash",{})


# Returns which chunk the mob is in right now. for example 0,0 or 0,32 or 96,32
func get_chunk_from_position(chunkposition: Vector3) -> Vector2:
	var x_position = chunkposition.x
	var z_position = chunkposition.z
	
	var chunk_x_index = floor(x_position / 32.0)
	var chunk_z_index = floor(z_position / 32.0)
	
	var chunk_x = chunk_x_index * 32
	var chunk_z = chunk_z_index * 32
	
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

# The mob is done blinking so we reset the relevant variables
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
		"melee_range": melee_range,
		"health": health,
		"current_health": current_health,
		"move_speed": move_speed,
		"current_move_speed": current_move_speed,
		"idle_move_speed": idle_move_speed,
		"current_idle_move_speed": current_idle_move_speed,
		"sight_range": sight_range,
		"sense_range": sense_range,
		"hearing_range": hearing_range
	}
	return newMobData


# Terminate the mob, disabling any movement and navigation
# This allows the mob to transition to the MobTerminate state
func terminate():
	terminated = true
