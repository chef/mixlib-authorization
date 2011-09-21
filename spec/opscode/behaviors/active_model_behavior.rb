# namaste: https://gist.github.com/639089
shared_examples_for "an active model" do
  require 'test/unit/assertions'
  require 'active_model/lint'

  include ActiveModel::Lint::Tests
  include Test::Unit::Assertions

  # to_s is to support ruby-1.9
  ActiveModel::Lint::Tests.public_instance_methods.map{|m| m.to_s}.grep(/^test/).each do |m|
    example m.gsub('_',' ') do
      send m
    end
  end

  def model
    subject
  end
end

