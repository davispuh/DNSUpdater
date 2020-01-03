# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dnsupdater/version'

Gem::Specification.new do |spec|
    spec.name = 'DNSUpdater'
    spec.version       = DNSUpdater::VERSION
    spec.authors       = ['Dāvis']
    spec.email         = ['davispuh@gmail.com']

    spec.summary       = 'An application to dynamically and remotely update DNS.'
    spec.description   = 'Using this application you can configure local or remote (over SSH or HTTP) DNS such as PowerDNS.'
    spec.homepage      = 'https://github.com/davispuh/DNSUpdater'
    spec.license       = 'UNLICENSE'

    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = spec.homepage
    spec.metadata['changelog_uri'] = spec.homepage + '/blob/master/CHANGELOG.md'

    # Specify which files should be added to the gem when it is released.
    # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
    spec.files = Dir.chdir(File.expand_path(__dir__)) do
        `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
    end
    spec.bindir        = 'exe'
    spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
    spec.require_paths = ['lib']

    spec.add_dependency 'addressable'
    spec.add_dependency 'idn-ruby'
    spec.add_dependency 'net-ssh'
    spec.add_dependency 'pdns_api'
    spec.add_dependency 'public_suffix'
    spec.add_dependency 'puma'
    spec.add_dependency 'rack'

    spec.add_development_dependency 'bundler', '~> 2.0'
    spec.add_development_dependency 'irb'
    spec.add_development_dependency 'rack-test'
    spec.add_development_dependency 'rake', '~> 10.0'
    spec.add_development_dependency 'redcarpet'
    spec.add_development_dependency 'rspec', '~> 3.0'
    spec.add_development_dependency 'simplecov'
    spec.add_development_dependency 'webmock', '>= 3.7'
    spec.add_development_dependency 'yard'
end
