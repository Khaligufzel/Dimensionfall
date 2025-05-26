extends Node
@onready var GameplayMusicPlayer: AudioStreamPlayer = $GameplayMusicPeace
@onready var GameOverMusic: AudioStreamPlayer = $GameOverMusic
@onready var StreamPlayer: AudioStreamPlayer = $StreamPlayer
@onready var theme_tracks: Array
@onready var current_track
@onready var next_track
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
	THEMES.PEACE: [preload("res://Sounds/Music/dark fallout.ogg"), preload("res://Sounds/Music/The-Surreal-Truth.ogg"), preload("res://Sounds/Music/Please_-answer-me-my-friend.ogg")]
	#THEMES.BATTLE: [preload("res://Sounds/Music/The-Depths-of-Hell.ogg")]
}

var current_theme: int = THEMES.PEACE
var is_repeating: bool = true

func play_theme(theme: int, repeat_themes: bool = true):
	if current_theme != theme or !StreamPlayer.playing:
		is_repeating = false # Prevent accidentally starting an old track playing
								# again when next command is stop()
		StreamPlayer.stop()
		
		is_repeating = repeat_themes
		current_theme = theme
		
		theme_tracks = TRACKS[current_theme]
		if theme_tracks != []:
			current_track = theme_tracks[randi() % theme_tracks.size()]
			StreamPlayer.stream = current_track
			StreamPlayer.play()
			print("Current theme: " + str(current_theme) + ", current track: " + str(current_track))

func replay_current_theme():
	theme_tracks = TRACKS[current_theme]
	next_track = theme_tracks[randi() % theme_tracks.size()]
	while next_track == current_track:
		next_track = theme_tracks[randi() % theme_tracks.size()]
	current_track = next_track
	StreamPlayer.stream = current_track
	StreamPlayer.play()

func _on_stream_player_finished():
	print("The song is finished")
	await get_tree().create_timer(5.0).timeout
	replay_current_theme()
	print("Current theme: " + str(current_theme) + ", next track: " + str(next_track))

func _on_gameplay_music_peace_finished():
	GameplayMusicPlayer.stream_paused = true
	print("Music stream paused")
	await get_tree().create_timer(10.0).timeout
	GameplayMusicPlayer.stream_paused = false
	print("Music stream resumed")



func gameplay_music_stop():
	GameplayMusicPlayer.stop()
