local typeforge = require(script.Parent.Parent.typeforge)
export type Function<T = never> = {}
export type Event<T = never> = {}

export type Buffer = {
	cursor: number,
	size: number,
	references: { unknown },
	inner: buffer,
}

export type function GetSchema(t: type)
	return t:readproperty(types.singleton("__T"))
end

export type Schema<T = nil> = {
	read read: (buf: buffer, offset: number) -> (T, number),
	read write: (input: T) -> (),
	read __T: T,
}

export type Intermediate<T, K> = {
	schema: Schema<T>,
	__T: T,
	__kind: K,
}

export type ClientRemote<T> = {
	read connect: (ClientRemote<T>, (T) -> ()) -> (),
	read fire: (ClientRemote<T>, T) -> (),
	__T: T,
	__kind: "remote",
}
export type ClientFunction<T> = {
	read invoke: (ClientFunction<T>, T) -> (),
	__T: T,
	__kind: "function",
}
export type ServerRemote<T> = {
	read connect: (ClientRemote<T>, (Player, T) -> ()) -> (),
	read fire: (ClientRemote<T>, Player, T) -> (),
	read fire_all: (ClientRemote<T>, T) -> (),
	__kind: "remote",
}
export type ServerFunction<T> = {
	set_callback: (ServerFunction<T>, (Player, T) -> ()) -> (),
	__kind: "function",
}

type inspect<T> = typeforge.Inspect<T>
type stringify<T> = typeforge.stringify<T>

type function out(xt: type)
	print(stringify(inspect(xt)):value())
end

type function ReplaceSchemas(original: type, event_type: type, fn_type: type)
	local ot = types.newtable()

	local function searchAndReplace(input: type, relative_write_to: type): ()
		if not input:is("table") then
			out(input)
			return
		end

		for i, v in input:properties() do
			local t = v.read
			if not t then
				continue
			end

			if GetSchema(t) then
				local substituted: type
				do
					const remote_kind = t:readproperty(types.singleton("__kind"))
					const value = t:readproperty(types.singleton("__T"))
					assert(remote_kind, "FAILED TO GET KIND")
					if remote_kind:value() == "function" then
						substituted = (fn_type :: never)(value)
					elseif remote_kind:value() == "event" then
						substituted = (event_type :: never)(value)
					end
				end

				relative_write_to:setreadproperty(types.singleton(i:value()), substituted)
			else
				local tempnt = types.newtable()
				relative_write_to:setreadproperty(types.singleton(i:value()), tempnt)

				searchAndReplace(t, tempnt)
			end
		end
	end

	searchAndReplace(original, ot)

	return ot
end

export type function ReplicateClient(original: type)
	return ReplaceSchemas(original, ClientRemote, ClientFunction)
end

export type function ReplicateServer(original: type)
	return ReplaceSchemas(original, ServerRemote, ServerFunction)
end

return nil
