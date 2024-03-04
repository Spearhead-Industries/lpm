local is_lunelpm, lpm = pcall(require, "@lune/lpm");
assert(is_lunelpm, `This must be built with Spearhead-Industries/lune-lpm, not lune-org/lune: {lpm}`);
assert(lpm.is_lpm_standalone(), "Do not run lpm with the run command, build as a standalone instead.");

local VERSION = "1.4.1";
_G.VERSION = VERSION;

local process = require("@lune/process");
local stdio = require("@lune/stdio");

local util = require("./util");

function main(argc: number, argv: {string}): number
    local subcommand = argv[1];

    (require("./commands/fix_compatability"))(".");

    util.run_script("__precli");

    if subcommand == "run" then -- Run the application.
        return (require("./commands/run"))(argc, argv);

    elseif subcommand == "test" then -- Test the application.

    elseif subcommand == "wally" then -- Test the application.
        return (require("./commands/wally_manifest"))();

    elseif subcommand == "script" then -- Test the application.
        return (require("./commands/script"))(argc, argv);

    elseif subcommand == "build" then -- Build the application.
        return (require("./commands/build"))(argc, argv);

    elseif subcommand == "edit" then
        return (require("./commands/edit"))(argc, argv);

    elseif subcommand == "install" or subcommand == "i" then -- Install a dependency library.
        return (require("./commands/install"))(argc, argv);

    elseif subcommand == "uninstall" then -- Uninstall a dependency
        return (require("./commands/uninstall"))(argc, argv);

    elseif subcommand == "init" then -- Create the application.
        return (require("./commands/init"))(argc, argv);

    elseif subcommand == "version" then
        stdio.write(`{stdio.color("blue")}Spearhead-Industries{stdio.color("reset")}/{stdio.color("yellow")}lpm{stdio.color("reset")} v{VERSION}`);

    elseif argc == 0 or subcommand == "help" then
        stdio.write(`{stdio.color("blue")}Spearhead-Industries{stdio.color("reset")}/{stdio.color("yellow")}lpm{stdio.color("reset")} v{VERSION}`);

    else
        stdio.ewrite("Unknown command: "..subcommand);
        return 1;
    end

    return 0;
end

process.exit(main(#process.args, process.args));
