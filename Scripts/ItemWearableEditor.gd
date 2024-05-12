extends Control

# This scene is intended to be used inside the item editor
# It is supposed to edit exactly one type of wearable

# Form elements
@export var SlotOptionButton: OptionButton = null


func _ready():
	refresh_wearableslots_optionbutton()


# Refreshes the SlotOptionButton by loading slot IDs from the wearable slots data
func refresh_wearableslots_optionbutton():
	var wearableslots = Gamedata.data.wearableslots.data
	# Clear current items in the OptionButton to avoid duplicates
	SlotOptionButton.clear()

	# Loop over each wearable slot and add the id to the OptionButton
	for slot in wearableslots:
		if slot.has("id"):
			SlotOptionButton.add_item(slot["id"])


func get_properties() -> Dictionary:
	return {
		"slot": SlotOptionButton.get_item_text(SlotOptionButton.selected)
	}


func set_properties(properties: Dictionary) -> void:
	if properties.has("slot"):
		update_slot_option(properties["slot"])


# Update the selected option in the SlotOptionButton to match the specified slot name
func update_slot_option(slotname):
	var items = SlotOptionButton.get_item_count()
	for i in range(items):
		if SlotOptionButton.get_item_text(i) == slotname:
			SlotOptionButton.selected = i
			return
