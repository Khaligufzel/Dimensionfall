extends Control

# Called when the node enters the scene tree for the first time.
func _ready():
	$CategoryTree.hide_root = true
	load_documentation_files()
	$CategoryTree.item_selected.connect(_on_CategoryTree_item_selected)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func load_documentation_files():
	var resourceDir = "./Documentation"
	var dir = DirAccess.open(resourceDir)
	if dir:
		var root = $CategoryTree.create_item()
		populateTree(resourceDir, root)
	else:
		print("An error occurred when trying to access the path.")

#This function takes the path of a directory and a treeitem as parameters. 
#Then it loops through all the items in the directory. 
#If it finds a directory, it will create a new treeitem and then call itself so the 
#function is executed recursively. If it finds a file it will only add a new treeitem 
#with the name of the file that was found.
func populateTree(directory: String, treeItem: TreeItem):
	var dir = DirAccess.open(directory)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var filePath = directory + "/" + file_name
			if dir.current_is_dir():
				var newTreeItem = $CategoryTree.create_item(treeItem)
				newTreeItem.set_text(0, sanitize_filename(file_name))
				populateTree(filePath, newTreeItem)
			else:
				var fileInfo = FileAccess.open(filePath, FileAccess.READ)
				if fileInfo:
					var newTreeItem = $CategoryTree.create_item(treeItem)
					newTreeItem.set_text(0, sanitize_filename(file_name))
					newTreeItem.set_metadata(0,filePath)
				else:
					print("Error opening file: " + filePath)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("Error opening directory: " + directory)

#This function is called when the CategoryTree emits the item_selected signal. 
#The function will get the currently selected item from the CategoryTree and 
#read the filename from the metadata of the selected Treeitem. 
#It will then display the contents of the file
func _on_CategoryTree_item_selected():
	var selected_item = $CategoryTree.get_selected()
	if selected_item != null:
		var metadata = selected_item.get_metadata(0)
		if metadata != null:
			$DocumentDisplay.display_file(metadata)

#This function takes a string and replaces "_" with " " and removes' ".md" at the end of the string. 
#It then returns the modified string
func sanitize_filename(input: String) -> String:
	var modifiedString = input.replace("_", " ")
	modifiedString = modifiedString.replace(".md", "")
	return modifiedString

#This function will be called when the user clicks ona link in the documentation page
func _on_document_display_meta_clicked(meta):
	#Open the link in the default browser on the user's OS
	OS.shell_open(str(meta))

#When the user clicks on the back button, return to the main menu
func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scene_selector.tscn")
