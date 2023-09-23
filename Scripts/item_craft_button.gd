extends Button

var recipe

var crafting_menu


func _on_toggled(button_pressed):
	if button_pressed:
		get_tree().call_group("CraftingMenu","item_craft_button_clicked", recipe)
