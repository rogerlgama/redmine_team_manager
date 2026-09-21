# frozen_string_literal: true

require_relative 'lib/redmine_team_manager'

Redmine::Plugin.register :redmine_team_manager do
  name 'Gestão de Times'
  author 'Roger Gama'
  description 'Gerencia times com papéis individuais e atribuição coletiva sem papel-base para o Time.'
  version '0.3.38'
  url 'https://github.com/rogerlgama/redmine_team_manager'
  requires_redmine version_or_higher: '6.0.0'

  menu :admin_menu,
       :rtm_teams,
       {controller: 'rtm_teams', action: 'index'},
       caption: :label_rtm_team_management,
       html: {class: 'icon icon-group'}

end
