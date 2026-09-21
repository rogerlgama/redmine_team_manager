# frozen_string_literal: true

class MakeTeamsRolelessAssignable < ActiveRecord::Migration[7.2]
  def up
    if table_exists?(:rtm_project_team_group_role_origins)
      select_all('SELECT id, member_id, role_id, managed FROM rtm_project_team_group_role_origins').each do |origin|
        member_id = origin['member_id'].to_i
        role_id = origin['role_id'].to_i
        managed = ActiveModel::Type::Boolean.new.cast(origin['managed'])

        if managed
          execute <<~SQL.squish
            DELETE FROM member_roles
            WHERE member_id = #{quote(member_id)} AND role_id = #{quote(role_id)}
          SQL
        end

        remaining = select_value("SELECT COUNT(*) FROM member_roles WHERE member_id = #{quote(member_id)}").to_i
        execute("DELETE FROM members WHERE id = #{quote(member_id)}") if remaining.zero?
      end
      drop_table :rtm_project_team_group_role_origins
    end

    remove_index :rtm_project_teams, :assignment_role_id if index_exists?(:rtm_project_teams, :assignment_role_id)
    remove_column :rtm_project_teams, :assignment_role_id if column_exists?(:rtm_project_teams, :assignment_role_id)
  end

  def down
    add_column :rtm_project_teams, :assignment_role_id, :integer unless column_exists?(:rtm_project_teams, :assignment_role_id)
    add_index :rtm_project_teams, :assignment_role_id unless index_exists?(:rtm_project_teams, :assignment_role_id)

    unless table_exists?(:rtm_project_team_group_role_origins)
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
end
