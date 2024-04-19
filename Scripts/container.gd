class_name ContainerItem
extends Node3D

# This is a standalone class that you can use to make a container of a 3d node
# For example, adding this a child to furniture will allow the player to add and remove
# items from it when it's in proximity


var inventory: InventoryStacked
var containerpos: Vector3
var sprite_3d: Sprite3D


# Called when the node enters the scene tree for the first time.
func _ready():
	position = containerpos
	create_random_loot()


func create_random_loot():
	if inventory.get_children() == []:
		inventory.create_and_add_item.call_deferred("plank_2x4")
		inventory.create_and_add_item.call_deferred("bullet_9mm")
		inventory.create_and_add_item.call_deferred("pistol_magazine")
		inventory.create_and_add_item.call_deferred("steel_scrap")


func create_inventory():
	inventory = InventoryStacked.new()
	inventory.capacity = 1000
	inventory.item_protoset = load("res://ItemProtosets.tres")
	add_child.call_deferred(inventory)


func construct_self(containerPos: Vector3):
	containerpos = containerPos
	add_to_group("Containers")
	create_inventory()
	create_sprite()
	create_area3d()


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
	sprite_3d.shaded = false
	sprite_3d.double_sided = true
	sprite_3d.no_depth_test = false
	sprite_3d.fixed_size = false
	sprite_3d.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite_3d.alpha_scissor_threshold = 0.5
	sprite_3d.alpha_hash_scale = 1
	sprite_3d.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_OFF
	sprite_3d.alpha_antialiasing_edge = 0
	sprite_3d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite_3d.render_priority = 0
	sprite_3d.texture = load("res://Textures/enemy.png")

	# Add to the scene tree
	add_child.call_deferred(sprite_3d)


# This area will be used to check if the player can reach into the inventory with ItemDetector
func create_area3d():
	var area3d = Area3D.new()
	add_child(area3d)
	area3d.owner = self
	var collisionshape3d = CollisionShape3D.new()
	var sphereshape3d = SphereShape3D.new()
	sphereshape3d.radius = 0.2
	collisionshape3d.shape = sphereshape3d
	area3d.add_child.call_deferred(collisionshape3d)


func get_items():
	return inventory.get_children()


func get_sprite():
	return sprite_3d.texture


func get_inventory():
	return inventory
