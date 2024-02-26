local stdio = require("@lune/stdio");
local serde = require("@lune/serde");
local fs = require("@lune/fs");
local process = require("@lune/process");

return function(argc: number, argv: {string}): number
    if not fs.isFile("./lpm-package.toml") then
        stdio.ewrite("No lpm-package.toml file found.\n");
        return 1;
    end

    local package = serde.decode("toml", fs.readFile("./lpm-package.toml"));

    local function commit()
        fs.writeFile("./lpm-package.toml", serde.encode("toml", package));
    end

    local cmds = {
        ["version"] = function()
            package.version = stdio.prompt("text", "New Version:", package.version);
            commit();
        end,

        ["name"] = function()
            package.name = stdio.prompt("text", "New Version:", package.name);
            commit();
        end,

        ["description"] = function()
            package.description = stdio.prompt("text", "New Description:", package.description);
            commit();
        end,

        ["authors"] = function()
            package.author = stdio.prompt("text", "New Author(s):", package.author);
            commit();
        end,

        ["licence"] = function()
            package.licence = stdio.prompt("text", "New Licence:", package.licence);
            commit();
        end,

        ["git-repo"] = function()
            local repo = process.spawn("git", {"config", "--get", "remote.origin.url"});

            if repo.ok then
                repo = repo.stdout:gsub("%s", "");
            else
                repo = nil;
            end

            package.repository = stdio.prompt("text", "New Git Repo:", repo or package.repository);
            commit();
        end,
    };

    local cmds_idx = {};

    for i, _ in pairs(cmds) do
        table.insert(cmds_idx, i);
    end

    local command = argv[2] or cmds_idx[stdio.prompt("select", "What would you like to do?", cmds_idx)];

    local func = cmds[command];
    
    if func then
        return func() or 0;
    else 
        stdio.ewrite("Unknown command");
        return 1;
    end
end