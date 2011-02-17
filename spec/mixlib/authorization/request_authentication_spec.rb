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

# Uncomment for verbose test debugging.
#Mixlib::Authorization::Log.level = :debug

describe RequestAuthentication do
  before do
    @user_class     = Struct::MockAuthModelsUser
    @client_class   = Struct::MockAuthModelsClient
    @actor_class    = Struct::MockAuthModelsActor
    @request_class  = Struct::MockMerbReqest

    @req = @request_class.new
    @req.env = { 'HTTP_X-OPS-SIGN' => 'not-used=but-required', 'HTTP_X-OPS-TIMESTAMP' => Time.new.rfc2822,
                 'HTTP_HOST' => 'host.example.com', 'HTTP_X-OPS-CONTENT-HASH' => '12345'}
  end

  describe "when given a request missing the required headers" do
    before do
      @req.env.clear
      @request_auth = Mixlib::Authorization::RequestAuthentication.new(@req, {})
    end

    it "indicates that required headers are missing" do
      @request_auth.required_headers_present?.should be_false
    end

    it "propagates the error message describing the invalid headers" do
      @request_auth.missing_headers.should match(/'X_OPS_SIGN', 'X_OPS_USERID', 'X_OPS_TIMESTAMP', 'HOST', 'X_OPS_CONTENT_HASH'/)
    end
  end

  describe "when authenticating a request from a user" do
    before do
      @req.env["HTTP_X-OPS-USERID"] = "MCChris"
      @mc_chris_auth_object = @actor_class.new("mc_chris_auth_object_id")
      @mc_chris = Mixlib::Authorization::Models::User.new
      @mc_chris.username = "MC Chris' Username"
      @mc_chris.public_key = "mc_chris_public_key"
      @mc_chris.stub!(:id).and_return("mc_chris_user_id")
      @params = {}

      @request_auth =  Mixlib::Authorization::RequestAuthentication.new(@req, @params)

      Mixlib::Authorization::Models::User.stub!(:find).with("MCChris").and_return(@mc_chris)
      @request_auth.stub!(:user_to_actor).with("mc_chris_user_id").and_return(@mc_chris_auth_object)

      OpenSSL::PKey::RSA.stub!(:new).with("mc_chris_public_key").and_return(:mc_chris_pub_key_rsaified)
    end

    describe "when the user is associated with the org" do
      before do
        Mixlib::Authorization::Models::OrganizationUser.stub!(:organizations_for_user).and_return(['org-guid-for-mc-chris-org'])
        @request_auth.stub!(:guid_from_orgname).and_return('org-guid-for-mc-chris-org')
      end

      it "fails if the user is not valid, i.e. can't be found in the database" do
        Mixlib::Authorization::Models::User.stub!(:find).with("MCChris").and_raise(ArgumentError)
        @request_auth.should_not be_a_valid_request
      end

      it "fails if the user is valid but authenticator returns a falsey value for :authenticate_user_request" do
        @request_auth.authenticator.should_receive(:authenticate_request).with(:mc_chris_pub_key_rsaified).and_return(nil)
        @request_auth.should_not be_a_valid_request
      end

      it "succeeds when the user is valid and the request signature can be verified with the user's public key" do
        @request_auth.authenticator.should_receive(:authenticate_request).with(:mc_chris_pub_key_rsaified).and_return(:a_successful_auth)
        @request_auth.should be_a_valid_request
      end

      it "sets the requesting actor's id in the params in a successful request" do
        pending "users of this class should not be depending on this shit"
        @request_auth.authenticator.should_receive(:authenticate_request).with(:mc_chris_pub_key_rsaified).and_return(:a_successful_auth)
        @request_auth.should be_a_valid_request
        @params[:requesting_actor_id].should == "mc_chris_auth_object_id"
      end

      it "checks that the user is assoicated with the organization in the request" do
        @request_auth.should be_a_valid_actor_for_org
      end

    end

    describe "and the user is not associated with the organization" do
      before do
        Mixlib::Authorization::Models::OrganizationUser.stub!(:organizations_for_user).and_return(['not-the-mc-chris-org'])
        @request_auth.stub!(:guid_from_orgname).and_return('org-guid-for-mc-chris-org')
      end

      it "says that the user is not associated with the org" do
        @request_auth.should_not be_a_valid_actor_for_org
      end

    end

  end

  describe "when authenticating a request from an api client" do
    before do
      @req.env["HTTP_X-OPS-USERID"] = "a_knife_client"
      @knife_client_auth_obj = @actor_class.new("knife_client_actor_id")
      @knife_client = @client_class.new("knife_client_id", "knife_client_name", "knife_client_public_key")
      @params = {:organization_id => "the_pushers_union"}

      Mixlib::Authorization::Models::User.stub!(:find).and_raise(ArgumentError)
      @the_pushers_couchdb = mock("the-orgdb-for-the-pushers-union")
      @the_pushers_couchdb.stub!(:by_clientname).with(:key => "a_knife_client").and_return([@knife_client])
      Mixlib::Authorization::Models::Client.stub!(:on).with(:the_pushers_database).and_return(@the_pushers_couchdb)

      @request_auth = Mixlib::Authorization::RequestAuthentication.new(@req, @params)
      @request_auth.stub!(:user_to_actor).with("knife_client_id").and_return(@knife_client_auth_obj)
      @request_auth.stub!(:database_from_orgname).and_return(:the_pushers_database)

      OpenSSL::PKey::RSA.stub!(:new).with("knife_client_public_key").and_return(:knife_client_pub_key_rsaified)
    end

    it "extracts the API client id from the headers" do
      @request_auth.username.should == 'a_knife_client'
    end

    it "extracts the orgname from the params hash" do
      @request_auth.orgname.should == 'the_pushers_union'
    end

    it "fetches the client from the database" do
      @request_auth.requesting_entity.should == @knife_client
    end

    it "loads the public key for the client" do
      @request_auth.user_key.should == :knife_client_pub_key_rsaified
    end

    it "succeeds when the client is valid and the request signature can be verified with the client's public key" do
      @request_auth.authenticator.should_receive(:authenticate_request).with(:knife_client_pub_key_rsaified).and_return(:a_successful_auth)
      @request_auth.should be_a_valid_request
    end

    it "fails when the client is not valid (can't be found in the org's db)" do
      @the_pushers_couchdb.stub!(:by_clientname).with(:key => "a_knife_client").and_return([])
      @request_auth.should_not be_a_valid_request
    end

    it "fails when the client is valid but the request signature can't be verified" do
      @request_auth.authenticator.should_receive(:authenticate_request).with(:knife_client_pub_key_rsaified).and_return(nil)
      @request_auth.should_not be_a_valid_request
    end

    it "determines that the request is not from a validator when the requesting entity is not a validator" do
      @request_auth.request_from_validator?.should be_false
    end

    it "determines that the request is from a validator when the requesting entity is a validator" do
      @knife_client.validator = true
      @request_auth.request_from_validator?.should be_true
    end

    it "determines the request is not from the webui " do
      @request_auth.should_not be_request_from_webui
    end

    it "extracts the requesting actor id" do
      @knife_client_auth_obj.auth_object_id.should == "knife_client_actor_id"
      @request_auth.requesting_actor_id.should == "knife_client_actor_id"
    end

    it "says that the actor exists" do
      @request_auth.actor_exists?.should be_true
    end

    it "queries the authenticator object to determine if the request's timestamp is valid" do
      @request_auth.authenticator.should_receive(:authenticate_request).with(:knife_client_pub_key_rsaified).and_return(:a_successful_auth)
      @request_auth.should be_a_valid_request
      # boo for message expectations but we stubbed the crap out of mixlib authn so whatever.
      @request_auth.authenticator.should_receive(:valid_timestamp?).and_return(true)
      @request_auth.valid_timestamp?.should be_true
      @request_auth.authenticator.should_receive(:valid_timestamp?).and_return(false)
      @request_auth.valid_timestamp?.should be_false
    end

  end

  describe "when authenticating a request from the Web UI" do
    before do
      @req.env['HTTP_X-OPS-REQUEST-SOURCE'] = 'web'
      @req.env["HTTP_X-OPS-USERID"] = "MCChris"
      @mc_chris_auth_object = @actor_class.new("mc_chris_auth_object_id")
      @mc_chris = Mixlib::Authorization::Models::User.new
      @mc_chris.username = "MC Chris' Username"
      @mc_chris.public_key = "mc_chris_public_key"
      @mc_chris.stub!(:id).and_return("mc_chris_user_id")
      @params = {}

      Mixlib::Authorization::Config[:web_ui_public_key] = "webui_public_key"

      @request_auth =  Mixlib::Authorization::RequestAuthentication.new(@req, @params)

      Mixlib::Authorization::Models::User.stub!(:find).with("MCChris").and_return(@mc_chris)
      @request_auth.stub!(:user_to_actor).with("mc_chris_user_id").and_return(@mc_chris_auth_object)

      Mixlib::Authorization::Models::OrganizationUser.stub!(:organizations_for_user).and_return(['org-guid-for-mc-chris-org'])
      @request_auth.stub!(:guid_from_orgname).and_return('org-guid-for-mc-chris-org')

      OpenSSL::PKey::RSA.stub!(:new).with("webui_public_key").and_return(:webui_public_key_rsaified)
    end

    it "uses the webui public key as the user key" do
      @request_auth.user_key.should == :webui_public_key_rsaified
    end

    it "uses the webui public key when validating the request" do
      @request_auth.authenticator.should_receive(:authenticate_request).with(:webui_public_key_rsaified).and_return(:a_successful_auth)
      @request_auth.should be_a_valid_request
    end

    it "says the request is from the webui" do
      @request_auth.should be_request_from_webui
    end

  end

end
