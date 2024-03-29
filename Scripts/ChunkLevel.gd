class_name ChunkLevel
extends Node3D

# This class is intended to be used to represent a level inside a chunk in the tacticalmap
# A chunk can have a maximum of 21 levels, from -10 to +10
# A level can hold a maximum of 1024 blocks using the 32x32 dimensions
# One of the purposes of the chunklevel is to control the visibility of levels above the player

var levelposition: Vector3
var blocklist: Array
var y: int

# Called when the node enters the scene tree for the first time.
func _ready():
	position = levelposition
	add_to_group("maplevels")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
