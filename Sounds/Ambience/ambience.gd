extends Node
@onready var streamPlayer: AudioStreamPlayer = $Ambience
enum AMBIENCE {
	DAYTIME_NATURE,
	#DAYTIME_URBAN,
	NIGHTTIME_NATURE,
	#NIGHTTIME_URBAN,
	RAINY,
	#SNOWY,
	WINDY
	
}

var TRACKS = {
	AMBIENCE.DAYTIME_NATURE: [preload("res://Sounds/Ambience/AmbientNatureBirdsWater01.wav"), preload("res://Sounds/Ambience/AmbientNatureOutside.wav")],
	AMBIENCE.NIGHTTIME_NATURE: [preload("res://Sounds/Ambience/cricketsounds.mp3")],
	AMBIENCE.RAINY: [preload("res://Sounds/Ambience/AmbientNatureNightRainy.wav")],
	AMBIENCE.WINDY: [preload("res://Sounds/Ambience/wind1.wav")]
}

var current_ambience: int = AMBIENCE.DAYTIME_NATURE
var is_repeating: bool = true

func play_ambience(ambience: int, repeat_ambience: bool = true):
	if current_ambience != ambience or !streamPlayer.playing:
		is_repeating = false # Prevent accidentally starting an old track playing
								# again when next command is stop()
		streamPlayer.stop()
		
		is_repeating = repeat_ambience
		current_ambience = ambience
		
		var ambience_tracks: Array = TRACKS[current_ambience]
		if ambience_tracks != []:
			streamPlayer.stream = ambience_tracks[randi() % ambience_tracks.size()]
			streamPlayer.play()

func replay_current_ambience():
	var ambience_tracks: Array = TRACKS[current_ambience]
	streamPlayer.stream = ambience_tracks[randi() % ambience_tracks.size()]
	streamPlayer.play()

func _on_ambience_finished():
	if is_repeating:
		replay_current_ambience()

func ambience_stop():
	streamPlayer.stop()
