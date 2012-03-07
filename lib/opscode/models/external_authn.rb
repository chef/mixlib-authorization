require 'active_model'
require 'active_model/validations'

require 'opscode/models/base'
require 'opscode/models/user'

module Opscode
  module Models

    class ExternalAuthn < Base
      include ActiveModel::Validations

      # inspired by: https://github.com/intridea/omniauth/wiki/Auth-Hash-Schema

      protected_attribute :id
      # An identifier unique to the given provider, such as an LDAP uid
      protected_attribute :external_user_id

      # The external authentication provider type, for now
      # there is only one type :ldap
      protected_attribute :provider

      # The associated User object
      # many_to_one :user, :class => :User

      protected_attribute :created_at #custom reader method
      protected_attribute :updated_at #custom reader method
      protected_attribute :last_updated_by
    end
  end
end
