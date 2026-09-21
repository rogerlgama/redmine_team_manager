# frozen_string_literal: true

class AddTechnicalGroupsToRedmineTeamManager < ActiveRecord::Migration[7.2]
  def change
    add_column :rtm_teams, :group_id, :integer
    add_index :rtm_teams, :group_id, unique: true

    add_column :rtm_project_teams, :assignment_role_id, :integer
    add_index :rtm_project_teams, :assignment_role_id

    create_table :rtm_project_team_group_role_origins do |t|
      t.references :project_team, null: false, foreign_key: {to_table: :rtm_project_teams}, index: {unique: true, name: 'idx_rtm_project_group_origin_unique'}
      t.integer :member_id, null: false
      t.integer :role_id, null: false
      t.boolean :managed, null: false, default: false
      t.timestamps null: false
    end
    add_index :rtm_project_team_group_role_origins, :member_id
    add_index :rtm_project_team_group_role_origins, :role_id
  end
end
