local stdio = require("@lune/stdio");
local serde = require("@lune/serde");
local process = require("@lune/process");
local fs = require("@lune/fs");

local function nil_if_empty(text: string): string?
    if text == "" then
        return nil; 
    else
        return text;
    end
end

return function(argc: number, argv: {string}): number
    if not fs.isFile("./lpm-package.toml") then
        stdio.write("No lpm-package.toml file found.\n");
        return 1;
    end

    local package = serde.decode("toml", fs.readFile("./lpm-package.toml"));

    if package.entrypoint and fs.isFile(package.entrypoint) then
        --[[process.spawn("lune", {"run", package.entrypoint}, {
            stdio = "forward"
        });]]

        local env = getfenv();
        env._LPM = package;

        require(package.entrypoint);
    else
        stdio.write("Entrypoint does not exist.");
        return 1;
    end

    return 0;
end