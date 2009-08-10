#
# Author:: Christopher Brown <cb@opscode.com>
#
# Copyright 2009, Opscode, Inc.
#
# All rights reserved - do not redistribute
#

require 'mixlib/authentication/signatureverification'
require 'mixlib/authorization/models'

module Mixlib
  module Authorization
    module RequestAuthentication
      
      class << self
        def authenticator
          @authenticator ||= Mixlib::Authentication::SignatureVerification.new      
        end

        def authenticate_every(request, params)
          auth = begin
                   Mixlib::Authorization::Log.debug("Raw request: #{request.inspect}")
                   headers = request.env.inject({ }) { |memo, kv| memo[$2.downcase.to_sym] = kv[1] if kv[0] =~ /^(HTTP_)(.*)/; memo }
                   username = headers[:x_ops_userid].chomp
                   orgname = params[:organization_id]
                   Mixlib::Authorization::Log.debug "I have #{headers.inspect}"
                   
                   user = begin
                            Mixlib::Authorization::Models::User.find(username)
                          rescue ArgumentError
                            if orgname
                              cr = database_from_orgname(orgname)
                              Mixlib::Authorization::Models::Client.on(cr).by_clientname(:key=>username).first
                            end
                          end
                   
                   actor = user_to_actor(user.id)
                   params[:requesting_actor_id] = actor.auth_object_id
                   user_key = OpenSSL::PKey::RSA.new(user.public_key)
                   Mixlib::Authorization::Log.debug "authenticating:\n #{user.inspect}\n"
                   authenticator.authenticate_user_request(request, user_key)
                 rescue StandardError => se
                   Mixlib::Authorization::Log.debug "authenticate every failed: #{se}, #{se.backtrace}"
                   nil
                 end
          raise Mixlib::Authorization::AuthorizationException, "Failed authorization" unless auth          
          auth
        end
      end      
    end
  end
end
