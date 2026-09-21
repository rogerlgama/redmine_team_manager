# frozen_string_literal: true

require File.expand_path('../../../../test/test_helper', __FILE__)

class RtmTeamTest < ActiveSupport::TestCase
  test 'requires a name' do
    team = RtmTeam.new
    assert_not team.valid?
  end
end
