extends State
class_name MobIdle

var idle_speed

var nav_agent: NavigationAgent3D # Used for pathfinding
var mob: CharacterBody3D # The mob we provide idle behavour for
var move_distance: float = 50.0
var moving_timer: Timer

@onready var target_location

var is_looking_to_move = false

var rng = RandomNumberGenerator.new()

func _ready():
	moving_timer.timeout.connect(_on_moving_cooldown_timeout)


func Enter():
	print("Mob idle")
	idle_speed = mob.idle_move_speed
	moving_timer.start()


func Exit():
	moving_timer.stop()


func Physics_Update(_delta: float):
	if mob.terminated:
		Transistioned.emit(self, "mobterminate") 
	if is_looking_to_move:
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
