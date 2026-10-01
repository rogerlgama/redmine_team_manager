# frozen_string_literal: true

module RedmineTeamManager
  module Patches
    module IssueQueryPatch
      # The native Redmine filter obtains "Assigned to" values from
      # Query#assigned_to_values, whose principals are project Members.
      # Team technical Groups deliberately are not project Members, so append
      # the Groups linked by RtmProjectTeam without changing native membership.
      def assigned_to_values
        values = Array(super)
        teams = redmine_team_manager_filter_team_groups
        return values if teams.empty?

        existing_ids = values.map { |value| Array(value)[1].to_s }.to_set
        team_values = teams.filter_map do |group|
          next if existing_ids.include?(group.id.to_s)

          status_label =
            if defined?(User::LABEL_BY_STATUS) && User::LABEL_BY_STATUS[group.status]
              l("status_#{User::LABEL_BY_STATUS[group.status]}")
            end

          [group.name, group.id.to_s, status_label]
        end

        # Preserve Redmine's special entries (eg. << me >>) and sort only the
        # principal entries by their displayed name.
        special, principals = values.partition { |value| Array(value)[1].to_s !~ /\A\d+\z/ }
        special + (principals + team_values).sort_by { |value| Array(value)[0].to_s.downcase }
      rescue ActiveRecord::StatementInvalid => e
        Rails.logger.error("[redmine_team_manager] Falha ao incluir Times no filtro Atribuído para: #{e.class}: #{e.message}")
        Array(super)
      end

      private

      def redmine_team_manager_filter_team_groups
        return [] unless defined?(RtmProjectTeam) && defined?(RtmTeam)
        return [] unless RtmProjectTeam.table_exists? && RtmTeam.table_exists?
        return [] unless RtmTeam.column_names.include?('group_id')

        project_ids = redmine_team_manager_filter_project_ids
        return [] if project_ids.empty?

        group_ids = RtmProjectTeam
          .joins(:team)
          .where(rtm_project_teams: {project_id: project_ids, active: true})
          .where(rtm_teams: {active: true})
          .where.not(rtm_teams: {group_id: nil})
          .distinct
          .pluck('rtm_teams.group_id')

        return [] if group_ids.empty?

        Group.where(id: group_ids, status: Principal::STATUS_ACTIVE).to_a.sort
      end

      def redmine_team_manager_filter_project_ids
        projects =
          if project
            [project] + (project.leaf? ? [] : project.descendants.visible.to_a)
          elsif respond_to?(:all_projects, true)
            Array(send(:all_projects))
          else
            Project.visible.to_a
          end

        projects.map(&:id).compact.uniq
      end
    end
  end
end
