local fs = require("@lune/fs");
local serde = require("@lune/serde");

return function()
    if fs.isFile("./lpm-package.toml") then
        local package = serde.decode("toml", fs.readFile("./lpm-package.toml"));
        

        --// Fix old author into new authors. 
        
        if package.author then
            package.authors = package.author:split(";");
        end
        package.author = nil;


        fs.writeFile("./lpm-package.toml", package);
    end
end