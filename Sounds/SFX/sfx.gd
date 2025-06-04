extends Node

# Audio players
@onready var stream_wrapper := SFXPlayerWrapper.new($AudioStreamPlayer)
@onready var movement_wrapper := SFXPlayerWrapper.new($MovementSFXPlayer)

# UI sound effects mapped by name
@onready var ui_sounds := {
	&"UI_Hover": $UI_Hover,
	&"UI_Click": $UI_Click,
}

# --- Inner class that wraps an AudioStreamPlayer and its logic ---
class SFXPlayerWrapper:
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

func play_sfx(sfx: int, repeat_sfx: bool = true):
	var wrapper: SFXPlayerWrapper = movement_wrapper if sfx == SFX.WALKING_GRASS else stream_wrapper

	if current_sfx != sfx or not wrapper.is_playing():
		stream_wrapper.stop()
		movement_wrapper.stop()

		current_sfx = sfx

		var sfx_tracks: Array = tracks.get(current_sfx, [])
		wrapper.play_random(sfx_tracks)


func replay_current_sfx():
	var sfx_tracks: Array = tracks.get(current_sfx, [])
	var wrapper: SFXPlayerWrapper = movement_wrapper if current_sfx == SFX.WALKING_GRASS else stream_wrapper
	wrapper.play_random(sfx_tracks)


func ui_sfx_play(sound : String):
	ui_sounds[sound].play()

func _on_audio_stream_player_finished():
	gameplay_sfx_stop()

func gameplay_sfx_stop():
	stream_wrapper.stop()

func movement_sfx_stop():
	movement_wrapper.stop()
