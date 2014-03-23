class Channel
	constructor: (bot, name) ->
		@_ =
			bot: bot
			name: name
			topic: ""
			users: []
		@_.bot.raw "TOPIC #{@_.name}"
	name: ->
		return @_.name

	toString: ->
		return @_.name

	bot: ->
		return @_.bot

	topic: ->
		return @_.topic

	kick: (user, comment) ->
		@_.bot.kick @_.name, user, comment

	mode: (modeStr) ->
		@_.bot.mode modeStr
		# TODO: See client.mode()

	op: (user) ->
		@_.bot.op @_.name, user

	deop: (user) ->
		@_.bot.deop @_.name, user

	voice: (user) ->
		@_.bot.voice @_.name, user

	devoice: (user) ->
		@_.bot.devoice @_.name, user

	msg: (msg) ->
		@_.bot.msg @_.name, msg

module.exports = Channel