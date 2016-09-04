Promise = require 'bluebird'
chai = require 'chai'
{expect} = chai
should = chai.should()

Client = require '../src/client'
TestServer = require './TestServer'
{cleanUp, multiDone} = require './helpers/util'

describe 'handleReply simulations', ->
	client = server = null
	beforeEach ->
		server = new TestServer 6667
		client = new Client
			server: 'localhost'
			nick: 'PakaluPapito'
			messageDelay: 0
			autoReconnect: false
			autoConnect: false
		connectPromise = client.connect()
		return server.expect [
			'NICK PakaluPapito'
			'USER NodeIRCClient 8 * :NodeIRCClient'
		]
		.then ->
			server.reply ':localhost 001 PakaluPapito :Welcome to the IRCNet Internet Relay Chat Network PakaluPapito'
			connectPromise
		.then ({nick}) ->
			nick.should.equal 'PakaluPapito'
			server.reply [
				':availo.esper.net 002 PakaluPapito :Your host is irc.ircnet.net[127.0.0.1/6667], running version charybdis-3.3.0'
				':availo.esper.net 003 PakaluPapito :This server was created Sun Feb 5 2012 at 23:12:30 CET'
				':availo.esper.net 004 PakaluPapito irc.ircnet.net charybdis-3.3.0 DQRSZagiloswz CFILPQbcefgijklmnopqrstvz bkloveqjfI'
				':availo.esper.net 005 PakaluPapito CHANTYPES=# EXCEPTS INVEX CHANMODES=eIbq,k,flj,CFPcgimnpstz CHANLIMIT=#:50 PREFIX=(ov)@+ MAXLIST=bqeI:100 MODES=4 NETWORK=IRCNet KNOCK STATUSMSG=@+ CALLERID=g :are supported by this server'
				':availo.esper.net 005 PakaluPapito CASEMAPPING=rfc1459 CHARSET=ascii NICKLEN=30 CHANNELLEN=50 TOPICLEN=390 ETRACE CPRIVMSG CNOTICE DEAF=D MONITOR=100 FNC TARGMAX=NAMES:1,LIST:1,KICK:1,WHOIS:1,PRIVMSG:4,NOTICE:4,ACCEPT:,MONITOR: :are supported by this server'
				':availo.esper.net 005 PakaluPapito EXTBAN=$,acjorsxz WHOX CLIENTVER=3.0 SAFELIST ELIST=CTU :are supported by this server'
				':PakaluPapito!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com JOIN #sexy'
				':availo.esper.net 332 PakaluPapito #sexy :Welcome to the #sexy!'
				':availo.esper.net 333 PakaluPapito #sexy KR!~KR@78-72-225-13-no193.business.telia.com 1394457068'
				':availo.esper.net 353 PakaluPapito * #sexy :PakaluPapito @KR Freek +Kurea Chase'
				':availo.esper.net 366 PakaluPapito #sexy :End of /NAMES list.'
				':PakaluPapito!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com JOIN #Furry'
				':availo.esper.net 332 PakaluPapito #Furry :Welcome to the #Furry! We have furries.'
				':availo.esper.net 333 PakaluPapito #Furry NotKR!~NotKR@78-72-225-13-no193.business.telia.com 1394457070'
				':availo.esper.net 353 PakaluPapito * #Furry :PakaluPapito @abcdeFurry +Bud'
				':availo.esper.net 366 PakaluPapito #Furry :End of /NAMES list.'
				'PING :finished'
			]
			server.expect [
				'PONG :finished'
			]

	afterEach ->
		cleanUp client, server

	it 'should read the iSupport values correctly', ->
		client._.iSupport['CHANTYPES'] = '#'
		client._.iSupport['CASEMAPPING'] = 'rfc1459'

	it 'should know what a channel is (isChannel)', ->
		client.isChannel('#burp').should.be.true
		client.isChannel('Clarence').should.be.false
		client.isChannel('&burp').should.be.false

	it 'should know the nick prefixes and chanmodes', ->
		client.modeToPrefix('o').should.equal '@'
		client.modeToPrefix('v').should.equal '+'
		client._.chanmodes[0].should.equal 'eIbq'
		client._.chanmodes[1].should.equal 'k'
		client._.chanmodes[2].should.equal 'flj'
		client._.chanmodes[3].should.equal 'CFPcgimnpstz'

	describe 'raw', ->
		it 'should emit raw event for a reply', (done) ->
			client.once 'raw', (msg) ->
				msg.command.should.equal 'PING'
				msg.params[0].should.equal 'FFFFFFFFBD03A0B0'
				server.expect 'PONG :FFFFFFFFBD03A0B0'
				.then done
			server.reply 'PING :FFFFFFFFBD03A0B0'

		it 'should emit raw event for some other reply', (done) ->
			client.once 'raw', (msg) ->
				msg.command.should.equal 'PRIVMSG'
				msg.params[0].should.equal '#kellyirc'
				msg.params[1].should.equal 'Current modules are...'
				done()
			server.reply ':Kurea!~Kurea@162.243.123.251 PRIVMSG #kellyirc :Current modules are...'

	describe '001', ->
		beforeEach ->
			cleanUp client, server

		it 'should save its given nick', ->
			client._.nick.should.equal 'PakaluPapito'

		it 'should emit connect events with the right nick', (done) ->
			server = new TestServer 6667
			client = new Client
				server: 'localhost'
				nick: 'PakaluPapito'
				messageDelay: 0
				autoReconnect: false
				autoConnect: false

			server.expect [
				'NICK PakaluPapito'
				'USER NodeIRCClient 8 * :NodeIRCClient'
			]
			.then ->
				server.reply ':localhost 001 PakaluPapito :Welcome to the IRCNet Internet Relay Chat Network PakaluPapito'
				# Gotta use e b/c it conflicts with test `server`
			client.once 'connecting', (e) ->
				e.server.should.equal 'localhost'
				e.port.should.equal 6667

				client.once 'connection-established', (e) ->
					e.server.should.equal 'localhost'
					e.port.should.equal 6667

					client.once 'connect', (e) ->
						e.server.should.equal 'localhost'
						e.port.should.equal 6667
						e.nick.should.equal 'PakaluPapito'
						done()

			client.connect()
			return

		it 'should reconnect if using multiple tries', (done) ->
			server = testServer = new TestServer 6667
			client = new Client
				server: 'localhost'
				nick: 'PakaluPapito'
				messageDelay: 0
				autoReconnect: false
				autoConnect: false
				reconnectDelay: 50
			client.once 'reconnecting', ({server, port, delay, triesLeft}) ->
				server.should.equal 'localhost'
				port.should.equal 6667
				delay.should.equal 50
				triesLeft.should.equal 1
				testServer.expect [
					'NICK PakaluPapito'
					'USER NodeIRCClient 8 * :NodeIRCClient'
				]
				.then ->
					testServer.reply ':localhost 001 PakaluPapito :Welcome to the IRCNet Internet Relay Chat Network PakaluPapito'
				client.once 'connect', -> done()

			client.connect(2)
			# immediately disconnect
			client.conn.destroy()
			client.conn.emit 'error', 'test disconnection'

		it 'should auto join the channels in opt.channels', ->
			server = new TestServer 6667
			client = new Client
				server: 'localhost'
				nick: 'PakaluPapito'
				messageDelay: 0
				autoReconnect: false
				channels: ['#sexy', '#Furry']
			return server.expect [
				'NICK PakaluPapito'
				'USER NodeIRCClient 8 * :NodeIRCClient'
			]
			.then ->
				server.reply ':localhost 001 PakaluPapito :Welcome to the IRCNet Internet Relay Chat Network PakaluPapito'
				return server.expect 'JOIN #sexy,#Furry'

	describe '372,375,376 (motd)', ->
		it 'should save the motd properly and emit a motd event', (done) ->
			# Thank you Brian Lee https://twitter.com/LRcomic/status/434440616051634176
			client.once 'motd', ({motd}) ->
				motd.should.equal '''
					irc.ircnet.net Message of the Day\r\n\
					THE ROSES ARE RED\r\n\
					THE VIOLETS ARE BLUE\r\n\
					IGNORE THIS LINE\r\n\
					THIS IS A HAIKU\r\n
				'''
				done()

			server.reply [
				':irc.ircnet.net 375 PakaluPapito :irc.ircnet.net Message of the Day'
				':irc.ircnet.net 372 PakaluPapito :THE ROSES ARE RED'
				':irc.ircnet.net 372 PakaluPapito :THE VIOLETS ARE BLUE'
				':irc.ircnet.net 372 PakaluPapito :IGNORE THIS LINE'
				':irc.ircnet.net 372 PakaluPapito :THIS IS A HAIKU'
				':irc.ircnet.net 376 PakaluPapito :End of /MOTD command.'
			]

	describe '433', ->
		beforeEach ->
			cleanUp client, server
		it 'should automatically try a new nick', ->
			# This happens before the 001 event so need to make a new client
			server = new TestServer 6667
			client = new Client
				server: 'localhost'
				nick: 'PakaluPapito'
				messageDelay: 0
				autoReconnect: false
				channels: ['#sexy', '#Furry']
			return server.expect [
				'NICK PakaluPapito'
				'USER NodeIRCClient 8 * :NodeIRCClient'
			]
			.then ->
				server.reply ':irc.ircnet.net 433 * PakaluPapito :Nickname is already in use.'
				return server.expect 'NICK PakaluPapito1'
			.then ->
				server.reply ':irc.ircnet.net 433 * PakaluPapito1 :Nickname is already in use.'
				return server.expect 'NICK PakaluPapito2'
			.then ->
				server.reply ':irc.ircnet.net 433 * PakaluPapito2 :Nickname is already in use.'
				return server.expect 'NICK PakaluPapito3'

	describe 'ping', ->
		it 'should respond to PINGs', ->
			server.reply 'PING :FFFFFFFFBD03A0B0'
			return server.expect 'PONG :FFFFFFFFBD03A0B0'

	describe 'join', ->
		it 'should emit a join event', (done) ->
			server.reply ':HotGurl!~Gurl22@cpe-76-183-227-155.tx.res.rr.com JOIN #sexy'
			client.once 'join', ({chan, nick, me}) ->
				chan.should.equal '#sexy'
				nick.should.equal 'HotGurl'
				me.should.be.false
				done()

		it 'should set `me` to true if it is the client', (done) ->
			server.reply ':PakaluPapito!~NodeIRCClient@cpe-76-183-227-155.tx.res.rr.com JOIN #gasstation'
			client.once 'join', ({chan, nick, me}) ->
				chan.should.equal '#gasstation'
				nick.should.equal 'PakaluPapito'
				me.should.be.true
				done()



	describe 'part', ->
		it 'should emit a part event', (done) ->
			server.reply ':KR!~RayK@cpe-76-183-227-155.tx.res.rr.com PART #sexy'
			client.once 'part', ({chan, nick, me}) ->
				chan.should.equal '#sexy'
				nick.should.equal 'KR'
				me.should.be.false
				done()

		it 'should set `me` to true if it is the client', (done) ->
			server.reply ':PakaluPapito!~NodeIRCClient@cpe-76-183-227-155.tx.res.rr.com PART #sexy'
			client.once 'part', ({chan, nick, me}) ->
				chan.should.equal '#sexy'
				nick.should.equal 'PakaluPapito'
				me.should.be.true
				done()

	describe 'nick', ->
		it 'should emit a nick event', (done) ->
			client.once 'nick', ({oldNick, newNick, me}) ->
				oldNick.should.equal 'KR'
				newNick.should.equal 'RK'
				me.should.be.false
				done()
			server.reply ':KR!~RayK@cpe-76-183-227-155.tx.res.rr.com NICK :RK'

		it 'should update its own nick', (done) ->
			client._.nick.should.equal 'PakaluPapito'
			server.reply ':PakaluPapito!~NodeIRCClient@cpe-76-183-227-155.tx.res.rr.com NICK :SteelUrGirl'
			client.once 'nick', ({oldNick, newNick, me}) ->
				me.should.be.true
				client._.nick.should.equal 'SteelUrGirl'
				done()

	describe 'error', ->
		it 'should emit an error event', (done) ->
			client.once 'error', (msg) ->
				msg.params[0].should.equal 'Closing Link: cpe-76-183-227-155.tx.res.rr.com (Client Quit)'
				done()
			server.reply 'ERROR :Closing Link: cpe-76-183-227-155.tx.res.rr.com (Client Quit)'

	describe 'kick', ->
		it 'should emit a kick event', (done) ->
			server.reply ':KR!~RayK@cpe-76-183-227-155.tx.res.rr.com KICK #sexy Freek'
			client.once 'kick', ({chan, nick, kicker, reason, me}) ->
				chan.should.equal '#sexy'
				nick.should.equal 'Freek'
				kicker.should.equal 'KR'
				should.not.exist reason
				me.should.be.false
				done()

		it 'should set `me` to true if it is the client', (done) ->
			server.reply ':KR!~RayK@cpe-76-183-227-155.tx.res.rr.com KICK #sexy PakaluPapito :THIS IS SPARTA!'
			client.once 'kick', ({chan, nick, kicker, reason, me}) ->
				chan.should.equal '#sexy'
				nick.should.equal 'PakaluPapito'
				kicker.should.equal 'KR'
				reason.should.equal 'THIS IS SPARTA!'
				me.should.be.true
				done()

	describe 'quit', ->
		it 'should emit a quit event', (done) ->
			server.reply ':Chase!kalt@millennium.stealth.net QUIT :Choke on it.'
			client.once 'quit', ({nick, reason}) ->
				nick.should.equal 'Chase'
				reason.should.equal 'Choke on it.'
				done()

	describe 'msg', ->
		it 'should emit a msg event', (done) ->
			client.once 'msg', ({from, to, msg}) ->
				from.should.equal 'Chase'
				to.should.equal '#sexy'
				msg.should.equal 'Choke on it.'
				done()
			server.reply ':Chase!kalt@millennium.stealth.net PRIVMSG #sexy :Choke on it.'
		it 'should strip colors', (done) ->
			client.once 'msg', ({from, to, msg}) ->
				from.should.equal 'Chase'
				to.should.equal '#sexy'
				msg.should.equal 'Choke on it.'
				done()
			server.reply ':Chase!kalt@millennium.stealth.net PRIVMSG #sexy :\x0304Choke on it.\x03'
		it 'should strip styles', (done) ->
			client.once 'msg', ({from, to, msg}) ->
				from.should.equal 'Chase'
				to.should.equal '#sexy'
				msg.should.equal 'Choke on it.'
				done()
			server.reply ':Chase!kalt@millennium.stealth.net PRIVMSG #sexy :\x02Choke on it.\x02'


	describe 'action', ->
		it 'should emit an action event', (done) ->
			client.once 'action', ({from, to, msg}) ->
				from.should.equal 'Chase'
				to.should.equal '#sexy'
				msg.should.equal 'chokes on it.'
				done()
			server.reply ':Chase!kalt@millennium.stealth.net PRIVMSG #sexy :\u0001ACTION chokes on it.\u0001'
	describe 'notice', ->
		it 'should emit a notice event', (done) ->
			client.once 'notice', ({from, to, msg}) ->
				from.should.equal 'Stranger'
				to.should.equal 'PakaluPapito'
				msg.should.equal 'I\'ll hurt you.'
				done()
			server.reply ':Stranger!kalt@millennium.stealth.net NOTICE PakaluPapito :I\'ll hurt you.'
		it 'should emit a notice event from a server correctly', (done) ->
			client.once 'notice', ({from, to, msg}) ->
				from.should.equal 'irc.ircnet.net'
				to.should.equal '*'
				msg.should.equal '*** Looking up your hostname...'
				done()
			server.reply ':irc.ircnet.net NOTICE * :*** Looking up your hostname...'
	describe 'invite', ->
		it 'should emit an invite event', (done) ->
			client.once 'invite', ({from, chan}) ->
				from.should.equal 'Angel'
				chan.should.equal '#dust'
				done()
			server.reply ':Angel!wings@irc.org INVITE PakaluPapito #dust'

	describe 'names', ->
		it 'should emit an names event', (done) ->
			client.once 'names', ({chan, names}) ->
				chan.should.equal '#sexy'
				names.should.deep.equal
					PakaluPapito: ''
					KR: '@'
					Freek: ''
					Kurea: '+'
					Chase: ''
				done()
			server.reply [
				':availo.esper.net 353 PakaluPapito * #sexy :PakaluPapito @KR Freek +Kurea Chase'
				':availo.esper.net 366 PakaluPapito #sexy :End of /NAMES list.'
			]

	describe 'mode', ->
		it 'should emit a mode event for +o-o with params (prefix mode)', (done) ->
			client.once 'mode', ({chan, sender, mode}) ->
				chan.should.equal '#sexy'
				sender.should.equal 'KR'
				mode.should.equal '-o+o KR Chase'
				done()
			server.reply ':KR!~RayK@cpe-76-183-227-155.tx.res.rr.com MODE #sexy -o+o KR Chase'

		it 'should emit a +mode event for +n (type D mode)', (done) ->
			client.once '+mode', ({chan, sender, mode, param}) ->
				chan.should.equal '#sexy'
				sender.should.equal 'irc.ircnet.net'
				mode.should.equal 'n'
				should.not.exist param
				done()
			server.reply ':irc.ircnet.net MODE #sexy +n'

		it 'should emit a -mode and +mode event for +o-o with params (prefix mode)', (done) ->
			client.once '-mode', ({chan, sender, mode, param}) ->
				chan.should.equal '#sexy'
				sender.should.equal 'KR'
				mode.should.equal 'o'
				param.should.equal 'KR'
				client.once '+mode', ({chan, sender, mode, param}) ->
					chan.should.equal '#sexy'
					sender.should.equal 'KR'
					mode.should.equal 'o'
					param.should.equal 'Chase'
					done()
			server.reply ':KR!~RayK@cpe-76-183-227-155.tx.res.rr.com MODE #sexy -o+o KR Chase'

		it 'should emit a -mode event for -b with param (type A mode)', (done) ->
			client.once '-mode', ({chan, sender, mode, param}) ->
				chan.should.equal '#sexy'
				sender.should.equal 'KR'
				mode.should.equal 'b'
				param.should.equal 'RK!*@*'
				done()
			server.reply ':KR!~RayK@cpe-76-183-227-155.tx.res.rr.com MODE #sexy -b RK!*@*'

		it 'should emit a -mode event for -k with param (type B mode)', (done) ->
			client.once '-mode', ({chan, sender, mode, param}) ->
				chan.should.equal '#sexy'
				sender.should.equal 'KR'
				mode.should.equal 'k'
				param.should.equal 'password'
				done()
			server.reply ':KR!~RayK@cpe-76-183-227-155.tx.res.rr.com MODE #sexy -k password'

		it 'should emit a +mode event for +l with param (type C mode)', (done) ->
			client.once '+mode', ({chan, sender, mode, param}) ->
				chan.should.equal '#sexy'
				sender.should.equal 'KR'
				mode.should.equal 'l'
				param.should.equal '25'
				done()
			server.reply ':KR!~RayK@cpe-76-183-227-155.tx.res.rr.com MODE #sexy +l 25'

		it 'should emit a -mode event for -l without param (type C mode)', (done) ->
			client.once '-mode', ({chan, sender, mode, param}) ->
				chan.should.equal '#sexy'
				sender.should.equal 'KR'
				mode.should.equal 'l'
				should.not.exist param
				done()
			server.reply ':KR!~RayK@cpe-76-183-227-155.tx.res.rr.com MODE #sexy -l'

	describe 'usermode', ->
		it 'should emit usermode for modes on users', (done) ->
			client.once 'usermode', ({user, mode, sender}) ->
				user.should.equal 'Freek'
				mode.should.equal '+o'
				sender.should.equal 'CoolIRCOp'
				done()
			server.reply ':CoolIRCOp!~wow@cpe-76-183-227-155.tx.res.rr.com MODE Freek +o'
		it 'should emit +usermode for modes on users', (done) ->
			client.once '+usermode', ({user, mode, sender}) ->
				user.should.equal 'Freek'
				mode.should.equal 'o'
				sender.should.equal 'CoolIRCOp'
				done()
			server.reply ':CoolIRCOp!~wow@cpe-76-183-227-155.tx.res.rr.com MODE Freek +o'

		it 'should emit -usermode for modes on users', (done) ->
			client.once '-usermode', ({user, mode, sender}) ->
				user.should.equal 'Freek'
				mode.should.equal 'o'
				sender.should.equal 'CoolIRCOp'
				done()
			server.reply ':CoolIRCOp!~wow@cpe-76-183-227-155.tx.res.rr.com MODE Freek -o'

	describe 'timeout', ->
		lastReplyTime = null
		beforeEach (done) ->
			cleanUp client, server
			.then ->
				server = new TestServer 6667
				client = new Client
					server: 'localhost'
					nick: 'PakaluPapito'
					messageDelay: 0
					autoReconnect: false
					timeout: 50 # Just large enough to run tests
				server.expect [
					'NICK PakaluPapito'
					'USER NodeIRCClient 8 * :NodeIRCClient'
				]
				.then ->
					server.reply ':localhost 001 PakaluPapito :Welcome to the IRCNet Internet Relay Chat Network PakaluPapito'
					lastReplyTime = Date.now()
					client.once 'connect', ({nick}) ->
						done()
			return
		it 'should send a PING to the server after a timeout', ->
			return server.expect 'PING :ruthere'
			.then ->
				((Date.now() - lastReplyTime) >= 50).should.be.true
				server.reply [
					':irc.ircnet.net PONG irc.ircnet.net :ruthere'
					'PING :finished'
				]
				return server.expect 'PONG :finished'
			.then ->
				client.isConnected().should.be.true

		it 'should emit timeout, error, and disconnect events after a timeout', (done) ->
			done = multiDone 3, done
			server.expect 'PING :ruthere'
			.then ->
				((Date.now() - lastReplyTime) >= 50).should.be.true
				client.once 'timeout', ->
					done()
				client.once 'error', ->
					done()
				client.once 'disconnect', ->
					done()
			return

	describe 'topic', ->
		it 'should emit topic for NOTOPIC reply', (done) ->
			client.once 'topic', ({chan, topic}) ->
				chan.should.equal '#sexy'
				topic.should.equal ''
				done()
			server.reply ':anarchy.esper.net 331 PakaluPapito #sexy :No topic is set'

		it 'should emit topic for TOPIC reply', (done) ->
			client.once 'topic', ({chan, topic}) ->
				chan.should.equal '#sexy'
				topic.should.equal 'We must transcend our flesh bodies for the astral plane.'
				done()
			server.reply ':anarchy.esper.net 332 PakaluPapito #sexy :We must transcend our flesh bodies for the astral plane.'
		it 'should emit topicwho for TOPIC_WHO_TIME reply', (done) ->
			client.once 'topicwho', ({chan, hostmask, time}) ->
				chan.should.equal '#sexy'
				hostmask.should.equal 'KR!~KR@78-72-225-13-no193.business.telia.com'
				time.getTime().should.equal 1394457068
				done()
			server.reply ':availo.esper.net 333 PakaluPapito #sexy KR!~KR@78-72-225-13-no193.business.telia.com 1394457068'

	describe 'network-error', ->
		beforeEach ->
			cleanUp client, server

		it 'should emit an error and disconnect event', (finalDone) ->
			server = new TestServer 6667
			client = new Client
				server: 'localhost'
				nick: 'BadNetworkBoy'
				messageDelay: 0
				autoReconnect: false
				channels: []
			done = multiDone 2, (args...) ->
				client.isConnected().should.be.false
				expect(client.conn).to.be.null
				finalDone args...

			server.expect [
				'NICK BadNetworkBoy'
				'USER NodeIRCClient 8 * :NodeIRCClient'
			]
			.then ->
				server.reply ':localhost 001 BadNetworkBoy :Welcome to the IRCNet Internet Relay Chat Network PakaluPapito'

			client.once 'connect', ->
				client.once 'error', (e) ->
					done()
				client.once 'disconnect', (e) ->
					done()

				client.conn.emit 'error', message: 'EFAKEERROR'
