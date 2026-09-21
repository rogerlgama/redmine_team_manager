# frozen_string_literal: true

module RedmineTeamManager
  class TechnicalGroupSynchronizer
    PREFIX = '[TIME] '
    ARCHIVED_PREFIX = '[TIME-ARQUIVADO] '

    def initialize(team)
      @team = team
    end

    def call
      RtmTeam.transaction do
        group = @team.technical_group
        release_stale_name_collision!(group)

        group ||= Group.new
        group.lastname = group_name
        group.save!

        desired_user_ids = @team.team_members.joins(:user).merge(User.active).pluck(:user_id).uniq.sort
        group.user_ids = desired_user_ids
        group.save! if group.changed?

        @team.update_column(:group_id, group.id) if @team.group_id != group.id
        group
      end
    end

    def group_name
      "#{PREFIX}#{@team.name}".truncate(255)
    end

    private

    # Older versions intentionally kept the native technical Group after a Team
    # was deleted so closed issues could preserve their historical assigned_to.
    # Reusing the former Team name could therefore collide with that orphan
    # Group and Redmine would reject Group#save! with "Nome não está disponível".
    #
    # Keep the historical Group, but move its name to an archived namespace.
    # The current Team can then keep/reuse its own technical Principal identity
    # without losing historical issue references.
    def release_stale_name_collision!(current_group)
      collision = Group.where.not(id: current_group&.id)
                       .where('LOWER(lastname) = ?', group_name.downcase)
                       .first
      return unless collision

      owner = RtmTeam.where(group_id: collision.id).where.not(id: @team.id).first
      if owner
        raise StandardError, "A identidade técnica '#{group_name}' já pertence ao Time '#{owner.name}'."
      end

      collision.lastname = unique_archived_name(collision)
      collision.save!
    end

    def unique_archived_name(group)
      original = group.lastname.to_s.sub(/\A#{Regexp.escape(PREFIX)}/i, '')
      base = "#{ARCHIVED_PREFIX}#{original} [##{group.id}]".truncate(255)
      return base unless group_name_taken?(base, excluding_id: group.id)

      sequence = 2
      loop do
        suffix = " (#{sequence})"
        candidate = "#{base.first(255 - suffix.length)}#{suffix}"
        return candidate unless group_name_taken?(candidate, excluding_id: group.id)
        sequence += 1
      end
    end

    def group_name_taken?(name, excluding_id: nil)
      scope = Group.where('LOWER(lastname) = ?', name.downcase)
      scope = scope.where.not(id: excluding_id) if excluding_id
      scope.exists?
    end
  end
end
