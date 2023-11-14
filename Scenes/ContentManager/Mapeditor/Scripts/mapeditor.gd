extends Control

signal zoom_level_changed(value: int)

var zoom_level:int = 50:
	set(val):
		zoom_level = val
		zoom_level_changed.emit(zoom_level)

func _on_zoom_scroller_zoom_level_changed(value):
	zoom_level = value

func _on_tile_grid_zoom_level_changed(value):
	zoom_level = value
