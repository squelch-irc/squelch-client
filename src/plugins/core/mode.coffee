{getSender} = require '../../util'
module.exports = ->
	return (client) ->
		client.mode = (chan, modeStr) ->
			@raw "MODE #{chan} #{modeStr}"

		client.ban = (chan, hostmask) ->
			@mode chan, "+b #{hostmask}"

		client.unban = (chan, hostmask) ->
			@mode chan, "-b #{hostmask}"

		client.op = (chan, user) ->
			@mode chan, "+o #{user}"

		client.deop = (chan, user) ->
			@mode chan, "-o #{user}"

		client.voice = (chan, user) ->
			@mode chan, "+v #{user}"

		client.devoice = (chan, user) ->
			@mode chan, "-v #{user}"

		client.on 'raw', (reply) ->
			if reply.command is 'MODE'
				sender = getSender reply
				chan = reply.params[0]
				user = chan if not @isChannel(chan)
				modes = reply.params[1]
				params = reply.params[2..] if reply.params.length > 2
				adding = true
				for c in modes
					if c is '+'
						adding = true
						continue
					if c is '-'
						adding = false
						continue
					if not user? # We're dealin with a real deal channel mode
						param = undefined
						# Cases where mode has param
						if @_.chanmodes[0].indexOf(c) isnt -1 or
						@_.chanmodes[1].indexOf(c) isnt -1 or
						(adding and @_.chanmodes[2].indexOf(c) isnt -1) or
						@_.prefix[c]?
							param = params.shift()
						@emit '+mode', {chan, sender, mode: c, param} if adding
						@emit '-mode', {chan, sender, mode: c, param} if not adding
					else # We're dealing with some stupid user mode
						# Ain't no one got time to keep track of user modes
						@emit '+usermode', {user, mode: c, sender} if adding
						@emit '-usermode', {user, mode: c, sender} if not adding

				@emit 'mode', {chan, sender, mode: reply.params[1..].join ' '}

