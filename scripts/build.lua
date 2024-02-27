--// Preamble //--

local process = require("@lune/process");
local fs = require("@lune/fs");
local luau = require("@lune/luau");

local EXT = if process.os == "windows" then ".exe" else "";
local BINARY_NAME = "./out/lpm"..EXT;
local ARCHIVE_NAME = `./out/lpm-{process.os}-{process.arch}.zip`;

local function run(cmd: string, cwd: string?)
    local parts = cmd:split(" ");
    local app = parts[1];
    table.remove(parts, 1);

    process.spawn(app, parts, {
        stdio = "forward",
        cwd = cwd
    });
end

local function check(cmd: string, arg: string)
    assert(process.spawn(cmd, {arg}).ok, `{cmd} must be installed.`);
end


--// Check Env //--

--check("lune", "--version");
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

if table.find(process.args, "--pull") ~= nil or not fs.isDir("./lune") then
    if fs.isDir("./lune") then
        fs.removeDir("./lune");
    end

    run("git clone https://github.com/lune-org/lune.git");
    fs.removeDir("./lune/.git")
    run("git apply ../lune.patch", "./lune");
    run("git rm --cached ./lune -f");
end

if table.find(process.args, "--rebuild") ~= nil or not fs.isDir("./lune/target") then
    if table.find(process.args, "--release") == nil then
        run("cargo build", "./lune")
    else
        run("cargo build -r --target x86_64-pc-windows-gnu", "./lune");
        run("cargo build -r --target x86_64-unknown-linux-gnu", "./lune");
        run("cargo build -r --target aarch64-unknown-linux-gnu", "./lune");
        --run("cargo build -r --target x86_64-apple-darwin", "./lune");
        --run("cargo build -r --target aarch64-apple-darwin", "./lune");
    end
end

local bytecode = luau.compile(fs.readFile("./out/bundled.lua"));
local append = string.pack(`>c{#bytecode}i8`, bytecode, #bytecode).."cr3sc3nt";

if table.find(process.args, "--release") == nil then
    local binary = fs.readFile("./lune/target/debug/lune"..EXT);
    binary..=append;
    fs.writeFile("./out/lpm.exe", binary)
else
    local function finalise(a: string, b: string, c: string)
        local binary = fs.readFile(`./lune/target/{a}`);
        binary..=append;
        fs.writeFile(`./out/{b}`, binary)

        if process.os == "windows" then
            run(`powershell Compress-Archive ./out/{b} ./out/{c} -Force`)
        else
            run(`zip ./out/{c} ./out/{b}`);
        end
    end

    finalise("x86_64-pc-windows-gnu/release/lune.exe", "lpm-windows-x86_64.exe", "lpm-windows-x86_64.zip");
    finalise("x86_64-unknown-linux-gnu/release/lune", "lpm-linux-x86_64", "lpm-linux-x86_64.zip");
    finalise("aarch64-unknown-linux-gnu/release/lune", "lpm-linux-aarch64", "lpm-linux-aarch64.zip")
end

--[[if table.find(process.args, "--noarchive") == nil then
    if process.os == "windows" then
        run(`powershell Compress-Archive {BINARY_NAME} {ARCHIVE_NAME} -Force`)
    else
        run(`zip -r {BINARY_NAME} {ARCHIVE_NAME}`);
    end
end]]