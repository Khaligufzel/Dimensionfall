extends RigidBody3D

var velocity = Vector3()
var damage = 10
var lifetime = 5.0
var owner_entity: Node3D = null  # Reference to the entity that fired the projectile
# The attack that will be executed when this bullet hits anything
# The default value is used for attacks from the player towards an enemy.
# If the player needs to get hit by the bullet, we will need an attack like this:
# {
# 	"attributeid": "torso_health", # The PlayerAttribute that is targeted by this attack
# 	"damage": 20, # The amount to subtract from the target attribute
# 	"knockback": 2, # The number of tiles to push the player away
# 	"mobposition": Vector3(17, 1, 219) # The global position of the mob
# }
var attack: Dictionary = {"damage":damage, "hit_chance":100}

func _ready():
	# Call a function to destroy the projectile after its lifetime expires
	set_lifetime(lifetime)

func _process(_delta):
	# Update the projectile's velocity each frame
	#set_linear_velocity(velocity)
	pass

func set_direction_and_speed(direction: Vector3, speed: float):
	velocity = direction.normalized() * speed
	# Rotate the bullet to match the direction
	rotate_bullet_to_match_direction(direction)
	set_linear_velocity(velocity)

func rotate_bullet_to_match_direction(direction: Vector3):
	# Ensure the direction vector is not zero
	if direction.length() == 0:
		return
	# Calculate the rotation needed to align the bullet's forward direction (usually -Z) with the velocity direction
	var target_rotation = Quaternion(Vector3(0, 0, -1), direction.normalized())
	# Apply the rotation to the bullet
	rotation = target_rotation.get_euler()


func set_lifetime(time: float):
	await get_tree().create_timer(time).timeout
	queue_free()  # Destroy the projectile after the timer

# The bullet has hit something
func _on_Projectile_body_entered(body: Node):
	# Ignore if the projectile hits the entity that fired it
	if body == owner_entity:
		return  # Don't collide with the shooter

	if body.has_method("get_hit"):
		body.get_hit(attack)
	queue_free()  # Destroy the projectile upon collision


func _on_body_shape_entered(_body_rid: RID, body: Node, _body_shape_index: int, _local_shape_index: int):
	if body and body == owner_entity:
		return
	queue_free()  # Destroy the projectile upon collision


# For some reason, the _on_body_shape_entered function does not trigger when the bullet collides
# with a collider that's not inside the tree, like with FurnitureStaticSrv. That's why an Area3d
# was added so it can still use the functionality it's supposed to. The Area3d listens to 
# Layer 3 and 4 which are the static and movable obstacles layers.
func _on_area_3d_body_shape_entered(body_rid: RID, _body: Node3D, _body_shape_index: int, _local_shape_index: int) -> void:
	if body_rid:
		# Used for bodies that exist outside the scene tree, like StaticFurnitureSrv
		Helper.signal_broker.bullet_hit.emit(body_rid, attack)
	queue_free()  # Destroy the projectile upon collision

# Configure the projectile collision settings.
# is_friendly: true = friendly projectile (fired by player), false = enemy projectile (fired by mobs)
# shooter: Reference to the entity that fired the projectile, used to prevent self-hits.
func configure_collision(is_friendly: bool, shooter: Node3D = null):
	owner_entity = shooter  # Store the reference to the shooter to prevent self-hits
	
	if is_friendly:
		collision_layer = 1 << 5  # Layer 6 (Friendly Projectiles)
		collision_mask = (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4)  # Can hit Layers 2, 3, 4, 5
	else:
		collision_layer = 1 << 4  # Layer 5 (Enemy Projectiles)
		collision_mask = (1 << 0) | (1 << 2) | (1 << 3) | (1 << 5)  # Can hit Layers 1, 3, 4, 6
