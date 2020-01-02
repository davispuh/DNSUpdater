# frozen_string_literal: true

class DNSUpdater
    # Container of updaters for each protocol
    module Updaters
        @@Updaters = {}

        def self.register(protocol, updater)
            @@Updaters[protocol.downcase.to_sym] = updater
        end

        def self.has?(protocol)
            @@Updaters.key?(protocol)
        end

        def self.get(protocol)
            @@Updaters[protocol]
        end

        def self.getAllProtocols
            @@Updaters.keys
        end

        def self.getHostPort(protocol, config)
            raise "Protocol '#{protocol}' not registered!" unless has?(protocol)

            @@Updaters[protocol].getHostPort(config)
        end
    end
end
