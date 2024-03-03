<!-- markdownlint-disable MD023 -->
<!-- markdownlint-disable MD033 -->
<!-- markdownlint-disable MD024 -->

# Changelogs

## [1.4.0] - !!!!????

### Added

- Added an `include` field to the manifest files.
  - Any files not specified in the include field, if it exists, will be removed.
  - `lpm-package.toml` is immunte to include.
  - Due to the way globs are parsed, `src` refers to *only* the directory and `src/**` refers to *only* the children of the directory. As such, both are required to keep a directory. Irritating, yes, I know, but when I can get around to reworking the glob parser, ill fix it. Same applies to `exclude`.
- Added `script` command to create and run scripts.
  - Scripts can either be luau or shell scripts.
  - Shell scripts are defined in the package manifest, whereas luau scripts are `.lua` files within `./scripts`.
  - `script new <name>` can be used to create new luau scripts.
  - `script run <name>` can be used to run a script. It will check for a shell script first, and check for a lua script if no shell script is found.
  - A set of builtin scripts are defined to 'hook' into lpm processes;
    - `__precli` runs when `lpm` is ran,
    - `__prebuild` runs prior to building,
    - `__postbuild` runs after building (if successful),
    - `__setup` runs if `install` is called with no arguments.
- Added install package aliases.
  - Packages can be installed under a different name by adding "=name" to the end of the package during install: `lpm install plainenglishh/router=thisisthealias`.
  - When uninstalling, it will check for the proper name of the package.
  - When requiring, it will look for the alias.
  - This is an expermiental feature.
- Added `wally` command to generate a `wally.toml` compatible manifest file from the `lpm-package.toml` manifest file.

### Changed

- The LPM CLI now attempts to fix any compatability issues (see author changes).
- `author` in the package manifest has now changed to `authors` (an array of authors).
- `version` in the package manifest now must conform to semver.
- `exclude` now uses globs instead of absolute paths.

## [1.3.1] - 2nd March 2024

### Changed

- Updated to use the new lune-lpm version, for net.createProxyClient.

## [1.3.0] - 27th Feburary 2024

### Added

- Added `lpm.is_standalone` function to the lpm builtin:
  - Returns `true` if the script is being executed as a standalone, returns false otherwise.
  - Although the `lpm` CLI is also a standalone lune programme, it will not be considered as one by this function.

### Changed

- `build` now carves out residual lpm bytecode in the resultant binary.

## [1.2.0] - 27th Feburary 2024

### Added

- `lpm` builtin with:
  - `create_binary` function to create a standalone binary from within LuaU.

### Changed

- Changed the internal build tool to use `lune-lpm` instead of vanilla lune.
  - `lune-lpm` is a patch of lune to enable process.args to be mutated and to allow standalones to be built fron inside LuaU.

- `run` now removes the first argument of process.args before handing over to the target script. This prevents 'run' from appearing in the target script's argument list.

## [1.1.0] - 26th Feburary 2024

### Added

- Added an `exclude` field to lpm-package.toml files.
  - Any exluded files *will* be downloaded with the rest of the repo and are instead removed *after* downloading.
  - Use .gitignore to hide sensitive information instead.
  - To prevent abuse, any double full-stops will be replaced with a single full-stop. Not that you should have multiple full-stops in a row in your filenames anyway as that looks ugly. 👍
  - All paths are prefixed with "./" automatically.

- Added support for wally and rotriever packages.
  - If no compatible package files are found, it will still install. You will need to figure out how to require it on your own however. Usually `require("@lpm/package/src")` will suffice.
  - Rotriever packages, if they have a valid `content_root` field, are requirable with the standard LPM `require("@lpm/package")` notation.
  - Wally dependencies are currently *not* supported, as I have yet to find an example of a wally package that has dependencies.
  - Any 'include' fields are ignored.

- The `install` and `uninstall` commands now remove any residual packages in the `lpm_modules` folder.
  - A package is deemed residual if it cannot be found in any (sub-)package `lpm-package.toml` dependencies.
  - This means that `uninstall` now correctly uninstalls sub-dependencies too.

- Added an `edit` subcommand to provide an interface to interact with your package metadata safely.

### Removed

- Removed _LPM from the `lpm run` environment.
- Removed Type Definitions for _LPM.

## [1.0.1] - 25th Feburary 2024

### Fixed

- Bug preventing temporary files from being removed after building.
