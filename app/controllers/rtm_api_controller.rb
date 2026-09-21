# frozen_string_literal: true

class RtmApiController < ApplicationController
  accept_api_auth :teams, :team_members, :team_projects

  before_action :require_admin
  before_action :find_team, only: %i[team_members team_projects]

  def teams
    teams = RtmTeam
            .left_joins(:team_members, :project_teams)
            .group('rtm_teams.id')
            .order(Arel.sql('LOWER(rtm_teams.name) ASC'))
            .select(
              'rtm_teams.*',
              'COUNT(DISTINCT rtm_team_members.id) AS api_members_count',
              'COUNT(DISTINCT rtm_project_teams.id) AS api_projects_count'
            )

    render json: {
      teams: teams.map { |team| team_payload(team) },
      total_count: teams.size
    }
  end

  def team_members
    team_members = @team.team_members
                        .includes(:user, :roles)
                        .sort_by { |team_member| team_member.user.name.to_s.downcase }

    render json: {
      team: basic_team_payload(@team),
      members: team_members.map { |team_member| member_payload(team_member) },
      total_count: team_members.size
    }
  end

  def team_projects
    project_teams = @team.project_teams
                         .includes(:project)
                         .references(:project)
                         .order('projects.name ASC')

    render json: {
      team: basic_team_payload(@team),
      projects: project_teams.map { |project_team| project_payload(project_team) },
      total_count: project_teams.size
    }
  end

  private

  def find_team
    @team = RtmTeam.find(params[:id])
  end

  def basic_team_payload(team)
    {
      id: team.id,
      name: team.name,
      active: team.active?
    }
  end

  def team_payload(team)
    basic_team_payload(team).merge(
      description: team.description,
      members_count: team.read_attribute('api_members_count').to_i,
      projects_count: team.read_attribute('api_projects_count').to_i,
      created_at: team.created_at,
      updated_at: team.updated_at
    )
  end

  def member_payload(team_member)
    user = team_member.user

    {
      id: user.id,
      login: user.login,
      name: user.name,
      active: user.active?,
      roles: team_member.roles.sort_by { |role| role.name.to_s.downcase }.map do |role|
        {
          id: role.id,
          name: role.name
        }
      end
    }
  end

  def project_payload(project_team)
    project = project_team.project

    {
      id: project.id,
      identifier: project.identifier,
      name: project.name,
      active: project.active?,
      team_link_active: project_team.active?,
      linked_at: project_team.created_at,
      last_synced_at: project_team.last_synced_at
    }
  end
end
