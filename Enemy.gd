extends CharacterBody2D


var speed
var target_location = position

@export var stats: NodePath
@export var player: Node2D
@onready var nav_agent := $NavigationAgent2D  as NavigationAgent2D

func _ready():
	speed = get_node(stats).moveSpeed

func _physics_process(_delta: float) -> void:
	var dir = to_local(nav_agent.get_next_path_position()).normalized()
	velocity = dir * speed
	move_and_slide()
	
func makepath() -> void:
	nav_agent.target_position = target_location
	

func _on_timer_timeout():
	makepath()


func _on_detection_player_spotted():
	target_location = player.global_position
	
func _get_hit(damage):
	print("Ouch!")
