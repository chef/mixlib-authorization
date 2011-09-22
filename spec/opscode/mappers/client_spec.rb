require File.expand_path('../../spec_helper', __FILE__)

describe Opscode::Mappers::User do
  include Fixtures

  before(:all) do
    require 'logger'
    @db = Sequel.connect("mysql2://root@localhost/opscode_chef_test")
    #@db.logger = Logger.new(STDOUT) # makes the tests loud.
  end

  before do
    @db[:clients].truncate

    @stats_client = TestingStatsClient.new
    @amqp_client = mock("Chef AMQP Client")
    @org_id = "fff000"

    @mapper = Opscode::Mappers::Client.new do |m|
      m.db = @db
      m.amqp = @amqp_client
      m.org_id = @org_id
      m.stats_client = @stats_client
      m.authz_id = "an_authz_id"
    end

    @container_acl = {  "delete" => {"groups"=>[], "actors"=>[]},
                        "read"   => {"groups"=>[], "actors"=>[]},
                        "grant"  => {"groups"=>[], "actors"=>[]},
                        "create" => {"groups"=>[], "actors"=>[]},
                        "update" => {"groups"=>[], "actors"=>[]} }


    @clients_container = mock("ClientsContainer", :fetch_join_acl => @container_acl)
  end

  describe "when there are no clients in the database" do
    it "does not list any clients" do
      @mapper.list.should == []
    end

    it "does not find a client by name" do
      @mapper.find_by_name("derp-validator").should be_nil
    end

    it "does not find a client for authentication" do
      @mapper.find_for_authentication("derp-validator").should be_nil
    end

    it "raises when attempting to create a client with invalid data" do
      client = Opscode::Models::Client.new
      lambda { @mapper.create(client, @clients_container) }.should raise_error(Opscode::Mappers::InvalidRecord)
    end

  end

  describe "when there are clients of other orgs in the database" do
    it "does not list any clients"

    it "does not find a client by name"

    it "does not find a client for authentication"
  end

  describe "after creating a validator client" do
    # NOTE: this should be written as a create_validator method;
    # set the correct authz permissions on the container:
    #   auth_acl_data = container.fetch_join_acl
    #   acl = Mixlib::Authorization::Acl.new(auth_acl_data)
    #   ["create","read"].each do |ace|
    #     container_ace = acl.aces[ace].to_user(org_db)
    #     container_ace.add_actor(clientname)
    #     container.update_join_ace(ace, container_ace.to_auth(org_db).ace)
    #   end
    #

    it "saves the client as a validator"
  end

  describe "after creating a client with the id and authz_id already set" do
    it "includes the client in the list of all clients"

    it "loads the client for authentication"

    it "finds the client by name"

    it "sets timestamps on the client"

    describe "and another client is created" do

      it "lists all clients"

    end

    describe "and updating the client's certificate" do

      it "saves the updated cert"

    end

    describe "and updating the client's name" do
      it "saves the updated client name"
    end

    describe "when trying to create a duplicate client" do
      it "raises an invalid record exception"

      it "marks the model object invalid"
    end
  end

  describe "after creating a client without an id or authz_id" do

    it "generates an id"

    it "generates an authz_id"

    it "updates the ACL with ACEs inherited from the container"

    it "creates a corresponding actor object in authz"

    it "adds the client to the search index"

    it "sets timestamps on the client"

  end

end

