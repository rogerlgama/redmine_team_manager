# frozen_string_literal: true

class RtmTeamsController < ApplicationController
  layout 'admin'
  before_action :require_admin
  before_action :find_team, only: %i[
    show edit update destroy copy add_member remove_member
    update_member_roles link_project unlink_project
  ]

  def index
    @teams = RtmTeam.includes(:team_members, :project_teams).sorted
  end

  def show
    @users = User.active.sorted.where.not(id: @team.team_members.select(:user_id))
    @roles = Role.givable.sorted
    @project_teams = @team.project_teams.includes(:project).order('projects.name')
    linked_project_ids = @project_teams.map(&:project_id)
    @available_projects = Project.active.where.not(id: linked_project_ids).order(:name)
  end

  def new
    @team = RtmTeam.new(active: true)
  end

  def create
    @team = RtmTeam.new(team_params.merge(active: true))
    @team.created_by = User.current
    if @team.save
      flash[:notice] = l(:notice_rtm_team_created)
      redirect_to rtm_team_path(@team)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @team.update(team_params.merge(active: true))
      flash[:notice] = l(:notice_rtm_team_updated)
      redirect_to rtm_team_path(@team)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @team.project_teams.exists?
      flash[:error] = l(:error_rtm_team_in_use)
      redirect_to rtm_team_path(@team)
    else
      @team.destroy!
      flash[:notice] = l(:notice_rtm_team_deleted)
      redirect_to rtm_teams_path
    end
  end

  def copy
    copied_team = nil
    RtmTeam.transaction do
      copied_team = RtmTeam.create!(
        name: unique_copy_name(@team.name),
        description: @team.description,
        active: true,
        created_by: User.current
      )

      @team.team_members.includes(:team_member_roles).each do |source_member|
        copied_member = copied_team.team_members.create!(user_id: source_member.user_id)
        source_member.team_member_roles.each do |source_role|
          copied_member.team_member_roles.create!(role_id: source_role.role_id)
        end
      end
    end

    copied_team.synchronize_technical_group!
    flash[:notice] = l(:notice_rtm_team_copied)
    redirect_to rtm_team_path(copied_team)
  rescue ActiveRecord::RecordInvalid => e
    flash[:error] = e.record.errors.full_messages.to_sentence
    redirect_to rtm_teams_path
  end

  def add_member
    team_member = @team.team_members.build(user_id: params[:user_id])
    role_ids = Array(params[:role_ids]).reject(&:blank?).map(&:to_i)
    if params[:user_id].blank?
      flash[:error] = l(:error_rtm_select_user)
    elsif role_ids.empty?
      flash[:error] = l(:error_rtm_select_role)
    elsif team_member.save
      role_ids.each {|role_id| team_member.team_member_roles.create!(role_id: role_id)}
      @team.synchronize_technical_group!
      synchronize_linked_projects!
      flash[:notice] = l(:notice_rtm_member_added)
    else
      flash[:error] = team_member.errors.full_messages.to_sentence
    end
    redirect_to rtm_team_path(@team)
  end

  def remove_member
    team_member = @team.team_members.includes(:team_member_roles).find(params[:team_member_id])

    # Keep the TeamMember alive while synchronizing. Project role-origin
    # records reference it and need the original team_member_id to safely
    # remove only the permissions managed by this Team.
    RtmTeam.transaction do
      team_member.team_member_roles.destroy_all
      synchronize_linked_projects!
      team_member.destroy!
      @team.synchronize_technical_group!
    end

    flash[:notice] = l(:notice_rtm_member_removed)
    redirect_to rtm_team_path(@team)
  rescue StandardError => e
    Rails.logger.error("[redmine_team_manager] Falha ao remover integrante #{params[:team_member_id]} do time #{@team.id}: #{e.class}: #{e.message}")
    flash[:error] = e.message
    redirect_to rtm_team_path(@team)
  end

  def update_member_roles
    team_member = @team.team_members.find(params[:team_member_id])
    role_ids = Array(params[:role_ids]).reject(&:blank?).map(&:to_i)
    if role_ids.empty?
      flash[:error] = l(:error_rtm_select_role)
    else
      RtmTeamMemberRole.transaction do
        team_member.team_member_roles.where.not(role_id: role_ids).destroy_all
        (role_ids - team_member.role_ids).each {|role_id| team_member.team_member_roles.create!(role_id: role_id)}
      end
      @team.synchronize_technical_group!
      synchronize_linked_projects!
      flash[:notice] = l(:notice_rtm_roles_updated)
    end
    redirect_to rtm_team_path(@team)
  end

  def link_project
    project_ids = Array(params[:project_ids].presence || params[:project_id]).reject(&:blank?).map(&:to_i).uniq
    if project_ids.empty?
      flash[:error] = l(:error_rtm_select_project)
      redirect_to rtm_team_path(@team)
      return
    end

    projects = Project.active.where(id: project_ids).index_by(&:id)
    missing_ids = project_ids - projects.keys
    raise ActiveRecord::RecordNotFound, l(:error_rtm_invalid_project_selection) if missing_ids.any?

    RtmProjectTeam.transaction do
      project_ids.each do |project_id|
        project_team = RtmProjectTeam.create!(
          project: projects.fetch(project_id),
          team: @team,
          created_by: User.current
        )
        RedmineTeamManager::TeamSynchronizer.new(project_team: project_team, actor: User.current).call
      end
    end

    flash[:notice] = l(project_ids.one? ? :notice_rtm_team_linked : :notice_rtm_team_linked_multiple, count: project_ids.size)
    redirect_to rtm_team_path(@team)
  rescue StandardError => e
    flash[:error] = e.message
    redirect_to rtm_team_path(@team)
  end

  def unlink_project
    project_id = params[:project_id].presence
    raise ActiveRecord::RecordNotFound, 'Projeto não informado para desvinculação do Time.' unless project_id

    project_team = @team.project_teams.find_by(project_id: project_id)
    raise ActiveRecord::RecordNotFound, 'O Time não está vinculado ao projeto informado.' unless project_team

    RedmineTeamManager::TeamSynchronizer.new(project_team: project_team, actor: User.current).unlink!
    flash[:notice] = l(:notice_rtm_team_unlinked)
    redirect_to rtm_team_path(@team)
  rescue StandardError => e
    flash[:error] = e.message
    redirect_to rtm_team_path(@team)
  end

  private

  def find_team
    @team = RtmTeam.find(params[:id])
  end

  def team_params
    params.require(:rtm_team).permit(:name, :description)
  end

  def synchronize_linked_projects!
    @team.project_teams.includes(:project).find_each do |project_team|
      RedmineTeamManager::TeamSynchronizer.new(project_team: project_team, actor: User.current).call
    end
  end

  def unique_copy_name(source_name)
    base = l(:label_rtm_copy_name, name: source_name)
    base = base.first(248)
    return base unless RtmTeam.where('LOWER(name) = ?', base.downcase).exists?

    sequence = 2
    loop do
      suffix = " (#{sequence})"
      candidate = "#{base.first(248 - suffix.length)}#{suffix}"
      return candidate unless RtmTeam.where('LOWER(name) = ?', candidate.downcase).exists?

      sequence += 1
    end
  end
end
