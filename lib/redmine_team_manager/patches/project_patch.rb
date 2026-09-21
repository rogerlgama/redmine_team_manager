# frozen_string_literal: true

module RedmineTeamManager
  module Patches
    module ProjectPatch
      def assignable_users(tracker = nil)
        principals = super(tracker).to_a
        (principals + redmine_team_manager_assignable_team_groups).uniq.sort
      end

      def redmine_team_manager_assignable_team_groups
        return [] unless defined?(RtmProjectTeam) && defined?(RtmTeam)
        return [] unless RtmProjectTeam.table_exists? && RtmTeam.table_exists?
        return [] unless RtmTeam.column_names.include?('group_id')

        group_ids = RtmProjectTeam
          .joins(:team)
          .where(rtm_project_teams: {project_id: id, active: true})
          .where(rtm_teams: {active: true})
          .where.not(rtm_teams: {group_id: nil})
          .distinct
          .pluck('rtm_teams.group_id')

        Group.where(id: group_ids, status: Principal::STATUS_ACTIVE).to_a
      rescue ActiveRecord::StatementInvalid => e
        Rails.logger.error("[redmine_team_manager] Falha ao obter Times atribuíveis do projeto #{id}: #{e.class}: #{e.message}")
        []
      end
    end
  end
end
