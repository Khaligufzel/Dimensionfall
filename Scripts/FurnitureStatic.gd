extends StaticBody3D


# id for the furniture json. this will be used to load the data when creating a furniture
# when saving a mob in between levels, we will use some static json defined by this id
# and some dynamic json like the furniture health
var id: String

@export var corpse_scene: PackedScene
var current_health: float = 10.0

	
func _get_hit(damage):
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
	
func set_sprite(newSprite: Resource):
	$Sprite3D.texture = newSprite
