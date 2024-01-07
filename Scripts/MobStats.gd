extends Node

@export var melee_damage: float
@export var melee_range: float
@export var health: float
var current_health: float
@export var moveSpeed: float
var current_move_speed: float
@export var idle_move_speed: float
var current_idle_move_speed: float
@export var sightRange: float
@export var senseRange: float
@export var hearingRange: float

# Called when the node enters the scene tree for the first time.
func _ready():
	current_health = health
	current_move_speed = moveSpeed
	current_idle_move_speed = idle_move_speed


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
