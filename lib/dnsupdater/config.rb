# frozen_string_literal: true

require_relative 'utils'

require 'pathname'

class DNSUpdater
    # Config file, configuration handling
    class Config < Hash
        def self.getDefaultConfig
            @@DefaultConfig ||= {
                'Default' => 'PowerDNS'
            }
            @@DefaultConfig
        end

        def initialize(configFile = nil)
            @ConfigFile = nil
            @ConfigFile = Pathname.new(configFile) unless configFile.to_s.empty?
            @TargetProtocol = {}

            update(load)
        end

        def getDefaultProtocol
            self['Default'].downcase.to_sym
        end

        def setTargetProtocol(source, protocol)
            @TargetProtocol[source] = protocol.downcase.to_sym unless protocol.to_s.empty?
        end

        def getTargetProtocol(name)
            protocol = name.downcase.to_sym
            return @TargetProtocol[protocol] if @TargetProtocol.key?(protocol)
            return getDefaultProtocol if self[name]['Target'].to_s.empty?

            target = self[name]['Target'].downcase.to_sym
            return getDefaultProtocol if target == :default

            target
        end

        def self.addDefault(name, config)
            getDefaultConfig[name] = config
        end

        private

        def load
            config = self.class.getDefaultConfig
            if @ConfigFile
                @ConfigFile = @ConfigFile.expand_path unless @ConfigFile.absolute?
                @ConfigFile = Pathname.new(Etc.sysconfdir) / 'dnsupdater.yaml' unless File.exist?(@ConfigFile)
                if File.exist?(@ConfigFile)
                    configData = YAML.load_file(@ConfigFile)
                    config = Utils.deepMerge(config, configData) if configData.is_a?(Hash)
                end
            end

            config
        end
    end
end
