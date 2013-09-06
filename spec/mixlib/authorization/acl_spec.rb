require File.expand_path('../../../spec_helper', __FILE__)

describe Acl do
  before do
    # TODO: This class should not even talk to the database at all.
    Opscode::Mappers.use_dev_config
#    Opscode::Mappers.connection_string = "mysql2://root@127.0.0.1/opscode_chef_test"
  end

  describe "in the constructor" do
    it "initializes itself with a default list of ACEs when none are supplied" do
      acl = Acl.new
      acl.aces.keys.sort.should == %w{create delete grant read update}
      acl.aces.each { |ace_name, ace| ace.should == Ace.new }
    end

    it "initializes using a provided hash of aces" do
      acl = Acl.new("create"=> {"actors"=>%w{terrence phillip},"groups"=>%w{poison winger}}, "delete"=>{"actors"=>%w{sinatra}, "groups"=>%w{ratpack}})
      acl.aces["create"].should == Ace.new({"actors"=>%w{terrence phillip},"groups"=>%w{poison winger}})
      acl.aces["delete"].should == Ace.new({"actors"=>%w{sinatra}, "groups"=>%w{ratpack}})
    end

    it "accepts that the ACEs are whatever weird object you supplied if you pass a non-hash to new()" do
      acl = Acl.new(:something_weird)
      acl.aces.should == :something_weird
      pending "this behavior is weird, should probably be an Arg error (verify this doesnt break things via features)"
    end
  end

  describe "once initialized with ACEs" do
    before do
      @acl = Acl.new
    end

    it "should converts itself to a nested hash suitable for JSONifying" do
      the_create_ace = Ace.new("actors" => %w{some actors}, "groups" => %w{some groups})
      @acl.add(:create, the_create_ace)
      @acl.for_json.keys.sort.should == %w{create delete grant read update}
      @acl.for_json["create"].should == the_create_ace.for_json
    end

    it "is equal to another object if it responds to for_json and the values returned by for_json are equal" do
      @acl.should == Acl.new

      acl_ace_data = {"create" => {"actors" => %w{list of actors}, "groups" => %w{list of groups}}}

      an_acl_with_an_ace          = Acl.new(acl_ace_data)
      an_acl_with_the_same_ace    = Acl.new(acl_ace_data)
      an_acl_with_a_different_ace = Acl.new(acl_ace_data.merge("update" => %w{some aces}))

      an_acl_with_an_ace.should     == an_acl_with_the_same_ace
      an_acl_with_an_ace.should_not == an_acl_with_a_different_ace
    end

    it "is equal to another object even if the members of ACEs are in different orders" do
      ace_1 = {"create" => {"actors" => ["larry", "moe", "curly"], "groups" => ["stooges", "comedians"]}}
      ace_2 = {"create" => {"actors" => ["moe", "curly", "larry"], "groups" => ["comedians", "stooges"]}}

      ace_1.should_not == ace_2 # as hashes, they SHOULD be unequal, since the arrays are in different orders

      acl_1 = Acl.new(ace_1)
      acl_2 = Acl.new(ace_2)

      acl_1.should == acl_2 # as ACLs, however, those ACE lists should be compared regardless of order.

    end

    it "sets an ace of a given type to a given value" do
      @acl.add(:create, :an_ace)
      @acl.aces["create"].should == :an_ace
    end

    it "silently fails when you try to add an ace that is not one of 'create','read','update','delete','grant'" do
      create_aces_before = @acl.aces["create"].for_json
      lambda {@acl.add(:craete_did_you_see_the_typo, :an_ace)}.should_not raise_error
      @acl.aces["create"].for_json.should == create_aces_before
      pending "*coughs* did you just say to fail silently?"
    end

    it "removes an ace of a given type" do
      @acl.remove("grant")
      @acl.aces["grant"].should be_nil
    end

    it "merges with another ACL by merging individual ACEs" do
      @acl.add(:delete, Ace.new("actors" => %w{foo bar}, "groups" => []))
      other_acl = Acl.new
      other_acl.add(:delete, Ace.new("actors" => %w{bar baz}, "groups" => %w{admins suits}))

      @acl.merge!(other_acl)
      @acl.aces["delete"].should == Ace.new("actors"=>%w{foo bar baz}, "groups" => %w{admins suits})
    end

    describe "converting the ids within its ACEs between auth ids and user ids" do
      before do
        @ace_with_auth_ids = Ace.new("actors" => %w{actor_auth_id_1 actor_auth_id_2 actor_auth_id_3},
                                    "groups" => %w{group_auth_id_1 group_auth_id_2 group_auth_id_3})
        @ace_with_user_ids = Ace.new( "actors" => %w{actor_user_id_1 actor_user_id_2 actor_user_id_3},
                                      "groups" => %w{group_user_id_1 group_user_id_2 group_user_id_3})

      end

      it "converts itself to a nested hash containing ACEs with user ids as hashes" do
        pending("Not running because requires MySQL")
        @acl.add(:create, @ace_with_auth_ids)
        @ace_with_auth_ids.should_receive(:to_user).with(:ORGDB).and_return(@ace_with_user_ids)
        expected = Acl.new
        expected.add(:create, @ace_with_user_ids)
        @acl.to_user(:ORGDB).should == expected
      end

      it "converts itself to a nested hash containing ACES with auth ids as hashes" do
        pending("Not running because requires MySQL")
        @acl.add(:grant, @ace_with_user_ids)

        @ace_with_user_ids.should_receive(:to_auth).with(:ORGDB).and_return(@ace_with_auth_ids)

        expected = Acl.new
        expected.add(:grant, @ace_with_auth_ids)

        @acl.to_auth(:ORGDB).should == expected
      end
    end

  end
