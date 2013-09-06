shared_context 'authentication strategies' do

  let(:login){ 'opscode' }
  let(:password){ 'pedant' }

  let(:user) do
    user = Opscode::Models::User.new
    user.username = login
    user.password = password
    user
  end

  let(:user_mapper) do
    mapper = double(Opscode::Mappers::User)
    mapper.stub(:find_by_username).and_return(user)
    mapper
  end

end
