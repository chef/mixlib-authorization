module Opscode
  module Authentication

    class AccessDeniedException < StandardError ; end
    class AuthenticationServiceException  < StandardError ; end
    class RemoteAuthenticationException  < StandardError ; end

    module Strategies

      # A strategy is a place where you can put logic related to authentication.
      # Any strategy inherits from Opscode::Authentication::Strategies.
      #
      # The Opscode::Authentication::Strategies.add method is a simple way to
      # provide additional custom strategies.
      #
      # Strategies _must_ declare an @authenticate@ method.
      class Base

        attr_reader :user_mapper

        def initialize(user_mapper)
          @user_mapper = user_mapper
        end

        # TODO figure out where this gets fed in
        def logger
          @logger ||= Logger.new('/dev/null')
        end

        # Run the authentiation strategy and return the underlying user instance
        # if authentication is successful
        def authenitcate(*args)
          raise NotImplementedError, "#{self.class} should implement this method"
        end

        # Same API as authenticated, but returns a boolean instead of a user.
        def authenticate?(*args)
          result = !!authenticate(*args)
          yield if result && block_given?
          result
        end

        # The same as +authenticate+ except on failure it will throw an
        # +AccessDeniedException+
        def authenticate!(*args)
          user = authenitcate(*args)
          throw AccessDeniedException unless user
          user
        end
      end
    end
  end
end
