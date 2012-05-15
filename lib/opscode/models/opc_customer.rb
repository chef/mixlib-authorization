require 'active_model'
require 'active_model/validations'

require 'opscode/models/base'

module Opscode
  module Models
    class OpcCustomer < Base
      include ActiveModel::Validations

      protected_attribute :id
      protected_attribute :name
      protected_attribute :domain
      protected_attribute :priority

      rw_attribute :display_name
      rw_attribute :contact

      protected_attribute :created_at #custom reader method
      protected_attribute :updated_at #custom reader method

      validates_presence_of :name, :message => "must not be blank"
      validates_format_of   :name, :with => /\A([a-zA-Z0-9\-_\.])*\z/, :message => "has an invalid format"

      # overrides attr_reader to use custom reader in superclass
      def created_at
        super
      end

      # overrides attr_reader to use custom reader in superclass
      def updated_at
        super
      end

      def initialize(*args)
        @priority = 0
        super
      end

      def to_key
        persisted? ? [name] : nil
      end

    end
  end
end
