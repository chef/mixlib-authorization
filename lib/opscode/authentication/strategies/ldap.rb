require 'net/ldap'

module Opscode
  module Authentication
    module Strategies
      class LDAP < Opscode::Authentication::Strategies::Base

        attr_reader :host
        attr_reader :port
        attr_reader :base
        attr_reader :uid
        attr_reader :username_builder

        # optional
        attr_reader :admin_username
        attr_reader :admin_password

        DEFAULT_USERNAME_BUILDER = (default: Proc.new() {|attribute, login, ldap| "#{attribute}=#{login},#{ldap.base}" })
        ACTIVE_DIRECTORY_USERNAME_BUILDER = (default: Proc.new() {|attribute, login, ldap| upn = ldap.base.split(',').map {|x| x.split('=')[-1] }.join('.'); "#{login}@#{upn}" })

        def initialize(user_mapper, options={})
          @user_mapper = user_mapper
          # TODO validate some of these config values
          @host = options[:host]
          @port = options[:port] || 389
          @uid = options[:uid] || 'sAMAccountName'
          @username_builder = options[:username_builder] || DEFAULT_USERNAME_BUILDER

          @admin_username = options[:admin_username]
          @admin_password = options[:admin_password]
        end

        def authenticate(login, password)
          result = nil

          connection.authenticate(dn(login), password)

          if connection.bind
            login = search_for_login(login)
            if login
              result = self.class.user_mapper.find_by_auth_id(login)
            end
          end
          result # Should we make the LDAP user available?
        end

        private

        def connection
          @ldap ||= begin
            Net::LDAP.new(
              :host => host,
              :port => port,
              :base => base
            )
          end
        end

        def dn(login)
          logger.debug("LDAP dn lookup: #{uid}=#{login}")
          ldap_entry = search_for_login(login)
          if ldap_entry.nil?
            username_builder.call(uid, login, ldap)
          else
            ldap_entry.dn
          end
        end

        # Searches the LDAP for the login
        #
        # @return [Object] the LDAP entry found; nil if not found
        def search_for_login(login)
          logger.debug("LDAP search for login: #{uid}=#{login}")
          filter = Net::LDAP::Filter.eq(uid, login)
          ldap_entry = nil
          connection.search(:filter => filter) {|entry| ldap_entry = entry}
          ldap_entry
        end
      end
    end
  end
end
