extends StaticBody3D


func update_texture(material: BaseMaterial3D) -> void:
	$MeshInstance3D.mesh = BoxMesh.new()
	$MeshInstance3D.mesh.surface_set_material(0, material)
