# frozen_string_literal: true

RSpec.describe DNSUpdater::Updaters do
    it 'can register updater' do
        updater = Class.new
        DNSUpdater::Updaters.register(:testprotocol, updater)
        expect(DNSUpdater::Updaters.has?(:testprotocol)).to be(true)
        expect(DNSUpdater::Updaters.get(:testprotocol)).to eq(updater)
    end
end
