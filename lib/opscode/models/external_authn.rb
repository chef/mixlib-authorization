require 'active_model'
require 'active_model/validations'

require 'opscode/models/base'

module Opscode
  module Models

    class ExternalAuthn < Base
      include ActiveModel::Validations

      # inspired by: https://github.com/intridea/omniauth/wiki/Auth-Hash-Schema

      protected_attribute :id
      # foreign key to a local user record
      protected_attribute :user_id
      # An identifier unique to the given provider, such as an LDAP uid
      protected_attribute :external_user_id

      # The external authentication provider type, for now
      # there is only one type :ldap
      protected_attribute :provider

      protected_attribute :created_at #custom reader method
      protected_attribute :updated_at #custom reader method
      protected_attribute :last_updated_by

      validates_presence_of :external_user_id
      validates_inclusion_of :provider, :in => [ "LDAP" ], :allow_blank => false

      # Since this model doesn't use the Active Record pattern, it can't talk
      # to the database to determine if an external user id is taken or not. This
      # is here for the data access layer to add validation errors for invalid
      # external user ids.
      def external_user_id_not_unique!
        errors.add(:conflicts, "external user id")
        errors.add(:external_user_id, "is already taken")
      end

      # overrides attr_reader to use custom reader in superclass
      def created_at
        super
      end

      # overrides attr_reader to use custom reader in superclass
      def updated_at
        super
      end
    end
  end
end
