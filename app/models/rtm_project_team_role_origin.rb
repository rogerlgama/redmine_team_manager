# frozen_string_literal: true

class RtmProjectTeamRoleOrigin < ApplicationRecord
  self.table_name = 'rtm_project_team_role_origins'

  belongs_to :project_team, class_name: 'RtmProjectTeam', inverse_of: :role_origins
  belongs_to :team_member, class_name: 'RtmTeamMember'
  belongs_to :member
  belongs_to :role

  validates :role_id, uniqueness: {scope: %i[project_team_id team_member_id]}
end
