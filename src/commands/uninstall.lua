local stdio = require("@lune/stdio");
local serde = require("@lune/serde");
local fs = require("@lune/fs");

local util = require("../util");

return function(argc: number, argv: {string}): number
    if not fs.isFile("./lpm-package.toml") then
        stdio.write("No lpm-package.toml file found.\n");
        return 1;
    end

    local uninstall_list = table.clone(argv);
    table.remove(uninstall_list, 1);

    local root_package = serde.decode("toml", fs.readFile("./lpm-package.toml"));

    for _, to_uninstall in pairs(uninstall_list) do
        local removed = false;
        
        local i;

        for j, v in pairs(root_package.dependencies) do
            if v == to_uninstall then
                i = j;
            end
        end

        if i then
            removed = true;
            root_package.dependencies[i] = nil;
        end

        fs.writeFile("./lpm-package.toml", serde.encode("toml", root_package));

        local folder_name = to_uninstall:split("/")[2]:gsub("@", "-v"):gsub("%.", "-");
        if fs.isDir("./lpm_modules/"..folder_name) then
            removed = true;
            fs.removeDir("./lpm_modules/"..folder_name);
        end

        if removed then
            print("Uninstalled "..to_uninstall);
        else
            print(`Couldn't find '{to_uninstall}' to uninstall.`);
        end
    end

    util.clean_residual();

    return 0;
end
