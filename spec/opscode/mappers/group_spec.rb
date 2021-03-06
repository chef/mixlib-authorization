require File.expand_path('../../spec_helper', __FILE__)
require 'mixlib/authorization/models/join_document'
require 'mixlib/authorization/models/join_types'
require 'mixlib/authorization/acl'


AuthzModels = Mixlib::Authorization::Models

describe Opscode::Mappers::Group do
  include Fixtures

  before(:all) do
    require 'logger'
    @db = Sequel.connect(Opscode::Mappers.connection_string)
    #@db.logger = Logger.new(STDOUT) # makes the tests loud.
  end

  before do
    @db.run("TRUNCATE TABLE groups CASCADE;")

    @stats_client = TestingStatsClient.new
    @org_id = "fff00000000000000000000000000000"

    @mapper = Opscode::Mappers::Group.new do |m|
      m.db = @db
      m.org_id = @org_id
      m.stats_client = @stats_client
      m.authz_id = Mixlib::Authorization::Config.dummy_actor_id
    end

    @group_acl = {  "delete" => {"groups"=>[], "actors"=>[]},
                        "read"   => {"groups"=>[], "actors"=>[]},
                        "grant"  => {"groups"=>[], "actors"=>[]},
                        "create" => {"groups"=>[], "actors"=>[]},
                        "update" => {"groups"=>[], "actors"=>[]} }

    @authz_server = Mixlib::Authorization::Config.authorization_service_uri
    @group_authz_model = AuthzModels::JoinTypes::Group.new(@authz_server,
                                                                   "requester_id" => Mixlib::Authorization::Config.dummy_actor_id)
    @sentinel_actor_id = Mixlib::Authorization::Config.other_actor_id1

    @group_authz_model.save
#    @group_authz_model.grant_permission_to_actor("grant", @sentinel_actor_id)

  end

  describe "when there are no groups in the database" do
    it "does not list any groups" do
      @mapper.list.should == []
    end

    it "does not find a group by name" do
      @mapper.find_by_name("derp-derp").should be_nil
    end

    it "does not find a group for authentication" do
      @mapper.find_for_authentication("derp-derp").should be_nil
    end

    it "raises when attempting to create a group with invalid data" do
      group = Opscode::Models::Group.new
      lambda { @mapper.create(group) }.should raise_error(Opscode::Mappers::InvalidRecord)
    end

  end

  describe "when there are groups of other orgs in the database" do
    before do
      group = {:id => "2".ljust(35, "2"), :org_id => "2".ljust(32, "2"), :name => "otherguy",
                :authz_id => "2".ljust(32, "2"),
                :last_updated_by => "0".ljust(32, "0"), :created_at => Time.now,
                :updated_at => Time.now}

      @db[:groups].insert(group)
    end
    it "does not list any groups" do
      @mapper.list.should == []
    end

    it "does not find a group by name" do
      @mapper.find_by_name("otherguy").should be_nil
    end

  end

  describe "after creating a group with the id and authz_id already set" do
    before do
      @group = Opscode::Models::Group.load(:name => "derp",
                                                :id => '1' * 36,
                                                :authz_id => '2' * 32)

      @mapper.create(@group)
    end

    it "includes the group in the list of all groups" do
      @mapper.list.should == %w{derp}
    end

    it "loads the group for authentication" do
      @mapper.find_for_authentication("derp").should == @group
    end

    it "finds the group by name" do
      @mapper.find_by_name("derp").should == @group
    end

    it "sets timestamps on the group" do
      group = @mapper.find_by_name("derp")
      group.created_at.to_i.should be_within(1).of(Time.now.to_i)
      group.updated_at.to_i.should be_within(1).of(Time.now.to_i)
    end

    describe "and another group is created" do
      before do
        @other_group = Opscode::Models::Group.load(:name => "herp")
        @mapper.create(@other_group)
      end

      it "lists all groups" do
        @mapper.list.should =~ %w{herp derp}
      end

    end

    describe "when trying to create a duplicate group" do
      it "raises an invalid record exception" do
        lambda { @mapper.create(@group) }.should raise_error(Opscode::Mappers::InvalidRecord)
      end

      it "marks the model object invalid" do
        lambda { @mapper.create(@group) }.should raise_error
        @group.errors.should have_key(:name)
      end

    end

    describe "when attempting to rename a group with the name of an existing group" do
      before do
        @other_group = Opscode::Models::Group.load(:name => "herpderp")
        @mapper.create(@other_group)
      end

      it "marks the object invalid and raises an error" do
        @group = Opscode::Models::Group.load(:name => "herpderp",
                                                     :id => '7' * 36,
                                                     :authz_id => '2' * 32)
        lambda { @mapper.update(@group) }.should raise_error(Opscode::Mappers::InvalidRecord)
        @group.errors.should have_key(:name)
      end

    end
  end

  describe "after creating a group without an id or authz_id" do
    before do
      @group = Opscode::Models::Group.new(:name => "herpderp")
      @mapper.create(@group)
    end

    it "generates an id" do
      @group.id.should match(/^[0-9a-f]{32}$/)
      row_data = @db[:groups].filter(:id => @group.id).first
      row_data.should_not be_nil
      row_data[:name].should == "herpderp"
    end

    it "generates an authz_id" do
      @group.authz_id.should match(/^[0-9a-f]{32}$/)
      row_data = @db[:groups].filter(:authz_id => @group.authz_id).first
      row_data.should_not be_nil
      row_data[:name].should == "herpderp"
    end

    it "creates a corresponding group object in authz" do
      authz_data = @group.authz_object_as(Mixlib::Authorization::Config.dummy_actor_id).fetch
      authz_data["id"].should == @group.authz_id
    end

    it "updates the ACL with ACEs inherited from the group" do
      acl = @group.authz_object_as(Mixlib::Authorization::Config.dummy_actor_id).fetch_acl
      acl["grant"]["actors"].should include(Mixlib::Authorization::Config.dummy_actor_id)
    end

    describe "and then destroying it" do
      before do
        @mapper.destroy(@group)
      end

      it "does not find the group in the database" do
        @db[:groups].filter(:id => @group.id).all.should be_empty
      end
    end

  end

end

