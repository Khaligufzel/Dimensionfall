extends HBoxContainer

# This is a standalone widget that provides a read-only textedit in a hboxcontainer and 
# a button to clear the contents of the textedit. You can drop data on it to set the content
# of the textedit. 

# It checks the specified mod and content type to validate the input

# To use this widget, instance it as a child node in your form and assign it to a variable like so:
# @export var mydroppableTextEdit: HBoxContainer = null
# 
# On the _ready function (or anywhere) in your script, call
# mydroppableTextEdit.content_types = [DMod.ContentType.MOBGROUPS, DMod.ContentType.MOBFACTIONS]
#
# To get the dropped data back, call:
# var mydroppeddata: Dictionary = mydroppableTextEdit.dropped_data


var is_disabled: bool = false  # Tracks whether the widget is disabled
var content_types: Array[DMod.ContentType]
var dropped_data: Dictionary # The data that was dropped last.


@export var mytextedit: TextEdit
@export var myplaceholdertext: String = "drop your data here"
@export var button: Button = null

signal text_changed(new_text: String)


func _ready():
	mytextedit.placeholder_text = myplaceholdertext


# This function should return true if the dragged data can be dropped here
# We are expecting a dictionary like this:
#	{
#		"id": selected_item_id,
#		"text": selected_item_text,
#		"mod_id": mod_id,
#		"contentType": contentType
#	}
func _can_drop_data(_newpos, data) -> bool:
	# Check if the data dictionary has the 'id' property
	if not data or not data.has("id") or not data.has("contentType"):
		return false
	
	if not data.contentType in content_types:
		return false # We only accept the provided content types, for example DMod.ContentType.MOBGROUPS
	
	var mod: DMod = Gamedata.mods.by_id(data.get("mod_id")) # Will be a mod with id "Core" for example
	# moddata could be the DMobs instance from the "Core" mod for example
	# Equivalent to calling Gamedata.mods.by_id("Core").mobs if the contentType is DMod.ContentType.MOBGROUPS
	var moddata: RefCounted = mod.get_data_of_type(data.contentType)
	
	# Check that the mod has the entity with the provided id
	if not moddata.has_id(data["id"]):
		return false

	# If all checks pass, return true
	return true


# This function handles the data being dropped
func _drop_data(newpos, data) -> void:
	if _can_drop_data(newpos, data):
		set_text(data.get("id", ""))
		dropped_data = data


func _on_button_button_up():
	mytextedit.clear()
	text_changed.emit("")


func set_text(newtext: String):
	mytextedit.text = newtext
	text_changed.emit(newtext)


func get_text():
	return mytextedit.text


# Disables all controls in the widget and sets is_disabled to true
func disable() -> void:
	is_disabled = true  # Set the disabled flag
	if button:  # Ensure button is valid before disabling
		button.disabled = true


# Enables all controls in the widget and sets is_disabled to false
func enable() -> void:
	is_disabled = false  # Reset the disabled flag
	if button:  # Ensure button is valid before enabling
		button.disabled = false
