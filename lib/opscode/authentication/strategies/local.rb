
module Opscode
  module Authentication
    module Strategies
      class Local < Opscode::Authentication::Strategies::Base

        def initialize(user_mapper, options={})
          @user_mapper = user_mapper
        end

        def authenticate(login, password)
          user = nil
          u = user_mapper.find_by_username(login)
          if u && u.correct_password?(password)
            user = u
          end
          user
        end

      end
    end
  end
end
