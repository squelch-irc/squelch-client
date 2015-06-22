chai = require 'chai'
{expect} = chai
should = chai.should()

Client = require '../src/client'
TestServer = require './TestServer'

###
Thank you KR https://gist.github.com/raymond-h/709801d9f3816ff8f157#file-test-util-coffee
Allows mocha to catch assertions in async functions
usage (done being another callback to be called with thrown assert except.)
asyncFunc param, param, async(done) (err, data) ->
  hurr
###
async = (done) ->
	(callback) -> (args...) ->
			try callback args...
			catch e then done e

cleanUp = (client, server, done) ->
	if client.isConnected()
		server.clientQuitting() # warn server to ignore ECONNREST errors
		client.forceQuit()
		server.expect 'QUIT'
	server.close()
	.then done

multiDone = (num, done) ->
	return (args...) ->
		done args... if --num is 0


describe 'Client', ->
	client = server = null
	beforeEach (done) ->
		server = new TestServer 6667, false
		client = new Client
			server: 'localhost'
			nick: 'PakaluPapito'
			messageDelay: 0
			autoReconnect: false
			autoConnect: false
			verbose: false
			port: 6667
		connectPromise = client.connect()
		server.expect [
			'NICK PakaluPapito'
			'USER NodeIRCClient 8 * :NodeIRCClient'
		]
		.then ->
			server.reply ':localhost 001 PakaluPapito :Welcome to the IRCNet Internet Relay Chat Network PakaluPapito'
			connectPromise
		.then (nick) ->
			nick.should.equal 'PakaluPapito'
			done()


	afterEach (done) ->
		cleanUp client, server, done

	describe 'constructor', ->
		it 'should throw an error with no arguments', ->
			expect ->
				client = new Client()
			.to.throw 'No options argument given.'
		it 'should throw an error with no server option', ->
			expect ->
				client = new Client
					port: 6697
					nick: 'PakaluPapito'
					username: 'PakaluPapito'
					realname: 'PakaluPapito'
			.to.throw 'No server specified.'
		it 'should load the config from a file', ->
			client = new Client('./test/testConfig.json')
			client.opt.server.should.equal 'localhost'
			client.opt.port.should.equal 6667
			client.opt.nick.should.equal 'NodeIRCTestBot'
			client.opt.username.should.equal 'NodeIRCTestBot'
			client.opt.realname.should.equal 'I do the tests.'
			client.opt.autoConnect.should.equal false

	describe 'disconnect', ->
		it 'should send QUIT to the server and null the connection', (done) ->
			client.disconnect()
			server.expect 'QUIT'
			.then done
			.catch done

		it 'should send a reason with the QUIT', (done) ->
			client.disconnect 'Choke on it.'
			server.expect 'QUIT :Choke on it.'
			.then done
			.catch done

		it 'should run the callback on successful disconnect', (done) ->
			client._.disconnecting.should.be.false
			client.disconnect async(done) () ->
				client._.disconnecting.should.be.false
				client.isConnected().should.be.false
				done()
			server.expect 'QUIT'
			.then ->
				client._.disconnecting.should.be.true
				server.reply 'ERROR :Closing Link: cpe-76-183-227-155.tx.res.rr.com (Client Quit)'

		it 'should resolve the promise on successful disconnect', (done) ->
			client._.disconnecting.should.be.false
			disconnectPromise = client.disconnect()
			server.expect 'QUIT'
			.then ->
				client._.disconnecting.should.be.true
				server.reply 'ERROR :Closing Link: cpe-76-183-227-155.tx.res.rr.com (Client Quit)'
				disconnectPromise
			.then ->
				client._.disconnecting.should.be.false
				client.isConnected().should.be.false
				done()

	describe 'isConnected', ->
		beforeEach (done) ->
			cleanUp client, server, done
		it 'should only be true when connected to the server', ->

			client = new Client
				server: 'localhost'
				nick: 'PakaluPapito'
				messageDelay: 0
				autoReconnect: false
				autoConnect: false
				verbose: false
			client.isConnected().should.be.false

			server = new TestServer 6667
			server.expect [
				'NICK PakaluPapito'
				'USER NodeIRCClient 8 * :NodeIRCClient'
			]
			.then ->
				server.reply ':localhost 001 PakaluPapito :Welcome to the IRCNet Internet Relay Chat Network PakaluPapito'
				client.on 'connect', ->
					client.isConnected().should.be.true
					done()

	describe 'verbose', ->
		it 'should return the right value', ->
			client.verbose().should.be.false
			client.opt.verbose.should.be.false
		it 'should set the right value', ->
			client.verbose true
			client.verbose().should.be.true
			client.opt.verbose.should.be.true
			client.verbose false
			client.verbose().should.be.false
			client.opt.verbose.should.be.false

	describe 'verboseError', ->
		it 'should return the right value', ->
			client.verboseError().should.be.true
			client.opt.verboseError.should.be.true
		it 'should set the right value', ->
			client.verboseError true
			client.verboseError().should.be.true
			client.opt.verboseError.should.be.true
			client.verboseError false
			client.verboseError().should.be.false
			client.opt.verboseError.should.be.false

	describe 'autoRejoin', ->
		it 'should send a join command after a KICK', (done) ->
			client.autoRejoin true
			joinPromise = client.join ['#nice']
			server.expect 'JOIN #nice'
			.then ->
				server.reply ':PakaluPapito!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com JOIN #nice'
				server.expect 'TOPIC #nice'
			.then -> joinPromise
			.then (e) ->
				server.reply ':KR!~RayK@cpe-76-183-227-155.tx.res.rr.com KICK #nice PakaluPapito :Nice ppl only'
				server.expect 'JOIN #nice'
			.then done
			.catch done




	describe 'kick', ->
		it 'with single chan and nick', (done) ->
			client.kick '#persia', 'messenger'
			server.expect 'KICK #persia messenger'
			.then done
			.catch done
		it 'with multiple chans and nicks', (done) ->
			client.kick ['#persia', '#empire'], ['messenger1', 'messenger2', 'messenger3']
			server.expect [
				'KICK #persia messenger1'
				'KICK #persia messenger2'
				'KICK #persia messenger3'
				'KICK #empire messenger1'
				'KICK #empire messenger2'
				'KICK #empire messenger3'
			]
			.then done
			.catch done
		it 'with a reason', (done) ->
			client.kick '#persia', 'messenger', 'THIS IS SPARTA!'
			server.expect 'KICK #persia messenger :THIS IS SPARTA!'
			.then done
			.catch done
			
	describe 'nick', ->
		it 'with no parameters should return the nick', ->
			client.nick().should.equal 'PakaluPapito'

		it 'with one parameter should send a NICK command', (done) ->
			client.nick 'PricklyPear'
			server.expect 'NICK PricklyPear'
			.then done
			.catch done

		it 'with two params should callback on success', (done) ->
			client.nick 'PricklyPear', async(done) (err, e) ->
				should.not.exist err
				e.oldNick.should.equal 'PakaluPapito'
				e.newNick.should.equal 'PricklyPear'
				client.listeners('nick').length.should.equal 0
				client.listeners('raw').length.should.equal 0
				done()
			server.expect 'NICK PricklyPear'
			.then ->
				server.reply ':PakaluPapito!~NodeIRCClient@cpe-76-183-227-155.tx.res.rr.com NICK :PricklyPear'

		it 'with two params should callback on error 432', (done) ->
			client.nick '!@#$%^&*()', async(done) (err, e) ->
				err.command.should.equal '432'
				should.not.exist e
				client.listeners('nick').length.should.equal 0
				client.listeners('raw').length.should.equal 0
				done()
			server.expect 'NICK !@#$%^&*()'
			.then ->
				server.reply ':irc.ircnet.net 432 PakaluPapito ass :Erroneous Nickname'

		it 'should resolve the promise on success', (done) ->
			nickPromise = client.nick 'PricklyPear'
			server.expect 'NICK PricklyPear'
			.then ->
				server.reply ':PakaluPapito!~NodeIRCClient@cpe-76-183-227-155.tx.res.rr.com NICK :PricklyPear'
				return nickPromise
			.then (e) ->
				e.oldNick.should.equal 'PakaluPapito'
				e.newNick.should.equal 'PricklyPear'
				client.listeners('nick').length.should.equal 0
				client.listeners('raw').length.should.equal 0
				done()



	describe 'msg', ->
		it 'should send a PRIVMSG', (done) ->
			client.msg '#girls', 'u want to see gas station'
			client.msg 'HotGurl22', 'i show u gas station'
			server.expect [
				'PRIVMSG #girls :u want to see gas station'
				'PRIVMSG HotGurl22 :i show u gas station'
			]
			.then done
			.catch done

		it 'should split long messages', (done) ->
			client.msg 'Pope', 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam mattis interdum nisi eu convallis. Vivamus non tortor sit amet dui feugiat lobortis nec faucibus risus. Mauris lacinia nunc sed felis viverra, nec dapibus elit gravida. Curabitur ac faucibus justo, id porttitor sapien. Ut sit amet orci massa. Aliquam ac lectus efficitur, eleifend ante a, fringilla elit. Sed ullamcorper porta velit, et euismod odio vestibulum et. Vestibulum luctus quam ut sapien tempus sollicitudin. Mauris magna odio, lacinia eget sollicitudin at, lobortis nec nunc. In hac habitasse platea dictumst. Maecenas mauris mauris, sodales sed nulla vitae, rutrum porta ipsum. Ut quis pellentesque elit.'
			server.expect [
				'PRIVMSG Pope :Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam mattis interdum nisi eu convallis. Vivamus non tortor sit amet dui feugiat lobortis nec faucibus risus. Mauris lacinia nunc sed felis viverra, nec dapibus elit gravida. Curabitur ac faucibus justo, id porttitor sapien. Ut sit amet orci massa. Aliquam ac lectus efficitur, eleifend ante a, fringilla elit. Sed ullamcorper porta velit, et euismo'
				'PRIVMSG Pope :d odio vestibulum et. Vestibulum luctus quam ut sapien tempus sollicitudin. Mauris magna odio, lacinia eget sollicitudin at, lobortis nec nunc. In hac habitasse platea dictumst. Maecenas mauris mauris, sodales sed nulla vitae, rutrum porta ipsum. Ut quis pellentesque elit.'
			]
			.then done
			.catch done

	describe 'action', ->
		it 'should send a PRIVMSG action', (done) ->
			client.action '#girls', 'shows u gas station'
			client.action 'HotGurl22', 'shows u camel'
			server.expect [
				'PRIVMSG #girls :\x01ACTION shows u gas station\x01'
				'PRIVMSG HotGurl22 :\x01ACTION shows u camel\x01'
			]
			.then done
			.catch done

		it 'should split long messages', (done) ->
			client.action 'Pope', 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam mattis interdum nisi eu convallis. Vivamus non tortor sit amet dui feugiat lobortis nec faucibus risus. Mauris lacinia nunc sed felis viverra, nec dapibus elit gravida. Curabitur ac faucibus justo, id porttitor sapien. Ut sit amet orci massa. Aliquam ac lectus efficitur, eleifend ante a, fringilla elit. Sed ullamcorper porta velit, et euismod odio vestibulum et. Vestibulum luctus quam ut sapien tempus sollicitudin. Mauris magna odio, lacinia eget sollicitudin at, lobortis nec nunc. In hac habitasse platea dictumst. Maecenas mauris mauris, sodales sed nulla vitae, rutrum porta ipsum. Ut quis pellentesque elit.'
			server.expect [
				'PRIVMSG Pope :\x01ACTION Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam mattis interdum nisi eu convallis. Vivamus non tortor sit amet dui feugiat lobortis nec faucibus risus. Mauris lacinia nunc sed felis viverra, nec dapibus elit gravida. Curabitur ac faucibus justo, id porttitor sapien. Ut sit amet orci massa. Aliquam ac lectus efficitur, eleifend ante a, fringilla elit. Sed ullamcorper porta ve\x01'
				'PRIVMSG Pope :\x01ACTION lit, et euismod odio vestibulum et. Vestibulum luctus quam ut sapien tempus sollicitudin. Mauris magna odio, lacinia eget sollicitudin at, lobortis nec nunc. In hac habitasse platea dictumst. Maecenas mauris mauris, sodales sed nulla vitae, rutrum porta ipsum. Ut quis pellentesque elit.\x01'
			]
			.then done
			.catch done

	describe 'notice', ->
		it 'should send a NOTICE', (done) ->
			client.notice '#girls', 'u want to see gas station'
			client.notice 'HotGurl22', 'i show u gas station'
			server.expect [
				'NOTICE #girls :u want to see gas station'
				'NOTICE HotGurl22 :i show u gas station'
			]
			.then done
			.catch done

		it 'should split long messages', (done) ->
			client.notice 'Pope', 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam mattis interdum nisi eu convallis. Vivamus non tortor sit amet dui feugiat lobortis nec faucibus risus. Mauris lacinia nunc sed felis viverra, nec dapibus elit gravida. Curabitur ac faucibus justo, id porttitor sapien. Ut sit amet orci massa. Aliquam ac lectus efficitur, eleifend ante a, fringilla elit. Sed ullamcorper porta velit, et euismod odio vestibulum et. Vestibulum luctus quam ut sapien tempus sollicitudin. Mauris magna odio, lacinia eget sollicitudin at, lobortis nec nunc. In hac habitasse platea dictumst. Maecenas mauris mauris, sodales sed nulla vitae, rutrum porta ipsum. Ut quis pellentesque elit.'
			server.expect [
				'NOTICE Pope :Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam mattis interdum nisi eu convallis. Vivamus non tortor sit amet dui feugiat lobortis nec faucibus risus. Mauris lacinia nunc sed felis viverra, nec dapibus elit gravida. Curabitur ac faucibus justo, id porttitor sapien. Ut sit amet orci massa. Aliquam ac lectus efficitur, eleifend ante a, fringilla elit. Sed ullamcorper porta velit, et euismod'
				'NOTICE Pope : odio vestibulum et. Vestibulum luctus quam ut sapien tempus sollicitudin. Mauris magna odio, lacinia eget sollicitudin at, lobortis nec nunc. In hac habitasse platea dictumst. Maecenas mauris mauris, sodales sed nulla vitae, rutrum porta ipsum. Ut quis pellentesque elit.'
			]
			.then done
			.catch done

	describe 'join', ->
		it 'a single channel with a callback', (done) ->
			client.join '#furry', async(done) (err, chan) ->
				should.not.exist err
				chan.should.be.equal '#furry'
				server.expect 'TOPIC #furry' # channel.coffee will auto ask for topic on creation
				.then done
				.catch done
			server.expect 'JOIN #furry'
			.then ->
				server.reply ':PakaluPapito!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com JOIN #furry'

		it 'an array of channels with a callback', (done) ->
			done = multiDone 2, done
			client.join ['#furry', '#wizard'], (err, channels) ->
				should.not.exist err
				channels[0].should.be.equal '#furry'
				channels[1].should.be.equal '#wizard'
				done()

			server.expect 'JOIN #furry,#wizard'
			.then ->
				server.reply ':PakaluPapito!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com JOIN #furry'
				server.reply ':PakaluPapito!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com JOIN #wizard'
				server.expect [ # channel.coffee will auto ask for topic on creation
					'TOPIC #furry'
					'TOPIC #wizard'
				]
			.then done
			.catch done

		it 'an array of channels should resolve the promise', (done) ->
			joinPromise = client.join ['#furry', '#wizard']
			server.expect 'JOIN #furry,#wizard'
			.then ->
				server.reply ':PakaluPapito!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com JOIN #furry'
				server.reply ':PakaluPapito!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com JOIN #wizard'
				server.expect [ # channel.coffee will auto ask for topic on creation
					'TOPIC #furry'
					'TOPIC #wizard'
				]
			.then -> joinPromise
			.then (e) ->
				e[0].should.be.equal '#furry'
				e[1].should.be.equal '#wizard'
				return
			.then done
			.catch done


	describe 'invite', ->
		it 'should send an INVITE', (done) ->
			client.invite 'HotBabe99', '#gasstation'
			server.expect 'INVITE HotBabe99 #gasstation'
			.then done
			.catch done

	describe 'part', ->
		it 'a single channel', (done) ->
			client.part '#furry'
			server.expect 'PART #furry'
			.then done
			.catch done

		it 'with a reason', (done) ->
			client.part '#furry', 'I\'m leaving.'
			server.expect 'PART #furry :I\'m leaving.'
			.then done
			.catch done

		it 'a single channel with a callback', (done) ->
			client.part '#furry', async(done) (err, chan) ->
				should.not.exist err
				chan.should.be.equal '#furry'
				done()
			server.expect 'PART #furry'
			.then ->
				server.reply ':PakaluPapito!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com PART #furry'

		it 'an array of channels', (done) ->
			client.part ['#furry', '#wizard', '#jayleno']
			server.expect 'PART #furry,#wizard,#jayleno'
			.then done
			.catch done

		it 'an array of channels with a callback should work for one channel in the array', (done) ->
			client.part ['#furry', '#wizard'], async(done) (err, channels) ->
				should.not.exist err
				channels[0].should.equal '#furry'
				channels[1].should.equal '#wizard'
				done()
			server.expect 'PART #furry,#wizard'
			.then ->
				server.reply ':PakaluPapito!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com PART #furry'
				server.reply ':PakaluPapito!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com PART #wizard'
		
		it 'an array of channels should resolve the promise', (done) ->
			partPromise = client.part ['#furry', '#wizard']
			server.expect 'PART #furry,#wizard'
			.then ->
				server.reply ':PakaluPapito!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com PART #furry'
				server.reply ':PakaluPapito!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com PART #wizard'
				partPromise
			.then (channels) ->
				channels[0].should.equal '#furry'
				channels[1].should.equal '#wizard'
				return
			.then done
			.catch done
	describe 'ssl', ->
		beforeEach (done) ->
			cleanUp client, server, done

		it 'should successfully connect', (done) ->
			server = new TestServer 6697, true
			client = new Client
				server: 'localhost'
				nick: 'PakaluPapito'
				messageDelay: 0
				autoReconnect: false
				autoConnect: false
				ssl: true
				selfSigned: true
				port: 6697
			connectPromise = client.connect()
			server.expect [
				'NICK PakaluPapito'
				'USER NodeIRCClient 8 * :NodeIRCClient'
			]
			.then ->
				server.reply ':localhost 001 PakaluPapito :Welcome to the IRCNet Internet Relay Chat Network PakaluPapito'
				connectPromise
			.then (nick) ->
				nick.should.equal 'PakaluPapito'
				done()

		it 'should throw an error for self signed certificates', (done) ->
			server = new TestServer 6697, true
			client = new Client
				server: 'localhost'
				nick: 'PakaluPapito'
				messageDelay: 0
				autoReconnect: false
				autoConnect: false
				verbose: false
				verboseError: false
				ssl: true
				selfSigned: false
				port: 6697
			client.connect()
			.catch (err) ->
				err.should.exist
				err.code.should.equal 'DEPTH_ZERO_SELF_SIGNED_CERT'
				done()
