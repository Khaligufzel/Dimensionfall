extends Node
@onready var streamPlayer: AudioStreamPlayer = $GameplayMusic
#Main Menu
func main_menu_music_play():
	$"MainMenu".play()
func main_menu_music_pause():
	$"MainMenu".stream_paused = true
func main_menu_music_resume():
	$"MainMenu".stream_paused = false
func main_menu_music_stop():
	$"MainMenu".stop()
#Game over
func game_over_music_play():
	$"GameOver".play()
func game_over_music_stop():
	$"GameOver".stop()

#In-game music
enum THEMES {
	PEACE,
	#BATTLE
}

var TRACKS = {
	THEMES.PEACE: [preload("res://Sounds/Music/dark fallout.ogg"), preload("res://Sounds/Music/The Surreal Truth.mp3"), preload("res://Sounds/Music/Please, answer me my friend.mp3")] 
	#THEMES.BATTLE: [preload("res://Sounds/Music/The Depths of Hell.mp3")]
}

var current_theme: int = THEMES.PEACE
var is_repeating: bool = true

func play_theme(theme: int, repeat_themes: bool = true):
	if current_theme != theme or !streamPlayer.playing:
		is_repeating = false # Prevent accidentally starting an old track playing
								# again when next command is stop()
		streamPlayer.stop()
		
		is_repeating = repeat_themes
		current_theme = theme
		
		var theme_tracks: Array = TRACKS[current_theme]
		if theme_tracks != []:
			streamPlayer.stream = theme_tracks[randi() % theme_tracks.size()]
			streamPlayer.play()

func replay_current_theme():
	var theme_tracks: Array = TRACKS[current_theme]
	streamPlayer.stream = theme_tracks[randi() % theme_tracks.size()]
	streamPlayer.play()

func _on_gameplay_music_finished():
	if is_repeating:
		replay_current_theme()

func gameplay_music_stop():
	streamPlayer.stop()
