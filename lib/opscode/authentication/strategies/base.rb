module Opscode
  module Authentication

    class AccessDeniedException < StandardError ; end
    class AuthenticationServiceException  < StandardError ; end
    class RemoteAuthenticationException  < StandardError ; end

    module Strategies

      # A strategy is a place where you can put logic related to authentication. Any strategy inherits
      # from Opscode::Authentication::Strategies.
      #
      # The Opscode::Authentication::Strategies.add method is a simple way to provide custom strategies.
      # You _must_ declare an @authenticate@ method.
      #
      # The parameters for Opscode::Authentication::Strategies.add method is:
      #   <label: Symbol> The label is the name given to a strategy.  Use the label to refer to the strategy when authenticating
      #   <strategy: Class|nil> The optional stragtegy argument if set _must_ be a class that inherits from Opscode::Authentication::Strategies::Base and _must_
      #                         implement an @authenticate@ method
      #   <block> The block acts as a convinient way to declare your strategy.  Inside is the class definition of a strategy.
      #
      # Examples:
      #
      #   Block Declared Strategy:
      #    Opscode::Authentication::Strategies.add(:foo) do
      #      def authenticate
      #        # authentication logic
      #      end
      #    end
      #
      #    Class Declared Strategy:
      #      Opscode::Authentication::Strategies.add(:foo, MyStrategy)
      #
      class Base

        attr_reader :user_mapper

        def logger
          # TODO: less ghetto.
          @logger ||= Logger.new('/dev/null')
        end

        def authenitcate(*args)
          raise NotImplementedError, "#{self.class} should implement this method"
        end

        def authenticate?(*args)
          result = !!authenticate(*args)
          yield if result && block_given?
          result
        end

        def authenticate!(*args)
          user = authenitcate(*args)
          throw AccessDeniedException unless user
          user
        end
      end
    end
  end
end
