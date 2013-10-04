shared_examples_for 'an authentication strategy' do

  describe 'configuration' do

  end

  describe 'authenticate' do
    it 'should return a user object when authentication succeeds' do
      strategy.authenticate(login, password).should eq user
    end

    it 'should return nil when authentication fails' do
      strategy.authenticate(login, 'FU').should be_nil
    end
  end

  describe 'authenticate?' do
    it 'should return true when authentication succeeds' do
      strategy.authenticate?(login, password).should be_true
    end

    it 'should return false when authentication fails' do
      strategy.authenticate?(login, 'FU').should be_false
    end

    it 'should yield to an optional block when authentication succeeds' do
      block_checker = nil
      strategy.authenticate?(login, password) do
        block_checker = 88
      end
      block_checker.should == 88
    end

    it 'should not yield to an optional block when authentication fails' do
      block_checker = nil
      strategy.authenticate?(login, 'FU') do
        block_checker = 88
      end
      block_checker.should be_nil
    end
  end

  describe 'authenticate!' do
    it 'should return a user object when authentication succeeds' do
      strategy.authenticate!(login, password).should eq user
    end

    it 'should return raise an AccessDeniedException when authentication fails' do
      lambda{ strategy.authenticate!(login, 'FU') }.should \
        raise_error(Opscode::Authentication::AccessDeniedException)
    end
  end
end
