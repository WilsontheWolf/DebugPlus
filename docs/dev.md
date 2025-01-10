# Developers

DebugPlus provides many features that are really only useful for people developing balatro mods. This page covers those features for devs, and is split up into 2 sections:

1. [Integrating Other Mods Into DebugPlus](#integrating-other-mods-into-debugplus)
2. [Using DebugPlus To Help Develop Over Mods](#using-debugplus-to-help-develop-over-mods)

## Integrating Other Mods Into DebugPlus

DebugPlus provides a public api, which allows mods to integrate into DebugPlus, providing devs and users a nicer experince with other mods. This section outlines how to use these features.

### API Basics

To access the DebugPlus API you can require the `debugplus-api` module. From there, you will want to call `isVersionCompatible` with the version you expect. This allows mods to detect if an incompatible version of DebugPlus is installed, and not crash. If you prefer to just look at some code, see [examples/example.lua](../examples/example.lua).

This typically looks like:

```lua
local success, dpAPI = pcall(require, "debugplus-api")

if success and dpAPI.isVersionCompatible(1) then
    -- Do stuff with the api here.
end
```

The version is the api version, and does not nessicarily follow the main mod version. The current latest and only version is `1`.

### Registering an ID

DebugPlus requires you to register a unique mod "id" to be tied to the things in DebugPlus's api. This is done with the `registerID` method. Assuming you have done the example in [API Basics](#api-basics), you can register a mod like so:

```lua
local debugplus = dpAPI.registerID("MyMod")
```

### Logging

DebugPlus provides a logger to allow users to log at different log levels, with their mod name appended to logs.

> [!NOTE]  
> If you are writing a [Steamodded](https://github.com/Steamodded/smods) mod, you can use [Steamodded's logging tools](https://github.com/Steamodded/smods/wiki/Logging) to also get these benefits, without relying on DebugPlus.
>
> Additionally, if you don't want any fancy features, just logging with `print` works fine.

You can get the logger from a [registered mod](#registering-an-id) like so:

```lua
debugplus.logger
```

The logger is an object with the following keys:

- log - Print an info log (equivalent to logger.info)
- debug = Print an debug log
- info = Print an info log
- warn = Print an warn log
- error = Print an info log

These methods are equivalent to `print` so you can use them anywhere you call print. This also means you can have a fallback like so:

```lua
local success, dpAPI = pcall(require, "debugplus-api")

local logger = { -- Placeholder logger, for when DebugPlus isn't available
    log = print,
    debug = print,
    info = print,
    warn = print,
    error = print
}

if success and dpAPI.isVersionCompatible(1) then -- Make sure DebugPlus is available and compatible
    local debugplus = dpAPI.registerID("Example")
    logger = debugplus.logger -- Provides the logger object
end

logger.log("Hi")
```

### Commands

DebugPlus provides an API to register commands to be able to run in the console. You can register a command from a [registered mod](#registering-an-id) using `addCommand` like so:

```lua
debugplus.addCommand({
    name = "test",
    shortDesc = "Testing command",
    desc = "This command is an example from the docs.",
    exec = function (args, rawArgs, dp)
        return "Hi Mom"
    end
})
```

Here is a brief list of the properties on the object passed to addCommand:

- name - The name of the command. Can only use lowercase letters, numbers, `-` and `_`. This will be used for running your command.
- shortDesc - A short description of your command. Shown when running `help` without any arguments.
- desc - The full description of your command. It's a good idea to add usage examples in here. Show when running `help` with your command as an argument.
- exec - The function that is run when running your command.

The arguments passed to exec are:

- args - A list with arguments passed by the user. How it's parsed is up to DebugPlus, but you can assume that each argument is a separate part of the user input
- rawArgs - A string with the complete text the user provided for your command. Useful for when you want to handle args differently than DebugPlus does.
- dp - A table with a few different methods/values on it to help with commands:
  - dp.hovered - The currently hovered ui element (equivalent to `G.CONTROLLER.hovering.target`)

The return value for exec has three arguments:

- The message to show the user. This is the only required argument and you will want to always return something here.
- The log level (defaults to INFO). Can be one of DEBUG, INFO, WARN, ERROR.
- colour (defaults to your log level's colour). Is a table with the first arg as red, second as green third as blue.

When exec is run, DebugPlus will attempt to catch errors in the command. This is for convenience so you don't need to restart the game if there is a little bug in the command, but it's recommended you don't use errors to indicate the user did something wrong, but instead do `return "Useful error message", "ERROR"`.

## Using DebugPlus To Help Develop Over Mods

DebugPlus provides a handful of commands dedicated to use when developing mods. Here is some info regarding them:

### Eval

DebugPlus provides an eval command. This command will run whatever lua code you put in it, and print out the result. It also handles errors. It's super helpful for when testing out what happens when you do x. Eval has access to the dp object described in [Commands](#commands) for convince.

### Reloading Atlases

DebugPlus provides a keybind (ctrl+m by default) to reload the game's atlases. When developing a mod, you can make a change to your atlas, then reload it to see changes in game, without restarting the game.

### Watch

Watch is a command that watches for changes in a file, then performs an action on it when it changes. It has a few different sub commands which determines what it does when the file changes. All the subcommands for the types follow the same syntax, `watch <type> <path>` where the path is a relative path to the file from the Balatro save directory.

#### lua

Running `watch lua <path>` will watch the provided file for changes and eval the code. Useful for when you want to do some testing on larger bits of code.

> [!WARNING]  
> Running this on an existing mod file is likely to cause issues due to side effects. Make sure you design your watched file around it being run multiple times.

#### config_tab

Running `watch config_tab <path>` will watch the provided file for changes and eval the code. The big difference between this and [lua](#lua) is that this will take the returned value, and render it in a config tab, similar to how `SMODS.config_tab` works.

See [examples/watch_config_tab.lua](../examples/watch_config_tab.lua).

#### center

> [!NOTE]  
> This watch depends on [Steamodded](https://github.com/Steamodded/smods) (v1.0.0+) to function.

> [!WARNING]  
> This watch command has side effects. Changes to objects will stay until you restart the game.

Running `watch center <path>` will watch the provided file for changes and eval the code. The big difference between this and [lua](#lua) is that this will take the returned value, and use it in a similar way to the object passed to the different [`SMODS.Center`](https://github.com/Steamodded/smods/wiki/SMODS.Center)'s. The biggest difference between the SMODS.Center's is that the key needs to be the full key with the `j_` prefix and your mod prefix.

DebugPlus will update the functions and loc_txt for your joker on the fly (and adds error protecton to the function). This allows you to rapidly iterate on a joker.

See [examples/watch_joker.lua](../examples/watch_joker.lua) and [examples/watch_consumeable.lua](../examples/watch_consumeable.lua).

#### shader

> [!NOTE]  
> This watch depends on [Steamodded](https://github.com/Steamodded/smods) (v1.0.0+) to function.


> [!WARNING]  
> This watch command is fairly unstable. It's recommended to run `watch stop` after you're done with it to prevent side effects and crashes. If the shader code has an issue at runtime, it will crash.

Running `watch shader <path>` will watch the provided shader file for changes and show a joker with the shader as an edition. This should just work with any edition shaders used for Steamodded. 

> [!NOTE]  
> Due to a quirk with shaders, they have to be passed a variable with their name. DebugPlus uses some heuristics to guess the name. If DebugPlus fails to guess correctly, the shader will crash. If the game crashes with the watch command but not when used with Steamodded on an edition, please make a bug report.
