# frozen_string_literal: true

require_relative '../lib/dnsupdater/updaters/updater'

RSpec.describe DNSUpdater do
    it 'has a version number' do
        expect(DNSUpdater::VERSION).to be_a(String)
    end

    it 'can be initialized' do
        expect { DNSUpdater.new(DNSUpdater::Config.new) }.not_to raise_error
    end

    it 'can update DNS' do
        config = DNSUpdater::Config.new
        params = {}

        updaterClass = DNSUpdater::Updaters::Updater
        updater = instance_double(updaterClass)
        expect(updaterClass).to receive(:new).with(kind_of(Hash)) { updater }
        expect(updater).to receive(:update).with(params)

        DNSUpdater::Updaters.register(:testprotocol, updaterClass)

        # expect {
        DNSUpdater.update(:testprotocol, params, config)
        # }.not_to raise_error
    end
end
