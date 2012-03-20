require 'opscode/authentication/strategies/base'
require 'net/ldap'

module Opscode
  module Authentication
    module Strategies
      class LDAP < Opscode::Authentication::Strategies::Base

        attr_reader :host
        attr_reader :port
        # assumes the format:
        #  cn=users,dc=opscode,dc=com
        attr_reader :base
        # adjust to non-standard format for user authentication (bind) login
        attr_reader :bind_login_format
        # :login_attribute is the LDAP attribute name for the user name in the login form.
        # typically AD would be 'cn', while OpenLDAP is 'uid'.
        attr_reader :login_attribute
        # :uid_attribute is the LDAP attribute name for the most unique identifier for the
        # user--hopefully one that will not change when the username changes.  Typically AD
        # would be 'objectsid'.
        attr_reader :uid_attribute
        # :login_attribute is the LDAP attribute name for the username that this entry maps
        # to in Chef.  For AD, this would typically be sAMAccountName or UserPrincipalName.
        attr_reader :chef_username_attribute

        DEFAULT_BIND_FORMAT = "%{uid}=%{login},%{base}"

        def initialize(options={})
          # TODO validate some of these config values
          @host = options[:host]
          @port = options[:port] || 389
          @base = options[:base]
          @bind_login_format = options[:bind_login_format] || DEFAULT_BIND_FORMAT
          @login_attribute = options[:login_attribute] || 'cn'
          @uid_attribute = options[:uid_attribute] || 'uid'
          @chef_username_attribute = options[:chef_username_attribute] || options[:login_attribute]

          super
        end

        # perform authentication via a bind against the configured LDAP instance
        # returns the underlying LDAP entry
        def authenticate(login, password)
          begin
            Net::LDAP.open(:host => host, :port => port, :base => base, :auth => build_auth_hash(login, password)) do |connection|
              # Authenticate
              unless connection.bind
                raise AccessDeniedException, connection.get_operation_result.message
              end
              # Retrieve user record from LDAP
              connection.search(:filter => Net::LDAP::Filter.eq(login_attribute, login)) do |entry|
                return ldap_to_chef_user(entry)
              end
              raise "Could not find LDAP user #{login_attribute}=#{login} with base #{base}"
            end
          rescue Net::LDAP::LdapError => e # assume the LDAP system is borked
            raise RemoteAuthenticationException, e.message
          end
        end

        # Same API as authenticated, but returns a boolean instead of a user.
        # If a block is provided yields the underlying LDAP entry on successful
        # binding
        def authenticate?(login, password, &block)
          result = authenticate(login, password)
          yield result if result && block_given?
          !!result
        end

        private

        def build_auth_hash(login, password)
          formatted_login = bind_login_format % \
              {:login => login, :uid => login_attribute, :base => base}
          {:method => :simple, :username => formatted_login, :password => password}
        end

        def ldap_to_chef_user(ldap_user)
          {
            :first_name => ldap_user['givenname'][0],
            :last_name => ldap_user['sn'][0],
#            :middle_name => "trolol",
            :display_name => ldap_user['displayname'][0],
            :email => ldap_user['mail'][0],
            :username => ldap_user[chef_username_attribute][0],
#            :public_key => nil,
#            :certificate => SAMPLE_CERT,
            :city => ldap_user['l'][0],
            :country => ldap_user['c'][0],
#            :twitter_account => "moonpolysoft",
#            :hashed_password => "some hex bits",
#            :salt => "some random bits",
#            :image_file_name => 'current_status.png',
            :external_authentication_uid => ldap_user[uid_attribute][0].unpack('H*')[0],
            :recovery_authentication_enabled => false,
#            :created_at => ldap_user['whencreated'],
#            :updated_at => @now.utc.to_s
          }
        end
      end
    end
  end
end
