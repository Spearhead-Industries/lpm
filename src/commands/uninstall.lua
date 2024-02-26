local stdio = require("@lune/stdio");
local serde = require("@lune/serde");
local fs = require("@lune/fs");

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
        local i = table.find(root_package.dependencies, to_uninstall);

        if i then
            removed = true;
            table.remove(root_package.dependencies, i);
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

    local total_dep = root_package.dependencies;

    for _, v in pairs(root_package.dependencies) do
        v = v:gsub("%.", "-"):gsub("@", "-v"):gsub("/", "sSDGSDJG", 1):split("sSDGSDJG")[2];
        if fs.isDir("./lpm_modules/"..v) and fs.isFile("./lpm_modules/"..v.."/lpm-package.toml") then
            local pkg = serde.decode("toml", fs.readFile("./lpm_modules/"..v.."/lpm-package.toml"));
            for _, dep in pairs(pkg.dependencies or {}) do
                table.insert(total_dep, dep);
            end
        end
    end

    for _, v in pairs(fs.readDir("./lpm_modules")) do
        local delete = true;

        for _, dep in pairs(total_dep) do
            local dir = dep:gsub("%.", "-"):gsub("@", "-v"):gsub("/", "sSDGSDJG", 1):split("sSDGSDJG")[2];
            if v == dir then
                delete = false;
            end
        end

        if delete then
            print(`Removed residual package {v}.`);
            fs.removeDir("./lpm_modules/"..v)
        end
    end

    return 0;
end
