require 'opscode/authentication/strategies/base'
require 'opscode/authentication/strategies/ldap'
require 'opscode/authentication/strategies/local'


module Opscode
  module Authentication
    module Strategies
      class << self
        # Add a strategy and store it in a hash.
        def add(label, strategy = nil, &block)
          strategy ||= Class.new(Opscode::Authentication::Strategies::Base)
          strategy.class_eval(&block) if block_given?

          unless strategy.method_defined?(:authenticate)
            raise NoMethodError, "authenticate is not declared in the #{label.inspect} strategy"
          end

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

        # convience method for loading all built-in
        # strategies
        def builtin!(user_mapper=nil, options=nil)
          user_mapper ||= Opscode::Mappers::User.new(Opscode::Mappers.default_connection, nil, 0)
          self.add(:local, Opscode::Authentication::Strategies::Local.new(user_mapper, options))
          self.add(:ldap, Opscode::Authentication::Strategies::LDAP.new(user_mapper, options))
          self
        end
      end
    end
  end
end
