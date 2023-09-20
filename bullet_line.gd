extends Line2D

var alpha = 1
#var tween : Tween


# Called when the node enters the scene tree for the first time.
func _ready():
#	tween = create_tween()
#	tween.tween_property()
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	alpha -= delta * 5
	default_color = Color(1, 1, 1, alpha)


func _on_timer_timeout():
	queue_free()
