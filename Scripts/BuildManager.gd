extends Node3D

@export var construction_ghost: MeshInstance3D
var is_building = false
var construction_type: String = "block"
var construction_choice: String = ""

@export var LevelGenerator: Node3D
@export var hud: NodePath

func _ready():
	# Connect the build menu visibility_changed signal to a local method
	Helper.signal_broker.build_window_visibility_changed.connect(_on_build_menu_visibility_change)
	Helper.signal_broker.construction_chosen.connect(_on_hud_construction_chosen)

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
	construction_type = ""
	construction_choice = ""

# When the user selects an option in the BuildingMenu.tscn scene
# type: One of "block" or "furniture". Choice: can be "concrete_wall" or some furniture id
func _on_hud_construction_chosen(type: String, choice: String):
	construction_type = type
	construction_choice = choice
	update_construction_ghost_material()  # Update the ghost material based on the new selection
	start_building()


func start_building():
	is_building = true
	General.is_allowed_to_shoot = false


# Connects from the ConstructionGhost.gd script. 
# Example construction data: {"pos": global_transform.origin}
func on_construction_clicked(construction_data: Dictionary):
	# Ensure construction_type and construction_choice are set
	if construction_type == "" or construction_choice == "":
		print_debug("Construction type or choice is not set. Aborting.")
		return

	var chunk: Chunk = LevelGenerator.get_chunk_from_position(construction_data.pos)
	if not chunk:
		return

	# Handle block construction
	if construction_type == "block":
		var numberofplanks: int = ItemManager.get_accessibleitem_amount("plank_2x4")
		if numberofplanks < 2:
			print_debug("Tried to construct, but not enough planks")
			return
		
		if not ItemManager.remove_resource("plank_2x4", 2, ItemManager.allAccessibleItems):
			return

		var local_position = calculate_local_position(construction_data.pos, chunk.position)
		chunk.add_block("concrete_00", local_position)
		print_debug("Block placed at local position: ", local_position, " in chunk at ", chunk.position, " with type ", construction_data.id)

	# Handle furniture construction
	elif construction_type == "furniture":
		construction_data.pos.y -= 1
		chunk.spawn_furniture({"json": {"id": construction_choice, "rotation": 0}, "pos": construction_data.pos})
		print_debug("Furniture construction chosen. Type: ", construction_type, ", Choice: ", construction_choice, ", construction_data.pos: ", str(construction_data.pos))

	# Handle unknown construction types
	else:
		print_debug("Unknown construction type: ", construction_type)


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


# Updates the material of the construction ghost based on the construction type and choice
func update_construction_ghost_material():
	if construction_type == "block":
		# Reset to the default material for blocks
		construction_ghost.reset_material_to_default()
	elif construction_type == "furniture":
		# Get the RFurniture instance by its ID
		var rfurniture: RFurniture = Runtimedata.furnitures.by_id(construction_choice)
		if rfurniture:
			# Retrieve the sprite material and set it to the construction ghost
			var furniture_sprite_material = Runtimedata.furnitures.get_shader_material_by_id(construction_choice)
			construction_ghost.set_material(furniture_sprite_material)
		else:
			print_debug("RFurniture with ID ", construction_choice, " not found. Resetting material.")
			construction_ghost.reset_material_to_default()
	else:
		# Handle unknown construction types by resetting to the default material
		print_debug("Unknown construction type: ", construction_type, ". Resetting material.")
		construction_ghost.reset_material_to_default()
