class_name DStats
extends RefCounted

# There's a D in front of the class name to indicate this class only handles stats data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of stats. You can access it through Gamedata.mods.by_id("Core").stats

# Paths for stats data and sprites
var dataPath: String = "./Mods/Core/Stats/Stats.json"
var spritePath: String = "./Mods/Core/Stats/"
var statdict: Dictionary = {}
var sprites: Dictionary = {}

# Add a mod_id parameter to dynamically initialize paths
func _init(mod_id: String) -> void:
	# Update dataPath and spritePath using the provided mod_id
	dataPath = "./Mods/" + mod_id + "/Stats/Stats.json"
	spritePath = "./Mods/" + mod_id + "/Stats/"
	
	# Load stats and sprites
	load_sprites()
	load_stats_from_disk()


# Load all stats data from disk into memory
func load_stats_from_disk() -> void:
	var statslist: Array = Helper.json_helper.load_json_array_file(dataPath)
	for mystat in statslist:
		var stat: DStat = DStat.new(mystat, self)
		if stat.spriteid:
			stat.sprite = sprites[stat.spriteid]
		statdict[stat.id] = stat

# Loads sprites and assigns them to the proper dictionary
func load_sprites() -> void:
	var png_files: Array = Helper.json_helper.file_names_in_dir(spritePath, ["png"])
	for png_file in png_files:
		# Load the .png file as a texture
		var texture := load(spritePath + png_file)
		# Add the material to the dictionary
		sprites[png_file] = texture

# Called when data changes and needs to be saved
func on_data_changed():
	save_stats_to_disk()

# Saves all stats to disk
func save_stats_to_disk() -> void:
	var save_data: Array = []
	for stat in statdict.values():
		save_data.append(stat.get_data())
	Helper.json_helper.write_json_file(dataPath, JSON.stringify(save_data, "\t"))

# Returns the dictionary containing all stats
func get_all() -> Dictionary:
	return statdict

# Duplicates a stat and saves it to disk with a new ID
func duplicate_to_disk(statid: String, newstatid: String) -> void:
	var statdata: Dictionary = by_id(statid).get_data().duplicate(true)
	# A duplicated stat is brand new and can't already be referenced by something
	# So we delete the references from the duplicated data if it is present
	statdata.erase("references")
	statdata.id = newstatid
	var newstat: DStat = DStat.new(statdata, self)
	statdict[newstatid] = newstat
	save_stats_to_disk()

# Adds a new stat with a given ID
func add_new(newid: String) -> void:
	var newstat: DStat = DStat.new({"id": newid}, self)
	statdict[newstat.id] = newstat
	save_stats_to_disk()

# Deletes a stat by its ID and saves changes to disk
func delete_by_id(statid: String) -> void:
	statdict[statid].delete()
	statdict.erase(statid)
	save_stats_to_disk()

# Returns a stat by its ID
func by_id(statid: String) -> DStat:
	return statdict[statid]

# Checks if a stat exists by its ID
func has_id(statid: String) -> bool:
	return statdict.has(statid)

# Returns the sprite of the stat
func sprite_by_id(statid: String) -> Texture:
	return statdict[statid].sprite

# Returns the sprite by its file name
func sprite_by_file(spritefile: String) -> Texture:
	return sprites[spritefile]

# Removes a reference from the selected stat
func remove_reference(statid: String, module: String, type: String, refid: String):
	var mystat: DStat = statdict[statid]
	mystat.remove_reference(module, type, refid)

# Adds a reference to the references list in the stat
func add_reference(statid: String, module: String, type: String, refid: String):
	var mystat: DStat = statdict[statid]
	mystat.add_reference(module, type, refid)

# Helper function to update references if they have changed
func update_reference(old: String, new: String, type: String, refid: String) -> void:
	if old == new:
		return  # No change detected, exit early

	# Remove from old group if necessary
	if old != "":
		remove_reference(old, "core", type, refid)
	if new != "":
		add_reference(new, "core", type, refid)
