# frozen_string_literal: true

class RtmTeamMemberRole < ApplicationRecord
  self.table_name = 'rtm_team_member_roles'

  belongs_to :team_member, class_name: 'RtmTeamMember', inverse_of: :team_member_roles
  belongs_to :role

  validates :role_id, uniqueness: {scope: :team_member_id}
  validate :role_must_be_assignable

  private

  def role_must_be_assignable
    errors.add(:role, :invalid) if role && !role.builtin.zero?
  end
end
