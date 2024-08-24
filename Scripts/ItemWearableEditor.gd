extends Control

# This scene is intended to be used inside the item editor
# It is supposed to edit exactly one type of wearable

# Form elements
@export var SlotOptionButton: OptionButton = null

var ditem: DItem = null:
	set(value):
		if not value:
			return
		ditem = value
		load_properties()

func _ready():
	refresh_wearableslots_optionbutton()

# Load properties from ditem.wearable and update the UI elements
func load_properties() -> void:
	if not ditem.wearable:
		return
	if ditem.wearable.slot != "":
		update_slot_option(ditem.wearable.slot)

# Save the selected slot from the SlotOptionButton back to ditem.wearable
func save_properties() -> void:
	ditem.wearable.slot = SlotOptionButton.get_item_text(SlotOptionButton.selected)

# Refreshes the SlotOptionButton by loading slot IDs from the wearable slots data
func refresh_wearableslots_optionbutton():
	var wearableslots = Gamedata.data.wearableslots.data
	# Clear current items in the OptionButton to avoid duplicates
	SlotOptionButton.clear()

	# Loop over each wearable slot and add the id to the OptionButton
	for slot in wearableslots:
		if slot.has("id"):
			SlotOptionButton.add_item(slot["id"])

# Update the selected option in the SlotOptionButton to match the specified slot name
func update_slot_option(slotname):
	var items = SlotOptionButton.get_item_count()
	for i in range(items):
		if SlotOptionButton.get_item_text(i) == slotname:
			SlotOptionButton.selected = i
			return
