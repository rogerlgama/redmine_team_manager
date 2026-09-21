# frozen_string_literal: true

class RtmProjectTeam < ApplicationRecord
  self.table_name = 'rtm_project_teams'

  belongs_to :project
  belongs_to :team, class_name: 'RtmTeam', inverse_of: :project_teams
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :role_origins, class_name: 'RtmProjectTeamRoleOrigin', foreign_key: :project_team_id, dependent: :destroy, inverse_of: :project_team
  has_many :sync_logs, class_name: 'RtmSyncLog', foreign_key: :project_team_id, dependent: :nullify, inverse_of: :project_team

  validates :team_id, uniqueness: {scope: :project_id}
  validate :team_must_be_unlocked, on: :create

  private

  def team_must_be_unlocked
    errors.add(:team, I18n.t(:error_rtm_team_locked)) if team && !team.active?
  end
end
