class_name ROvermapareas
extends RefCounted

# There's an R in front of the class name to indicate this class only handles runtime overmap area data, nothing more
# This script is intended to be used inside the Runtime autoload singleton
# This script handles the list of overmap areas. You can access it through Runtime.mods.by_id("Core").overmapareas

# Dictionary to store runtime overmap areas
var overmapareadict: Dictionary = {}
var references: Dictionary = {}

# Constructor
func _init() -> void:
	# Get all mods and their IDs
	var mod_ids: Array = Gamedata.mods.get_all_mod_ids()

	# Loop through each mod to get its DOvermapareas
	for mod_id in mod_ids:
		var dovermapareas: DOvermapareas = Gamedata.mods.by_id(mod_id).overmapareas

		# Loop through each DOvermaparea in the mod
		for dovermaparea_id: String in dovermapareas.get_all().keys():
			var dovermaparea: DOvermaparea = dovermapareas.by_id(dovermaparea_id)

			# Check if the overmap area exists in overmapareadict
			var rovermaparea: ROvermaparea
			if not overmapareadict.has(dovermaparea_id):
				# If it doesn't exist, create a new ROvermaparea
				rovermaparea = add_new(dovermaparea_id)
			else:
				# If it exists, get the existing ROvermaparea
				rovermaparea = overmapareadict[dovermaparea_id]

			# Overwrite the ROvermaparea properties with the DOvermaparea properties
			rovermaparea.overwrite_from_dovermaparea(dovermaparea)

# Returns the dictionary containing all overmap areas
func get_all() -> Dictionary:
	return overmapareadict

# Adds a new overmap area with a given ID
func add_new(newid: String) -> ROvermaparea:
	var newovermaparea: ROvermaparea = ROvermaparea.new(self, newid)
	overmapareadict[newovermaparea.id] = newovermaparea
	return newovermaparea

# Deletes an overmap area by its ID
func delete_by_id(overmapareaid: String) -> void:
	overmapareadict[overmapareaid].delete()
	overmapareadict.erase(overmapareaid)

# Returns an overmap area by its ID
func by_id(overmapareaid: String) -> ROvermaparea:
	return overmapareadict[overmapareaid]

# Checks if an overmap area exists by its ID
func has_id(overmapareaid: String) -> bool:
	return overmapareadict.has(overmapareaid)

# Returns a random ROvermaparea
func get_random_area() -> ROvermaparea:
	var area_ids = overmapareadict.keys()
	if area_ids.is_empty():
		return null
	var random_id = area_ids.pick_random()
	return overmapareadict[random_id]
