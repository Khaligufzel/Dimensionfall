extends Popup

# This script is intended to be used in the Sprite_Selector_Popup widget.
# The goal is to show the user a list of sprites that the user can select from
# The user selects a sprite and presses OK or Cancel to confirm the choice
# The parent interface will then receive the resource path of the selected sprite
# In order to use the Sprite_Selector_Popup, set the Sprite Dir property to the
# Directory where sprites should be loaded from. Each sprite will be represented
# By a Selectable_Sprite_Widget that handles selecting and click signals

#This will be instanced many times to make up the sprite list
@export var selectable_Sprite_Widget: PackedScene
#Reference to the Scrolling_flow_container that holds the sprites
@export var spriteList: Control = null
#Keep a reference to all the sprites that were instanced
var instanced_sprites: Array[Node] = []
# The parent control has to provide a dictionary. This dictionary
# contains a list of textures with the name of the texture as a key
var sprites_collection: Dictionary = {}:
	set(value):
		sprites_collection = value
		populate_sprite_list()
# Reference to one of the selectable_Sprite_Widgets that the user has selected
var selectedSprite: Control = null
#Will be sent when the user has selected a tile and pressed OK
signal sprite_selected_ok(clicked_sprite: Control)


# For each item in Gamedata.x.sprites it will create a
# selectable_Sprite_Widget and assign the file as the texture of the selectable_Sprite_Widget. 
# Then it will add the selectable_Sprite_Widget as a child to spriteList
func populate_sprite_list():
	for filename in sprites_collection.keys():
		var material = sprites_collection[filename]
		var selectableSpriteInstance = selectable_Sprite_Widget.instantiate()
		# Assign the texture to the TextureRect
		selectableSpriteInstance.set_sprite_texture(material)
		selectableSpriteInstance.selectableSprite_clicked.connect(sprite_clicked)
		selectableSpriteInstance.selectableSprite_double_clicked.connect(\
		_on_sprite_double_clicked)
		spriteList.add_content_item(selectableSpriteInstance)
		instanced_sprites.append(selectableSpriteInstance)

# Called after the user selects a tile in the popup textbox and presses OK
func _on_ok_button_up():
	_emit_sprite_selected_and_close()

# Called after the users presses cancel on the popup asking for a tile
func _on_cancel_button_up():
	hide()

func deselect_all_sprites():
	for child in instanced_sprites:
		child.set_selected(false)

# Mark the clicked selectedSprite as selected, but only after deselecting all other sprites
func sprite_clicked(spite_selected: Control) -> void:
	deselect_all_sprites()
	selectedSprite = spite_selected
	# If the clicked brush was not select it, we select it. Otherwise we deselect it
	spite_selected.set_selected(true)

func _on_sprite_double_clicked(sprite_selected: Control):
	selectedSprite = sprite_selected
	_emit_sprite_selected_and_close()
	
func _emit_sprite_selected_and_close():
	if selectedSprite:
		sprite_selected_ok.emit(selectedSprite)
		hide()
