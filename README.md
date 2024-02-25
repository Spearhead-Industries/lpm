<div align="center">

# Lua Package Mananger (LPM)\*

</div>

Simple package manager for LuaU.

**Maintainer:** @plainenglishh

\* definitely not inspired by npm...

### Alternatives

This tool was designed to aid in the production of LuaU/Lune standalone tools, not Roblox games. Use [Wally](https://github.com/UpliftGames/wally) for Roblox games.

## Installation

### Aftman (Recommended)

You can install lpm with the [Aftman](https://github.com/LPGhatguy/aftman) toolchain manager:

```bash
# Project Only
aftman init
aftman add Spearhead-Industries/lpm
aftman install

# Globally
aftman add --global Spearhead-Industries/lpm
```

### From Source

You can install from source with the following steps (assumes you have aftman installed):

```bash
# Download and CD into the repo
git clone https://github.com/Spearhead-Industries/lpm.git
cd lpm

# Install the toolchain
aftman install

# Run the build script
lune run ./scripts/build.lua

# The executable should now be available in ./out/
```

## Usage

### Creating a Package: `init`

```bash
lpm init
```

The `init` command, short for initialise, allows you to create a new package in the current working directory. It will prompt you with a series of questions about your package.

### Installing Dependencies: `install`

```bash
lpm install [PACKAGE(s)]
```

The `install` command allows you to install dependencies in your package. The command expects a list of package identifers. The format for package identifiers are as follows;

```raw
<github-author>/<github-name>[@<ref>]

github-author refers to the owner of the repository.
github-name refers to the name of the repository.
ref refers to either a tag or branch, and is optional.

If no ref is specified, it will use the main branch.
```

> [!NOTE]  
> LPM sees `Spearhead-Industries/test-lpm-package` and `Spearhead-Industries/test-lpm-package@1.0.0` as completely seperate unrelated packages.

After installing the package(s), you can access them with;

```lua
-- No ref
local package = require("@lpm/hi");

-- Has ref
local package = require("@lpm/hi-v1-0-0"); -- Due to darklua limitations, "@" is replaced with "-v" and "." is replaced with "-" within requires.
```

### Uninstalling Dependencies: `uninstall`

```bash
lpm uninstall [PACKAGE(s)]
```

The `uninstall` command allows you to uninstall dependencies in your package. The command expects a list of package identifers.

Please note that the `uninstall` command does *not* go through the uninstalled package's own dependencies to uninstall them too. I understand this may be annoying if you're uninstalling a package with lots of dependencies. In the near future I'll make it iterate through remaining packages to cleanup unused packages.

### Running your Package: `run`

```bash
lpm run
```

The `run` command allows you to execute your package. The command will begin executing your package at the entrypoint specified by your `lpm-package.toml` file.

### Compiling your Package: `build`

```bash
lpm build [OPTIONS]
```

The `build` command allows you to compile your package into a standalone executable. You must have [darklua](https://github.com/seaofvoices/darklua) installed for this to function.

The resulting binary will be located in `./out`.

#### Options

|Option|Meaning|
|---|---|
|`--mkarchive`|Generates an aftman compatible `.zip` archive.|
