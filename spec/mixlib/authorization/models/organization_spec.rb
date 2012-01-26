require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')

RSpec::Matchers.define :have_validation_error do |*expected|
  match do |actual|
    return false if actual.valid?
    actual.errors.full_messages == expected
  end
end

describe Models::Organization do
  before do
    @org = Models::Organization.new
  end
  
  describe "validating org properties" do
    before do
      @org[:name] = "valid-org-name"
      @org[:full_name] = "Valid Org Full Name"
      @org[:org_type] = "Business"
      @org[:clientname] = "org-validator"
      
      @org.stub!(:unique_name?).and_return(true)
    end
    
    it "allows org names with 'a-z', '0-9', '_', and '-'" do
      @org[:name] = "valid-org-name"
      @org.should be_valid
      @org[:name] = "underscores_r_cool"
      @org.should be_valid
    end
    
    it "does not allow org names with chars other than 'a-z', '0-9', '_', '-'" do
      @org[:name] = "valid-org-name"
      @org.should be_valid
      
      @org[:name] = "INVALID"
      @org.should_not be_valid
      @org[:name] = "$$big$$pimpin"
      @org.should_not be_valid
      @org[:name] = "_reserved_for_opscode"
      @org.should_not be_valid
      @org[:name] = "-too-fugly-for-even-god-to-love"
      @org.should_not be_valid
    end

    it "has helpful error messages" do
      @org[:name] = "name INVALID"
      @org.should have_validation_error "name must only contain letters, digits, hyphens, and underscores"
      @org[:name] = "_reserved_for_opscode"
      @org.should have_validation_error "name must begin with a letter or digit"
      @org[:name] = "-too-fugly-for-even-god-to-love"
      @org.should have_validation_error "name must begin with a letter or digit"
      @org[:name] = "SHOUTING"
      @org.should have_validation_error "name must only contain letters, digits, hyphens, and underscores", "name must begin with a letter or digit"
    end
    
    it "ensures that the name is unique"
    it "ensures the org type is valid"
    
  end
  
  
end