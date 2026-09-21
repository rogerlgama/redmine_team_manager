# Relatório administrativo de Times publicado em uma página Wiki.
get 'admin/teams/report',
    to: 'rtm_team_reports#new',
    as: :new_rtm_team_report
post 'admin/teams/report',
     to: 'rtm_team_reports#create',
     as: :rtm_team_report

# frozen_string_literal: true

resources :rtm_teams, path: 'admin/teams' do
  member do
    post :copy
    post :add_member
    post :link_project
    delete 'projects/:project_id', action: :unlink_project, as: :unlink_project
    delete 'members/:team_member_id', action: :remove_member, as: :remove_member
    patch 'members/:team_member_id/roles', action: :update_member_roles, as: :update_member_roles
  end
end

resources :projects, only: [] do
  resources :rtm_project_teams, path: 'teams', only: %i[index show new create destroy] do
    member do
      get :preview
      post :sync
    end
  end
end

# API REST do plugin.
get 'api/team_manager/teams',
    to: 'rtm_api#teams',
    defaults: {format: :json}

get 'api/team_manager/teams/:id/members',
    to: 'rtm_api#team_members',
    defaults: {format: :json},
    constraints: {id: /\d+/}

get 'api/team_manager/teams/:id/projects',
    to: 'rtm_api#team_projects',
    defaults: {format: :json},
    constraints: {id: /\d+/}
