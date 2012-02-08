require 'net/ldap'

module Opscode
  module Authentication
    module Strategies
      class LDAP < Opscode::Authentication::Strategies::Base

        attr_reader :host
        attr_reader :port
        # assumes the format:
        #  dc=opscode,dc=com
        attr_reader :base
        # :uid is the LDAP attribute name for the user name in the login form.
        # typically AD would be 'sAMAccountName' or 'UserPrincipalName',
        # while OpenLDAP is 'uid'.
        attr_reader :uid
        # adjust to non-standard format for user authentication (bind) login
        attr_reader :bind_login_format

        DEFAULT_BIND_FORMAT = "%{uid}=%{login},%{base}"

        def initialize(user_mapper, options={})
          # TODO validate some of these config values
          @host = options[:host]
          @port = options[:port] || 389
          @uid = options[:uid] || 'uid'
          @bind_login_format = options[:bind_login_format] || DEFAULT_BIND_FORMAT

          super(user_mapper)
        end

        # perform authentication via a bind against the configured LDAP instance
        # returns the underlying LDAP entry
        def authenticate(login, password)
          result = nil

          connection.authenticate(bind_name(login), password)

          if connection.bind
            result = search_for_login(login)
            # if login
            #   result = self.class.user_mapper.find_by_auth_id(login)
            # end
          end
          result
        end

        # Same API as authenticated, but returns a boolean instead of a user.
        # If a block is provided yields the underlying LDAP entry on successful
        # binding
        def authenticate?(login, password, &block)
          result = !!authenticate(*args)
          yield ldap_entry if result && block_given?
          result
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

        def bind_name(login)
          bind_login_format % \
              {:login => login, :uid => uid, :base => base}
        end

        # Searches the LDAP for the login.
        #
        # Returns the LDAP entry found; nil if not found
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
