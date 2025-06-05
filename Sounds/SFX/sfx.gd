extends Node

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

# Audio players initialized with custom SFX player logic
@onready var generic_sfx_player := SFXPlayer.new($AudioStreamPlayer)
@onready var movement_sfx_player := SFXPlayer.new($MovementSFXPlayer)

# UI sound effects mapped by name
@onready var ui_sounds := {
	&"UI_Hover": $UI_Hover,
	&"UI_Click": $UI_Click,
}

# --- Class that handles playback logic for a specific AudioStreamPlayer ---
class SFXPlayer:
	var player: AudioStreamPlayer
	var current_sfx: int = -1

	func _init(_player: AudioStreamPlayer) -> void:
		player = _player

	func stop() -> void:
		if player:
			player.stop()

	func play_random(tracks: Array) -> void:
		if tracks.is_empty():
			return
		player.stream = tracks.pick_random()
		player.play()

	func is_playing() -> bool:
		return player and player.playing


# Enum to reference sound effects
enum SFX {
	WALKING_GRASS,
	HURT_MALE
}

# Track current SFX and repeat mode
var current_sfx: int = SFX.WALKING_GRASS

# Plays the specified sound effect using the appropriate SFXPlayer instance
func play_sfx(sfx: int):
	var soundplayer := movement_sfx_player if sfx == SFX.WALKING_GRASS else generic_sfx_player

	if current_sfx != sfx or not soundplayer.is_playing():
		movement_sfx_player.stop()
		generic_sfx_player.stop()

		current_sfx = sfx

		var sfx_tracks: Array = tracks.get(current_sfx, [])
		soundplayer.play_random(sfx_tracks)

# Plays a UI sound effect by name
func ui_sfx_play(sound: String):
	ui_sounds[sound].play()

func _on_audio_stream_player_finished():
	gameplay_sfx_stop()

func _on_movement_sfx_player_finished():
	movement_sfx_stop()

# Stops general SFX
func gameplay_sfx_stop():
	generic_sfx_player.stop()

# Stops movement-related SFX
func movement_sfx_stop():
	movement_sfx_player.stop()
