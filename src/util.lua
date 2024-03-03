local stdio = require("@lune/stdio");

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
        :gsub("*", "[^/\\]*")
        :gsub("?", "[^/\\]")
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

    local CORE = "[%w%-]+/[%w%-_%.]";
    local REF = "[%w%-%._/]"

    local parsed = {};

    parsed.valid = (
            string.match(package_id, `^{CORE}$`)
        or string.match(package_id, `^{CORE}@{REF}$`)
    ) ~= nil;

    if parsed.valid then
        parsed.owner = string.match(package_id, "^([%w%-]+).*$")
    end

    return parsed;
end

print(util.parse_package_id("plainenglishh/lpm@1.0.0"))

return util;
