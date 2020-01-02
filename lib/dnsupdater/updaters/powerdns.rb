# frozen_string_literal: true

require_relative 'updater'
require_relative '../../dnsupdater'

require 'public_suffix'
require 'addressable/idna'

class DNSUpdater
    # Module for DNS updater implementations
    module Updaters
        # PowerDNS updater
        class PowerDNS < Updater
            # Exceptions from this updater
            class Error < Error
            end

            # @see Updater#update
            def update(params)
                fillParams(params)

                raise Error, "Domain can't be empty!" if params[:Domain].to_s.empty?

                zone = getZone(params[:Server], params[:Port], params[:Domain])

                records = []
                getIPs(params[:IPs]).each do |ipAddr|
                    type = ipAddr.ipv6? ? 'AAAA' : 'A'
                    records << {
                        name: Addressable::IDNA.to_ascii(params[:Domain]) + '.',
                        type: type,
                        records: ipAddr.to_s,
                        ttl: params[:TTL]
                    }
                end

                result = zone.update(*records)
                return unless result.key?(:error)

                errorMessage = result[:error]
                errorMessage = result[:result] if errorMessage =~ /Non-JSON/
                raise Error, self.class.name + ': ' + errorMessage
            end

            # @see Updater.getHostPort
            def self.getHostPort(config)
                [
                    config['PowerDNS']['API']['Host'],
                    config['PowerDNS']['API']['Port']
                ]
            end

            private

            def getClient(key, host = 'localhost', port = 8081)
                require 'pdns_api'

                @pdns ||= PDNS::Client.new(
                    host: host,
                    port: port,
                    key: key,
                    version: 1
                )

                @pdns
            end

            def getServer(server, port)
                apiConfig = @Config['PowerDNS']['API']
                if apiConfig['Shared']
                    host = apiConfig['Host']
                    port = apiConfig['Port']
                else
                    host = server
                    server = 'localhost'
                end
                key = apiConfig['Key']
                getClient(key, host, port).server(server)
            end

            def getZone(server, port, domain)
                zoneDomain = PublicSuffix.domain(domain)

                getServer(server, port).zone(Addressable::IDNA.to_ascii(zoneDomain))
            end

            def fillParams(params)
                apiConfig = @Config['PowerDNS']['API']

                params[:Server] = apiConfig['Host'] unless params[:Server]
                params[:Port] = apiConfig['Port'] unless params[:Port]

                params[:TTL] = @Config['PowerDNS']['TTL']

                params
            end
        end

        Config.addDefault('PowerDNS',
                          'TTL' => 300,
                          'API' => {
                              'Shared' => false,
                              'Host' => 'localhost',
                              'Port' => 8081
                          })
        register(:powerdns, PowerDNS)
    end
end
