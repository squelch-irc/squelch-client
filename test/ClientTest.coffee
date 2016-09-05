chai = require 'chai'
{expect} = chai
should = chai.should()
Promise = require 'bluebird'

Client = require '../src/client'
TestServer = require './TestServer'
{getReplyCode} = require '../src/replies'
{cleanUp} = require './helpers/util'

describe 'Client', ->
	client = server = null
	beforeEach ->
		server = new TestServer 6667, false
		client = new Client
			server: 'localhost'
			nick: 'PakaluPapito'
			messageDelay: 0
			autoReconnect: false
			autoConnect: false
			port: 6667
		connectPromise = client.connect()
		return server.expect [
			'NICK PakaluPapito'
			'USER NodeIRCClient 8 * :NodeIRCClient'
		]
		.then ->
			server.reply ':localhost 001 PakaluPapito :Welcome to the IRCNet Internet Relay Chat Network PakaluPapito'
			return connectPromise
		.then ({nick}) ->
			nick.should.equal 'PakaluPapito'


	afterEach ->
		return cleanUp client, server

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
		it 'should send QUIT to the server and null the connection', ->
			client.disconnect()
			return server.expect 'QUIT'

		it 'should send a reason with the QUIT', ->
			client.disconnect 'Choke on it.'
			return server.expect 'QUIT :Choke on it.'

		it 'should run the callback on successful disconnect', ->
			client._.disconnecting.should.be.false

			disconnectPromise = new Promise (resolve) ->
				client.disconnect ->
					client._.disconnecting.should.be.false
					client.isConnected().should.be.false
					client.isConnecting().should.be.false
					resolve()
			quitPromise = server.expect 'QUIT'
			.then ->
				client._.disconnecting.should.be.true
				server.reply 'ERROR :Closing Link: cpe-76-183-227-155.tx.res.rr.com (Client Quit)'
			return Promise.all([disconnectPromise, quitPromise])

		it 'should resolve the promise on successful disconnect', ->
			client._.disconnecting.should.be.false
			disconnectPromise = client.disconnect()
			return server.expect 'QUIT'
			.then ->
				client._.disconnecting.should.be.true
				server.reply 'ERROR :Closing Link: cpe-76-183-227-155.tx.res.rr.com (Client Quit)'
				return disconnectPromise
			.then ->
				client._.disconnecting.should.be.false
				client.isConnected().should.be.false
				client.isConnecting().should.be.false

	describe 'forceQuit', ->
		it 'should send a QUIT and immediately close the connection', ->
			client.forceQuit()
			return server.expect 'QUIT'
			.then ->
				client.isConnected().should.be.false
				client.isConnecting().should.be.false
				should.not.exist client.conn

		it 'should send a QUIT with a reason and immediately close the connection', ->
			client.forceQuit('screw this')
			server.expect 'QUIT :screw this'
			.then ->
				client.isConnected().should.be.false
				client.isConnecting().should.be.false
				should.not.exist client.conn

	describe 'isConnected/isConnecting', ->
		beforeEach ->
			return cleanUp client, server
		it 'should only be true when connected to the server', ->
			server = new TestServer 6667
			client = new Client
				server: 'localhost'
				nick: 'PakaluPapito'
				messageDelay: 0
				autoReconnect: false
				autoConnect: false

			client.isConnecting().should.be.false
			client.isConnected().should.be.false
			client.connect()
			client.isConnecting().should.be.true
			client.isConnected().should.be.false

			return server.expect [
				'NICK PakaluPapito'
				'USER NodeIRCClient 8 * :NodeIRCClient'
			]
			.then ->
				client.on 'connect', ->
					return new Promise (resolve) ->
						client.isConnected().should.be.true
						client.isConnecting().should.be.false
						resolve()
				server.reply ':localhost 001 PakaluPapito :Welcome to the IRCNet Internet Relay Chat Network PakaluPapito'

	describe 'autoRejoin', ->
		it 'should send a join command after a KICK', ->
			client.autoRejoin true
			client.join '#nice'
			return server.expect 'JOIN #nice'
			.then ->
				server.reply ':PakaluPapito!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com JOIN #nice'
				return new Promise (resolve) ->
					client.once 'join', resolve
			.then ({chan}) ->
				chan.should.equal '#nice'
				server.reply ':KR!~RayK@cpe-76-183-227-155.tx.res.rr.com KICK #nice PakaluPapito :Nice ppl only'
				server.expect 'JOIN #nice'

	describe 'raw', ->
		it 'should throw an error if client is not yet connected', ->
			return cleanUp client, server
			.then ->
				client = new Client
					server: 'localhost'
					nick: 'PakaluPapito'
					messageDelay: 0
					autoReconnect: false
					autoConnect: false
				(-> client.raw('send this message pleause')).should.throw(Error)
		it 'should do nothing if message is empty or missing', ->
			client.raw ''
			client.raw null
			client.raw

	describe 'kick', ->
		it 'with single chan and nick', ->
			client.kick '#persia', 'messenger'
			return server.expect 'KICK #persia messenger'

		it 'with multiple chans and nicks', ->
			client.kick ['#persia', '#empire'], ['messenger1', 'messenger2', 'messenger3']
			return server.expect [
				'KICK #persia messenger1'
				'KICK #persia messenger2'
				'KICK #persia messenger3'
				'KICK #empire messenger1'
				'KICK #empire messenger2'
				'KICK #empire messenger3'
			]

		it 'with a reason', ->
			client.kick '#persia', 'messenger', 'THIS IS SPARTA!'
			return server.expect 'KICK #persia messenger :THIS IS SPARTA!'

	describe 'nick', ->
		it 'with no parameters should return the nick', ->
			client.nick().should.equal 'PakaluPapito'

		it 'with one parameter should send a NICK command', ->
			client.nick 'PricklyPear'
			return server.expect 'NICK PricklyPear'

		it 'should not auto nick change while connected', (done) ->
			client.nick 'bloodninja'
			server.expect 'NICK bloodninja'
			.then ->
				server.reply ':irc.ircnet.net 433 * bloodninja :Nickname is already in use.'

			client.on 'raw', (reply) ->
				if reply.command is getReplyCode 'ERR_NICKNAMEINUSE'
					done()


	describe 'msg', ->
		it 'should send a PRIVMSG', ->
			client.msg '#girls', 'u want to see gas station'
			client.msg 'HotGurl22', 'i show u gas station'
			return server.expect [
				'PRIVMSG #girls :u want to see gas station'
				'PRIVMSG HotGurl22 :i show u gas station'
			]

		it 'should split long messages', ->
			client.msg 'Pope', 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam mattis interdum nisi eu convallis. Vivamus non tortor sit amet dui feugiat lobortis nec faucibus risus. Mauris lacinia nunc sed felis viverra, nec dapibus elit gravida. Curabitur ac faucibus justo, id porttitor sapien. Ut sit amet orci massa. Aliquam ac lectus efficitur, eleifend ante a, fringilla elit. Sed ullamcorper porta velit, et euismod odio vestibulum et. Vestibulum luctus quam ut sapien tempus sollicitudin. Mauris magna odio, lacinia eget sollicitudin at, lobortis nec nunc. In hac habitasse platea dictumst. Maecenas mauris mauris, sodales sed nulla vitae, rutrum porta ipsum. Ut quis pellentesque elit.'
			return server.expect [
				'PRIVMSG Pope :Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam mattis interdum nisi eu convallis. Vivamus non tortor sit amet dui feugiat lobortis nec faucibus risus. Mauris lacinia nunc sed felis viverra, nec dapibus elit gravida. Curabitur ac faucibus justo, id porttitor sapien. Ut sit amet orci massa. Aliquam ac lectus efficitur, eleifend ante a, fringilla elit. Sed ullamcorper porta velit, et euismo'
				'PRIVMSG Pope :d odio vestibulum et. Vestibulum luctus quam ut sapien tempus sollicitudin. Mauris magna odio, lacinia eget sollicitudin at, lobortis nec nunc. In hac habitasse platea dictumst. Maecenas mauris mauris, sodales sed nulla vitae, rutrum porta ipsum. Ut quis pellentesque elit.'
			]

		it 'should trigger a `msg` event if triggerEventsForOwnMessages is true', (done) ->
			client.triggerEventsForOwnMessages true
			client.autoSplitMessage false
			client.on 'msg', ({from, to, msg}) ->
				from.should.equal 'PakaluPapito'
				to.should.equal '#girls'
				msg.should.equal 'u want to see gas station'
				done()
			server.expect [
				'PRIVMSG #girls :u want to see gas station'
			]
			client.msg '#girls', 'u want to see gas station'

		it 'should trigger multiple `msg` event for long messages if triggerEventsForOwnMessages is true', (done) ->
			client.triggerEventsForOwnMessages true
			client.autoSplitMessage true
			client.once 'msg', ({from, to, msg}) ->
				from.should.equal 'PakaluPapito'
				to.should.equal 'Pope'
				msg.should.equal 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam mattis interdum nisi eu convallis. Vivamus non tortor sit amet dui feugiat lobortis nec faucibus risus. Mauris lacinia nunc sed felis viverra, nec dapibus elit gravida. Curabitur ac faucibus justo, id porttitor sapien. Ut sit amet orci massa. Aliquam ac lectus efficitur, eleifend ante a, fringilla elit. Sed ullamcorper porta velit, et euismo'
				client.once 'msg', ({from, to, msg}) ->
					from.should.equal 'PakaluPapito'
					to.should.equal 'Pope'
					msg.should.equal 'd odio vestibulum et. Vestibulum luctus quam ut sapien tempus sollicitudin. Mauris magna odio, lacinia eget sollicitudin at, lobortis nec nunc. In hac habitasse platea dictumst. Maecenas mauris mauris, sodales sed nulla vitae, rutrum porta ipsum. Ut quis pellentesque elit.'
					done()

			server.expect [
				'PRIVMSG Pope :Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam mattis interdum nisi eu convallis. Vivamus non tortor sit amet dui feugiat lobortis nec faucibus risus. Mauris lacinia nunc sed felis viverra, nec dapibus elit gravida. Curabitur ac faucibus justo, id porttitor sapien. Ut sit amet orci massa. Aliquam ac lectus efficitur, eleifend ante a, fringilla elit. Sed ullamcorper porta velit, et euismo'
				'PRIVMSG Pope :d odio vestibulum et. Vestibulum luctus quam ut sapien tempus sollicitudin. Mauris magna odio, lacinia eget sollicitudin at, lobortis nec nunc. In hac habitasse platea dictumst. Maecenas mauris mauris, sodales sed nulla vitae, rutrum porta ipsum. Ut quis pellentesque elit.'
			]
			client.msg 'Pope', 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam mattis interdum nisi eu convallis. Vivamus non tortor sit amet dui feugiat lobortis nec faucibus risus. Mauris lacinia nunc sed felis viverra, nec dapibus elit gravida. Curabitur ac faucibus justo, id porttitor sapien. Ut sit amet orci massa. Aliquam ac lectus efficitur, eleifend ante a, fringilla elit. Sed ullamcorper porta velit, et euismod odio vestibulum et. Vestibulum luctus quam ut sapien tempus sollicitudin. Mauris magna odio, lacinia eget sollicitudin at, lobortis nec nunc. In hac habitasse platea dictumst. Maecenas mauris mauris, sodales sed nulla vitae, rutrum porta ipsum. Ut quis pellentesque elit.'


	describe 'action', ->
		it 'should send a PRIVMSG action', ->
			client.action '#girls', 'shows u gas station'
			client.action 'HotGurl22', 'shows u camel'
			return server.expect [
				'PRIVMSG #girls :\x01ACTION shows u gas station\x01'
				'PRIVMSG HotGurl22 :\x01ACTION shows u camel\x01'
			]

		it 'should split long messages', ->
			client.action 'Pope', 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam mattis interdum nisi eu convallis. Vivamus non tortor sit amet dui feugiat lobortis nec faucibus risus. Mauris lacinia nunc sed felis viverra, nec dapibus elit gravida. Curabitur ac faucibus justo, id porttitor sapien. Ut sit amet orci massa. Aliquam ac lectus efficitur, eleifend ante a, fringilla elit. Sed ullamcorper porta velit, et euismod odio vestibulum et. Vestibulum luctus quam ut sapien tempus sollicitudin. Mauris magna odio, lacinia eget sollicitudin at, lobortis nec nunc. In hac habitasse platea dictumst. Maecenas mauris mauris, sodales sed nulla vitae, rutrum porta ipsum. Ut quis pellentesque elit.'
			return server.expect [
				'PRIVMSG Pope :\x01ACTION Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam mattis interdum nisi eu convallis. Vivamus non tortor sit amet dui feugiat lobortis nec faucibus risus. Mauris lacinia nunc sed felis viverra, nec dapibus elit gravida. Curabitur ac faucibus justo, id porttitor sapien. Ut sit amet orci massa. Aliquam ac lectus efficitur, eleifend ante a, fringilla elit. Sed ullamcorper porta ve\x01'
				'PRIVMSG Pope :\x01ACTION lit, et euismod odio vestibulum et. Vestibulum luctus quam ut sapien tempus sollicitudin. Mauris magna odio, lacinia eget sollicitudin at, lobortis nec nunc. In hac habitasse platea dictumst. Maecenas mauris mauris, sodales sed nulla vitae, rutrum porta ipsum. Ut quis pellentesque elit.\x01'
			]

		it 'should trigger a `action` event if triggerEventsForOwnMessages is true', (done) ->
			client.triggerEventsForOwnMessages true
			client.autoSplitMessage false
			client.on 'action', ({from, to, msg}) ->
				from.should.equal 'PakaluPapito'
				to.should.equal '#girls'
				msg.should.equal 'shows u gas station'
				done()
			server.expect [
				'PRIVMSG #girls :\x01ACTION shows u gas station\x01'
			]
			client.action '#girls', 'shows u gas station'

		it 'should trigger multiple `action` event for long messages if triggerEventsForOwnMessages is true', (done) ->
			client.triggerEventsForOwnMessages true
			client.autoSplitMessage true
			client.once 'action', ({from, to, msg}) ->
				from.should.equal 'PakaluPapito'
				to.should.equal 'Pope'
				msg.should.equal 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam mattis interdum nisi eu convallis. Vivamus non tortor sit amet dui feugiat lobortis nec faucibus risus. Mauris lacinia nunc sed felis viverra, nec dapibus elit gravida. Curabitur ac faucibus justo, id porttitor sapien. Ut sit amet orci massa. Aliquam ac lectus efficitur, eleifend ante a, fringilla elit. Sed ullamcorper porta ve'
				client.once 'action', ({from, to, msg}) ->
					from.should.equal 'PakaluPapito'
					to.should.equal 'Pope'
					msg.should.equal 'lit, et euismod odio vestibulum et. Vestibulum luctus quam ut sapien tempus sollicitudin. Mauris magna odio, lacinia eget sollicitudin at, lobortis nec nunc. In hac habitasse platea dictumst. Maecenas mauris mauris, sodales sed nulla vitae, rutrum porta ipsum. Ut quis pellentesque elit.'
					done()

			server.expect [
				'PRIVMSG Pope :\x01ACTION Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam mattis interdum nisi eu convallis. Vivamus non tortor sit amet dui feugiat lobortis nec faucibus risus. Mauris lacinia nunc sed felis viverra, nec dapibus elit gravida. Curabitur ac faucibus justo, id porttitor sapien. Ut sit amet orci massa. Aliquam ac lectus efficitur, eleifend ante a, fringilla elit. Sed ullamcorper porta ve\x01'
				'PRIVMSG Pope :\x01ACTION lit, et euismod odio vestibulum et. Vestibulum luctus quam ut sapien tempus sollicitudin. Mauris magna odio, lacinia eget sollicitudin at, lobortis nec nunc. In hac habitasse platea dictumst. Maecenas mauris mauris, sodales sed nulla vitae, rutrum porta ipsum. Ut quis pellentesque elit.\x01'
			]
			client.action 'Pope', 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam mattis interdum nisi eu convallis. Vivamus non tortor sit amet dui feugiat lobortis nec faucibus risus. Mauris lacinia nunc sed felis viverra, nec dapibus elit gravida. Curabitur ac faucibus justo, id porttitor sapien. Ut sit amet orci massa. Aliquam ac lectus efficitur, eleifend ante a, fringilla elit. Sed ullamcorper porta velit, et euismod odio vestibulum et. Vestibulum luctus quam ut sapien tempus sollicitudin. Mauris magna odio, lacinia eget sollicitudin at, lobortis nec nunc. In hac habitasse platea dictumst. Maecenas mauris mauris, sodales sed nulla vitae, rutrum porta ipsum. Ut quis pellentesque elit.'

	describe 'notice', ->
		it 'should send a NOTICE', ->
			client.notice '#girls', 'u want to see gas station'
			client.notice 'HotGurl22', 'i show u gas station'
			return server.expect [
				'NOTICE #girls :u want to see gas station'
				'NOTICE HotGurl22 :i show u gas station'
			]

		it 'should split long messages', ->
			client.notice 'Pope', 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam mattis interdum nisi eu convallis. Vivamus non tortor sit amet dui feugiat lobortis nec faucibus risus. Mauris lacinia nunc sed felis viverra, nec dapibus elit gravida. Curabitur ac faucibus justo, id porttitor sapien. Ut sit amet orci massa. Aliquam ac lectus efficitur, eleifend ante a, fringilla elit. Sed ullamcorper porta velit, et euismod odio vestibulum et. Vestibulum luctus quam ut sapien tempus sollicitudin. Mauris magna odio, lacinia eget sollicitudin at, lobortis nec nunc. In hac habitasse platea dictumst. Maecenas mauris mauris, sodales sed nulla vitae, rutrum porta ipsum. Ut quis pellentesque elit.'
			return server.expect [
				'NOTICE Pope :Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam mattis interdum nisi eu convallis. Vivamus non tortor sit amet dui feugiat lobortis nec faucibus risus. Mauris lacinia nunc sed felis viverra, nec dapibus elit gravida. Curabitur ac faucibus justo, id porttitor sapien. Ut sit amet orci massa. Aliquam ac lectus efficitur, eleifend ante a, fringilla elit. Sed ullamcorper porta velit, et euismod'
				'NOTICE Pope : odio vestibulum et. Vestibulum luctus quam ut sapien tempus sollicitudin. Mauris magna odio, lacinia eget sollicitudin at, lobortis nec nunc. In hac habitasse platea dictumst. Maecenas mauris mauris, sodales sed nulla vitae, rutrum porta ipsum. Ut quis pellentesque elit.'
			]

		it 'should trigger a `notice` event if triggerEventsForOwnMessages is true', (done) ->
			client.triggerEventsForOwnMessages true
			client.autoSplitMessage false
			client.on 'notice', ({from, to, msg}) ->
				from.should.equal 'PakaluPapito'
				to.should.equal 'HotGurl22'
				msg.should.equal 'i show u gas station'
				done()
			server.expect [
				'NOTICE HotGurl22 :i show u gas station'
			]
			client.notice 'HotGurl22', 'i show u gas station'

		it 'should trigger multiple `notice` event for long messages if triggerEventsForOwnMessages is true', (done) ->
			client.triggerEventsForOwnMessages true
			client.autoSplitMessage true
			client.once 'notice', ({from, to, msg}) ->
				from.should.equal 'PakaluPapito'
				to.should.equal 'Pope'
				msg.should.equal 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam mattis interdum nisi eu convallis. Vivamus non tortor sit amet dui feugiat lobortis nec faucibus risus. Mauris lacinia nunc sed felis viverra, nec dapibus elit gravida. Curabitur ac faucibus justo, id porttitor sapien. Ut sit amet orci massa. Aliquam ac lectus efficitur, eleifend ante a, fringilla elit. Sed ullamcorper porta velit, et euismod'
				client.once 'notice', ({from, to, msg}) ->
					from.should.equal 'PakaluPapito'
					to.should.equal 'Pope'
					msg.should.equal ' odio vestibulum et. Vestibulum luctus quam ut sapien tempus sollicitudin. Mauris magna odio, lacinia eget sollicitudin at, lobortis nec nunc. In hac habitasse platea dictumst. Maecenas mauris mauris, sodales sed nulla vitae, rutrum porta ipsum. Ut quis pellentesque elit.'
					done()

			server.expect [
				'NOTICE Pope :Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam mattis interdum nisi eu convallis. Vivamus non tortor sit amet dui feugiat lobortis nec faucibus risus. Mauris lacinia nunc sed felis viverra, nec dapibus elit gravida. Curabitur ac faucibus justo, id porttitor sapien. Ut sit amet orci massa. Aliquam ac lectus efficitur, eleifend ante a, fringilla elit. Sed ullamcorper porta velit, et euismod'
				'NOTICE Pope : odio vestibulum et. Vestibulum luctus quam ut sapien tempus sollicitudin. Mauris magna odio, lacinia eget sollicitudin at, lobortis nec nunc. In hac habitasse platea dictumst. Maecenas mauris mauris, sodales sed nulla vitae, rutrum porta ipsum. Ut quis pellentesque elit.'
			]
			client.notice 'Pope', 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam mattis interdum nisi eu convallis. Vivamus non tortor sit amet dui feugiat lobortis nec faucibus risus. Mauris lacinia nunc sed felis viverra, nec dapibus elit gravida. Curabitur ac faucibus justo, id porttitor sapien. Ut sit amet orci massa. Aliquam ac lectus efficitur, eleifend ante a, fringilla elit. Sed ullamcorper porta velit, et euismod odio vestibulum et. Vestibulum luctus quam ut sapien tempus sollicitudin. Mauris magna odio, lacinia eget sollicitudin at, lobortis nec nunc. In hac habitasse platea dictumst. Maecenas mauris mauris, sodales sed nulla vitae, rutrum porta ipsum. Ut quis pellentesque elit.'

	describe 'join', ->
		it 'a single channel', ->
			client.join '#furry'
			return server.expect 'JOIN #furry'

		it 'a single channel with a key', ->
			client.join '#furry', 'password'
			return server.expect 'JOIN #furry password'

		it 'an array of channels', ->
			client.join ['#furry', '#wizard']
			return server.expect 'JOIN #furry,#wizard'

	describe 'invite', ->
		it 'should send an INVITE', ->
			client.invite 'HotBabe99', '#gasstation'
			return server.expect 'INVITE HotBabe99 #gasstation'

	describe 'part', ->
		it 'a single channel', ->
			client.part '#furry'
			return server.expect 'PART #furry'

		it 'with a reason', ->
			client.part '#furry', 'I\'m leaving.'
			return server.expect 'PART #furry :I\'m leaving.'

		it 'an array of channels', ->
			client.part ['#furry', '#wizard', '#jayleno']
			return server.expect 'PART #furry,#wizard,#jayleno'

	describe 'mode', ->
		it 'should send a MODE', ->
			client.mode '#kellyirc', '+ck password'
			return server.expect 'MODE #kellyirc +ck password'

		it 'op should send a +o for a single user', ->
			client.op '#kellyirc', 'user1'
			return server.expect 'MODE #kellyirc +o user1'

		it 'op should send a +ooo for 3 users', ->
			client.op '#kellyirc', ['user1', 'user2', 'user3']
			return server.expect 'MODE #kellyirc +ooo user1 user2 user3'

		it 'deop should send a -o for a single user', ->
			client.deop '#kellyirc', 'user1'
			return server.expect 'MODE #kellyirc -o user1'

		it 'deop should send a -ooo for 3 users', ->
			client.deop '#kellyirc', ['user1', 'user2', 'user3']
			return server.expect 'MODE #kellyirc -ooo user1 user2 user3'

		it 'voice should send a +v for a single user', ->
			client.voice '#kellyirc', 'user1'
			return server.expect 'MODE #kellyirc +v user1'

		it 'voice should send a +vvv for 3 users', ->
			client.voice '#kellyirc', ['user1', 'user2', 'user3']
			return server.expect 'MODE #kellyirc +vvv user1 user2 user3'

		it 'devoice should send a -v for a single user', ->
			client.devoice '#kellyirc', 'user1'
			return server.expect 'MODE #kellyirc -v user1'

		it 'devoice should send a -vvv for 3 users', ->
			client.devoice '#kellyirc', ['user1', 'user2', 'user3']
			return server.expect 'MODE #kellyirc -vvv user1 user2 user3'

		describe 'topic', ->
			beforeEach ->
				server.reply [
					':PakaluPapito!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com JOIN #sexy'
					':availo.esper.net 332 PakaluPapito #sexy :Welcome to the #sexy!'
					':availo.esper.net 333 PakaluPapito #sexy KR!~KR@78-72-225-13-no193.business.telia.com 1394457068'
					'PING :finished'
				]
				return server.expect 'PONG :finished'

			it 'should set a TOPIC', ->
				client.topic '#sexy', 'This is topic now'
				return server.expect 'TOPIC #sexy :This is topic now'

			it 'should request a TOPIC', ->
				client.topic '#sexy'
				return server.expect 'TOPIC #sexy'

	describe 'ssl', ->
		beforeEach ->
			return cleanUp client, server

		it 'should successfully connect', ->
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
			return server.expect [
				'NICK PakaluPapito'
				'USER NodeIRCClient 8 * :NodeIRCClient'
			]
			.then ->
				server.reply ':localhost 001 PakaluPapito :Welcome to the IRCNet Internet Relay Chat Network PakaluPapito'
				return connectPromise
			.then ({nick}) ->
				nick.should.equal 'PakaluPapito'

		it 'should throw an error for self signed certificates', ->
			server = new TestServer 6697, true
			client = new Client
				server: 'localhost'
				nick: 'PakaluPapito'
				messageDelay: 0
				autoReconnect: false
				autoConnect: false
				ssl: true
				selfSigned: false
				port: 6697
			return client.connect()
			.catch (err) ->
				err.should.exist
				err.code.should.equal 'DEPTH_ZERO_SELF_SIGNED_CERT'
