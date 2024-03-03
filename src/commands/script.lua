local fs = require("@lune/fs");
local stdio = require("@lune/stdio");
local serde = require("@lune/serde");

local util = require("../util");

return function(argc: number, argv: {string}): number
    if not fs.isFile("./lpm-package.toml") then
        stdio.write("No lpm-package.toml file found.\n");
        return 1;
    end

    local subcommand = argv[2];

    if subcommand == "new" then
        local name = argv[3];
        if not name then
            stdio.ewrite("Specify script name.\n");
            return 1;
        end

        fs.writeDir("./scripts/")
        fs.writeFile("./scripts/"..name..".lua", "return function(arg1, arg2)\n\tprint(\"Hello, World\");\n\n\treturn 0; -- 0 = Success, anything else = fail.\nend\n");

        stdio.write(`Created lua script '{name}'. If you intended to create a shell script, remove the lua script and edit lpm-package.toml.\n`);
        return 0;
    elseif subcommand == "run" then
        local name = argv[3];
        if not name then
            stdio.ewrite("Specify script name.\n");
            return 1;
        end

        return util.run_script(name, select(4, unpack(argv)));
    end
    
    return 0;
end