extends Node
@onready var GameplayMusicPlayer: AudioStreamPlayer = $GameplayMusicPeace
@onready var GameOverMusic: AudioStreamPlayer = $GameOverMusic
@onready var StreamPlayer: AudioStreamPlayer = $StreamPlayer
#Main Menu
func main_menu_music_play():
	$"MainMenuMusic".play()
func main_menu_music_pause():
	$"MainMenuMusic".stream_paused = true
func main_menu_music_resume():
	$"MainMenuMusic".stream_paused = false
func main_menu_music_stop():
	$"MainMenuMusic".stop()
	
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


# Called when the node enters the scene tree for the first time.
func _ready():
	# Connect to the Helper.signal_broker.game_started signal
	Helper.signal_broker.game_started.connect(_on_game_started)
	Helper.signal_broker.game_loaded.connect(_on_game_loaded)
	Helper.signal_broker.game_ended.connect(_on_game_ended)

func play_theme(theme: int, repeat_themes: bool = true):
	if current_theme != theme or !StreamPlayer.playing:
		is_repeating = false # Prevent accidentally starting an old track playing
								# again when next command is stop()
		StreamPlayer.stop()
		
		is_repeating = repeat_themes
		current_theme = theme
		
		var theme_tracks: Array = TRACKS[current_theme]
		if theme_tracks != []:
			StreamPlayer.stream = theme_tracks[randi() % theme_tracks.size()]
			StreamPlayer.play()

func replay_current_theme():
	var theme_tracks: Array = TRACKS[current_theme]
	StreamPlayer.stream = theme_tracks[randi() % theme_tracks.size()]
	StreamPlayer.play()

func gameplay_music_stop():
	GameplayMusicPlayer.stop()

# Function for handling game started signal
func _on_game_started():
	GameplayMusicPlayer.play()
	
# Function for handling game ended signal
func _on_game_ended():
	GameplayMusicPlayer.stop()
	
# Function for handling game loaded signal
func _on_game_loaded():
	GameplayMusicPlayer.play()
