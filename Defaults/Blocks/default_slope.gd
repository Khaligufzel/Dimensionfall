extends StaticBody3D

var id: String = ""

func update_texture(material: BaseMaterial3D) -> void:
	var prism_mesh = PrismMesh.new()
	prism_mesh.left_to_right = 1
	prism_mesh.surface_set_material(0, material)

	$MeshInstance3D.mesh = prism_mesh  # Assign the new PrismMesh to the MeshInstance3D

	
func get_texture_string() -> String:
	return $MeshInstance3D.mesh.material.albedo_texture.resource_path
