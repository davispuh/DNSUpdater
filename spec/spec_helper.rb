# frozen_string_literal: true

require 'simplecov'
require 'webmock/rspec'
require 'rack/test'

if ENV['CI']
    require 'coveralls'
    SimpleCov.formatter = Coveralls::SimpleCov::Formatter
end

SimpleCov.start

RSpec.configure do |config|
    # Enable flags like --only-failures and --next-failure
    config.example_status_persistence_file_path = '.rspec_status'

    # Disable RSpec exposing methods globally on `Module` and `main`
    config.disable_monkey_patching!

    config.expect_with :rspec do |c|
        c.syntax = :expect
    end

    config.mock_with :rspec do |mocks|
        mocks.verify_doubled_constant_names = true
        mocks.verify_partial_doubles = true
    end

    config.include Rack::Test::Methods
end

require_relative '../lib/dnsupdater'

def loadedConfig
    DNSUpdater::Config.new(File.expand_path('../config_example.yaml', __dir__))
end

def getPath(domain, ips)
    [nil, domain, ips.join(',')].join('/')
end

def getIPAddrs(ips)
    ips = [ips] unless ips.is_a?(Array)
    ips.map { |ip| IPAddr.new(ip) }
end
