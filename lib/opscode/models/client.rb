require 'active_model'
require 'active_model/validations'

require 'opscode/models/base'

module Opscode
  module Models
    class Client < Base
      include ActiveModel::Validations

      use_authz_model_class(Opscode::AuthzModels::Actor)

      INDEX_TYPE = 'client'.freeze

      rw_attribute :name
      alias :clientname :name # backcompat w/ derpdb code

      protected_attribute :id
      protected_attribute :authz_id
      protected_attribute :org_id
      protected_attribute :public_key # custom getter below
      protected_attribute :certificate
      protected_attribute :validator

      protected_attribute :created_at #custom reader method
      protected_attribute :updated_at #custom reader method

      # This will be necessary to generate URLs from the client objects if we wish to do that...
      #protected_attribute :orgname

      # Setter for org_id. This is a protected attribute so we don't
      # accidentally allow users to change the org_id of a client.
      def assign_org_id!(new_org_id)
        @org_id = new_org_id
      end

      # overrides attr_reader to use custom reader in superclass
      def created_at
        super
      end

      # overrides attr_reader to use custom reader in superclass
      def updated_at
        super
      end

      def validator?
        false
      end

      # Like a regular attribute setter, except that it forcibly casts the
      # argument to a string first. Note that this attribute is protected which
      # prevents users from providing their own certs.
      def certificate=(new_certificate)
        # if the user *had* a public key, nuke it.
        @public_key = nil
        @certificate = new_certificate.to_s
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

      # Converts the Client to a Hash in the correct format to be passed to
      # opscode-expander.
      def for_index
        with_metadata = {}

        with_metadata[:type]        = INDEX_TYPE
        with_metadata[:id]          = id
        # This is used to constrain queries to a single org and cannot be removed ever:
        with_metadata[:database]    = "chef_#{org_id}"
        with_metadata[:item]        = for_json
        with_metadata[:enqueued_at] = Time.now.to_i

        if (with_metadata[:id].nil? or with_metadata[:type].nil?)
          raise ArgumentError, "Type, Id, or Database missing in index operation: #{with_metadata.inspect}" 
        end

        with_metadata
      end

    end
  end
end

