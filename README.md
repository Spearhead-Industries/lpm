<div align="center">

# Lua Package Mananger (LPM)\*

</div>

Simple package manager for LuaU.

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
# Get the lune lpm fork
git clone https://github.com/Spearhead-Industries/lune-lpm.git

# Build
cd lune-lpm
cargo build

# Download and CD into the repo
cd ..
git clone https://github.com/Spearhead-Industries/lpm.git
cd lpm

# Install the toolchain
aftman install

# Run the build script
../lune-lpm/target/debug/lune-lpm run ./scripts/build.lua

# The executable should now be available in ./out/
```

#### Why 'Lune-LPM'?

We use a modified version of Lune to grant us access to some internal workings we wouldn't otherwise have access to. This helps make lpm easier to use. Changes to Lune are as follows;

1. a `@lune/lpm` standalone was created with functions for handling standalone binaries.
2. `process.args` was made mutable to allow lpm args to be removed before handing over to the entrypoint.

LPM is not indended to be ran with the `lune run ...` / `lune-lpm run ...` notation, as such lune-lpm only exists to create the standalone for lpm.

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


### Editing your Package Metadata: `edit`

```bash
lpm edit [OPERATION]
```

The `edit` command allows you to interact with your `lpm-package.toml` file safely, and allows you to perform the following operations;

1. `version`
2. `name`
3. `description`
4. `authors`
5. `licence`
6. `git-repo`

## Deviations from Standard Lune

When using lpm to run or build, an additional builtin library is made available: `@lune/lpm`.

This builtin exposes the following functions:-

### create_binary

```lua
lpm.create_binary(bytecode: string): string
```

Creates a standalone lune binary from the provided bytecode.

#### Example

```lua
local luau = require("@lune/luau");
local lpm = require("@lune/lpm");
local fs = require("@lune/fs");
local process = require("@lune/process");

local source = [[
    print("Hello, World");
]];

local bytecode = luau.compile(source);
local binary = lpm.create_binary(bytecode);
fs.writeFile("./hi.exe", binary);
local stdout = process.spawn("hi.exe").stdout;
print(stdout); --> Hello, World
```
