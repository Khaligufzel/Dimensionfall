extends Node

var early_life_events = {}
var childhood_events = []
var adolescence_events = []
var young_adulthood_events = []
var mature_adulthood_events = []
var life_stage_independent_events = []

# List of traits
var traits = [
	"Bravery", "Discipline", "Resilience", "Creativity", "Loyalty", "Honesty", "Patience", "Optimism", "Curiosity"
]

var archetypes = []

var character = {
	"name": "",
	"archetype": "",
	"backstory": [],
	"personality_traits": {}
}

func _ready():
	
	# Load JSON data

	var event_data = Helper.json_helper.load_json_dictionary_file("res://Mods/Core/Character/Events.json")
	var archetype_data = Helper.json_helper.load_json_array_file("res://Mods/Core/Character/Archetypes.json")

	# Make some events
	early_life_events = event_data["early_life_events"]
	childhood_events = event_data["childhood_events"]
	adolescence_events = event_data["adolescence_events"]
	young_adulthood_events = event_data["young_adulthood_events"]
	mature_adulthood_events = event_data["mature_adulthood_events"]
	life_stage_independent_events = event_data["life_stage_independent_events"]
	archetypes = archetype_data


	# Generate a character (temp)
	var char_name = "Alex"
	var archetype = pick_random_archetype()
	
	character = generate_character(char_name, archetype)
	var story = generate_story(character)
	print(story)

func generate_character(character_name: String, archetype: String) -> Dictionary:
	var generated_character = {
		"name": character_name,
		"archetype": archetype,
		"backstory": [],
		"personality_traits": {}
	}
	
	# Initialize traits with default value of 5
	for trait1 in traits:
		generated_character["personality_traits"][trait1] = 5
	
	# Generate backstory
	# Generate backstory
	generated_character["backstory"].append(pick_random_event(early_life_events))
	generated_character["backstory"].append(pick_random_event(childhood_events))
	generated_character["backstory"].append(pick_random_event(adolescence_events))
	generated_character["backstory"].append(pick_random_event(young_adulthood_events))
	generated_character["backstory"].append(pick_random_event(mature_adulthood_events))
	generated_character["backstory"].append(pick_random_event(life_stage_independent_events))
	
	# Adjust personality traits based on backstory
	for event_dict in generated_character["backstory"]:
		#var event = event_dict["event"]
		var trait_changes = event_dict["trait_changes"] if event_dict.has("trait_changes") else event_dict
		for trait_change in trait_changes:
			var trait1 = trait_change["trait"]
			var change = trait_change["change"]
			if generated_character["personality_traits"].has(trait1):
				generated_character["personality_traits"][trait1] = clamp(generated_character["personality_traits"][trait1] + change, 1, 10)
	
	return generated_character

func pick_random_event(events: Array) -> Dictionary:
	# var total_weight = 0
	# for event_dict in events:
	# 	total_weight += event_dict["weight"]
	
	# var random_weight = randi() % total_weight
	# for event_dict in events:
	# 	random_weight -= event_dict["weight"]
	# 	if random_weight < 0:
	# 		return event_dict
	# return events[events.size() - 1]
	var event_dict = events[0]

	return event_dict

func pick_random_archetype() -> String:
	return archetypes[randi() % archetypes.size()]

func generate_story(generated_character: Dictionary) -> String:
	var story = "Character Name: " + generated_character["name"] + "\n"
	story += "Archetype: " + generated_character["archetype"] + "\n\n"
	story += "Backstory:\n"
	
	# Make "story"
	story += "In their early life, " + generated_character["name"] + " " + generated_character["backstory"][0]["event"] + ". "
	story += "During their childhood, " + generated_character["name"] + " " + generated_character["backstory"][1]["event"] + ". "
	story += "As an adolescent, they " + generated_character["backstory"][2]["event"] + ". "
	story += "In their young adulthood, " + generated_character["name"] + " " + generated_character["backstory"][3]["event"] + ". "
	story += "Later in their mature adulthood, they " + generated_character["backstory"][4]["event"] + ". "
	story += "Throughout their life, they also " + generated_character["backstory"][5]["event"] + ".\n\n"
	
	story += "Personality Traits:\n"
	for trait1 in generated_character["personality_traits"]:
		story += "- " + trait1 + ": " + str(generated_character["personality_traits"][trait1]) + "\n"
	
	return story
