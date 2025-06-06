extends Node

# Enum to reference sound effects
enum SFX {
	WALKING_GRASS,
	WALKING_CONCRETE,
	WALKING_WOOD,
	HURT_MALE
}

# Preloaded audio streams grouped by sound type
var tracks := {
	SFX.WALKING_GRASS: [
		preload("res://Sounds/SFX/Footsteps/footstep01.wav"),
		preload("res://Sounds/SFX/Footsteps/footstep01.wav")
	],
	SFX.WALKING_CONCRETE: [
		preload("res://Sounds/SFX/Footsteps/footstep01.wav"),
		preload("res://Sounds/SFX/Footsteps/footstep01.wav")
	],
	SFX.WALKING_WOOD: [
		preload("res://Sounds/SFX/Footsteps/footstep01.wav"),
		preload("res://Sounds/SFX/Footsteps/footstep01.wav")
	],
	SFX.HURT_MALE: [
		preload("res://Sounds/SFX/Hurt sounds (Male)/aargh0.wav"),
		preload("res://Sounds/SFX/Hurt sounds (Male)/aargh2.wav"),
		preload("res://Sounds/SFX/Hurt sounds (Male)/aargh4.wav"),
		preload("res://Sounds/SFX/Hurt sounds (Male)/aargh6.wav")
	]
}

# Audio players initialized with custom SFX player logic
@onready var generic_sfx_player := SFXPlayer.new($AudioStreamPlayer, tracks[SFX.HURT_MALE])
@onready var movement_sfx_player := SFXPlayer.new($MovementSFXPlayer, tracks[SFX.WALKING_GRASS])

# UI sound effects mapped by name
@onready var ui_sounds := {
	&"UI_Hover": $UI_Hover,
	&"UI_Click": $UI_Click,
}

# --- Class that handles playback logic for a specific AudioStreamPlayer ---
class SFXPlayer:
	var player: AudioStreamPlayer
	var tracks: Array = []

	func _init(_player: AudioStreamPlayer, _tracks: Array = []) -> void:
		player = _player
		tracks = _tracks

	func stop() -> void:
		if player:
			player.stop()

	func is_playing() -> bool:
		return player and player.playing

	# Play a random track at the given volume (0–100%)
	func play_random(volume_percent: float = 100.0) -> void:
		if tracks.is_empty():
			return

		var db := linear_to_db(clamp(volume_percent, 0.0, 100.0) / 100.0)
		player.volume_db = db

		player.stream = tracks.pick_random()
		player.play()

# Plays a general SFX sound (e.g., pain grunts, explosions, etc.)
func play_generic_sfx(volume_percent: float = 100.0):
	if not generic_sfx_player.is_playing():
		generic_sfx_player.play_random(volume_percent)

# Plays a movement-related SFX based on walking surface and loudness
func play_movement_sfx(surface_type: SFX, volume_percent: float = 100.0):
	if not movement_sfx_player.is_playing():
		if surface_type in tracks:
			movement_sfx_player.tracks = tracks[surface_type]
			movement_sfx_player.play_random(volume_percent)

# Plays a UI sound effect by name (like hover or click)
func ui_sfx_play(sound: String):
	if ui_sounds.has(sound):
		ui_sounds[sound].play()

# Called when generic audio stream finishes
func _on_audio_stream_player_finished():
	gameplay_sfx_stop()

# Called when movement audio stream finishes
func _on_movement_sfx_player_finished():
	movement_sfx_stop()

# Stops general SFX
func gameplay_sfx_stop():
	generic_sfx_player.stop()

# Stops movement-related SFX
func movement_sfx_stop():
	movement_sfx_player.stop()
