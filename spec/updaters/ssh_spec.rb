# frozen_string_literal: true

require_relative '../../lib/dnsupdater/updaters/ssh'
require_relative '../../lib/dnsupdater/updaters/powerdns'

require 'ipaddr'

RSpec.describe DNSUpdater::Updaters::SSH do
    it 'has been registered' do
        expect(DNSUpdater::Updaters.get(:ssh)).to eq(DNSUpdater::Updaters::SSH)
    end

    it 'has default config' do
        expect(DNSUpdater::Config.getDefaultConfig['SSH']).to be_a(Hash)
    end

    it 'can update DNS' do
        params = { Server: 'ssh.example.com', Port: 321, Domain: 'dns.example.com', IPs: ['192.168.1.1'], Target: 'PowerDNS' }
        config = loadedConfig

        connectionSession = instance_double('Net::SSH::Connection::Session')
        allow(Net::SSH).to receive(:start) do |&block|
            block.call(connectionSession)
        end

        forward = instance_double('Net::SSH::Service::Forward')

        targetProtocol = config.getTargetProtocol(params[:Target])
        targetHost, targetPort = DNSUpdater::Updaters.getHostPort(targetProtocol, config)
        expect(forward).to receive(:local).with(Integer, targetHost, targetPort).twice

        expect(connectionSession).to receive(:forward).and_return(forward).twice
        allow(connectionSession).to receive(:loop)

        ips = getIPAddrs(params[:IPs])
        expect(DNSUpdater).to receive(:update).with(targetProtocol, hash_including(Domain: params[:Domain], IPs: ips), kind_of(Hash))

        ssh = DNSUpdater::Updaters::SSH.new(loadedConfig)
        expect { ssh.update(params) }.not_to raise_error

        # When using IP from 'client'
        params[:IPs] = ['client']

        clientIp = '172.16.0.1'
        ips = getIPAddrs(clientIp)
        expect(DNSUpdater).to receive(:update).with(targetProtocol, hash_including(Domain: params[:Domain], IPs: ips), kind_of(Hash))
        expect(connectionSession).to receive(:exec!).with('env') { "SSH_CLIENT=#{clientIp} 61353 321" }

        expect { ssh.update(params) }.not_to raise_error
    end
end
