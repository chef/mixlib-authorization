require File.expand_path('../../spec_helper', __FILE__)

describe Opscode::Models::Container do
  include Fixtures

  before do
    @now = Time.new
    @db_values = {
      :id => "abc123",
      :authz_id => Mixlib::Authorization::Config.dummy_actor_id,
      :org_id => "fff000",
      :name => "takeout",
      :created_at => @now.utc.to_s,
      :updated_at => @now.utc.to_s
    }
  end
  #it_should_behave_like("an active model")

  describe "when created without any data" do
    before do
      @container = Opscode::Models::Container.new
    end

    it "has no name" do
      @container.name.should be_nil
    end

    it "has no id" do
      @container.id.should be_nil
    end

    it "has no authz id" do
      @container.authz_id.should be_nil
    end

    it "is not marked as being persisted" do
      @container.should_not be_persisted
    end

    it "is not valid" do
      @container.should_not be_valid
    end

    it "has an invalid name" do
      @container.valid?
      @container.errors[:name].should include("must not be blank")
    end

    # validates_format :name, :with => /\A([a-zA-Z0-9\-_\.])*\z/
    describe "when validating the name field" do
      it "does not accept names with non alphanumeric characters" do
        @container = Opscode::Models::Container.new(:name => "@$%thisissomeperl")
        @container.should_not be_valid
        @container.errors[:name].should include("has an invalid format")
      end

      it "does not accept an empty string as the name" do
        @container = Opscode::Models::Container.new(:name => "")
        @container.should_not be_valid
        @container.errors[:name].should include("must not be blank")
      end

      it "accepts names with alphanumeric, underscore and period" do
        @container = Opscode::Models::Container.new(:name => "FOObar123_.")
        @container.should be_valid
      end

    end

    describe "when the name is not unique" do
      before do
        @container = Opscode::Models::Container.new(:name => "derp")
        @container.name_not_unique!
      end

      it "is invalid" do
        @container.errors[:name].should include("already exists.")
      end

    end

  end

  describe "when created with values from the database" do
    before do
      @container = Opscode::Models::Container.load(@db_values)
    end

    it "has a name" do
      @container.name.should == "takeout"
    end

    it "gives the name via #containername" do
      @container.containername.should == "takeout"
    end

    it "has an id" do
      @container.id.should == "abc123"
    end

    it "has an authz id" do
      @container.authz_id.should == Mixlib::Authorization::Config.dummy_actor_id
    end

    it "has an org_id" do
      @container.org_id.should == "fff000"
    end

    it "has a creation timestamp" do
      @container.created_at.to_i.should == @now.to_i
    end

    it "has an update timestamp" do
      @container.updated_at.to_i.should == @now.to_i
    end

  end

  describe "after required attributes are set" do
    before do
      @container = Opscode::Models::Container.load(@db_values)
    end

    describe "when converted to a Hash for user-facing purposes" do

      before do
        @container_for_json = @container.for_json
      end

      it "has a name" do
        @container_for_json["containername"].should == "takeout"
      end

    end

    describe "when converted to a Hash for the mapper layer" do
      before do
        @db_hash = @container.for_db
      end

      it "has an id" do
        @db_hash[:id].should == "abc123"
      end

      it "has an authz id" do
        @db_hash[:authz_id].should == Mixlib::Authorization::Config.dummy_actor_id
      end

      it "has an org id" do
        @db_hash[:org_id].should == "fff000"
      end

      it "has a name" do
        @db_hash[:name].should == "takeout"
      end
    end

    describe "when authorizing a request" do

      it "creates an authorization side object" do
        @container.create_authz_object_as(Mixlib::Authorization::Config.dummy_actor_id)
        @container.authz_id.should_not be_nil
        authz_id = @container.authz_id
        @container.authz_object_as(Mixlib::Authorization::Config.dummy_actor_id).fetch.should == {"id" => authz_id}
      end

      describe "and the authz side has been created" do
        before do
          @container.create_authz_object_as(Mixlib::Authorization::Config.dummy_actor_id)
        end

        it "checks authorization rights" do
          @container.should_not be_authorized(Mixlib::Authorization::Config.other_actor_id1, :update)
          @container.should be_authorized(Mixlib::Authorization::Config.dummy_actor_id, :update)
        end

        it "supports the old interface to authorization checks" do
          @container.should respond_to(:is_authorized?)
        end

        it "updates the authz side object" do
          # This is actually a no-op, because there is no updateable data in the
          # authz side object for a user. But we want to test it anyway.
          expected_id = @container.authz_id
          @container.update_authz_object_as(@container.authz_id)
          @container.authz_object_as(Mixlib::Authorization::Config.dummy_actor_id).fetch.should == {"id" => expected_id}
        end

        # NOTE: the previous implementation did NOT actually destroy the authz
        # side object, so this implementation won't either to keep compat at a
        # maximum. But we may wish to revisit this decision, or invent a true
        # turing machine with infinite tape for storage.
        it "destroys the authz side object by removing the reference to it" do
          authz_id = @container.authz_id
          @container.destroy_authz_object_as(authz_id)
          @container.authz_id.should be_nil
        end

      end

    end
  end

  describe "when created from valid form data" do
    before do
      @form_params = {:name => 'superderp'}
      @container = Opscode::Models::Container.new(@form_params)
    end

    it "has a name" do
      @container.name.should == "superderp"
    end

    it "does not have an organization id" do
      @container.org_id.should be_nil
    end

    describe "when an org id is assigned" do
      before do
        @container.assign_org_id!("f00ba4")
      end

      it "has an org_id" do
        @container.org_id.should == "f00ba4"
      end
    end

  end

end

