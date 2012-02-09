require File.expand_path('../../../spec_helper', __FILE__)

describe Opscode::Authentication::Strategies::LDAP do

  include_context "authentication strategies"

  let(:user) do
    OpenStruct.new(:uid => 'foo')
  end

  let(:connection) do
    c = Net::LDAP.new
    c.stub!(:bind).with({:method=>:simple, :username=>"opscode", :password=>"pedant"}).and_return(true)
    c.stub!(:bind).with({:method=>:simple, :username=>"opscode", :password=>"FU"}).and_return(false)
    c.stub!(:search).with(any_args()).and_yield(user)
    c
  end

  let!(:strategy) do
    s = Opscode::Authentication::Strategies::LDAP.new(user_mapper)
    s.stub!(:connection).and_return(connection)
    s
  end

  it_behaves_like 'an authentication strategy'

  it "should yield the LDAP entry on successful authentication" do
    strategy.authenticate?(login, password) do |entry|
      entry.should eq user
    end
  end

  context 'upstream LDAP system is unavailable' do
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
