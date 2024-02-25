--// Preamble //--

local process = require("@lune/process");
local fs = require("@lune/fs");

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
run(`lune build ./out/bundled.lua -o {BINARY_NAME}`);

if table.find(process.args, "--noarchive") == nil then
    if process.os == "windows" then
        run(`powershell Compress-Archive {BINARY_NAME} {ARCHIVE_NAME} -Force`)
    else
        run(`zip -r {BINARY_NAME} {ARCHIVE_NAME}`);
    end
end