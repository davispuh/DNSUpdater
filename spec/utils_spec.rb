# frozen_string_literal: true

RSpec.describe DNSUpdater::Utils do
    it 'has deepMerge to merge nested Hash' do
        a = { a: 1, b: { c: 3, d: 5 } }
        b = { a: 2, b: { c: 4, f: 6 } }
        r = { a: 2, b: { c: 4, d: 5, f: 6 } }

        expect(DNSUpdater::Utils.deepMerge(a, b)).to eq(r)
    end
end
