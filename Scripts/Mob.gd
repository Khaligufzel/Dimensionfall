extends CharacterBody3D

var tween: Tween 
var original_scale
# id for the mob json. this will be used to load the data when creating a mob
# when saving a mob in between levels, we will use some static json defined by this id
# and some dynamic json like the mob health and buffs and debuffs
var id: String

@export var stats: NodePath

@export var corpse_scene: PackedScene

@onready var nav_agent := $NavigationAgent3D  as NavigationAgent3D

func _ready():
	pass
	#3d
#	original_scale = get_node(sprite).scale
	
func _get_hit(damage):
	
	#3d
#	tween = create_tween()
#	tween.tween_property(get_node(sprite), "scale", get_node(sprite).scale * 1.35, 0.1)
#	tween.tween_property(get_node(sprite), "scale", original_scale, 0.1)
	
	get_node(stats).current_health -= damage
	if get_node(stats).current_health <= 0:
		_die()
	
func _die():
	add_corpse.call_deferred(global_position)
	queue_free()

func add_corpse(pos: Vector3):
	var corpse = corpse_scene.instantiate()
	get_tree().get_root().add_child(corpse)
	corpse.global_position = pos
	corpse.add_to_group("mapitems")
	
func set_sprite(newSprite: Resource):
	var material := StandardMaterial3D.new() 
	material.albedo_texture = newSprite # Set the texture of the material
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	$MeshInstance3D.mesh.surface_set_material(0, material)
