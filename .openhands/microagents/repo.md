---
name: repo
type: repo
agent: CodeActAgent
---
This repository contains the source for **Dimensionfall**, a top-down real-time survival game built in Godot. It includes game scenes, scripts, assets, procedural world generation, an in-game content editor, and mod support.

## Repository Structure

### Scenes
- `scene_selector.tscn`: Main menu entry point (Play, Content Editor, Help).
- `level_generation.tscn`: Game scene that merges mods, generates terrain, instantiates chunks, and initializes the HUD.
- UI scenes (`Scenes/UI`): Inventory, crafting, quests, overmap, etc.
- Content Editor scenes (`Scenes/ContentManager`): JSON-based editor for mods (maps, items, quests, furniture).

### Scripts
- `Scripts/`: Core GDScript code organized into:
  - **Autoload singletons**: `Gamedata`, `Runtimedata`, `Helper`, `ItemManager`, `CraftingRecipesManager`, `QuestManager`, `Gloot`.
  - **Helper submodules**: `json_helper`, `map_manager`, `overmap_manager`, `quest_helper`, `time_helper`, `save_helper`, `signal_broker`, `task_manager`.
  - **World generation**: `LevelGenerator`, `Chunk.gd` (procedural chunks of up to 32×32×21 blocks).
  - **Gameplay components**: Player, weapons (EquippedLeft/EquippedRight), mobs, items, crafting, base building.

### Mods & Data
- `Mods/`: Core mod (`Dimensionfall`) plus example/test mods.
- JSON files per data type (items, furniture, maps, tacticalmaps) stored alongside sprites within each mod folder.
- Runtime mod merging: `Gamedata` loads mod sets; `Runtimedata` merges them for play.

### Assets
- `Textures/`, `Media/`, `Images/`, `Sounds/`, `Shaders/`: Art, audio, and effects.
- Sprites created via Blender-Pixelart, Material-Maker.

### Documentation
- `Documentation/Game_design/Game_architecture.md`: Overall architecture (scenes, autoloads, map generation, content editor, saving/loading).
- `Documentation/Game_development/Getting_started.md`: Contributor setup and workflow guide.
- Additional docs: lore, feature list, modding guide, extended design details.

### Tests
- `Tests/Unit/`: GUT-based unit tests for map manager, chunk, mob, container, player, etc.
- **Running tests**: Launch Godot with GUT plugin or use the GUT command-line runner.

## Running the Game
1. Install Godot (see https://godotengine.org).
2. Open this project in Godot and press the Play button.
3. Alternatively, download a demo release from the GitHub Releases page.

## GitHub Pull Request
When submitting a PR:
- Fork the repo and create a feature branch off `main`.
- Commit changes with clear messages and include related issue references.
- Open a draft PR against `main`: describe your changes, testing steps, and impact.

## Implementation Details
- **Procedure**: OvermapManager builds a 100×100 grid via noise, biome areas, roads, and tacticalmaps; LevelGenerator spawns chunks around the player.
- **Content Editor**: In-game JSON editor maintaining cross-entity references; supports mod packaging without external Godot.
- **Saving/Loading**: `Helper.save_helper` serializes overmap seed/state, loaded chunks, player state, and inventory via Gloot.
