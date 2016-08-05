module.exports.cleanUp = (client, server) ->
	if client.isConnected()
		server.clientQuitting() # warn server to ignore ECONNREST errors
		client.forceQuit()
		server.expect 'QUIT'
	return server.close()

module.exports.multiDone = (num, done) ->
	return (args...) ->
		done args... if --num is 0
