local stdio = require("@lune/stdio");
local serde = require("@lune/serde");
local process = require("@lune/process");
local fs = require("@lune/fs");

return function(argc: number, argv: {string}): number
    if not fs.isFile("./lpm-package.toml") then
        stdio.write("No lpm-package.toml file found.\n");
        return 1;
    end


    --// Create a patched process builtin with new argv information.

    local new_argv = {};
    for i, v in ipairs(argv) do -- Shift 'lpm run' down.
        new_argv[-1] = v;
    end

    local patched_process = {};
    for i, v in pairs(process) do
        patched_process[i] = v;
    end

    table.freeze(new_argv);
    
    patched_process.args = new_argv;

    
    --// Get package entrypoint and begin execution.

    local package = serde.decode("toml", fs.readFile("./lpm-package.toml"));

    if package.entrypoint and fs.isFile(package.entrypoint) then    
        require(package.entrypoint); -- Consider converting to a lune run call. Issues with stdin however.
    else
        stdio.write("Entrypoint does not exist.");
        return 1;
    end

    return 0;
end