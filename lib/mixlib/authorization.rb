require 'couchrest'
require 'mixlib/log'

module Mixlib
  module Authorization
    
    PRIVKEY = nil
    
    class Log
      extend  Mixlib::Log      
    end
    
    class AuthorizationException < StandardError
    end
    
  end
end

require 'mixlib/authorization/join_helper'
require 'mixlib/authorization/auth_helper'
require 'mixlib/authorization/auth_join'
require 'mixlib/authorization/request_authentication'

