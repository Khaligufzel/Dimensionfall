extends VBoxContainer

@export var scrolling_Flow_Container: PackedScene = null
@export var tileBrush: PackedScene = null

var instanced_brushes: Array[Node] = []

signal tile_brush_selection_change(tilebrush: Control)
var selected_brush: Control:
	set(newBrush):
		selected_brush = newBrush
		tile_brush_selection_change.emit(selected_brush)

func _ready():
	loadMaps()


# this function will read all files in Gamedata.data.maps.data and creates tilebrushes for each tile in the list. 
func loadMaps():
	var mapsList: Array = Gamedata.data.maps.data
	var newTilesList: Control = scrolling_Flow_Container.instantiate()
	newTilesList.header = "maps"
	add_child(newTilesList)

	for map in mapsList:
		# Extract the base name without the extension
		var base_name = map.get_basename()
		# If the file has an image to represent it's content, load it
		if Gamedata.data.maps.sprites.has(base_name + ".png"):
			var mySprite: Resource = Gamedata.data.maps.sprites[base_name + ".png"]
			if mySprite:
				# Create a TextureRect node
				var brushInstance = tileBrush.instantiate()
				brushInstance.set_label(base_name)
				# Assign the texture to the TextureRect
				brushInstance.set_tile_texture(mySprite)
				# Since the map editor needs to knw what tile ID is used,
				# We store the tile id in a variable in the brush
				brushInstance.mapID = map
				brushInstance.tilebrush_clicked.connect(tilebrush_clicked)
				# Add the TextureRect as a child to the TilesList
				newTilesList.add_content_item(brushInstance)
				instanced_brushes.append(brushInstance)

#Mark the clicked tilebrush as selected, but only after deselecting all other brushes
func tilebrush_clicked(tilebrush: Control) -> void:
	deselect_all_brushes()
	# If the clicked brush was not select it, we select it. Otherwise we deselect it
	if selected_brush != tilebrush:
		selected_brush = tilebrush
		selected_brush.set_selected(true)
	else:
		selected_brush = null
	
func deselect_all_brushes():
	for child in instanced_brushes:
		child.set_selected(false)
