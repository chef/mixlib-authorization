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

SAMPLE_CERT =<<-CERT
-----BEGIN CERTIFICATE-----
MIIDODCCAqGgAwIBAgIEz5HZWDANBgkqhkiG9w0BAQUFADCBnjELMAkGA1UEBhMC
VVMxEzARBgNVBAgMCldhc2hpbmd0b24xEDAOBgNVBAcMB1NlYXR0bGUxFjAUBgNV
BAoMDU9wc2NvZGUsIEluYy4xHDAaBgNVBAsME0NlcnRpZmljYXRlIFNlcnZpY2Ux
MjAwBgNVBAMMKW9wc2NvZGUuY29tL2VtYWlsQWRkcmVzcz1hdXRoQG9wc2NvZGUu
Y29tMCAXDTExMDcxOTIyNTY1MloYDzIxMDAwOTIwMjI1NjUyWjCBmzEQMA4GA1UE
BxMHU2VhdHRsZTETMBEGA1UECBMKV2FzaGluZ3RvbjELMAkGA1UEBhMCVVMxHDAa
BgNVBAsTE0NlcnRpZmljYXRlIFNlcnZpY2UxFjAUBgNVBAoTDU9wc2NvZGUsIElu
Yy4xLzAtBgNVBAMUJlVSSTpodHRwOi8vb3BzY29kZS5jb20vR1VJRFMvdXNlcl9n
dWlkMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0NKi934E1BoX2PVP
Nlv+2rtdFervrNt5tK762QYFBlciwAdH0DIxcBsEpJyi/V/IAPi05LRoIs+a2qjN
VD73YjxoKIVnm3wFOEHY6XKMN0NCzyhPPxGQqws9aSSOU1lGa72sOoPGH+1e46ni
7adW1TMTNN8w8bYCXeL2dvyXAbzlTap+tLbkeKgjt9MvRwFQfQ8Im9KqfuHDbVJn
EquRIx/0TbT+BF9jBg463GG0tMKySulqw4+CpAAh2BxdjvdcfIpXQNPJao3CgvGF
xN+GlrHO5kIGNT0iie+Z02TUr8sIAhc6n21q/F06W7i7vY07WgiwT+iLJ+IG4ylQ
ewAYtwIDAQABMA0GCSqGSIb3DQEBBQUAA4GBAGKC0q99xFwyrHZkKhrMOZSWLV/L
9t4WWPdI+iGB6bG0sbUF+bWRIetPtUY5Ueqf7zLxkFBvFkC/ob4Kb5/S+81/jE0r
h7zcu9piePUXRq+wzg6be6mTL/+YVFtowSeBR1sZbhjtNM8vv2fVq7OEkb7BYJ9l
HYCz2siW4sVv9rca
-----END CERTIFICATE-----
CERT

SAMPLE_CERT_KEY =<<-KEY
-----BEGIN RSA PUBLIC KEY-----
MIIBCgKCAQEA0NKi934E1BoX2PVPNlv+2rtdFervrNt5tK762QYFBlciwAdH0DIx
cBsEpJyi/V/IAPi05LRoIs+a2qjNVD73YjxoKIVnm3wFOEHY6XKMN0NCzyhPPxGQ
qws9aSSOU1lGa72sOoPGH+1e46ni7adW1TMTNN8w8bYCXeL2dvyXAbzlTap+tLbk
eKgjt9MvRwFQfQ8Im9KqfuHDbVJnEquRIx/0TbT+BF9jBg463GG0tMKySulqw4+C
pAAh2BxdjvdcfIpXQNPJao3CgvGFxN+GlrHO5kIGNT0iie+Z02TUr8sIAhc6n21q
/F06W7i7vY07WgiwT+iLJ+IG4ylQewAYtwIDAQAB
-----END RSA PUBLIC KEY-----
KEY

describe Opscode::Models::User do
  it_should_behave_like("an active model")

  describe "when empty" do
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
      @user.actor_id.should be_nil
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
      @db_data = {
        :id => "123abc",
        :actor_id => "abc123",
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
        :password => nil,
        :hashed_password => "some hex bits",
        :salt => "some random bits",
        :image_file_name => 'current_status.png'
      }
      @user = Opscode::Models::User.new(@db_data)
    end

    it "has a database id" do
      @user.id.should == "123abc"
    end

    it "has an actor id" do
      @user.actor_id.should == "abc123"
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
  end

end
