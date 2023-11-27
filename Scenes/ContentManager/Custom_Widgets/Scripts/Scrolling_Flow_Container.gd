extends Control


@export var contentItems: FlowContainer = null
@export var collapseButton: Button = null
var is_collapsed: bool = false
var header: String = "Items":
	set(newName):
		header = newName
		collapseButton.text = header

#This function will collapse and expand the $Content/ContentItems when the collapse button is pressed
func _on_collapse_button_button_up():
	contentItems.visible = is_collapsed
	if is_collapsed:
		size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	is_collapsed = !is_collapsed

func add_content_item(item: Node):
	contentItems.add_child(item)
