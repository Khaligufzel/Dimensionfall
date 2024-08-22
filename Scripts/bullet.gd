extends RigidBody3D

var velocity = Vector3()
var damage = 10
var lifetime = 5.0

func _ready():
	# Call a function to destroy the projectile after its lifetime expires
	set_lifetime(lifetime)

func _process(_delta):
	# Update the projectile's velocity each frame
	#set_linear_velocity(velocity)
	pass

func set_direction_and_speed(direction: Vector3, speed: float):
	velocity = direction.normalized() * speed
	# Rotate the bullet to match the direction
	rotate_bullet_to_match_direction(direction)
	set_linear_velocity(velocity)

func rotate_bullet_to_match_direction(direction: Vector3):
	# Ensure the direction vector is not zero
	if direction.length() == 0:
		return
	# Calculate the rotation needed to align the bullet's forward direction (usually -Z) with the velocity direction
	var target_rotation = Quaternion(Vector3(0, 0, -1), direction.normalized())
	# Apply the rotation to the bullet
	rotation = target_rotation.get_euler()


func set_lifetime(time: float):
	await get_tree().create_timer(time).timeout
	queue_free()  # Destroy the projectile after the timer

# The bullet has hit something
func _on_Projectile_body_entered(body: Node):
	if body.has_method("get_hit"):
		var attack: Dictionary = {"damage":damage, "hit_chance":100}
		body.get_hit(attack)
	queue_free()  # Destroy the projectile upon collision


func _on_body_shape_entered(_body_rid: RID, _body: Node, _body_shape_index: int, _local_shape_index: int):
	queue_free()  # Destroy the projectile upon collision


# For some reason, the _on_body_shape_entered function does not trigger when the bullet collides
# with a collider that's not inside the tree, like with FurnitureStaticSrv. That's why an Area3d
# was added so it can still use the functionality it's supposed to. The Area3d listens to 
# Layer 7 which is the static obstacles layer.
func _on_area_3d_body_shape_entered(body_rid: RID, _body: Node3D, _body_shape_index: int, _local_shape_index: int) -> void:
	if body_rid:
		print_debug("a bullet hit ", body_rid)
		var attack: Dictionary = {"damage":damage, "hit_chance":100}
		# Used for bodies that exist outside the scene tree, like StaticFurnitureSrv
		Helper.signal_broker.bullet_hit.emit(body_rid, attack)
	queue_free()  # Destroy the projectile upon collision
