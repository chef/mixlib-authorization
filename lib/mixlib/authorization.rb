require 'couchrest'
require 'mixlib/log'

module Mixlib
  module Authorization
    class Log
      extend  Mixlib::Log      
    end
  end
end

require 'mixlib/authorization/internal_auth'
require 'mixlib/authorization/join_helper'
require 'mixlib/authorization/auth_helper'
require 'mixlib/authorization/auth_join'

