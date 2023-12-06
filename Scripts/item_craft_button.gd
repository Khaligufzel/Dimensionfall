extends Button

var recipe

var crafting_menu


func _on_toggled(currently_pressed: bool):
	if currently_pressed:
		get_tree().call_group("CraftingMenu","item_craft_button_clicked", recipe)
