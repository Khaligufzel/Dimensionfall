extends Node
@onready var streamPlayer: AudioStreamPlayer = $AudioStreamPlayer
@onready var movementPlayer: AudioStreamPlayer = $MovementSFXPlayer

# create audio player instances
@onready var uisounds = {
	&"UI_Hover" : $UI_Hover,
	&"UI_Click" : $UI_Click,
	}

enum SFX {
	WALKING_GRASS,
	HURT_MALE
}

var TRACKS = {
	SFX.WALKING_GRASS: [preload("res://Sounds/SFX/Footsteps/footstep01.wav")],
	SFX.HURT_MALE: [preload("res://Sounds/SFX/Hurt sounds (Male)/aargh0.wav"), preload("res://Sounds/SFX/Hurt sounds (Male)/aargh2.wav"), preload("res://Sounds/SFX/Hurt sounds (Male)/aargh4.wav"), preload("res://Sounds/SFX/Hurt sounds (Male)/aargh6.wav")] 
}

var current_sfx: int = SFX.WALKING_GRASS
var is_repeating: bool = false

func play_sfx(sfx: int, repeat_sfx: bool = true):
	if current_sfx != sfx or !streamPlayer.playing or !movementPlayer.playing:
		is_repeating = false # Prevent accidentally starting an old track playing
								# again when next command is stop()
		streamPlayer.stop()
		movementPlayer.stop()
		
		is_repeating = repeat_sfx
		current_sfx = sfx
		
		var sfx_tracks: Array = TRACKS[current_sfx]
		if sfx_tracks != []:
			if current_sfx == SFX.WALKING_GRASS:
				movementPlayer.stream = sfx_tracks[randi() % sfx_tracks.size()]
				movementPlayer.play()
			else:
				streamPlayer.stream = sfx_tracks[randi() % sfx_tracks.size()]
				streamPlayer.play()

func replay_current_sfx():
	var sfx_tracks: Array = TRACKS[current_sfx]
	if current_sfx == SFX.WALKING_GRASS:
		movementPlayer.stream = sfx_tracks[randi() % sfx_tracks.size()]
		movementPlayer.play()
	else:
		streamPlayer.stream = sfx_tracks[randi() % sfx_tracks.size()]
		streamPlayer.play()

func ui_sfx_play(sound : String):
	uisounds[sound].play()

func _on_audio_stream_player_finished():
	gameplay_sfx_stop()

func gameplay_sfx_stop():
	streamPlayer.stop()

func movement_sfx_stop():
	movementPlayer.stop()
