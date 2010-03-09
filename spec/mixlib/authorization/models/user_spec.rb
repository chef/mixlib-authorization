require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')

describe Mixlib::Authorization::Models::User do
  before do
    @user = Mixlib::Authorization::Models::User.new
  end
  
  it "generates a salt" do
    # OpenSSL::Random.random_bytes(n)
    # [random_bytes(n)].pack("m*").delete("\n")
    @user.send(:generate_salt!)
    puts "salt size: #{@user.salt.size}"
    @user.salt.should match(/^[A-Za-z0-9\-\_]{60}$/)
  end
  
  it "allows the password to be set, generating a salt and one-way digest of the unhashed password" do
    stubby_salt = 'A' * 60
    @user.stub!(:salt).and_return(stubby_salt)
    @user.set_password("tatftMEANStatft")
    @user.password.should == Digest::SHA1.hexdigest("#{stubby_salt}--tatftMEANStatft--")
  end
  
  it "tells you if an (unhashed) password matches the hashed one in the database" do
    stubby_salt = 'A' * 60
    @user.stub!(:salt).and_return(stubby_salt)
    @user.set_password("tatftMEANStatft")
    @user.password.should == Digest::SHA1.hexdigest("#{stubby_salt}--tatftMEANStatft--")
    @user.correct_password?("tatftMEANStatft").should be_true
    @user.correct_password?("tatftMEANSdont_write_tests").should be_false #obviously
  end
end