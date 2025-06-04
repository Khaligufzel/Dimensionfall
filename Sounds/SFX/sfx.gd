extends Node

# Audio players
@onready var stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var movement_player: AudioStreamPlayer = $MovementSFXPlayer

# UI sound effects mapped by name
@onready var ui_sounds := {
	&"UI_Hover": $UI_Hover,
	&"UI_Click": $UI_Click,
}

# Enum to reference sound effects
enum SFX {
	WALKING_GRASS,
	HURT_MALE
}

# Preloaded audio streams grouped by sound type
var tracks := {
	SFX.WALKING_GRASS: [preload("res://Sounds/SFX/Footsteps/footstep01.wav")],
	SFX.HURT_MALE: [
		preload("res://Sounds/SFX/Hurt sounds (Male)/aargh0.wav"),
		preload("res://Sounds/SFX/Hurt sounds (Male)/aargh2.wav"),
		preload("res://Sounds/SFX/Hurt sounds (Male)/aargh4.wav"),
		preload("res://Sounds/SFX/Hurt sounds (Male)/aargh6.wav")
	]
}

# Track current SFX and repeat mode
var current_sfx: int = SFX.WALKING_GRASS
var is_repeating: bool = false

func play_sfx(sfx: int, repeat_sfx: bool = true):
	if current_sfx != sfx or !stream_player.playing or !movement_player.playing:
		is_repeating = false # Prevent accidentally starting an old track playing
								# again when next command is stop()
		stream_player.stop()
		movement_player.stop()
		
		is_repeating = repeat_sfx
		current_sfx = sfx
		
		var sfx_tracks: Array = tracks[current_sfx]
		if sfx_tracks != []:
			if current_sfx == SFX.WALKING_GRASS:
				movement_player.stream = sfx_tracks[randi() % sfx_tracks.size()]
				movement_player.play()
			else:
				stream_player.stream = sfx_tracks[randi() % sfx_tracks.size()]
				stream_player.play()

func replay_current_sfx():
	var sfx_tracks: Array = tracks[current_sfx]
	if current_sfx == SFX.WALKING_GRASS:
		movement_player.stream = sfx_tracks[randi() % sfx_tracks.size()]
		movement_player.play()
	else:
		stream_player.stream = sfx_tracks[randi() % sfx_tracks.size()]
		stream_player.play()

func ui_sfx_play(sound : String):
	ui_sounds[sound].play()

func _on_audio_stream_player_finished():
	gameplay_sfx_stop()

func gameplay_sfx_stop():
	stream_player.stop()

func movement_sfx_stop():
	movement_player.stop()
