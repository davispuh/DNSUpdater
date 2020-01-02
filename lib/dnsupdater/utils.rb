# frozen_string_literal: true

class DNSUpdater
    # Utility methods
    module Utils
        # Merge two hashes recursively
        # @param hash1 [Hash]
        # @param hash2 [Hash]
        # @return [Hash] merged hash
        def self.deepMerge(hash1, hash2)
            hash1.merge(hash2) do |_key, oldval, newval|
                if oldval.is_a?(Hash)
                    deepMerge(oldval, newval)
                else
                    newval
                end
            end
        end
    end
end
