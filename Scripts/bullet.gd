extends RigidBody3D

var velocity = Vector3()
var damage = 10
var lifetime = 5.0

func _ready():
	# Call a function to destroy the projectile after its lifetime expires
	set_lifetime(lifetime)

func _process(_delta):
	# Update the projectile's velocity each frame
	set_linear_velocity(velocity)

func set_direction_and_speed(direction: Vector3, speed: float):
	velocity = direction.normalized() * speed

func set_lifetime(time: float):
	await get_tree().create_timer(time).timeout
	queue_free()  # Destroy the projectile after the timer

func _on_Projectile_body_entered(body):
	if body.has_method("get_hit"):
		body.get_hit(damage)
	queue_free()  # Destroy the projectile upon collision


func _on_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	queue_free()  # Destroy the projectile upon collision
