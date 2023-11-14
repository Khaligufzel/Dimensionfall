extends Control

signal zoom_level_changed


func _on_zoom_slider_value_changed(value):
	zoom_level_changed.emit(value) 
	
func _on_mapeditor_zoom_level_changed(value):
	$HBoxContainer/ZoomSliderPercentLabel.text = str($HBoxContainer/ZoomSlider.value) + "%"
	if $HBoxContainer/ZoomSlider.value != value:
		$HBoxContainer/ZoomSlider.value = value
