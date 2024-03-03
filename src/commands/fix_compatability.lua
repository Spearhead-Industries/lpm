local fs = require("@lune/fs");
local serde = require("@lune/serde");

return function(path)
    if fs.isFile(path.."/lpm-package.toml") then
        local package = serde.decode("toml", fs.readFile(path.."/lpm-package.toml"));
        

        --// Fix old author into new authors. 
        
        if package.author then
            package.authors = package.author:split(";");
        end
        if #package.authors == 1 and package.authors[1] == "" then
            package.authors = {package.author}
        end
        package.author = nil;


        --// Fix old dependencies

        local new_dep = {};
        for i, v in pairs(package.dependencies) do
            if typeof(i) == "number" then
                new_dep[v] = v;
            else
                new_dep[i] = v;
            end
        end
        package.dependencies = new_dep;

        
        --// Add scripts
        
        package.scripts = package.scripts or {};


        --// Out

        fs.writeFile(path.."/lpm-package.toml", serde.encode("toml", package));
    end
end