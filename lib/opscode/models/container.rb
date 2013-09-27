# encoding: binary
# ^^ is needed for the email address regex to work properly
require 'openssl'
require 'digest/sha2'
require 'active_model'
require 'active_model/validations'

require 'opscode/models/base'

module Opscode
  module Models
    class InvalidParameters < ArgumentError
    end

    class Container < Base
      include ActiveModel::Validations

      use_authz_model_class(Opscode::AuthzModels::Container)

      # not sure if this should be a ro_attribute or a protected_attribute; renames aren't allowed
      ro_attribute :name
      alias :containername :name

      protected_attribute :id
      protected_attribute :authz_id
      protected_attribute :org_id

      rw_attribute :last_updated_by
      alias :requester_id :last_updated_by

      protected_attribute :created_at #custom reader method
      protected_attribute :updated_at #custom reader method

      validates_presence_of :name, :message => "must not be blank"
      validates_format_of   :name, :with => /\A([a-zA-Z0-9\-_\.])*\z/, :message => "has an invalid format"



      # Returns the class object that is used for the authz side representation
      # of this model. If not set, it will raise a NotImplementedError.
      def authz_model_class
        self.class.authz_model_class
      end

      def join_type
        Mixlib::Authorization::Models::JoinTypes::Container.new(Mixlib::Authorization::Config.authorization_service_uri,
                                                                "requester_id" => last_updated_by,
                                                                "object_id" => authz_id)
      end


      def fetch_join_acl
        # may be mixing concerns here, since the other authz stuff
        # happens in the mapper...
        join_type.fetch_acl
      end

      def update_join_ace(type, data)
        join_type.update_ace(type,data)
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
        params.each do |attr, value|
          if ivar = self.class.model_attributes[attr.to_s]
            instance_variable_set(ivar, params[attr])
          end
        end
      end

      # Setter for org_id. This is a protected attribute so we don't
      # accidentally allow users to change the org_id of a client.
      def assign_org_id!(new_org_id)
        @org_id = new_org_id
      end

      # These objects can't determine if their attrs
      # are globally unique or not, so the data layer calls this when a
      # uniqueness constraint is violated.
      def name_not_unique!
        errors.add(:conflicts, "name")
        errors.add(:name, "already exists.")
      end


      # overrides attr_reader to use custom reader in superclass
      def created_at
        super
      end

      # overrides attr_reader to use custom reader in superclass
      def updated_at
        super
      end

      # A Hash representation of this object suitable for conversion to JSON
      # for publishing via API. Protected attributes will not be included.
      def for_json
        hash_for_json = {
          "containername"=>name,
          "containerpath"=>name
        }
      end


    end
  end
end
