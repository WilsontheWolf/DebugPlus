# DebugPlus 1.1.0

## Features
- Copying a playing card now places it in the deck if your hand is empty.
- Internal changes to the logger
- Detect nested folders (when smods is loaded) and provide a useful error message
- Change to using json metadata for Steamodded (this shouldn't have any user facing effect).

# DebugPlus 1.0.0

I've been cooking this for a while but now it's ready for general consumption. 
DebugPlus v1.0.0 is a major change for the master branch, which has been mostly 
unchanged for 5 months.

## Breaking Changes

> [!IMPORTANT]  
> There's a high likelihood that you will be impacted by at least one of these. Make sure you read through this section.

- The minimum required [lovely](https://github.com/ethangreen-dev/lovely-injector) version has been increased.  
    - v0.5.0-beta7 is the new minimum, but v0.6.0 is recommended. You can grab the latest lovely at https://github.com/ethangreen-dev/lovely-injector/releases.
- By default, most debug keybinds require you hold CTRL to use them.
    - You may change this in the config. If Steamodded is installed, then go to Mods > DebugPlus > Config, otherwise go to Settings > DebugPlus to access the config.
- The layout of branches has changed a bit, if you are getting the code from the source. 
    - As of now, the master branch will be where main development goes. A new stable branch has been created if you just want the latest release.
    - You can also now download the latest version from [GitHub Releases](https://github.com/WilsontheWolf/DebugPlus/releases).

## Features
This build contains a bunch of new features, listed below:
- Improvements to the console
    - Log levels
    - Better support for logs with many lines
    - Config options to manage which logs you see
    - Scrolling
    - If you're looking to use these additional log details in your mod, see the [developer docs](https://github.com/WilsontheWolf/DebugPlus/blob/master/docs/dev.md) for more info
- A command handler
    - You can now run numerous commands to modify aspects of the game
    - Accessible by opening the console (pressing `/`)
    - Run the `help` command to see all the commands
    - There is also an api for mods to add their own commands. See the [developer docs](https://github.com/WilsontheWolf/DebugPlus/blob/master/docs/dev.md) for more info
- Configuration
    - Added some configuration options to control different aspects of the game.
    - If steamodded is installed, then go to Mods > DebugPlus > Config, otherwise go to Settings > DebugPlus to access the config.
