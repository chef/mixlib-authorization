require File.expand_path('../../../spec_helper', __FILE__)

# namaste: https://gist.github.com/639089
shared_examples_for "ActiveModel" do
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
  it_should_behave_like("ActiveModel")

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

  end

  describe "when marked as peristed" do
    before do
      @user = Opscode::Models::User.new
      @user.persisted!
    end

    it "is marked as persisted" do
      @user.should be_persisted
    end
  end

end
