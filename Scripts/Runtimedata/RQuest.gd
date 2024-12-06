class_name RQuest
extends RefCounted

# This class represents a quest with its properties
# Only used while the game is running
# Example quest data:
# {
#     "id": "starter_tutorial_00",
#     "name": "Beginnings",
#     "description": "This will teach you the basics of survival...",
#     "sprite": "spear_stone_32.png",
#     "rewards": [
#         {
#             "amount": 10,
#             "item_id": "berries_wild"
#         }
#     ],
#     "steps": [
#         {
#             "amount": 1,
#             "item": "long_stick",
#             "tip": "You can find one in the forest",
#             "type": "collect"
#         }
#     ]
# }

# Properties defined in the quest
var id: String
var name: String
var description: String
var spriteid: String
var sprite: Texture
var rewards: Array = []  # Rewards for completing the quest
var steps: Array = []    # Steps required to complete the quest
var parent: RQuests      # Reference to the list containing all runtime quests for this mod

# Constructor to initialize quest properties
# myparent: The list containing all quests for this mod
# newid: The ID of the quest being created
func _init(myparent: RQuests, newid: String):
	parent = myparent
	id = newid

# Overwrite this quest's properties using a DQuest
func overwrite_from_dquest(dquest: DQuest) -> void:
	if not id == dquest.id:
		print_debug("Cannot overwrite from a different id")
	name = dquest.name
	description = dquest.description
	spriteid = dquest.spriteid
	sprite = dquest.sprite
	rewards = dquest.rewards.duplicate(true)
	steps = dquest.steps.duplicate(true)

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
