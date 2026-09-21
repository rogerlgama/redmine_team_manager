# frozen_string_literal: true

class RtmProjectTeamsController < ApplicationController
  before_action :require_admin
  before_action :find_project
  before_action :find_project_team, only: %i[show preview sync destroy]
  before_action :ensure_linked_team_unlocked, only: %i[sync destroy]

  def index
    @project_teams = RtmProjectTeam.where(project: @project).includes(team: {team_members: %i[user roles]}).order('rtm_teams.name')
    @available_teams = RtmTeam.active.where.not(id: @project_teams.select(:team_id)).sorted
  end

  def show
    @preview = RedmineTeamManager::SynchronizationPreview.new(@project_team).call
  end

  def new
    redirect_to action: :index
  end

  def create
    team = RtmTeam.find(params[:team_id])
    unless team.active?
      flash[:error] = l(:error_rtm_team_locked)
      redirect_to project_rtm_project_teams_path(@project)
      return
    end

    @project_team = RtmProjectTeam.new(project: @project, team: team, created_by: User.current)
    if @project_team.save
      RedmineTeamManager::TeamSynchronizer.new(project_team: @project_team).call
      flash[:notice] = l(:notice_rtm_team_linked)
      redirect_to project_rtm_project_team_path(@project, @project_team)
    else
      flash[:error] = @project_team.errors.full_messages.to_sentence
      redirect_to project_rtm_project_teams_path(@project)
    end
  rescue StandardError => e
    @project_team.destroy if @project_team&.persisted? && !@project_team.role_origins.exists?
    flash[:error] = e.message
    redirect_to project_rtm_project_teams_path(@project)
  end

  def preview
    @preview = RedmineTeamManager::SynchronizationPreview.new(@project_team).call
    render :show
  end

  def sync
    result = RedmineTeamManager::TeamSynchronizer.new(project_team: @project_team).call
    flash[:notice] = "#{l(:notice_rtm_sync_complete)} +#{result.added_roles} / -#{result.removed_roles} papéis."
    redirect_to project_rtm_project_team_path(@project, @project_team)
  rescue StandardError => e
    flash[:error] = e.message
    redirect_to project_rtm_project_team_path(@project, @project_team)
  end

  def destroy
    RedmineTeamManager::TeamSynchronizer.new(project_team: @project_team).unlink!
    flash[:notice] = l(:notice_rtm_team_unlinked)
    redirect_to project_rtm_project_teams_path(@project)
  rescue StandardError => e
    flash[:error] = e.message
    redirect_to project_rtm_project_team_path(@project, @project_team)
  end

  private

  def find_project
    @project = Project.find(params[:project_id])
  end

  def find_project_team
    @project_team = RtmProjectTeam.find_by!(id: params[:id], project_id: @project.id)
  end

  def ensure_linked_team_unlocked
    return if @project_team.team.active?

    flash[:error] = l(:error_rtm_team_locked)
    redirect_to project_rtm_project_team_path(@project, @project_team)
  end

end
