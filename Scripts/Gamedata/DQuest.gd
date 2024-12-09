class_name DQuest
extends RefCounted

# This class represents a quest with its properties
# Example quest data:
# {
#   "description": "This will teach you the basics of survival...",
#   "id": "starter_tutorial_00",
#   "name": "Beginnings",
#   "rewards": [
#       {
#           "amount": 10,
#           "item_id": "berries_wild"
#       }
#   ],
#   "sprite": "spear_stone_32.png",
#   "steps": [
#			{
#				"amount": 1,
#				"item": "long_stick",
#				"tip": "You can find one in the forest",
#				"type": "collect"
#			}
#			{
#				"item": "stone_spear",
#				"tip": "Press c to open the craft menu",
#				"type": "craft"
#			},
#			{
#				"amount": 2,
#				"mob": "scrapwalker",
#				"tip": "You can find them in town",
#				"type": "kill"
#			},
#			{
#				"amount": 3,
#				"mobgroup": "bandits",  # Example mobgroup kill step
#				"tip": "You can find them in the northern forest",
#				"type": "kill"
#			},
#			{
#				"map_id": "city_square",
#				"tip": "Circuit boards can often be scavenged from scrap piles or robotic enemies.",
#				"type": "enter",
#				"reveal_condition": "visited"
#			},
#   ]
# }

# Properties defined in the quest
var id: String
var name: String
var description: String
var spriteid: String
var sprite: Texture
var rewards: Array = []
var steps: Array = []
var parent: DQuests

# Constructor to initialize quest properties from a dictionary
# myparent: The list containing all quests for this mod
func _init(data: Dictionary, myparent: DQuests):
	parent = myparent
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	spriteid = data.get("sprite", "")
	rewards = data.get("rewards", [])
	steps = data.get("steps", [])

# Get data function to return a dictionary with all properties
func get_data() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"sprite": spriteid,
		"rewards": rewards,
		"steps": steps
	}

# Method to save any changes to the quest back to disk
func save_to_disk():
	parent.save_quests_to_disk()


# Handles quest deletion
func delete():
	var stepitems: Array = steps.filter(func(step): return step.has("item"))
	for collectstep in stepitems:
		Gamedata.items.remove_reference(collectstep.item, "core", "quests", id)
	var stepmobs: Array =  steps.filter(func(step): return step.has("mob"))
	for killstep in stepmobs:
		Gamedata.mods.remove_reference(DMod.ContentType.MOBS, killstep.mob, DMod.ContentType.QUESTS, id)
	var stepmobgroups: Array = steps.filter(func(step): return step.has("mobgroup"))
	for killstep in stepmobgroups:
		Gamedata.mobgroups.remove_reference(killstep.mobgroup, "core", "quests", id)
	var steprewards: Array = rewards.filter(func(reward): return reward.has("item_id"))
	for reward in steprewards: # Remove the reference to this quest from the reward item
		Gamedata.items.remove_reference(reward.item_id, "core", "quests", id)


# Handles quest changes
func changed(olddata: DQuest):
	var quest_id: String = id

	# Get items, mobs, mobgroups, and maps from the old steps
	var old_quest_items: Array = olddata.steps.filter(func(step): return step.has("item"))
	var old_quest_mobs: Array = olddata.steps.filter(func(step): return step.has("mob"))
	var old_quest_mobgroups: Array = olddata.steps.filter(func(step): return step.has("mobgroup"))
	var old_quest_maps: Array = olddata.steps.filter(func(step): return step.has("map_id"))
	var old_quest_rewards: Array = olddata.rewards.filter(func(reward): return reward.has("item_id"))

	# Get items, mobs, mobgroups, and maps from the new steps
	var new_quest_items: Array = steps.filter(func(step): return step.has("item"))
	var new_quest_mobs: Array = steps.filter(func(step): return step.has("mob"))
	var new_quest_mobgroups: Array = steps.filter(func(step): return step.has("mobgroup"))
	var new_quest_maps: Array = steps.filter(func(step): return step.has("map_id"))
	var new_quest_rewards: Array = rewards.filter(func(reward): return reward.has("item_id"))

	# Remove references for old items and rewards that are not in the new data
	for old_item in old_quest_items:
		if old_item not in new_quest_items:
			Gamedata.items.remove_reference(old_item.item, "core", "quests", quest_id)

	for old_reward in old_quest_rewards:
		if old_reward not in new_quest_rewards:
			Gamedata.items.remove_reference(old_reward.item_id, "core", "quests", quest_id)

	for old_map in old_quest_maps:
		if old_map not in new_quest_maps:
			Gamedata.mods.remove_reference(DMod.ContentType.MAPS, old_map.map_id, DMod.ContentType.QUESTS, quest_id)

	# Remove references for old mobs that are not in the new data
	for old_mob in old_quest_mobs:
		if old_mob not in new_quest_mobs:
			Gamedata.mods.remove_reference(DMod.ContentType.MOBS, old_mob.mob, DMod.ContentType.QUESTS, quest_id)

	# Remove references for old mobgroups that are not in the new data
	for old_mobgroup in old_quest_mobgroups:
		if old_mobgroup not in new_quest_mobgroups:
			Gamedata.mobgroups.remove_reference(old_mobgroup.mobgroup, "core", "quests", quest_id)

	# Add references for new items and rewards
	for new_item in new_quest_items:
		Gamedata.items.add_reference(new_item.item, "core", "quests", quest_id)

	for new_reward in new_quest_rewards:
		Gamedata.items.add_reference(new_reward.item_id, "core", "quests", quest_id)

	for new_map in new_quest_maps:
		Gamedata.mods.add_reference(DMod.ContentType.MAPS, new_map.map_id, DMod.ContentType.QUESTS, quest_id)

	# Add references for new mobs
	for new_mob in new_quest_mobs:
		Gamedata.mods.add_reference(DMod.ContentType.MOBS, new_mob.mob, DMod.ContentType.QUESTS, quest_id)

	# Add references for new mobgroups
	for new_mobgroup in new_quest_mobgroups:
		Gamedata.mobgroups.add_reference(new_mobgroup.mobgroup, "core", "quests", quest_id)

	save_to_disk()


# Removes all steps where the mob property matches the given mob_id
func remove_steps_by_mob(mob_id: String) -> void:
	steps = steps.filter(func(step): 
		return not (step.has("mob") and step.mob == mob_id)
	)
	save_to_disk()


# Removes all steps where the mobgroup property matches the given mobgroup_id
func remove_steps_by_mobgroup(mobgroup_id: String) -> void:
	steps = steps.filter(func(step): 
		return not (step.has("mobgroup") and step.mobgroup == mobgroup_id)
	)
	save_to_disk()


# Removes all steps where the item property matches the given item_id
func remove_steps_by_item(item_id: String) -> void:
	steps = steps.filter(func(step): 
		return not (step.has("item") and step.item == item_id)
	)
	save_to_disk()

# Removes all rewards where the item_id matches the given item_id
func remove_rewards_by_item(item_id: String) -> void:
	rewards = rewards.filter(func(reward): 
		return not (reward.has("item_id") and reward.item_id == item_id)
	)
	save_to_disk()
