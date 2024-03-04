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

    table.remove(process.args, 1)
    table.freeze(process.args);

    --table.clear(process.args);
    --for i, v in pairs(new_argv)
    
    --// Get package entrypoint and begin execution.

    local package = serde.decode("toml", fs.readFile("./lpm-package.toml"));

    if package.entrypoint and fs.isFile(package.entrypoint) then    
        local main = require(package.entrypoint); -- Consider converting to a lune run call. Issues with stdin however.
        if main and typeof(main) == "function" then
            return main(#process.args, process.args);
        end
    else
        stdio.write("Entrypoint does not exist.");
        return 1;
    end

    return 0;
end