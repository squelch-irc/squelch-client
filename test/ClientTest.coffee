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

cleanUp = (client, server) ->
	if client.isConnected()
		client.forceQuit()
		server.expect 'QUIT'
	server.close()


describe 'Client', ->
	client = server = null
	beforeEach (done) ->
		server = new TestServer 6667
		client = new Client
			server: 'localhost'
			nick: 'PakaluPapito'
			messageDelay: 0
			autoReconnect: false
			autoConnect: true
			verbose: false
		server.expect [
			'NICK PakaluPapito'
			'USER NodeIRCClient 8 * :NodeIRCClient'
		]
		.then ->
			server.reply ':localhost 001 PakaluPapito :Welcome to the IRCNet Internet Relay Chat Network PakaluPapito'
			client.on 'connect', -> done()

	afterEach ->
		cleanUp client, server

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

	# TODO: secure server connect

	describe 'disconnect', ->
		it 'should send QUIT to the server and null the connection', (done) ->
			client.disconnect()
			server.expect 'QUIT'
			.then done

		it 'should send a reason with the QUIT', (done) ->
			client.disconnect 'Choke on it.'
			server.expect 'QUIT :Choke on it.'
			.then done

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

	describe 'isConnected', ->
		beforeEach ->
			cleanUp client, server
		afterEach ->
			cleanUp client, server
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

	describe 'kick', ->
		it 'with single chan and nick', (done) ->
			client.kick '#persia', 'messenger'
			server.expect 'KICK #persia messenger'
			.then done
		it 'with multiple chans and nicks', (done) ->
			client.kick ['#persia', '#empire'], ['messenger1', 'messenger2', 'messenger3']
			server.expect 'KICK #persia,#empire messenger1,messenger2,messenger3'
			.then done
		it 'with a reason', (done) ->
			client.kick '#persia', 'messenger', 'THIS IS SPARTA!'
			server.expect 'KICK #persia messenger :THIS IS SPARTA!'
			.then done
			
	describe 'nick', ->
		it 'with no parameters should return the nick', ->
			client.nick().should.equal 'PakaluPapito'

		it 'with one parameter should send a NICK command', (done) ->
			client.nick 'PricklyPear'
			server.expect 'NICK PricklyPear'
			.then done

		it 'with two params should callback on success', (done) ->
			client.nick 'PricklyPear', async(done) (err, oldNick, newNick) ->
				should.not.exist err
				oldNick.should.equal 'PakaluPapito'
				newNick.should.equal 'PricklyPear'
				client.listeners('nick').length.should.equal 0
				client.listeners('raw').length.should.equal 0
				done()
			server.expect 'NICK PricklyPear'
			.then ->
				server.reply ':PakaluPapito!~NodeIRCClient@cpe-76-183-227-155.tx.res.rr.com NICK :PricklyPear'

		it 'with two params should callback on error 432', (done) ->
			client.nick '!@#$%^&*()', async(done) (err, oldNick, newNick) ->
				err.command.should.equal '432'
				should.not.exist oldNick
				should.not.exist newNick
				client.listeners('nick').length.should.equal 0
				client.listeners('raw').length.should.equal 0
				done()
			server.expect 'NICK !@#$%^&*()'
			.then ->
				client.handleReply ':irc.ircnet.net 432 Cage !@#$%^&*() :Erroneous Nickname'


	describe 'msg', ->
		it 'should send a PRIVMSG', (done) ->
			client.msg '#girls', 'u want to see gas station'
			client.msg 'HotGurl22', 'i show u gas station'
			server.expect [
				'PRIVMSG #girls :u want to see gas station'
				'PRIVMSG HotGurl22 :i show u gas station'
			]
			.then done

	describe 'action', ->
		it 'should send a PRIVMSG action', (done) ->
			client.action '#girls', 'shows u gas station'
			client.action 'HotGurl22', 'shows u camel'
			server.expect [
				'PRIVMSG #girls :\u0001ACTION shows u gas station\u0001'
				'PRIVMSG HotGurl22 :\u0001ACTION shows u camel\u0001'
			]
			.then done

	describe 'notice', ->
		it 'should send a NOTICE', (done) ->
			client.notice '#girls', 'u want to see gas station'
			client.notice 'HotGurl22', 'i show u gas station'
			server.expect [
				'NOTICE #girls :u want to see gas station'
				'NOTICE HotGurl22 :i show u gas station'
			]
			.then done

	describe 'join', ->
		it 'a single channel', (done) ->
			client.join '#furry'
			server.expect 'JOIN #furry'
			.then done

		it 'a single channel with a callback', (done) ->
			client.join '#furry', async(done) (chan, nick) ->
				chan.should.be.equal '#furry'
				nick.should.be.equal 'PakaluPapito'
				server.expect 'TOPIC #furry' # channel.coffee will auto ask for topic on creation
				.then done
			server.expect 'JOIN #furry'
			.then ->
				server.reply ':PakaluPapito!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com JOIN #furry'

		it 'an array of channels', (done) ->
			client.join ['#furry', '#wizard', '#jayleno']
			server.expect 'JOIN #furry,#wizard,#jayleno'
			.then done

		it 'an array of channels with a callback should work for one channel in the array', (done) ->
			client.join ['#furry', '#wizard'], async(done) (chan, nick) ->
				chan.should.be.equal '#furry'
				nick.should.be.equal 'PakaluPapito'
				server.expect 'TOPIC #furry' # channel.coffee will auto ask for topic on creation
				.then done
			server.expect 'JOIN #furry,#wizard'
			.then ->
				server.reply ':PakaluPapito!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com JOIN #furry'
		it 'an array of channels with a callback should work for another channel in the array', (done) ->
			client.join ['#furry', '#wizard'], async(done) (chan, nick) ->
				chan.should.be.equal '#wizard'
				nick.should.be.equal 'PakaluPapito'
				server.expect 'TOPIC #wizard' # channel.coffee will auto ask for topic on creation
				.then done
			server.expect 'JOIN #furry,#wizard'
			.then ->
				server.reply ':PakaluPapito!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com JOIN #wizard'

	describe 'invite', ->
		it 'should send an INVITE', (done) ->
			client.invite 'HotBabe99', '#gasstation'
			server.expect 'INVITE HotBabe99 #gasstation'
			.then done

	describe 'part', ->
		it 'a single channel', (done) ->
			client.part '#furry'
			server.expect 'PART #furry'
			.then done

		it 'a single channel with a reason', (done) ->
			client.part '#furry', 'I\'m leaving.'
			server.expect 'PART #furry :I\'m leaving.'
			.then done

		it 'a single channel with a callback', (done) ->
			client.part '#furry', async(done) (chan, nick) ->
				chan.should.be.equal '#furry'
				nick.should.be.equal 'PakaluPapito'
				done()
			server.expect 'PART #furry'
			.then ->
				server.reply ':PakaluPapito!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com PART #furry'

		it 'a single channel with a reason and callback', (done) ->
			client.part '#furry', 'I\'m leaving', async(done) (chan, nick) ->
				chan.should.be.equal '#furry'
				nick.should.be.equal 'PakaluPapito'
				done()
			server.expect 'PART #furry :I\'m leaving'
			.then ->
				server.reply ':PakaluPapito!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com PART #furry'

		it 'an array of channels', (done) ->
			client.part ['#furry', '#wizard', '#jayleno']
			server.expect 'PART #furry,#wizard,#jayleno'
			.then done

		it 'an array of channels with a reason', (done) ->
			client.part ['#furry', '#wizard', '#jayleno'], 'I\'m leaving.'
			server.expect 'PART #furry,#wizard,#jayleno :I\'m leaving.'
			.then done

		it 'an array of channels with a callback should work for one channel in the array', (done) ->
			client.part ['#furry', '#wizard'], async(done) (chan, nick) ->
				chan.should.be.equal '#furry'
				nick.should.be.equal 'PakaluPapito'
				done()
			server.expect 'PART #furry,#wizard'
			.then ->
				server.reply ':PakaluPapito!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com PART #furry'
		it 'an array of channels with a callback should work for another channel in the array', (done) ->
			client.part ['#furry', '#wizard'], async(done) (chan, nick) ->
				chan.should.be.equal '#wizard'
				nick.should.be.equal 'PakaluPapito'
				done()
			server.expect 'PART #furry,#wizard'
			.then ->
				server.reply ':PakaluPapito!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com PART #wizard'