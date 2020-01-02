# DNSUpdater - Dynamic DNS (DDNS)

Using this application you can update DNS records on local or remote (over SSH or HTTP) DNS server (eg. PowerDNS).

For example if you have dynamic IP you can use this application to automatically update DNS record with your external IP.

## Installation

First you need to have Ruby and RubyGems.
Then you can install it with:

```sh
$ gem install DNSUpdater
```

### Install Systemd service files

```sh
$ cp service/dnsupdater.{service,timer} /etc/systemd/system/
$ systemctl enable dnsupdater.timer
```

Note that you'll need to edit `/etc/systemd/system/dnsupdater.service` to set target domain.

### Configure

Create `/etc/dnsupdater.yaml` with your settings, take a look at [config_example.yaml](config_example.yaml).

By default configuration file will be looked into current directory as `config.yaml` or in `/etc/dnsupdater.yaml`.
But you can specify any config path with `-c` flag.

## Usage

```sh
$ updateDNS -h
Usage: updateDNS [options] <target>
    -c, --config config.yaml         Path to config file
    -t, --target=PROTOCOL            Target protocol (useful for SSH)
    -s, --serve                      Serve/handle HTTP
    -h, --help                       Show this message

Supported targets are: http, https, powerdns, ssh
Target examples:
* default:///example.com/10.0.0.1
* ssh://dns.example.com:123/example.org/client
* http://example.org/dns.example.com/127.0.0.1,192.168.1.1
```

### Update DNS record on locally installed PowerDNS

`$ updateDNS powerdns:///domain.example.com/192.168.1.1`

Note that you'll need to set PowerDNS HTTP API key in config.

### Update DNS record on remote PowerDNS over SSH with current external IP

`$ updateDNS ssh://ssh.example.org/domain.example.com/client`

`client` as IP means that DNS record will be updated with your external IP (client IP from target DNS server point).

SSH settings can also be configured in `~/.ssh/config` which will be respected.

### HTTP server mode

DNSUpdater can also work as HTTP server and update DNS records from clients.

`$ updateDNS --serve http://192.168.1.2/`

For authentication you'll need to set `SharedSecret` in config.
Also I recommend placing it behind Nginx.

Then clients can do
```
$ updateDNS http://192.168.1.2/domain.example.com/client
```

PS. It also accepts DynDNS format: `/nic/update?hostname=yourhostname&myip=ipaddress`

### Update DNS record on firewalled remote PowerDNS over SSH with HTTP

Suppose you have 3 machines:

`A` - internal firewalled PowerDNS server which isn't accessible publicly.

`B` - publicly accessible HTTP server.

`C` - client who's external IP you want to set.


On `B` you would run `updateDNS -s` in HTTP server mode configured that it updates PowerDNS on `A` over SSH.

On `C` you would run `updateDNS https://B/mydomain.example.com/client`

## Updaters/Providers

Basically currently there's support only for PowerDNS and don't have BIND support,
but it should be pretty easy to add support for others so just send a PR :)

## Documentation

YARD with markdown is used for documentation (`redcarpet` required)

## Specs

RSpec and simplecov are required, to run tests just `rake spec`
code coverage will also be generated

## Code status
[![Gem Version](https://badge.fury.io/rb/DNSUpdater.png)](http://badge.fury.io/rb/DNSUpdater)
[![Build Status](https://travis-ci.org/davispuh/DNSUpdater.png?branch=master)](https://travis-ci.org/davispuh/DNSUpdater)
[![Coverage Status](https://coveralls.io/repos/davispuh/DNSUpdater/badge.png?branch=master)](https://coveralls.io/r/davispuh/DNSUpdater?branch=master)

## Unlicense

![Copyright-Free](http://unlicense.org/pd-icon.png)

All text, documentation, code and files in this repository are in public domain (including this text, README).
It means you can copy, modify, distribute and include in your own work/code, even for commercial purposes, all without asking permission.

[About Unlicense](http://unlicense.org/)

## Contributing

Feel free to improve as you see.

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Export `.yaml` data files to binary `.dat` with `rake export`
4. Commit your changes (`git commit -am 'Add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create new Pull Request


**Warning**: By sending pull request to this repository you dedicate any and all copyright interest in pull request (code files and all other) to the public domain. (files will be in public domain even if pull request doesn't get merged)

Also before sending pull request you acknowledge that you own all copyrights or have authorization to dedicate them to public domain.

If you don't want to dedicate code to public domain or if you're not allowed to (eg. you don't own required copyrights) then DON'T send pull request.
