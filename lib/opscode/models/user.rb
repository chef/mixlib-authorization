# encoding: binary
# ^^ is needed for the email address regex to work properly
require 'openssl'
require 'digest/sha2'
require 'active_model'
require 'active_model/validations'

module Opscode
  module Models
    class User
      include ActiveModel::Validations

      # Stolen from CouchRest for maxcompat:
      #
      # Extracted from dm-validations 0.9.10
      #
      # Copyright (c) 2007 Guy van den Berg
      #
      # Permission is hereby granted, free of charge, to any person obtaining
      # a copy of this software and associated documentation files (the
      # "Software"), to deal in the Software without restriction, including
      # without limitation the rights to use, copy, modify, merge, publish,
      # distribute, sublicense, and/or sell copies of the Software, and to
      # permit persons to whom the Software is furnished to do so, subject to
      # the following conditions:
      #
      # The above copyright notice and this permission notice shall be
      # included in all copies or substantial portions of the Software.
      #
      # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
      # EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
      # MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
      # NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
      # LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
      # OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
      # WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
      #
      EmailAddress = begin
        alpha = "a-zA-Z"
        digit = "0-9"
        atext = "[#{alpha}#{digit}\!\#\$\%\&\'\*+\/\=\?\^\_\`\{\|\}\~\-]"
        dot_atom_text = "#{atext}+([.]#{atext}*)*"
        dot_atom = "#{dot_atom_text}"
        qtext = '[^\\x0d\\x22\\x5c\\x80-\\xff]'
        text = "[\\x01-\\x09\\x11\\x12\\x14-\\x7f]"
        quoted_pair = "(\\x5c#{text})"
        qcontent = "(?:#{qtext}|#{quoted_pair})"
        quoted_string = "[\"]#{qcontent}+[\"]"
        atom = "#{atext}+"
        word = "(?:#{atom}|#{quoted_string})"
        obs_local_part = "#{word}([.]#{word})*"
        local_part = "(?:#{dot_atom}|#{quoted_string}|#{obs_local_part})"
        no_ws_ctl = "\\x01-\\x08\\x11\\x12\\x14-\\x1f\\x7f"
        dtext = "[#{no_ws_ctl}\\x21-\\x5a\\x5e-\\x7e]"
        dcontent = "(?:#{dtext}|#{quoted_pair})"
        domain_literal = "\\[#{dcontent}+\\]"
        obs_domain = "#{atom}([.]#{atom})*"
        domain = "(?:#{dot_atom}|#{domain_literal}|#{obs_domain})"
        addr_spec = "#{local_part}\@#{domain}"
        pattern = /^#{addr_spec}$/
      end

      def self.add_model_attribute(attr_name)
        @model_ivars ||= {}
        ivar = "@#{attr_name}".to_sym
        model_attributes[attr_name] = ivar
        model_ivars[ivar] = attr_name
      end

      def self.model_attributes
        @model_attributes ||= {}
      end

      def self.model_ivars
        @model_ivars ||= {}
      end

      def self.rw_attribute(attr_name)
        add_model_attribute(attr_name)
        attr_accessor attr_name
      end

      def self.ro_attribute(attr_name)
        add_model_attribute(attr_name)
        attr_reader attr_name
      end

      rw_attribute :id
      rw_attribute :actor_id
      rw_attribute :first_name
      rw_attribute :last_name
      rw_attribute :middle_name
      rw_attribute :display_name
      rw_attribute :email
      rw_attribute :username
      rw_attribute :public_key
      rw_attribute :certificate
      rw_attribute :city
      rw_attribute :country
      rw_attribute :twitter_account
      rw_attribute :image_file_name

      ro_attribute :password # with a custom setter below
      ro_attribute :hashed_password
      ro_attribute :salt

      validates_presence_of :first_name
      validates_presence_of :last_name
      validates_presence_of :display_name
      validates_presence_of :username
      validates_presence_of :email

      # We need to get a password when creating; on updates we only need a
      # password when updating the hashed_password
      validates_presence_of :password, :unless => :persisted?

      validates_presence_of :hashed_password
      validates_presence_of :salt

      validates_format_of :username, :with => /^[a-z0-9\-_]+$/
      validates_format_of :email, :with => EmailAddress

      validates_length_of :password, :within => 6..50
      validates_length_of :username, :within => 1..50

      validate :certificate_or_pubkey_present

      def initialize(params={})
        params.each do |attr, value|
          if ivar = self.class.model_attributes[attr]
            instance_variable_set(ivar, params[attr])
          else
            raise ArgumentError, "unknown attribute #{attr} (set to #{value}) for #{self.class}"
          end
        end
        @persisted = false
      end

      # Generates a new salt (overwriting the old one, if any) and sets password
      # to the salted digest of +unhashed_password+
      def password=(unhashed_password)
        @password = unhashed_password
        generate_salt!
        @hashed_password = encrypt_password(unhashed_password)
      end

      def public_key
        if @public_key
          @public_key
        elsif certificate
          OpenSSL::X509::Certificate.new(certificate).public_key
        else
          nil
        end
      end

      def persisted?
        @persisted
      end

      def persisted!
        @persisted = true
      end

      def to_param
        persisted? ? username : nil
      end

      def to_key
        persisted? ? [username] : nil
      end

      def for_json
        # TODO!
        #
        # Example output from AuthZ::Models::User :
        # =New style user w/ cert:
        # {"salt"=>"41VUs96LS6fGYfWHNYibkyA5yPYlL9OHtTkvO7hj9fr4aSMEUXKna72a2-8q",
        #  "city"=>nil,
        #  "image_file_name"=>nil,
        #  "twitter_account"=>nil,
        #  "_rev"=>"3-3549bc41b3d0ab5eacfd1148b5cb2255",
        #  "country"=>nil,
        #  "certificate"=>"-----BEGIN CERTIFICATE-----\nMIIDODCCAqGgAwIBAgIEz5HZWDANBgkqhkiG9w0BAQUFADCBnjELMAkGA1UEBhMC\nVVMxEzARBgNVBAgMCldhc2hpbmd0b24xEDAOBgNVBAcMB1NlYXR0bGUxFjAUBgNV\nBAoMDU9wc2NvZGUsIEluYy4xHDAaBgNVBAsME0NlcnRpZmljYXRlIFNlcnZpY2Ux\nMjAwBgNVBAMMKW9wc2NvZGUuY29tL2VtYWlsQWRkcmVzcz1hdXRoQG9wc2NvZGUu\nY29tMCAXDTExMDcxOTIyNTY1MloYDzIxMDAwOTIwMjI1NjUyWjCBmzEQMA4GA1UE\nBxMHU2VhdHRsZTETMBEGA1UECBMKV2FzaGluZ3RvbjELMAkGA1UEBhMCVVMxHDAa\nBgNVBAsTE0NlcnRpZmljYXRlIFNlcnZpY2UxFjAUBgNVBAoTDU9wc2NvZGUsIElu\nYy4xLzAtBgNVBAMUJlVSSTpodHRwOi8vb3BzY29kZS5jb20vR1VJRFMvdXNlcl9n\ndWlkMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0NKi934E1BoX2PVP\nNlv+2rtdFervrNt5tK762QYFBlciwAdH0DIxcBsEpJyi/V/IAPi05LRoIs+a2qjN\nVD73YjxoKIVnm3wFOEHY6XKMN0NCzyhPPxGQqws9aSSOU1lGa72sOoPGH+1e46ni\n7adW1TMTNN8w8bYCXeL2dvyXAbzlTap+tLbkeKgjt9MvRwFQfQ8Im9KqfuHDbVJn\nEquRIx/0TbT+BF9jBg463GG0tMKySulqw4+CpAAh2BxdjvdcfIpXQNPJao3CgvGF\nxN+GlrHO5kIGNT0iie+Z02TUr8sIAhc6n21q/F06W7i7vY07WgiwT+iLJ+IG4ylQ\newAYtwIDAQABMA0GCSqGSIb3DQEBBQUAA4GBAGKC0q99xFwyrHZkKhrMOZSWLV/L\n9t4WWPdI+iGB6bG0sbUF+bWRIetPtUY5Ueqf7zLxkFBvFkC/ob4Kb5/S+81/jE0r\nh7zcu9piePUXRq+wzg6be6mTL/+YVFtowSeBR1sZbhjtNM8vv2fVq7OEkb7BYJ9l\nHYCz2siW4sVv9rca\n-----END CERTIFICATE-----\n",
        #  "_id"=>"033b2bbea7551073dce3d52133aff8bd",
        #  "username"=>"kallistec2",
        #  "couchrest-type"=>"Mixlib::Authorization::Models::User",
        #  "last_name"=>"deleo",
        #  "display_name"=>"dan deleo",
        #  "password"=>"ff99a4ed138363b4db3957366149dcf2d078a885",
        #  "requester_id"=>"4920224947d7ed92e872e53b620e94b7",
        #  "middle_name"=>"",
        #  "first_name"=>"dan",
        #  "email"=>"dan+trolol@opscode.com"}
        #
        # =Old style w/ pubkey:
        # {"salt"=>"cdcb3129-3b54-aac3-f3c5-31c5cacdfdc4",
        #  "public_key"=>"-----BEGIN RSA PUBLIC KEY-----\nMIIBCgKCAQEA3ml2+ld8kOcqFshKVHApLXgLpNYqLWrIfF3kogJLDWKYuW+sCZna\nbO1m7AKgM2vE87R1ASmepluUYafiztPl8ywYS06ZkgF/ihMnsINF0a2h1dz4YW83\npci5ZMbCPt7cU3D+3F3qLvefDLozHNteFndseA7xxTGGIZ6WN7on+wMPWCis1YR0\nM1CV69ySH3PS/E4slP/ClO3Tvn+P3a3UAyR+cL2lU5djDt+/p8TikJyTFaC9ABZR\nhtgQUPmE4p43S4/kogli7ST/pUOBHXMA69D9hhDqLLtAkknACVN4ZhRUxittdA1c\nhuOvPWgP1KG10DB08Wq2AyhMBEYKonf0rQIDAQAB\n-----END RSA PUBLIC KEY-----\n",
        #  "_rev"=>"3-ea3490bfb7f783b7cae728261c5a34aa",
        #  "_id"=>"bba1b4d7578ff21b1ac03a60194e8d69",
        #  "username"=>"dan",
        #  "last_name"=>"CommunitySite",
        #  "couchrest-type"=>"Mixlib::Authorization::Models::User",
        #  "display_name"=>"CommunitySite",
        #  "password"=>"610615d59afa9717c30aed015bd3ee12723438e5",
        #  "middle_name"=>"CommunitySite",
        #  "requester_id"=>"4920224947d7ed92e872e53b620e94b7",
        #  "email"=>"dan@opscode.com",
        #  "first_name"=>"CommunitySite"}
        #
      end

      def certificate_or_pubkey_present
        if certificate.nil? && public_key.nil?
          errors.add(:credentials, "must have a certificate or public key")
        elsif certificate && public_key # should never have BOTH
          errors.add(:credentials, "cannot have both a certificate and public key")
        end
      end

      # Since this model doesn't use the Active Record pattern, it can't talk
      # to the database to determine if an email address is taken or not. This
      # is here for the data access layer to add validation errors for invalid
      # email addrs.
      def email_not_unique!
        errors.add(:email, "is already in use")
      end

      # Same deal as with email, these objects can't determine if their attrs
      # are globally unique or not, so the data layer calls this when a
      # uniqueness constraint is violated.
      def username_not_unique!
        errors.add(:username, "is already taken")
      end

      private

      # Generates a 60 Char salt in URL-safe BASE64 and sets @salt to this value
      def generate_salt!
        base64_salt = [OpenSSL::Random.random_bytes(48)].pack("m*").delete("\n")
        # use URL-safe base64, just in case
        base64_salt.gsub!('/','_')
        base64_salt.gsub!('+','-')
        @salt = base64_salt[0..59]
      end

      def encrypt_password(password)
        Digest::SHA1.hexdigest("#{salt}--#{password}--")
      end

    end
  end
end

