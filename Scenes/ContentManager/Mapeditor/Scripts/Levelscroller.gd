extends VBoxContainer



func _on_level_scrollbar_value_changed(value):
	$LevelIndicator/Label.text = "Level: " + str(0-value)
