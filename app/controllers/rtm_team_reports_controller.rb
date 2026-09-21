# frozen_string_literal: true

class RtmTeamReportsController < ApplicationController
  layout 'admin'
  before_action :require_admin

  def new
    load_projects
    @project_id = params[:project_id]
    @page_title = params[:page_title].presence || 'Relatorio_Gestao_de_Times'
  end

  def create
    @project_id = params[:project_id]
    @page_title = params[:page_title].to_s.strip

    project = Project.find_by(id: @project_id)
    unless project
      flash.now[:error] = l(:error_rtm_report_select_project)
      load_projects
      render :new, status: :unprocessable_entity
      return
    end

    if @page_title.blank?
      flash.now[:error] = l(:error_rtm_report_page_required)
      load_projects
      render :new, status: :unprocessable_entity
      return
    end

    unless project.module_enabled?(:wiki) && project.wiki.present?
      flash.now[:error] = l(:error_rtm_report_wiki_unavailable)
      load_projects
      render :new, status: :unprocessable_entity
      return
    end

    page = RedmineTeamManager::TeamReportPublisher.new(
      project: project,
      page_title: @page_title,
      actor: User.current
    ).call

    flash[:notice] = l(:notice_rtm_report_generated, page: page.title, project: project.name)
    redirect_to controller: 'wiki', action: 'show', project_id: project.identifier, id: page.title
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:error] = e.record.errors.full_messages.to_sentence
    load_projects
    render :new, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("[redmine_team_manager] Falha ao gerar relatório de Times: #{e.class}: #{e.message}")
    flash.now[:error] = e.message
    load_projects
    render :new, status: :unprocessable_entity
  end

  private

  def load_projects
    @projects = Project.active.order(:name).select do |project|
      project.module_enabled?(:wiki) && project.wiki.present?
    end
  end
end
