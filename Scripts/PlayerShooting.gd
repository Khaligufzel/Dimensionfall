extends Node3D

var weapon
var magazine
var ammo

var current_ammo : int
var max_ammo : int

signal ammo_changed

@export var projectiles: NodePath
@export var bullet_speed: float
@export var bullet_damage: float
#@export var cooldown = 0.25
@export var bullet_scene: PackedScene

@export var bullet_line_scene: PackedScene

@export var attack_cooldown : Timer
@export var reload_timer : Timer

@export var player: NodePath
@export var hud: NodePath

@export var shoot_audio_player : AudioStreamPlayer3D
@export var shoot_audio_randomizer : AudioStreamRandomizer

@export var reload_audio_player : AudioStreamPlayer3D
#@export var reload_audio_randomizer : AudioStreamRandomizer

var damage = 25


func _input(event):
	if not weapon:
		return  # Return early if no weapon is equipped
	
	if event.is_action_pressed("reload_weapon"):
		reload_timer.start()
		get_node(hud).start_progress_bar(reload_timer.time_left)
	
	
	if event.is_action_pressed("click") && General.is_mouse_outside_HUD && General.is_allowed_to_shoot:

#		var space_state = get_world_2d().direct_space_state
#		var query = PhysicsRayQueryParameters2D.create(global_position, global_position + (get_global_mouse_position() - global_position).normalized() * 10000 , pow(2, 1-1) + pow(2, 2-1) + pow(2, 3-1),[self])
#
#		var result = space_state.intersect_ray(query)
#
#		if result:
#			print("hit")
#			var line = bullet_line_scene.instantiate()
#			get_node(projectiles).add_child(line)
#			line.add_point(global_position)
#			line.add_point(result.position)
#
#			if result.collider.has_method("_get_hit"):
#				result.collider._get_hit(damage)
		if attack_cooldown.is_stopped() && current_ammo > 0 && reload_timer.is_stopped():
			attack_cooldown.start()
			current_ammo -= 1
			ammo_changed.emit(current_ammo, max_ammo)
			shoot_audio_player.stream = shoot_audio_randomizer
			shoot_audio_player.play()
			
			var space_state = get_world_3d().direct_space_state
			var mouse_pos : Vector2 = get_viewport().get_mouse_position()
			
#			var dropPlane  = Plane(Vector3(0, 0, 1), 1)
#			var position3D = dropPlane.intersects_ray(
#							 get_tree().get_first_node_in_group("Camera").project_ray_origin(mouse_pos),
#							 get_tree().get_first_node_in_group("Camera").project_ray_normal(mouse_pos))
			
#			var query = PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3(mouse_pos.x - global_position.x, 0, mouse_pos.y - global_position.z).normalized() * 10000 , pow(2, 1-1) + pow(2, 2-1) + pow(2, 3-1),[self])
			#var query = PhysicsRayQueryParameters3D.create(global_position, global_position + (position3D - global_position).normalized() * 10000 , pow(2, 1-1) + pow(2, 2-1) + pow(2, 3-1),[self])
			var layer = pow(2, 1-1) + pow(2, 2-1) + pow(2, 3-1)
			var mouse_pos_in_world = Helper.raycast_from_mouse(mouse_pos, layer).position
			var query = PhysicsRayQueryParameters3D.create(global_position, global_position + (Vector3(mouse_pos_in_world.x - global_position.x, 0, mouse_pos_in_world.z - global_position.z)).normalized() * 10000, layer, [self])

			var result = space_state.intersect_ray(query)
			
			if result:
				print("hit")
#				var line = bullet_line_scene.instantiate()
#				get_node(projectiles).add_child(line)
#				line.add_point(global_position)
#				line.add_point(result.position)
				Helper.line(global_position, result.position)
				
				if result.collider.has_method("_get_hit"):
					result.collider._get_hit(damage)
					





#		var bullet = bullet_scene.instantiate()
#		bullet.speed = bullet_speed
#		bullet.damage = bullet_damage
#		get_node(projectiles).add_child(bullet)
#		bullet.global_position = global_position
#		#bullet.rotation = (get_global_mouse_position() - global_position).normalized()
#		bullet.direction = (get_global_mouse_position() - global_position).normalized()

# Called when the node enters the scene tree for the first time.
func _ready():
	# Initialize without assigning a default weapon, magazine, or ammo.
	weapon = null
	magazine = null
	ammo = null
	current_ammo = 0
	max_ammo = 0
	#weapon = Gamedata.get_data_by_id(Gamedata.data.items, "pistol_9mm")
	#magazine = Gamedata.get_data_by_id(Gamedata.data.items, "pistol_magazine")
	#ammo = Gamedata.get_data_by_id(Gamedata.data.items, "bullet_9mm")
	#
	#max_ammo = int(magazine.Magazine["max_ammo"])
	#current_ammo = max_ammo
	#
	#ammo_changed.emit(current_ammo, max_ammo)
	#
	#attack_cooldown.wait_time = float(weapon.Ranged["firing_speed"])
	#reload_timer.wait_time = float(weapon.Ranged["reload_speed"])
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	
	# Reloading sound logic, basically we want to play the sound during the reloading phase,
	# not before or after reloading so the end of reloading sounds will align with end of the reloading phase
	if reload_timer.time_left <= reload_audio_player.stream.get_length() && !reload_audio_player.playing && !reload_timer.is_stopped():
		reload_audio_player.play()


func _on_reload_time_timeout():
	if weapon:
		current_ammo = max_ammo
		ammo_changed.emit(current_ammo, max_ammo)


# The player has equipped an item in one of the equipmentslots
# equippedItem is an InventoryItem
# slotName is a string, for example "LeftHand" or "RightHand"
func _on_hud_item_was_equipped(equippedItem: InventoryItem, slotName: String):
	var weaponID = equippedItem.prototype_id
	var weaponData = Gamedata.get_data_by_id(Gamedata.data.items, weaponID)
	if weaponData.has("Ranged"):
		weapon = weaponData
		var twoHanded: bool = weapon.Ranged.two_handed
		var newMagazineID = weapon.Ranged.used_magazine
		var newAmmoID = weapon.Ranged.used_ammo
		magazine = Gamedata.get_data_by_id(Gamedata.data.items, newMagazineID)
		ammo = Gamedata.get_data_by_id(Gamedata.data.items, newAmmoID)
		
		max_ammo = int(magazine.Magazine["max_ammo"])
		current_ammo = max_ammo
		
		attack_cooldown.wait_time = float(weapon.Ranged["firing_speed"])
		reload_timer.wait_time = float(weapon.Ranged["reload_speed"])
		ammo_changed.emit(current_ammo, max_ammo)
	else:
		# Reset weapon, magazine, and ammo if the equipped item is not a weapon
		weapon = null
		magazine = null
		ammo = null
		current_ammo = 0
		max_ammo = 0
