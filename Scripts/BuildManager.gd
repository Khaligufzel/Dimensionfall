extends Node3D

@export var construction_ghost: MeshInstance3D
var is_building = false

@export var LevelGenerator: Node3D
@export var hud: NodePath

func _ready():
	# Connect the build menu visibility_changed signal to a local method
	Helper.signal_broker.build_window_visibility_changed.connect(_on_build_menu_visibility_change)

func _process(_delta):
	if is_building:
		construction_ghost.visible = true

func _input(event: InputEvent):
	if event.is_action_pressed("click_right") and is_building:
		cancel_building()

func cancel_building():
	is_building = false
	General.is_allowed_to_shoot = true
	construction_ghost.visible = false

func _on_hud_construction_chosen(_construction: String):
	start_building()

func start_building():
	is_building = true
	General.is_allowed_to_shoot = false

func on_construction_clicked(construction_data: Dictionary):
	var numberofplanks: int = ItemManager.get_accessibleitem_amount("plank_2x4")
	if numberofplanks < 2:
		print_debug("tried to construct, but not enough planks")
		return
		
	if not ItemManager.remove_resource("plank_2x4",2):
		return
	var chunk: Chunk = LevelGenerator.get_chunk_from_position(construction_data.pos)
	if chunk:
		var local_position = calculate_local_position(construction_data.pos, chunk.position)
		chunk.add_block(construction_data.id, local_position)
		print_debug("Block placed at local position: ", local_position, " in chunk at ", chunk.position, " with type ", construction_data.id)

func calculate_local_position(global_pos: Vector3, chunk_pos: Vector3) -> Vector3:
	# Calculate local position within the chunk
	var local_x = int(global_pos.x - chunk_pos.x) % 32
	var local_z = int(global_pos.z - chunk_pos.z) % 32
	return Vector3(local_x, global_pos.y, local_z)

func _on_build_menu_visibility_change(buildmenu):
	if !is_building:
		return
	# Update construction ghost visibility based on build menu visibility
	set_building_state(buildmenu.is_visible())

func set_building_state(visible: bool):
	construction_ghost.visible = visible
	is_building = visible
	if not visible:
		General.is_allowed_to_shoot = true
