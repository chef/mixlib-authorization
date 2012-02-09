require 'opscode/authentication/strategies/base'
require 'opscode/authentication/strategies/ldap'
require 'opscode/authentication/strategies/local'

module Opscode
  module Authentication
    module Strategies
      class << self

        # Add a strategy and store it in a hash.
        def add(label, strategy = nil)
          unless strategy.ancestors.include?(Opscode::Authentication::Strategies::Base)
            raise "#{label.inspect} is not a #{base}"
          end
          strategies[label] = strategy
        end

        # Provides access to strategies by label
        def [](label)
          strategies[label]
        end

        def strategies
          @strategies ||= {}
        end

        # convience method for loading all built-in strategies
        def builtin!
          self.add(:local, Opscode::Authentication::Strategies::Local)
          self.add(:ldap, Opscode::Authentication::Strategies::LDAP)
          self
        end
      end
    end
  end
end
