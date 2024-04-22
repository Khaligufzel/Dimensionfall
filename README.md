# Catax:

Catax is a top-down real-time survival game set in a post-apocalyptic world. Survive in a strange place where you can visit multiple dimensions. Will you fight demons? Aliens? Zombies? Who knows what you will come across.

![Catax_basic](Media/Catax_basic.png)


## How to play:
Until releases are shared on github, you can play the game in the following way:
- Download [Godot](https://godotengine.org/download/) from their website or from [steam](https://store.steampowered.com/app/404790/Godot_Engine/)
- Download this project by going to the top-right of this page and clicking the green 'code' button and then click 'download zip'
- Extract the zip file to a location of your choosing
- Open Godot and click open project and navigate to the folder where you extracted the zip file
- Open the project in Godot and click 'play' in the top-right

## Features:
The game has the following features:

### Combat:
Ranged combat is currently implemented. One-handed weapons can be dual-wielded. Two-handed weapons will take up both slots. You can load and unload guns and magazines. Ammunition and other loot can be looted from enemy corpses.

### Inventory
- You have to manage weight and volume.
- You can drag and drop item from different containers
- Interact with your equipment slots

![Catax_inventory](Media/Catax_inventory.png)

### Overmap
The game will create an overmap where some areas are suitable for travel. Each viable location will let you enter into a new tacticalmap and explore. The overmap is infinite.

![Catax_overmap](Media/Catax_overmap.png)


### Main menu
- Play the game
- Load a game
- Read documentation
- Manage content for the game
![Catax_main_menu](Media/Catax_main_menu.png)


### Content editor
Content for this game is created in the content editor. On the left you can select content to edit. You can edit tacticalmaps, maps, items, tiles, furniture and mobs. 
- All content is saved as JSON, which allows you to edit the files manually or using an external editor if you want to.
- Content is loaded as mods, even the core content. Put all your json and sprites into /mods/yourmod/ and it can be read by the game (only core content is read at the moment, full mod support will be implemented)
![Catax_content_editor](Media/Catax_content_editor.png)


### Tacticalmap editor
A tacticalmap is made from maps. This allows you to piece together a bigger map. You can specify any size and start filling the grid with maps from the selection on the right. The tiles in the grid can be rotated to properly connect roads and create symmetry.
![Catax_tacticalmap_editor](Media/Catax_tacticalmap_editor.png)


### Map editor

 
A map has a fixed size of 32x32 and has a maximum of 21 levels in height, ranging from -10 to +10. 
- Place tiles, mobs and furniture onto the grid and get creative
- Controls allow you to move up and down, zoom, rotate, copy/paste and more

![Catax_map_editor](Media/Catax_map_editor.png)

### Item editor
Allows you to edit and add items in the game. An item will work as you configure it. You can make it work as a weapon and as food if you choose to, the types are not mutually exclusive. Specify the item properties in the convenient editor which has tooltips and controls to help you fill in the right values.
![Catax_item_editor](Media/Catax_item_editor.png)


### Tile editor
Allows you to specify the properties of tiles and add new ones. Sprites are loaded from /mods/core/tiles so put your sprites there if you want to add new ones.
![Catax_tile_editor](Media/Catax_tile_editor.png)


### Mob editor
Allows you to create new mobs and configure them. You can then use the map editor to place them on the map.

![Catax_mob_editor](Media/Catax_mob_editor.png)


# Furniture editor
Create new furniture or edit existing ones with this editor. After creating them, you can place them on the map with the map editor.

![Catax_furniture_editor](Media/Catax_furniture_editor.png)


## Roadmap

### Stage 1 (first release):

- Building/crafting/reloading should take resources from the inventory
- Basic crafting/building menu
- "Progress bar" to show the player when the current action will be finished (reloading, building, crafting etc.)
- A few additional weapons
- In-game content editor to make our own mods or contribute to the core mod
- Doors
- Sounds
- Bug fixing
- Polishing

Additional features before our first release:

- furniture/containers
- personal goals
- more enemies/better AI
- noise
- some fancy shaders?
- equipment
- proper player inventory, bags, pockets etc.

### Stage 2:

- Vehicles
- Proper base building
- Base raids?
- World map
- Saving
- Player stats and skills
- Melee weapons
- Recoil/sway/spread/aiming


## Contribute

If you like Godot and want to contribute, feel free to submit a pull request or issue on your ideas, or join us on discord. To make edits, download [Godot](https://godotengine.org/download/) from their website or from [steam](https://store.steampowered.com/app/404790/Godot_Engine/). Download the source code and open the project using Godot. This is and always will be a hobby project and will not be for sale. 

## Community

Official Discord:
[https://discord.gg/jFEc7Yp](https://discord.gg/hWJTUSnW)
