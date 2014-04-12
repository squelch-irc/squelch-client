class Channel
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
	name: ->
		return @_.name

	toString: ->
		return @_.name

	client: ->
		return @_.client

	topic: (topic) ->
		return @_.topic  if not topic?
		@_.client.raw "TOPIC #{@_.name} #{topic}"

	topicSetter: ->
		return @_.topicSetter

	topicTime: ->
		return @_.topicTime

	kick: (user, comment) ->
		@_.client.kick @_.name, user, comment

	ban: (hostmask) ->
		@_.client.ban @_.name, hostmask

	unban: (hostmask) ->
		@_.client.unban @_.name, hostmask

	mode: (modeStr) ->
		return @mode.join("") if not modeStr?
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
		return (nick for nick, status of @_.users when status is "@")

	voices: ->
		return (nick for nick, status of @_.users when status is "+")

	normalUsers: ->
		return (nick for nick, status of @_.users when status is "")

module.exports = Channel