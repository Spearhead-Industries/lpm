local stdio = require("@lune/stdio");
local fs = require("@lune/fs");
local serde = require("@lune/serde");
local process = require("@lune/process");

local util = {};

function util.removable_text(text: string): ()->()
    stdio.write(text);
    return function()
        stdio.write(("\b"):rep(#text));
        stdio.write((" "):rep(#text));
        stdio.write(("\b"):rep(#text));
    end
end

-- NOTE: Unlike standard globs, * will match dotfiles instead of just .*
function util.glob_to_lua_pattern(glob: string): string
    return "^"..glob
        -- Reserved Char Escape
        :gsub("%%", "%%%%")
        :gsub("%.", "%%.")
        :gsub("%(", "%%(")
        :gsub("%)", "%%)")
        :gsub("%+", "%%+")
        :gsub("%-", "%%-")
        :gsub("%^", "%%^")
        :gsub("%$", "%%$")
        -- Conversions
        :gsub("%*%*", ".-")
        :gsub("%*", "[^/\\]-")
        :gsub("%?", "[^/\\]")
        :gsub("%[(.-)(%%%-)(.-)%]", function(a, b, c)
            return "["..a.."-"..c.."]"
        end)
        :gsub("%[(!)(.+)%]", function(a, b)
            return "[^"..b.."]"
        end)
        .."$";
end

type semver = {
    valid: boolean,
    major: number?,
    minor: number?,
    patch: number?,
    prerelease_identifiers: {string}?,
    build_identifiers: {string}?
};
function util.parse_semver(semver: string): semver
    local version_data = {};

    local VERSION_CORE = "%d+%.%d+%.%d+";
    local DOT_SEPERATED_IDENTIFIERS = "[%w.]+";

    version_data.valid = (
        string.match(semver, `^{VERSION_CORE}$`)
        or string.match(semver, `^{VERSION_CORE}%-{DOT_SEPERATED_IDENTIFIERS}$`)
        or string.match(semver, `^{VERSION_CORE}%+{DOT_SEPERATED_IDENTIFIERS}$`)
        or string.match(semver, `^{VERSION_CORE}%-{DOT_SEPERATED_IDENTIFIERS}+{DOT_SEPERATED_IDENTIFIERS}$`)
    ) ~= nil;

    if version_data.valid then
        version_data.major = tonumber(string.match(semver, "^(%d+).*"))
        version_data.minor = tonumber(string.match(semver, "^%d%.(%d+).*"))
        version_data.patch = tonumber(string.match(semver, "^%d%.%d%.(%d+).*"))
        version_data.prerelease_identifiers = (string.match(semver, "^.*%-([%w.]+).*") or ""):split(".");
        version_data.build_identifiers = (string.match(semver, "^.*%+([%w.]+).*") or ""):split(".");

        if version_data.prerelease_identifiers[1] == "" then
            version_data.prerelease_identifiers = nil;
        end

        if version_data.build_identifiers[1] == "" then
            version_data.build_identifiers = nil;
        end
    end

    return version_data;
end

function util.pack_semver(parsed: semver): string
    local semver = "";

    semver ..= tostring(parsed.major) .. ".";
    semver ..= tostring(parsed.minor) .. ".";
    semver ..= tostring(parsed.patch);

    if parsed.prerelease_identifiers then
        semver ..= "-" .. table.concat(parsed.prerelease_identifiers, ".");
    end

    if parsed.build_identifiers then
        semver ..= "+" .. table.concat(parsed.build_identifiers, ".");
    end

    return semver;
end

function util.semver_bump(semver: string, by: "major"|"minor"|"patch", dont_drop_metadata: boolean?): string
    local parsed = util.parse_semver(semver);

    if by == "major" then
        parsed.major += 1;
        parsed.minor = 0;
        parsed.patch = 0;
    elseif by == "minor" then
        parsed.minor += 1;
        parsed.patch = 0;
    elseif by == "patch" then
        parsed.patch += 1;
    end

    if not dont_drop_metadata then
        parsed.prerelease_identifiers = nil;
        parsed.build_identifiers = nil;
    end

    return util.pack_semver(parsed);
end

type package_id = {
    valid: boolean?,
    owner: string?,
    name: string?,
    ref: string?
};

function util.parse_package_id(package_id: string): package_id
    -- <github-author>/<github-name>[@<ref>]

    local CORE = "[%w%-]+/[%w%-_%.]+";
    local REF = "[%w%-%._/]+"

    local parsed = {};

    parsed.valid = (
            string.match(package_id, `^{CORE}$`)
        or string.match(package_id, `^{CORE}@{REF}$`)
    ) ~= nil;

    if parsed.valid then
        parsed.owner = string.match(package_id, "^([%w%-]+).*$");
        parsed.name = string.match(package_id, "^[%w%-]+/([%w%-_%.]+).*$");
        parsed.ref = string.match(package_id, "^[%w%-]+/[%w%-_%.]+@([%w%-%._/]+).*$");
    end

    return parsed;
end

function util.pack_package_id(parsed: package_id): string
    local package_id = "";

    package_id ..= tostring(parsed.owner) .. "/";
    package_id ..= tostring(parsed.name);
    package_id ..= "@"..tostring(parsed.ref);

    return package_id;
end

function util.dir_safe(name: string): string
    local id = util.parse_package_id(name);
    if id.valid then
        name = id.name;
        if id.ref then
            name ..= "@"..id.ref;
        end
    end
    return name:gsub("@", "-v"):gsub("%.", "-");
end

function util.clean_residual()
    local root_package = serde.decode("toml", fs.readFile("./lpm-package.toml"));

    local total_dep = table.clone(root_package.dependencies);
    for alias, id in pairs(root_package.dependencies) do
        local folder = "./lpm_modules/"..util.dir_safe(alias);
        
        if fs.isDir(folder) and fs.isFile(folder.."/lpm-package.toml") then
            local pkg = serde.decode("toml", fs.readFile(folder.."/lpm-package.toml"));
            --print(pkg)
            for als, dep in pairs(pkg.dependencies or {}) do
                total_dep[als] = dep;
            end
        end
    end
    
    for _, name in pairs(fs.readDir("./lpm_modules")) do
        local delete = true;
        
        for alias, _ in pairs(total_dep) do
            if util.dir_safe(alias) == name then
                delete = false;
            end
        end

        if delete then
            print(`  {stdio.color("yellow")}Removed{stdio.color("reset")} residual package {name}.`);
            fs.removeDir("./lpm_modules/"..name)
        end
    end
end

function util.run_script(name: string, ...): number
    if not fs.isFile("./lpm-package.toml") then
        return 1;
    end

    local root_package = serde.decode("toml", fs.readFile("./lpm-package.toml"));

    if root_package.scripts[name] then
        return process.spawn("", {root_package.scripts[name]}, {
            shell = true,
            stdio = "forward"
        }).code;
    elseif fs.isFile("./scripts/"..name..".lua") then
        return require("./scripts/"..name..".lua")(...) or 0;
    else
        if name:sub(1, 2) ~= "__" then
            stdio.ewrite(`Script {name} not found.\n`);
        end
        return 1;
    end
end

function util.get_files(glob: string)
    local flat_files = {};

    local function search_dir(dir)
        if dir == "./.git" then
            return;
        end

        local files = fs.readDir(dir);
        for _, v in pairs(files) do
            local name = dir.."/"..v;
            local md = fs.metadata(name);

            if md.kind == "dir" then
                search_dir(name);
                if string.match(name:sub(2), util.glob_to_lua_pattern(glob)) then
                    table.insert(flat_files, name);
                end
            elseif md.kind == "file" then
                if string.match(name:sub(2), util.glob_to_lua_pattern(glob)) then
                    table.insert(flat_files, name);
                end
            end
        end
    end

    search_dir(".")

    return flat_files;
end

return util;
