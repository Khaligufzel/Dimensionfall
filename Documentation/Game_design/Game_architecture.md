# Game architecture
This page includes information about the overall game architecture.

There are several key parts that will be described on this page
|   |

# Main scene
The main scene is scene_selector.tscn. From here, you can navigate to playing the game, modifying the content or opening the help menu.


# Game scene
When you press the 'play demo' button, the game switches to 'level_generation.tscn'. Each entity will run their script on their _ready function:
1. The LevelGenerator will check if there is any save data for the location and load that. If there isn't it will ask the `overmap_manager` for the terrain round the player's spawn position. The data from the `overmap_manager` will be a grid of maps determined by the mapseed. For each chunk in the grid that is close to the player, the LevelGenerator will call Chunk.gd to create a new chunk based on the mapdata for that position. Chunk.gd will process all the blocks in the map (max 32x32x21 blocks) and instantiate them, as well as the furniture and enemies.
2. The player will have his stats, health and equipment initialized. If this is a new game, the defaults will be applied. Otherwise the data will be loaded from memory.
3. If the player holds any weapons, the weapon controllers called EquippedLeft and EquippedRight will initialize the weapon. It will check if it's a melee or ranged weapon and set it's stats accordingly
4. The HUD will initialize all the menus like the crafting menu, inventory, quest journal and overmap.
5. The overmap will, when opened, show the area around the player that can be explored. The overmap displays an infinite terrain around the player based on the map seed. The player can use this overmap to determine his next move.


# Autoloads
The game has the following [autoloads](https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html). These will initialize when the game is started and are accessible from every script and will persist even after switching a scene:

