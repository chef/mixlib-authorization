require 'opscode/authentication/strategies/base'

module Opscode
  module Authentication
    module Strategies
      class Local < Opscode::Authentication::Strategies::Base

        def initialize(user_mapper, options={})
          @user_mapper = user_mapper
        end

        # performs authentication against the local database
        def authenticate(login, password)
          user = @user_mapper.find_by_username(login)
          unless user && user.correct_password?(password)
            raise AccessDeniedException, "Username and password incorrect"
          end
          user.for_json
        end

      end
    end
  end
end
