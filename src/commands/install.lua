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
    local args = table.clone(argv);
    table.remove(args, 1);

    local install_list = {};

    for i, v in pairs(args) do
        if v:match("^.-=.-$") ~= nil then
            table.insert(install_list, {
                dep = v:match("^(.-)=.-$"),
                alias = v:match("^.-=(.-)$");
            });
        else
            table.insert(install_list, {
                dep = v,
                alias = v;
            });
        end
    end


    if not fs.isDir("./lpm_modules") then
        fs.writeDir("./lpm_modules");
    end

    local function install(dependency: string, add_to_root_dep: boolean, extra: string?, alias: string?)
        for i, v in pairs(root_package.dependencies) do
            if i == alias and v ~= dependency then
                print(`  {stdio.color("red")}Skipped{stdio.color("reset")} '{dependency}' (already a package aliased to {alias})`)
                return;
            end
        end

        for i, v in pairs(root_package.dependencies) do
            if i ~= alias and v == dependency and alias ~= nil then
                print(`  {stdio.color("red")}Skipped{stdio.color("reset")} '{dependency}' (already installed as {alias})`)
                return;
            end
        end

        local message_prefix = "  I";

        --// Parse the package identifier into it's compononents.

        local identifier = util.parse_package_id(dependency);
        local owner = identifier.owner;
        local name = identifier.name;
        local ref = identifier.ref;
        

        --// Construct the URL and Dir name.

        local repo_url = "https://github.com/"..owner.."/"..name..".git";

        local dir_name = alias or util.dir_safe(dependency);
        --print(alias, dir_name)

        
        --// Add the dependency to the package file.

        local is_dependency = false;

        for _, v in pairs(root_package.dependencies) do
            if v == dependency then
                is_dependency = true;
            end
        end

        if not is_dependency then
            root_package.dependencies[alias or dependency] = dependency;
        end

        fs.writeFile("./lpm-package.toml", serde.encode("toml", root_package))


        --// Remove previous version

        if fs.isDir(`./lpm_modules/{dir_name}/`) then
            message_prefix = "  Rei";
            fs.removeDir(`./lpm_modules/{dir_name}/`);
        end
    

        --// Notify the user the package is being downloaded.

        local remove;
        remove = util.removable_text(
            stdio.color("blue")
            ..message_prefix
            ..`nstalling{stdio.color("reset")} '{dependency}'`
            .. if alias ~= dependency and alias ~= nil then ` as {alias}` else ""
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

            local include = (dep_p or {}).include or {"**"};
            table.insert(include, "lpm-package.toml");

            local exclude = (dep_p or {}).exclude or {};

            local files_to_include = {};

            for i, v in pairs(include) do
                for _, file in pairs(util.get_files(`/lpm_modules/{dir_name}/{v}`)) do
                    table.insert(files_to_include, file);
                end
            end

            for i, v in pairs(util.get_files(`/lpm_modules/{dir_name}/**`)) do
                if not table.find(files_to_include, v) then
                    --print("I would remove", v)
                    if fs.isFile(v) then 
                        fs.removeFile(v);
                    elseif fs.isDir(v) then
                        fs.removeDir(v);
                    end
                end
            end

            for i, v in pairs(exclude) do
                for _, file in pairs(util.get_files(`/lpm_modules/{dir_name}/{v}`)) do
                    --print("I would remove", file)
                    if fs.isFile(file) then 
                        fs.removeFile(file);
                    elseif fs.isDir(file) then
                        fs.removeDir(file);
                    end
                end
            end

            if dep_p and dep_p.entrypoint then
                fs.writeFile(`./lpm_modules/{dir_name}/init.lua`, `return require("{dep_p.entrypoint}")`);
            else
                extra = "no package file found, use with caution"..(extra and "; "..extra or "");
            end

            (require("../commands/fix_compatability"))(`./lpm_modules/{dir_name}/`);
            
            remove();
            print(
                stdio.color("green")
                ..message_prefix
                ..`nstalled{stdio.color("reset")} '{dependency}'`
                .. if alias ~= dependency and alias ~= nil then ` as {alias}` else ""
                .. if extra then ` ({extra})` else ""
            );

            for i, v in pairs((dep_p or {}).dependencies or {}) do
                local already_have = table.find(root_package.dependencies, v);
                if not already_have then
                    install(v, false, `dependency of '{dependency}'`);
                end
            end
        end
    end

    if #install_list > 0 then
        for _, info in pairs(install_list) do
            local dependency = info.dep;
            local alias = info.alias;
            install(dependency, true, nil, if alias == dependency then nil else alias);
        end
    else -- Install project dependencies
        util.run_script("__setup");
        for alias, dependency in pairs(root_package.dependencies or {}) do
            install(dependency, false, nil, if alias == dependency then nil else alias);
        end
    end

    util.clean_residual();

    return 0;
end
