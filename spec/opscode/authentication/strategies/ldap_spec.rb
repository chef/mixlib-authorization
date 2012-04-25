require File.expand_path('../../../spec_helper', __FILE__)

describe Opscode::Authentication::Strategies::LDAP do

  include_context "authentication strategies"

  let(:default_base) { "dc=opscode,dc=com" }
  let(:default_options) { {:base => default_base} }
  let(:user) { OpenStruct.new(:uid => 'foo') }

  let(:connection) do
    c = Net::LDAP.new
    c.stub!(:bind).with({:method=>:simple,
      :username=>"uid=#{login},dc=opscode,dc=com", :password=>"pedant"}).and_return(true)
    c.stub!(:bind).with({:method=>:simple,
      :username=>"uid=#{login},dc=opscode,dc=com", :password=>"FU"}).and_return(false)
    c.stub!(:search).with(any_args()).and_yield(user)
    c
  end

  let!(:strategy) do
    s = Opscode::Authentication::Strategies::LDAP.new(user_mapper, default_options)
    s.stub!(:connection).and_return(connection)
    s
  end

  it_behaves_like "an authentication strategy"

  it "should yield the LDAP entry on successful authentication" do
    strategy.authenticate?(login, password) do |entry|
      entry.should eq user
    end
  end

  context "configuration" do
    it "should set some sane defaults" do
      strategy.port.should == 389
      strategy.uid.should == 'uid'
      strategy.bind_login_format == "%{uid}=%{login},%{base}"
    end

    it "should allow customizaiton of the bind login format" do
      s = Opscode::Authentication::Strategies::LDAP.new(user_mapper,
            default_options.merge(:bind_login_format => "FAKE-%{uid}-FORMAT-%{login}-YO-%{base}"))
      s.stub!(:connection).and_return(connection)
      auth_hash = {:method=>:simple, :username=>"FAKE-uid-FORMAT-#{login}-YO-#{default_base}", :password=>"pedant"}
      connection.should_receive(:bind).with(auth_hash)
      s.authenticate(login, password)
    end
  end

  context "upstream LDAP system is unavailable" do
    let!(:strategy) do
      s = Opscode::Authentication::Strategies::LDAP.new(user_mapper)
      s
    end

    it "should raise a Opscode::Authentication::RemoteAuthenticationException" do
      lambda{ strategy.authenticate(login, password) }.should \
        raise_error{ Opscode::Authentication::RemoteAuthenticationException }
    end
  end
end
