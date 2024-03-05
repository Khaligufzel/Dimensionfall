extends CharacterBody3D

var tween: Tween 
var original_scale
# id for the mob json. this will be used to load the data when creating a mob
# when saving a mob in between levels, we will use some static json defined by this id
# and some dynamic json like the mob health and buffs and debuffs
var id: String


var melee_damage: float = 20.0
var melee_range: float = 1.5
var health: float = 100.0
var current_health: float
var moveSpeed: float = 1.0
var current_move_speed: float
var idle_move_speed: float = 0.5
var current_idle_move_speed: float
var sightRange: float = 200.0
var senseRange: float = 50.0
var hearingRange: float = 1000.0

@export var corpse_scene: PackedScene
@onready var nav_agent := $NavigationAgent3D  as NavigationAgent3D
#
#func _ready():
	#pass
	##3d
##	original_scale = get_node(sprite).scale
# Called when the node enters the scene tree for the first time.
func _ready():
	current_health = health
	current_move_speed = moveSpeed
	current_idle_move_speed = idle_move_speed
	
func get_hit(damage):
	
	#3d
#	tween = create_tween()
#	tween.tween_property(get_node(sprite), "scale", get_node(sprite).scale * 1.35, 0.1)
#	tween.tween_property(get_node(sprite), "scale", original_scale, 0.1)
	current_health -= damage
	if current_health <= 0:
		_die()
	
func _die():
	add_corpse.call_deferred(global_position)
	queue_free()

func add_corpse(pos: Vector3):
	var corpse = corpse_scene.instantiate()
	get_tree().get_root().add_child(corpse)
	corpse.global_position = pos
	corpse.add_to_group("mapitems")

# Sets the sprite to the mob
# TODO: In order to optimize this, instead of calling original_mesh.duplicate()
# We should keep track of every unique mesh (one for each type of mob)
# THen we check if there has already been a mesh created for a mob with this
# id and assign that mesh. Right now every mob has it's own unique mesh
func set_sprite(newSprite: Resource):
	var original_mesh = $MeshInstance3D.mesh
	var new_mesh = original_mesh.duplicate()  # Clone the mesh
	var material := StandardMaterial3D.new()
	material.albedo_texture = newSprite
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	new_mesh.surface_set_material(0, material)
	$MeshInstance3D.mesh = new_mesh  # Set the new mesh to MeshInstance3D


# Applies it's own data from the dictionary it received
# If it is created as a new mob, it will spawn with the default stats
# If it is created from a saved game, it might have lower health for example
func apply_stats_from_json(json_data: Dictionary) -> void:
	id = json_data.id
	set_sprite(Gamedata.get_sprite_by_id(Gamedata.data.mobs,json_data.id))
	if json_data.has("melee_damage"):
		melee_damage = float(json_data["melee_damage"])
	if json_data.has("melee_range"):
		melee_range = float(json_data["melee_range"])
	if json_data.has("health"):
		health = float(json_data["health"])
		if json_data.has("current_health"):
			current_health =  float(json_data["current_health"])
		else: # Reset current health to max health
			current_health = health
	if json_data.has("move_speed"):
		moveSpeed = float(json_data["move_speed"])
		if json_data.has("current_move_speed"):
			current_move_speed =  float(json_data["current_move_speed"])
		else: # Reset current moveSpeed to max moveSpeed
			current_move_speed = moveSpeed
	if json_data.has("idle_move_speed"):
		idle_move_speed = float(json_data["idle_move_speed"])
		if json_data.has("current_idle_move_speed"):
			current_idle_move_speed =  float(json_data["current_idle_move_speed"])
		else: # Reset current idle_move_speed to max idle_move_speed
			current_idle_move_speed = idle_move_speed
	if json_data.has("sight_range"):
		sightRange = float(json_data["sight_range"])
	if json_data.has("sense_range"):
		senseRange = float(json_data["sense_range"])
	if json_data.has("hearing_range"):
		hearingRange = float(json_data["hearing_range"])
