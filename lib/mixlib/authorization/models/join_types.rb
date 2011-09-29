#
# Author:: Christopher Brown <cb@opscode.com>
#
# Copyright 2009, Opscode, Inc.
#
# All rights reserved - do not redistribute
#

module Mixlib
  module Authorization
    module Models
      module JoinTypes
        class Group < Mixlib::Authorization::Models::JoinDocument
        end

        class Actor < Mixlib::Authorization::Models::JoinDocument
        end

        class Container < Mixlib::Authorization::Models::JoinDocument
        end

        class Object < Mixlib::Authorization::Models::JoinDocument
        end
      end
    end

  end
end
