extends State
class_name MobRangedAttack

var attack_timer: Timer
var mob: CharacterBody3D
var spotted_target: CharacterBody3D

func _ready():
	name = "MobRangedAttack"
	attack_timer = Timer.new()
	attack_timer.wait_time = 1 #mob.rmob.ranged_cooldown # TODO: Need a ranged_cooldown in mob data
	add_child.call_deferred(attack_timer)
	attack_timer.timeout.connect(_on_attack_cooldown_timeout)

func Enter():
	attack_timer.start()
	print("ENTERING RANGED ATTACK MODE")

func Exit():
	attack_timer.stop()

func Physics_Update(_delta: float):
	if mob.terminated:
		Transistioned.emit(self, "mobterminate")
		return

	var ranged_range: int = mob.get_ranged_range()

	if spotted_target and is_instance_valid(spotted_target) and mob.global_position.distance_to(spotted_target.global_position) <= ranged_range:
		# Make the mob look at the target
		var target_position = spotted_target.global_position
		target_position.y = mob.meshInstance.global_position.y # Align y to avoid tilting
		mob.meshInstance.look_at(target_position, Vector3.UP)

		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(mob.global_position, spotted_target.global_position, 3, [self])
		var result = space_state.intersect_ray(query)

		if result and result.collider == spotted_target:
			if attack_timer.is_stopped():
				attack_timer.start()
	else:
		Transistioned.emit(self, "mobfollow") # Exit back to follow state if out of range


func _on_attack_cooldown_timeout():
	shoot_projectile()

func shoot_projectile():
	# Ensure target is still valid before shooting
	if not spotted_target or not is_instance_valid(spotted_target):
		return

	var spawn_position = mob.global_transform.origin + Vector3(0.0, -0.0, 0.0)
	var target_position = spotted_target.global_position
	var projectile_speed: float = 5 # TODO: implement mob.rmob.projectile_speed

	spawn_projectile(spawn_position, target_position, projectile_speed)


func _on_detection_target_spotted(entity):
	spotted_target = entity


# Spawns a projectile with the given spawn position, target position, and speed.
func spawn_projectile(spawn_position: Vector3, target_position: Vector3, speed: float):
	var projectile_instance = preload("res://Defaults/Projectiles/DefaultBullet.tscn").instantiate()
	# Configure the projectile as an enemy projectile
	projectile_instance.configure_collision(false, mob)

	# Align target y-level to avoid vertical aim issues (flat projectiles)
	target_position.y = spawn_position.y

	# Calculate direction and apply speed
	var direction = (target_position - spawn_position).normalized()
	direction.y = 0

	# Generate attack data and assign it to the projectile
	projectile_instance.attack = create_attack_data(spawn_position)
	projectile_instance.set_bullet_texture(mob.get_bullet_sprite())

	Helper.signal_broker.projectile_spawned.emit(projectile_instance, mob.get_rid())

	projectile_instance.global_transform.origin = spawn_position
	projectile_instance.set_direction_and_speed(direction, speed)


# Creates attack data for a ranged projectile
func create_attack_data(spawn_position: Vector3) -> Dictionary:
	# Exmple: {"id": "basic_ranged", "damage_multiplier": 1, "type": "ranged"}
	var chosen_attack: Dictionary = mob.get_attack_of_type("ranged")
	if not chosen_attack:
		return {}
	return {
		"attack": chosen_attack,
		"mobposition": spawn_position,
		"hit_chance": 100
	}