| Autoload | Description |
| ------------- | ------------- |
| ItemManager | Runtime item manipulation happens here. It handles things like inventory, reloading, equipment and crafting |
| Helper | General autoload with generic helper functions. Also contains these sub-helpers: json_helper, save_helper, signal_broker, task_manager, map_manager |
| Gamedata | Loads data from the /mods folder and allows any script to access it |
| Gloot | An addon that provides functionality for the inventory. We do not access this directly, only trough the classes provided by the addon. |
| General | A general autoload script for functions that do not fit anywhere else |
| CraftingRecipesmanager | Manages visibility and availability of crafting recipes and performs checks on requirements |
| QuestManager | Autoload of the [QuestManager](https://github.com/Chevifier/QuestManager) addon. It handles quest tracking on the backend. |

## Nakama

Multiplayer addon for Godot. See documentation on [Github](https://github.com/heroiclabs/nakama-godot)


## Helper

A general helper autoload that provides generic functions used in many other scripts. It also includes several sub-helpers:
| Sub-Autoload | Description |
| ------------- | ------------- |
| json_helper | Can be accessed trough `Helper.json_helper`. Provides functions for manipulating json files and data |
| map_manager | Can be accessed trough `Helper.map_manager`. Provides functions for accessing and manipulating map data. For example, finding out what's around the player and constructing and destructing blocks and furniture. |
| overmap_manager | Can be accessed trough `Helper.overmap_manager`. Creates the overmap based on the mapseed. Defines regions and fills the overmap grids with the terrain that the player will explore. Provides data about the terrain to the `levelgenerator` and the overmap gui. |
| quest_helper | Can be accessed trough `Helper.quest_helper`. Provides functions for accessing and manipulating quests. It will translate quest json data into actual ScriptedQuests for the player to complete. It responds to signals from all over the game in order to track the quest progress. |
| time_helper | Can be accessed trough `Helper.time_helper`. Provides functions for accessing the time that has passed in-game. This can be used for time based events, food rot, day/night cycle and other things. |
| save_helper | Can be accessed trough `Helper.save_helper`. Provides functions for saving and loading data. |
| signal_broker | Can be accessed trough `Helper.signal_broker`. This is a central point trough which to send signals for other scripts to react to. The most important use case is allowing signals between game entities (blocks, enemies, containers) and the player's UI. |
| task_manager | Can be accessed trough `Helper.task_manager`. Provides functions to offload tasks onto a separate thread. A simple example would be `my_data = await Helper.task_manager.create_task(process_my_file.bind(filecontents)).completed`. We only need to use this for functions that show spikes in the profiler and dropping the FPS. See Chunk.gd for the current application |


## Gamedata
Central management of game data. Data is loaded from the `/mods` folder. This includes all entity data and sprites. All data can be accessed trough this autoload. Ties heavily into the Content Editor. When data is changed using the content editor, the Gamedata autoload will update related entities if needed and save the data. The data is stored in it's own class, accessible trough Gamedata.items or Gamedata.furnitures or Gamedata.maps, and so on.

## Gloot
An autoload that is provided by the [Gloot addon](https://github.com/peter-kish/gloot). We do not access this directly, just trough the addon's classes. It provides functionality for the inventory.

## ItemManager
Manages creation, destruction and movement of items in the player's inventory and elsewhere

## General
A general autoload script for functions that do not fit anywhere else

## CraftingRecipesmanager
Manages visibility and availability of crafting recipes and performs checks on requirements

## QuestManager
Autoload of the [QuestManager](https://github.com/Chevifier/QuestManager) addon. It handles quest tracking on the backend.


# Map generation
The game world is generated by the `overmap_manager` as `OvermapGrid`s filled with `map_cell`s. This is just data to be used by the `level_generation` script, which will instantiate the `maps` as `chunks` in-game so the player has terrain to walk on.

## Overmap
The `overmap_manager` uses these steps to produce the final overmap:
1. A noisemap is used to generate the base layer of fields and forests
2. The `overmap areas` are placed on the map. An example of an `overmap area` is a city
3. If cities are placed on the grid, they will be connected by roads
4. Tacticalmaps are placed on the grid randomly, avoiding the existing roads and areas
5. The final product will be a 100x100 grid filled with cells that have an id of a map

The overmap window in-game is a UI element that generates a grid of tiles to represent the overmap. It aids the player in exploring the world and can point to quest targets.

## Tacticalmap
A tacticalmap is a manually created grid of maps. This grid can have any dimension, from 1x1 to 64x64 or bigger. It is made up of maps. In-game, the `overmap_manager` will read a tacticalmap and for each of the cells in a tacticalmap, it will put the associated map on the overmap. This allows for static areas inside the procedural terrain. When making a Tacticalmap, enter the dimensions to set the size you want to use. A grid will be displayed, and you can select one of the maps to paint onto the grid. Using a combination of maps, you can create a town, forest, mountain or anything you like.

## Map editing
Maps are edited in the Content Editor and contain data for a maximum of 32x32x21 blocks. When editing a map, a fixed grid of 32 tiles is presented. You can pick tiles from the palette in the editor to paint onto the grid to make anything you want. You can also add enemies and furniture. Use areas to enable random generation when the map is instanced into the game. For example, randomized floors or mob positions. To have a map spawn in-game, it has to be added to a `tacticalmap` or an `overmap area`

## Overmap areas
Can be used to create areas on the overmap, like biomes. The area can be modified in the content editor and is made up or regions. When generated onto the overmap, it will define a center point and draw a circle around it, then warp the shape in a random way. Each region in the area will cover a set %. This allows you to create a center, middle and outer rings. For example, a city is made up of an inner `urban` region, a middle `suburban` region and an outer `field` region. You can specify the size of the area in the editor.

Each region contains a list of maps. You can add maps to the regions by dragging them from the maps list. You can then assign a weight to each map, which will control the chances of it spawning. The editor also has a `generation` tab to assist in easy visualization of the final product. The `overmap_manager` will spawn 10 areas on the overmap, trying to keep them separate.


# Content editor
Content for the game is created and modified in the content editor. You could make content in Godot itself, but when the game is exported and the end-user does not have Godot, they can still open the game and add content from there using mods. Right now only the core mod can be loaded and modified but full mod support is planned.

Content in the content editor is represented in lists, where each item has it's own ID. The UI allows you to add, duplicate, modify and delete items in the lists. Maps and tacticalmaps are each stored in their own json files. Everything else is stored in one json file per type. So all items are in one json file and furniture is in another etc. The JSON files are loaded by Gamedata and that is what will be manipulated using the content editor. Nothing is saved to disk until the user presses the save button.

Each type has it's own kind of editor. Most of the editors are just forms for the user to manipulate the json behind it. You could also use an external editor to edit the json directly. However, the content editor also manages references between entities. So when an itemgroup has it's items configured, the items will get a reference to the itemgroup. When an item form that itemgroup is deleted, it will also disappear from the itemgroup. This prevents non-exisiting items from spawning. Multiple references are established in different relationships between entities.

Sprites are stored in the same folder as the JSON data for each type. Each item can be assigned a sprite. Some items might even share the same sprite. To add new sprites, you can drop them in the appropriate folder in the /mods folder. 



# Saving and loading
The Helper.save_helper will save and load data when the scene changes or a game is loaded. The saved data is stored in the user data folder. In Godot, go to the menu buttons in the top and click Project -> Open user data folder to open the user data folder. This might be `C:\Users\User\AppData\Roaming\Godot\app_userdata\CataX` on windows.

When the player presses escape and clicks on `save game` or `return to main menu`, all relevant data is stored. 
- The overmap seed is generated once and saved when the game starts. After that the overmap state is saved and loaded
- The player inventory is serialized trough the Gloot addon and de-serialized when a game is loaded
- The game is keeping track of the player's equipment in ItemManager.player_equipment, which is then saved and loaded into json
- The player's stats are just read from the player's node and saved as a dictionary into a json file which is loaded at a later moment.
- The map that the player is currently playing on is saved when returning to the main menu. Each chunk is unloaded and saved to a dictionary called Helper.loaded_chunk_data. This dictionary is then saved into a JSON file for the current coordinate on the overmap, which will be stored in a file like `C:\Users\User\AppData\Roaming\Godot\app_userdata\CataX\save\2024-05-25T213346\map_x1_y4\map.json`

When the player presses the load game button on the main menu, the `_on_load_game_button_pressed` function in scene_selector is called and all the previously saved data is loaded. 
