cloneDeep = require 'lodash.clonedeep'
{getReplyCode} = require '../replies'

###
An object containing some information about an IRC channel.
NOTE: Do not modify the contents of the private _ object.
@author Rahat Ahmed
###
class Channel
	###
	@nodoc
	###
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

	###
	Clones this Channel object
	@nodoc
	@return [Channel] A deep copy of this Channel object
	###
	clone: ->
		copy = new Channel @, @_.name
		copy._ = cloneDeep @._
		return copy

	###
	Returns the name of this channel.
	@return [String] the name of this channel
	###
	name: ->
		return @_.name

	###
	Returns the name of this channel.
	@return [String] the name of this channel
	###
	toString: ->
		return @_.name

	###
	Returns the client this channel is associated with.
	@return [Client] the client
	###
	client: ->
		return @_.client

	###
	@overload #topic()
	  Returns the topic of this channel.
	  @return [String] the topic of this channel
	@overload #topic(topic)
	  Sets the topic of this channel.
	  @param topic [String] the new topic to set
	###
	topic: (topic) ->
		return @_.topic  if not topic?
		@_.client.raw "TOPIC #{@_.name} #{topic}"

	###
	Returns the hostmask of the person who set the topic.
	@return [String] the hostmask of the topic setter
	###
	topicSetter: ->
		return @_.topicSetter

	###
	Returns when the topic was set.
	@return [Date] when the topic was set
	###
	topicTime: ->
		return @_.topicTime

	###
	Convenience function for parting this channel.
	@see Client#part
	###
	part: (reason, cb) ->
		@_.client.part @_.name, reason, cb

	###
	Convenience function for kicking a user from this channel.
	@see Client#kick
	###
	kick: (user, reason) ->
		@_.client.kick @_.name, user, reason

	###
	Convenience function for baning a user from this channel.
	@see Client#ban
	###
	ban: (hostmask) ->
		@_.client.ban @_.name, hostmask

	###
	Convenience function for unbaning a user from this channel.
	@see Client#unban
	###
	unban: (hostmask) ->
		@_.client.unban @_.name, hostmask

	###
	Convenience function for setting or getting modes for this channel.
	@see Client#mode
	###
	mode: (modeStr) ->
		return @mode.join('') if not modeStr?
		@_.client.mode modeStr

	###
	Convenience function for giving a user op in this channel.
	@see Client#op
	###
	op: (user) ->
		@_.client.op @_.name, user

	###
	Convenience function for removing op from a user in this channel.
	@see Client#deop
	###
	deop: (user) ->
		@_.client.deop @_.name, user

	###
	Convenience function for giving a user voice in this channel.
	@see Client#voice
	###
	voice: (user) ->
		@_.client.voice @_.name, user

	###
	Convenience function for removing voice from a user in this channel.
	@see Client#devoice
	###
	devoice: (user) ->
		@_.client.devoice @_.name, user

	###
	Convenience function for sending a message to this channel.
	@see Client#msg
	###
	msg: (msg) ->
		@_.client.msg @_.name, msg

	###
	Returns a list of all users in this channel.
	@return [Array] Array of all nicks of users in this channel.
	###
	users: ->
		return (nick for nick of @_.users)

	###
	Returns a list of all users in this channel that are ops.
	@return [Array] Array of all nicks of ops in this channel.
	###
	ops: ->
		return (nick for nick, status of @_.users when status is '@')

	###
	Returns a list of all users in this channel that are voices.
	@return [Array] Array of all nicks of voices in this channel.
	###
	voices: ->
		return (nick for nick, status of @_.users when status is '+')

	###
	Returns a list of all users in this channel that have no special status.
	@return [Array] Array of all nicks of users with no special status in this channel.
	###
	normalUsers: ->
		return (nick for nick, status of @_.users when status is '')

module.exports = ->
	# TODO: accept option to not clone channel objects
	return (client) ->
		client._.channels = {}

		###
		Returns the channel objects of all channels the client is in.
		@return [Array] The array of all channels the client is in.
		###
		client.channels = ->
			return getChannel(chan) for chan in @_.channels

		###
		Gets the Channel object if the bot is in that channel.
		@param name [String] The name of the channel
		@return [Boolean] The Channel object, or undefined if the bot is not in that channel.
		###
		client.getChannel = (name) ->
			chan = @_.channels[name.toLowerCase()]
			return chan?.clone()

		###
		Checks if the client is in the channel.
		@param name [String] The name of the channel
		@return [Boolean] true if the bot is in the given channel.
		###
		client.isInChannel = (name) ->
			return getChannel(name) instanceof Channel

		# Override client.mode so it can access channel data
		oldMode = client.mode
		client.mode = (chan, modeStr) ->
			return @_.channels[chan.toLowerCase()].mode() if not modeStr?
			oldMode chan, modeStr

		client.on 'raw', (reply) ->
			if reply.command is getReplyCode 'RPL_NOTOPIC'
				@_.channels[reply.params[1].toLowerCase()]._.topic = ''
			if reply.command is getReplyCode 'RPL_TOPIC'
				@_.channels[reply.params[1].toLowerCase()]._.topic = reply.params[2]
			if reply.command is getReplyCode 'RPL_TOPIC_WHO_TIME'
				chan = @_.channels[reply.params[1].toLowerCase()]
				chan._.topicSetter = reply.params[2]
				chan._.topicTime = new Date parseInt(reply.params[3])
			if reply.command is getReplyCode 'RPL_NAMREPLY'
				# TODO: trigger event on name update
				chan = @_.channels[reply.params[2].toLowerCase()]
				return if not chan?
				names = reply.params[3].split ' '
				for name in names
					if @_.reversePrefix[name[0]]?
						chan._.users[name[1..]] = name[0]
					else
						chan._.users[name] = ''
			if reply.command is getReplyCode 'RPL_ENDOFNAMES'
				chan = reply.params[1]
				@emit 'names', chan

		client.on 'nick', (oldnick, newnick) ->
			for name, chan of @_.channels
				for user, status of chan._.users when user is oldnick
					chan._.users[newnick] = chan._.users[oldnick]
					delete chan._.users[oldnick]

		client.on 'join', (chan, nick) ->
			if nick is @_.nick
				@_.channels[chan.toLowerCase()] = new Channel @, chan
			else
				@_.channels[chan.toLowerCase()]._.users[nick] = ''

		client.on 'part', (chan, nick) ->
			if nick is @_.nick
				delete @_.channels[chan.toLowerCase()]
			else
				users = @_.channels[chan.toLowerCase()]._.users
				for user of users when user is nick
					delete users[nick]
					break

		client.on 'kick', (chan, nick) ->
			if nick is @_.nick
				delete @_.channels[chan.toLowerCase()]
				@raw "JOIN #{chan}" if @opt.autoRejoin
			else
				delete @_.channels[chan.toLowerCase()]._.users[nick]

		client.on '+mode', (chan, sender, mode, param) ->
			if @_.prefix[mode]? # Update user's mode in channel
				@_.channels[chan.toLowerCase()]._.users[param] = @_.prefix[mode]
			else # Update channel mode
				channelModes = @_.channels[chan.toLowerCase()]._.mode
				channelModes.push mode

		client.on '-mode', (chan, sender, mode, param) ->
			if @_.prefix[mode]? # Update user's mode in channel
				@_.channels[chan.toLowerCase()]._.users[param] = ''
			else # Update channel mode
				channelModes = @_.channels[chan.toLowerCase()]._.mode
				index = channelModes.indexOf mode
				channelModes[index..index] = [] if index isnt -1
