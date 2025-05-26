extends Node

@export var root_path : NodePath

func _ready() -> void:
	assert(root_path != null, "Empty root path for Interface Sounds!")
	# connect signals to the method that plays the sounds
	install_sounds(get_node(root_path))

#Add new ones for other nodes you want sound for
func install_sounds(node: Node) -> void:
	for i in node.get_children():
		if i is Button:
			i.mouse_entered.connect( Sfx.ui_sfx_play.bind(&"UI_Hover") )
			i.pressed.connect( Sfx.ui_sfx_play.bind(&"UI_Click") )
		elif i is OptionButton:
			i.mouse_entered.connect( Sfx.ui_sfx_play.bind(&"UI_Hover") )
			i.pressed.connect( Sfx.ui_sfx_play.bind(&"UI_Click") )
		elif i is TextureButton:
			i.mouse_entered.connect( Sfx.ui_sfx_play.bind(&"UI_Hover") )
			i.pressed.connect( Sfx.ui_sfx_play.bind(&"UI_Click") )
		#elif i is TabContainer:
		#	i.tab_hovered.connect( Sfx.ui_sfx_play.bind(&"UI_Hover") )
		#	i.tab_clicked.connect( Sfx.ui_sfx_play.bind(&"UI_Hover") )
		#elif i is MarginContainer:
		#	i.mouse_entered.connect( Sfx.ui_sfx_play.bind(&"UI_Hover") )
		#	i.pressed.connect( Sfx.ui_sfx_play.bind(&"UI_Click") )
		install_sounds(i)
