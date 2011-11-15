require File.expand_path('../../spec_helper', __FILE__)

describe Opscode::Mappers::User do
  include Fixtures

  before(:all) do
    require 'logger'
    @db = Sequel.connect(SQL_DATABASE_URI)
    #@db.logger = Logger.new(STDOUT) # makes the tests loud.
  end

  before do
    @db[:users].truncate

    @stats_client = TestingStatsClient.new

    @user_data = {
      :id => "123abc".ljust(32, '0'),
      :authz_id => "abc123".ljust(32, '0'),
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
    @mapper = Opscode::Mappers::User.new(@db, @stats_client, "some_dudes_authz_id".ljust(32, "0"))
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

    it "benchmarks a create operations" do
      @user = Opscode::Models::User.load(@user_data)
      @mapper.create(@user)
      # there may be extra calls to do uniqueness validations, that's fine.
      @stats_client.times_called.should >= 1
    end

    it "raises an error when attempting to save an invalid object" do
      @user_data.delete(:first_name)
      @user = Opscode::Models::User.load(@user_data)
      lambda { @mapper.create(@user) }.should raise_error(Opscode::Mappers::InvalidRecord)
    end

    it "has no users in the full list" do
      @mapper.find_all_usernames.should == []
    end

    it "raises an error when attempting to delete a user that doesn't exist" do
      @user = Opscode::Models::User.load(@user_data)
      lambda { @mapper.destroy(@user) }.should raise_error(Opscode::Mappers::RecordNotFound)
    end

  end

  describe "after 'joeuser' is created with the db id and authz id set" do
    before do
      @user = Opscode::Models::User.load(@user_data)
      @now = Time.now
      Time.stub!(:now).and_return(@now)
      @mapper.create(@user)
    end

    it "marks the user object as persisted" do
      @user.should be_persisted
    end

    it "loads a subset of the user's data for authentication purposes" do
      user = @mapper.find_for_authentication("joeuser")
      user.username.should == "joeuser"
      user.public_key.to_s.should == SAMPLE_CERT_KEY
      user.id.should == "123abc".ljust(32, '0')
      # This is used when making authz requests later
      user.authz_id.should == "abc123".ljust(32, '0')
      user.should be_persisted
    end

    it "loads the username, id, and authz_id by username" do
      authz_id = @user.authz_id
      id = @user.id
      user = @mapper.find_by_authz_id(authz_id)
      user.authz_id.should == authz_id
      user.username.should == "joeuser"
      user.id.should == id
    end

    it "loads the full user object" do
      user = @mapper.find_by_username("joeuser")
      user.should == @user
    end

    it "has a created_at and updated_at timestamp set on the user" do
      user = @mapper.find_by_username("joeuser")
      user.created_at.to_i.should be_within(1).of(@now.to_i)
      user.updated_at.to_i.should be_within(1).of(@now.to_i)
    end

    it "loads the username, first name, last name, and email of all users" do
      verbose_user_list = @mapper.find_all_for_support_ui
      verbose_user_list.should have(1).users
      verbose_user = verbose_user_list.first
      verbose_user.username.should == "joeuser"
      verbose_user.first_name.should == "Joe"
      verbose_user.last_name.should == "User"
      verbose_user.email.should == "joe@example.com"
    end

    it "lists all username" do
      @mapper.find_all_usernames.should == ["joeuser"]
    end

    it "updates the user in the database from a User object" do
      updated_data = @user_data.dup
      updated_data[:certificate] = ALTERNATE_CERT
      updated_data[:password] = "newPassword"
      @user.update_from_params(updated_data)
      @mapper.update(@user)
      round_tripped = @mapper.find_by_username("joeuser")
      round_tripped.should == @user
      round_tripped.should be_correct_password("newPassword")
      round_tripped.certificate.should == ALTERNATE_CERT
    end

    it "deletes the user from the database" do
      @mapper.destroy(@user)
      @mapper.find_by_username("joeuser").should be_nil
    end

    describe "when trying to create another user with the same username" do
      it "raises an InvalidRecord exception" do
        @user.id.replace("duplicate_guy")
        lambda { @mapper.create(@user) }.should raise_error(Opscode::Mappers::InvalidRecord)
      end

      it "marks the user object as invalid" do
        @user.id.replace("duplicate_username_guy")
        @mapper.create(@user) rescue nil
        @user.errors.should have_key(:username)
      end
    end

    describe "when trying to create another user with the same email" do
      it "raises an InvalidRecord exception" do
        @user.id.replace("duplicate_guy")
        @user.username.replace("a-different-username")
        lambda { @mapper.create(@user)}.should raise_error(Opscode::Mappers::InvalidRecord)
      end

      it "marks the user object as invalid" do
        @user.id.replace("duplicate_guy")
        @user.authz_id.replace("wtfbro")
        @user.username.replace("a-different-username")
        @mapper.create(@user) rescue nil
        @user.errors.should have_key(:email)
      end
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
      pending "Authz side ID comes from authz itself..."
      user.authz_id.should_not be_nil
      user.authz_id.should_not == @old_authz_id
    end
  end

end
