export type fn_listener = { fn: () -> (), once: boolean? }

export type buffer_writer = {
	size: number,
	cursor: number,
	references: { unknown },
	buff: buffer,
}

export type serdes_data<T> = {
	read: (buff: buffer_writer, cursor: number) -> (T, number),
	write: (buff: buffer_writer, v: T) -> (),
}

type event_comb_mt<T> = {
	__index: event_comb_mt<T>,
	connect: (self: t_event<T>, callback: (T, plr: Player?) -> (), once: boolean?) -> () -> (),
	wait: () -> (T, Player?),
	fire_client: (self: t_event<T>, plr: Player | { Player }, arg: T) -> (),
	fire_all: (self: t_event<T>, arg: T) -> (),
	fire_server: (self: t_event<T>, arg: T) -> (),
}

type fn_comb_mt<T, R> = {
	__index: fn_comb_mt<T, R>,
	invoke: (self: t_fn<T, R>, input: T) -> (boolean, R),
	set_callback: (self: t_fn<T, R>, cb: (T, plr: Player) -> R) -> (),
}

export type t_event<T> = typeof(setmetatable(
	{} :: {
		kind: "event",
		listeners: { fn_listener },
		schema: serdes_data<T>,
		type: number,
		id: number,
	},
	{} :: event_comb_mt<T>
))

export type t_fn<T, R> = typeof(setmetatable(
	{} :: {
		kind: "function",
		callback: ((arg: T, plr: Player?) -> R)?,
		schema: serdes_data<T>,
		schema_out: serdes_data<{ any }>,
		id: number,
	},
	{} :: fn_comb_mt<T, R>
))

return nil
