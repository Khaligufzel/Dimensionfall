class_name ContainerItem
extends Node3D

# This is a standalone class that you can use to make a container of a 3d node
# For example, adding this as a child to furniture will allow the player to add and remove
# items from it when it's in proximity


var inventory: InventoryStacked
var containerpos: Vector3
var sprite_3d: Sprite3D
var texture_id: String # The ID of the texture set for this container
var itemgroup: String # The ID of an itemgroup that it creates loot from
var ditemgroup: DItemgroup # The ID of an itemgroup that it creates loot from


# Called when the node enters the scene tree for the first time.
func _ready():
	position = containerpos
	 # If no item was added we delete the container if it's not a child of some furniture
	_on_item_removed(null)
	if texture_id:
		set_texture(texture_id)


# Called when a function creates this class using ContainerItem.new(container_json)
# Basic setup for this container. Should be called before adding it to the scene tree
func _init(item: Dictionary):
	_initialize_container(item)
	create_loot()


func _initialize_container(item: Dictionary):
	containerpos = Vector3(item.global_position_x, item.global_position_y, item.global_position_z)
	add_to_group("Containers")
	_create_inventory()
	_create_area3d()

	if item.has("inventory"):
		deserialize_and_apply_items.call_deferred(item.inventory)
	# texture_id may be set when a furniture is destroyed and spawns this container
	if item.has("texture_id"):
		texture_id = item.texture_id
	create_sprite()

	# Check if the item has itemgroups, pick one at random and set the itemgroup property
	if item.has("itemgroups"):
		var itemgroups_array: Array = item.itemgroups
		if itemgroups_array.size() > 0:
			itemgroup = itemgroups_array.pick_random()
			# Attempt to retrieve the itemgroup data from Gamedata
			ditemgroup = Gamedata.itemgroups.by_id(itemgroup)
			if ditemgroup.use_sprite:
				texture_id = ditemgroup.spriteid


# Will add item to the inventory based on the assigned itemgroup
# Only new furniture will have an itemgroup assigned, not previously saved furniture.
func create_loot():
	if not itemgroup or itemgroup == "":
		return
	# A flag to track whether items were added
	var item_added: bool = false
	
	# Check if the itemgroup data exists and has items
	if ditemgroup:
		var groupmode: String = ditemgroup.mode # can be "Collection" or "Distribution".
		if groupmode == "Collection":
			item_added = _add_items_to_inventory_collection_mode(ditemgroup.items)
		elif groupmode == "Distribution":
			item_added = _add_items_to_inventory_distribution_mode(ditemgroup.items)

	# Set the texture if an item was successfully added and if it hasn't been set by set_texture
	if item_added and sprite_3d.texture == Gamedata.textures.container and not ditemgroup.use_sprite:
		set_random_inventory_item_texture()
	elif not item_added:
		 # If no item was added we delete the container if it's not a child of some furniture
		_on_item_removed(null)


# Takes a list of items and adds them to the inventory in Collection mode.
func _add_items_to_inventory_collection_mode(items: Array[DItemgroup.Item]) -> bool:
	var item_added: bool = false
	# Loop over each item object in the itemgroup's 'items' property
	for item_object: DItemgroup.Item in items:
		# Each item_object is expected to be a dictionary with id, probability, min, max
		var item_id = item_object.id
		var item_probability = item_object.probability
		if randi_range(0, 100) <= item_probability:
			item_added = true # An item is about to be added
			# Determine quantity to add based on min and max
			var quantity = randi_range(item_object.minc, item_object.maxc)
			_add_item_to_inventory(item_id, quantity)
	return item_added


# Takes a list of items and adds one to the inventory based on probabilities in Distribution mode.
func _add_items_to_inventory_distribution_mode(items: Array[DItemgroup.Item]) -> bool:
	var total_probability = 0
	# Calculate the total probability
	for item_object in items:
		total_probability += item_object.probability

	# Generate a random value between 0 and total_probability - 1
	var random_value = randi_range(0, total_probability - 1)
	var cumulative_probability = 0

	# Iterate through items to select one based on the random value
	for item_object: DItemgroup.Item in items:
		cumulative_probability += item_object.probability
		# Check if the random value falls within the current item's range
		if random_value < cumulative_probability:
			var item_id = item_object.id
			var quantity = randi_range(item_object.minc, item_object.maxc)
			_add_item_to_inventory(item_id, quantity)
			return true  # One item is added, return immediately

	return false  # In case no item is added, though this is highly unlikely


