#
# Author:: Adam Jacob <adam@opscode.com>
# Author:: Christopher Brown <cb@opscode.com>
# Author:: Nuo Yan <nuo@opscode.com>
#
# Copyright 2009, Opscode, Inc.
#
# All rights reserved - do not redistribute
#

module Mixlib
  module Authorization
    module Models
      class User < CouchRest::ExtendedDocument
        include CouchRest::Validation
        include Mixlib::Authorization::AuthHelper
        include Mixlib::Authorization::JoinHelper
        
        use_database Mixlib::Authorization::Config.default_database
        
        view_by :first_name
        view_by :last_name
        view_by :middle_name
        view_by :display_name
        view_by :email 
        view_by :username
        view_by :city
        view_by :country
        view_by :twitter_accuont

        property :first_name
        property :last_name
        property :middle_name
        property :display_name
        property :email
        property :username
        property :public_key
        property :certificate
        property :city
        property :country
        property :twitter_account
        property :password
        property :salt
        property :image_file_name
        
        validates_with_method :username, :unique_username?
        validates_with_method :email, :unique_email?
        
        
        validates_present :first_name, :last_name, :display_name, :username, :email, :password, :salt

        validates_format :username, :with => /^[a-z0-9\-_]+$/
        validates_format :email, :as => :email_address
        
        validates_length :password, :within => 6..50
        validates_length :username, :within => 1..50
        
        auto_validate!
        
        create_callback :after, :create_join
        update_callback :after, :update_join
        destroy_callback :before, :delete_join

        join_type Mixlib::Authorization::Models::JoinTypes::Actor

        join_properties :requester_id
        
        # Generates a new salt (overwriting the old one, if any) and sets password
        # to the salted digest of +unhashed_password+
        def set_password(unhashed_password)
          generate_salt!
          self[:password] = encrypt_password(unhashed_password)
        end
        
        def correct_password?(unhashed_password)
          encrypt_password(unhashed_password) == self[:password]
        end
        
        def public_key
          self[:public_key] || OpenSSL::X509::Certificate.new(self.certificate).public_key
        end
        
        def unique_username?
          begin
            r = User.by_username(:key => self[:username], :include_docs => false)
            how_many = r["rows"].length
            # If we don't have an object with this name, then we are the first, and it's cool.
            # If we do have *one*, and we have an id, we assume we are safe to save ourself again.
            return true if (how_many == 0) || (how_many == 1 && self.has_key?('_id'))
          rescue StandardError => se
            Mixlib::Authorization::Log.error "Failed to determine if username '#{self['username']}' is unique"
            Mixlib::Authorization::Log.debug(se.inspect)
            Mixlib::Authorization::Log.debug(se.backtrace.join("\n"))
          end
          [ false, "The name #{self[:username]} is not unique!" ]
        end
        
        def unique_email?
          begin
            r = User.by_email(:key => self[:email], :include_docs => false)
            how_many = r["rows"].length
            # If we don't have an object with this name, then we are the first, and it's cool.
            # If we do have *one*, and we have an id, we assume we are safe to save ourself again.
            return true if (how_many == 0) || (how_many == 1 && self.has_key?('_id'))
          rescue StandardError => se
            Mixlib::Authorization::Log.error "Failed to determine if E-mail '#{self['email']}' is unique"
          end
          [ false, "The E-mail #{self[:email]} is not unique!" ]
        end
        
        def self.find(name)
          User.by_username(:key => name).first or raise ArgumentError, "User named #{name} cannot be found in the database"
        end
        
        def for_json
          self.properties.inject({ }) do |result, prop|
            pname = prop.name.to_sym
            result[pname] = self.send(pname)
            result
          end
        end
        
        private
        
        # Generates a 60 Char salt in URL-safe BASE64 and sets self[:salt] to this value
        def generate_salt!
          base64_salt = [OpenSSL::Random.random_bytes(48)].pack("m*").delete("\n")
          # use URL-safe base64, just in case
          base64_salt.gsub!('/','_')
          base64_salt.gsub!('+','-')
          self[:salt] = base64_salt[0..59]
        end
        
        def encrypt_password(password)
          Digest::SHA1.hexdigest("#{salt}--#{password}--")
        end

      end
      
    end
  end
end
