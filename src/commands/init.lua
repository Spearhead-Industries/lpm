local stdio = require("@lune/stdio");
local serde = require("@lune/serde");
local process = require("@lune/process");
local fs = require("@lune/fs");

local function nil_if_empty(text: string): string?
    if text == "" then
        return nil; 
    else
        return text;
    end
end

local tdef;
if process.os == "windows" then
    tdef = process.env["USERPROFILE"]..`/.lpm/.typedefs/`;
else
    tdef = `~/.lpm/.typedefs/`;
end

local function dedent(text: string): string
    --local padding = text:match("^(%w+)%W");
    return text;
end

return function(argc: number, argv: {string}): number
    if fs.isFile("./lpm-package.toml") then
        if stdio.prompt("confirm", "There is already an lpm-package.toml file, would you like to replace it?") then
            fs.removeFile("./lpm-package.toml")
        else
            return 0;
        end

    end

    local dir = process.cwd:gsub("\\", "/"):split("/");
    dir = dir[#dir-1];

    local package_file = {};

    package_file.name = stdio.prompt("text", "Package Name", dir);
    package_file.version = stdio.prompt("text", "Version", "1.0.0");
    package_file.description = stdio.prompt("text", "Description");
    package_file.entrypoint = stdio.prompt("text", "Entrypoint", "./src/main.lua");
    package_file.repository = stdio.prompt("text", "Git Repository");
    package_file.author = stdio.prompt("text", "Author(s)");
    package_file.licence = stdio.prompt("text", "Licence", "MIT");
    package_file.dependencies = {};

    local file = serde.encode("toml", package_file);

    stdio.write("\nPackage File:\n\n");
    print(file);

    if not stdio.prompt("confirm", "Is this correct") then
        return 0;
    end
   
    file = "# Autogenerated by Spearhead-Industries/lpm\n\n" .. file;

    fs.writeFile("./lpm-package.toml", file);
    process.spawn("lune", {"setup"});
    
    if not fs.isDir(tdef.."/".._G.VERSION) then
        fs.writeDir(tdef.."/".._G.VERSION);
    end

    fs.writeFile(`{tdef}{_G.VERSION}/def.d.lua`, dedent([[
        declare _LPM: {
            name: string,
            version: string,
            description: string,
            entrypoint: string,
            repository: string,
            author: string,
            licence: string
        };
    ]]));

    if not fs.isFile("./.gitignore") then
        fs.writeFile("./.gitignore", "");
    end

    local gi = fs.readFile("./.gitignore");
    if string.find(gi, "# LPM") == nil then
        fs.writeFile("./.gitignore", gi.."\n\n# LPM\n\n/out\n/lpm_modules");
    end
    -- luaurc --
    if not fs.isFile("./.luaurc") then
        fs.writeFile("./.luaurc", "{}");
    end

    local luaurc = serde.decode("json", fs.readFile("./.luaurc"));
    luaurc.aliases = luaurc.aliases or {};
    luaurc.aliases["lpm"] = "./lpm_modules/"
    fs.writeFile("./.luaurc", serde.encode("json", luaurc, true))

    -- vscode settings --
    local vscode_settings = serde.decode("json", fs.readFile("./.vscode/settings.json"));
    vscode_settings["luau-lsp.require.directoryAliases"]["@lpm/"] = "./lpm_modules/";
    vscode_settings["luau-lsp.types.definitionFiles"] = vscode_settings["luau-lsp.types.definitionFiles"] or {};

    local pfx = if process.os == "windows" then process.env["USERPROFILE"] else "~";
    table.insert(vscode_settings["luau-lsp.types.definitionFiles"], `{pfx}/.lpm/.typedefs/{_G.VERSION}/def.d.lua`);
    fs.writeFile("./.vscode/settings.json", serde.encode("json", vscode_settings, true))

    return 0;
end