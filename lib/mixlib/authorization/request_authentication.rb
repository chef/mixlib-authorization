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
      extend Mixlib::Authorization::AuthHelper
      
      class << self
        def authenticator
          @authenticator ||= Mixlib::Authentication::SignatureVerification.new      
        end

        def authenticate_every(request, params)
          auth = begin
                   headers = request.env.inject({ }) { |memo, kv| memo[$2.downcase.gsub(/\-/,"_").to_sym] = kv[1] if kv[0] =~ /^(HTTP_)(.*)/; memo }
                   Mixlib::Authorization::Log.debug("headers in authenticate_every: #{headers.inspect}")
                   username = headers[:x_ops_userid].chomp
                   #BUGBUG - next line seems odd.  Can't we ensure that it's *always* :organization_id? [cb]
                   orgname = params[:organization_id] || params[:id]
                   Mixlib::Authorization::Log.debug "Authenticating username #{username}, orgname #{orgname}"
                   
                   user = begin
                            Mixlib::Authorization::Log.debug "checking for user #{username}"
                            Mixlib::Authorization::Models::User.find(username)
                          rescue ArgumentError
                            if orgname
                              cr = database_from_orgname(orgname)
                              Mixlib::Authorization::Log.debug "checking for client #{username}"
                              Mixlib::Authorization::Models::Client.on(cr).by_name(:key=>username).first
                            end
                          end

                   raise Mixlib::Authorization::AuthorizationException, "Unable to find user or client" unless user
                   Mixlib::Authorization::Log.debug "Found user or client: #{user.inspect}"
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
