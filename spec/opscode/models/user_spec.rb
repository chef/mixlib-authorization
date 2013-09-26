require File.expand_path('../../spec_helper', __FILE__)

include Fixtures

describe Opscode::Models::User do

  it_should_behave_like("an active model")

  before do
    @now = Time.now
    @db_data = {
      :id => "123abc",
      :authz_id => "abc123",
      :first_name => 'moon',
      :last_name => "polysoft",
      :middle_name => "trolol",
      :display_name => "problem?",
      :email => 'trolol@example.com',
      :username => 'trolol',
      :public_key => nil,
      :certificate => SAMPLE_CERT,
      :city => "Fremont",
      :country => "USA",
      :twitter_account => "moonpolysoft",
      :hashed_password => "some hex bits",
      :salt => "some random bits",
      :image_file_name => 'current_status.png',
      :external_authentication_uid => "furious_dd@example.com",
      :recovery_authentication_enabled => false,
      :created_at => @now.utc.to_s,
      :updated_at => @now.utc.to_s

    }
  end

  describe "when created without any data" do
    before do
      @user = Opscode::Models::User.new
    end

    it "has an no first name" do
      @user.first_name.should be_nil
    end

    it "has an empty last name" do
      @user.last_name.should be_nil
    end

    it "has an empty middle name" do
      @user.middle_name.should be_nil
    end

    it "has an empty display name" do
      @user.display_name.should be_nil
    end

    it "has an empty email address" do
      @user.email.should be_nil
    end

    it "has an empty username" do
      @user.username.should be_nil
    end

    it "has no public key" do
      @user.public_key.should be_nil
    end

    it "has no certificate" do
      @user.certificate.should be_nil
    end

    it "has no city" do
      @user.city.should be_nil
    end

    it "has no country" do
      @user.country.should be_nil
    end

    it "has no twitter account" do
      @user.twitter_account.should be_nil
    end

    it "has no password" do
      @user.password.should be_nil
    end

    it "has no salt" do
      @user.salt.should be_nil
    end

    it "has no image file" do
      @user.image_file_name.should be_nil
    end

    it "has no external authentication uid" do
      @user.external_authentication_uid.should be_nil
    end

    it "local recovery authenticaiton should be disabled" do
      @user.recovery_authentication_enabled.should be_false
    end

    it "is not peristed" do
      @user.should_not be_persisted
    end

    it "is not valid" do
      @user.should_not be_valid
    end

    it "has no id" do
      @user.id.should be_nil
    end

    it "has no actor id" do
      @user.authz_id.should be_nil
    end

    describe "after validating" do
      before do
        @user.valid?
      end

      it "has an invalid display name" do
        @user.errors[:display_name].should include("must not be blank")
      end

      it "has an invalid username" do
        @user.errors[:username].should include("must not be blank")
      end

      it "has an invalid email address" do
        @user.errors[:email].should include("must not be blank")
      end

      it "has an invalid password" do
        @user.should_not be_persisted
        @user.errors[:password].should include("can't be blank")
      end

      it "has a vaidation error because there is no cert or pubkey" do
        @user.errors[:credentials].should include("must have a certificate or public key")
      end
    end

    describe "after updating the timestamps" do
      before do
        @now = Time.now
        @later = @now + 3612
        Time.stub(:now).and_return(@now, @later)
        @user.update_timestamps!
      end

      it "sets created_at to now" do
        @user.created_at.should == @now.utc
      end

      it "sets updated_at to now" do
        @user.updated_at.should == @now.utc
      end

      it "includes the timestamps in the hash format for the database" do
        @user.for_db[:created_at].should == @now
        @user.for_db[:updated_at].should == @now
      end

      describe "and updating them again" do
        before do
          @user.update_timestamps!
        end

        it "leaves created_at set to the original value" do
          @user.created_at.should == @now
        end

        it "sets updated_at to the newer 'now'" do
          @user.updated_at.should == @later
        end

      end
    end

    describe "after updating the last_updated_by field" do
      before do
        @user.last_updated_by!("authz_id_for_some_dude")
      end

      it "shows who it was last updated by" do
        @user.last_updated_by.should == "authz_id_for_some_dude"
      end
    end

    describe "after setting the password" do
      before do
        @user.password = 'p@ssw0rd1'
      end

      it "generates a random salt" do
        @user.salt.should match(/[\w\-_]{60}/)
      end

      it "sets the hashed password" do
        expected_passwd = Digest::SHA1.hexdigest("#{@user.salt}--p@ssw0rd1--")
        @user.hashed_password.should == expected_passwd
      end

      it "has a valid password" do
        @user.valid?
        @user.errors[:password].should be_empty
        @user.errors[:hashed_password].should be_empty
        @user.errors[:salt].should be_empty
      end

      it "verifies that the correct password is correct" do
        @user.should be_correct_password("p@ssw0rd1")
      end

      it "rejects an invalid password" do
        @user.should_not be_correct_password("wrong!")
      end
    end

    describe "after setting the password to something too short" do
      before do
        @user.password = "2shrt"
      end

      it "has an invalid password" do
        @user.should_not be_valid
        @user.errors[:password].should == ["must be between 6 and 50 characters"]
      end
    end

    describe "when the email address is not unique" do
      before do
        @user.email_not_unique!
      end

      it "has an invalid email address" do
        @user.errors[:email].should == ["already exists."]
        @user.errors[:conflicts].should == ["email"]
      end
    end

    describe "when the username is not unique" do
      before do
        @user.username_not_unique!
      end

      it "has an invalid username" do
        @user.errors[:username].should == ["is already taken"]
        @user.errors[:conflicts].should == ["username"]
      end
    end

    describe "if both the certificate and public key are set" do
      before do
        @user.certificate = "an RSA cert"
        @user.instance_variable_set(:@public_key, "an RSA pubkey")
      end

      it "has invalid authentication credentials" do
        @user.should_not be_valid
        @user.errors[:credentials].should == ["cannot have both a certificate and public key"]
      end
    end

    # New users should have certificates and no public key (pubkey is embedded
    # in the cert). Some older users have a pubkey. They should still work correctly.
    describe "when it has a public key and no certificate (old, 'deprecated' style)" do
      before do
        @user = Opscode::Models::User.load(:public_key => "an RSA pubkey")
      end

      it "has valid authentication credentials" do
        @user.valid?
        @user.errors[:credentials].should be_empty
      end

      # seems redundant, no? but when the user has a cert, pubkey is derived
      # from it
      it "gives the public key as the public key" do
        @user.public_key.should == "an RSA pubkey"
      end

      it "nullifies the public key when a new cert is set" do
        @user.certificate = SAMPLE_CERT
        @user.instance_variable_get(:@public_key).should be_nil
        @user.public_key.to_s.should == SAMPLE_CERT_KEY
        @user.valid?
        @user.errors[:credentials].should be_empty
      end
    end

    describe "when it has a certificate (i.e. 'new style')" do
      before do
        @user.certificate = SAMPLE_CERT
      end

      it "uses the public key from the certificate" do
        # Prior implementation returned a String if public_key was set in
        # the database, OpenSSL::PKey::RSA when the user has a certificate.
        # It is not known if converting to a string would have negative impact.
        # Therefore, we consider the old behavior part of the contract.
        @user.public_key.should be_a_kind_of(OpenSSL::PKey::RSA)
        @user.public_key.to_s.should == SAMPLE_CERT_KEY
      end

      it "has valid credentials" do
        @user.valid?
        @user.errors[:credentials].should be_empty
      end
    end

    describe "after the authz_id is set" do
      before do
        @user.assign_authz_id!("new-authz-id")
      end

      it "has the updated authz_id" do
        @user.authz_id.should == "new-authz-id"
      end
    end

  end

  describe "when marked as peristed" do
    before do
      @user = Opscode::Models::User.new
      @user.persisted!
    end

    it "says it is persisted" do
      @user.should be_persisted
    end
  end

  describe "when created from database params" do
    before do
      @user = Opscode::Models::User.load(@db_data)
    end

    it "has a database id" do
      @user.id.should == "123abc"
    end

    it "has an actor id" do
      @user.authz_id.should == "abc123"
    end

    it "has a first name" do
      @user.first_name.should == "moon"
    end

    it "has a last name" do
      @user.last_name.should == "polysoft"
    end

    it "has a middle name" do
      @user.middle_name.should == "trolol"
    end

    it "has a display name" do
      @user.display_name.should == "problem?"
    end

    it "has an email address" do
      @user.email.should == "trolol@example.com"
    end

    it "has a public key extracted from its certificate" do
      @user.public_key.to_s.should == SAMPLE_CERT_KEY
    end

    it "has a certificate" do
      @user.certificate.should == SAMPLE_CERT
    end

    it "has a city" do
      # http://en.wikipedia.org/wiki/File:FremontTroll.jpg
      @user.city.should == "Fremont"
    end

    it "has a country" do
      @user.country.should == "USA"
    end

    it "has a twitter account" do
      @user.twitter_account.should == "moonpolysoft"
    end

    it "has an empty password field" do
      @user.password.should be_nil
    end

    it "has a hashed password" do
      @user.hashed_password.should == "some hex bits"
    end

    it "has a password salt" do
      @user.salt.should == "some random bits"
    end

    it "has an image file" do
      @user.image_file_name.should == "current_status.png"
    end

    it "has an external authentication uid" do
      @user.external_authentication_uid.should == "furious_dd@example.com"
    end

    it "local recovery authenticaiton should be disabled" do
      @user.recovery_authentication_enabled.should be_false
    end

    it "gives the created_at timestamp as a time object" do
      @user.created_at.should be_a_kind_of(Time)
      @user.created_at.to_i.should be_within(1).of(@now.to_i)
    end

    it "gives the updated_at timestamp as a time object" do
      @user.updated_at.should be_a_kind_of(Time)
      @user.updated_at.to_i.should be_within(1).of(@now.to_i)
    end

    it "is == to another user object with the same data" do
      copy = Opscode::Models::User.load(@db_data)
      @user.should == copy
    end

    it "is == to another user object with the same data but timestamps truncated to 1s resolution" do
      very_close_data = @db_data.dup
      very_close_data[:created_at] = Time.at(@now.to_i).utc.to_s
      very_close_data[:updated_at] = Time.at(@now.to_i).utc.to_s
      very_close_user = Opscode::Models::User.load(very_close_data)

      # Force lazy typecasting of timestamps to fire
      very_close_user.created_at
      very_close_user.updated_at

      @user.should == very_close_user
    end

    it "is not == to another user object if any of the data is different" do
      [:id, :authz_id, :first_name, :middle_name, :last_name, :username, :display_name, :hashed_password, :salt, :twitter_account].each do |attr_name|
        not_quite_data = @db_data.dup
        not_quite_data[attr_name] += "nope"
        not_quite = Opscode::Models::User.load(not_quite_data)
        @user.should_not == not_quite
      end
    end

    it "converts to a hash for JSONification" do
      user_as_a_hash = @user.for_json
      user_as_a_hash.should be_a_kind_of(Hash)
      user_as_a_hash[:city].should == "Fremont"
      user_as_a_hash[:image_file_name].should == "current_status.png"
      user_as_a_hash[:twitter_account].should == 'moonpolysoft'
      user_as_a_hash[:country].should == 'USA'
      user_as_a_hash[:username].should == "trolol"
      user_as_a_hash[:first_name].should == "moon"
      user_as_a_hash[:last_name].should == "polysoft"
      user_as_a_hash[:display_name].should == "problem?"
      user_as_a_hash[:middle_name].should == 'trolol'
      user_as_a_hash[:email].should == 'trolol@example.com'
      user_as_a_hash.should_not have_key(:public_key)

      # The API only ever shows the public key; the controller handles adding
      # it to the output.
      user_as_a_hash[:certificate].should be_nil

      # These are no longer shown in API output
      user_as_a_hash[:salt].should be_nil
      user_as_a_hash[:password].should be_nil

      expected_keys = [ :city, :twitter_account, :country, :username,
        :first_name, :last_name, :display_name, :middle_name, :email,
        :image_file_name, :external_authentication_uid]


      user_as_a_hash.keys.should =~ expected_keys
    end

    it "can update the password from params" do
      new_data = {:password => "opensesame"}
      @user.update_from_params(new_data)
      @user.should be_correct_password("opensesame")
    end

    it "can update the certificate from params" do
      new_data = {:certificate => ALTERNATE_CERT}
      @user.update_from_params(new_data)
      @user.certificate.should == ALTERNATE_CERT
    end

  end

  describe "when updating informational fields with valid form data" do
    before do
      @user = Opscode::Models::User.load(@db_data)

