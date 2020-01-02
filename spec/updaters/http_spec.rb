# frozen_string_literal: true

require_relative '../../lib/dnsupdater/updaters/http'
require_relative '../../lib/dnsupdater/updaters/powerdns'

RSpec.describe DNSUpdater::Updaters::HTTP do
    it 'has been registered' do
        expect(DNSUpdater::Updaters.get(:http)).to eq(DNSUpdater::Updaters::HTTP)
    end

    it 'has default config' do
        expect(DNSUpdater::Config.getDefaultConfig['HTTP']).to be_a(Hash)
    end

    let(:server) { 'http.example.com' }
    let(:domain) { 'dns.example.com' }
    let(:updateIPs) { ['192.168.1.1'] }
    let(:app) { DNSUpdater::Updaters::HTTP.new(loadedConfig) }

    it 'can update DNS' do
        params = { Server: server, Port: 8080, Domain: domain, IPs: updateIPs }
        path = getPath(params[:Domain], params[:IPs])
        uri = Addressable::URI.new(scheme: 'http', host: params[:Server], port: params[:Port], path: path)
        stub_request(:post, uri).to_return(status: 200, body: '{ "success": true, "message": "Updated!" }')

        expect { app.update(params) }.not_to raise_error
    end

    def getAuthHeader(config, path)
        secret = config['HTTP']['SharedSecret']
        hmac, = DNSUpdater::Updaters::HTTP.buildAuthHMAC(secret, 'POST', path)
        DNSUpdater::Updaters::HTTP::AUTH_NAME + ' ' + Base64.urlsafe_encode64(hmac, padding: false)
    end

    def getResponse(useClientIP = false)
        config = loadedConfig
        path = getPath(domain, useClientIP ? ['client'] : updateIPs)
        targetProtocol = config.getTargetProtocol('HTTP')
        ips = getIPAddrs(useClientIP ? '127.0.0.1' : updateIPs)
        expect(DNSUpdater).to receive(:update).with(targetProtocol, hash_including(Domain: domain, IPs: ips), kind_of(Hash))

        header('Authorization', getAuthHeader(config, path))
        post(path)
    end

    def validateSuccessfulResponse(response)
        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['success']).to be(true)
    end

    def validateUnauthorizedResponse(response)
        expect(response.status).to eq(401)
        result = JSON.parse(response.body)
        expect(result['success']).to be(false)
    end

    context 'with specified IP' do
        it 'handles DNSUpdate HTTP' do
            validateSuccessfulResponse(getResponse(false))
        end

        it 'validates authentication' do
            path = getPath(domain, updateIPs)
            # Invalid auth
            allow(Time).to receive(:now).and_return(Time.at(1_570_000_000), Time.now)
            header('Authorization', getAuthHeader(loadedConfig, path))
            validateUnauthorizedResponse(post(path))
        end
    end

    context 'with IP from client' do
        it 'handles DNSUpdate HTTP' do
            validateSuccessfulResponse(getResponse(true))
        end
    end

    it 'handles Dynamic DNS HTTP' do
        config = loadedConfig
        path = '/update?hostname=' + domain + '&myip=' + updateIPs.first
        authName = DNSUpdater::Updaters::HTTP::AUTH_NAME
        password = Base64.urlsafe_encode64(OpenSSL::HMAC.digest('SHA256', config['HTTP']['SharedSecret'], authName), padding: false)
        authHeader = 'Basic ' + ["#{authName}:#{password}"].pack('m0')
        targetProtocol = config.getTargetProtocol('HTTP')
        ips = getIPAddrs(updateIPs.first)
        expect(DNSUpdater).to receive(:update).with(targetProtocol, hash_including(Domain: domain, IPs: ips), kind_of(Hash))
        header('Authorization', authHeader)
        response = post(path)
        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['success']).to be(true)
    end
end
