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
		@_ =
			client: client
			name: name
			topic: ""
			topicSetter: ""
			topicTime: null
			users: {}
			mode: []
		@_.client.raw "TOPIC #{@_.name}"

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
		return @mode.join("") if not modeStr?
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
		return (nick for nick, status of @_.users when status is "@")

	###
	Returns a list of all users in this channel that are voices.
	@return [Array] Array of all nicks of voices in this channel.
	###
	voices: ->
		return (nick for nick, status of @_.users when status is "+")

	###
	Returns a list of all users in this channel that have no special status.
	@return [Array] Array of all nicks of users with no special status in this channel.
	###
	normalUsers: ->
		return (nick for nick, status of @_.users when status is "")

module.exports = Channel