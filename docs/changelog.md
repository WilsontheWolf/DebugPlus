# DebugPlus 1.5.1

## Fixes
- Fixed a bug where the crash handler would not receive keyboard input when "Console In Crash Handler" is enabled.

# DebugPlus 1.5.0

## Features
- Added a new text input to the console
  - There is now a cursor and it can be moved using left and right (and jumped with shift + left and shift + right)
  - You may now delete words with shift + backspace (and shift + del)
  - Hopefully fixed some weirdness with the old input
- The console's command history is now saved to a file and remebered when you restart the game.
  - There is a new option "Store Command History" to disable this behaviour if you so desire.
- 🥔

## Fixes
- Fix an issue where the console key would not be useable on some keyboard layouts
- Fixed an issue where cards were not properly calculated when being removed with SMODS present
- Improved compatibiltiy with mods hooking love.keypressed

# DebugPlus 1.4.2

## Fixes
- Fix an issue where `\`'s didn't work in the watch command.
- Fix an issue where SMODS logs with spaces in their logger wouldn't be parsed.

# DebugPlus 1.4.1

## Fixes
- Fixes an issue where watch would stop automatically reloading when quitting to the main menu from a run.

# DebugPlus 1.4.0

## Features
- Added a new profiler for use with newer luajit versions (see https://canary.discord.com/channels/1116389027176787968/1336473631483760791 [in [the balatro discord](https://discord.gg/balatro)]).
- Eval now works properly for multiple returns.
- Adjust console hooks to play nicer with some other mods.

## Fixes
- Tables with custom tostring methods had `hi` appended to them.
- Rare crash with watcher.
- Printing a `nil` would not display itself or any args past it.
- Crash when registering a mod with the api.

# DebugPlus 1.3.1

## Fixes
- Fix a crash when the config loader logged.
- Fixed a rare crash with the 1 and 2 keybinds.
- Fixed the console not receiving text input on some platforms.
- Fixed MacOS being unable to use some keybinds (by allowing ctrl or cmd to be used).

# DebugPlus 1.3.0

## Breaking Changes
- The watch joker command has been changed to watch center. It now works for any type of center, instead of just jokers.

## Features
- Some tweaks the the table stringifier (what's used when you eval a table)
  - Now no longer shows all values from all tables for 2 levels. Instead it shows all values from the top level table, and then shows only a subset of values from lower tables (ends at 3 levels)
  - Tables with custom tostring functions are stringified instead of expanded (for example talisman numbers)
- New option to automatically expand printed tables using the table stringifier.
- New option to process strings before printing to the lovely console.
  - This allows the expanding tables to also be printed and also works around some weird lovely bugs.
- Experimental option to make the console accessible from the crash screen.
  - Toggleable in the config. Doesn't work in vanilla.
- Key repeat is now on in the console (allows you to hold keys like backspace).
- Split config into multiple tabs


# DebugPlus 1.2.0

Another minor release. This one was mostly just some adjustments to existing stuff, to work a bit better.

## Features
- The `c` and `r` keybinds now work on tags.
- Whitespace before and after commands are now ignored when run.

## Fixes
- Fix an issue with the script for making release zips, where the steamodded metadata was not included. (The release zip for v1.1.0 was recreated with this change applied).

# DebugPlus 1.1.0

This is a minor release for DebugPlus, that adds some minor features and internal tweaks.

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
