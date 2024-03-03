local stdio = require("@lune/stdio");
local serde = require("@lune/serde");
local process = require("@lune/process");
local fs = require("@lune/fs");
local lpm = require("@lune/lpm");
local net = require("@lune/net");
local luau = require("@lune/luau");

local darklua_conf = [[{"bundle": {"require_mode": {"name":"path", "sources":{"@lpm":"./lpm_modules/"}, "module_folder_name":"init"},"excludes": ["@lune/**"]},"rules": []}]];

local util = require("../util");

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
    

local function remove_lpm_bytecode(binary: string): string
    local lpm_blocks = {};
    for len_raw in string.gmatch(binary, "(........)LPMBLOCK") do
        table.insert(lpm_blocks, len_raw);
    end
    local len = string.unpack(">I8", lpm_blocks[#lpm_blocks]) + 8 + 8;
    local i = string.find(binary, lpm_blocks[#lpm_blocks].."LPMBLOCK");
    local bottom, top  = i - len, i + 8 + 8;
    binary = string.sub(binary, 1, bottom) ..string.sub(binary, top);
    return binary;
end

return function(argc: number, argv: {string}): number
    if not fs.isFile("./lpm-package.toml") then
        stdio.write("No lpm-package.toml file found.\n");
        return 1;
    end

    util.run_script("__prebuild");

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
        pcall(function()
            binary = remove_lpm_bytecode(binary);
        end)

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

            fs.writeFile(`./out/{package.name}-linux-aarch64`, remove_lpm_bytecode(linux_aarch64.body));
            fs.writeFile(`./out/{package.name}-linux-x86_64`, remove_lpm_bytecode(linux_x86_64.body));
            fs.writeFile(`./out/{package.name}-windows-x86_64.exe`, remove_lpm_bytecode(windows_x86_64.body));
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

    util.run_script("__postbuild");

    return 0;
end