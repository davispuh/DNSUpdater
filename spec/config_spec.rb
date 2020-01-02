# frozen_string_literal: true

require 'tempfile'

RSpec.describe DNSUpdater::Config do
    it 'has default config' do
        expect(DNSUpdater::Config.getDefaultConfig).to be_a(Hash)
    end

    let(:testConfig) { DNSUpdater::Config.new }

    it 'can be initialized' do
        expect { testConfig }.not_to raise_error
    end

    it 'can store settings for protocol' do
        DNSUpdater::Config.addDefault(:testProtocol, testConfig)
        expect(DNSUpdater::Config.getDefaultConfig[:testProtocol]).to eq(testConfig)
    end

    def configFile
        Tempfile.open(['configTest', '.yaml']) { |file| yield(file) }
    end

    it 'can load config from empty file' do
        configFile do |file|
            file.truncate(0)
            expect { DNSUpdater::Config.new(file.path) }.not_to raise_error
        end
    end

    it 'can load config from file' do
        config = loadedConfig
        expect(config.length).to be > 1
        expect(config.key?('PowerDNS')).to be(true)
    end

    it 'can get default protocol' do
        expect(loadedConfig.getDefaultProtocol).to be_a(Symbol)
    end

    context 'with set target protocol' do
        it 'can get set target protocol' do
            config = loadedConfig
            config.setTargetProtocol(:ssh, 'HTTP')

            expect(config.getTargetProtocol('SSH')).to eq(:http)
        end
    end

    context 'with not set target protocol' do
        it 'can get target protocol from config' do
            expect(loadedConfig.getTargetProtocol('HTTP')).to eq(:powerdns)
        end
    end
end
