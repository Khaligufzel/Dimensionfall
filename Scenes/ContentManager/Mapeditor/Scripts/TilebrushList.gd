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
	loadMobs()
	loadTiles()
	loadFurniture()
	
# this function will read all files in Gamedata.data.tiles.data and creates tilebrushes for each tile in the list. It will make separate lists for each category that the tiles belong to.
func loadMobs():
	var mobList: Array = Gamedata.data.mobs.data
	var newMobsList: Control = scrolling_Flow_Container.instantiate()
	newMobsList.header = "Mobs"
	add_child(newMobsList)
	for item in mobList:
		if item.has("sprite"):
			var imagefileName: String = item["sprite"]
			imagefileName = imagefileName.get_file()
			# Get the texture from gamedata
			var texture: Resource = Gamedata.data.mobs.sprites[imagefileName]
			# Create a TextureRect node
			var brushInstance = tileBrush.instantiate()
			# Assign the texture to the TextureRect
			brushInstance.set_tile_texture(texture)
			# Since the map editor needs to knw what tile ID is used,
			# We store the tile id in a variable in the brush
			brushInstance.tileID = item.id
			brushInstance.tilebrush_clicked.connect(tilebrush_clicked)
			brushInstance.entityType = "mob"
			# Add the TextureRect as a child to the TilesList
			newMobsList.add_content_item(brushInstance)
			instanced_brushes.append(brushInstance)

func loadFurniture():
	var furnitureList: Array = Gamedata.data.furniture.data 
	var newFurnitureList: Control = scrolling_Flow_Container.instantiate()
	newFurnitureList.header = "Furniture"
	add_child(newFurnitureList)

	for item in furnitureList:
		if item.has("sprite"):
			var imagefileName: String = item["sprite"]
			imagefileName = imagefileName.get_file()
			var texture: Resource = Gamedata.data.furniture.sprites[imagefileName]
			var brushInstance = tileBrush.instantiate()
			brushInstance.set_tile_texture(texture)
			brushInstance.tileID = item.id
			brushInstance.tilebrush_clicked.connect(tilebrush_clicked)
			brushInstance.entityType = "furniture"
			newFurnitureList.add_content_item(brushInstance)
			instanced_brushes.append(brushInstance)


# this function will read all files in Gamedata.data.tiles.data and creates tilebrushes for each tile in the list. It will make separate lists for each category that the tiles belong to.
func loadTiles():
	var tileList: Array = Gamedata.data.tiles.data

	for item in tileList:
		if item.has("sprite"):
			#We need to put the tiles the right catecory
			#Each tile can have 0 or more categories
			for category in item["categories"]:
				#Check if the category was already added
				var newTilesList: Control = find_list_by_category(category)
				if !newTilesList:
					newTilesList = scrolling_Flow_Container.instantiate()
					newTilesList.header = category
					add_child(newTilesList)
				var imagefileName: String = item["sprite"]
				imagefileName = imagefileName.get_file()
				# Get the texture from gamedata
				var texture: Resource = Gamedata.data.tiles.sprites[imagefileName].albedo_texture
				# Create a TextureRect node
				var brushInstance = tileBrush.instantiate()
				# Assign the texture to the TextureRect
				brushInstance.set_tile_texture(texture)
				# Since the map editor needs to knw what tile ID is used,
				# We store the tile id in a variable in the brush
				brushInstance.tileID = item.id
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
