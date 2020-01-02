# frozen_string_literal: true

require_relative 'updater'

require 'net/ssh'
require 'socket'

class DNSUpdater
    # Module for DNS updater implementations
    module Updaters
        # DNS updater over SSH
        class SSH < Updater
            # Exceptions from this updater
            class Error < Error
            end

            # @see Updater#update
            def update(params)
                fillParams(params)

                startPortForward(params[:Server], params[:SSHParams], params[:TargetHost], params[:TargetPort], params[:TargetParams]) do |targetParams|
                    targetParams[:IPs] = getIPs(params[:IPs])
                end
                waitPortForward(params[:SSHParams][:timeout])

                DNSUpdater.update(params[:TargetParams][:Protocol], params[:TargetParams], @Config)

                finishPortForward
            rescue Interrupt
                raise Error, "\nCancelled!"
            end

            private

            def startPortForward(server, sshParams, targetHost, targetPort, targetParams)
                @SSHFowardProcessing = false
                @SSHError = nil
                @SSHThread = Thread.new do
                    @SSH = nil
                    Net::SSH.start(server, nil, sshParams) do |ssh|
                        @SSH = ssh
                        targetParams[:Port] = getFreePort
                        yield(targetParams)

                        ssh.forward.local(targetParams[:Port], targetHost, targetPort)
                        @SSHFowardProcessing = true
                        ssh.loop { ssh.busy? || @SSHFowardProcessing }
                    end
                    @SSH = nil
                rescue IOError, SocketError, SystemCallError, Net::SSH::Exception => e
                    @SSHError = e.message
                end
                @SSHThread.report_on_exception = true
                @SSHThread.abort_on_exception = true
            end

            def waitPortForward(timeout)
                while !@SSHFowardProcessing && timeout.positive?
                    raise Error, self.class.name + ': ' + @SSHError.to_s unless @SSHError.nil?

                    sleep(0.2)
                    timeout -= 0.2
                end

                return if timeout.positive?

                @SSHThread.terminate
                raise Error, self.class.name + ': Timeout while waiting for SSH connection!'
            end

            def finishPortForward
                @SSHFowardProcessing = false
                @SSHThread.join(3)
            end

            def fillParams(params)
                sshConfig = @Config['SSH']

                targetProtocol = @Config.getTargetProtocol('SSH')
                raise Error, 'Unsupported!' if targetProtocol == :ssh

                params[:Server] = sshConfig['Host'] unless params[:Server]

                params[:TargetParams] = {}
                params[:TargetParams][:Protocol] = targetProtocol
                params[:TargetParams][:Server] = 'localhost'
                params[:TargetParams][:Domain] = params[:Domain]

                sshParams = {}
                setParam(:Port, sshParams, params, sshConfig, :to_i)
                setParam(:User, sshParams, params, sshConfig, :to_s)
                sshParams[:password] = sshConfig['Password'].to_s if sshConfig['Password']
                sshParams[:keys] = [sshConfig['KeyFile'].to_s] if sshConfig['KeyFile']
                setParam(:Timeout, sshParams, params, sshConfig, :to_f)
                sshParams[:timeout] = 10 unless sshParams[:timeout]

                params[:SSHParams] = sshParams
                params[:TargetHost], params[:TargetPort] = Updaters.getHostPort(targetProtocol, @Config)

                params
            end

            def setParam(name, resultParams, params, config, typeConvertMethod)
                if params[name]
                    resultParams[name.to_s.downcase.to_sym] = params[name].send(typeConvertMethod)
                elsif config[name.to_s]
                    resultParams[name.to_s.downcase.to_sym] = config[name.to_s].send(typeConvertMethod)
                end
            end

            def getFreePort
                TCPServer.open(0) do |socket|
                    return socket.addr[1]
                end
            end

            def resolveClient
                envs = @SSH.exec!('env').split("\n")
                envVars = Hash[envs.map { |vars| vars.split('=', 2) }]
                [envVars['SSH_CLIENT'].split.first]
            end
        end

        Config.addDefault('SSH', 'Timeout' => 10)
        register(:ssh, SSH)
    end
end
