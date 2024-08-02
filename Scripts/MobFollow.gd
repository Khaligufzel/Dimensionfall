extends State
class_name MobFollow



var nav_agent: NavigationAgent3D # Used for pathfinding
var mob: CharacterBody3D # The mob that we are enabling the follow behaviour for
var mobCol: CollisionShape3D # The collision shape of the mob
var pathfinding_timer: Timer

var targeted_player

@onready var target_location = mob.position

func _ready():
	#nav_agent.set_navigation_map(Helper.navigationmap)
	pathfinding_timer.timeout.connect(_on_timer_timeout)

func Enter():
	print("Following the player")
	pathfinding_timer.start()
	makepath()

func Exit():
	pathfinding_timer.stop()

func Physics_Update(_delta: float):
	if mob.terminated:
		Transistioned.emit(self, "mobterminate") 
	
	if nav_agent.get_navigation_map() == null:
		var current_chunk = mob.get_chunk_from_position(mob.global_transform.origin)
		mob.update_navigation_agent_map(current_chunk)
		return
	var next_pos: Vector3 = nav_agent.get_next_path_position()
	var dir = mob.to_local(next_pos).normalized()
	mob.velocity = dir * mob.current_move_speed
	mob.move_and_slide()

	# Rotation towards target using look_at
	if targeted_player:
		var target_position = targeted_player.global_position
		target_position.y = mob.meshInstance.global_position.y  # Align y-axis to avoid tilting
		mob.meshInstance.look_at(target_position, Vector3.UP)
	
	if !targeted_player:
		return
	var space_state = get_world_3d().direct_space_state
	# TODO Change playerCol to group of players
	var query = PhysicsRayQueryParameters3D.create(mobCol.global_position, targeted_player.global_position, int(pow(2, 1-1) + pow(2, 3-1)),[self])
	var result = space_state.intersect_ray(query)
	
	if result:
		
		if result.collider.is_in_group("Players")&& Vector3(mobCol.global_position).distance_to(targeted_player.global_position) <= mob.melee_range / 2:
			print("changing state to mobattack...")
			Transistioned.emit(self, "mobattack")
	
	if Vector3(mob.global_position).distance_to(target_location) <= 0.5:
		Transistioned.emit(self, "mobidle") 

	
func makepath() -> void:
	nav_agent.target_position = target_location
#	print("From follow: ", target_location)
	
func _on_timer_timeout():
	makepath()

func _on_detection_player_spotted(player):
	target_location = player.position
	targeted_player = player
