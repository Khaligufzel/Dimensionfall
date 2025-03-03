extends Control

# This scene is intended to be used inside the item editor
# It is supposed to edit exactly one tool


# Form elements
@export var flashlight_number: SpinBox = null


var ditem: DItem = null:
	set(value):
		if not value:
			return
		ditem = value
		load_properties()


func save_properties() -> void:
	# Ensure tool_qualities exists
	if not ditem.tool:
		print_debug("ditem.tool is null, cannot save tool qualities.")
		return

	# Save the flashlight number into tool_qualities as {"flashlight": value}
	ditem.tool.tool_qualities["flashlight"] = int(flashlight_number.value)


func load_properties() -> void:
	if not ditem.tool:
		print_debug("ditem.tool is null, skipping property loading.")
		return
	
	# Load the flashlight number from tool_qualities, defaulting to 1 if not set
	flashlight_number.value = ditem.tool.tool_qualities.get("flashlight", 1)
