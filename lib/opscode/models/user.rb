# encoding: binary
# ^^ is needed for the email address regex to work properly
require 'openssl'
require 'digest/sha2'
require 'active_model'
require 'active_model/validations'

require 'opscode/authorizable'

module Opscode
  module Models
    class User

      include Opscode::Authorizable

      class InvalidParameters < ArgumentError
      end

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
        attr_name = attr_name.to_s
        ivar = "@#{attr_name}".to_sym
        model_attributes[attr_name] = ivar
        model_ivars[ivar] = attr_name
      end

      def self.add_protected_model_attribute(attr_name)
        attr_name = attr_name.to_s
        ivar = "@#{attr_name}".to_sym
        protected_model_attributes[attr_name] = ivar
        protected_ivars[ivar] = attr_name
      end

      def self.model_attributes
        @model_attributes ||= {}
      end

      def self.model_ivars
        @model_ivars ||= {}
      end

      def self.protected_model_attributes
        @protected_model_attributes ||= {}
      end

      def self.protected_ivars
        @protected_ivars ||= {}
      end

      # Defines an attribute that has an attr_accessor and can be set from
      # parameters passed to new(). This attribute will automatically be
      # included in the 'pre-JSON' representation of the object given by
      # #for_json and #for_db
      def self.rw_attribute(attr_name)
        add_model_attribute(attr_name)
        attr_accessor attr_name
      end

      # Defines an attribute that has an attr_reader and can be set from
      # parameters passed to new() This attribute will automatically be
      # included in the 'pre-JSON' representation of the object given by
      # #for_json and #for_db
      def self.ro_attribute(attr_name)
        add_model_attribute(attr_name)
        attr_reader attr_name
      end

      # Defines an attribute that has an attr_reader but CANNOT be set from
      # parameters passed to new()
      #
      # These parameters will not be included in the JSON representation of
      # this object.
      #
      # This is intended for attributes that are set by the Mapper layer, such
      # as created/updated timestamps or anything that end users should not be
      # able to modify directly.
      #
      # This attribute will automatically be included in the Hash
      # representation of the object used by the mapper layer (i.e., the ouput
      # of #for_db )
      #--
      # NB: if you get all GoF about it, this is a _presentation_ concern that
      # should be handled by a presenter object. It's very noble to shave that
      # yak, good luck.
      def self.protected_attribute(attr_name)
        add_protected_model_attribute(attr_name)
        attr_reader attr_name
      end

      # Declares which class should be used for the authz side representation
      # of this model.
      def self.use_authz_model_class(authz_model_class)
        @authz_model_class = authz_model_class
      end

      # Returns the class object that is used for the authz side representation
      # of this model. If not set, it will raise a NotImplementedError.
      def self.authz_model_class
        @authz_model_class or raise NotImplementedError, "#{self.class.name} must declare an authz model class before it can do authz things"
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
      rw_attribute :public_key
      rw_attribute :certificate
      rw_attribute :city
      rw_attribute :country
      rw_attribute :twitter_account
      rw_attribute :image_file_name

      ro_attribute :hashed_password
      ro_attribute :salt

      protected_attribute :id
      protected_attribute :authz_id
      protected_attribute :created_at #custom reader method
      protected_attribute :updated_at #custom reader method
      protected_attribute :last_updated_by

      attr_reader :password # with a custom setter below

      #########################################################################
      # NOTE: the error messages here are customized to match the previous
      # couchrest implementation as much as possible. I find the copy somewhat
      # awkward, but tests and who-knows-what-else expect the messages to have
      # this text, so we'll leave it for now.
      #########################################################################

      validates_presence_of :first_name, :message => "must not be blank"
      validates_presence_of :last_name, :message => "must not be blank"
      validates_presence_of :display_name, :message => "must not be blank"
      validates_presence_of :username, :message => "must not be blank"
      validates_presence_of :email, :message => "must not be blank"

      # We need to get a password when creating; on updates we only need a
      # password when updating the hashed_password
      validates_presence_of :password, :unless => :persisted?

      validates_presence_of :hashed_password
      validates_presence_of :salt

      validates_format_of :username, :with => /^[a-z0-9\-_]+$/, :message => "has an invalid format (valid characters are a-z, 0-9, hyphen and underscore)"
      validates_format_of :email, :with => EmailAddress, :message => "has an invalid format"

      validates_length_of :password, :within => 6..50, :message => 'must be between 6 and 50 characters', :if => :updating_password?
      validates_length_of :username, :within => 1..50

      validate :certificate_or_pubkey_present

      # This is an alternative constructor that will load both "public" and
      # "protected" attributes from the +params+. This should not be called
      # with user input, it's for the mapper layer to create a new object from
      # database data.
      def self.load(params)
        params = params.dup
        model = new
        model.assign_protected_ivars_from_params!(params)
        model.assign_ivars_from_params!(params)
        model
      end

      # Create a User. If +params+ is a hash of attributes, the User will be
      # "inflated" with those values; otherwise the user will be empty.
      def initialize(params=nil)
        params = params.nil? ? {} : params.dup
        assign_ivars_from_params!(params)
        @persisted = false
      end

      PASSWORD = 'password'.freeze
      CERTIFICATE = 'certificate'.freeze

      # Assigns instance variables from "safe" params, that is ones that are
      # not defined via +protected_attribute+.
      #
      # This should be called by #initialize so you shouldn't have to call it
      # yourself. But if you do, user supplied input is ok.
      #
      # NB: This destructively modifies the argument, so dup before you call it.
      def assign_ivars_from_params!(params)
        # Setting the password and hashed_password+salt at the same time is ambiguous.
        # did you want to overwrite the existing hashed_password+salt or not?
        if params.key?(:password) && (params.key?(:hashed_password) || params.key?(:salt))
          raise InvalidParameters, "cannot set the password and hashed password at the same time"
        end

        if params.key?(:password) || params.key?(PASSWORD)
          self.password = params.delete(:password) || params.delete(PASSWORD)
        end

        if params.key?(:certificate) || params.key?(CERTIFICATE)
          self.certificate = params.delete(:certificate) || params.delete(CERTIFICATE)
        end

        params.each do |attr, value|
          if ivar = self.class.model_attributes[attr.to_s]
            instance_variable_set(ivar, params[attr])
          end
        end
      end


      # Updates this User from the given params
      def update_from_params(params)
        assign_ivars_from_params!(params.dup)
      end

      # Sets protected instance variables from the given +params+. This should
      # only be called when loading objects from the database. Definitely do
      # not use this when loading user-supplied parameters.
      #
      # NB: This method destructively modifies the argument. Be sure to dup
      # before you call this if the params don't belong to you.
      def assign_protected_ivars_from_params!(params)
        self.class.protected_model_attributes.each do |attr, ivar|
          if value = (params.delete(attr) || params.delete(attr.to_sym) )
            instance_variable_set(ivar, value)
          end
        end
      end

      CREATED_AT = 'created_at'
      UPDATED_AT = 'updated_at'

      # True if the other object is a User or subclass and all "public" and
      # "protected" attributes are equal. Timestamps are fudged to 1s
      # resolution, since that's what MySQL stores, e.g., if you save a User to
      # the database and then load a copy of it from the database, the two will
      # be equal even though the former will have fractional second resolution
      # on the timestamps.
      def ==(other)
        return false unless other.kind_of?(self.class)
        other_data = other.for_db
        for_db.inject(true) do |matches, (attr_name, value)|
          matches && case attr_name
          when :created_at, :updated_at, CREATED_AT, UPDATED_AT
            send(attr_name).to_i == other.send(attr_name).to_i
          else
            value == other_data[attr_name]
          end
        end
      end

      # Like a regular attribute setter, except that it forcibly casts the
      # argument to a string first
      def certificate=(new_certificate)
        @certificate = new_certificate.to_s
      end

      # Generates a new salt (overwriting the old one, if any) and sets password
      # to the salted digest of +unhashed_password+
      def password=(unhashed_password)
        @password = unhashed_password
        generate_salt!
        @hashed_password = encrypt_password(unhashed_password)
      end

      # Casts created_at to a Time object (if required) and returns it
      def created_at
        if @created_at && @created_at.kind_of?(String)
          @created_at = Time.parse(@created_at)
        else
          @created_at
        end
      end

      # Casts updated_at to a Time object (if required) and returns it
      def updated_at
        if @updated_at && @updated_at.kind_of?(String)
          @updated_at = Time.parse(@updated_at)
        else
          @updated_at
        end
      end

      # True if +candidate_password+'s hashed form matches the hashed_password,
      # false otherwise.
      def correct_password?(candidate_password)
        hashed_candidate_password = encrypt_password(candidate_password)
        (@hashed_password.to_s.hex ^ hashed_candidate_password.hex) == 0
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

      # Sets the updated_at and created_at (if necessary) timestamps.
      def update_timestamps!
        now = Time.now.utc
        @created_at ||= now
        @updated_at = now
      end

      # Sets the last_updated_by attribute to +authz_updating_actor_id+,
      # which should be the authz side id of the user/client making changes.
      #
      # NB: the last_updated_by is for diagnostic/troubleshooting use. Plz to
      # not abuse its existence.
      def last_updated_by!(authz_updating_actor_id)
        @last_updated_by = authz_updating_actor_id
      end

      # Sets the database id of this object. Only meant to be used by the
      # mapper layer when/if it generates an id for you.
      def assign_id!(id)
        @id = id
      end

      # Sets the authz side id of this object. Only meant to be used when
      # creating this object in the database and authz.
      def assign_authz_id!(new_authz_id)
        @authz_id = new_authz_id
      end

      # Whether or not this object has been stored to/loaded from the database.
      # In a rails form, this is used to determine whether the operation is a
      # create or update so that the same form view can be used for both
      # operations.
      def persisted?
        @persisted
      end

      # Marks this object as persisted. Should only be called by the mapper layer.
      def persisted!
        @persisted = true
      end

      # Is the password being updated? This is always true when creating a new
      # user. Also true when the password field is set on an existing user.
      # Used to trigger validation of the password format.
      def updating_password?
        (!persisted?) || (!password.nil?)
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

      # The debugging optimized representation of this object. All public and
      # "protected" attributes are included, which means things like passwords
      # can be disclosed. So don't use this in a way that will be logged in
      # production.
      def inspect
        as_str = "#<#{self.class}:#{self.object_id.to_s(16)}"
        self.class.model_attributes.merge(self.class.protected_model_attributes).each do |attr_name, ivar_name|
          as_str << " #{attr_name}=#{instance_variable_get(ivar_name).inspect}"
        end
        as_str << ">"
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

      # A Hash representation of this object suitable for conversion to JSON
      # for publishing via API. Protected attributes will not be included.
      def for_json
        hash_for_json = {}
        self.class.model_attributes.each do |attr_name, ivar_name|
          value = instance_variable_get(ivar_name)
          hash_for_json[attr_name.to_sym] = value if value
        end
        hash_for_json[:password] = hash_for_json.delete(:hashed_password)
        hash_for_json
      end

      # A Hash representation of this object suitable for persistence to the
      # database.  Protected attributes will be included so don't send this to
      # end users.
      def for_db
        hash_for_db = {}

        self.class.model_attributes.each do |attr_name, ivar_name|
          if value = instance_variable_get(ivar_name)
            hash_for_db[attr_name.to_sym] = value
          end
        end

        self.class.protected_model_attributes.each do |attr_name, ivar_name|
          if value = instance_variable_get(ivar_name)
            hash_for_db[attr_name.to_sym] = value
          end
        end

        hash_for_db
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

