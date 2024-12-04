class_name RMap
extends RefCounted

# There's a R in front of the class name to indicate this class only handles runtime map data, nothing more
# This script is intended to be used inside the Runtimedata autoload singleton
# This script handles data for one map. You can access it trough Runtimedata.maps.by_id(mapid)

# This class represents a map with its properties
# Example map data:
#{
#	"areas": [
#	{
#	    "id": "base_layer",
#	    "rotate_random": false,
#	    "spawn_chance": 100,
#	    "tiles": [
#	    	{ "id": "grass_plain_01", "count": 100 },
#	    	{ "id": "grass_dirt_00", "count": 15 }
#	    ],
#	    "entities": []
#	},
#	{
#	    "id": "sparse_trees",
#	    "rotate_random": true,
#	    "spawn_chance": 30,
#	    "tiles": [
#	    	{ "id": "null", "count": 1000 }
#	    ],
#	    "entities": [
#	    	{ "id": "Tree_00", "type": "furniture", "count": 1 },
#	    	{ "id": "WillowTree_00", "type": "furniture", "count": 1 }
#	    ]
#	},
#	{
#	    "id": "generic_field_finds",
#	    "rotate_random": false,
#	    "spawn_chance": 50,
#	    "tiles": [
#	    	{ "id": "null", "count": 500 }
#	    ],
#	    "entities": [
#	    	{ "id": "generic_field_finds", "type": "itemgroup", "count": 1 }
#	    ]
#	}
#	],
#	"categories": ["Field", "Plains"],
#	"connections": {
#	"north": "ground",
#	"south": "ground",
#	"east": "ground",
#	"west": "ground"
#	},
#	"description": "A simple and vast field covered with green grass, perfect for beginners.",
#	"id": "field_grass_basic_00",
#	"levels": [
#		[], [], [], [], [], [], [], [], [], [],
#	[
#	    {
#	    "id": "grass_medium_dirt_01",
#	    "rotation": 180,
#	    "areas": [
#	        { "id": "base_layer", "rotation": 0 },
#	        { "id": "sparse_trees", "rotation": 0 },
#	        { "id": "generic_field_finds", "rotation": 0 }
#	    ]
#	    },
#	    {
#	    "id": "grass_plain_01",
#	    "rotation": 90,
#	    "areas": [
#	        { "id": "base_layer", "rotation": 0 },
#	        { "id": "sparse_trees", "rotation": 0 },
#	        { "id": "generic_field_finds", "rotation": 0 }
#	    ]
#	    }
#	]
#	],
#	"mapheight": 32,
#	"mapwidth": 32,
#	"name": "Basic Grass Field",
#	"references": {
#		"core": {
#			"overmapareas": [
#				"city"
#			]
#		}
#	},
#	"weight": 1000
#}


var id: String = "":
	set(newid):
		id = newid.replace(".json", "") # In case the filename is passed, we remove json
var name: String = ""
var description: String = ""
var categories: Array = [] # example: "categories": ["Buildings","Urban","City"]
var weight: int = 1000
var mapwidth: int = 32
var mapheight: int = 32
var levels: Array = [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]]
var areas: Array = []
var sprite: Texture = null
 # Variable to store connections. For example: {"south": "road","west": "ground"} default to ground
var connections: Dictionary = {"north": "ground","east": "ground","south": "ground","west": "ground"}
var dataPath: String
var parent: RMaps

# Constructor to initialize the  map with an ID and data path
func _init(myparent: RMaps, newid: String, newdataPath: String):
	id = newid
	dataPath = newdataPath
	parent = myparent

func overwrite_from_dmap(dmap: DMap) -> void:
	if not id == dmap.id:
		print_debug("Cannot overwrite from a different id")
		return

	# Copy properties directly from dmap
	name = dmap.name
	description = dmap.description
	categories = dmap.categories.duplicate(true)
	weight = dmap.weight
	mapwidth = dmap.mapwidth
	mapheight = dmap.mapheight
	levels = dmap.levels.duplicate(true)
	areas = dmap.areas.duplicate(true)
	sprite = dmap.sprite
	connections = dmap.connections.duplicate(true)
	dataPath = dmap.dataPath


func get_data() -> Dictionary:
	var mydata: Dictionary = {}
	mydata["id"] = id
	mydata["name"] = name
	mydata["description"] = description
	if not categories.is_empty():
		mydata["categories"] = categories
	mydata["weight"] = weight
	mydata["mapwidth"] = mapwidth
	mydata["mapheight"] = mapheight
	mydata["levels"] = levels
	if not areas.is_empty():
		mydata["areas"] = areas
	if not connections.is_empty():  # Omit connections if empty
		mydata["connections"] = connections
	return mydata
