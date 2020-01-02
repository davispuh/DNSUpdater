# frozen_string_literal: true

require_relative 'dnsupdater/version'
require_relative 'dnsupdater/error'
require_relative 'dnsupdater/config'
require_relative 'dnsupdater/updaters'

require 'uri'
require 'etc'
require 'yaml'
require 'addressable/uri'

# Do DNS update based on specified target
class DNSUpdater
    def initialize(config)
        @Config = config
    end

    # Update DNS based on specified target
    # @param target [String]
    # @param targetProtocol [String]
    def update(target, targetProtocol = nil)
        raise Error, self.class.name + ': Invalid target (empty)!' if target.to_s.empty?

        uri = self.class.parseTarget(target)
        params = self.class.buildParams
        self.class.fillPathParams(uri.path, params)
        self.class.fillUriParams(uri, params)

        params[:Protocol] = @Config.getDefaultProtocol if params[:Protocol].to_s.empty? || (params[:Protocol] == :default)

        @Config.setTargetProtocol(params[:Protocol], targetProtocol)

        self.class.update(params[:Protocol], params, @Config)
    end

    # Update DNS using updater identified by specified protocol
    # @param protocol [Symbol]
    # @param params [Hash]
    # @param config [Config]
    def self.update(protocol, params, config)
        raise Error, "Unsupported protocol: '#{protocol}'!" unless Updaters.has?(protocol)

        updater = Updaters.get(protocol)
        updater.new(config).update(params)
    end

    class << self
        # Create param Hash
        def buildParams(protocol = nil, server = nil, port = nil)
            params = { Protocol: nil, Server: server, Port: port, User: nil, Domain: nil, IPs: [] }
            params[:Protocol] = protocol.downcase.to_sym if protocol

            params
        end

        # Process target into URI
        # @param target [String]
        # @return [Addressable::URI] parsed URI
        def parseTarget(target)
            Addressable::URI.parse(target.to_s)
        end

        # Set :Domain and :IPs from path to params
        # @param path [String] source data path
        # @param params [Hash] target params
        # @return [Hash] result params
        def fillPathParams(path, params)
            parts = path.split('/').map { |part| Addressable::URI.unencode_component(part) }

            raise Error, 'Not enough parameters!' if parts.count < 3

            params[:Domain] = parts[-2]
            params[:IPs] = parts[-1].to_s.split(',')

            params
        end

        # Set uri info to params
        # @param uri [Addressable::URI] source uri
        # @param params [Hash] target params
        # @return [Hash] result params
        def fillUriParams(uri, params)
            params[:Protocol] = uri.scheme.to_sym unless uri.scheme.to_s.empty?
            params[:Server] = uri.host unless uri.host.to_s.empty?
            params[:Port] = uri.port unless uri.port.to_s.empty?
            params[:User] = uri.user unless uri.user.to_s.empty?

            params
        end
    end
end
