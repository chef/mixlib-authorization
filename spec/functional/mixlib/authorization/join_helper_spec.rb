require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

class ExampleModel < Hash

  REQUESTER_ID = "requester_id".freeze
  CLIENTNAME = "clientname".freeze

  def id
    @id ||= UUID.new.generate(:compact)
  end
end

class ExampleActorBasedModel < ExampleModel
  include JoinHelper

  join_type Models::JoinTypes::Actor
  join_properties REQUESTER_ID
end

describe JoinHelper do
  before(:all) do
    server = CouchRest.new("http://localhost:5984")

    begin
      CouchRest.delete("http://localhost:5984/authorization")
    rescue RestClient::ResourceNotFound
      # Attempted to delete non-existent database, that's ok
    end

    begin    
      db = server.database!("authorization")
    rescue RestClient::PreconditionFailed
      db = server.database!("authorization")
    end


    authz_design_docs = Dir[File.expand_path('../../../../../../opscode-authz/features/support/db/*.cdb', __FILE__)]

    Mixlib::Authorization::Log.debug("Attempting to load authz design docs from authz cuke directories")
    Mixlib::Authorization::Log.debug("Found #{authz_design_docs.size} design docs: #{authz_design_docs.join(', ')}")

    authz_design_docs.each do |filename|
      File.open(filename,'r') do |file|
        doc_id = file.readline
        view_def = JSON.parse(file.inject("") { |half_formed_eye, line| half_formed_eye + line.chomp })
        db.save_doc({ '_id' => doc_id, 'views' => view_def })
      end
    end  

    @extended_class = Class.new(Hash)
    @extended_class.send(:include, JoinHelper)
  end

  after(:all) do
    begin
      CouchRest.delete("http://localhost:5984/authorization")
    rescue RestClient::ResourceNotFound
      # Attempted to delete non-existent database, that's ok
    end
  end

  it "adds a join type to the mixed in class" do
    @extended_class.join_type(:AJoinType)
    @extended_class.join_type_for_class.should == :AJoinType
  end

  it "adds join properties to the mixed in class" do
    @extended_class.join_properties(:requester_id)
    @extended_class.new.join_data.should == {"requester_id" => nil}
  end

  describe "when extending an actor model" do
    before do
      @model = ExampleActorBasedModel.new
      @model['requester_id'] = UUID.new.generate(:compact).to_s
    end

    describe "when the model does not have an auth join" do
      it "creates an auth join and an Actor join" do
        join_doc = @model.create_join
        join_doc.should be_a_kind_of(Mixlib::Authorization::AuthJoin)
        join_doc.user_object_id.should == @model.id

        auth_join = @model.fetch_auth_join_for(join_doc)
        auth_join.join_data["object_id"].should == join_doc["auth_object_id"]
      end

      it "raises an authorization error when attempting to update a join" do
        expected_err_str = "ExampleActorBasedModel #{@model.id} does not have an auth join object"
        lambda {@model.update_join}.should raise_error(AuthorizationError, expected_err_str)
      end

      it "does not cause a ruckus when attempting to delete the join object" do
        lambda { @model.delete_join }.should_not raise_error
      end

      it "raises an error that === ArgumentError when attempting to fetch a join" do
        lambda { @model.fetch_join }.should raise_error(ArgumentError, "Cannot find join for ExampleActorBasedModel #{@model.id}")
      end

      it "raises an error that === ArgumentError when attempting to fetch a join ACL" do
        lambda { @model.fetch_join_acl }.should raise_error(ArgumentError, "Cannot find join for ExampleActorBasedModel #{@model.id}")
      end

      it "raises an error that === ArgumentError when attempting to determine if an actor is authorized for an operation" do
        lambda { @model.is_authorized?(:charlie, :read) }.should raise_error(ArgumentError, "Cannot find join for ExampleActorBasedModel #{@model.id}")
      end

      it "raises an errot that === ArgumentError when attempting to update a join ACE" do
        lambda { @model.update_join_ace(:read, {})}.should raise_error(ArgumentError, "Cannot find join for ExampleActorBasedModel #{@model.id}")
      end

    end

    describe "when the model has a join" do
      before do
        @join_doc = @model.create_join
        @auth_join = @model.fetch_auth_join_for(@join_doc)
        @auth_join.join_data["requester_id"].should == @model["requester_id"]
      end

      it "updates an auth join object with updated Auth data" do
        @model['requester_id'] = new_requester_id = UUID.new.generate(:compact).to_s
        @model.update_join
        new_auth_join = @model.fetch_auth_join_for(@join_doc)
        new_auth_join.join_data["requester_id"].should == new_requester_id
      end

      it "deletes a join object but not the actor-type-specific auth join object" do
        @model.delete_join
        AuthJoin.by_user_object_id(:key=>@model.id).should be_empty
        auth_side_data = {"object_id"=>@join_doc[:auth_object_id], "requester_id" => @model["requester_id"]}
        actor_join = Models::JoinTypes::Actor.new(Mixlib::Authorization::Config.authorization_service_uri, auth_side_data).fetch
        actor_join.should == {"id" => @join_doc["auth_object_id"]}
      end

      it "fetches the auth side data" do
        @model.fetch_join.should == {"id" => @join_doc["auth_object_id"] }
      end

      it "fetches a join acl" do
        auth_object = @model.fetch_auth_join_for(@join_doc)
        auth_object.update_ace('read', "actors"=>["signing_caller"], "groups"=>["tdd-ppl"])
        acl = @model.fetch_join_acl
        acl["read"].should == {"actors"=>["signing_caller"], "groups"=>["tdd-ppl"]}
      end

      it "queries the auth object to determine if an actor is authorized for an action" do
        auth_object = @model.fetch_auth_join_for(@join_doc)
        auth_object.update_ace('read', "actors"=>["signing_caller", "mal"], "groups"=>[])
        @model.is_authorized?("mal", "read").should be_true
        @model.is_authorized?("trolls", "read").should be_false
      end

    end

  end
end