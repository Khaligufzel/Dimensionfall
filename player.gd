extends CharacterBody2D

signal update_doll

var rng = RandomNumberGenerator.new()

var speed = 100  # speed in pixels/sec
var current_speed

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
	

func _physics_process(delta):
	var direction = Input.get_vector("left", "right", "up", "down")
	velocity = direction * speed

	move_and_slide()
	

func _get_hit(damage: float):
	var limb_number = rng.randi_range(0,5)
	
	match limb_number:
		0:
			current_head_health -= damage
		1:
			current_right_arm_health -= damage
		2:
			current_left_arm_health -= damage
		3:
			current_torso_health -= damage
		4:
			current_right_leg_health -= damage
		5:
			current_left_leg_health -= damage
			
	update_doll.emit(current_head_health, current_right_arm_health, current_left_arm_health, current_torso_health, current_right_leg_health, current_left_leg_health)
