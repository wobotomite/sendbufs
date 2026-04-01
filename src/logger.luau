local fire_listeners = require("./fire-listeners")
local template = "[sendbufs]: %s"

function white(...:string)
    print(template:format(table.concat({...},", ")))
end

function red(...:string)
    error(template:format(table.concat({...},", ")))
end

function orange(...:string)
    warn(template:format(table.concat({...},", ")))
end

function handler(err)
   red(err) 
end

function errorif(cond:boolean,...:string)
    if (cond) then
        red(...);
    end
end

return {
    errorif=errorif,
    white = white,
    red = red,
    orange = orange,
    handler=handler,
}