#{"city"=>"", "twitter_account"=>"", "image_file_name"=>nil, "format"=>nil, "country"=>"", "requesting_user"=>"pivotal", "request_from_validator"=>false, "username"=>"dan-123", "action"=>"update", "id"=>"dan-123", "orgname"=>"dan-123", "last_name"=>"deleoRules", "requesting_entity"=>#<Opscode::Models::User:-2549fd50 public_key="-----BEGIN RSA PUBLIC KEY-----\nMIIBCgKCAQEAsZLZ7EMfzy/YYMpRMRH5bS0BZI2pRDNOJMDuJzyE50S0Uq4TTspq\nDcF4gztsAUiUTNR8cCJp0vfONr5l8moETVQQprw3KPwa2mRQBBBKZrXIhh8IRZBY\noG7TI/R2Rqhv4EfnlgK5rgpBQ/3rcheaLxg+tk5XnSh5HwBvhbB8MLYqLJUjzC9U\nh/zz/LvbHoQM1Rnt4XXrbDUEm24YKyGWQJyG8b5m4FEK/vYqhRXHCt3rmOhVQkde\nUJsfgzezuIFC4kmvtp5m7KQtRq2KXHRtl39PGFwMrwfrxXEc4vIGE8xK6Wnz3q9U\n4ihDVm0uIsj79gNP7LJ6uo3AMxI6XoKJAQIDAQAB\n-----END RSA PUBLIC KEY-----\n" city=nil salt=nil created_at=nil twitter_account=nil image_file_name=nil country=nil updated_at=nil certificate=nil username="pivotal" hashed_password=nil id="fa281061b0591e548a8a0822cf285815" last_name=nil last_updated_by=nil display_name=nil aut
#2011-08-12T22:37:12.905931+00:00 account-rspreprod-i-7e80a213 [opscode-account]: hz_id="4920224947d7ed92e872e53b620e94b7" first_name=nil middle_name=nil email=nil>, "display_name"=>"dan deleoRules", "controller"=>"users", "requesting_actor_type"=>:user, "requesting_actor_id"=>"4920224947d7ed92e872e53b620e94b7", "first_name"=>"dan", "middle_name"=>"", "email"=>"dan+test123@opscode.com"}

      @form_data = {
        'first_name' => 'UpdatedFirstName',
        'last_name' => "UpdatedLastName",
        'middle_name' => "UpdatedMiddleName",
        'display_name' => "UpdatedDisplayName",
        'email' => 'updated@example.com',
        'username' => 'trolol',
        'city' => "UpdatedCity",
        'country' => "USA-updated",
        'twitter_account' => "updated_twits",
        'image_file_name' => 'updated_status.png',
        'external_authentication_uid' => 'updated_uid@updated.com'
      }
      @user.persisted!
      @user.update_from_params(@form_data)
    end

    it "updates the first name" do
      @user.first_name.should == "UpdatedFirstName"
    end

    it "updates the last name" do
      @user.last_name.should == "UpdatedLastName"
    end

    it "updates the middle name" do
      @user.middle_name.should == "UpdatedMiddleName"
    end

    it "updates the email address" do
      @user.email.should == "updated@example.com"
    end

    it "updates the City" do
      @user.city.should == "UpdatedCity"
    end

    it "updates the country" do
      @user.country.should == "USA-updated"
    end

    it "updates the twitter account" do
      @user.twitter_account.should == "updated_twits"
    end

    it "updates the image file name" do
      @user.image_file_name.should == "updated_status.png"
    end

    it "updates the external authentication uid" do
      @user.external_authentication_uid.should == "updated_uid@updated.com"
    end

    it "does not update the password" do
      @user.hashed_password.should == "some hex bits"
    end

    it "does not update the salt" do
      @user.salt.should == "some random bits"
    end

    it "is marked as having been persisted" do
      @user.should be_persisted
    end

    it "is not marked as updating the password" do
      @user.should_not be_updating_password
    end

    it "is valid to be saved again" do
      @user.should be_valid
    end

    describe "and the password is being updated" do
      it "is invalid when the password is too short" do
        @form_data["password"] = "2shrt"
        @user.update_from_params(@form_data)
        @user.should_not be_valid
        @user.errors.should have_key(:password)
      end

      it "is valid when updated with a valid password" do
        @form_data["password"] = "valid-password"
        @user.update_from_params(@form_data)
        @user.should be_valid
        @user.salt.should_not == "some random bits"
        @user.hashed_password.should_not == "some hex bits"
        @user.should be_a_correct_password("valid-password")
      end
    end

  end

  describe "when updating with incomplete form data" do
    before do
      @user = Opscode::Models::User.load(@db_data)
      @form_data = {
        :first_name => nil,
        :last_name => nil,
        :middle_name => nil,
        :display_name => nil,
        :email => nil,
        :username => 'trolol',
        :city => nil,
        :country => nil,
        :twitter_account => nil,
        :image_file_name => nil,
        :external_authentication_uid => nil
      }
      @user.update_from_params(@form_data)
    end

    it "sets the first name nil" do
      @user.first_name.should be_nil
    end

    it "sets the last name to nil" do
      @user.last_name.should be_nil
    end

    it "sets the middle name to nil" do
      @user.middle_name.should be_nil
    end

    it "sets the display name to nil" do
      @user.display_name.should be_nil
    end

    it "sets the email address to nil" do
      @user.email.should be_nil
    end

    it "sets the city to nil" do
      @user.city.should be_nil
    end

    it "sets the twitter account to nil" do
      @user.twitter_account.should be_nil
    end

    it "sets the image file to nil" do
      @user.image_file_name.should be_nil
    end

    it "sets the external authentication uid to nil" do
      @user.external_authentication_uid.should be_nil
    end
  end

  describe "when created from form data" do
    before do
      @form_data = {
        :first_name => 'moon',
        :last_name => "polysoft",
        :middle_name => "trolol",
        :display_name => "problem?",
        :email => 'trolol@example.com',
        :username => 'trolol',
        :public_key => nil,
        :certificate => SAMPLE_CERT,
        :city => "Fremont",
        :country => "USA",
        :twitter_account => "moonpolysoft",
        :password => 'p@ssw0rd1',
        :image_file_name => 'current_status.png',
        :external_authentication_uid => "furious_dd@example.com"
      }
      @user = Opscode::Models::User.new(@form_data)
    end

    it "generates a hashed password and salt" do
      @user.password.should == "p@ssw0rd1"
      @user.salt.should_not be_nil
      @user.hashed_password.should_not be_nil
      @user.should be_correct_password('p@ssw0rd1')
    end

  end

  describe "when created from form data containing a mix of string and symbol keys and extraneous data" do
    before do
      @form_data = {
        'first_name' => 'moon',
        'last_name' => "polysoft",
        'middle_name' => "trolol",
        'display_name' => "problem?",
        'email' => 'trolol@example.com',
        'username' => 'trolol',
        :certificate => SAMPLE_CERT,
        'city' => "Fremont",
        'country' => "USA",
        'twitter_account' => "moonpolysoft",
        'password' => 'p@ssw0rd1',
        'image_file_name' => 'current_status.png',
        :external_authentication_uid => "furious_dd@example.com",
        :requesting_actor_id => "some garbage",
        :id => "whatever", # pretty common in our code
        :user_id => "something",
        :authz_id => "malicious-intent",
        :recovery_authentication_enabled => true
      }
      @user = Opscode::Models::User.new(@form_data)
    end

    it "correctly sets all given fields that are publicly settable" do
    end

    it "does not set any fields that are protected" do
      @user.id.should be_nil
      @user.authz_id.should be_nil
      @user.created_at.should be_nil
      @user.updated_at.should be_nil
      @user.recovery_authentication_enabled.should be_true
    end

  end

  describe "when created from data containing both a hashed password and non-hashed password" do
    it "raises an error" do
      @form_data = {
        :id => "123abc",
        :authz_id => "abc123",
        :first_name => 'moon',
        :last_name => "polysoft",
        :middle_name => "trolol",
        :display_name => "problem?",
        :email => 'trolol@example.com',
        :username => 'trolol',
        :public_key => nil,
        :certificate => SAMPLE_CERT,
        :city => "Fremont",
        :country => "USA",
        :twitter_account => "moonpolysoft",
        :image_file_name => 'current_status.png',
        :external_authentication_uid => "furious_dd@example.com",
        :requesting_actor_id => "some garbage",
        :password => 'p@ssw0rd1',
        :hashed_password => "whoah what are you doing here?",
        :salt => "some random bits"
      }
      lambda { Opscode::Models::User.new(@form_data) }.should raise_error(ArgumentError)
    end
  end

  # TODO: make this a shared example group
  describe "implementing the required interface for Authorizable" do
    before do
      @user = Opscode::Models::User.new
    end

    it "defines all the required methods" do
      @user.should respond_to(:authz_id)
      @user.should respond_to(:authz_model_class)
      @user.should respond_to(:assign_authz_id!)
      @user.method(:assign_authz_id!).arity.should == 1
    end

    it "sets an authz id" do
      @user.assign_authz_id!("new-uuid-id")
      @user.authz_id.should == "new-uuid-id"
    end

    it "has an authz model class" do
      # could make a bunch of assertions about this class also.
      @user.authz_model_class.should be_a_kind_of(Class)
    end

    it "unsets an authz id" do
      @user.assign_authz_id!("some-uuid")
      @user.assign_authz_id!(nil)
      @user.authz_id.should be_nil
    end

  end

  describe "when authorizing a request" do
    before do
      @user = Opscode::Models::User.load(@db_data)
    end

    it "creates an authorization side object" do
      @user.create_authz_object_as(Mixlib::Authorization::Config.dummy_actor_id)
      @user.authz_id.should_not be_nil
      authz_id = @user.authz_id
      @user.authz_object_as(Mixlib::Authorization::Config.dummy_actor_id).fetch.should == {"id" => authz_id}
    end

    describe "and the authz side has been created" do
      before do
        @user.create_authz_object_as(Mixlib::Authorization::Config.dummy_actor_id)
      end

      it "checks authorization rights", :focus => true do
        @user.should_not be_authorized(Mixlib::Authorization::Config.other_actor_id1, :update)
        @user.should be_authorized(@user.authz_id, :update)
      end

      it "supports the old interface to authorization checks" do
        @user.should respond_to(:is_authorized?)
      end

      it "updates the authz side object" do
        # This is actually a no-op, because there is no updateable data in the
        # authz side object for a user. But we want to test it anyway.
        expected_id = @user.authz_id
        @user.update_authz_object_as(@user.authz_id)
        @user.authz_object_as(@user.authz_id).fetch.should == {"id" => expected_id}
      end

      # NOTE: the previous implementation did NOT actually destroy the authz
      # side object, so this implementation won't either to keep compat at a
      # maximum. But we may wish to revisit this decision, or invent a true
      # turing machine with infinite tape for storage.
      it "destroys the authz side object by removing the reference to it" do
        authz_id = @user.authz_id
        @user.destroy_authz_object_as(authz_id)
        @user.authz_id.should be_nil
      end

    end

  end


end
