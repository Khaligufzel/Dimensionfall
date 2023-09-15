extends CharacterBody2D

var tween: Tween
var speed
var target_location = position

var original_scale

@export var sprite: NodePath
@export var stats: NodePath
#@export var player: Node2D
@onready var nav_agent := $NavigationAgent2D  as NavigationAgent2D

func _ready():
#	speed = get_node(stats).moveSpeed
	original_scale = get_node(sprite).scale


#func _move(_velocity):
#	velocity = _velocity
#	move_and_slide()

#func _physics_process(_delta: float) -> void:
#	var dir = to_local(nav_agent.get_next_path_position()).normalized()
#	velocity = dir * speed
#	move_and_slide()
	
	
	
	
#func makepath() -> void:
#	nav_agent.target_position = target_location
#

#func _on_timer_timeout():
#	makepath()


#func _on_detection_player_spotted(player):
#	target_location = player.global_position
	
func _get_hit(damage):
	print("Ouch!")
	
	tween = create_tween()
	tween.tween_property(get_node(sprite), "scale", get_node(sprite).scale * 1.35, 0.1)
	tween.tween_property(get_node(sprite), "scale", original_scale, 0.1)
	
	get_node(stats).current_health -= damage
	if get_node(stats).current_health <= 0:
		_die()
	
func _die():
	queue_free()
