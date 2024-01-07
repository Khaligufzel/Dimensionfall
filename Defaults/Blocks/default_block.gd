extends StaticBody3D

var id: String = ""

func update_texture(material: BaseMaterial3D) -> void:
	$MeshInstance3D.mesh = BoxMesh.new()
	$MeshInstance3D.mesh.surface_set_material(0, material)
	
func get_texture_string() -> String:
	return $MeshInstance3D.mesh.material.albedo_texture.resource_path
