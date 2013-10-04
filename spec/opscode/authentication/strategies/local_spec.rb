require 'spec_helper'

describe Opscode::Authentication::Strategies::Local do

  include_context "authentication strategies"

  let!(:strategy) do
    Opscode::Authentication::Strategies::Local.new(user_mapper)
  end

  it_should_behave_like 'an authentication strategy'

end
