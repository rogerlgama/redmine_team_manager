# frozen_string_literal: true

require File.expand_path('../../../../test/test_helper', __FILE__)

class RtmSmokeTest < Redmine::IntegrationTest
  test 'plugin models load' do
    assert RtmTeam.table_exists?
    assert RtmProjectTeam.table_exists?
  end
end
