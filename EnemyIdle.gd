extends State
class_name EnemyIdle

var idle_speed

@export var stats: NodePath


func Enter():
	idle_speed = get_node(stats).idle_move_speed
	


func _on_detection_player_spotted(player):
	Transistioned.emit(self, "enemyfollow")
