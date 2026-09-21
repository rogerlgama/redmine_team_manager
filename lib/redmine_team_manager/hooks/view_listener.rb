# frozen_string_literal: true

module RedmineTeamManager
  module Hooks
    class ViewListener < Redmine::Hook::ViewListener
      render_on :view_projects_show_right,
                partial: 'rtm_hooks/project_overview_team'

      render_on :view_layouts_base_html_head,
                partial: 'rtm_hooks/html_head'
    end
  end
end
