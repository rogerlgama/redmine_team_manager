# frozen_string_literal: true

module RedmineTeamManager
  class TeamSynchronizer
    Result = Struct.new(:added_members, :added_roles, :removed_roles, :removed_members, :unchanged_roles, :warnings, keyword_init: true)

    def initialize(project_team:, actor: User.current)
      @project_team = project_team
      @project = project_team.project
      @team = project_team.team
      @actor = actor
    end

    def call
      ensure_team_unlocked!
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = nil

      RtmProjectTeam.transaction do
        synchronize_technical_group!
        preview = SynchronizationPreview.new(@project_team).call
        counters = {added_members: 0, added_roles: 0, removed_roles: 0, removed_members: 0, unchanged_roles: preview.unchanged.size}

        preview.additions.each {|entry| add_role(entry, counters)}
        preview.removals.each {|entry| remove_role(entry[:origin], counters)}

        @project_team.update!(last_synced_at: Time.current, active: true)
        result = Result.new(**counters, warnings: preview.warnings)
        create_log!('success', result, started)
      end

      result
    rescue StandardError => e
      create_failure_log(e, started)
      raise
    end

    def unlink!
      ensure_team_unlocked!
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = nil

      RtmProjectTeam.transaction do
        ensure_group_has_no_assigned_issues!
        counters = {added_members: 0, added_roles: 0, removed_roles: 0, removed_members: 0, unchanged_roles: 0}
        @project_team.role_origins.includes(:member, :role).to_a.each {|origin| remove_role(origin, counters)}
        result = Result.new(**counters, warnings: [])
        create_log!('unlinked', result, started)
        @project_team.destroy!
      end

      result
    rescue StandardError => e
      create_failure_log(e, started)
      raise
    end

    private

    def ensure_team_unlocked!
      return if @team.active?

      raise StandardError, I18n.t(:error_rtm_team_locked)
    end

    def synchronize_technical_group!
      @group = @team.synchronize_technical_group!
    end

    # A technical group may remain assigned to closed issues for historical
    # purposes. Unlinking is blocked only when an OPEN issue in this project
    # is still assigned to the Team, because after unlinking the Team stops
    # being an assignable principal for new/active work in this project.
    def ensure_group_has_no_assigned_issues!
      group = @team.technical_group
      return unless group

      open_status_ids = IssueStatus.where(is_closed: false).select(:id)
      assigned_count = Issue.where(
        project_id: @project.id,
        assigned_to_id: group.id,
        status_id: open_status_ids
      ).count

      return if assigned_count.zero?

      raise StandardError, I18n.t(:error_rtm_group_has_assigned_issues, count: assigned_count)
    end

    def add_role(entry, counters)
      user = entry[:user]
      role = entry[:role]
      team_member = entry[:team_member]
      member = Member.find_by(project_id: @project.id, user_id: user.id)

      unless member
        member = Member.new(project: @project, principal: user)
        member.roles = [role]
        member.save!
        counters[:added_members] += 1
        counters[:added_roles] += 1
        managed = true
      else
        preexisting = member.roles.exists?(role.id)
        unless preexisting
          MemberRole.create!(member: member, role: role)
          counters[:added_roles] += 1
        end
        managed = !preexisting || RtmProjectTeamRoleOrigin.where(member_id: member.id, role_id: role.id, managed: true).exists?
      end

      RtmProjectTeamRoleOrigin.create!(project_team: @project_team, team_member: team_member, member: member, role: role, managed: managed)
    end

    def remove_role(origin, counters)
      # An origin may survive after its Redmine Member was removed manually or by
      # an older plugin version. During unlink we must clean that stale origin
      # instead of dereferencing a nil Member.
      member_id = origin.member_id
      role_id = origin.role_id
      member = member_id && Member.find_by(id: member_id)

      unless member
        origin.destroy!
        return
      end

      should_remove_role = origin.managed &&
                           !RtmProjectTeamRoleOrigin.where(member_id: member_id, role_id: role_id)
                                                     .where.not(id: origin.id).exists?
      origin.destroy!

      if should_remove_role
        removed_count = member.member_roles.where(role_id: role_id).destroy_all.size
        counters[:removed_roles] += 1 if removed_count.positive?
      end

      # The Member might have been removed by a callback while deleting the last
      # role. Re-read it safely before deciding whether the membership itself can
      # be deleted.
      member = Member.find_by(id: member_id)
      return unless member

      if member.roles.empty? && !RtmProjectTeamRoleOrigin.where(member_id: member_id).exists?
        member.destroy!
        counters[:removed_members] += 1
      end
    end

    def create_log!(status, result, started)
      RtmSyncLog.create!(project_team: @project_team, project: @project, team: @team, user: @actor, status: status,
                         added_members: result.added_members, added_roles: result.added_roles,
                         removed_roles: result.removed_roles, removed_members: result.removed_members,
                         unchanged_roles: result.unchanged_roles,
                         details: {warnings: result.warnings, technical_group_id: @team.group_id, roleless_assignment: true},
                         duration_ms: elapsed_ms(started))
    end

    def create_failure_log(error, started)
      RtmSyncLog.create!(project_team: @project_team.persisted? ? @project_team : nil, project_id: @project.id,
                         team_id: @team.id, user: @actor, status: 'failed',
                         error_message: "#{error.class}: #{error.message}", duration_ms: elapsed_ms(started))
    rescue StandardError
      Rails.logger.error("[redmine_team_manager] Failed to record sync error: #{error.message}")
    end

    def elapsed_ms(started)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    end
  end
end
