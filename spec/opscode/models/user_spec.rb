require File.expand_path('../../spec_helper', __FILE__)

# namaste: https://gist.github.com/639089
shared_examples_for "an active model" do
  require 'test/unit/assertions'
  require 'active_model/lint'

  include ActiveModel::Lint::Tests
  include Test::Unit::Assertions

  # to_s is to support ruby-1.9
  ActiveModel::Lint::Tests.public_instance_methods.map{|m| m.to_s}.grep(/^test/).each do |m|
    example m.gsub('_',' ') do
      send m
    end
  end

  def model
    subject
  end
end

describe Opscode::Models::User do
  include Fixtures

  it_should_behave_like("an active model")

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

      it "has an invalid first name" do
        @user.errors[:first_name].should include("can't be blank")
      end

      it "has an invalid last name" do
        @user.errors[:last_name].should include("can't be blank")
      end

      it "has an invalid display name" do
        @user.errors[:display_name].should include("can't be blank")
      end

      it "has an invalid username" do
        @user.errors[:username].should include("can't be blank")
      end

      it "has an invalid email address" do
        @user.errors[:email].should include("can't be blank")
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
        @user.errors[:password].should == ["is too short (minimum is 6 characters)"]
      end
    end

    describe "when the email address is not unique" do
      before do
        @user.email_not_unique!
      end

      it "has an invalid email address" do
        @user.errors[:email].should == ["is already in use"]
      end
    end

    describe "when the username is not unique" do
      before do
        @user.username_not_unique!
      end

      it "has an invalid username" do
        @user.errors[:username].should == ["is already taken"]
      end
    end

    describe "if both the certificate and public key are set" do
      before do
        @user.certificate = "an RSA cert"
        @user.public_key = "an RSA pubkey"
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
        @user.public_key = "an RSA pubkey"
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
        :created_at => @now.utc.to_s,
        :updated_at => @now.utc.to_s

      }
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
      user_as_a_hash[:salt].should == "some random bits"
      user_as_a_hash[:hashed_password].should == "some hex bits"
      user_as_a_hash[:image_file_name].should == "current_status.png"
      user_as_a_hash[:twitter_account].should == 'moonpolysoft'
      user_as_a_hash[:country].should == 'USA'
      user_as_a_hash[:certificate].should == SAMPLE_CERT
      user_as_a_hash[:username].should == "trolol"
      user_as_a_hash[:first_name].should == "moon"
      user_as_a_hash[:last_name].should == "polysoft"
      user_as_a_hash[:display_name].should == "problem?"
      user_as_a_hash[:middle_name].should == 'trolol'
      user_as_a_hash[:email].should == 'trolol@example.com'
      user_as_a_hash.should_not have_key(:public_key)

      expected_keys = [ :city, :salt, :hashed_password, :twitter_account,
                        :country, :certificate, :username,
                        :first_name, :last_name, :display_name, :middle_name,
                        :email, :image_file_name]


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
        :image_file_name => 'current_status.png'
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

        :password => 'p@ssw0rd1',
        :hashed_password => "whoah what are you doing here?",
        :salt => "some random bits"

      }
      lambda { Opscode::Models::User.new(@form_data) }.should raise_error(ArgumentError)
    end
  end

  describe "when create from form data containing illegal params" do
    it "raises an error" do
      # not legal to set your authz_id for yourself :P
      lambda { Opscode::Models::User.new(:authz_id => "12345") }.should raise_error(ArgumentError)
    end
  end


end
