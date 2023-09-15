extends Area2D

var speed
var direction = Vector2(0,0)
var damage

var velocity

# Called when the node enters the scene tree for the first time.
func _ready():
	#look_at(get_global_mouse_position())
	#print(rotation_degrees)
	#rotate(get_angle_to(get_global_mouse_position()))
	pass
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	velocity = direction * speed * delta
	look_at(position + velocity)
	position += velocity

	#rotation = velocity
	


func _on_body_entered(body):
	print("hit")
	if body.has_method("_get_hit"):
		body._get_hit(damage)
	queue_free()

