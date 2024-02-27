--// Preamble //--

local process = require("@lune/process");
local fs = require("@lune/fs");
local lpm = require("@lune/lpm");
local luau = require("@lune/luau");

local EXT = if process.os == "windows" then ".exe" else "";
local BINARY_NAME = "./out/lpm"..EXT;
local ARCHIVE_NAME = `./out/lpm-{process.os}-{process.arch}.zip`;

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

run("darklua process -c ./darklua.json ./src/main.lua ./out/bundled.lua");
local compiled = luau.compile(fs.readFile("./out/bundled.lua"), {
    optimizationLevel = 2,
    debugLevel = 0,
    coverageLevel = 0
});

local binary = lpm.create_binary(compiled, true);
fs.writeFile(BINARY_NAME, binary);

--run(`lune build ./out/bundled.lua -o {BINARY_NAME}`);

if table.find(process.args, "--noarchive") == nil then
    if process.os == "windows" then
        run(`powershell Compress-Archive {BINARY_NAME} {ARCHIVE_NAME} -Force`)
    else
        run(`zip -r {BINARY_NAME} {ARCHIVE_NAME}`);
    end
end