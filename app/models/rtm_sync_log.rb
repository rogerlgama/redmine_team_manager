# frozen_string_literal: true

class RtmSyncLog < ApplicationRecord
  self.table_name = 'rtm_sync_logs'

  belongs_to :project_team, class_name: 'RtmProjectTeam', optional: true, inverse_of: :sync_logs
  belongs_to :project
  belongs_to :team, class_name: 'RtmTeam'
  belongs_to :user, optional: true

  serialize :details, coder: JSON

  scope :recent, -> { order(created_at: :desc) }
end
