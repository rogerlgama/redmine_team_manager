# frozen_string_literal: true

class RtmTeamMember < ApplicationRecord
  self.table_name = 'rtm_team_members'

  belongs_to :team, class_name: 'RtmTeam', inverse_of: :team_members
  belongs_to :user
  has_many :team_member_roles, class_name: 'RtmTeamMemberRole', foreign_key: :team_member_id, dependent: :destroy, inverse_of: :team_member
  has_many :roles, through: :team_member_roles

  validates :user_id, uniqueness: {scope: :team_id}
  validate :user_must_be_active

  private

  def user_must_be_active
    errors.add(:user, :invalid) if user && !user.active?
  end
end
