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

return util;