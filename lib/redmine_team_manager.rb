# frozen_string_literal: true

require 'set'

module RedmineTeamManager
  PLUGIN_ID = :redmine_team_manager
end

require_relative 'redmine_team_manager/patches/project_patch'
require_relative 'redmine_team_manager/patches/issue_patch'
require_relative 'redmine_team_manager/patches/members_helper_patch'
require_relative 'redmine_team_manager/patches/application_helper_patch'
require_relative 'redmine_team_manager/patches/members_controller_patch'
require_relative 'redmine_team_manager/hooks/view_listener'
require_relative 'redmine_team_manager/team_report_publisher'

module RedmineTeamManager
  def self.install_patches!
    patch_map = {
      'Project' => RedmineTeamManager::Patches::ProjectPatch,
      'Issue' => RedmineTeamManager::Patches::IssuePatch,
      'MembersHelper' => RedmineTeamManager::Patches::MembersHelperPatch,
      'ApplicationHelper' => RedmineTeamManager::Patches::ApplicationHelperPatch,
      'MembersController' => RedmineTeamManager::Patches::MembersControllerPatch
    }

    patch_map.each do |constant_name, patch|
      target = constant_name.safe_constantize
      next unless target
      target.prepend(patch) unless target < patch
    end
  end
end

# Install immediately when the Redmine constants are already loaded, and also
# on every Rails prepare cycle. This avoids a production-only situation where
# a patch callback is registered after the initial prepare pass and therefore
# does not affect the running process until another reload.
RedmineTeamManager.install_patches!
Rails.application.config.to_prepare { RedmineTeamManager.install_patches! }
