require 'spec_helper'

describe Opscode::Models::Client do
  include Fixtures

  before do
    @now = Time.new
    @db_values = {
      :id => "abc123",
      :authz_id => "def456",
      :org_id => "fff000",
      :name => "superderp",
      :created_at => @now.utc.to_s,
      :updated_at => @now.utc.to_s,
      :certificate => SAMPLE_CERT
    }
  end
  #it_should_behave_like("an active model")

  describe "when created without any data" do
    before do
      @client = Opscode::Models::Client.new
    end

    it "has no name" do
      @client.name.should be_nil
    end

    it "has no id" do
      @client.id.should be_nil
    end

    it "has no authz id" do
      @client.authz_id.should be_nil
    end

    it "is not marked as being persisted" do
      @client.should_not be_persisted
    end

    it "has no public key" do
      @client.public_key.should be_nil
    end

    it "is not a validator" do
      @client.should_not be_a_validator
    end

    it "is not valid" do
      @client.should_not be_valid
    end

    it "has an invalid name" do
      @client.valid?
      @client.errors[:name].should include("must not be blank")
    end

    # validates_format :clientname, :with => /\A([a-zA-Z0-9\-_\.])*\z/
    describe "when validating the name field" do
      it "does not accept names with non alphanumeric characters" do
        @client.name = "@$%thisissomeperl"
        @client.should_not be_valid
        @client.errors[:name].should include("has an invalid format")
      end

      it "does not accept an empty string as the name" do
        @client.name = ""
        @client.should_not be_valid
        @client.errors[:name].should include("must not be blank")
      end

      it "accepts names with alphanumeric, underscore and period" do
        @client.name = "FOObar123_."
        @client.should be_valid
      end

    end

    describe "when the name is not unique" do
      before do
        @client.name = "derp"
        @client.name_not_unique!
      end

      it "is invalid" do
        @client.errors[:name].should include("already exists.")
      end

    end

  end

  describe "when created with values from the database" do
    before do
      @client = Opscode::Models::Client.load(@db_values)
    end

    it "has a name" do
      @client.name.should == "superderp"
    end

    it "gives the name via #clientname" do
      @client.clientname.should == "superderp"
    end

    it "has an id" do
      @client.id.should == "abc123"
    end

    it "has an authz id" do
      @client.authz_id.should == "def456"
    end

    it "has an org_id" do
      @client.org_id.should == "fff000"
    end

    it "has a creation timestamp" do
      @client.created_at.to_i.should == @now.to_i
    end

    it "has an update timestamp" do
      @client.updated_at.to_i.should == @now.to_i
    end

    it "has a certificate" do
      @client.certificate.should == SAMPLE_CERT
    end

    it "derives the public key from the cert" do
      @client.public_key.to_s.should == SAMPLE_CERT_KEY
    end

    it "is not a validator" do
      @client.should_not be_a_validator
    end

    describe "with an old-style public key" do
      before do
        @db_values.delete(:certificate)
        @db_values[:public_key] = "ceci n'est pas une RSA key"
        @client = Opscode::Models::Client.load(@db_values)
      end

      it "has no cert" do
        @client.certificate.should be_nil
      end

      it "has a public key" do
        @client.public_key.should == "ceci n'est pas une RSA key"
      end

      it "includes the public key in the db Hash representation" do
        @client.for_db[:public_key].should == "ceci n'est pas une RSA key"
      end
    end
  end

  describe "when created as a validator for an org" do
    before do
      @client = Opscode::Models::Client.new_validator_for_org("derporg")
    end

    it "is named orgname-validator" do
      @client.name.should == "derporg-validator"
    end

    it "is a validator" do
      @client.should be_a_validator
    end
  end

  describe "when created as a validator" do
    before do
      @client = Opscode::Models::Client.new(:name => "secondary-validator")
      @client.validator!
    end

    it "is a validator" do
      @client.should be_a_validator
    end
  end

  describe "after required attributes are set" do
    before do
      @client = Opscode::Models::Client.load(@db_values)
    end

    describe "when converted to a Hash for user-facing purposes" do

      # ApiClient has differences between OSS/platform and possibly client versions.
      # Relevant fields:
      # Chef 0.9-0.10 ApiClient#to_json:
      # * name
      # * public_key
      # * admin
      # * json_class
      # * chef_type
      # JSON creation from Chef gem:
      # * name || clientname
      # * public_key
      # * admin
      # API response from CouchRest based model:
      # * orgname
      # * clientname
      # * name
      # * validator
      # * certificate

      before do
        @client_for_json = @client.for_json
      end

      it "has a name" do
        @client_for_json[:name].should == "superderp"
      end

      it "does not have a clientname field" do
        # 0.9 is the lowest supported version of Chef you can use w/ the
        # platform; use of "name" instead of "clientname" is supported at least
        # since this version.
        # https://github.com/opscode/chef/blob/0.9.0/chef/lib/chef/api_client.rb
        # pychef also does not need a "clientname" field so this should be fine.
        @client_for_json.should_not have_key(:clientname)
      end

    end

    describe "when converted to a Hash for indexing" do
      before do
        @now = Time.now
        Time.stub(:new).and_return(@now)
        @client_for_index = @client.for_index
      end

      it "has a type attribute" do
        @client_for_index[:type].should == 'client'
      end

      it "has an id attribute" do
        @client_for_index[:id].should == 'abc123'
      end

      it "has a database attribute" do
        @client_for_index[:database].should == 'chef_fff000'
      end

      it "has an item attribute containing the client's Hash representation" do
        @client_for_index[:item].should == @client.for_json
      end

      it "has an enqueued_at attribute with the current Unix time" do
        @client_for_index[:enqueued_at].should == @now.to_i
      end
    end

    describe "when converted to a Hash for the mapper layer" do
      before do
        @db_hash = @client.for_db
      end

      it "has an id" do
        @db_hash[:id].should == "abc123"
      end

      it "has an authz id" do
        @db_hash[:authz_id].should == "def456"
      end

      it "has an org id" do
        @db_hash[:org_id].should == "fff000"
      end

      it "has a name" do
        @db_hash[:name].should == "superderp"
      end

      it "has a certificate" do
        @db_hash[:certificate].should == SAMPLE_CERT
      end
    end

    describe "when authorizing a request" do

      it "creates an authorization side object" do
        @client.create_authz_object_as(Mixlib::Authorization::Config.dummy_actor_id)
        @client.authz_id.should_not be_nil
        authz_id = @client.authz_id
        @client.authz_object_as(Mixlib::Authorization::Config.dummy_actor_id).fetch.should == {"id" => authz_id}
      end

      describe "and the authz side has been created" do
        before do
          @client.create_authz_object_as(Mixlib::Authorization::Config.dummy_actor_id)
        end

        it "checks authorization rights" do
          @client.should_not be_authorized(Mixlib::Authorization::Config.other_actor_id1, :update)
          @client.should be_authorized(@client.authz_id, :update)
        end

        it "supports the old interface to authorization checks" do
          @client.should respond_to(:is_authorized?)
        end

        it "updates the authz side object" do
          # This is actually a no-op, because there is no updateable data in the
          # authz side object for a user. But we want to test it anyway.
          expected_id = @client.authz_id
          @client.update_authz_object_as(@client.authz_id)
          @client.authz_object_as(@client.authz_id).fetch.should == {"id" => expected_id}
        end

        # NOTE: the previous implementation did NOT actually destroy the authz
        # side object, so this implementation won't either to keep compat at a
        # maximum. But we may wish to revisit this decision, or invent a true
        # turing machine with infinite tape for storage.
        it "destroys the authz side object by removing the reference to it" do
          authz_id = @client.authz_id
          @client.destroy_authz_object_as(authz_id)
          @client.authz_id.should be_nil
        end

      end

    end
  end

  describe "when created from valid form data" do
    before do
      @form_params = {:name => 'superderp'}
      @client = Opscode::Models::Client.new(@form_params)
    end

    it "has a name" do
      @client.name.should == "superderp"
    end

    it "does not have an organization id" do
      @client.org_id.should be_nil
    end

    it "does not have a cert" do
      @client.certificate.should be_nil
    end

    describe "when an org id is assigned" do
      before do
        @client.assign_org_id!("f00ba4")
      end

      it "has an org_id" do
        @client.org_id.should == "f00ba4"
      end
    end

    describe "when a certificate is assigned" do
      before do
        @client.certificate= SAMPLE_CERT
      end

      it "has a certificate" do
        @client.certificate.should == SAMPLE_CERT
      end
    end
  end

  describe "when created from form params containing params that the user should not set" do
    before do
      @bad_user_input = {:name => "dr.evil", :org_id => "86", :certificate => "AN RSA CERT", :id => "123456"}
      @client = Opscode::Models::Client.new(@bad_user_input)
    end

    it "does not set the protected attributes" do
      @client.org_id.should be_nil
      @client.certificate.should be_nil
      @client.id.should be_nil
    end
  end

end

