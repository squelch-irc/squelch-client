class Channel
	constructor: (client, name) ->
		@_ =
			client: client
			name: name
			topic: ""
			users: {}
			mode: []
		@_.client.raw "TOPIC #{@_.name}"
	name: ->
		return @_.name

	toString: ->
		return @_.name

	client: ->
		return @_.client

	topic: ->
		return @_.topic

	kick: (user, comment) ->
		@_.client.kick @_.name, user, comment

	mode: (modeStr) ->
		@_.client.mode modeStr
		# TODO: See client.mode()

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