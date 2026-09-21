# frozen_string_literal: true

module RedmineTeamManager
  class SynchronizationPreview
    Result = Struct.new(:additions, :removals, :unchanged, :warnings, keyword_init: true)

    def initialize(project_team)
      @project_team = project_team
      @project = project_team.project
      @team = project_team.team
    end

    def call
      desired = desired_pairs
      existing_origins = @project_team.role_origins.includes(:team_member, :role, member: :principal)
      existing = existing_origins.index_by {|origin| [origin.team_member_id, origin.role_id]}

      additions = desired.reject {|key, _| existing.key?(key)}.values
      removals = existing.reject {|key, _| desired.key?(key)}.values.map do |origin|
        {user: origin.team_member.user, role: origin.role, origin: origin}
      end
      unchanged = desired.select {|key, _| existing.key?(key)}.values
      warnings = @team.team_members.select {|tm| !tm.user.active?}.map {|tm| "#{tm.user.name}: usuário inativo"}

      Result.new(additions: additions, removals: removals, unchanged: unchanged, warnings: warnings)
    end

    private

    def desired_pairs
      @team.team_members.includes(:user, :roles).each_with_object({}) do |team_member, memo|
        next unless team_member.user.active?

        team_member.roles.each do |role|
          memo[[team_member.id, role.id]] = {team_member: team_member, user: team_member.user, role: role}
        end
      end
    end
  end
end
