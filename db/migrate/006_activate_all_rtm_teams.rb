# frozen_string_literal: true

class ActivateAllRtmTeams < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:rtm_teams) && column_exists?(:rtm_teams, :active)

    execute "UPDATE rtm_teams SET active = TRUE WHERE active = FALSE OR active IS NULL"
  end

  def down
    # The previous blocked state cannot be reconstructed reliably.
  end
end
