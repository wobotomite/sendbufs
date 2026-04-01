# sendbufs

### API:

### sendbufs.schema
```lua
sendbufs.schema[T] -> typeof T
```

Schemas are used to define request bodies:
```lua
const schema = sendbufs.schema.ARRAY(sendbufs.schema.STRUCT({
    optional = sendbufs.schema.OPTIONAL(sendbufs.schema.BOOL),
    age = sendbufs.schema.U8,
    cf = sendbufs.schema.CFRAME,
    name = sendbufs.schema.STRING,

    -- use refs to skip serialization for components and/or to send over data that does not have a schema definition.
    model = sendbufs.schema.REF
}));
```

# <i> ALWAYS DEFINE EVENTS AND FUNCTIONS STATICALLY INSIDE OF SHARED SCRIPTS </i>
i.e. "remotes" in ReplicatedStorage that contains:
```lua
local network = {
    awesome_event = sendbufs.create_event(sendbufs.schema.STRUCT{
        success = sendbufs.schema.BOOL,
        data = sendbufs.schema.OPTIONAL(sendbufs.schema.ARRAY(sendbufs.schema.U8)),
    })
}

-- add middleware here. more on that later.

return network;
```

### sendbufs.create_event | sendbufs.create_unreliable
```lua
sendbufs.create_event<T>(schema:T);
sendbufs.create_unreliable<T>(schema:T);
```
Creates a remote event definition
```luau
local ev = sendbufs.create_event(sendbufs.schema.VECF32);
```

Methods:
```luau
ev:fire_server(data:T);

ev:fire_client(p:(Player|{Player}), data:T);

ev:fire_all(data:T);

ev:connect(callback:(T,Player?)->(),once?:boolean);

ev:wait(): (T,Player?);

-- where T: sendbufs.schema.VECF32 
```

### sendbufs.create_request
```lua
sendbufs.create_request<T,R>(input:T, output:R);
```
Creates a remote function definition. 
<b>CLIENT TO SERVER ONLY</b>
```luau
local ev = sendbufs.create_request(sendbufs.schema.NONE,sendbufs.schema.VECF32);
-- (example) sends nothing and receives a vector
```

Methods:
```luau
ev:invoke(data:T): (boolean,R)

ev:set_callback(cb:(T,Player)->R);

-- where T: sendbufs.schema.NONE,
--       R: sendbufs.schema.VECF32
```

### middleware

Middleware runs on the server before every listener call (events) and before parsing sent data (functions).
It cannot modify data and should only be used for filtering.

##### Middleware functions are fired sequentially!

#### example (useful) middleware functions:

```lua
local function rate_limit(rate: number)
	local map = {}
	return function(id,plr,b,refs)
		local t = os.clock()
		local t0 = map[plr] or 0
		if t - t0 > rate then
			map[plr] = t;
			return true
		else
			return false
		end
	end
end

local function limit_payload(to:number)
	return function(_,_,b)
		if (buffer.len(b)>to) then
			warn("PAYLOAD TOO BIG!")
			return false
		end
		return true
	end
end

local function server_to_client_only(list: {[sendbufs.TEvent]:boolean})
	-- middleware only runs on the server!
	-- remote functions are always client-to-server by design
	return function(id)
		if list[id] then
			return false
		end
		return true
	end
end

local function scope_middleware(
	scope: {[string]:sendbufs.TEvent},
	middleware:(n:number,plr:Player,b:buffer,refs:{unknown}?)->boolean
	)
	for _,ev in scope do
		sendbufs.middleware(ev,middleware);
	end
end

local function print_payload(_,plr,b)
	print(plr,"sent",buffer.len(b),"bytes");
	return true;
end
```


```lua
local network = {

	data_change_requests = {
		try_eat_food = sendbufs.create_event(sendbufs.STRUCT{
			food_name = sendbufs.STRING,
			amount = sendbufs.U16
		});
		try_equip_armor = sendbufs.create_event(sendbufs.STRING);
	}

    awesome_event = sendbufs.create_event(sendbufs.schema.STRUCT{
        success = sendbufs.schema.BOOL,
        data = sendbufs.schema.OPTIONAL(sendbufs.schema.ARRAY(sendbufs.schema.U8)),
    })
    server_only = sendbufs.create_event(sendbufs.schema.CFRAME);
}

sendbufs.global_middleware(server_to_client_only({
    [network.server_only] = true,
}));

sendbufs.scope_middleware(network.data_change_requests,rate_limit(1/3));
sendbufs.middleware(network.awesome_event,rate_limit(1/24));

sendbufs.middleware(network.awesome_event,limit_payload(1024));

sendbufs.global_middleware(print_payload);

return network;
```