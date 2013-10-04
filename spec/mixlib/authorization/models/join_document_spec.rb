require 'spec_helper'

describe Mixlib::Authorization::Models::JoinDocument, :pending => 'broken' do
  def actor
    Mixlib::Authorization::Models::JoinTypes::Actor
  end

  before do
    # Calling this a "join document" is confusing because that usually means
    # metadata associated with the join itself. This class is more like a model
    # backed by web service resources

    @authorization_service_uri = Mixlib::Authorization::Config.authorization_service_uri
    @default_requestor_id = Mixlib::Authorization::Config.superuser_id
  end

  describe "when the actor does not exist" do
    before do
      @authz_model = actor.new(@authorization_service_uri, "requester_id" => @default_requestor_id, "object_id" => "f" * 32)
    end

    it "raises NotFound when loading the authz data" do
      lambda { @authz_model.fetch}.should raise_error(RestClient::ResourceNotFound)
    end

    it "raises NotFound when loading the ACL" do
      lambda { @authz_model.fetch_acl }.should raise_error(RestClient::ResourceNotFound)
    end

  end

  describe "when an actor has been created" do
    before do
      @created_authz_model = actor.new(@authorization_service_uri, "requester_id" => @default_requestor_id)
      @created_authz_model.save
      @authz_model = actor.new(@authorization_service_uri, "requester_id" => @default_requestor_id, "object_id" => @created_authz_model.id)
    end

    it "loads the authz object" do
      # The authz object doesn't actually have interesting data. but whatever
      @authz_model.fetch.should == {"id" => @authz_model.id}
    end

    it "loads the object's ACL" do
      acl_data = @authz_model.fetch_acl

      acl_data["create"].should == {"actors"=>[@authz_model.id, "0"], "groups"=>[]}
      acl_data["read"].should   == {"actors"=>[@authz_model.id, "0"], "groups"=>[]}
      acl_data["update"].should == {"actors"=>[@authz_model.id, "0"], "groups"=>[]}
      acl_data["delete"].should == {"actors"=>[@authz_model.id, "0"], "groups"=>[]}
      acl_data["grant"].should  == {"actors"=>[@authz_model.id, "0"], "groups"=>[]}
    end

    it "authorizes its creator for all operations" do
      %w{create read update delete grant}.each do |ace_type|
        @authz_model.should be_authorized("0", ace_type)
      end
    end

    it "begrudgingly supports checking permissions via #is_authorized?" do
      %w{create read update delete grant}.each do |ace_type|
        @authz_model.is_authorized?("0", ace_type).should be_true
      end
    end

    it "adds an actor to an ACE" do
      @authz_model.grant_permission_to_actor("read", "123abc")
      @authz_model.fetch_acl["read"]["actors"].should include("123abc")
    end

    describe "when applying ACLs from a parent object" do
      before do
        @container = Mixlib::Authorization::Models::JoinTypes::Object.new(@authorization_service_uri, "requester_id" => @default_requestor_id)
        @container.save
        %w{create read update delete grant}.each do |ace_type|
          @container.grant_permission_to_actor(ace_type, "fff000")
        end
        @authz_model.apply_parent_acl(@container)
      end

      it "has inherited permissions from the parent" do
        acl_data = @authz_model.fetch_acl

        acl_data["create"].should == {"actors"=>[@authz_model.id, "0", "fff000"], "groups"=>[]}
        acl_data["read"].should   == {"actors"=>[@authz_model.id, "0", "fff000"], "groups"=>[]}
        acl_data["update"].should == {"actors"=>[@authz_model.id, "0", "fff000"], "groups"=>[]}
        acl_data["delete"].should == {"actors"=>[@authz_model.id, "0", "fff000"], "groups"=>[]}
        acl_data["grant"].should  == {"actors"=>[@authz_model.id, "0", "fff000"], "groups"=>[]}
      end

    end

  end

end
