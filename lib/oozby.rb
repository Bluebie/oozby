warn "Requires ruby 2.0 or newer" unless RUBY_VERSION.split('.').first.to_i >= 2
require_relative 'oozby/base'
require_relative 'oozby/environment'
require_relative 'oozby/preprocessor'
require_relative 'oozby/preprocessor-definitions'
require_relative 'oozby/render'
require_relative 'oozby/element'
require_relative 'oozby/version'
