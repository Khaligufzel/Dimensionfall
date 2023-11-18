extends HFlowContainer

@onready var tileBrush: PackedScene = preload("res://Scenes/ContentManager/Mapeditor/tilebrush.tscn")

signal tile_brush_selection_change(tilebrush: Control)
var selected_brush: Control:
	set(newBrush):
		selected_brush = newBrush
		tile_brush_selection_change.emit(selected_brush)

func _ready():
	loadTiles()
	
# this function will read all files in "res://Mods/Core/Tiles/" and for each file it will create a texturerect and assign the file as the texture of the texturerect. Then it will add the texturerect as a child to $HSplitContainer/EntitiesContainer/TilesList
func loadTiles():
	var tilesDir = "res://Mods/Core/Tiles/"
	
	var dir = DirAccess.open(tilesDir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var extension = file_name.get_extension()

			if !dir.current_is_dir():
				if extension == "png":
					# Create a TextureRect node
					var brushInstance = tileBrush.instantiate()

					# Load the texture from file
					var texture: Resource = load(tilesDir + file_name)

					# Assign the texture to the TextureRect
					brushInstance.set_tile_texture(texture)
					brushInstance.tilebrush_clicked.connect(tilebrush_clicked)

					# Add the TextureRect as a child to the TilesList
					add_child(brushInstance)
			file_name = dir.get_next()
	else:
		print_debug("An error occurred when trying to access the path.")
	dir.list_dir_end()

#Mark the clicked tilebrush as selected, but only after deselecting all other brushes
func tilebrush_clicked(tilebrush: Control) -> void:
	deselect_all_brushes()
	# If the clicked brush was not select it, we select it. Otherwise we deselect it
	if selected_brush != tilebrush:
		selected_brush = tilebrush
		selected_brush.modulate = Color(0.227, 0.635, 0.757)
	else:
		selected_brush = null
	
func deselect_all_brushes():
	var children = get_children()
	for child in children:
		child.modulate = Color(1,1,1)
