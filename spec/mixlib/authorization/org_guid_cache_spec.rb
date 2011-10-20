require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

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

    @time_now = Time.now
    @time_in_two_minutes = Time.at(@time_now.to_i + 120)
  end

  it "should fetch directly on both tries if caching disabled" do
    @org_guid_map.disable_caching

    # expect this to be called twice, as the cache is disabled.
    Time.should_not_receive(:now)
    Mixlib::Authorization::Models::Organization.
      should_receive(:by_name).
      exactly(2).
      with(:key => "test_org1").
      and_return([@test_org])

    @org_guid_map.guid_for_org("test_org1").should == "test_guid_1111"
    @org_guid_map.guid_for_org("test_org1").should == "test_guid_1111"
  end

  it "should fetch from cache on second try if it hasn't expired" do
    @org_guid_map.enable_caching

    # expect this to be called once only, as it will exist within the
    # cache on the second try.
    Time.should_receive(:now).and_return(@time_now)
    Mixlib::Authorization::Models::Organization.
      should_receive(:by_name).
      exactly(1).
      with(:key => "test_org1").
      and_return([@test_org])
    Time.should_receive(:now).and_return(@time_now)

    @org_guid_map.guid_for_org("test_org1").should == "test_guid_1111"
    @org_guid_map.guid_for_org("test_org1").should == "test_guid_1111"
  end

  it "should fetch directly on both tries if the cache has expired" do
    @org_guid_map.enable_caching

    # expect this to be called twice, as the cache will have expired
    # on the second try.
    Time.should_receive(:now).and_return(@time_now)
    Mixlib::Authorization::Models::Organization.
      should_receive(:by_name).
      exactly(1).
      with(:key => "test_org1").
      and_return([@test_org])
    Time.should_receive(:now).and_return(@time_in_two_minutes)
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
    Time.should_receive(:now).and_return(@time_now)  # first fetch
    Mixlib::Authorization::Models::Organization.
      should_receive(:by_name).
      exactly(1).
      with(:key => "test_org1").
      and_return([@test_org])
    Time.should_receive(:now).and_return(@time_now)  # second fetch

    Time.should_receive(:now).and_return(@time_now)  # first fetch
    Mixlib::Authorization::Models::Organization.
      should_receive(:by_name).
      exactly(1).
      with(:key => "test_org2").
      and_return([@test_org2])
    Time.should_receive(:now).and_return(@time_now)  # second fetch

    @org_guid_map.guid_for_org("test_org1").should == "test_guid_1111"
    @org_guid_map.guid_for_org("test_org1").should == "test_guid_1111"
    @org_guid_map.guid_for_org("test_org2").should == "test_guid_2222"
    @org_guid_map.guid_for_org("test_org2").should == "test_guid_2222"
  end


end


