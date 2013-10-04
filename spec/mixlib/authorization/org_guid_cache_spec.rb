require 'spec_helper'

# Tests for OrgGuidMap and its caching.

describe Mixlib::Authorization::AuthHelper::OrgGuidMap do
  before do
    @org_guid_map = Mixlib::Authorization::AuthHelper::OrgGuidMap.new

    @test_org = Mixlib::Authorization::Models::Organization.new
    @test_org.name = "test_org1"
    @test_org.guid = "test_guid_1111"

    @test_org2 = Mixlib::Authorization::Models::Organization.new
    @test_org2.name = "test_org2"
    @test_org2.guid = "test_guid_2222"
  end

  it "should fetch directly on both tries if caching disabled" do
    @org_guid_map.disable_caching

    # expect this to be called twice, as the cache is disabled.
    Mixlib::Authorization::Models::Organization.
      should_receive(:by_name).
      exactly(2).
      with(:key => "test_org1").
      and_return([@test_org])

    @org_guid_map.guid_for_org("test_org1").should == "test_guid_1111"
    @org_guid_map.guid_for_org("test_org1").should == "test_guid_1111"
  end

  it "should fetch from cache on second try" do
    @org_guid_map.enable_caching

    # expect this to be called once only, as it will exist within the
    # cache on the second try.
    Mixlib::Authorization::Models::Organization.
      should_receive(:by_name).
      exactly(1).
      with(:key => "test_org1").
      and_return([@test_org])

    @org_guid_map.guid_for_org("test_org1").should == "test_guid_1111"
    @org_guid_map.guid_for_org("test_org1").should == "test_guid_1111"
  end

  it "should fetch directly once, and from the cache once, for two sets of two lookups" do
    @org_guid_map.enable_caching

    # each organization should be fetched exactly once and then pulled
    # from cache
    Mixlib::Authorization::Models::Organization.
      should_receive(:by_name).
      exactly(1).
      with(:key => "test_org1").
      and_return([@test_org])

    Mixlib::Authorization::Models::Organization.
      should_receive(:by_name).
      exactly(1).
      with(:key => "test_org2").
      and_return([@test_org2])

    @org_guid_map.guid_for_org("test_org1").should == "test_guid_1111"
    @org_guid_map.guid_for_org("test_org1").should == "test_guid_1111"
    @org_guid_map.guid_for_org("test_org2").should == "test_guid_2222"
    @org_guid_map.guid_for_org("test_org2").should == "test_guid_2222"
  end
end


