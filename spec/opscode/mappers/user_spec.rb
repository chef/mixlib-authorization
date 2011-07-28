require File.expand_path('../../spec_helper', __FILE__)

describe Opscode::Mappers::User do
  include Fixtures

  before(:all) do
    require 'logger'
    @db = Sequel.connect("mysql2://root@localhost/opscode_chef_test")
    #@db.logger = Logger.new(STDOUT) # makes the tests loud.
  end

  before do
    @db[:users].truncate

    @user_data = {
      :id => "123abc",
      :authz_id => "abc123",
      :first_name => 'Joe',
      :last_name => "User",
      :middle_name => "The",
      :display_name => "Joe the sample User",
      :email => 'joe@example.com',
      :username => 'joeuser',
      :certificate => SAMPLE_CERT,
      :city => "Fremont",
      :country => "USA",
      :password => "p@ssword1",
      :image_file_name => 'current_status.png'
    }
    @mapper = Opscode::Mappers::User.new(@db, "some_dudes_authz_id")
  end

  describe "when no users are in the database" do
    it "does not find a user for authenticating" do
      @mapper.find_for_authentication("joeuser").should be_nil
    end

    it "does not find a user" do
      @mapper.find_by_username("joeuser").should be_nil
    end

    it "can create a user record from a user model" do
      @user = Opscode::Models::User.load(@user_data)
      @mapper.create(@user)
      @db[:users].first[:username].should == "joeuser"
    end

    it "benchmarks a create operation" do
      @user = Opscode::Models::User.load(@user_data)
      @mapper.create(@user)
      pending "integrate benchmarker"
    end

  end

  describe "after 'joeuser' is created with the db id and authz id set" do
    before do
      @user = Opscode::Models::User.load(@user_data)
      @now = Time.now
      Time.stub!(:now).and_return(@now)
      @mapper.create(@user)
    end

    it "finds a user for authentication purposes" do
      user = @mapper.find_for_authentication("joeuser")
      user.username.should == "joeuser"
      user.public_key.to_s.should == SAMPLE_CERT_KEY
      user.id.should == "123abc"
      # This is used when making authz requests later
      user.authz_id.should == "abc123"
      user.should be_persisted
    end

    it "has a created_at and updated_at timestamp set on the user" do
      user = @mapper.find_by_username("joeuser")
      user.created_at.to_i.should be_within(1).of(@now.to_i)
      user.updated_at.to_i.should be_within(1).of(@now.to_i)
    end

  end

  describe "after 'joeuser' is created without a database id or authz id" do
    before do
      @old_id = @user_data.delete(:id)
      @old_authz_id = @user_data.delete(:authz_id)

      @user = Opscode::Models::User.new(@user_data)
      @mapper.create(@user)
    end

    it "has a generated id and authz id for joeuser" do
      user = @mapper.find_by_username("joeuser")
      user.id.should_not be_nil
      user.id.should_not == @old_id
      user.authz_id.should_not be_nil
      user.authz_id.should_not == @old_authz_id
    end
  end

end
