require 'spec_helper'
require 'mixlib/authorization/models/join_document'
require 'mixlib/authorization/models/join_types'
require 'mixlib/authorization/acl'


AuthzModels = Mixlib::Authorization::Models

describe Opscode::Mappers::Container do
  include Fixtures

  before(:all) do
    require 'logger'
    @db = Sequel.connect(Opscode::Mappers.connection_string)
    #@db.logger = Logger.new(STDOUT) # makes the tests loud.
  end

  before do
    @db.run("TRUNCATE TABLE containers CASCADE;")

    @stats_client = TestingStatsClient.new
    @org_id = "fff00000000000000000000000000000"

    @mapper = Opscode::Mappers::Container.new do |m|
      m.db = @db
      m.org_id = @org_id
      m.stats_client = @stats_client
      m.authz_id = Mixlib::Authorization::Config.dummy_actor_id
    end

    @container_acl = {  "delete" => {"groups"=>[], "actors"=>[]},
                        "read"   => {"groups"=>[], "actors"=>[]},
                        "grant"  => {"groups"=>[], "actors"=>[]},
                        "create" => {"groups"=>[], "actors"=>[]},
                        "update" => {"groups"=>[], "actors"=>[]} }

    @authz_server = Mixlib::Authorization::Config.authorization_service_uri
    @container_authz_model = AuthzModels::JoinTypes::Container.new(@authz_server,
                                                                   "requester_id" => Mixlib::Authorization::Config.dummy_actor_id)
    @sentinel_actor_id = Mixlib::Authorization::Config.other_actor_id1

    @container_authz_model.save
#    @container_authz_model.grant_permission_to_actor("grant", @sentinel_actor_id)

  end

  describe "when there are no containers in the database" do
    it "does not list any containers" do
      @mapper.list.should == []
    end

    it "does not find a container by name" do
      @mapper.find_by_name("derp-derp").should be_nil
    end

    it "does not find a container for authentication" do
      @mapper.find_for_authentication("derp-derp").should be_nil
    end

    it "raises when attempting to create a container with invalid data" do
      container = Opscode::Models::Container.new
      lambda { @mapper.create(container) }.should raise_error(Opscode::Mappers::InvalidRecord)
    end

  end

  describe "when there are containers of other orgs in the database" do
    before do
      container = {:id => "2".ljust(35, "2"), :org_id => "2".ljust(32, "2"), :name => "otherguy",
                :authz_id => "2".ljust(32, "2"),
                :last_updated_by => "0".ljust(32, "0"), :created_at => Time.now,
                :updated_at => Time.now}

      @db[:containers].insert(container)
    end
    it "does not list any containers" do
      @mapper.list.should == []
    end

    it "does not find a container by name" do
      @mapper.find_by_name("otherguy").should be_nil
    end

  end

  describe "after creating a container with the id and authz_id already set" do
    before do
      @container = Opscode::Models::Container.load(:name => "derp",
                                                :id => '1' * 36,
                                                :authz_id => '2' * 32)

      @mapper.create(@container)
    end

    it "includes the container in the list of all containers" do
      @mapper.list.should == %w{derp}
    end

    it "loads the container for authentication" do
      @mapper.find_for_authentication("derp").should == @container
    end

    it "finds the container by name" do
      @mapper.find_by_name("derp").should == @container
    end

    it "sets timestamps on the container" do
      container = @mapper.find_by_name("derp")
      container.created_at.to_i.should be_within(1).of(Time.now.to_i)
      container.updated_at.to_i.should be_within(1).of(Time.now.to_i)
    end

    describe "and another container is created" do
      before do
        @other_container = Opscode::Models::Container.load(:name => "herp")
        @mapper.create(@other_container)
      end

      it "lists all containers" do
        @mapper.list.should =~ %w{herp derp}
      end

    end

    describe "when trying to create a duplicate container" do
      it "raises an invalid record exception" do
        lambda { @mapper.create(@container) }.should raise_error(Opscode::Mappers::InvalidRecord)
      end

      it "marks the model object invalid" do
        lambda { @mapper.create(@container) }.should raise_error
        @container.errors.should have_key(:name)
      end

    end

    describe "when attempting to rename a container with the name of an existing container" do
      before do
        @other_container = Opscode::Models::Container.load(:name => "herpderp")
        @mapper.create(@other_container)
      end

      it "marks the object invalid and raises an error" do
        @container = Opscode::Models::Container.load(:name => "herpderp",
                                                     :id => '7' * 36,
                                                     :authz_id => '2' * 32)
        lambda { @mapper.update(@container) }.should raise_error(Opscode::Mappers::InvalidRecord)
        @container.errors.should have_key(:name)
      end

    end
  end

  describe "after creating a container without an id or authz_id" do
    before do
      @container = Opscode::Models::Container.new(:name => "herpderp")
      @mapper.create(@container)
    end

    it "generates an id" do
      @container.id.should match(/^[0-9a-f]{32}$/)
      row_data = @db[:containers].filter(:id => @container.id).first
      row_data.should_not be_nil
      row_data[:name].should == "herpderp"
    end

    it "generates an authz_id" do
      @container.authz_id.should match(/^[0-9a-f]{32}$/)
      row_data = @db[:containers].filter(:authz_id => @container.authz_id).first
      row_data.should_not be_nil
      row_data[:name].should == "herpderp"
    end

    it "creates a corresponding container object in authz" do
      authz_data = @container.authz_object_as(Mixlib::Authorization::Config.dummy_actor_id).fetch
      authz_data["id"].should == @container.authz_id
    end

    it "updates the ACL with ACEs inherited from the container" do
      acl = @container.authz_object_as(Mixlib::Authorization::Config.dummy_actor_id).fetch_acl
      acl["grant"]["actors"].should include(Mixlib::Authorization::Config.dummy_actor_id)
    end

    describe "and then destroying it" do
      before do
        @mapper.destroy(@container)
      end

      it "does not find the container in the database" do
        @db[:containers].filter(:id => @container.id).all.should be_empty
      end
    end

  end

end

