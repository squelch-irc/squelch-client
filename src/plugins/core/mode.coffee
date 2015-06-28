{getSender} = require '../../util'
module.exports = ->
	return (client) ->

		###
		Sets mode +b on a hostmask in a channel.
		@param chan [String] The channel to set the mode in
		@param hostmask [String] The hostmask to ban
		###
		client.ban = (chan, hostmask) ->
			@mode chan, "+b #{hostmask}"

		###
		Sets mode -b on a hostmask in a channel.
		@param chan [String] The channel to set the mode in
		@param hostmask [String] The hostmask to unban
		###
		client.unban = (chan, hostmask) ->
			@mode chan, "-b #{hostmask}"

		###
		@overload #mode(chan, modeStr)
			Sets a given mode on a hostmask in a channel.
			@param chan [String] The channel to set the mode in
			@param modeStr [String] The modes and arguments to set for that channel
		###
		client.mode = (chan, modeStr) ->
			@raw "MODE #{chan} #{modeStr}"

		###
		Sets mode +o on a user in a channel.
		@param chan [String] The channel to set the mode in
		@param user [String] The user to op
		###
		client.op = (chan, user) ->
			@mode chan, "+o #{user}"

		###
		Sets mode -o on a user in a channel.
		@param chan [String] The channel to set the mode in
		@param user [String] The user to deop
		###
		client.deop = (chan, user) ->
			@mode chan, "-o #{user}"

		###
		Sets mode +v on a user in a channel.
		@param chan [String] The channel to set the mode in
		@param user [String] The user to voice
		###
		client.voice = (chan, user) ->
			@mode chan, "+v #{user}"

		###
		Sets mode -v on a user in a channel.
		@param chan [String] The channel to set the mode in
		@param user [String] The user to devoice
		###
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
						@emit '+mode', chan, sender, c, param if adding
						@emit '-mode', chan, sender, c, param if not adding
					else # We're dealing with some stupid user mode
						# Ain't no one got time to keep track of user modes
						@emit '+usermode', user, c, sender if adding
						@emit '-usermode', user, c, sender if not adding