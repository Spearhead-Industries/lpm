local stdio = require("@lune/stdio");
local serde = require("@lune/serde");
local process = require("@lune/process");
local fs = require("@lune/fs");

return function(argc: number, argv: {string}): number
    if not fs.isFile("./lpm-package.toml") then
        stdio.write("No lpm-package.toml file found.\n");
        return 1;
    end

    local dependencies = table.clone(argv);
    table.remove(dependencies, 1);

    local package = serde.decode("toml", fs.readFile("./lpm-package.toml"));

    for _, dependency in pairs(dependencies) do
        local removed = false;
        local i = table.find(package.dependencies, dependency);

        if i then
            removed = true;
            table.remove(package.dependencies, i);
        end

        fs.writeFile("./lpm-package.toml", serde.encode("toml", package));

        local folder_name = dependency:split("/")[2]:gsub("@", "-v"):gsub("%.", "-");
        if fs.isDir("./lpm_modules/"..folder_name) then
            removed = true;
            fs.removeDir("./lpm_modules/"..folder_name);
        end

        if removed then
            print("Uninstalled "..dependency);
        else
            print(`Couldn't find '{dependency}' to uninstall.`);
        end
    end


    return 0;
end
