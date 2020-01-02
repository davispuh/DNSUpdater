# frozen_string_literal: true

require_relative 'lib/dnsupdater/web'

run DNSUpdater::Web.new('config.yaml')
