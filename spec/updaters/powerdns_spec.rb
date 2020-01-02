# frozen_string_literal: true

require_relative '../../lib/dnsupdater/updaters/powerdns'

require 'addressable/uri'
require 'public_suffix'

RSpec.describe DNSUpdater::Updaters::PowerDNS do
    it 'has been registered' do
        expect(DNSUpdater::Updaters.get(:powerdns)).to eq(DNSUpdater::Updaters::PowerDNS)
    end

    it 'has default config' do
        expect(DNSUpdater::Config.getDefaultConfig['PowerDNS']).to be_a(Hash)
    end

    it 'can update DNS' do
        params = { Server: 'powerdns.example.com', Port: 123, Domain: 'dns.example.com', IPs: ['127.126.125.124'] }
        path = '/api/v1/servers/localhost/zones/' + PublicSuffix.domain(params[:Domain])
        uri = Addressable::URI.new(scheme: 'http', host: params[:Server], port: params[:Port], path: path)
        request = stub_request(:patch, uri).to_return(status: 200, body: '{}')

        powerdns = DNSUpdater::Updaters::PowerDNS.new(loadedConfig)

        expect { powerdns.update(params) }.not_to raise_error
        expect(request).to have_been_requested

        # When using IP from 'client'
        params[:IPs] = ['client']
        expect { powerdns.update(params) }.not_to raise_error

        # When using IP from a domain
        params[:IPs] = ['example.com']
        expect { powerdns.update(params) }.not_to raise_error
    end
end
