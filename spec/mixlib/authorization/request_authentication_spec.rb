require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

Struct.new("MockAuthModelsUser", :id, :username, :public_key)
Struct.new("MockAuthModelsClient", :id, :clientname, :public_key, :validator)
class Struct::MockAuthModelsClient
  def validator?
    validator
  end
end
Struct.new("MockAuthModelsActor", :auth_object_id)
Struct.new("MockMerbReqest", :env)

describe RequestAuthentication do
  before(:all) do
    @user_class     = Struct::MockAuthModelsUser
    @client_class   = Struct::MockAuthModelsClient
    @actor_class    = Struct::MockAuthModelsActor
    @request_class  = Struct::MockMerbReqest
  end
  
  before do
    @req = @request_class.new
  end
  
  describe "when authenticating a request from a user" do
    before do
      @req.env = {"HTTP_X-OPS-USERID" => "MCChris"}
      @mc_chris_auth_object = @actor_class.new("mc_chris_auth_object_id")
      @mc_chris = @user_class.new("mc_chris_user_id", "MC Chris' Username", "mc_chris_public_key")
      @params = {}
      
      Mixlib::Authorization::Models::User.stub!(:find).with("MCChris").and_return(@mc_chris)
      RequestAuthentication.stub!(:user_to_actor).with("mc_chris_user_id").and_return(@mc_chris_auth_object)
      
      OpenSSL::PKey::RSA.stub!(:new).with("mc_chris_public_key").and_return(:mc_chris_pub_key_rsaified)
    end
    
    it "fails if the user is not valid, i.e. can't be found in the database" do
      Mixlib::Authorization::Models::User.stub!(:find).with("MCChris").and_raise(ArgumentError)
      lambda {RequestAuthentication.authenticate_every(@req, @params)}.should raise_error(AuthorizationError)
    end
    
    it "fails if the user is valid but authenticator returns a falsey value for :authenticate_user_request" do
      RequestAuthentication.authenticator.should_receive(:authenticate_user_request).with(@req, :mc_chris_pub_key_rsaified).and_return(nil)
      lambda {RequestAuthentication.authenticate_every(@req, @params)}.should raise_error(AuthorizationError)
    end

    it "succeeds when the user is valid and the request signature can be verified with the user's public key" do
      RequestAuthentication.authenticator.should_receive(:authenticate_user_request).with(@req, :mc_chris_pub_key_rsaified).and_return(:a_successful_auth)
      RequestAuthentication.authenticate_every(@req, @params).should == :a_successful_auth
    end
    
    it "sets the requesting actor's id in the params in a successful request" do
      RequestAuthentication.authenticator.should_receive(:authenticate_user_request).with(@req, :mc_chris_pub_key_rsaified).and_return(:a_successful_auth)
      RequestAuthentication.authenticate_every(@req, @params)
      @params[:requesting_actor_id].should == "mc_chris_auth_object_id"
    end
  end
  
  describe "when authenticating a request from an api client" do
    before do
      @req.env = {"HTTP_X-OPS-USERID" => "a_knife_client"}
      @knife_client_auth_obj = @actor_class.new("knife_client_actor_id")
      @knife_client = @client_class.new("knife_client_id", "knife_client_name", "knife_client_public_key")
      @params = {:organization_id => "the_pushers_union"}
      
      Mixlib::Authorization::Models::User.stub!(:find).and_raise(ArgumentError)
      RequestAuthentication.stub!(:database_from_orgname).and_return(:the_pushers_database)
      @the_pushers_couchdb = mock("the-orgdb-for-the-pushers-union")
      @the_pushers_couchdb.stub!(:by_clientname).with(:key => "a_knife_client").and_return([@knife_client])
      Mixlib::Authorization::Models::Client.stub!(:on).with(:the_pushers_database).and_return(@the_pushers_couchdb)
      RequestAuthentication.stub!(:user_to_actor).with("knife_client_id").and_return(@knife_client_auth_obj)
      
      OpenSSL::PKey::RSA.stub!(:new).with("knife_client_public_key").and_return(:knife_client_pub_key_rsaified)
    end
    
    
    it "succeeds when the client is valid and the request signature can be verified with the client's public key" do
      RequestAuthentication.authenticator.should_receive(:authenticate_user_request).with(@req, :knife_client_pub_key_rsaified).and_return(:a_successful_auth)
      RequestAuthentication.authenticate_every(@req, @params).should == :a_successful_auth
    end
    
    it "fails when the client is not valid (can't be found in the org's db)" do
      @the_pushers_couchdb.stub!(:by_clientname).with(:key => "a_knife_client").and_return([])
      lambda {RequestAuthentication.authenticate_every(@req, @params)}.should raise_error(AuthorizationError)
    end
    
    it "failse when the client is valid but the request signature can't be verified" do
      RequestAuthentication.authenticator.should_receive(:authenticate_user_request).with(@req, :knife_client_pub_key_rsaified).and_return(nil)
      lambda {RequestAuthentication.authenticate_every(@req, @params)}.should raise_error(AuthorizationError)
    end
    
    it "sets the requesting actor's id in the params in a successful request" do
      RequestAuthentication.authenticator.should_receive(:authenticate_user_request).with(@req, :knife_client_pub_key_rsaified).and_return(:a_successful_auth)
      RequestAuthentication.authenticate_every(@req, @params)
      @params[:requesting_actor_id].should == "knife_client_actor_id"
    end
    
    it "sets params[:request_from_validator] to false when the requesting client is not a validator" do
      RequestAuthentication.authenticator.should_receive(:authenticate_user_request).with(@req, :knife_client_pub_key_rsaified).and_return(:a_successful_auth)
      RequestAuthentication.authenticate_every(@req, @params)
      @params[:request_from_validator].should be_false
    end

    it "sets params[:request_from_validator] to true when the requesting client *is* a validator" do
      @knife_client.validator = true
      RequestAuthentication.authenticator.should_receive(:authenticate_user_request).with(@req, :knife_client_pub_key_rsaified).and_return(:a_successful_auth)
      RequestAuthentication.authenticate_every(@req, @params)
      @params[:request_from_validator].should be_true
    end
  end
  
end