import IRCClient from require "irc"

[[
	How to use batches:

	Add in a hook START_BATCH.<your batch type> that adds in a callback to
	BATCH.<label>. This hook should be used for collecting data to later be
	used for processing.

	Add in a hook END_BATCH.<label> during START_BATCH.<your batch type>. This
	hook should be used for performing operations all at once on your dataset.

	Hooks specific to a label will be cleaned up when the batch ends.
]]

IRCClient\add_handler 'BATCH', (prefix, args, tags)=>
	-- @fire_hook "START_BATCH.netsplit", "yXNAbvnRHTRBv", "irc.one", "irc.two"
	label = args[1]
	if label\sub(1, 1) == "+" -- start new batch
		@fire_hook "START_BATCH.#{args[2]}", label\sub(2), unpack(args, 3)
	else
		label = label\sub 2
		@fire_hook "END_BATCH.#{label}"
		@hooks\remove "BATCH.#{label}"
		@hooks\remove "END_BATCH.#{label}"

opts = {in_batch: true}

IRCClient\add_hook 'START_BATCH.netsplit', (label, _local, remote)=>
	@with_context "BATCH.#{label}", =>
		disconnected_clients = {}
		@add_hook "BATCH.#{label}", wrap_iter: true, =>
			count = 0
			for prefix, args, tags in coroutine.yield
				count += 1
				disconnected_clients[count] = {prefix, args, tags}
		@add_hook "END_BATCH.#{label}", =>
			for client in disconnected_clients
				{prefix, args, tags} = client
				@process prefix, args, tags, opts

IRCClient\add_hook 'START_BATCH.netjoin', (label, _local, remote)=>
	@with_context "BATCH.#{label}", =>
		reconnected_clients = {}
		@add_hook "BATCH.#{label}", wrap_iter: true, =>
			count = 0
			for prefix, args, tags in coroutine.yield
				count += 1
				reconnected_clients[count] = {prefix, args, tags}
		@add_hook "END_BATCH.#{label}", =>
			for client in reconnected_clients
				{prefix, args, tags} = client
				@process prefix, args, tags, opts