# Takes an item_id and quantity and adds it to the inventory
func _add_item_to_inventory(item_id: String, quantity: int):
	# Fetch the individual item data for verification
	var ditem: DItem = Gamedata.items.by_id(item_id)
	# Check if the item data is valid before adding
	if ditem and quantity > 0:
		while quantity > 0:
			# Calculate the stack size for this iteration, limited by max_stack_size
			var stack_size = min(quantity, ditem.max_stack_size)
			# Create and add the item to the inventory
			var item = inventory.create_and_add_item(item_id)
			# Set the item stack size
			InventoryStacked.set_item_stack_size(item, stack_size)
			# Decrease the remaining quantity
			quantity -= stack_size


# Function to deserialize inventory and apply the correct sprite
func deserialize_and_apply_items(items_data: Dictionary):
	inventory.deserialize(items_data)
	
	var default_texture: Texture = Gamedata.textures.container
	
	if inventory.get_items().size() > 0:
		if sprite_3d.texture == default_texture:
			sprite_3d.texture = Gamedata.textures.container_filled
		# Else, some other texture has been set so we keep that
	else:
		sprite_3d.texture = default_texture
		_on_item_removed(null)


# Creates a new InventoryStacked to hold items in it
func _create_inventory():
	inventory = InventoryStacked.new()
	inventory.capacity = 1000
	inventory.item_protoset = ItemManager.item_protosets
	add_child.call_deferred(inventory)
	inventory.item_removed.connect(_on_item_removed)
	inventory.item_added.connect(_on_item_added)


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
	set_texture(texture_id)
	#sprite_3d.texture = Gamedata.textures.container

	# Add to the scene tree
	add_child.call_deferred(sprite_3d)


# Updates the texture of this container. If no texture is provided, we use the default
func set_texture(mytex: String):
	if not mytex:
		sprite_3d.texture = Gamedata.textures.container
		return
	var newsprite: Texture = Gamedata.furnitures.sprite_by_file(mytex)
	if newsprite:
		sprite_3d.texture = newsprite
		texture_id = mytex  # Save the texture ID
	else:
		newsprite = Gamedata.items.sprite_by_file(mytex)
		if newsprite:
			sprite_3d.texture = newsprite
			texture_id = mytex  # Save the texture ID
		else:
			sprite_3d.texture = Gamedata.textures.container


# This area will be used to check if the player can reach into the inventory with ItemDetector
func _create_area3d():
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
		return Gamedata.textures.container


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
	else: # There are still items in the container
		if is_inside_tree():
			set_random_inventory_item_texture() # Update to a new sprite


func _on_item_added(_item: InventoryItem):
	# Check if this ContainerItem is a direct child of the tree root
	if is_inside_tree() and not get_parent() == get_tree().get_root():
		set_random_inventory_item_texture() # Update to a new sprite


func add_item(item_id: String):
	inventory.create_and_add_item.call_deferred(item_id)


func insert_item(item: InventoryItem) -> bool:
	var iteminv: InventoryStacked = item.get_inventory()
	if iteminv == inventory:
		return false # Can't insert into itself
	if not iteminv.transfer_autosplitmerge(item, inventory):
		print_debug("Failed to transfer item: " + str(item))
	return true


# Saves the data for this container to a JSON dictionary, 
# intended to be saved to disk
func get_data() -> Dictionary:
	var newitemData: Dictionary = {
		"global_position_x": containerpos.x, 
		"global_position_y": containerpos.y, 
		"global_position_z": containerpos.z, 
		"inventory": inventory.serialize()
	}
	if texture_id:
		newitemData["texture_id"] = texture_id
	
	return newitemData


# Sets the sprite_3d texture to a texture of a random item in the container's inventory
func set_random_inventory_item_texture():
	var items: Array = inventory.get_items()
	if items.size() == 0:
		return
	
	# Pick a random item from the inventory
	var random_item = items.pick_random()
	var item_id = random_item.prototype_id
	
	# Set the sprite_3d texture to the item's sprite
	sprite_3d.texture = Gamedata.items.sprite_by_id(item_id)


# Properly destroys the container and its associated resources
func destroy():
	Helper.signal_broker.container_exited_proximity.emit(self)
	# Disconnect signals to avoid issues during cleanup
	if inventory:
		inventory.item_removed.disconnect(_on_item_removed)
		inventory.item_added.disconnect(_on_item_added)

	# Free the inventory resource
	if inventory:
		inventory.queue_free()
		inventory = null

	# Free the sprite resource
	if sprite_3d:
		sprite_3d.queue_free()
		sprite_3d = null

	# Free the node itself
	queue_free()
