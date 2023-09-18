extends CharacterBody2D

signal update_doll

signal update_stamina_HUD

@export var animation_player: NodePath
@export var sprite: NodePath

var is_alive = true

var rng = RandomNumberGenerator.new()

var speed = 50  # speed in pixels/sec
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


func _ready():
	current_left_arm_health = left_arm_health
	current_right_arm_health = right_arm_health
	current_left_leg_health = left_leg_health
	current_right_leg_health = right_leg_health
	current_head_health = head_health
	current_torso_health = torso_health
	
	current_stamina = stamina
	

func _physics_process(delta):
	if is_alive:
		if !is_running || current_stamina <= 0:
			var direction = Input.get_vector("left", "right", "up", "down")
			velocity = direction * speed
			if velocity.length() > 0.1:
				get_node(animation_player).play("player_walking")
			else:
				get_node(animation_player).stop()
			move_and_slide()
		elif is_running && current_stamina > 0:
			var direction = Input.get_vector("left", "right", "up", "down")
			velocity = direction * speed * run_multiplier
			
			if velocity.length() > 0:
				get_node(animation_player).play("player_running")
				current_stamina -= delta * stamina_lost_while_running_persec
			
			move_and_slide()
			
		if velocity.length() < 0.1:
			current_stamina += delta * stamina_regen_while_standing_still
			if current_stamina > stamina:
				current_stamina = stamina
			
		
		if velocity.x > 0:
			get_node(sprite).flip_h = true
		elif velocity.x < 0:
			get_node(sprite).flip_h = false
		update_stamina_HUD.emit(current_stamina)


func _input(event):
	if event.is_action_pressed("run"):
		is_running = true
	if event.is_action_released("run"):
		is_running = false

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


func die():
	print("Player died")
	is_alive = false
	
func transfer_damage_to_torso(damage: float):
	current_torso_health -= damage
	check_if_alive()
