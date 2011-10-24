require File.expand_path('../../spec_helper', __FILE__)
require 'mixlib/authorization/models/join_document'
require 'mixlib/authorization/models/join_types'
require 'mixlib/authorization/acl'


AuthzModels = Mixlib::Authorization::Models

describe Opscode::Mappers::Client do
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
      m.authz_id = "0"
    end

    @container_acl = {  "delete" => {"groups"=>[], "actors"=>[]},
                        "read"   => {"groups"=>[], "actors"=>[]},
                        "grant"  => {"groups"=>[], "actors"=>[]},
                        "create" => {"groups"=>[], "actors"=>[]},
                        "update" => {"groups"=>[], "actors"=>[]} }

    @authz_server = Mixlib::Authorization::Config.authorization_service_uri
    @container_authz_model = AuthzModels::JoinTypes::Container.new(@authz_server,
                                                                   "requester_id" => "0")
    @sentinel_actor_id = "86"

    @container_authz_model.save
    @container_authz_model.grant_permission_to_actor("grant", @sentinel_actor_id)

    @clients_container = mock("ClientsContainer", :authz_object_as => @container_authz_model)
    @clients_container.stub!(:[]).with(:requester_id).and_return("0")
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
    before do
      client = {:id => "222", :org_id => "222", :name => "otherguy",
                :pubkey_version => 1, :public_key => SAMPLE_CERT,
                :validator => false, :last_updated_by => "0",
                :created_at => Time.now, :updated_at => Time.now}
      @db[:clients].insert(client)
    end
    it "does not list any clients" do
      @mapper.list.should == []
    end

    it "does not find a client by name" do
      @mapper.find_by_name("otherguy").should be_nil
    end

  end

  describe "after creating a validator client" do
    before do
      @queue = mock("AMQP Queue")
      @amqp_client.should_receive(:transaction).and_yield
      @amqp_client.should_receive(:queue_for_object).and_yield(@queue)
      @queue.should_receive(:publish)
      @client = Opscode::Models::Client.load(:name => "derp-validator",
                                             :validator => true,
                                             :certificate => SAMPLE_CERT )
      @mapper.create(@client, @clients_container)

    end

    it "saves the client as a validator" do
      client = @mapper.find_by_name("derp-validator")
      client.should be_a_validator
    end

    it "grants the client read and create permissions on the clients container" do
      container_acl = @container_authz_model.fetch_acl
      container_acl["create"]["actors"].should include(@client.authz_id)
      container_acl["read"]["actors"].should include(@client.authz_id)
    end

    it "refuses to delete the last validator in an organization" do
      lambda { @mapper.destroy(@client) }.should raise_error(Opscode::Mappers::Client::CannotDeleteValidator)
    end

    describe "and creating another validator" do
      before do
        @queue = mock("AMQP Queue")
        @amqp_client.should_receive(:transaction).twice.and_yield
        @amqp_client.should_receive(:queue_for_object).twice.and_yield(@queue)
        @queue.should_receive(:publish).twice
        @alt_validator = Opscode::Models::Client.load(:name => "derp-validator-two",
                                               :validator => true,
                                               :certificate => SAMPLE_CERT )
        @mapper.create(@alt_validator, @clients_container)
      end

      it "allows one of the validators to be deleted" do
        @mapper.destroy(@client) #should_not raise_error
      end
    end
  end

  describe "after creating a client with the id and authz_id already set" do
    before do
      @client = Opscode::Models::Client.load(:name => "derp",
                                             :validator => false,
                                             :certificate => SAMPLE_CERT,
                                             :id => '1' * 32,
                                             :authz_id => '2' * 32)

      @queue = mock("AMQP Queue")
      @amqp_client.should_receive(:transaction).and_yield
      @amqp_client.should_receive(:queue_for_object).and_yield(@queue)
      @queue.should_receive(:publish)

      @mapper.create(@client, @clients_container)
    end

    it "includes the client in the list of all clients" do
      @mapper.list.should == %w{derp}
    end

    it "loads the client for authentication" do
      @mapper.find_for_authentication("derp").should == @client
    end

    it "finds the client by name" do
      @mapper.find_by_name("derp").should == @client
    end

    it "sets timestamps on the client" do
      client = @mapper.find_by_name("derp")
      client.created_at.to_i.should be_within(1).of(Time.now.to_i)
      client.updated_at.to_i.should be_within(1).of(Time.now.to_i)
    end

    describe "and another client is created" do
      before do
        @amqp_client.should_receive(:transaction).and_yield
        @amqp_client.should_receive(:queue_for_object).and_yield(@queue)
        @queue.should_receive(:publish)

        @other_client = Opscode::Models::Client.load(:name => "herp",
                                                     :validator => false,
                                                     :certificate => SAMPLE_CERT )
        @mapper.create(@other_client, @clients_container)
      end

      it "lists all clients" do
        @mapper.list.should =~ %w{herp derp}
      end

    end

    describe "and updating the client's certificate" do
      before do
        @amqp_client.should_receive(:transaction).and_yield
        @amqp_client.should_receive(:queue_for_object).and_yield(@queue)
        @queue.should_receive(:publish)

        @client = @mapper.find_by_name("derp")
        @client.certificate = ALTERNATE_CERT
        @mapper.update(@client)
      end

      it "saves the updated cert" do
        client = @mapper.find_by_name("derp")
        client.certificate.to_s.should == ALTERNATE_CERT
      end

    end

    describe "and updating the client's name" do
      before do
        @amqp_client.should_receive(:transaction).and_yield
        @amqp_client.should_receive(:queue_for_object).and_yield(@queue)
        @queue.should_receive(:publish)

        @client = @mapper.find_by_name("derp")
        @client.name = "herpderp"

        @mapper.update(@client)
      end

      it "saves the updated client name" do
        @mapper.find_by_name("derp").should be_nil
        @mapper.find_by_name("herpderp").should == @client
      end
    end

    describe "when trying to create a duplicate client" do
      it "raises an invalid record exception" do
        lambda { @mapper.create(@client, @clients_container) }.should raise_error(Opscode::Mappers::InvalidRecord)
      end

      it "marks the model object invalid" do
        lambda { @mapper.create(@client, @clients_container) }.should raise_error
        @client.errors.should have_key(:name)
      end

    end

    describe "when attempting to rename a client with the name of an existing client" do
      before do
        @amqp_client.should_receive(:transaction).and_yield
        @amqp_client.should_receive(:queue_for_object).and_yield(@queue)
        @queue.should_receive(:publish)

        @other_client = Opscode::Models::Client.load(:name => "herpderp",
                                                     :certificate => SAMPLE_CERT,
                                                     :validator => false)
        @mapper.create(@other_client, @clients_container)
      end

      it "marks the object invalid and raises an error" do
        @client.name = "herpderp"
        lambda { @mapper.update(@client) }.should raise_error(Opscode::Mappers::InvalidRecord)
        @client.errors.should have_key(:name)
      end

    end
  end

  describe "after creating a client without an id or authz_id" do
    before do
      @queue = mock("AMQP Queue")
      @amqp_client.should_receive(:transaction).and_yield
      @amqp_client.should_receive(:queue_for_object).and_yield(@queue)
      @queue.should_receive(:publish)

      @client = Opscode::Models::Client.new(:name => "herpderp")
      @client.certificate = SAMPLE_CERT
      @mapper.create(@client, @clients_container)
    end

    it "generates an id" do
      @client.id.should match(/^[0-9a-f]{32}$/)
      row_data = @db[:clients].filter(:id => @client.id).first
      row_data.should_not be_nil
      row_data[:name].should == "herpderp"
    end

    it "generates an authz_id" do
      @client.authz_id.should match(/^[0-9a-f]{32}$/)
      row_data = @db[:clients].filter(:authz_id => @client.authz_id).first
      row_data.should_not be_nil
      row_data[:name].should == "herpderp"
    end

    it "creates a corresponding actor object in authz" do
      authz_data = @client.authz_object_as("0").fetch
      authz_data["id"].should == @client.authz_id
    end

    it "updates the ACL with ACEs inherited from the container" do
      acl = @client.authz_object_as("0").fetch_acl
      acl["grant"]["actors"].should include(@sentinel_actor_id)
    end

    it "adds the client to the search index" do
      # this is tested by the mocks for amqp_client and queue.
      # leaving this here just to be explicit
    end

    describe "and then destroying it" do
      before do
        @amqp_client.should_receive(:transaction).and_yield
        @amqp_client.should_receive(:queue_for_object).and_yield(@queue)
        @queue.should_receive(:publish)
        @mapper.destroy(@client)
      end

      it "does not find the client in the database" do
        @db[:clients].filter(:id => @client.id).all.should be_empty
      end
    end

  end

end

