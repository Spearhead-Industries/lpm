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

    if not fs.isDir("./lpm_modules") then
        fs.writeDir("./lpm_modules");
    end

    local function install(dependency: string, add: boolean)
        local reinstalling = "I";
    
        local author = dependency:split("/")[1];
        local rawname = dependency:split("/")[2];
        
        local ref = rawname:split("@")[2]
        if not ref then
            rawname..="@a";
        end
        local name = rawname:split("@")[1]

        local path = "https://github.com/"..author.."/"..name..".git";

        local folder_name = name;
        if ref then
            folder_name = (folder_name.."-v"..ref):gsub("%.", "-");
        end
        
        if not table.find(package.dependencies, dependency) and add then
            table.insert(package.dependencies, dependency);
        end

        fs.writeFile("./lpm-package.toml", serde.encode("toml", package))
    
        if fs.isDir(`./lpm_modules/{folder_name}/`) then
            reinstalling = "Rei";
            fs.removeDir(`./lpm_modules/{folder_name}/`);
        end
    
        local init = stdio.color("yellow")..reinstalling..`nstalling{stdio.color("reset")} '{dependency}'`;
        stdio.write(init);
    
        local git
        if ref then
            git = process.spawn("git", {"clone", "--depth", "1", path, "--branch", ref, `./lpm_modules/{folder_name}`});
        else
            git = process.spawn("git", {"clone", "--depth", "1", path, `./lpm_modules/{folder_name}`});
        end
        
        if not git.ok then
            stdio.write(("\b"):rep(#init));
            print(stdio.color("red")..`Failed to install {dependency}:        `)
            warn(git.stderr);
        else
            fs.removeDir(`./lpm_modules/{folder_name}/.git`);
            local dep_p = serde.decode("toml", fs.readFile(`./lpm_modules/{folder_name}/lpm-package.toml`));
            fs.writeFile(`./lpm_modules/{folder_name}/init.lua`, `return require("{dep_p.entrypoint}")`);
            stdio.write(("\b"):rep(#init));
            print(stdio.color("green")..reinstalling..`nstalled{stdio.color("reset")} '{dependency}'      `);

            for i, v in pairs(dep_p.dependencies or {}) do
                if not table.find(package.dependencies, v) then
                    install(v, false);
                else
                    print("Skipped dependency "..v.." as we already have it.");
                end
            end
        end
    end

    if #dependencies > 0 then
        for _, dependency in pairs(dependencies) do
            install(dependency, true);
        end
    else -- Install project dependencies
        for _, dependency in pairs(package.dependencies or {}) do
            install(dependency, false);
        end
    end

    return 0;
end
