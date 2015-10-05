# squelch-client


An IRC Client for Node.js written in CoffeeScript, used in the Squelch IRC client.

## Documentation

You can find the full documentation [here](https://github.com/squelch-irc/squelch-client/wiki/Client).

## Installation

`npm install squelch-client`

## Example usage

There will be more extensive examples soon. For now, here is a simple IRC echo bot in CoffeeScript.

```coffeescript
Client = require 'squelch-client'

client = new Client
	server: "irc.esper.net"
	nick: "TestBot"
	autoConnect: false
	channels: ["#kellyirc"]

client.connect()
.then ({nick}) ->
	client.on 'msg', ({from, to, msg}) ->
		if to is "#kellyirc"
			client.msg to, "ECHO: #{msg}"
```

## Debugging

By default, squelch-client does not output anything to the console. If you wish to see debug output, run node with the `DEBUG` environment variable set to `squelch-client:*`. To only output errors, use `squelch-client:error`.

`$ DEBUG=squelch-client:* node main.js`

## Running tests

Grunt is used to run the tests. Clone the repo and run `npm install` and `npm install -g grunt-cli` for dependencies. Then to run the tests, run `grunt test`.

