require 'spec_helper'

describe Models::Client do
  before do
    @client = Models::Client.new
  end
  
  it "says if it is a validator or not" do
    @client.should respond_to(:validator?)
  end
  
  it "defaults to validator==false" do
    @client.validator.should be_false
  end
  
  it "is a validator if it has a name of the form ORGNAME-validator" do
    @client.orgname     = "teh-clownco"
    @client.clientname  = "teh-clownco-validator"
    @client.should be_a_validator
  end
  
  it "is a validator if it has validator==true" do
    @client.orgname     = "teh-clownco"
    @client.clientname  = "an-alternate-validator"
    @client.validator   = true
    @client.should be_a_validator
  end
  
  it "is not a validator if it's name doesn't match ORGNAME-validator and validator==false" do
    @client.orgname     = "teh-clownco"
    @client.clientname  = "not-the-validator"
    @client.validator   = false
    @client.should_not be_a_validator
  end
  
end
