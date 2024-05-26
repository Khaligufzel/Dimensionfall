class_name ContainerItem
extends Node3D

# This is a standalone class that you can use to make a container of a 3d node
# For example, adding this as a child to furniture will allow the player to add and remove
# items from it when it's in proximity


var inventory: InventoryStacked
var containerpos: Vector3
var sprite_3d: Sprite3D
var itemgroup: String # The ID of an itemgroup that it creates loot from


# Called when the node enters the scene tree for the first time.
func _ready():
	position = containerpos
	create_loot()


# Will add item to the inventory based on the assigned itemgroup
# Only new furniture will have an itemgroup assigned, not previously saved furniture.
func create_loot():
	# A flag to track whether items were added
	var item_added: bool = false
	# Attempt to retrieve the itemgroup data from Gamedata
	var itemgroup_data = Gamedata.get_data_by_id(Gamedata.data.itemgroups, itemgroup)
	
	# Check if the itemgroup data exists and has items
	if itemgroup_data and "items" in itemgroup_data:
		# Loop over each item object in the itemgroup's 'items' property
		for item_object in itemgroup_data["items"]:
			# Each item_object is expected to be a dictionary with id, probability, min, max
			var item_id = item_object["id"]
			var item_min = item_object["min"]
			var item_max = item_object["max"]
			var item_probability = item_object["probability"]  # This could be used for determining spawn chance

			# Fetch the individual item data for verification
			var item_data = Gamedata.get_data_by_id(Gamedata.data.items, item_id)
			
			# Check if the item data is valid before adding
			if item_data and not item_data.is_empty():
				# Check probability to decide if item should be added
				if randi_range(0, 100) <= item_probability:
					item_added = true # An item is about to be added
					# Determine quantity to add based on min and max
					var quantity = randi_range(item_min, item_max)
					for i in range(quantity):
						# Create and add the item to the inventory
						inventory.create_and_add_item.call_deferred(item_id)
			else:
				print_debug("No valid data found for item ID: " + str(item_id))
	else:
		# Fallback if no valid itemgroup data found or the itemgroup is empty
		print_debug("Invalid or empty itemgroup data for itemgroup ID: " + str(itemgroup))

	# Set the texture if an item was successfully added and if it hasn't been set by set_texture
	if item_added and sprite_3d.texture == load("res://Textures/container_32.png"):
		sprite_3d.texture = load("res://Textures/container_filled_32.png")
	elif not item_added:
		 # If no item was added we delete the container if it's not a child of some furniture
		_on_item_removed(null)


# Creates a new InventoryStacked to hold items in it
func create_inventory():
	inventory = InventoryStacked.new()
	inventory.capacity = 1000
	inventory.item_protoset = load("res://ItemProtosets.tres")
	add_child.call_deferred(inventory)
	inventory.item_removed.connect(_on_item_removed)
	inventory.item_added.connect(_on_item_added)


# Basic setup for this container. Should be called before adding it to the scene tree
func construct_self(containerPos: Vector3):
	containerpos = containerPos
	add_to_group("Containers")
	create_inventory()
	create_sprite()
	create_area3d()


# Creates the sprite with some default properties
# These properties were copied from when the sprite was an actual node in the editor
func create_sprite():
	sprite_3d = Sprite3D.new()

	# Set the properties
	sprite_3d.centered = true
	sprite_3d.offset = Vector2(0, 0)
	sprite_3d.flip_h = false
	sprite_3d.flip_v = false
	sprite_3d.pixel_size = 0.01
	sprite_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite_3d.transparent = true
	sprite_3d.shaded = true
	sprite_3d.double_sided = true
	sprite_3d.no_depth_test = false
	sprite_3d.fixed_size = false
	sprite_3d.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite_3d.alpha_scissor_threshold = 0.5
	sprite_3d.alpha_hash_scale = 1
	sprite_3d.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_OFF
	sprite_3d.alpha_antialiasing_edge = 0
	sprite_3d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite_3d.render_priority = 10
	sprite_3d.texture = load("res://Textures/container_32.png")

	# Add to the scene tree
	add_child.call_deferred(sprite_3d)


# Updates the texture of this container. If no texture is provided, we use the default
func set_texture(mytex: String):
	var newsprite: Texture = Gamedata.data.furniture.sprites[mytex]
	if newsprite:
		sprite_3d.texture = newsprite
	else:
		sprite_3d.texture = load("res://Textures/container_32.png")


# This area will be used to check if the player can reach into the inventory with ItemDetector
func create_area3d():
	var area3d = Area3D.new()
	add_child(area3d)
	area3d.collision_layer = 1 << 6  # Set to layer 7
	area3d.collision_mask = 1 << 6   # Set mask to layer 7
	area3d.owner = self
	var collisionshape3d = CollisionShape3D.new()
	var sphereshape3d = SphereShape3D.new()
	sphereshape3d.radius = 0.2
	collisionshape3d.shape = sphereshape3d
	area3d.add_child.call_deferred(collisionshape3d)


# Returns an array of InventoryItems that are in the InventoryStacked
func get_items():
	return inventory.get_children()


# Returns a list of prototype id's from the inventory items
func get_item_ids() -> Array[String]:
	var returnarray: Array[String] = []
	for item: InventoryItem in inventory.get_items():
		var id = item.prototype_id
		returnarray.append(id)
	return returnarray


# Returns the sprite that represents this containeritem
func get_sprite():
	# If this is an orphan we return the sprite of the container
	if is_inside_tree() and get_parent() == get_tree().get_root():
		return sprite_3d.texture
	else:
		# The parent is probably a furniture so return that
		return get_parent().get_sprite()


# Returns the inventorystacked that this container holds
func get_inventory() -> InventoryStacked:
	return inventory


# Signal handler for item removed
# We don't want empty containers on the map, but we do want them as children of furniture
# So we delete empty containers if they are a child of the tree root.
func _on_item_removed(_item: InventoryItem):
	# Check if there are any items left in the inventory
	if inventory.get_items().size() == 0:
		if is_inside_tree():
			# Check if this ContainerItem is a direct child of the tree root
			if get_parent() == get_tree().get_root():
				Helper.signal_broker.container_exited_proximity.emit(self)
				queue_free.call_deferred()
			else:
				# It's a child of some node, probably furniture
				sprite_3d.texture = load("res://Textures/container_32.png")


func _on_item_added(_item: InventoryItem):
	# Check if this ContainerItem is a direct child of the tree root
	if is_inside_tree() and not get_parent() == get_tree().get_root():
		sprite_3d.texture = load("res://Textures/container_filled_32.png")


func add_item(item_id: String):
	inventory.create_and_add_item.call_deferred(item_id)


func insert_item(item: InventoryItem) -> bool:
	if not item.get_inventory().transfer_autosplitmerge(item, inventory):
		print_debug("Failed to transfer item: " + str(item))
	return true
