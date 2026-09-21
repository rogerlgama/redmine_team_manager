# frozen_string_literal: true

module RedmineTeamManager
  class TeamReportPublisher
    def initialize(project:, page_title:, actor:)
      @project = project
      @page_title = page_title.to_s.strip
      @actor = actor
    end

    def call
      raise ArgumentError, I18n.t(:error_rtm_report_page_required) if @page_title.blank?
      raise ArgumentError, I18n.t(:error_rtm_report_wiki_unavailable) unless @project.wiki.present?

      page = nil
      WikiPage.transaction do
        page = find_or_create_page!
        publish_content!(page)
      end
      page
    end

    private

    def find_or_create_page!
      wiki = @project.wiki
      page = wiki.pages.where('LOWER(title) = ?', @page_title.downcase).first
      return page if page

      wiki.pages.create!(title: @page_title)
    end

    def publish_content!(page)
      content = page.content || WikiContent.new(page: page)
      content.text = build_textile
      content.author = @actor
      content.comments = I18n.t(:text_rtm_report_update_comment)
      content.save!
    end

    def build_textile
      teams = RtmTeam.includes(
        team_members: [:user, :roles],
        project_teams: :project
      ).sorted.to_a

      lines = []
      lines << 'h1. Gestão de Times'
      lines << ''
      lines << "_#{I18n.t(:label_rtm_report_generated_at)}: #{I18n.l(Time.current, format: :long)}_"
      lines << ''
      lines << 'h2. &#x1F4CC; Times'
      lines << ''
      lines << '|_.Time|_.Integrantes|_.Projetos|'

      teams.each do |team|
        lines << "|#{textile_escape(team.name)}|=.#{team.team_members.size}|=.#{team.project_teams.size}|"
      end

      lines << '|- Nenhum time cadastrado -|=.0|=.0|' if teams.empty?

      teams.each_with_index do |team, team_index|
        lines << '' if team_index.zero?
        lines << '|\3{border-bottom:1px solid #dddddd;border-right:1px solid #dddddd;}. |' unless team_index.zero?
        lines << "|\\3<{background-color:#eeeeee;}. &#x1F4CB; *#{textile_escape(team.name)}*|"
        lines << '|_. _Integrante_|_. _Papel_|_. _Projeto associado_|'

        members = team.team_members
                      .select { |tm| tm.user.present? }
                      .sort_by { |tm| tm.user.name.to_s.downcase }
        projects = team.project_teams
                       .map(&:project)
                       .compact
                       .sort_by { |project| project.name.to_s.downcase }

        if members.any?
          members.each_with_index do |member, index|
            role_names = member.roles
                               .sort_by { |role| role.name.to_s.downcase }
                               .map(&:name)
                               .join(', ')

            if index.zero?
              lines << "|#{textile_escape(member.user.name)}|#{textile_escape(role_names)}|/#{members.size}=. {{collapse(Lista de projetos)"
              if projects.any?
                projects.each { |project| lines << textile_escape(project.name) }
              else
                lines << 'Nenhum projeto associado.'
              end
              lines << '}} |'
            else
              lines << "|#{textile_escape(member.user.name)}|#{textile_escape(role_names)}|"
            end
          end
        else
          lines << '|- Nenhum integrante cadastrado -| |/1=. {{collapse(Lista de projetos)'
          if projects.any?
            projects.each { |project| lines << textile_escape(project.name) }
          else
            lines << 'Nenhum projeto associado.'
          end
          lines << '}} |'
        end
      end

      textile = lines.join("\n")
      if textile.include?("|_.Situação|") || textile.match?(/\|=.*Ativo\|/)
        raise "Relatório de Times contém a coluna Situação legada"
      end
      textile
    end

    def textile_escape(value)
      value.to_s.gsub(/[^\u0000-\uFFFF]/) { |char| "&#x#{char.ord.to_s(16).upcase};" }.gsub('|', '&#124;').gsub("\r", ' ').gsub("\n", ' ')
    end
  end
end
