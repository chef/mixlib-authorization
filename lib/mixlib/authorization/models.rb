
require 'extlib'

module Mixlib
  module Authorization
    module Models
      class Config
        cattr_accessor :default_database        
      end
    end
  end
end

require 'mixlib/authorization/models/join_document'
require 'mixlib/authorization/models/join_types'
require 'mixlib/authorization/models/user'
require 'mixlib/authorization/models/client'
require 'mixlib/authorization/models/group'
require 'mixlib/authorization/models/container'
