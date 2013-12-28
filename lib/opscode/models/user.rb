# encoding: binary
# ^^ is needed for the email address regex to work properly
require 'openssl'
require 'digest/sha2'
require 'bcrypt'
require 'active_model'
require 'active_model/validations'

require 'opscode/models/base'


module Opscode
  module Models
    class InvalidParameters < ArgumentError
    end

    class User < Base

      DEFAULT_BCRYPT_COST = 12
      HASH_TYPE_SHA1BCRYPT = 'SHA1-bcrypt'
      HASH_TYPE_BCRYPT     = 'bcrypt'

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

      use_authz_model_class(Opscode::AuthzModels::Actor)

      # Returns the class object that is used for the authz side representation
      # of this model. If not set, it will raise a NotImplementedError.
      def authz_model_class
        self.class.authz_model_class
      end

      rw_attribute :first_name
      rw_attribute :last_name
      rw_attribute :middle_name
      rw_attribute :display_name
      rw_attribute :email

      rw_attribute :username
      alias :name :username


      rw_attribute :city
      rw_attribute :country
      rw_attribute :twitter_account
      rw_attribute :image_file_name

      # An identifier unique to the given provider, such as an LDAP uid
      rw_attribute :external_authentication_uid

      # Indicates this user can fall back to local authentication (if configured).
      # Local authentication uses the values saved in username and hashed_password.
      rw_attribute :recovery_authentication_enabled

      # We now have a password checker API endpoint, so these should not appear
      # in API output. They are also not directly settable.
      protected_attribute :hashed_password
      protected_attribute :salt
      protected_attribute :hash_type

      protected_attribute :id
      protected_attribute :authz_id
      protected_attribute :created_at #custom reader method
      protected_attribute :updated_at #custom reader method
      protected_attribute :last_updated_by

      # As of 2013-12 we are switching back to generating simple RSA
      # key pairs for users and clients in EC rather than
      # certificates. We want to maintain back compat with users and
      # clients that have an existing certificate.
      rw_attribute :public_key
      rw_attribute :certificate

      attr_reader :password # with a custom setter below

      #########################################################################
      # NOTE: the error messages here are customized to match the previous
      # couchrest implementation as much as possible. I find the copy somewhat
      # awkward, but tests and who-knows-what-else expect the messages to have
      # this text, so we'll leave it for now.
      #########################################################################

      validates_presence_of :display_name, :message => "must not be blank"
      validates_presence_of :username, :message => "must not be blank"
      validates_presence_of :email, :message => "must not be blank", :unless => :external_authentication_enabled?

      # We need to get a password when creating; on updates we only need a
      # password when updating the hashed_password
      validates_presence_of :password, :if => Proc.new { |user| user.requires_password? && !user.persisted? }

      validates_presence_of :hashed_password, :if => :requires_password?
      validates_presence_of :salt, :if => lambda { |user| user.requires_password? and !user.using_bcrypt? }

      validates_format_of :username, :with => /^[a-z0-9\-_]+$/, :message => "has an invalid format (valid characters are a-z, 0-9, hyphen and underscore)"
      validates_format_of :email, :with => EmailAddress, :message => "has an invalid format", :if => Proc.new { |user| user.email != nil}

      validates_length_of :password, :within => 6..50, :message => 'must be between 6 and 50 characters', :if => :updating_password?
      validates_length_of :username, :within => 1..50

      validate :certificate_or_pubkey_present

      PASSWORD = 'password'.freeze
      CERTIFICATE = 'certificate'.freeze
      PUBLIC_KEY = 'public_key'.freeze

      def initialize(*args)
        # Default set to bcrypt. Mapper will override this to whatever is persisted
        @hash_type = external_authentication_enabled? ? nil : HASH_TYPE_BCRYPT

        super(*args)
      end

      # Override self.load to make a special case for hash_type
      def self.load(params)
        super(params).tap do |user|
          user.send(:instance_variable_set, :@hash_type, params[:hash_type])
        end
      end

      def for_json
        hash_for_json = super
        hash_for_json[:public_key] ||= public_key
        hash_for_json.delete(:certificate)
        hash_for_json
      end

      class HashType
        attr_reader :user
        def initialize(user)
          @user = user
        end

        def correct_password?(password)
          raise "Implement correct_password?()"
        end

        def hash_password(password)
          raise "Implement set_password()"
        end
      end

      class LegacyPassword < HashType
        def encrypt(unhashed_password)
          salt = generate_salt
          [encrypt_password(unhashed_password, salt), salt]
        end

        def correct_password?(candidate_password)
          hashed_candidate_password = encrypt_password(candidate_password, user.salt)
          (user.hashed_password.to_s.hex ^ hashed_candidate_password.hex) == 0
        end

        # Generates a 60 Char salt in URL-safe BASE64 and sets @salt to this value
        def generate_salt
          base64_salt = [OpenSSL::Random.random_bytes(48)].pack("m*").delete("\n")
          # use URL-safe base64, just in case
          base64_salt.gsub!('/','_')
          base64_salt.gsub!('+','-')
          base64_salt[0..59]
        end

        private

        def encrypt_password(password, salt)
          Digest::SHA1.hexdigest("#{salt}--#{password}--")
        end
      end

      class SHA1BCryptPassword < HashType
        # Instead, opscode-account should automatically convert to bcrypt on login/password change.
        def encrypt(unhashed_password)
          bcrypt_salt = BCrypt::Engine.generate_salt(DEFAULT_BCRYPT_COST)
          sha1_salt = user.salt || LegacyPassword.new(user).generate_salt

          # Wrap legacy password inside a bcrypt hash
          sha1_hashed_password = sha1_encrypt_password(unhashed_password, sha1_salt)
          bcrypt_secret = BCrypt::Engine.hash_secret(sha1_hashed_password, bcrypt_salt)

          [bcrypt_secret, sha1_salt]
        end

        def correct_password?(candidate_password)
          BCrypt::Password.new(user.hashed_password.to_s) == sha1_encrypt_password(candidate_password, user.salt)
        end

        private
        def sha1_encrypt_password(password, salt)
          Digest::SHA1.hexdigest("#{salt}--#{password}--")
        end
        # This is defined more as a way to test it. In production, this method should never be called.

      end

      class BCryptPassword < HashType
        # Instead, opscode-account should automatically convert to bcrypt on login/password change.
        def encrypt(unhashed_password)
          bcrypt_salt = BCrypt::Engine.generate_salt(DEFAULT_BCRYPT_COST)
          bcrypt_secret = BCrypt::Engine.hash_secret(unhashed_password, bcrypt_salt)

          # The database contains triggers that require hashed_password, salt, and hash_type
          # to all be non-null if any of the three are non-null.
          [bcrypt_secret, '']
        end

        def correct_password?(candidate_password)
          BCrypt::Password.new(user.hashed_password.to_s) == candidate_password
        end
      end

      # Assigns instance variables from "safe" params, that is ones that are
      # not defined via +protected_attribute+.
      #
      # This should be called by #initialize so you shouldn't have to call it
      # yourself. But if you do, user supplied input is ok.
      #
      # NB: This destructively modifies the argument, so dup before you call it.
      #
      # Also note, this overrides the implementation in Base.
      def assign_ivars_from_params!(params)
        # Setting the password and hashed_password+salt at the same time is ambiguous.
        # did you want to overwrite the existing hashed_password+salt or not?
        if params.key?(:password) && (params.key?(:hashed_password) || params.key?(:salt))
          raise InvalidParameters, "cannot set the password and hashed password at the same time"
        end

        if params.key?(:password) || params.key?(PASSWORD)
          self.password = params.delete(:password) || params.delete(PASSWORD)
        end

        self.set_cert_or_key(params)

        params.each do |attr, value|
          if ivar = self.class.model_attributes[attr.to_s]
            instance_variable_set(ivar, params[attr])
          end
        end
      end

      # Set certificate or public key data. The database has a single
      # column "public_key" mapping to certificate here which may
      # container either a certificate or a public key.
      def set_cert_or_key(params)
        key_data = if params.key?(:certificate) || params.key?(CERTIFICATE)
                     params.delete(:certificate) || params.delete(CERTIFICATE)
                   elsif params.key?(:public_key) || params.key?(PUBLIC_KEY)
                     params.delete(:public_key) || params.delete(PUBLIC_KEY)
                   else
                     nil
                   end
        if key_data
          if key_data.index("BEGIN PUBLIC KEY")
            self.public_key = key_data
          elsif key_data.index("BEGIN CERTIFICATE")
            self.certificate = key_data
          end
        end
      end

      # Like a regular attribute setter, except that it forcibly casts the
      # argument to a string first
      def certificate=(new_certificate)
        # if the user *had* a public key, nuke it.
        @public_key = nil
        @certificate = new_certificate.to_s
      end

      def public_key=(key)
        # if user had a certificate, nuke it.
        @certificate = nil
        @public_key = key.to_s
      end

      def hash_strategy
        case hash_type
        when HASH_TYPE_BCRYPT
          BCryptPassword.new(self)
        when HASH_TYPE_SHA1BCRYPT
          SHA1BCryptPassword.new(self)
        when nil
          LegacyPassword.new(self)
        else
          raise 'Unimplemented hash type'
        end
      end

      # This function changes the hash_type to bcrypt and
      # re-encrypts the password, if there is an unhashed password
      def upgrade_password!
        return if using_bcrypt?
        return unless updating_password?
        # Initiate the re-encrypt by changing the hash_type and
        # calling #password= again
        @hash_type = HASH_TYPE_BCRYPT
        self.password = @password
      end

      # Generates a new salt (overwriting the old one, if any) and sets password
      # to the salted digest of +unhashed_password+
      def password=(unhashed_password)
        @password = unhashed_password
        @hashed_password, @salt = hash_strategy.encrypt(unhashed_password)
      end

      # True if +candidate_password+'s hashed form matches the hashed_password,
      # false otherwise.
      def correct_password?(candidate_password)
        hash_strategy.correct_password?(candidate_password)
      end

      # The User's public key. Derived from the certificate if the user has a
      # certificate, or just returns the public key if the user has a public
      # key. Users nowadays are created with certificates but some older users
      # have public keys.
      def public_key
        if @public_key
          @public_key
        elsif certificate
          OpenSSL::X509::Certificate.new(certificate).public_key
        else
          nil
        end
      end

      def external_authentication_enabled?
        Mixlib::Authorization::Config.has_key?(:ldap_host)
      end

      def requires_password?
        !external_authentication_enabled?
      end

      def using_bcrypt?
        hash_type == HASH_TYPE_BCRYPT
      end

      # Is the password being updated? This is always true when creating a new
      # user. Also true when the password field is set on an existing user.
      # Used to trigger validation of the password format.
      def updating_password?
        (!persisted? && requires_password?) || (!password.nil?)
      end

      def to_param
        persisted? ? username : nil
      end

      # Essentially the "natural key" of this object, if it has been persisted.
      # In a rails app, this can be used to generate routes. For example, a
      # Chef node has a URL +nodes/NODE_NAME+
      def to_key
        persisted? ? [username] : nil
      end

      def pretty_print(pp)
        data = for_db
        pp.text("#{self.class.name}: #{data.delete(:username)} (0x#{object_id.to_s(16)})\n")
        pp.text("database id: #{data.delete(:id)}\n")
        pp.text("Authz id: #{data.delete(:authz_id)}\n")
        pp.nest(2) do
          data.each do |attr_name, value|
            pp.text("#{attr_name}: #{value}")
            pp.breakable
          end
        end
      end

      # Adds a validation error if there is no certificate or public key,
      # or else if *both* a certificate *and* a public_key are present (which
      # is ambiguous)
      def certificate_or_pubkey_present
        # must use the @public_key instance var b/c the getter method will
        # return the cert's public key for compat reasons
        if certificate.nil? && @public_key.nil?
          errors.add(:credentials, "must have a certificate or public key")
        elsif certificate && @public_key # should never have BOTH
          errors.add(:credentials, "cannot have both a certificate and public key")
        end
      end

      # Since this model doesn't use the Active Record pattern, it can't talk
      # to the database to determine if an email address is taken or not. This
      # is here for the data access layer to add validation errors for invalid
      # email addrs.
      def email_not_unique!
        errors.add(:conflicts, "email")
        errors.add(:email, "already exists.")
      end

      # Same deal as with email, these objects can't determine if their attrs
      # are globally unique or not, so the data layer calls this when a
      # uniqueness constraint is violated.
      def username_not_unique!
        errors.add(:conflicts, "username")
        errors.add(:username, "is already taken")
      end

      # overrides attr_reader to use custom reader in superclass
      def created_at
        super
      end

      # overrides attr_reader to use custom reader in superclass
      def updated_at
        super
      end

      def to_partial_path
        ""
      end

    end
  end
end

