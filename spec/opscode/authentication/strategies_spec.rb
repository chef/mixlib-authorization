require File.expand_path('../../spec_helper', __FILE__)

describe Opscode::Authentication::Strategies do
  it "should allow me to get access to a particular strategy" do
    class FooStrategy < Opscode::Authentication::Strategies::Base
    end
    Opscode::Authentication::Strategies.add(:foo, FooStrategy)
    strategy = Opscode::Authentication::Strategies[:foo]
    strategy.should_not be_nil
    strategy.ancestors.should include(Opscode::Authentication::Strategies::Base)
  end

  it "should not allow a strategy that does not extend from Opscode::Authentication::Strategies::Base" do
    class BazStrategy
    end
    lambda do
      Opscode::Authentication::Strategies.add(:foo, BazStrategy)
    end.should raise_error
  end

  it "should load load builtin strategies when requested" do
    Opscode::Authentication::Strategies.builtin!
    Opscode::Authentication::Strategies[:local].should_not be_nil
    Opscode::Authentication::Strategies[:ldap].should_not be_nil
  end
end
