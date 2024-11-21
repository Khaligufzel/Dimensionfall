extends HBoxContainer

# This is a standalone widget that provides a read-only textedit in a hboxcontainer and 
# a button to clear the contents of the textedit. You can drop data on it to set the content
# of the textedit. 

# To use this widget, instance it as a child node in your form and assign it to a variable like so:
# @export var mydroppableTextEdit: HBoxContainer = null
# 
# On the _ready function (or anywhere) in your script, call
# mydroppableTextEdit.drop_function = mydropfunction
# mydroppableTextEdit.can_drop_function = mycandropfunction
#
# Example mydropfunction:
# func mydropfunction(dropped_data: Dictionary):
# 	print("my dropped data has id" + dropped_data["id"])
# 
# Example mycandropfunction:
# func mycandropfunction(dropped_data: Dictionary):
# 	return dropped_data.has("id")
#
#
#
# If you want a function with extra arguments, you can use this in the ready function:
# mydroppableTextEdit.drop_function = mydropfunction.bind("pistol_9mm")
# mydroppableTextEdit.can_drop_function = mycandropfunction.bind("pistol_9mm")
# The dropped_data will always be passed, and every argumen you bind will be the second,
# third and so on argument
#
# Example mydropfunction with one extra argument:
# func mydropfunction(dropped_data: Dictionary, item_id: String):
# 	print("my dropped data has id" + dropped_data["id"])
# 	print("The data id " + dropped_data["id"] + " matches the item_id " + item_id)
# 
# Example mycandropfunction with one extra argument:
# func mycandropfunction(dropped_data: Dictionary, item_id: String):
# 	return dropped_data.has("id") and dropped_data["id"] == item_id


var can_drop_function: Callable
var drop_function: Callable
var is_disabled: bool = false  # Tracks whether the widget is disabled


@export var mytextedit: TextEdit
@export var myplaceholdertext: String = "drop your data here"
@export var button: Button = null


func _ready():
	mytextedit.placeholder_text = myplaceholdertext


# This function should return true if the dragged data can be dropped here
func _can_drop_data(_newpos, data) -> bool:
	if is_disabled:  # Check if the widget is disabled
		return false
	if can_drop_function and can_drop_function.is_valid():
		return can_drop_function.call(data)
	return false  # Default to false if no valid callable is set


# This function handles the data being dropped
func _drop_data(newpos, data) -> void:
	if _can_drop_data(newpos, data):
		_handle_item_drop(data, newpos)


# Called when the user has successfully dropped data onto the TextEdit
func _handle_item_drop(dropped_data, _newpos) -> void:
	if drop_function and drop_function.is_valid():
		drop_function.call(dropped_data)


func _on_button_button_up():
	mytextedit.clear()


func set_text(newtext: String):
	mytextedit.text = newtext


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
