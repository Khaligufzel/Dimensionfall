# How Parts Work

This page features snippets of extra documentation on key pieces of the plugin. It was previously included in the README.

- `app_config.tscn` is set as the first autoload. It calls `app_settings.gd` to load all the configuration settings from the config file (if it exists) through `config.gd`.
- `option_control.tscn` and its inherited scenes are used for most configurable options in the menus. They work with `config.gd` to keep settings persistent between runs.
- `capture_focus.gd` is attached to container nodes throughout the UI. It focuses onto UI elements when they are shown, allowing for easier navigation without a mouse.
