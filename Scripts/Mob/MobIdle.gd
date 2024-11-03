extends State
class_name MobIdle

var idle_speed

var nav_agent: NavigationAgent3D # Used for pathfinding
var mob: CharacterBody3D # The mob we provide idle behavour for
var move_distance: float = 50.0
var moving_timer: Timer

@onready var target_location: Vector3

var is_looking_to_move = false

var rng = RandomNumberGenerator.new()

func _ready():
	name = "MobIdle"
	nav_agent = mob.nav_agent
	# Create and configure MovingCooldown Timer
	var moving_cooldown = Timer.new()
	moving_cooldown.wait_time = 4
	moving_timer = moving_cooldown
	add_child(moving_cooldown)
	moving_timer.timeout.connect(_on_moving_cooldown_timeout)
	moving_timer.start()


func Enter():
	print("Mob idle")
	idle_speed = mob.idle_move_speed


func Exit():
	moving_timer.stop()


func Physics_Update(_delta: float):
	if mob.terminated:
		Transistioned.emit(self, "mobterminate")
	
	if is_looking_to_move:
		handle_mob_movement()

func handle_mob_movement():
	var chunk_position = mob.get_chunk_from_position(target_location)
	
	# Check if the target location has a navigation map
	if Helper.chunk_navigation_maps.has(chunk_position):
		move_mob_to_target() # Continue moving
	else:
		# If there's no navigation map for the target location, stop moving
		is_looking_to_move = false

func move_mob_to_target():
	var dir = mob.to_local(nav_agent.get_next_path_position()).normalized()
	mob.velocity = dir * mob.current_idle_move_speed
	mob.move_and_slide()
	
	if Vector3(mob.global_position).distance_to(target_location) <= 0.5:
		is_looking_to_move = false


func _on_detection_player_spotted(_player):
	Transistioned.emit(self, "mobfollow")


func makepath() -> void:
	nav_agent.target_position = target_location
	#print(nav_agent.target_position)


func _on_moving_cooldown_timeout():
	var space_state = get_world_3d().direct_space_state
	var random_dir = Vector3(rng.randf_range(-1,1), mob.global_position.y, rng.randf_range(-1, 1))
	var query = PhysicsRayQueryParameters3D.create(mob.global_position, mob.global_position + (random_dir * move_distance), int(pow(2, 1-1) + pow(2, 3-1)),[self])

	var result = space_state.intersect_ray(query)
	if !result:
		is_looking_to_move = true
		target_location = mob.global_position + (random_dir * move_distance)
		makepath()
