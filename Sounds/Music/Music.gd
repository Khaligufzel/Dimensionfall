extends Node
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
