extends State
class_name MobFollow



@export var nav_agent: NavigationAgent3D
@export var mob: CharacterBody3D
@export var mobCol: NodePath
@export var stats: NodePath
@export var pathfinding_timer: Timer

var targeted_player

@onready var target_location = mob.position


func Enter():
	print("Following the player")
	pathfinding_timer.start()
	makepath()

func Exit():
	pathfinding_timer.stop()

func Physics_Update(_delta: float):
	var dir = mob.to_local(nav_agent.get_next_path_position()).normalized()
	mob.velocity = dir * get_node(stats).current_move_speed
	mob.move_and_slide()

	# Rotation towards target using look_at
	if targeted_player:
		var mesh_instance = $"../../MeshInstance3D"
		var target_position = targeted_player.global_position
		target_position.y = mesh_instance.global_position.y  # Align y-axis to avoid tilting
		mesh_instance.look_at(target_position, Vector3.UP)
	
	if !targeted_player:
		return
	var space_state = get_world_3d().direct_space_state
	# TO-DO Change playerCol to group of players
	var query = PhysicsRayQueryParameters3D.create(get_node(mobCol).global_position, targeted_player.global_position, int(pow(2, 1-1) + pow(2, 3-1)),[self])
	var result = space_state.intersect_ray(query)
	
	if result:
		
		if result.collider.is_in_group("Players")&& Vector3(get_node(mobCol).global_position).distance_to(targeted_player.global_position) <= get_node(stats).melee_range / 2:
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
