# frozen_string_literal: true

require_relative 'updaters/http'

require 'rack/handler/puma'
require 'addressable/idna'

class DNSUpdater
    # HTTP updater web server
    class Web
        def initialize(configFile)
            @Config = Config.new(configFile)
            @HTTP = Updaters::HTTP.new(@Config)
        end

        def getConfig
            @Config
        end

        def call(env)
            @HTTP.call(env)
        rescue RuntimeError => e
            @HTTP.class.formatResponse(500, e.message)
        end

        def self.startServer(configFile, protocol, params)
            web = new(configFile)
            config = getServerConfig(web.getConfig, protocol, params)

            Rack::Handler::Puma.run(web, config)
        rescue IOError, SocketError, SystemCallError => e
            raise Error, self.class.name + ': ' + e.message
        end

        def self.getServerConfig(webConfig, protocol, params)
            webConfig.setTargetProtocol(:http, protocol)

            config = Hash[webConfig['HTTP'].map { |k, v| [k.to_sym, v] }]

            config[:Host] = Addressable::IDNA.to_ascii(params[:Server]) unless params[:Server].to_s.empty?
            config[:Port] = params[:Port] if params[:Port].to_i.positive?
            config[:environment] = 'production'

            config
        end
    end
end
