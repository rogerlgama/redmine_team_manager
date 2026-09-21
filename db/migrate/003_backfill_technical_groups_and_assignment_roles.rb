# frozen_string_literal: true

class BackfillTechnicalGroupsAndAssignmentRoles < ActiveRecord::Migration[7.2]
  class MigrationProjectTeam < ActiveRecord::Base
    self.table_name = 'rtm_project_teams'
  end

  def up
    MigrationProjectTeam.reset_column_information
    fallback_role_id = select_value("SELECT id FROM roles WHERE builtin = 0 ORDER BY position, id LIMIT 1")

    if MigrationProjectTeam.where(assignment_role_id: nil).exists?
      raise 'Nenhum papel atribuível foi localizado para migrar os vínculos existentes.' unless fallback_role_id

      MigrationProjectTeam.where(assignment_role_id: nil).update_all(assignment_role_id: fallback_role_id)
    end

    change_column_null :rtm_project_teams, :assignment_role_id, false
  end

  def down
    change_column_null :rtm_project_teams, :assignment_role_id, true
  end
end
