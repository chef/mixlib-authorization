require File.expand_path('../../spec_helper', __FILE__)

describe Opscode::Mappers::User do

  describe "when no users are in the database" do
    it "does not find a user for authenticating" do
      @mapper.find_for_authentication("joeuser").should be_nil
    end

    it "does not load the user" do
      @mapper.find_by_username("joeuser").should be_nil
    end
  end

  describe "when joeuser is in the database" do

    it "finds a user for authentication purposes" do
      @user = @mapper.find_for_authentication("joeuser")
      @user.username.should == "joeuser"
      @user.public_key.should == "an rsa pub key"
      @user.id.should == "123abc"
      # This is used when making authz requests later
      @user.authz_id.should == "abc123"
    end
  end

end
