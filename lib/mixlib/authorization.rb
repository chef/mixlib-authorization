require 'extlib'
require 'couchrest'
require 'mixlib/log'

module Mixlib
  module Authorization
    
    class Log
      extend  Mixlib::Log      
    end
    
    class AuthorizationException < StandardError
    end
    
    class Config
      cattr_accessor :default_database
      cattr_accessor :privkey      
    end
  end
end

