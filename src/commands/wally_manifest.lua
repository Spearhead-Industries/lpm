local serde = require("@lune/serde");
local fs = require("@lune/fs")
local util = require("../util");

return function()
    if not fs.isFile("./lpm-package.toml") then
        return;
    end

    local package = serde.decode("toml", fs.readFile("./lpm-package.toml"));

    local wally = {
        package = {
            name = package.name,
            description = package.description,
            verison = package.version,
            license = package.licence,
            authors = package.authors,
            realm = "shared",
            exclude = package.exclude,
            include = package.include
        },
        dependencies = package.dependencies
    };

    local new_dep = {};
    for i, v in pairs(wally.dependencies) do
        local ref = util.parse_package_id(i);
        if ref.valid then
            new_dep[util.dir_safe(i)] = v;
        else
            new_dep[i] = v;
        end
    end
    wally.dependencies = new_dep;

    fs.writeFile("./wally.toml", serde.encode("toml", wally));
    print("Wrote to ./wally.toml");

    return 0;
end
