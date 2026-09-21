# frozen_string_literal: true

class RtmTeam < ApplicationRecord
  self.table_name = 'rtm_teams'

  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :technical_group, class_name: 'Group', foreign_key: :group_id, optional: true
  has_many :team_members, class_name: 'RtmTeamMember', foreign_key: :team_id, dependent: :destroy, inverse_of: :team
  has_many :project_teams, class_name: 'RtmProjectTeam', foreign_key: :team_id, dependent: :restrict_with_error, inverse_of: :team

  validates :name, presence: true, length: {maximum: 248}, uniqueness: {case_sensitive: false}

  scope :active, -> { where(active: true) }
  scope :sorted, -> { order(Arel.sql('LOWER(name) ASC')) }

  after_commit :synchronize_technical_group_after_save, on: %i[create update]

  def synchronize_technical_group!
    RedmineTeamManager::TechnicalGroupSynchronizer.new(self).call
  end

  private

  def synchronize_technical_group_after_save
    synchronize_technical_group!
  rescue StandardError => e
    Rails.logger.error("[redmine_team_manager] Falha ao sincronizar grupo técnico do time #{id}: #{e.class}: #{e.message}")
  end
end
