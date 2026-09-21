# frozen_string_literal: true

module RedmineTeamManager
  module Patches
    module MembersControllerPatch
      # Server-side protection: even if a technical Team group id is posted
      # manually, the native Members screen cannot add it as a project member.
      def create
        if params[:membership]
          ids = Array.wrap(params[:membership][:user_id] || params[:membership][:user_ids])
          filtered = ids.reject { |id| redmine_team_manager_technical_group_id?(id) }

          if params[:membership].key?(:user_ids)
            params[:membership][:user_ids] = filtered
          elsif params[:membership].key?(:user_id)
            params[:membership][:user_id] = filtered.first
          end
        end

        super
      end

      private

      def redmine_team_manager_technical_group_id?(id)
        return false if id.blank?

        group = Group.find_by(id: id)
        return false unless group

        name = group.name.to_s
        return true if name.start_with?('[TIME] ', '[TIME-ARQUIVADO] ')

        if defined?(RtmTeam) && RtmTeam.respond_to?(:table_exists?) && RtmTeam.table_exists? &&
           RtmTeam.column_names.include?('group_id')
          RtmTeam.where(group_id: group.id).exists?
        else
          false
        end
      rescue ActiveRecord::StatementInvalid
        false
      end
    end
  end
end
