extends Control

#This scene is intended to be used inside the content editor
#It is supposed to edit exactly one mob (friend and foe)
#It expects to save the data to a JSON file that contains all data from a mod
#To load data, provide the name of the mob data file and an ID

@export var mobImageDisplay: TextureRect = null
@export var IDTextLabel: Label = null
@export var PathTextLabel: Label = null
@export var NameTextEdit: TextEdit = null
@export var DescriptionTextEdit: TextEdit = null
@export var mobSelector: Popup = null
@export var melee_damage_numedit: SpinBox
@export var melee_range_numedit: SpinBox
@export var health_numedit: SpinBox
@export var moveSpeed_numedit: SpinBox
@export var idle_move_speed_numedit: SpinBox
@export var sightRange_numedit: SpinBox
@export var senseRange_numedit: SpinBox
@export var hearingRange_numedit: SpinBox

#The JSON file to be edited
var contentSource: String = "":
	set(value):
		contentSource = value
		load_mob_data()
		mobSelector.sprites_dictionary = Gamedata.mob_materials

#This function will find an item in the contentSource JSOn file with an iD that is equal to self.name
#If an item is found, it will set all the elements in the editor with the corresponding values
func load_mob_data() -> void:
	if not FileAccess.file_exists(contentSource):
		return

	var file = FileAccess.open(contentSource, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()

	for item in data:
		if item["id"] == self.name:
			if mobImageDisplay != null and item.has("imagePath"):
				mobImageDisplay.texture = load(item["imagePath"])
			if IDTextLabel != null:
				IDTextLabel.text = str(item["id"])
			if NameTextEdit != null and item.has("name"):
				NameTextEdit.text = item["name"]
			if DescriptionTextEdit != null and item.has("description"):
				DescriptionTextEdit.text = item["description"]
			if melee_damage_numedit != null and item.has("melee_damage"):
				melee_damage_numedit.get_line_edit().text = item["melee_damage"]
			if melee_range_numedit != null and item.has("melee_range"):
				melee_damage_numedit.get_line_edit().text = item["melee_range"]
			if health_numedit != null and item.has("health"):
				health_numedit.get_line_edit().text = item["health"]
			if moveSpeed_numedit != null and item.has("move_speed"):
				moveSpeed_numedit.get_line_edit().text = item["move_speed"]
			if idle_move_speed_numedit != null and item.has("idle_move_speed"):
				idle_move_speed_numedit.get_line_edit().text = item["idle_move_speed"]
			if sightRange_numedit != null and item.has("sight_range"):
				sightRange_numedit.get_line_edit().text = item["sight_range"]
			if senseRange_numedit != null and item.has("sense_range"):
				senseRange_numedit.get_line_edit().text = item["sense_range"]
			if hearingRange_numedit != null and item.has("hearing_range"):
				hearingRange_numedit.get_line_edit().text = item["hearing_range"]
			break
	

#The editor is closed, destroy the instance
#TODO: Check for unsaved changes
func _on_close_button_button_up() -> void:
	queue_free()

#This function takes all data fro the form elements and writes it to the contentSource JSON file.
func _on_save_button_button_up() -> void:
	var file = FileAccess.open(contentSource, FileAccess.READ_WRITE)
	var data = JSON.parse_string(file.get_as_text())
	file.close()

	for item in data:
		if item["id"] == IDTextLabel.text:
			item["imagePath"] = mobImageDisplay.texture.resource_path
			item["name"] = NameTextEdit.text
			item["description"] = DescriptionTextEdit.text
			item["melee_damage"] = melee_damage_numedit.get_line_edit().text
			item["melee_range"] = melee_damage_numedit.get_line_edit().text
			item["health"] = health_numedit.get_line_edit().text
			item["move_speed"] = moveSpeed_numedit.get_line_edit().text
			item["idle_move_speed"] = idle_move_speed_numedit.get_line_edit().text
			item["sight_range"] = sightRange_numedit.get_line_edit().text
			item["sense_range"] = senseRange_numedit.get_line_edit().text
			item["hearing_range"] = hearingRange_numedit.get_line_edit().text
			break

	file = FileAccess.open(contentSource, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


#When the mobImageDisplay is clicked, the user will be prompted to select an image from 
# "res://Mods/Core/mobs/". The texture of the mobImageDisplay will change to the selected image
func _on_mob_image_display_gui_input(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		mobSelector.show()


func _on_sprite_selector_sprite_selected_ok(clicked_sprite) -> void:
	var mobTexture: Resource = clicked_sprite.get_texture()
	mobImageDisplay.texture = mobTexture
	PathTextLabel.text = mobTexture.resource_path
