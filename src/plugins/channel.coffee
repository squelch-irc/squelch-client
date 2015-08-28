cloneDeep = require 'lodash.clonedeep'
{getReplyCode} = require '../replies'


class Channel
	constructor: (client, name) ->
		# TODO: use a WeakMap to hide this info
		@_ =
			client: client
			name: name
			topic: ''
			topicSetter: ''
			topicTime: null
			users: {}
			mode: []

	# Clones this Channel object
	clone: ->
		copy = new Channel @, @_.name
		copy._ = cloneDeep @._
		return copy

	name: ->
		return @_.name

	toString: ->
		return @_.name

	client: ->
		return @_.client

	contains: (nick) ->
		return @_.users[nick]?

	getStatus: (nick) ->
		return @_.users[nick]

	topic: (topic) ->
		return @_.topic  if not topic?
		@_.client.raw "TOPIC #{@_.name} #{topic}"

	topicSetter: ->
		return @_.topicSetter

	topicTime: ->
		return @_.topicTime

	part: (reason, cb) ->
		@_.client.part @_.name, reason, cb

	kick: (user, reason) ->
		@_.client.kick @_.name, user, reason

	ban: (hostmask) ->
		@_.client.ban @_.name, hostmask

	unban: (hostmask) ->
		@_.client.unban @_.name, hostmask

	mode: (modeStr) ->
		return @mode.join('') if not modeStr?
		@_.client.mode modeStr

	op: (user) ->
		@_.client.op @_.name, user

	deop: (user) ->
		@_.client.deop @_.name, user

	voice: (user) ->
		@_.client.voice @_.name, user

	devoice: (user) ->
		@_.client.devoice @_.name, user

	msg: (msg) ->
		@_.client.msg @_.name, msg

	users: ->
		return (nick for nick of @_.users)

	ops: ->
		return (nick for nick, status of @_.users when status is '@')

	voices: ->
		return (nick for nick, status of @_.users when status is '+')

	normalUsers: ->
		return (nick for nick, status of @_.users when status is '')

module.exports = ->
	# TODO: accept option to not clone channel objects
	return (client) ->
		client._.channels = {}

		client.channels = ->
			return (@getChannel(chan) for chan of @_.channels)

		client.getChannel = (name) ->
			chan = @_.channels[name.toLowerCase()]
			return chan?.clone()

		client.isInChannel = (name, nick = @nick()) ->
			return !!(@getChannel(name)?.contains(nick))

		# Override client.mode so it can access channel data
		oldMode = client.mode
		client.mode = (chan, modeStr) ->
			return @_.channels[chan.toLowerCase()].mode() if not modeStr?
			oldMode chan, modeStr

		client._.internalEmitter.on 'raw', (reply) ->

			if reply.command is getReplyCode 'RPL_NOTOPIC'
				client._.channels[reply.params[1].toLowerCase()]._.topic = ''
				client.emit 'topic', {chan: reply.params[1], topic: ''}
			if reply.command is getReplyCode 'RPL_TOPIC'
				client._.channels[reply.params[1].toLowerCase()]._.topic = reply.params[2]
				client.emit 'topic', {chan: reply.params[1], topic: reply.params[2]}
			if reply.command is getReplyCode 'RPL_TOPIC_WHO_TIME'
				chan = client._.channels[reply.params[1].toLowerCase()]
				chan._.topicSetter = reply.params[2]
				chan._.topicTime = new Date parseInt(reply.params[3])
				client.emit 'topicwho', {chan: reply.params[1], hostmask: chan._.topicSetter, time: chan._.topicTime}
			if reply.command is getReplyCode 'RPL_NAMREPLY'
				# TODO: trigger event on name update
				chan = client._.channels[reply.params[2].toLowerCase()]
				return if not chan?
				names = reply.params[3].split ' '
				for name in names
					if client._.reversePrefix[name[0]]?
						chan._.users[name[1..]] = name[0]
					else
						chan._.users[name] = ''
			if reply.command is getReplyCode 'RPL_ENDOFNAMES'
				chan = reply.params[1]
				client.emit 'names', {chan}

		client._.internalEmitter.on 'nick', ({oldNick, newNick}) ->
			for name, chan of client._.channels
				if chan._.users[oldNick]?
					chan._.users[newNick] = chan._.users[oldNick]
					delete chan._.users[oldNick]

		client._.internalEmitter.on 'join', ({chan, nick}) ->
			if nick is client._.nick
				client._.channels[chan.toLowerCase()] = new Channel client, chan
			else
				client._.channels[chan.toLowerCase()]._.users[nick] = ''

		client._.internalEmitter.on 'part', ({chan, nick}) ->
			if nick is client._.nick
				delete client._.channels[chan.toLowerCase()]
			else
				users = client._.channels[chan.toLowerCase()]._.users
				delete users[nick]

		client._.internalEmitter.on 'kick', ({chan, nick}) ->
			if nick is client._.nick
				delete client._.channels[chan.toLowerCase()]
				client.raw "JOIN #{chan}" if client.opt.autoRejoin
			else
				delete client._.channels[chan.toLowerCase()]._.users[nick]

		client._.internalEmitter.on 'quit', (e) ->
			{nick} = e
			leftChannels = []
			for name, chan of client._.channels when chan._.users[nick]?
				leftChannels.push chan.name()
				delete chan._.users[nick]
			e.channels = leftChannels

		client._.internalEmitter.on '+mode', ({chan, sender, mode, param}) ->
			if client._.prefix[mode]? # Update user's mode in channel
				client._.channels[chan.toLowerCase()]._.users[param] = client._.prefix[mode]
			else # Update channel mode
				channelModes = client._.channels[chan.toLowerCase()]._.mode
				channelModes.push mode

		client._.internalEmitter.on '-mode', ({chan, sender, mode, param}) ->
			if client._.prefix[mode]? # Update user's mode in channel
				client._.channels[chan.toLowerCase()]._.users[param] = ''
			else # Update channel mode
				channelModes = client._.channels[chan.toLowerCase()]._.mode
				index = channelModes.indexOf mode
				channelModes[index..index] = [] if index isnt -1
