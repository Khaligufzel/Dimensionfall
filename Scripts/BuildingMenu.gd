extends GridContainer


var is_building_menu_open = false
@export var construction_option_button: OptionButton = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	populate_optionbutton()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func populate_optionbutton():
	# Clear the existing options while preserving the first option
	construction_option_button.clear()
	construction_option_button.add_item("concrete_wall", 0)  # First option remains concrete_wall

	# Get constructable furnitures and add their IDs to the option button
	var rfurnitures: Array[RFurniture] = Runtimedata.furnitures.get_constructable_furnitures()
	for rfurniture in rfurnitures:
		construction_option_button.add_item(rfurniture.id)


func _on_construction_option_button_item_selected(_index: int) -> void:
	# Get the selected option from the OptionButton
	var selected_value = construction_option_button.get_selected_id()
	var selected_text = construction_option_button.get_item_text(selected_value)

	# Determine the type and emit the signal
	if selected_text == "concrete_wall":
		Helper.signal_broker.construction_chosen.emit("block", "concrete_wall")
	else:
		Helper.signal_broker.construction_chosen.emit("furniture", selected_text)
