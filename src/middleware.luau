local RunService = game:GetService("RunService")

local remotes = require("./remotes")

type middleware_fn = (id:number,plr:Player,b:buffer,refs:{unknown}?)->boolean

local added: {[number]:{middleware_fn}} = {}

function middleware<T,R>(net:any, fn:middleware_fn)
    local array = added[net.id] or {};
    table.insert(array,fn);
end

function global_middleware(fn:middleware_fn)
    for r in remotes do
        local array = added[r] or {};
        table.insert(array,fn);
    end
end

function run_middleware_for(id:number,plr:Player,b:buffer,refs:{unknown}?)
    if (not RunService:IsServer()) then
        return true;
    end
    local array = added[id];
    if not array then
        return true;
    end
    for _,fn in array do
        if not fn(id,plr,b,refs) then
            return false;
        end
    end
    return true;
end

return {
    middleware = middleware,
    global_middleware = global_middleware,
    run_middleware_for=run_middleware_for,

}