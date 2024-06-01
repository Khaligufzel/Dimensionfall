# Getting started with game development

This guide is intended for new contributors. It will teach you the basics of contributing to the project. Use your skillset to make changes in the area you enjoy working on. It can be coding, modding, graphics, music, testing and many other ways. If you're a player reading this page, you can contribute by [submitting an issue](https://docs.github.com/en/issues/tracking-your-work-with-issues/creating-an-issue) to report bugs!


## Basic setup
These steps will help you setup with Godot and Github to start contributing your changes to this repository
1. Download [Godot](https://godotengine.org/download/) from their website or from [steam](https://store.steampowered.com/app/404790/Godot_Engine/).
2. Create a [Github account](https://docs.github.com/en/get-started/start-your-journey/creating-an-account-on-github) if you do not already have one
3. Install [git](https://docs.github.com/en/get-started/getting-started-with-git/set-up-git) for a command line interface or [Github desktop](https://docs.github.com/en/desktop/overview/getting-started-with-github-desktop) for a graphical interface (recommended).
4. Fork this repositoy. See [this guide](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/fork-a-repo?tool=webui) if you use git or [this guide](https://docs.github.com/en/desktop/adding-and-cloning-repositories/cloning-and-forking-repositories-from-github-desktop) if you use Github desktop (recommended)
5. Clone your fork to your local computer if you haven't already. You can now launch Godot and [open the project](https://docs.godotengine.org/en/stable/tutorials/editor/project_manager.html#opening-and-importing-projects). Once it's open, you can press the 'play' button in the top-right to try it out. If you're new to Godot, read their [getting started](https://docs.godotengine.org/en/stable/getting_started/step_by_step/index.html) guide.


## Make your first change
These steps show you how to make a simple change to the game without any coding
1. Before you can start making changes, make a branch using [git](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-and-deleting-branches-within-your-repository) or [Github Desktop](https://docs.github.com/en/desktop/overview/getting-started-with-github-desktop#making-changes-in-a-branch) (recommended)
2. Open the project in Godot if you haven't already
3. Press the play button in the top-right to start the game
4. Press 'Content editor' from the main menu and then 'Content manager'.
5. Find the 'item groups' list in the left part of the content manager. You can collapse the other lists by clicking on their name
6. Click on the + button next to 'Item Groups' to add a new itemgroup. A pop-up will show, asking for an id. You have to make it unique, for example `basic_mob_loot_00`
7. The new itemgroup is added to the list. Scroll down the list and double click the `basic_mob_loot_00` itemgroup to edit it
8. A new editor is opened in a tab that allows you to change the properties of the itemgroup. Click the image next to `Sprite:` to select a sprite for this itemgroup. It can be any sprite, for example the machete
9. Enter a name and description, for example `Mob loot` and `Some loot the player can find in mobs`
10. You don't need to change the Group type, but you can hover over the drop-down menu to read what it does
11. In the left list, expand the 'items' list if it is collapsed. Drag items from the list into the 'items' area of the itemgroup editor. This allows you to compose a list of items you want to spawn when this itemgroup is used
12. You don't need to edit the probability or min and max count, but you can hover the cursor on the controls to see what they do.
13. Press 'Save' and 'Close' to finish your changes. Now that we are done, close the game and let's commit your changes to the branch
14. To commit your changes to your branch, read [this guide](https://docs.github.com/en/desktop/overview/getting-started-with-github-desktop#making-changes-in-a-branch) for Github Desktop (recommended) or [this guide](https://docs.github.com/en/get-started/using-git/pushing-commits-to-a-remote-repository) for git
15. Lastly, [create a pull request](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request#creating-the-pull-request). Someone with the rights to merge your request will review it and merge it if accepted. A message about your pull request will also appear in the discord server, so someone will review it soon.


# Add/edit content
Anyone can add or edit content for the game. You do not need to know anything about programming to start working on content. If you haven't worked on a github project before, make sure to do the [basic setup](basic-setup) and read the [make your first change](make-your-first-change) guide.

## Working with the content editor
To edit content, start the game first. From the main menu, click 'Content editor' and then 'Content manager'. You will now see the main window of the content manager. On the left side, you can see types of content to add to or edit.

### Basic controls
The basic controls are as follows:
- Click on the name of the list to collapse/expand it
- Double-click on an item in the list to edit it. An editor will open in a new tab in the editor
- Click the `+` sign next to a list name to add a brand new item in that list. A pop-up will show where you can enter the id of this new item. It has to be unique. Once you have entered the id, click `Ok` and the new item will be at the bottom of the list
- Click the `D` to duplicate an item in the list. A pop-up will appear with the id of the item you duplicated. Edit the id to make it unique and press `Ok` to add it to the list. It will have the same properties as the item you duplicated from. Only the id has changed
- Click the `-` to delete an item from the list

### Adding/updating sprites
If you're an artist and want to update or add sprites, you will need to use Godot or the file browser to browse to `Mods/Core/` and one of the sub-folders. From there, you can edit, replace or add a sprite. The TacticalMaps and Maps folder are excluded from this, because TacticalMaps do not have a sprite (yet) and the sprite for maps is generated by the content editor.
- If you edited/replaced a sprite, it will be loaded into the game on the next launch
- If you added a sprite, it will be loaded, but you have to assign it to one of the entities in the content editor. For example, go to the itemlist and double-click one of the items to edit it. The item editor will open in a new tab. Next, click the image next to `Sprite:` and select the sprite you added. Lastly, press `save` to save your changes


## Modifying the game code
First, do the [basic setup](basic-setup). Also, read the [game architecture](https://github.com/Khaligufzel/CataX/blob/main/Documentation/Game_design/Game_architecture.md) document to get a basic understanding about the structure of the game's code.

### Navigating the project
- Most of the game's scripts are in `/Scripts`. For the contenteditor, they will be in `/Scenes/ContentManager`.
- Get familiar with the [autoloads](https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html) as described in the [game architecture](https://github.com/Khaligufzel/CataX/blob/main/Documentation/Game_design/Game_architecture.md) document since they will provide central access to functions you can use anywhere.
- You can also look at what [pull requests](https://github.com/Khaligufzel/CataX/pulls?q=is%3Apr) have been opened previously. From there, you can open one of the pull requests and see what element of the game was changed and the files associated with it. If you spot a pull request that modified part of the map generation, click it and go to `files changed` in the pull request to see the files that were changed
- In Godot, use `ctrl+shift+f` to find text in files. For example, if you want to know what scripts alter or read the player node, search for player.

### Choose what to modify
Maybe you have some ideas about what to work on, or perhaps you want to fix a bug. Here are some tips to get started:
- Look at what [issues](https://github.com/Khaligufzel/CataX/issues) are open and assign one to your name.
- In the discord, look at the roadmap channel and pick a subject to work on from there
- Also in the discord, browse the channels and see what ideas have been shared, for example in the brainstorming channel

### Game data and game play
The contenteditor and game are closely related. Data that you need in-game needs to be defined in the content editor. It also goes the other way around. If you define something in the content editor, make sure it is also implemented in-game.

Here is a small example of a change you can make. We will add `weight` to moveable furniture.
1. Open FurnitureEditor.tscn in Godot and go to the 2D view. In the form, add two controls in a place that makes sense. We will add a label and a spinbox
2. Name the label `WeightLabel` and the spinbox will be called `WeightSpinbox`
3. Select the `WeightSpinbox` in the editor and go to the inspector. Find the `Tooltip` property and enter the description for this control. For example: `Specify the weight in kg for this furniture. A larger number means it will be heavier and harder to push. A smaller number means it will be lighter and easier to push. Only applies to moveable furniture`
4. Go to the `FurnitureEditor.gd` script. Assign the spinbox control to an export variable like so: `@export var weightSpinbox: SpinBox = null`
5. In the `load_furniture_data` function we add the lines:
   ```
	if weightSpinbox != null and contentData.has("weight"):
		weightSpinbox.value = float(contentData["weight"])
   ```
6. In the `_on_save_button_button_up` function we add the line `contentData["weight"] = weightSpinbox.value`. Now the property will get saved and loaded from JSON
7. In the `FurniturePhysics.gd` script, in the `construct_self` function, we add the line `mass = furnitureJSONData.get("weight", 0)` to set the mass according to the weight.
8. Open the contenteditor and open one of the moveable furniture and set the weight property and save it. Now the furniture will use the weight property you implemented.
9. The mass will get read in the `player.gd` script when the player starts to push the furniture.
10. Follow step 14 and 15 of the [make your first change](make-your-first-change) paragraph to commit your changes.

This was a simple change. Of course, the practical application of json data will vary each time and some may be more complicated then others. To make what you want, ask for help and read guides about the topic you want to work on.

### UI development
UI is another area that is somewhat accessible to contributors starting out. This means menus, windows and status indicators. The main scenes are in `/Scenes/UI`. These scenes are added to the `HUD` node in `level_generation.tscn` to have them displayed to the player when a button is pressed.

Keep in mind that the UI communicates with the game world trough autoloads. For example, the Inventory menu works together with the `ItemManager` (`/Scripts/item_manager.gd`). Some game elements like the player and some windows communicate trough `Helper.signal_broker`. To find out what connects to what, press `ctrl+shift+f` in Godot and search for `Helper.signal_broker` and a list will come up.

Icons used in the UI can be found in `/Textures` and `/Images/Icons`. Sometimes you don't need to use an icon and a button with an `x` or arrow `->` will suffice. In the case of the character menu, the icons are loaded from the mod data in `/Mods/Core/Stats` and `/Mods/Core/Stats`