end

describe Ace do
  it "should not be equal to another ace that has different groups and actors" do
    an_empty_ace = Ace.new
    a_non_empty_ace = Ace.new({"actors" => ["frankie-muniz"], "groups" => ["heh"]})
    an_empty_ace.should_not == a_non_empty_ace
  end

  it "should be equal to another ace that has the same groups and actors when their actors and groups are empty" do
    an_ace_with_empty_permissions       = Ace.new
    another_ace_with_empty_permissions  = Ace.new
    an_ace_with_empty_permissions.should == another_ace_with_empty_permissions
  end

  describe "once initialized with ACE data" do
    before do
      @ace = Ace.new
    end

    it "adds members to the actors list" do
      @ace.add_actor("Uwe Boll")
      @ace.actors.should == ["Uwe Boll"]
    end

    it "add members to the groups list" do
      @ace.add_group("absurdists")
      @ace.groups.should == ["absurdists"]
    end

    it "removes members from the actors list" do
      @ace.add_actor("Rick Moranis")
      @ace.add_actor("Rick Roll")
      @ace.actors.should have(2).actors
      @ace.remove_actor("Rick Roll")
      @ace.actors.should == ["Rick Moranis"]
    end

    it "removes members from the groups list " do
      @ace.add_group("sophists")
      @ace.groups.should == ["sophists"]
      @ace.remove_group("sophists")
      @ace.groups.should == []
    end

    it "converts itself to a hash suitable for JSONifying" do
      @ace.add_actor("erlang")
      @ace.add_group("admins")
      @ace.for_json.should == {"actors" => ["erlang"], "groups" => ["admins"]}
    end

    it "merges with another ACE, giving a set union of the members w/o duplicates" do
      @ace.add_actor("scala").add_group("stoics")
      other_ace = Ace.new
      other_ace.add_actor("scala").add_group("stoics")
      @ace.add_actor("erlang").add_group("skeptics")
      other_ace.add_actor("io").add_group("realists")
      @ace.merge!(other_ace)
      @ace.should == Ace.new("actors" => %w{scala erlang io}, "groups" => %w{stoics skeptics realists})
    end

    it "transforms its members from auth ids to users ids, given the organization database" do
      @ace.add_group("nominalists")
      @ace.stub(:transform_group_ids).with(%w{nominalists}, :ORGDB, :to_user).and_return(%w{utilitarians})

      @ace.add_actor("beconstructive")
      @ace.stub(:transform_actor_ids).with(%w{beconstructive}, :ORGDB, :to_user).and_return(%w{quietdown})

      @ace.to_user(:ORGDB).should == Ace.new("groups"=>%w{utilitarians},"actors"=>%w{quietdown})
    end

  end
end
