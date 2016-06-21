module.exports =
	# Helper method to get nick or server out of the prefix of a message
	getSender: (parsedReply) ->
		if parsedReply.prefix.isServer
			return parsedReply.prefix.host
		return parsedReply.prefix.nick
