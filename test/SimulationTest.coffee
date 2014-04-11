chai = require 'chai'
{expect} = chai
should = chai.should()

Client = require '../src/client'
TestClient = require './TestClient'

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

describe 'handleReply simulations', ->
	client = null

	beforeEach ->
		client = new TestClient
			server: "irc.ircnet.net"
			nick: "PakaluPapito"
			channels: ["#sexy", "#Furry"]
			verbose: false
		client.handleReplies [
			":irc.ircnet.net 001 PakaluPapito :Welcome to the IRCNet Internet Relay Chat Network PakaluPapito"
			":availo.esper.net 002 PakaluPapito :Your host is irc.ircnet.net[127.0.0.1/6667], running version charybdis-3.3.0"
			":availo.esper.net 003 PakaluPapito :This server was created Sun Feb 5 2012 at 23:12:30 CET"
			":availo.esper.net 004 PakaluPapito irc.ircnet.net charybdis-3.3.0 DQRSZagiloswz CFILPQbcefgijklmnopqrstvz bkloveqjfI"
			":availo.esper.net 005 PakaluPapito CHANTYPES=# EXCEPTS INVEX CHANMODES=eIbq,k,flj,CFPcgimnpstz CHANLIMIT=#:50 PREFIX=(ov)@+ MAXLIST=bqeI:100 MODES=4 NETWORK=IRCNet KNOCK STATUSMSG=@+ CALLERID=g :are supported by this server"
			":availo.esper.net 005 PakaluPapito CASEMAPPING=rfc1459 CHARSET=ascii NICKLEN=30 CHANNELLEN=50 TOPICLEN=390 ETRACE CPRIVMSG CNOTICE DEAF=D MONITOR=100 FNC TARGMAX=NAMES:1,LIST:1,KICK:1,WHOIS:1,PRIVMSG:4,NOTICE:4,ACCEPT:,MONITOR: :are supported by this server"
			":availo.esper.net 005 PakaluPapito EXTBAN=$,acjorsxz WHOX CLIENTVER=3.0 SAFELIST ELIST=CTU :are supported by this server"
			":availo.esper.net 251 PakaluPapito :There are 13 users and 7818 invisible on 11 servers"
			":availo.esper.net 252 PakaluPapito 35 :IRC Operators online"
			":availo.esper.net 253 PakaluPapito 1 :unknown connection(s)"
			":availo.esper.net 254 PakaluPapito 5065 :channels formed"
			":availo.esper.net 255 PakaluPapito :I have 2166 clients and 1 servers"
			":availo.esper.net 265 PakaluPapito 2166 5215 :Current local users 2166, max 5215"
			":availo.esper.net 266 PakaluPapito 7831 9054 :Current global users 7831, max 9054"
			":availo.esper.net 250 PakaluPapito :Highest connection count: 5216 (5215 clients) (2518758 connections received)"
			":PakaluPapito!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com JOIN #sexy"
			":availo.esper.net 332 PakaluPapito #sexy :Welcome to the #sexy!"
			":availo.esper.net 333 PakaluPapito #sexy KR!~KR@78-72-225-13-no193.business.telia.com 1394457068"
			":availo.esper.net 353 PakaluPapito * #sexy :PakaluPapito @KR Freek +Kurea Chase ^Freek"
			":availo.esper.net 366 PakaluPapito #kellyirc :End of /NAMES list."
			":PakaluPapito!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com JOIN #Furry"
			":availo.esper.net 332 PakaluPapito #Furry :Welcome to the #Furry! We have furries."
			":availo.esper.net 333 PakaluPapito #Furry NotKR!~NotKR@78-72-225-13-no193.business.telia.com 1394457070"
			":availo.esper.net 353 PakaluPapito * #Furry :PakaluPapito @abcdeFurry +Bud"
			":availo.esper.net 366 PakaluPapito #kellyirc :End of /NAMES list."
		]

	it 'should read the iSupport values correctly', ->
		client._.iSupport["CHANTYPES"] = "#"
		client._.iSupport["CASEMAPPING"] = "rfc1459"

	it 'should know what a channel is (isChannel)', ->
		client.isChannel("#burp").should.be.true
		client.isChannel("Clarence").should.be.false
		client.isChannel("&burp").should.be.false

	describe 'channel objects', ->
		it 'should have created one for #sexy and #Furry', ->
			client._.channels["#sexy"].should.exist
			client._.channels["#sexy"].name().should.equal "#sexy"
			client._.channels["#sexy"].topic().should.equal "Welcome to the #sexy!"
			client._.channels["#sexy"].topicSetter().should.equal "KR!~KR@78-72-225-13-no193.business.telia.com"
			client._.channels["#sexy"].topicTime().getTime().should.equal 1394457068
			client._.channels["#sexy"]._.users["KR"].should.equal "@"
			client._.channels["#sexy"]._.users["Kurea"].should.equal "+"
			client._.channels["#sexy"]._.users["Chase"].should.equal ""
			should.not.exist client._.channels["#sexy"]._.users["Bud"]

			client._.channels["#furry"].should.exist
			client._.channels["#furry"].should.exist
			client._.channels["#furry"].name().should.equal "#Furry"
			client._.channels["#furry"].topic().should.equal "Welcome to the #Furry! We have furries."
			client._.channels["#furry"].topicSetter().should.equal "NotKR!~NotKR@78-72-225-13-no193.business.telia.com"
			client._.channels["#furry"].topicTime().getTime().should.equal 1394457070
			# eh good enough

	it 'should know the nick prefixes and chanmodes', ->
		client._.prefix.o.should.equal "@"
		client._.prefix.v.should.equal "+"
		client._.chanmodes[0].should.equal "eIbq"
		client._.chanmodes[1].should.equal "k"
		client._.chanmodes[2].should.equal "flj"
		client._.chanmodes[3].should.equal "CFPcgimnpstz"

	describe 'raw', ->
		it 'should emit raw event for a reply', (done) ->
			client.once 'raw', async(done) (msg) ->
				msg.command.should.equal "PING"
				msg.params[0].should.equal "FFFFFFFFBD03A0B0"
				done()
			client.handleReply "PING :FFFFFFFFBD03A0B0"

		it 'should emit raw event for some other reply', (done) ->
			client.once 'raw', async(done) (msg) ->
				msg.command.should.equal "PRIVMSG"
				msg.params[0].should.equal "#kellyirc"
				msg.params[1].should.equal "Current modules are..."
				done()
			client.handleReply ":Kurea!~Kurea@162.243.123.251 PRIVMSG #kellyirc :Current modules are..."

	describe '001', ->
		it 'should save its given nick', ->
			client._.nick.should.equal "PakaluPapito"

		it 'should emit a connect event with the right nick', (done) ->
			# Need to attach the listener before it handles the reply
			client = new TestClient
				server: "irc.ircnet.net"
				nick: "PakaluPapito"
				verbose: false
			client.once 'connect', async(done) (nick) ->
				nick.should.equal "PakaluPapito"
				done()
			client.handleReply ":irc.ircnet.net 001 PakaluPapito :Welcome to the IRCNet Internet Relay Chat Network PakaluPapito"

		it 'should auto join the channels in opt.channels', ->
			client.happened("JOIN #sexy,#Furry").should.be.true

	describe '372,375,376 (motd)', ->
		it 'should save the motd properly and emit a motd event', (done) ->
			# Thank you Brian Lee https://twitter.com/LRcomic/status/434440616051634176
			client.once 'motd', async(done) (motd) ->
				motd.should.equal "irc.ircnet.net Message of the Day\r\n\
					THE ROSES ARE RED\r\n\
					THE VIOLETS ARE BLUE\r\n\
					IGNORE THIS LINE\r\n\
					THIS IS A HAIKU\r\n"
				done()

			client.handleReplies [
				":irc.ircnet.net 375 PakaluPapito :irc.ircnet.net Message of the Day"
				":irc.ircnet.net 372 PakaluPapito :THE ROSES ARE RED"
				":irc.ircnet.net 372 PakaluPapito :THE VIOLETS ARE BLUE"
				":irc.ircnet.net 372 PakaluPapito :IGNORE THIS LINE"
				":irc.ircnet.net 372 PakaluPapito :THIS IS A HAIKU"
				":irc.ircnet.net 376 PakaluPapito :End of /MOTD command."
			]

	describe '433', ->
		it 'should automatically try a new nick', ->
			# This happens before the 001 event so need to make a new client
			client = new TestClient
				server: "irc.ircnet.net"
				nick: "PakaluPapito"
				verbose: false
			client.handleReply ":irc.ircnet.net 433 * PakaluPapito :Nickname is already in use."
			client.happened "NICK PakaluPapito1"
			client.handleReply ":irc.ircnet.net 433 * PakaluPapito1 :Nickname is already in use."
			client.happened "NICK PakaluPapito2"
			client.handleReply ":irc.ircnet.net 433 * PakaluPapito2 :Nickname is already in use."
			client.happened "NICK PakaluPapito3"

	describe 'ping', ->
		it 'should respond to PINGs', ->
			client.handleReply "PING :FFFFFFFFBD03A0B0"
			client.happened("PONG :FFFFFFFFBD03A0B0").should.be.true

	describe 'join', ->
		it 'should add the user to the channel', ->
			client.handleReply ":HotGurl!~Gurl22@cpe-76-183-227-155.tx.res.rr.com JOIN #sexy"
			client.getChannel("#sexy").users().indexOf("HotGurl").should.not.equal -1

		it 'should create the channel if it is the client', ->
			should.not.exist client.getChannel("#gasstation")
			client.handleReply ":PakaluPapito!~NodeIRCClient@cpe-76-183-227-155.tx.res.rr.com JOIN #gasstation"
			client.getChannel("#gasstation").should.exist

		it 'should emit a join event', (done) ->
			client.once 'join', async(done) (chan, nick) ->
				chan.should.equal "#sexy"
				nick.should.equal "HotGurl"
				done()
			client.handleReply ":HotGurl!~Gurl22@cpe-76-183-227-155.tx.res.rr.com JOIN #sexy"
			client.getChannel("#sexy").users().indexOf("HotGurl").should.not.equal -1

		it 'should emit a join#chan event', (done) ->
			client.once 'join#sexy', async(done) (chan, nick) ->
				chan.should.equal "#sexy"
				nick.should.equal "HotGurl"
				done()
			client.handleReply ":HotGurl!~Gurl22@cpe-76-183-227-155.tx.res.rr.com JOIN #sexy"

		it 'should emit a join#chan event in lowercase', (done) ->
			client.once 'join#testchan', async(done) (chan, nick) ->
				chan.should.equal "#testChan"
				nick.should.equal "PakaluPapito"
				done()
			client.handleReply ":PakaluPapito!~NodeIRCClient@cpe-76-183-227-155.tx.res.rr.com JOIN #testChan"

	describe 'part', ->
		it 'should remove the user from the channels users', ->
			client.getChannel("#sexy").users().indexOf("KR").should.not.equal -1
			client.handleReply ":KR!~RayK@cpe-76-183-227-155.tx.res.rr.com PART #sexy"
			client.getChannel("#sexy").users().indexOf("KR").should.equal -1

		it 'should remove the channel if the nick is the client', ->
			client.getChannel("#sexy").should.exist
			client.handleReply ":PakaluPapito!~NodeIRCClient@cpe-76-183-227-155.tx.res.rr.com PART #sexy"
			should.not.exist client.getChannel("#sexy")

		it 'should emit a part event', (done) ->
			client.once 'part', async(done) (chan, nick) ->
				chan.should.equal "#sexy"
				nick.should.equal "KR"
				done()
			client.handleReply ":KR!~RayK@cpe-76-183-227-155.tx.res.rr.com PART #sexy"

		it 'should emit a part#chan event', (done) ->
			client.once 'part#sexy', async(done) (chan, nick) ->
				chan.should.equal "#sexy"
				nick.should.equal "KR"
				done()
			client.handleReply ":KR!~RayK@cpe-76-183-227-155.tx.res.rr.com PART #sexy"

		it 'should emit a part#chan event in lowercase', (done) ->
			client.once 'part#furry', async(done) (chan, nick) ->
				chan.should.equal "#Furry"
				nick.should.equal "PakaluPapito"
				done()
			client.handleReply ":PakaluPapito!~NodeIRCClient@cpe-76-183-227-155.tx.res.rr.com PART #Furry"

	describe 'nick', ->
		it 'should emit a nick event', (done) ->
			client.once 'nick', async(done) (oldnick, newnick) ->
				oldnick.should.equal "KR"
				newnick.should.equal "RK"
				done()
			client.handleReply ":KR!~RayK@cpe-76-183-227-155.tx.res.rr.com NICK :RK"

		it 'should update its own nick', ->
			client._.nick.should.equal "PakaluPapito"
			client.handleReply ":PakaluPapito!~NodeIRCClient@cpe-76-183-227-155.tx.res.rr.com NICK :SteelUrGirl"
			client._.nick.should.equal "SteelUrGirl"

	describe 'error', ->
		it 'should emit an error event', (done) ->
			client.once 'error', async(done) (msg) ->
				msg.should.equal "Closing Link: cpe-76-183-227-155.tx.res.rr.com (Client Quit)"
				done()
			client.handleReply "ERROR :Closing Link: cpe-76-183-227-155.tx.res.rr.com (Client Quit)"
		it 'should emit an disconnect event', (done) ->
			client._.disconnecting.should.be.false
			client.once 'disconnect', async(done) () ->
				done()
			client.disconnect() # won't trigger error if disconnecting
			client._.disconnecting.should.be.true
			client.handleReply "ERROR :Closing Link: cpe-76-183-227-155.tx.res.rr.com (Client Quit)"
			client._.disconnecting.should.be.false

	describe 'kick', ->
		it 'should remove the user from the channels users', ->
			client.getChannel("#sexy").users().indexOf("Freek").should.not.equal -1
			client.handleReply ":KR!~RayK@cpe-76-183-227-155.tx.res.rr.com KICK #sexy Freek"
			client.getChannel("#sexy").users().indexOf("Freek").should.equal -1

		it 'should remove the channel if the nick is the client', ->
			client.getChannel("#sexy").should.exist
			client.handleReply ":KR!~RayK@cpe-76-183-227-155.tx.res.rr.com KICK #sexy PakaluPapito"
			should.not.exist client.getChannel("#sexy")

		it 'should emit a kick event', (done) ->
			client.once 'kick', async(done) (chan, nick, kicker, reason) ->
				chan.should.equal "#sexy"
				nick.should.equal "Freek"
				kicker.should.equal "KR"
				should.not.exist reason
				done()
			client.handleReply ":KR!jto@tolsun.oulu.fi KICK #sexy Freek"
		it 'should emit a kick event with a reason', (done) ->
			client.once 'kick', async(done) (chan, nick, kicker, reason) ->
				chan.should.equal "#sexy"
				nick.should.equal "Freek"
				kicker.should.equal "KR"
				reason.should.equal "THIS IS SPARTA!"
				done()
			client.handleReply ":KR!jto@tolsun.oulu.fi KICK #sexy Freek :THIS IS SPARTA!"

	describe 'quit', ->
		it 'should remove the user from the channels they are in', ->
			client.getChannel("#sexy").users().indexOf("Chase").should.not.equal -1
			client.handleReply ":Chase!kalt@millennium.stealth.net QUIT :Choke on it."
			client.getChannel("#sexy").users().indexOf("Chase").should.equal -1

		it 'should emit a quit event', (done) ->
			client.once 'quit', async(done) (nick, reason) ->
				nick.should.equal "Chase"
				reason.should.equal "Choke on it."
				done()
			client.handleReply ":Chase!kalt@millennium.stealth.net QUIT :Choke on it."

	describe 'msg', ->
		it 'should emit a msg event', (done) ->
			client.once 'msg', async(done) (from, to, msg) ->
				from.should.equal "Chase"
				to.should.equal "#sexy"
				msg.should.equal "Choke on it."
				done()
			client.handleReply ":Chase!kalt@millennium.stealth.net PRIVMSG #sexy :Choke on it."

	describe 'action', ->
		it 'should emit an action event', (done) ->
			client.once 'action', async(done) (from, to, action) ->
				from.should.equal "Chase"
				to.should.equal "#sexy"
				action.should.equal "chokes on it."
				done()
			client.handleReply ":Chase!kalt@millennium.stealth.net PRIVMSG #sexy :\u0001ACTION chokes on it.\u0001"
	describe 'notice', ->
		it 'should emit a notice event', (done) ->
			client.once 'notice', async(done) (from, to, msg) ->
				from.should.equal "Stranger"
				to.should.equal "PakaluPapito"
				msg.should.equal "I'll hurt you."
				done()
			client.handleReply ":Stranger!kalt@millennium.stealth.net NOTICE PakaluPapito :I'll hurt you."
		it 'should emit a notice event from a server correctly', (done) ->
			client.once 'notice', async(done) (from, to, msg) ->
				from.should.equal "irc.ircnet.net"
				to.should.equal "*"
				msg.should.equal "*** Looking up your hostname..."
				done()
			client.handleReply ":irc.ircnet.net NOTICE * :*** Looking up your hostname..."
	describe 'invite', ->
		it 'should emit an invite event', (done) ->
			client.once 'invite', async(done) (from, chan) ->
				from.should.equal "Angel"
				chan.should.equal "#dust"
				done()
			client.handleReply ":Angel!wings@irc.org INVITE PakaluPapito #dust"
	describe 'mode', ->
		it 'should emit a +mode event for +n (type D mode)', (done) ->
			client.once '+mode', async(done) (chan, sender, mode, param) ->
				chan.should.equal "#sexy"
				sender.should.equal "irc.ircnet.net"
				mode.should.equal "n"
				should.not.exist param
				done()
			client.handleReply ":irc.ircnet.net MODE #sexy +n"

		it 'should emit a +mode event for +o with param (prefix mode)', (done) ->
			client.once '+mode', async(done) (chan, sender, mode, param) ->
				chan.should.equal "#sexy"
				sender.should.equal "KR"
				mode.should.equal "o"
				console.log client._.prefix
				param.should.equal "Freek"
				done()
			client.handleReply ":KR!~RayK@cpe-76-183-227-155.tx.res.rr.com MODE #sexy +o Freek"

		it 'should emit a -mode event for -b with param (type A mode)', (done) ->
			client.once '-mode', async(done) (chan, sender, mode, param) ->
				chan.should.equal "#sexy"
				sender.should.equal "KR"
				mode.should.equal "b"
				param.should.equal "RK!*@*"
				done()
			client.handleReply ":KR!~RayK@cpe-76-183-227-155.tx.res.rr.com MODE #sexy -b RK!*@*"

		it 'should emit a -mode event for -k with param (type B mode)', (done) ->
			client.once '-mode', async(done) (chan, sender, mode, param) ->
				chan.should.equal "#sexy"
				sender.should.equal "KR"
				mode.should.equal "k"
				param.should.equal "password"
				done()
			client.handleReply ":KR!~RayK@cpe-76-183-227-155.tx.res.rr.com MODE #sexy -k password"

		it 'should emit a +mode event for +l with param (type C mode)', (done) ->
			client.once '+mode', async(done) (chan, sender, mode, param) ->
				chan.should.equal "#sexy"
				sender.should.equal "KR"
				mode.should.equal "l"
				param.should.equal "25"
				done()
			client.handleReply ":KR!~RayK@cpe-76-183-227-155.tx.res.rr.com MODE #sexy +l 25"

		it 'should emit a -mode event for -l without param (type C mode)', (done) ->
			client.once '-mode', async(done) (chan, sender, mode, param) ->
				chan.should.equal "#sexy"
				sender.should.equal "KR"
				mode.should.equal "l"
				should.not.exist param
				done()
			client.handleReply ":KR!~RayK@cpe-76-183-227-155.tx.res.rr.com MODE #sexy -l"

		it 'should update the users status in the channel object for +o', ->
			client.getChannel("#sexy")._.users["Freek"].should.equal ""
			client.handleReply ":KR!~RayK@cpe-76-183-227-155.tx.res.rr.com MODE #sexy +o Freek"
			client.getChannel("#sexy")._.users["Freek"].should.equal "@"

		it 'should update the users status in the channel object for +v', ->
			client.getChannel("#sexy")._.users["Chase"].should.equal ""
			client.handleReply ":KR!~RayK@cpe-76-183-227-155.tx.res.rr.com MODE #sexy +v Chase"
			client.getChannel("#sexy")._.users["Chase"].should.equal "+"

		it 'should update the users status in the channel object for -v', ->
			client.getChannel("#sexy")._.users["Kurea"].should.equal "+"
			client.handleReply ":KR!~RayK@cpe-76-183-227-155.tx.res.rr.com MODE #sexy -v Kurea"
			client.getChannel("#sexy")._.users["Kurea"].should.equal ""

	describe 'usermode', ->
		it 'should emit +usermode for modes on users', (done) ->
			client.once '+usermode', async(done) (user, mode, sender) ->
				user.should.equal "Freek"
				mode.should.equal "o"
				sender.should.equal "CoolIRCOp"
				done()
			client.handleReply ":CoolIRCOp!~wow@cpe-76-183-227-155.tx.res.rr.com MODE Freek +o"

		it 'should emit -usermode for modes on users', (done) ->
			client.once '-usermode', async(done) (user, mode, sender) ->
				user.should.equal "Freek"
				mode.should.equal "o"
				sender.should.equal "CoolIRCOp"
				done()
			client.handleReply ":CoolIRCOp!~wow@cpe-76-183-227-155.tx.res.rr.com MODE Freek -o"