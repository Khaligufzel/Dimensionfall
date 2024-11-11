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
	attack_timer.wait_time = mob.dmob.melee_cooldown  # Set the wait time based on mob's melee_cooldown
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
# attack: a dictionary like this:
# {
# 	"attributeid": "torso_health", # The PlayerAttribute that is targeted by this attack
# 	"damage": 20, # The amount to subtract from the target attribute
# 	"knockback": 2, # The number of tiles to push the player away
# 	"mobposition": Vector3(17, 1, 219) # The global position of the mob
# }
func attack():
	print("Attacking!")

	# Apply damage to a randomly selected attribute from 'any_of'
	if mob.dmob.targetattributes.has("any_of") and not mob.dmob.targetattributes["any_of"].is_empty():
		var any_of_attributes: Array = mob.dmob.targetattributes["any_of"]
		var selected_attribute: Dictionary = any_of_attributes.pick_random()
		_apply_attack_to_player(selected_attribute)

	# Apply damage to each attribute in 'all_of'
	if mob.dmob.targetattributes.has("all_of"):
		var all_of_attributes: Array = mob.dmob.targetattributes["all_of"]
		for attribute in all_of_attributes:
			_apply_attack_to_player(attribute)


# Helper function to send attack data to the player's _get_hit method
func _apply_attack_to_player(attribute: Dictionary) -> void:
	if targeted_player and targeted_player.has_method("_get_hit"):
		var attack_data: Dictionary = {
			"attributeid": attribute["id"],
			"damage": attribute["damage"],
			"knockback": mob.dmob.melee_knockback,
			"mobposition": mob.global_position
		}
		targeted_player._get_hit(attack_data)


func stop_attacking():
	print("I stopped attacking")
	attack_timer.stop()
	Transistioned.emit(self, "mobfollow")


func _on_detection_player_spotted(player):
	targeted_player = player # Replace with function body.


func _on_attack_cooldown_timeout():
	attack()
