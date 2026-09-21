# frozen_string_literal: true

module RedmineTeamManager
  module Patches
    module IssuePatch
      # Redmine 6.0 validates assigned_to through Issue#assignable_users.
      # The Team technical Group deliberately has no Member/Role, so it is
      # appended directly from the plugin's Team <-> Project association.
      def assignable_users
        principals = Array(super)
        return principals if project.nil?

        groups = redmine_team_manager_assignable_team_groups_for_issue
        (principals + groups).uniq.sort
      end

      private

      def redmine_team_manager_assignable_team_groups_for_issue
        return [] unless defined?(RtmProjectTeam) && defined?(RtmTeam)
        return [] unless RtmProjectTeam.table_exists? && RtmTeam.table_exists?
        return [] unless RtmTeam.column_names.include?('group_id')

        group_ids = RtmProjectTeam
          .joins(:team)
          .where(rtm_project_teams: {project_id: project.id, active: true})
          .where(rtm_teams: {active: true})
          .where.not(rtm_teams: {group_id: nil})
          .distinct
          .pluck('rtm_teams.group_id')

        return [] if group_ids.empty?

        # Do not depend on Setting.issue_group_assignment?: Times are an
        # explicit plugin concept and are allowed as collective assignees even
        # though they do not have a project Role.
        Group.where(id: group_ids, status: Principal::STATUS_ACTIVE).to_a
      rescue ActiveRecord::StatementInvalid => e
        Rails.logger.error("[redmine_team_manager] Falha ao obter Times atribuíveis da tarefa: #{e.class}: #{e.message}")
        []
      end
    end
  end
end
