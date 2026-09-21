# Redmine Team Manager

Redmine plugin for managing reusable teams, assigning individual roles to each team member, and making the team available as a collective issue assignee.

Portuguese documentation: [README.pt-BR.md](README.pt-BR.md)

## Features

- Central team administration outside individual projects.
- One or more Redmine roles per team member.
- Bulk linking of a team to multiple projects.
- Collective issue assignment through a native Redmine group.
- Team members keep only their individually configured project roles.
- Technical team groups are hidden from the native project-member picker.
- Project overview displays the members of each linked team.
- JSON API for teams, members, roles, and linked projects.
- Textile report publishing to a selected Redmine wiki page.
- Searchable selectors for users, roles, and projects, without external JavaScript dependencies.

The plugin does not modify Redmine core files.

## How it works

Each team has a native Redmine group named `[TIME] Team name`. The group provides Redmine's standard collective-assignment and notification behavior, but it is not added to the project as a member and receives no base role.

The plugin links the team to projects separately and adds only linked technical groups to `Issue#assignable_users`. Individual users receive the roles configured for them in the team.

Unlinking is refused while open issues in the project are assigned to the team. Historical native groups are preserved during a full rollback so existing issue references are not broken.

## Requirements

- Redmine 6.0 or newer
- Ruby and Rails versions supported by the installed Redmine version
- A database supported by Redmine

The release was validated against Redmine 6.0.6, Ruby 3.3.8, Rails 7.2.2.1, and PostgreSQL. The wiki report also includes compatibility handling for MySQL installations that use three-byte `utf8`.

## Installation

1. Back up the Redmine database and files.
2. Copy the plugin to `REDMINE_ROOT/plugins/redmine_team_manager`.
3. From the Redmine root, run:

   ```bash
   bundle exec rake redmine:plugins:migrate NAME=redmine_team_manager RAILS_ENV=production
   ```

4. Restart Redmine.
5. Open **Administration → Team Management** (or **Gestão de Times** in Portuguese).

## Upgrade

1. Back up the database and the existing plugin directory.
2. Replace the plugin files, keeping the directory name `redmine_team_manager`.
3. Run the migration command shown above.
4. Restart Redmine.

When upgrading from 0.2.0, migration 004 removes the former base-role memberships while preserving individual memberships. Migration 006 reactivates legacy teams created before the active-state controls were removed.

## REST API

The endpoints accept Redmine API authentication and require an administrator account:

```text
GET /api/team_manager/teams.json
GET /api/team_manager/teams/:id/members.json
GET /api/team_manager/teams/:id/projects.json
```

## Wiki report

From **Administration → Team Management**, choose **Generate report**, a destination project, and a wiki page. The plugin creates or updates the page with a team summary and a table containing each member, role, and linked project.

## Tests

Run from the Redmine root:

```bash
bundle exec rails test plugins/redmine_team_manager/test RAILS_ENV=test
```

## Uninstall

To roll back the plugin tables:

```bash
bundle exec rake redmine:plugins:migrate NAME=redmine_team_manager VERSION=0 RAILS_ENV=production
```

Then remove `plugins/redmine_team_manager` and restart Redmine. Native technical groups are deliberately retained to preserve historical issue assignments.

## License

Copyright holders license this project under the GNU General Public License version 2 or, at your option, any later version (`GPL-2.0-or-later`). See [LICENSE](LICENSE).

## Author

Roger Gama
