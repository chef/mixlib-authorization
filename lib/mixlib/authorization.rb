require 'extlib'
require 'couchrest'
require 'mixlib/config'
require 'mixlib/log'

module Mixlib
  module Authorization
    
    class Log
      extend  Mixlib::Log      
    end
    
    class AuthorizationException < StandardError
    end
    
    class Config
      extend Mixlib::Config

      default_database nil
      private_key nil
      authorization_service_uri nil
      certificate_service_uri nil
      couchdb_uri nil
    end
  end
end

