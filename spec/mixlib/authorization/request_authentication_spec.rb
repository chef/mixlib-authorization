require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

Struct.new("MockAuthModelsUser", :id, :username, :public_key)
Struct.new("MockAuthModelsClient", :id, :clientname, :public_key, :validator)
class Struct::MockAuthModelsClient
  def validator?
    validator
  end
end
Struct.new("MockAuthModelsActor", :auth_object_id)
class MockMerbReqest < Struct.new(:env, :params, :method, :path)
  def raw_post
    ""
  end
end

# Uncomment for verbose test debugging.
#Mixlib::Authorization::Log.level = :debug
#Mixlib::Authentication::Log.level = :debug

describe RequestAuthentication do
  before(:all) do
    Opscode::Mappers.connection_string = "mysql2://root@localhost/opscode_chef_test"
  end

  before do
    Opscode::Mappers.default_connection[:users].truncate
    @user_class     = Struct::MockAuthModelsUser
    @client_class   = Struct::MockAuthModelsClient
    @actor_class    = Struct::MockAuthModelsActor
    @request_class  = MockMerbReqest


    @user_mapper = Opscode::Mappers::User.new(Opscode::Mappers.default_connection, nil, 0)

  end

  describe "when given a request missing the required headers" do
    before do
      @req = @request_class.new
      @req.env = {}
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
      # Create the user
      @user_data = {  :username => "mc-chris",
                      :password => "password",
                      :email => "mc.chris@example.com",
                      :first_name => "MC",
                      :last_name => "Chris",
                      :display_name => "MC CHRIS",
                      :certificate => AuthzFixtures::CERT}
      @user = Opscode::Models::User.new(@user_data)
      @user_mapper.create(@user)

      # Generate the request data/signature
      @client_side_data = {:http_method => "GET", :path => "/testing", :body => "", :host => 'mixlib-authz.example.com', :timestamp => Time.now.to_s, :user_id => 'mc-chris'}
      @user_rsa_key = OpenSSL::PKey::RSA.new(AuthzFixtures::PRIVKEY)
      @signature_creator = Mixlib::Authentication::SignedHeaderAuth.signing_object(@client_side_data)
      @client_side_headers = @signature_creator.sign(@user_rsa_key)
      @server_side_headers = {}
      @client_side_headers.each do |header, value|
        key = header[/^X/] ? "HTTP_#{header}" : header
        @server_side_headers[key] = value
      end
      @server_side_headers['HTTP_HOST'] = 'mixlib-authz.example.com'

      # Create request object (implements contract of object returned by #request in a merb controller)
      @req = @request_class.new(@server_side_headers, {}, "GET", "/testing")
      @req.env = @server_side_headers
      @params = {}

      @request_auth =  Mixlib::Authorization::RequestAuthentication.new(@req, @params)

    end

    it "fails if the user is not valid, i.e. can't be found in the database" do
      @user_mapper.destroy(@user)
      @request_auth.should_not be_a_valid_request
    end

    it "fails if the user's certificate does not match the key used to sign the request" do
      @user.certificate = AuthzFixtures::WRONG_CERT
      @user_mapper.update(@user)
      @request_auth.should_not be_a_valid_request
    end

    it "succeeds when the user is valid and the request signature can be verified with the user's public key" do
      @request_auth.should be_a_valid_request
    end

  end

  describe "when authenticating a request from an api client" do
    before do
      # Client Data
      @client_data = {:clientname => "a_knife_client", :orgname => "example-org", :certificate => AuthzFixtures::CERT}
      @client = Mixlib::Authorization::Models::Client.new(@client_data)
      @client.stub!(:authz_id).and_return("123abc")

      # Generate the request data/signature
      @client_side_data = {:http_method => "GET", :path => "/testing", :body => "", :host => 'mixlib-authz.example.com', :timestamp => Time.now.to_s, :user_id => 'a_knife_client'}
      @client_rsa_key = OpenSSL::PKey::RSA.new(AuthzFixtures::PRIVKEY)
      @signature_creator = Mixlib::Authentication::SignedHeaderAuth.signing_object(@client_side_data)
      @client_side_headers = @signature_creator.sign(@client_rsa_key)
      @server_side_headers = {}
      @client_side_headers.each do |header, value|
        key = header[/^X/] ? "HTTP_#{header}" : header
        @server_side_headers[key] = value
      end
      @server_side_headers['HTTP_HOST'] = 'mixlib-authz.example.com'

      # Create request object (implements contract of object returned by #request in a merb controller)
      @req = @request_class.new(@server_side_headers, {}, "GET", "/testing")
      @params = {:organization_id => "example-org"}
      @request_auth = Mixlib::Authorization::RequestAuthentication.new(@req, @params)
      @request_auth.stub!(:database_from_orgname).and_return(:couchrest_db_for_example_org)

    end

    it "extracts the API client id from the headers" do
      @request_auth.username.should == 'a_knife_client'
    end

    it "extracts the orgname from the params hash" do
      @request_auth.orgname.should == 'example-org'
    end

    describe "and the client does not exist in the database" do
      before do
        @org_scoped_client_model = mock("CouchDB Client model for example-org", :by_clientname => [ ])
        Mixlib::Authorization::Models::Client.stub!(:on).with(:couchrest_db_for_example_org).and_return(@org_scoped_client_model)
      end

      it "fails authentication" do
        @request_auth.should_not be_a_valid_request
      end

    end

    describe "and the client exists in the database" do
      before do
        # Wire up the layers of proxies and such for CouchREST
        @org_scoped_client_model = mock("CouchDB Client model for example-org", :by_clientname => [ @client ])
        Mixlib::Authorization::Models::Client.stub!(:on).with(:couchrest_db_for_example_org).and_return(@org_scoped_client_model)
      end

      it "fetches the client from the database" do
        @request_auth.requesting_entity.should == @client
      end

      it "loads the public key for the client" do
        @request_auth.user_key.to_s.should == @client.public_key.to_s
      end

      it "succeeds when the client is valid and the request signature can be verified with the client's public key" do
        @request_auth.should be_a_valid_request
      end


      it "fails when the client is valid but the request signature can't be verified" do
        @client.certificate = AuthzFixtures::WRONG_CERT
        @request_auth.should_not be_a_valid_request
      end

      it "determines that the request is not from a validator when the requesting entity is not a validator" do
        @request_auth.request_from_validator?.should be_false
      end

      it "determines that the request is from a validator when the requesting entity is a validator" do
        @client.validator = true
        @request_auth.request_from_validator?.should be_true
      end

      it "determines the request is not from the webui " do
        @request_auth.should_not be_request_from_webui
      end

      it "extracts the requesting actor id" do
        @request_auth.requesting_actor_id.should == "123abc"
      end

      it "says that the actor exists" do
        @request_auth.actor_exists?.should be_true
      end

      it "queries the authenticator object to determine if the request's timestamp is valid" do
        @request_auth.should be_a_valid_request
        # TODO: craft an actual unauthorized request w/ bad timestamp instead.
        @request_auth.authenticator.should_receive(:valid_timestamp?).and_return(true)
        @request_auth.valid_timestamp?.should be_true
        @request_auth.authenticator.should_receive(:valid_timestamp?).and_return(false)
        @request_auth.valid_timestamp?.should be_false
      end
    end

  end

  describe "when authenticating a request from the Web UI" do
    before do
      @user_data = {  :username => "mc-chris",
                      :password => "password",
                      :email => "mc.chris@example.com",
                      :first_name => "MC",
                      :last_name => "Chris",
                      :display_name => "MC CHRIS",
                      :certificate => AuthzFixtures::CERT}
      @user = Opscode::Models::User.new(@user_data)
      @user_mapper.create(@user)

      # Generate the request data/signature
      @client_side_data = {:http_method => "GET", :path => "/testing", :body => "", :host => 'mixlib-authz.example.com', :timestamp => Time.now.to_s, :user_id => 'mc-chris'}
      @user_rsa_key = OpenSSL::PKey::RSA.new(AuthzFixtures::PRIVKEY2)
      @signature_creator = Mixlib::Authentication::SignedHeaderAuth.signing_object(@client_side_data)
      @client_side_headers = @signature_creator.sign(@user_rsa_key)
      @server_side_headers = {}
      @client_side_headers.each do |header, value|
        key = header[/^X/] ? "HTTP_#{header}" : header
        @server_side_headers[key] = value
      end
      @server_side_headers['HTTP_HOST'] = 'mixlib-authz.example.com'
      @server_side_headers['HTTP_X-OPS-REQUEST-SOURCE'] = 'web'
      @server_side_headers["HTTP_X-OPS-USERID"] = "mc-chris"

      @req = @request_class.new(@server_side_headers, {}, "GET", "/testing")
      @req.env = @server_side_headers
      @params = {}

      Mixlib::Authorization::Config[:web_ui_public_key] = OpenSSL::PKey::RSA.new(AuthzFixtures::PUBKEY2.strip)

      @request_auth =  Mixlib::Authorization::RequestAuthentication.new(@req, @params)

    end

    it "uses the webui public key as the user key" do
      @request_auth.send(:webui_public_key).to_s.should == AuthzFixtures::PUBKEY2.to_s
      @request_auth.user_key.to_s.should == AuthzFixtures::PUBKEY2.to_s
    end

    it "uses the webui public key when validating the request" do
      #@request_auth.authenticator.should_receive(:authenticate_request).with(:webui_public_key_rsaified).and_return(:a_successful_auth)
      @request_auth.should be_a_valid_request
    end

    it "says the request is from the webui" do
      @request_auth.should be_request_from_webui
    end

    describe "using the multi webui keys feature" do
      before do
        # not sure what we'll use for the tags, maybe a datetime or something
        Mixlib::Authorization::Config[:web_ui_public_keys] = {"some_tag" => OpenSSL::PKey::RSA.new(AuthzFixtures::PUBKEY3.strip) }
        @server_side_headers["HTTP_X-OPS-WEBKEY-TAG"] = "some_tag"

        @req = @request_class.new(@server_side_headers, {}, "GET", "/testing")
        @req.env = @server_side_headers
        @params = {}

        Mixlib::Authorization::Config[:web_ui_public_key] = OpenSSL::PKey::RSA.new(AuthzFixtures::PUBKEY2.strip)

        @request_auth =  Mixlib::Authorization::RequestAuthentication.new(@req, @params)
      end

      it "uses the webui public key specified in the tag as the user key" do
        @request_auth.send(:webui_public_key).to_s.should == OpenSSL::PKey::RSA.new(AuthzFixtures::PUBKEY3.strip).to_s
        @request_auth.user_key.to_s.should == AuthzFixtures::PUBKEY3.to_s
      end

      it "says the request is from the webui" do
        @request_auth.should be_request_from_webui
      end

    end

  end

end
