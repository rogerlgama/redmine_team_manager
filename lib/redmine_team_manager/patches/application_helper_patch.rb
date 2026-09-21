# frozen_string_literal: true

module RedmineTeamManager
  module Patches
    module ApplicationHelperPatch

      # Redmine's issue form renders the assignee list through this helper.
      # Add linked Team identities here as a UI safety net. The Issue patch
      # remains authoritative for validation when the issue is saved.
      def principals_options_for_select(collection, selected = nil)
        if defined?(@issue) && @issue && @issue.respond_to?(:project) && @issue.project &&
           @issue.project.respond_to?(:redmine_team_manager_assignable_team_groups)
          collection = (Array(collection) + @issue.project.redmine_team_manager_assignable_team_groups).uniq.sort
        end
        super(collection, selected)
      end

      # Final rendering guard for the native
      # Settings > Members > New member selector.
      #
      # MembersHelper filters the relation before pagination. This second layer
      # filters the principals immediately before Redmine renders the checkboxes,
      # covering both the initial modal and AJAX autocomplete responses even if
      # another plugin replaces/wraps MembersHelper#render_principals_for_new_members.
      def principals_check_box_tags(name, principals)
        principals = Array(principals)

        if redmine_team_manager_native_member_selector?
          principals = principals.reject do |principal|
            redmine_team_manager_technical_principal?(principal)
          end
        end

        super(name, principals)
      end

      private

      def redmine_team_manager_native_member_selector?
        controller.respond_to?(:controller_name) &&
          controller.controller_name == 'members' &&
          %w[new autocomplete].include?(controller.action_name)
      end

      def redmine_team_manager_technical_principal?(principal)
        return false unless principal.is_a?(Group)

        group_name = principal.name.to_s
        return true if group_name.start_with?('[TIME] ', '[TIME-ARQUIVADO] ')

        redmine_team_manager_registered_technical_group_ids.include?(principal.id)
      end

      def redmine_team_manager_registered_technical_group_ids
        @redmine_team_manager_registered_technical_group_ids ||= begin
          if defined?(RtmTeam) && RtmTeam.respond_to?(:table_exists?) && RtmTeam.table_exists? &&
             RtmTeam.column_names.include?('group_id')
            RtmTeam.where.not(group_id: nil).pluck(:group_id).compact.to_set
          else
            Set.new
          end
        rescue ActiveRecord::StatementInvalid
          Set.new
        end
      end
    end
  end
end
