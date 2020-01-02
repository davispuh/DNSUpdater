# frozen_string_literal: true

require_relative '../lib/dnsupdater/cli'

RSpec.describe DNSUpdater::CLI do
    it 'shows help' do
        expect { DNSUpdater::CLI.main(['-h']) }.to output(/Usage/).to_stdout.and output('').to_stderr.and raise_error(SystemExit)
    end

    it 'updates DNS' do
        domain = 'example.org'
        ips = ['10.0.0.1']
        target = 'powerdns://example.com' + getPath(domain, ips)
        # rubocop:disable Lint/SuppressedException
        expectation = expect do
            DNSUpdater::CLI.main([target])
        rescue SystemExit
            # we don't want to exit from tests
        end
        # rubocop:enable Lint/SuppressedException

        ips = getIPAddrs(ips)
        expect(DNSUpdater).to receive(:update).with(:powerdns, hash_including(Domain: domain, IPs: ips), kind_of(Hash))

        expectation.to output(/Updated!/).to_stdout.and output('').to_stderr
    end

    it 'serves HTTP' do
        # rubocop:disable Lint/SuppressedException
        expectation = expect do
            DNSUpdater::CLI.main(['-s'])
        rescue SystemExit
            # we don't want to exit from tests
        end
        # rubocop:enable Lint/SuppressedException

        expect(Rack::Handler::Puma).to receive(:run).with(kind_of(DNSUpdater::Web), kind_of(Hash))

        expectation.to output('').to_stdout.and output('').to_stderr
    end
end
