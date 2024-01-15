# frozen_string_literal: true

# Dependencies
#
# Sigh. Rails autoloads the gems specified in the Gemfile and nothing else.
# We need to explicitly require all of our dependencies listed in kpm.gemspec
#
# See also https://github.com/carlhuda/bundler/issues/49

require 'killbill_client'
require 'killbill_assets_ui'

module KPM
  class Engine < ::Rails::Engine
    isolate_namespace KPM

    ActiveSupport::Inflector.inflections do |inflect|
      inflect.acronym 'KPM'
    end
  end
end
