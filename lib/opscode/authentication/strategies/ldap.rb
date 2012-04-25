require 'opscode/authentication/strategies/base'
require 'net/ldap'

module Opscode
  module Authentication
    module Strategies
      class LDAP < Opscode::Authentication::Strategies::Base

        attr_reader :host
        attr_reader :port
        attr_reader :bind_dn
        attr_reader :bind_password
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
          @bind_dn = options[:bind_dn]
          @bind_password = options[:bind_password]
          @base_dn = options[:base_dn]
          @login_attribute = (options[:login_attribute] || 'samaccountname').downcase
          super
        end

        # perform authentication via a bind against the configured LDAP instance
        # returns the underlying LDAP entry
        def authenticate(login, password)

          begin
            client.search(:base => base_dn,
              :filter => Net::LDAP::Filter.eq(login_attribute, login), :size => 1) do |entry|

              # attempt to authenticate as user
              unless client.bind_as(:base => base_dn, :filter => "(#{@login_attribute}=#{login})", :password => password)
                raise AccessDeniedException, "Remote LDAP authentication (bind) failed for '#{login}'"
              end

              return ldap_record_to_chef_user(entry)
            end

            # return a nice failure message
            message = case client.get_operation_result.code
              when 0 # search failed
                "Could not locate a record with distinguished name [#{login_attribute}=#{login},#{base_dn}] on remote LDAP server."
              when 49 # bind failed
                "Could not bind to remote LDAP server. Please ensure the 'bind_dn' and 'bind_password' values are correct."
              else # everything else
                "Could not complete remote LDAP operation (#{format_error_for_display(client.get_operation_result)})"
              end

            raise AccessDeniedException, message

          rescue Errno::ETIMEDOUT => e # LDAP timeout
            raise RemoteAuthenticationException, e.message
          rescue Net::LDAP::LdapError => e # assume the LDAP system is borked
            raise RemoteAuthenticationException, e.message
          end
        end

        # Same API as authenticated, but returns a boolean instead of a user.
        # If a block is provided yields the underlying LDAP entry on successful
        # binding
        def authenticate?(login, password, &block)
          result = authenticate(login, password) rescue false
          yield result if result && block_given?
          !!result
        end

        private

        def client
          @client ||= begin
            opts = {:host => @host, :port => @port}
            if @bind_dn && @bind_password
              opts[:auth] = {
                :method => :simple,
                :username => @bind_dn,
                :password => @bind_password
              }
            end
            Net::LDAP.new(opts)
          end
        end

        def ldap_record_to_chef_user(ldap_user)
          # AD contains a binary SID we must unpack
          external_uid = if ldap_user['objectsid']
            sid_to_string_sid(ldap_user['objectsid'].first)
          else
            ldap_user['uid'].first
          end

          username = ldap_user[login_attribute][0].force_encoding("UTF-8").downcase.gsub(/[^a-z0-9\-_]/, '_')

          {
            :first_name => ldap_user['givenname'][0].force_encoding("UTF-8"),
            :last_name => ldap_user['sn'][0].force_encoding("UTF-8"),
            :display_name => ldap_user['displayname'][0].force_encoding("UTF-8") || username,
            :email => ldap_user['mail'][0].force_encoding("UTF-8"),
            :username => username,
            :city => ldap_user['l'][0].force_encoding("UTF-8"),
            :country => ldap_user['c'][0].force_encoding("UTF-8"),
            :external_authentication_uid => external_uid,
            :recovery_authentication_enabled => false,
          }
        end

        def format_error_for_display(result)
          "code=#{result.code}, messsage=#{result.message}, error=#{result.error_message}"
        end

        def sid_to_string_sid(sid)
          # See http://blogs.msdn.com/b/oldnewthing/archive/2004/03/15/89753.aspx
          a,b,c1,c2,c3,c4,c5,c6,d,e,f,g ,h= sid.unpack('CCC6LLLLL')
          # c is big-endian, not little (plus, it's 48 bits)
          c = c6 | c5 << 8 | c4 << 16 | c3 << 24 | c2 << 32 | c1 << 40
          "S-#{a}-#{b}-#{c}-#{d}-#{e}-#{f}-#{g}-#{h}"
        end
      end
    end
  end
end
