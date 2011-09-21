
require 'opscode/authorizable'

module Opscode
  module Models

    class InvalidParameters < ArgumentError
    end

    class Base

      include Opscode::Authorizable

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

      # Returns the class object that is used for the authz side representation
      # of this model. If not set, it will raise a NotImplementedError.
      def authz_model_class
        self.class.authz_model_class
      end

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

      # Assigns instance variables from "safe" params, that is ones that are
      # not defined via +protected_attribute+.
      #
      # This should be called by #initialize so you shouldn't have to call it
      # yourself. But if you do, user supplied input is ok.
      #
      # NB: This destructively modifies the argument, so dup before you call it.
      def assign_ivars_from_params!(params)
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

      def to_param
        raise NotImplementedError, "#{self.class} should implement this method"
      end

      # Essentially the "natural key" of this object, if it has been persisted.
      # In a rails app, this can be used to generate routes. For example, a
      # Chef node has a URL +nodes/NODE_NAME+
      def to_key
        raise NotImplementedError, "#{self.class} should implement this method"
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

      # A Hash representation of this object suitable for conversion to JSON
      # for publishing via API. Protected attributes will not be included.
      def for_json
        hash_for_json = {}
        self.class.model_attributes.each do |attr_name, ivar_name|
          value = instance_variable_get(ivar_name)
          hash_for_json[attr_name.to_sym] = value if value
        end
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


    end
  end
end
