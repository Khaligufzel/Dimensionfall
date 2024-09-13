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
#			}
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

# Constructor to initialize quest properties from a dictionary
func _init(data: Dictionary):
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
	Gamedata.quests.save_quests_to_disk()


# Handles quest deletion
func delete():
	var stepitems: Array = steps.filter(func(step): return step.has("item"))
	for collectstep in stepitems:
		Gamedata.items.remove_reference(collectstep.item, "core", "quests", id)
	var stepmobs: Array =  steps.filter(func(step): return step.has("mob"))
	for killstep in stepmobs:
		Gamedata.mobs.remove_reference(killstep.mob, "core", "quests", id)
	var steprewards: Array = rewards.filter(func(reward): return reward.has("item_id"))
	for reward in steprewards: # Remove the reference to this quest from the reward item
		Gamedata.items.remove_reference(reward.item_id, "core", "quests", id)


# Handles quest changes
func changed(olddata: DQuest):
	var quest_id: String = id

	# Get items and mobs from the old steps
	var old_quest_items: Array = olddata.steps.filter(func(step): return step.has("item"))
	var old_quest_mobs: Array = olddata.steps.filter(func(step): return step.has("mob"))
	var old_quest_maps: Array = olddata.steps.filter(func(step): return step.has("map_id"))
	# Get rewards from the old data
	var old_quest_rewards: Array = olddata.rewards.filter(func(reward): return reward.has("item_id"))

	# Get items and mobs from the new steps
	var new_quest_items: Array = steps.filter(func(step): return step.has("item"))
	var new_quest_mobs: Array = steps.filter(func(step): return step.has("mob"))
	var new_quest_maps: Array = steps.filter(func(step): return step.has("map_id"))
	# Get rewards from the new data
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
			Gamedata.maps.remove_reference_from_map(old_map.map_id, "core", "quests", quest_id)

	# Remove references for old mobs that are not in the new data
	for old_mob in old_quest_mobs:
		if old_mob not in new_quest_mobs:
			Gamedata.mobs.remove_reference(old_mob.mob, "core", "quests", quest_id)

	# Add references for new items and rewards
	for new_item in new_quest_items:
		Gamedata.items.add_reference(new_item.item, "core", "quests", quest_id)

	for new_reward in new_quest_rewards:
		Gamedata.items.add_reference(new_reward.item_id, "core", "quests", quest_id)

	for new_map in new_quest_maps:
		Gamedata.maps.add_reference_to_map(new_map.map_id, "core", "quests", quest_id)

	# Add references for new mobs
	for new_mob in new_quest_mobs:
		Gamedata.mobs.add_reference(new_mob.mob, "core", "quests", quest_id)

	save_to_disk()

# Removes all steps where the mob property matches the given mob_id
func remove_steps_by_mob(mob_id: String) -> void:
	steps = steps.filter(func(step): 
		return not (step.has("mob") and step.mob == mob_id)
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
