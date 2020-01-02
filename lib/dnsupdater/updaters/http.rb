# frozen_string_literal: true

require_relative 'updater'

require 'net/http'
require 'uri'
require 'cgi'
require 'json'
require 'base64'
require 'openssl'
require 'addressable/uri'
require 'rack/utils'

class DNSUpdater
    # Module for DNS updater implementations
    module Updaters
        # DNS updater over HTTP
        class HTTP < Updater
            # Name of authentication - our own custom
            AUTH_NAME = 'DNSUpdate'
            # Time how long authentication key is valid for
            AUTH_VALID_SECONDS = 60 * 10 # 10mins
            # Default settings
            DEFAULT_SETTINGS = { 'Host' => '127.0.0.1', 'Port' => 8245 }.freeze

            # @see Updater#update
            def update(params)
                @ENV = nil
                fillParams(params)

                path = [nil, params[:Domain], params[:IPs].join(',')].join(Addressable::URI::SLASH)
                uri = Addressable::URI.new(scheme: params[:Protocol].to_s, host: params[:Server], port: params[:Port], path: path).normalize
                request = Net::HTTP::Post.new(uri.path)
                addAuthHeader(request, uri.path)
                sendRequest(uri, request)
            end

            def call(env)
                @ENV = env

                path = @ENV['PATH_INFO']
                if isAuthenticated(@ENV['HTTP_AUTHORIZATION'], @ENV['REQUEST_METHOD'], path, @ENV['QUERY_STRING'])
                    handleRequest(@ENV['REQUEST_METHOD'], path, CGI.parse(@ENV['QUERY_STRING']))
                else
                    authName = AUTH_NAME
                    authName = 'Basic' if isDynDNS(path, CGI.parse(@ENV['QUERY_STRING']))
                    self.class.formatResponse(401, 'Unauthorized!', 'WWW-Authenticate' => authName)
                end
            rescue Error => e
                self.class.formatResponse(400, e.message)
            end

            def self.getParams(target)
                params = DNSUpdater.buildParams
                DNSUpdater.fillPathParams(target, params)

                params
            end

            def self.formatResponse(code, message, extraHeaders = {})
                headers = { 'Content-Type' => 'application/json; charset=UTF-8' }
                headers.merge!(extraHeaders)
                data = { success: code == 200, message: message }
                [code, headers, [JSON.generate(data)]]
            end

            # @see Updater.getHostPort
            def self.getHostPort(config)
                [
                    config['HTTP']['Host'],
                    config['HTTP']['Port']
                ]
            end

            # Build authentication HMAC, taking into parameters and time
            # If authValidTime is passed it will be decreased for use of retry
            def self.buildAuthHMAC(secret, method, path, query = '', authValidTime = nil)
                if authValidTime
                    authValidTime -= 1
                else
                    # Will be valid only for limited time
                    authValidTime = Time.now.to_i / AUTH_VALID_SECONDS
                end
                data = buildAuthString(authValidTime, method, path, query)

                [OpenSSL::HMAC.digest('SHA256', secret, data), authValidTime]
            end

            def self.buildAuthString(*params)
                params.join(':')
            end

            private

            def sendRequest(uri, request)
                Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
                    response = http.request(request)
                    result = { 'success' => false, 'message' => response.body }
                    result = JSON.parse(result['message']).to_hash if result['message'].to_s[0] == '{'
                    raise Error, self.class.name + ": [#{response.code} #{response.message}] " + result['message'].to_s if response.code.to_i != 200 || !result['success']
                end
            rescue IOError, SocketError, SystemCallError, OpenSSL::OpenSSLError => e
                raise Error, self.class.name + ': ' + e.message
            rescue Interrupt
                raise Error, "\nCancelled!"
            end

            def addAuthHeader(request, path)
                secret = @Config['HTTP']['SharedSecret'].to_s
                return if secret.empty?

                hmac, = self.class.buildAuthHMAC(secret, 'POST', path)
                request['Authorization'] = AUTH_NAME + ' ' + Base64.urlsafe_encode64(hmac, padding: false)
            end

            def fillParams(params)
                httpConfig = @Config['HTTP']

                params[:Server] = httpConfig['Host'] unless params[:Server]
                params[:Port] = httpConfig['Port'] unless params[:Port]
                params[:Protocol] = :http unless params.key?(:Protocol)

                targetProtocol = @Config.getTargetProtocol('HTTP')
                raise Error, 'Unsupported!' if %i[http https].include?(targetProtocol)

                params[:TargetParams] = {}
                params[:TargetParams][:Protocol] = targetProtocol
                params[:TargetParams][:Domain] = params[:Domain]
            end

            def resolveClient
                @ENV ? [@ENV['REMOTE_ADDR']] : nil
            end

            def getDynDNSUri(query)
                '/' + query['hostname'].to_a.first.to_s + '/' + query['myip'].to_a.first.to_s
            end

            def getUri(method, path)
                raise Error, 'Invalid parameters!' unless method == 'POST'

                uri = path.dup
                uri.force_encoding('UTF-8')
                uri
            end

            def isDynDNS(path, query)
                path[-7..] == '/update' || query.key?('hostname') || query.key?('myip')
            end

            def handleRequest(method, path, query)
                uri = isDynDNS(path, query) ? getDynDNSUri(query) : getUri(method, path)

                params = self.class.getParams(uri)
                fillParams(params)

                params[:TargetParams][:IPs] = getIPs(params[:IPs])

                DNSUpdater.update(params[:TargetParams][:Protocol], params[:TargetParams], @Config)

                self.class.formatResponse(200, 'Updated!')
            end

            def constantTimeEqual?(a, b)
                return false if a.bytesize != b.bytesize

                # OpenSSL.memcmp?(a, b) # Not released yet, should be in OpenSSL 2.2
                Rack::Utils.secure_compare(a, b)
            end

            def isDynDNSAuthenticated(authorizationHeader)
                secret = @Config['HTTP']['SharedSecret'].to_s
                authHeaderParts = authorizationHeader.to_s.split
                return false if authHeaderParts.length != 2 || authHeaderParts.first != 'Basic' || secret.empty?

                user, password = Base64.decode64(authHeaderParts.last).split(':')
                begin
                    password = Base64.urlsafe_decode64(password.to_s)
                rescue ArgumentError
                    password = nil
                end

                constantTimeEqual?(user.to_s, AUTH_NAME) & constantTimeEqual?(password.to_s, OpenSSL::HMAC.digest('SHA256', secret, AUTH_NAME))
            end

            def isDNSUpdateAuthenticated(authorizationHeader, method, path, query)
                secret = @Config['HTTP']['SharedSecret'].to_s
                authHeaderParts = authorizationHeader.to_s.split
                return false if authHeaderParts.length != 2 || authHeaderParts.first != AUTH_NAME || secret.empty?

                authHMAC = ''
                begin
                    authHMAC = Base64.urlsafe_decode64(authHeaderParts.last)
                rescue ArgumentError
                    authHMAC = ''
                end

                hmac, authValidTime = self.class.buildAuthHMAC(secret, method, path, query)

                return false if authHMAC.bytesize != hmac.bytesize

                # Compare in constant time to be timing safe
                result = constantTimeEqual?(authHMAC, hmac)
                unless result
                    # In case of fail, retry again for previous time, see buildAuthHMAC
                    hmac, = self.class.buildAuthHMAC(secret, method, path, query, authValidTime)
                    result = constantTimeEqual?(authHMAC, hmac)
                end

                result
            end

            def isAuthenticated(authorizationHeader, method, path, query)
                if isDynDNS(path, CGI.parse(query))
                    isDynDNSAuthenticated(authorizationHeader)
                else
                    isDNSUpdateAuthenticated(authorizationHeader, method, path, query)
                end
            end
        end

        Config.addDefault('HTTP', HTTP::DEFAULT_SETTINGS)
        Config.addDefault('HTTPS', HTTP::DEFAULT_SETTINGS)
        register(:http, HTTP)
        register(:https, HTTP)
    end
end
