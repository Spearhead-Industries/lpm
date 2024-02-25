local stdio = require("@lune/stdio");
local serde = require("@lune/serde");
local process = require("@lune/process");
local fs = require("@lune/fs");

local darklua_conf = [[{"bundle": {"require_mode": {"name":"path", "sources":{"@lpm":"./lpm_modules/"}, "module_folder_name":"init"},"excludes": ["@lune/**"]},"rules": []}]];

return function(argc: number, argv: {string}): number
    if not fs.isFile("./lpm-package.toml") then
        stdio.write("No lpm-package.toml file found.\n");
        return 1;
    end

    local package = serde.decode("toml", fs.readFile("./lpm-package.toml"));

    if package.entrypoint and fs.isFile(package.entrypoint) then
        --// Preamble //--

        local EXT = if process.os == "windows" then ".exe" else "";
        local BINARY_NAME = `./out/{package.name}`..EXT;
        local ARCHIVE_NAME = `./out/{package.name}-{process.os}-{process.arch}.zip`;

        local function run(cmd: string)
            local parts = cmd:split(" ");
            local app = parts[1];
            table.remove(parts, 1);

            process.spawn(app, parts, {
                stdio = "forward"
            });
        end

        local function check(cmd: string, arg: string)
            assert(process.spawn(cmd, {arg}).ok, `{cmd} must be installed.`);
        end


        --// Check Env //--

        check("lune", "--version");
        check("darklua", "--version");

        if process.os == "windows" then
            check("powershell", "-Help");
        else
            check("zip", "--version");
        end


        --// Build Steps //--

        if fs.isDir("./out") then
            fs.removeDir("./out");
        end

        fs.writeDir("./out");

        fs.writeFile("./lpm_build_conf.json", darklua_conf);

        run(`darklua process -c ./lpm_build_conf.json {package.entrypoint} ./out/bundled.lua`);
        run(`lune build ./out/bundled.lua -o {BINARY_NAME}`);

        fs.readFile("./lpm_build_conf.json");

        if table.find(process.args, "--mkarchive") ~= nil then
            if process.os == "windows" then
                run(`powershell Compress-Archive {BINARY_NAME} {ARCHIVE_NAME} -Force`)
            else
                run(`zip -r {BINARY_NAME} {ARCHIVE_NAME}`);
            end
        end
    else
        stdio.write("Entrypoint does not exist.");
        return 1;
    end

    return 0;
end