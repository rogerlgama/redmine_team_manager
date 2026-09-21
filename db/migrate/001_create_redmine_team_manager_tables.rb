# frozen_string_literal: true

class CreateRedmineTeamManagerTables < ActiveRecord::Migration[7.2]
  def change
    create_table :rtm_teams do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true
      t.integer :created_by_id
      t.timestamps null: false
    end
    add_index :rtm_teams, 'LOWER(name)', unique: true, name: 'idx_rtm_teams_lower_name'
    add_index :rtm_teams, :created_by_id

    create_table :rtm_team_members do |t|
      t.references :team, null: false, foreign_key: {to_table: :rtm_teams}, index: false
      t.integer :user_id, null: false
      t.timestamps null: false
    end
    add_index :rtm_team_members, %i[team_id user_id], unique: true
    add_index :rtm_team_members, :user_id

    create_table :rtm_team_member_roles do |t|
      t.references :team_member, null: false, foreign_key: {to_table: :rtm_team_members}, index: false
      t.integer :role_id, null: false
      t.timestamps null: false
    end
    add_index :rtm_team_member_roles, %i[team_member_id role_id], unique: true, name: 'idx_rtm_team_member_roles_unique'
    add_index :rtm_team_member_roles, :role_id

    create_table :rtm_project_teams do |t|
      t.integer :project_id, null: false
      t.references :team, null: false, foreign_key: {to_table: :rtm_teams}, index: false
      t.integer :created_by_id
      t.datetime :last_synced_at
      t.boolean :active, null: false, default: true
      t.timestamps null: false
    end
    add_index :rtm_project_teams, %i[project_id team_id], unique: true
    add_index :rtm_project_teams, :team_id
    add_index :rtm_project_teams, :created_by_id

    create_table :rtm_project_team_role_origins do |t|
      t.references :project_team, null: false, foreign_key: {to_table: :rtm_project_teams}, index: false
      t.references :team_member, null: false, foreign_key: {to_table: :rtm_team_members}, index: false
      t.integer :member_id, null: false
      t.integer :role_id, null: false
      t.boolean :managed, null: false, default: false
      t.timestamps null: false
    end
    add_index :rtm_project_team_role_origins,
              %i[project_team_id team_member_id role_id],
              unique: true,
              name: 'idx_rtm_role_origins_unique'
    add_index :rtm_project_team_role_origins, %i[member_id role_id], name: 'idx_rtm_role_origins_member_role'

    create_table :rtm_sync_logs do |t|
      t.references :project_team, null: true, foreign_key: {to_table: :rtm_project_teams}, index: false
      t.integer :project_id, null: false
      t.integer :team_id, null: false
      t.integer :user_id
      t.string :status, null: false
      t.integer :added_members, null: false, default: 0
      t.integer :added_roles, null: false, default: 0
      t.integer :removed_roles, null: false, default: 0
      t.integer :removed_members, null: false, default: 0
      t.integer :unchanged_roles, null: false, default: 0
      t.text :details
      t.text :error_message
      t.integer :duration_ms
      t.timestamps null: false
    end
    add_index :rtm_sync_logs, :project_team_id
    add_index :rtm_sync_logs, %i[project_id team_id]
    add_index :rtm_sync_logs, :user_id
  end
end
