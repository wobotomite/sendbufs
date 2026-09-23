# Intro:
sendbufs is a networking library with buffer compression and type validation via schemas.
## Getting Started
1. create a shared network definitions script (i.e. ReplicatedStorage/network-definitions.luau)
2. export remotes out of it in a table:
```lua
const remotes = table.freeze {
  test_remote = sendbufs.event(),
	core = {
		send_alert = sendbufs.event(sendbufs.schema.struct {

			message = sendbufs.schema.str,
			sound = sendbufs.schema.maybe(sendbufs.schema.str),
		}),
		sync_charm = sendbufs.event(sendbufs.schema.ref),
		update_settings = sendbufs.event(sendbufs.schema.struct {
			id = sendbufs.schema.str,
			val = sendbufs.schema.ref,
		}),
		update_camera_focus = sendbufs.event(sendbufs.schema.vector(sendbufs.schema.f32)),

		get_group_rewards = sendbufs.event(),
    test_fn = sendbufs.fn(), -- input: nil, output: nil because the args are empty.
	},
}
sendbufs.middleware(remotes.core.update_camera_focus, rate_limit(1 / 10))
return remotes;
```
3. create a server & a client module to use the network definitions in:
```lua
-- CLIENT:
const network_definitions = require(...);
return sendbufs.create_client(network_definitions)
-- SERVER:
const network_definitions = require(...);
return sendbufs.create_server(network_definitions, 4096) -- optional, 4096 by default. the max size of one packet a client can send to the server. clients split their batches to fit, so only a single message bigger than this gets dropped.
```
4. require & use:
```lua
-- CLIENT:
network.core.update_camera_focus:fire(Vector3.new(.7,0,.7))
network.core.test_fn:invoke();
-- SERVER:
const dc = network.core.update_camera_focus:connect(function(plr, vec) -- types are inferred
end)

if "no longer needed" then
dc() -- disconnect
end

network.core.test_fn:set_callback(function(plr) -- one callback per remote function: calling set_callback again logs an error and keeps the first one.
return true, nil -- 1st value is the success, second is the result. return false to tell the client the function failed.
end)
```
