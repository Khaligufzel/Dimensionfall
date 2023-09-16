extends CanvasLayer

@export var head_health: NodePath
@export var right_arm_health: NodePath
@export var left_arm_health: NodePath
@export var torso_health: NodePath
@export var right_leg_health: NodePath
@export var left_leg_health: NodePath

@export var healthy_color: Color
@export var damaged_color: Color
var current_color


func test():
	print("TESTING 123 123!")

func update_doll():
	pass


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_player_update_doll(head, right_arm, left_arm, torso, right_leg, left_leg):
#	head_health = head
#	right_arm_health = right_arm
#	left_arm_health = left_arm
#	torso_health = torso
#	right_leg_health = right_leg
#	left_leg_health = left_leg
	
	get_node(head_health).modulate = lerp(damaged_color, healthy_color, head/100)
	get_node(right_arm_health).modulate = lerp(damaged_color, healthy_color, right_arm/100)
	get_node(left_arm_health).modulate = lerp(damaged_color, healthy_color, left_arm/100)
	get_node(torso_health).modulate = lerp(damaged_color, healthy_color, torso/100)
	get_node(right_leg_health).modulate = lerp(damaged_color, healthy_color, right_leg/100)
	get_node(left_leg_health).modulate = lerp(damaged_color, healthy_color, left_leg/100)

