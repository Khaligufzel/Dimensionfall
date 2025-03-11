extends Node3D

# This script is supposed to work with the TargetManager node in the level_generation scene
# This script will keep track of existing mobs and factions
# Mobs can request a target from this script to follow/attack
# This ensures efficient processing of mobs and their targets
# A dictionary keeps track of what factions hate what mobs

# Dictionary with arrays of CharacterBody3D (mobs)
# Example: {"zombies": [CharacterBody3D,CharacterBody3D,CharacterBody3D]
var hates_mobs: Dictionary[String, Array]
# Dictionary with dictionaries of mob IDs (as strings)
# Example: {"zombies": {"robot_01": true}} # Mobs in the zombie faction hate robot_01
var hates_mob_ids: Dictionary[String, Dictionary]
@export var player: Player

func _ready():
	var mobfactions: Array = Runtimedata.mobfactions.get_all_mobfactions()
	for faction: RMobfaction in mobfactions:
		hates_mobs[faction.id] = []
		hates_mob_ids[faction.id] = faction.get_mobs_by_relation_type("hostile")
	# Connect to the mob_spawned signal
	Helper.signal_broker.mob_spawned.connect(_on_mob_spawned)
	Helper.signal_broker.mob_killed.connect(_on_mob_killed)


# Returns an array of CharacterBody3D instances for a given faction ID
func get_mobs_by_faction(faction_id: String) -> Array:
	if hates_mobs.has(faction_id):
		return hates_mobs[faction_id]
	return []


# When a mob is spawned, add it to every faction that hates it
func _on_mob_spawned(mob) -> void:
	var mob_id = mob.rmob.id
	for faction_id in hates_mob_ids.keys():
		if hates_mob_ids[faction_id].has(mob_id):
			# Add the mob to the hates_mobs dictionary if not already present
			if mob not in hates_mobs[faction_id]:
				hates_mobs[faction_id].append(mob)


# When a mob is killed, remove it from every faction
func _on_mob_killed(mob) -> void:
	for faction_id in hates_mobs.keys():
		if mob in hates_mobs[faction_id]:
			hates_mobs[faction_id].erase(mob)
