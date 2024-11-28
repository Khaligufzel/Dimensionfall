extends CanvasLayer

@export var stamina_HUD: NodePath
@export var clock_label: Label = null


@export var ammo_HUD_left: NodePath
@export var ammo_HUD_right: NodePath

@export var healthy_color: Color
@export var damaged_color: Color

# This window shows the inventory to the player
@export var inventoryWindow : Control
@export var characterWindow : Control
@export var questWindow : Control

@export var building_menu: NodePath
@export var crafting_menu : NodePath
@export var overmap: Control

var is_building_menu_open = false


@export var progress_bar : NodePath
@export var progress_bar_filling : NodePath
@export var progress_bar_timer : NodePath
var progress_bar_timer_max_time : float

var is_progress_bar_well_progressing_i_guess = false

signal construction_chosen



@export var item_protoset : ItemProtoset

func test():
	print("TESTING 123 123!")
	
func _process(_delta):
	if is_progress_bar_well_progressing_i_guess:
		update_progress_bar()

func _ready():
	# If some node wants to start a progressbar, they will emit a signal trough the broker
	Helper.signal_broker.hud_start_progressbar.connect(start_progress_bar)
	# We let the signal broker forward the change in visibility so other nodes can respond
	var buildmenu = get_node(building_menu)
	buildmenu.visibility_changed.connect(\
	Helper.signal_broker.on_build_menu_visibility_changed.bind(buildmenu))
	Helper.time_helper.minute_passed.connect(_on_minute_passed)


func update_progress_bar():
	var progressBarNode = get_node(progress_bar_filling)
	var timerNode = get_node(progress_bar_timer)
	progressBarNode.scale.x = lerp(1, 0, timerNode.time_left / progress_bar_timer_max_time)

func _input(event):
	if event.is_action_pressed("build_menu"):
		print("Build menu")
		if is_building_menu_open:
			is_building_menu_open = false
			get_node(building_menu).set_visible(false)
		else:
			is_building_menu_open = true
			get_node(building_menu).set_visible(true)
			
	if event.is_action_pressed("toggle_inventory"):
		inventoryWindow.visible = !inventoryWindow.visible
			
	if event.is_action_pressed("character_menu"):
		characterWindow.visible = !characterWindow.visible
			
	if event.is_action_pressed("quest_menu"):
		questWindow.visible = !questWindow.visible

	if event.is_action_pressed("crafting_menu"):
		get_node(crafting_menu).visible = !get_node(crafting_menu).visible
	if event.is_action_pressed("overmap"):
		if overmap.visible:
			overmap.hide()
		else:
			overmap.show()

	if is_progress_bar_well_progressing_i_guess:
		get_node(progress_bar_filling).scale.x = lerp(1, 0, get_node(progress_bar_timer).time_left / progress_bar_timer_max_time)


func _on_player_update_stamina_hud(stamina):
	get_node(stamina_HUD).text = str(round(stamina)) + "%"


func _on_concrete_button_down():
	construction_chosen.emit("concrete_wall")


func start_progress_bar(time : float):
	get_node(progress_bar).visible = true
	get_node(progress_bar_timer).wait_time = time
	get_node(progress_bar_timer).start()
	get_node(progress_bar_filling).scale.x = 0
	progress_bar_timer_max_time = time
	is_progress_bar_well_progressing_i_guess = true


func interrupt_progress_bar():
	get_node(progress_bar).visible = false
	is_progress_bar_well_progressing_i_guess = false


func _on_progress_bar_timer_timeout():
	interrupt_progress_bar()


func _on_shooting_ammo_changed(current_ammo: int, max_ammo: int, leftHand:bool):
	var ammo_HUD: Label = get_node(ammo_HUD_left)
	var prefix: String = "L: "
	if !leftHand:
		ammo_HUD = get_node(ammo_HUD_right)
		prefix = "R: "
	if current_ammo == -1 and max_ammo == -1:  # Assuming -1 is the value when no weapon is equipped
		ammo_HUD.hide()
	else:
		ammo_HUD.text = prefix + str(current_ammo) + "/" + str(max_ammo)
		ammo_HUD.show()


# The parameter container the inventory that has entered proximity
func _on_item_detector_add_to_proximity_inventory(container):
	inventoryWindow._on_item_detector_add_to_proximity_inventory(container)


# The parameter container the inventory that has left proximity
func _on_item_detector_remove_from_proximity_inventory(container):
	inventoryWindow._on_item_detector_remove_from_proximity_inventory(container)


func _on_minute_passed(current_time: String):
	clock_label.text = current_time  # Update the clock label
