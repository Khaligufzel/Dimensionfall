extends State
class_name MobFollow



var nav_agent: NavigationAgent3D # Used for pathfinding
var mob: CharacterBody3D # The mob that we are enabling the follow behaviour for
var mobCol: CollisionShape3D # The collision shape of the mob
var pathfinding_timer: Timer

var targeted_player

@onready var target_location = mob.position

# Initializes the MobFollow state by setting up references to mob components
# (collision shape, navigation agent) and configuring the pathfinding timer.
func _ready():
	name = "MobFollow"
	mobCol = mob.collision_shape_3d
	nav_agent = mob.nav_agent
	# Create and configure Follow Timer
	var follow_timer = Timer.new()
	follow_timer.wait_time = 0.2
	follow_timer.autostart = true
	pathfinding_timer = follow_timer
	add_child.call_deferred(follow_timer)
	pathfinding_timer.timeout.connect(_on_timer_timeout)


# Called when the mob enters the follow state. Starts the pathfinding timer 
# and initiates path creation towards the target location.
func Enter():
	print("Following the player")
	pathfinding_timer.start()
	makepath()


# Called when the mob exits the follow state, stopping the pathfinding timer.
func Exit():
	pathfinding_timer.stop()



# Updates physics calculations each frame, moving the mob along the navigation path
# and adjusting its orientation to face the targeted player if one is detected.
# Performs raycasting to check for direct line-of-sight and proximity to the player,
# transitioning to an attack state if within melee range.
func Physics_Update(_delta: float):
	if mob.terminated:
		Transistioned.emit(self, "mobterminate")
		return
	
	move_toward_target()
	orient_toward_target()
	check_for_player_in_range()
	check_if_idle()


# Moves the mob towards the next position in the navigation path
func move_toward_target():
	var next_pos: Vector3 = nav_agent.get_next_path_position()
	if nav_agent.get_navigation_map() == null or next_pos == mob.global_transform.origin:
		var current_chunk = mob.get_chunk_from_position(target_location)
		mob.update_navigation_agent_map(current_chunk)
		return
	
	var dir = mob.to_local(next_pos).normalized()
	mob.velocity = dir * mob.current_move_speed
	mob.move_and_slide()


# Orients the mob to face the targeted player, aligning y-axis to prevent tilting
func orient_toward_target():
	if targeted_player:
		var target_position = targeted_player.global_position
		target_position.y = mob.meshInstance.global_position.y  # Align y-axis to avoid tilting
		mob.meshInstance.look_at(target_position, Vector3.UP)


# Performs raycasting to check if the targeted player is within sight and melee range
func check_for_player_in_range():
	if !targeted_player:
		return
	
	var space_state = get_world_3d().direct_space_state
	# TODO Change playerCol to group of players
	var query = PhysicsRayQueryParameters3D.create(
		mobCol.global_position,
		targeted_player.global_position,
		int(pow(2, 1 - 1) + pow(2, 3 - 1)), # Testing only for collision layers 1 and 3 
		[self] # Exclude self
	)
	var result = space_state.intersect_ray(query)
	if result and result.collider:
		if result.collider.is_in_group("Players") and Vector3(mobCol.global_position).distance_to(targeted_player.global_position) <= mob.melee_range / 2:
			print("changing state to mobattack...")
			Transistioned.emit(self, "mobattack")


# Checks if the mob has reached its target location, transitions to idle if true
func check_if_idle():
	if Vector3(mob.global_position).distance_to(target_location) <= 0.5:
		Transistioned.emit(self, "mobidle")


# Sets the target position for the navigation agent based on target location.
func makepath() -> void:
	nav_agent.target_position = target_location


# Triggered by the pathfinding timer to regularly update the navigation path.
func _on_timer_timeout():
	makepath()


# Called when the mob detects a player; updates the target location and targeted player.
func _on_detection_player_spotted(player):
	target_location = player.position
	targeted_player = player
