local stdio = require("@lune/stdio");
local serde = require("@lune/serde");
local process = require("@lune/process");
local fs = require("@lune/fs");

local util = require("../util");

type metadata = {
    name: string,
    version: string,
    licence: string,
    entrypoint: string?,
    description: string?,
    author: string?,
    type: string?
};

local function get_metadata(path: string): metadata?
    if fs.isFile(path.."/lpm-package.toml") then
        local package = serde.decode("toml", fs.readFile(path.."/lpm-package.toml"));

        return {
            name = package.name,
            description = package.description,
            author = package.author,
            entrypoint = package.entrypoint,
            licence = package.licence,
            version = package.version,
            type = "lpm",
            dependencies = package.dependencies,
            exclude = package.exclude or {},
            include = package.include
        };
    elseif fs.isFile(path.."/rotriever.toml") then
        local package = serde.decode("toml", fs.readFile(path.."/rotriever.toml")).package;

        return {
            name = package.name,
            package = package.author,
            entrypoint = package.content_root .. "/init",
            version = package.version,
            licence = package.license,
            type = "rotriever",
            exclude = package.exclude or {},
            include = package.include
        };
    elseif fs.isFile(path.."/wally.toml") then
        local package = serde.decode("toml", fs.readFile(path.."/wally.toml"));

        return {
            name = package.name,
            package = package.author,
            version = package.version,
            licence = package.license,
            type = "wally",
            exclude = package.exclude or {},
            include = package.include
        };
    else
        return nil;
    end
end

return function(argc: number, argv: {string}): number
    if not fs.isFile("./lpm-package.toml") then
        stdio.write("No lpm-package.toml file found.\n");
        return 1;
    end

    local root_package = serde.decode("toml", fs.readFile("./lpm-package.toml"));
    local install_list = table.clone(argv);
    table.remove(install_list, 1);


    if not fs.isDir("./lpm_modules") then
        fs.writeDir("./lpm_modules");
    end

    local function install(dependency: string, add_to_root_dep: boolean, extra: string?)
        local message_prefix = "I";
    

        --// Parse the package identifier into it's compononents.

        local name_componenets = dependency:split("/");
        local author = name_componenets[1];
        local rawname = name_componenets[2];
        
        local ref = rawname:split("@")[2];
        if not ref then
            rawname..="@a"; -- if it works, it works.
        end

        local name = rawname:split("@")[1]


        --// Construct the URL and Dir name.

        local repo_url = "https://github.com/"..author.."/"..name..".git";

        local dir_name = name;
        if ref then
            dir_name = (dir_name.."-v"..ref):gsub("%.", "-");
        end

        
        --// Add the dependency to the package file.

        if not table.find(root_package.dependencies, dependency) and add_to_root_dep then
            table.insert(root_package.dependencies, dependency);
        end

        fs.writeFile("./lpm-package.toml", serde.encode("toml", root_package))


        --// Remove previous version

        if fs.isDir(`./lpm_modules/{dir_name}/`) then
            message_prefix = "Rei";
            fs.removeDir(`./lpm_modules/{dir_name}/`);
        end
    

        --// Notify the user the package is being downloaded.
        
        local remove;
        remove = util.removable_text(
            stdio.color("yellow")
            ..message_prefix
            ..`nstalling{stdio.color("reset")} '{dependency}'`
            .. if extra then ` ({extra})` else ""
        );

        local git_clone_result;
        if ref then
            git_clone_result = process.spawn("git", {"clone", "--depth", "1", repo_url, "--branch", ref, `./lpm_modules/{dir_name}`});
        else
            git_clone_result = process.spawn("git", {"clone", "--depth", "1", repo_url, `./lpm_modules/{dir_name}`});
        end
        
        if not git_clone_result.ok then
            -- Maybe they use `v1.0.0` instead of `1.0.0` for tags?
            git_clone_result = process.spawn("git", {"clone", "--depth", "1", repo_url, "--branch", "v"..ref, `./lpm_modules/{dir_name}`});
        end

        if not git_clone_result.ok then
            remove();
            print(stdio.color("red")..`Failed to download {dependency} from GitHub:`..stdio.color("reset"));
            print(git_clone_result.stderr);

            return;
        else
            fs.removeDir(`./lpm_modules/{dir_name}/.git`);
            local dep_p = get_metadata(`./lpm_modules/{dir_name}/`);

            if dep_p and dep_p.entrypoint then
                fs.writeFile(`./lpm_modules/{dir_name}/init.lua`, `return require("{dep_p.entrypoint}")`);
            else
                extra = "no package file found, use with caution"..(extra and "; "..extra or "");
            end
            
            remove();
            print(
                stdio.color("green")
                ..message_prefix
                ..`nstalled{stdio.color("reset")} '{dependency}'`
                .. if extra then ` ({extra})` else ""
            );

            local exclude = (dep_p or {}).exclude or {};

            for i, v in pairs(exclude) do
                local path = `./lpm_modules/{dir_name}/`..v:gsub("%.%.", ".");
                --print(path);
                if fs.isFile(path) or fs.isDir(path) then
                    if fs.isFile(path) then
                        fs.removeFile(path);
                    else
                        fs.removeDir(path);
                    end
                end
            end

            for i, v in pairs((dep_p or {}).dependencies or {}) do
                local already_have = table.find(root_package.dependencies, v);
                if not already_have then
                    install(v, false, `dependency of '{dependency}'`);
                end
            end
        end
    end

    if #install_list > 0 then
        for _, dependency in pairs(install_list) do
            install(dependency, true);
        end
    else -- Install project dependencies
        for _, dependency in pairs(root_package.dependencies or {}) do
            install(dependency, false);
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
