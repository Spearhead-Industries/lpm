local stdio = require("@lune/stdio");
local serde = require("@lune/serde");
local process = require("@lune/process");
local fs = require("@lune/fs");
local lpm = require("@lune/lpm");
local net = require("@lune/net");
local luau = require("@lune/luau");

local darklua_conf = [[{"bundle": {"require_mode": {"name":"path", "sources":{"@lpm":"./lpm_modules/"}, "module_folder_name":"init"},"excludes": ["@lune/**"]},"rules": []}]];


local function run(cmd: string)
    local parts = cmd:split(" ");
    local app = parts[1];
    table.remove(parts, 1);
    
    process.spawn(app, parts, {
        stdio = "forward"
    });
end

local function compress(a: string, b: string)
    if process.os == "windows" then
        run(`powershell Compress-Archive {b} {a} -Force`)
    else
        run(`zip {a} {b}`);
    end
end

local function check(cmd: string, arg: string)
    assert(process.spawn(cmd, {arg}).ok, `{cmd} must be installed.`);
end
    

return function(argc: number, argv: {string}): number
    if not fs.isFile("./lpm-package.toml") then
        stdio.write("No lpm-package.toml file found.\n");
        return 1;
    end

    local package = serde.decode("toml", fs.readFile("./lpm-package.toml"));

    if package.entrypoint and fs.isFile(package.entrypoint) then
        local EXT = if process.os == "windows" then ".exe" else "";
        local BINARY_NAME = `./out/{package.name}`..EXT;
        local ARCHIVE_NAME = `./out/{package.name}-{process.os}-{process.arch}.zip`;

        --check("lune", "--version");
        check("darklua", "--version");

        if process.os == "windows" then
            check("powershell", "-Help");
        else
            check("zip", "--version");
        end

        if fs.isDir("./out") then
            fs.removeDir("./out");
        end

        fs.writeDir("./out");

        fs.writeFile("./lpm_build_conf.json", darklua_conf);

        run(`darklua process -c ./lpm_build_conf.json {package.entrypoint} ./out/bundled.lua`);
        
        local bytecode = luau.compile(fs.readFile("./out/bundled.lua"));
        local binary = lpm.create_binary(bytecode);
        fs.writeFile(BINARY_NAME, binary);
        
        fs.removeFile("./lpm_build_conf.json");

        if table.find(process.args, "--release") ~= nil then
            local linux_aarch64 = net.request({
                url = `https://github.com/Spearhead-Industries/lpm/releases/download/{_G.VERSION}/lpm-linux-aarch64`;
            });

            local linux_x86_64 = net.request({
                url = `https://github.com/Spearhead-Industries/lpm/releases/download/{_G.VERSION}/lpm-linux-x86_64`;
            });

            local windows_x86_64 = net.request({
                url = `https://github.com/Spearhead-Industries/lpm/releases/download/{_G.VERSION}/lpm-windows_x86_64.exe`;
            });

            fs.writeFile(`./out/{package.name}-linux-aarch64`, linux_aarch64);
            fs.writeFile(`./out/{package.name}-linux-x86_64`, linux_x86_64);
            fs.writeFile(`./out/{package.name}-windows-x86_64.exe`, windows_x86_64);
            compress(`./out/{package.name}-linux-aarch64`, `./out/{package.name}-linux-aarch64.zip`);
            compress(`./out/{package.name}-linux-x86_64`, `./out/{package.name}-linux-x86_64.zip`);
            compress(`./out/{package.name}-windows-x86_64.exe`, `./out/{package.name}-windows-x86_64.zip`);
        else
            if table.find(process.args, "--mkarchive") ~= nil then
                compress(ARCHIVE_NAME, BINARY_NAME);
            end
        end
    else
        stdio.write("Entrypoint does not exist.");
        return 1;
    end

    return 0;
end