extends Node3D

@onready var projectiles_container : Node = $Projectiles

func _ready():
	Helper.signal_broker.projectile_spawned.connect(on_projectile_spawned)

func on_projectile_spawned(projectile: Node, instigator: RID):
	projectiles_container.add_child(projectile)
