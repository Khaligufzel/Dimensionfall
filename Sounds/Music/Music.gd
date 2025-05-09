extends Node

func main_menu_music():
	$"MainMenu".play()

func main_menu_music_paused():
	$"MainMenu".stream_paused = true
	
func main_menu_music_resumed():
	$"MainMenu".stream_paused = false

func main_menu_music_stopped():
	$"MainMenu".stop()
