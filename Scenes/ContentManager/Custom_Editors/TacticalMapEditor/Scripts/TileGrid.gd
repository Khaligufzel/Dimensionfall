extends GridContainer

@export var tileScene: PackedScene
#This is the index of the level we are on. 0 is ground level. can be -10 to +10
var currentLevel: int = 10
#Contains the data of every tile in the current level, the ground level or level 0 by default
var currentLevelData: Array[Dictionary] = []
@export var mapEditor: Control
@export var buttonRotateRight: Button
var selected_brush: Control

var drawRectangle: bool = false
var erase: bool = false
var snapAmount: float
# Initialize new mapdata with a 3x3 empty map grid
var defaultMapData: Dictionary = {"mapwidth": 3, "mapheight": 3, "maps": [[[],[],[]],[[],[],[]],[[],[],[]]]}
var rotationAmount: int = 0
#Contains map metadata like size as well as the data on all levels
var mapData: Dictionary = defaultMapData.duplicate():
	set(data):
		if data.is_empty():
			mapData = defaultMapData.duplicate()
		else:
			mapData = data.duplicate()
		#loadLevelData(currentLevel)
		

