# frozen_string_literal: true

require_relative '../dnsupdater'
require_relative 'web'
require_relative 'updaters/all'

require 'optparse'

class DNSUpdater
    # For usage in command-line applications
    module CLI
        # Main entry point for CLI
        def self.main(args)
            options = getOptions(args)
            if options[:Serve]
                serveWebUpdates(options)
            else
                doSingleUpdate(options)
            end
        rescue RuntimeError => e
            abort(e.to_s)
        end

        class << self
            private

            def getOptionParser(options)
                OptionParser.new do |opts|
                    programName = File.basename($PROGRAM_NAME)
                    opts.banner = "Usage: #{programName} [options] <target>"
                    opts.on('-c', '--config config.yaml', 'Path to config file') do |configFile|
                        options[:ConfigFile] = configFile
                    end
                    opts.on('-t', '--target=PROTOCOL', 'Target protocol (useful for SSH)') do |protocol|
                        options[:Protocol] = protocol
                    end
                    opts.on('-s', '--serve', 'Serve/handle HTTP') do |serve|
                        options[:Serve] = true if serve
                    end
                    opts.on_tail('-h', '--help', 'Show this message') do
                        puts opts
                        puts "\nSupported targets are: " + Updaters.getAllProtocols.map(&:to_s).sort.join(', ')
                        puts 'Target examples:'
                        puts '* default:///example.com/10.0.0.1'
                        puts '* ssh://dns.example.com:123/example.org/client'
                        puts '* http://example.org/dns.example.com/127.0.0.1,192.168.1.1'

                        raise SystemExit
                    end
                end
            end

            def getOptions(args)
                options = {
                    ConfigFile: 'config.yaml',
                    Targets: [],
                    Protocol: nil,
                    Serve: false
                }

                parser = getOptionParser(options)

                begin
                    parser.parse!(args)
                rescue OptionParser::ParseError => e
                    warn e.message
                    raise SystemExit
                end
                options[:Targets] = args
                options
            end

            def doSingleUpdate(options)
                config = Config.new(options[:ConfigFile])
                updater = DNSUpdater.new(config)
                options[:Targets].each do |target|
                    updater.update(target, options[:Protocol])
                    puts "Updated #{target}"
                end
            end

            def serveWebUpdates(options)
                target = nil
                target = options[:Targets].first unless options[:Targets].empty?
                params = prepareWebParams(target)
                Web.startServer(options[:ConfigFile], options[:Protocol], params)
            end

            def prepareWebParams(target)
                params = DNSUpdater.buildParams
                uri = DNSUpdater.parseTarget(target)
                DNSUpdater.fillUriParams(uri, params)

                params[:Protocol] = :http if params[:Protocol].to_s.empty?
                raise 'Wrong protocol for --serve, must be http!' unless params[:Protocol] == :http

                params
            end
        end
    end
end
