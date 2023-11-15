extends Control

@onready var tileBrush: PackedScene = preload("res://Scenes/ContentManager/Mapeditor/tilebrush.tscn")
signal zoom_level_changed(value: int)
var selected_brush: Control

var zoom_level:int = 50:
	set(val):
		zoom_level = val
		zoom_level_changed.emit(zoom_level)

func _on_zoom_scroller_zoom_level_changed(value):
	zoom_level = value

func _on_tile_grid_zoom_level_changed(value):
	zoom_level = value


func _ready():
	loadTiles()


# this function will read all files in "res://Mods/Core/Tiles/" and for each file it will create a texturerect and assign the file as the texture of the texturerect. Then it will add the texturerect as a child to $HSplitContainer/EntitiesContainer/TilesList
func loadTiles():
	var tilesDir = "res://Mods/Core/Tiles/"
	var tilesList = $HSplitContainer/EntitiesContainer/ScrollContainer/TilesList
	
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
					tilesList.add_child(brushInstance)
			file_name = dir.get_next()
	else:
		print_debug("An error occurred when trying to access the path.")
	dir.list_dir_end()


#Mark the clicked tilebrush as selected, but only after deselecting all other brushes
func tilebrush_clicked(tilebrush: Control) -> void:
	selected_brush = tilebrush

# The clicked tile gets the texture of the selected brush
func _on_grid_tile_clicked(clicked_tile: Node):
	if selected_brush:
		clicked_tile.set_texture(selected_brush.get_texture())




