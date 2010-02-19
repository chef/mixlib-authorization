#
# Author:: Christopher Brown <cb@opscode.com>
#
# Copyright 2009, Opscode, Inc.
#
# All rights reserved - do not redistribute
#

require 'extlib'
require 'couchrest'
require 'mixlib/config'
require 'mixlib/log'

module Mixlib
  module Authorization
    
    class Log
      extend  Mixlib::Log      
    end

    Log.level = :error
    
    class AuthorizationError < StandardError
    end
    
    class Config
      extend Mixlib::Config

      default_database nil
      private_key nil
      authorization_service_uri nil
      certificate_service_uri nil
      couchdb_uri nil
      web_ui_public_key nil
      web_ui_private_key nil
      web_ui_proxy_user nil
    end
  end
end

