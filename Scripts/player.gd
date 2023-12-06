extends CharacterBody3D

signal update_doll

signal update_stamina_HUD

var is_alive = true

var rng = RandomNumberGenerator.new()

var speed = 1  # speed in meters/sec
var current_speed

var run_multiplier = 1.5
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
var stamina_lost_while_running_persec = 10
var stamina_regen_while_standing_still = 5

var hunger = 0
var current_hunger

var thirst = 0
var current_thirst

var nutrition = 100
var current_nutrition

var pain
var current_pain = 0

@export var sprite : Sprite3D

@export var interact_range : float = 10

#@export var progress_bar : NodePath
#@export var progress_bar_filling : NodePath
#@export var progress_bar_timer : NodePath

@export var foostep_player : AudioStreamPlayer
@export var foostep_stream_randomizer : AudioStreamRandomizer

#var progress_bar_timer_max_time : float

#var is_progress_bar_well_progressing_i_guess = false

func _ready():
	current_left_arm_health = left_arm_health
	current_right_arm_health = right_arm_health
	current_left_leg_health = left_leg_health
	current_right_leg_health = right_leg_health
	current_head_health = head_health
	current_torso_health = torso_health
	
	current_stamina = stamina
	
	
func _process(_delta):
#	if is_progress_bar_well_progressing_i_guess:
#		get_node(progress_bar_filling).scale.x = lerp(1, 0, get_node(progress_bar_timer).time_left / progress_bar_timer_max_time)
		
		
	# player facing the mouse position
	var mouse_position : Vector3 =  get_tree().get_first_node_in_group("Camera").project_ray_origin(get_viewport().get_mouse_position())
	if mouse_position.x > global_position.x:
		sprite.flip_h = true
	else:
		sprite.flip_h = false

func _physics_process(delta):

	var gravity = 9.8
	velocity.y += -gravity * delta
	move_and_slide()
	
	if is_alive:
		if !is_running || current_stamina <= 0:
			var input_dir = Input.get_vector("left", "right", "up", "down")
			var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			velocity = direction * speed
#			if velocity.length() > 0.1:
#				get_node(animation_player).play("player_walking")
#			else:
#				get_node(animation_player).stop()
			move_and_slide()
		elif is_running && current_stamina > 0:
			var input_dir = Input.get_vector("left", "right", "up", "down")
			var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			velocity = direction * speed * run_multiplier
			
			if velocity.length() > 0:
#				get_node(animation_player).play("player_running")
				current_stamina -= delta * stamina_lost_while_running_persec
			
			move_and_slide()
			
		if velocity.length() < 0.1:
			current_stamina += delta * stamina_regen_while_standing_still
			if current_stamina > stamina:
				current_stamina = stamina

		update_stamina_HUD.emit(current_stamina)


func _input(event):
	if event.is_action_pressed("run"):
		is_running = true
	if event.is_action_released("run"):
		is_running = false
		
	#checking if we can interact with the object
	if event.is_action_pressed("interact"):
		var layer = pow(2, 1-1) + pow(2, 2-1) + pow(2, 3-1)
		var mouse_pos : Vector2 = get_viewport().get_mouse_position()
		var world_mouse_position = Helper.raycast_from_mouse(mouse_pos, layer).position
		var result = Helper.raycast(global_position, global_position + (Vector3(world_mouse_position.x - global_position.x, 0, world_mouse_position.z - global_position.z)).normalized() * interact_range, layer, [self])

		print("Interact button pressed")
		if result:
			print("Found object")
			if result.collider.get_owner().has_method("interact"):
				print("collider has method")
				result.collider.get_owner().interact()
				

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
	print("Player died")
	is_alive = false
	
func transfer_damage_to_torso(damage: float):
	current_torso_health -= damage
	check_if_alive()
	
#func start_progress_bar(time : float):
#	get_node(progress_bar).visible = true
#	get_node(progress_bar_timer).wait_time = time
#	get_node(progress_bar_timer).start()
#	get_node(progress_bar_filling).scale.x = 0
#	progress_bar_timer_max_time = time
#	is_progress_bar_well_progressing_i_guess = true
#
#
#func interrupt_progress_bar():
#	get_node(progress_bar).visible = false
#	is_progress_bar_well_progressing_i_guess = false
#
#
#func _on_progress_bar_timer_timeout():
#	interrupt_progress_bar()
	
func play_footstep_audio():
	foostep_player.stream = foostep_stream_randomizer
	foostep_player.play()

