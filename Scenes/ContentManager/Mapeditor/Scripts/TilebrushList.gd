extends VBoxContainer

#@onready var tileBrush: PackedScene = preload("res://Scenes/ContentManager/Mapeditor/tilebrush.tscn")
#@onready var scrolling_Flow_Container: PackedScene = preload("res://Scenes/ContentManager/Custom_Widgets/Scrolling_Flow_Container.tscn")
@export var scrolling_Flow_Container: PackedScene = null
@export var tileBrush: PackedScene = null

var instanced_brushes: Array[Node] = []

signal tile_brush_selection_change(tilebrush: Control)
var selected_brush: Control:
	set(newBrush):
		selected_brush = newBrush
		tile_brush_selection_change.emit(selected_brush)

func _ready():
	loadTiles()
	
# this function will read all files in "res://Mods/Core/Tiles/" and for each file it will create a texturerect and assign the file as the texture of the texturerect. Then it will add the texturerect as a child to $HSplitContainer/EntitiesContainer/TilesList
func loadTiles():
	var tileList: Array = Gamedata.all_tiles

	for item in tileList:
		if item.has("imagePath"):
			#We need to put the tiles the right catecory
			#Each tile can have 0 or more categories
			for category in item["categories"]:
				#Check if the category was already added
				var newTilesList: Control = find_list_by_category(category)
				if !newTilesList:
					newTilesList = scrolling_Flow_Container.instantiate()
					newTilesList.header = category
					add_child(newTilesList)
				var imagefileName: String = item["imagePath"]
				imagefileName = imagefileName.get_file()
				# Get the texture from gamedata
				var texture: Resource = Gamedata.tile_materials[imagefileName].albedo_texture
				# Create a TextureRect node
				var brushInstance = tileBrush.instantiate()
				# Assign the texture to the TextureRect
				brushInstance.set_tile_texture(texture)
				brushInstance.tilebrush_clicked.connect(tilebrush_clicked)

				# Add the TextureRect as a child to the TilesList
				newTilesList.add_content_item(brushInstance)
				instanced_brushes.append(brushInstance)
	
#Find the list associated with the category
func find_list_by_category(category: String) -> Control:
	var currentCategories: Array[Node] = get_children()
	var categoryFound: Control = null
	#Check if the category was already added
	for categoryList in currentCategories:
		if categoryList.header == category:
			categoryFound = categoryList
			break
	return categoryFound
	

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
