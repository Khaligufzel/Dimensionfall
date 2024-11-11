extends State
class_name MobAttack

var attack_timer: Timer
var mob: CharacterBody3D # The mob that we execute the attack for

var tween: Tween
var targeted_player
var is_in_attack_mode = false

func _ready():
	name = "MobAttack"
	# Create and configure AttackCooldown Timer
	var attack_cooldown = Timer.new()
	attack_timer = attack_cooldown
	add_child.call_deferred(attack_cooldown)
	attack_timer.timeout.connect(_on_attack_cooldown_timeout)


func Enter():
	attack_timer.start()
	print("ENTERING BATTLE MODE")


func Exit():
	pass


func Physics_Update(_delta: float):
	if mob.terminated:
		Transistioned.emit(self, "mobterminate") 
	# Rotation towards target using look_at
	if targeted_player:
		var target_position = targeted_player.global_position
		target_position.y = mob.meshInstance.global_position.y  # Align y-axis to avoid tilting
		mob.meshInstance.look_at(target_position, Vector3.UP)

	var space_state = get_world_3d().direct_space_state
	# TO-DO Change playerCol to group of players
	var query = PhysicsRayQueryParameters3D.create(mob.global_position, targeted_player.global_position, int(pow(2, 1-1) + pow(2, 3-1)), [self])
	var result = space_state.intersect_ray(query)

	if result:

		if result.collider.is_in_group("Players") && Vector3(mob.global_position).distance_to(targeted_player.global_position) <= mob.melee_range:

			if !is_in_attack_mode:
				is_in_attack_mode = true
				try_to_attack()			
		else:
			is_in_attack_mode = false
			stop_attacking()
	else:
		is_in_attack_mode = false
		stop_attacking()


func try_to_attack():
	print("Trying to attack...")
	attack_timer.start()


# The mob is going to attack.
func attack():
	print("Attacking!")
	# Apply damage to a randomly selected attribute from 'any_of'
	if mob.dmob.targetattributes.has("any_of") and not mob.dmob.targetattributes["any_of"].is_empty():
		var any_of_attributes: Array = mob.dmob.targetattributes["any_of"]
		var selected_attribute: Dictionary = any_of_attributes.pick_random()
		var attribute_id: String = selected_attribute["id"]
		var damage: float = selected_attribute["damage"]

		if targeted_player and targeted_player.has_method("_get_hit"):
			targeted_player._get_hit(attribute_id, damage)

	# Apply damage to each attribute in 'all_of'
	if mob.dmob.targetattributes.has("all_of"):
		var all_of_attributes: Array = mob.dmob.targetattributes["all_of"]
		for attribute in all_of_attributes:
			var attribute_id: String = attribute["id"]
			var damage: float = attribute["damage"]

			if targeted_player and targeted_player.has_method("_get_hit"):
				targeted_player._get_hit(attribute_id, damage)



func stop_attacking():
	print("I stopped attacking")
	attack_timer.stop()
	Transistioned.emit(self, "mobfollow")


func _on_detection_player_spotted(player):
	targeted_player = player # Replace with function body.


func _on_attack_cooldown_timeout():
	attack()
