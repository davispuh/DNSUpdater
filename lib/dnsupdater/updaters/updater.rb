# frozen_string_literal: true

require 'socket'
require 'ipaddr'
require 'resolv'

require_relative '../error'
require_relative '../updaters'
require_relative '../config'

class DNSUpdater
    module Updaters
        # Base class of any DNS updater
        class Updater
            def initialize(config)
                @Config = config
            end

            # Update DNS using given params
            # @param params [Hash] target params
            def update(params)
                raise Error, 'Child class must implement this!'
            end

            # Get configured host and port for updater
            # @param config [Config]
            def self.getHostPort(config)
                raise Error, 'Unsupported!'
            end

            protected

            def getIPs(namesOrIPs)
                ipAddrs = {}

                namesOrIPs.to_a.each do |nameOrIP|
                    if nameOrIP.is_a?(IPAddr)
                        setIPAddr(nameOrIP, ipAddrs)
                    elsif nameOrIP == 'client'
                        resolveClient.each do |ip|
                            setIPAddr(ip, ipAddrs)
                        end
                    else
                        begin
                            setIPAddr(nameOrIP, ipAddrs)
                        rescue IPAddr::InvalidAddressError
                            setIPsFromDNS(nameOrIP, ipAddrs)
                        end
                    end
                end

                ipAddrs.values
            end

            def setIPsFromDNS(nameOrIP, ipAddrs)
                Resolv::DNS.open do |dns|
                    dns.each_address(nameOrIP) do |addr|
                        setIPAddr(addr, ipAddrs)
                    end
                end
            end

            def setIPAddr(addr, ipAddrs)
                addr = IPAddr.new(addr.to_s) unless addr.is_a?(IPAddr)
                ipAddrs[addr.to_s] = addr
            end

            def resolveClient
                ipAddrs = Socket.ip_address_list.select do |addr|
                    !addr.ipv4_loopback? && !addr.ipv6_loopback?
                end
                ipAddrs.map do |addr|
                    addr.ip_address.split('%').first
                end
            end
        end
    end
end
