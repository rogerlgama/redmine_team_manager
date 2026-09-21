# frozen_string_literal: true

module RedmineTeamManager
  module Patches
    module MembersHelperPatch
      # Keeps technical Team identities out of the native
      # Settings > Members > New member selector. Team membership is managed
      # exclusively from Administration > Team Management.
      def render_principals_for_new_members(project, limit = 100)
        scope = Principal.active.visible.sorted.not_member_of(project).like(params[:q])
        scope = scope.where.not(id: redmine_team_manager_technical_group_ids)

        principal_count = scope.count
        principal_pages = Redmine::Pagination::Paginator.new principal_count, limit, params['page']
        principals = scope.offset(principal_pages.offset).limit(principal_pages.per_page).to_a

        s =
          content_tag(
            'div',
            content_tag(
              'div',
              principals_check_box_tags('membership[user_ids][]', principals),
              id: 'principals'
            ),
            class: 'objects-selection'
          )

        links =
          pagination_links_full(
            principal_pages,
            principal_count,
            per_page_links: false
          ) do |text, parameters, options|
            link_to(
              text,
              autocomplete_project_memberships_path(
                project,
                parameters.merge(q: params[:q], format: 'js')
              ),
              remote: true
            )
          end

        s + content_tag('span', links, class: 'pagination')
      end

      private

      def redmine_team_manager_technical_group_ids
        ids = []

        if defined?(RtmTeam) && RtmTeam.column_names.include?('group_id')
          ids.concat(RtmTeam.where.not(group_id: nil).pluck(:group_id))
        end

        # Archived technical identities are deliberately retained so old issue
        # references remain valid. They must not become manually manageable
        # through the native membership dialog either.
        ids.concat(
          Group.where("lastname LIKE ? OR lastname LIKE ?", '[TIME]%', '[TIME-ARQUIVADO]%').pluck(:id)
        )

        ids.compact.uniq
      end
    end
  end
end
