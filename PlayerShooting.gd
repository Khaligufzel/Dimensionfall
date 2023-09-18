extends Node2D

@export var projectiles: NodePath
@export var bullet_speed: float
@export var bullet_damage: float
@export var cooldown = 0.25
@export var bullet_scene: PackedScene


func _input(event):
	if event.is_action_pressed("click") && General.is_mouse_outside_HUD:
		var bullet = bullet_scene.instantiate()
		bullet.speed = bullet_speed
		bullet.damage = bullet_damage
		get_node(projectiles).add_child(bullet)
		bullet.global_position = global_position
		#bullet.rotation = (get_global_mouse_position() - global_position).normalized()
		bullet.direction = (get_global_mouse_position() - global_position).normalized()

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
