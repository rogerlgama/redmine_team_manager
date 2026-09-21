# frozen_string_literal: true

class RemoveLeaderFromRtmTeamMembers < ActiveRecord::Migration[7.2]
  def up
    remove_column :rtm_team_members, :leader if column_exists?(:rtm_team_members, :leader)
  end

  def down
    add_column :rtm_team_members, :leader, :boolean, null: false, default: false unless column_exists?(:rtm_team_members, :leader)
  end
end
