require 'opscode/authentication/strategies/base'
require 'net/ldap'

module Opscode
  module Authentication
    module Strategies
      class LDAP < Opscode::Authentication::Strategies::Base

        attr_reader :host
        attr_reader :port
        # assumes a format like:
        #  cn=users,dc=opscode,dc=us
        attr_reader :base_dn
        # The LDAP attribute holding the user's login name. Typically in Active
        # Directory it will be ``sAMAccountName``, while in OpenLDAP it is ``uid``.
        attr_reader :login_attribute

        def initialize(options={})
          # TODO validate some of these config values
          @host = options[:host]
          @port = options[:port] || 389
          @base_dn = options[:base_dn]
          @login_attribute = (options[:login_attribute] || 'samaccountname').downcase
          super
        end

        # perform authentication via a bind against the configured LDAP instance
        # returns the underlying LDAP entry
        def authenticate(login, password)
          begin

            auth = {:method => :simple,
                    :username => format_login_for_binding(login),
                    :password => password}

            Net::LDAP.open(:host => host, :port => port, :base => base_dn, :auth => auth) do |connection|
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

        # Determines the proper binding format for the login name:
        #
        #   opscode\testy
        #   testy@opscode.us
        #   CN=Testy McTesterson,CN=Users,DC=opscode,DC=us"
        #
        def format_login_for_binding(login)
          # If we already have an old-school domain login (domain\user) or
          # newer-style UPN login (user@domain) return it.
          if login =~ /[\\@]/
            login
          elsif active_directory?
            # extract the domain components from the base distinguished name and
            # create a UPN:
            #
            #   dc=opscode,dc=us => opscode.us
            base_upn = base_dn.split(/,?dc\s?=\s?/i)[-2..-1].join('.')
            "#{login}@#{base_upn}"
          else
            # fall back to binding with standard LDAP common name
            "cn=#{login},#{base_dn}"
          end
        end

        def ldap_to_chef_user(ldap_user)
          # AD contains a binary SID we must unpack
          external_uid = if ldap_user['objectsid']
            ldap_user['objectsid'].first.unpack('H*')[0]
          elsif ldap_user['samaccountname']
            ldap_user['samaccountname'].first
          else
            ldap_user['uid'].first
          end

          {
            :first_name => ldap_user['givenname'][0],
            :last_name => ldap_user['sn'][0],
            :display_name => ldap_user['displayname'][0],
            :email => ldap_user['mail'][0],
            :username => ldap_user[login_attribute][0],
            :city => ldap_user['l'][0],
            :country => ldap_user['c'][0],
            :external_authentication_uid => external_uid,
            :recovery_authentication_enabled => false,
          }
        end

        # sniff test to determine if we are dealing with the Active Directory
        # flavor of LDAP.  Mainly used to make certain assumption about things
        # like attribute naming and login name binding format.
        def active_directory?
          # TODO - there has to be a better way
          (login_attribute == 'samaccountname') ||
            (login_attribute == 'cn')
        end
      end
    end
  end
end
