# Gestão de Times para Redmine

Plugin para administrar times reutilizáveis, atribuir papéis individuais aos integrantes e disponibilizar o time como responsável coletivo por tarefas.

## Recursos

- Administração central de times, independente de um projeto específico.
- Um ou vários papéis do Redmine por integrante.
- Vinculação de um time a vários projetos em uma única operação.
- Atribuição coletiva de tarefas por meio de um grupo nativo do Redmine.
- Preservação exclusiva dos papéis individuais de cada integrante.
- Ocultação dos grupos técnicos no seletor nativo de membros do projeto.
- Exibição dos integrantes dos times na visão geral do projeto.
- API JSON para times, integrantes, papéis e projetos vinculados.
- Publicação de relatório Textile em uma página Wiki escolhida.
- Seletores pesquisáveis de usuários, papéis e projetos, sem bibliotecas JavaScript externas.

O plugin não modifica arquivos do núcleo do Redmine.

## Funcionamento

Cada time possui um grupo nativo chamado `[TIME] Nome do time`. Esse grupo fornece a atribuição coletiva e as notificações padrão do Redmine, mas não é incluído como membro do projeto e não recebe papel-base.

O vínculo do time com o projeto é mantido separadamente. Somente os grupos técnicos vinculados são acrescentados a `Issue#assignable_users`; os usuários recebem os papéis configurados individualmente no time.

A desvinculação é recusada enquanto houver tarefas abertas do projeto atribuídas ao time. Em um rollback completo, os grupos técnicos são preservados para não quebrar referências históricas.

## Requisitos e compatibilidade

- Redmine 6.0 ou superior.
- Ruby e Rails compatíveis com a versão instalada do Redmine.
- Banco de dados suportado pelo Redmine.

A versão foi validada com Redmine 6.0.6, Ruby 3.3.8, Rails 7.2.2.1 e PostgreSQL. O relatório Wiki inclui tratamento para instalações MySQL configuradas com `utf8` de três bytes.

## Instalação e atualização

1. Faça backup do banco e dos arquivos do Redmine.
2. Copie o plugin para `REDMINE_ROOT/plugins/redmine_team_manager`.
3. Na raiz do Redmine, execute:

   ```bash
   bundle exec rake redmine:plugins:migrate NAME=redmine_team_manager RAILS_ENV=production
   ```

4. Reinicie o Redmine.
5. Acesse **Administração → Gestão de Times**.

Ao atualizar, substitua os arquivos mantendo exatamente o nome da pasta e execute novamente a migração. A migration 004 trata instalações da versão 0.2.0; a migration 006 reativa times legados anteriores à retirada do controle de situação.

## API REST

Os endpoints aceitam autenticação pela API do Redmine e exigem uma conta administradora:

```text
GET /api/team_manager/teams.json
GET /api/team_manager/teams/:id/members.json
GET /api/team_manager/teams/:id/projects.json
```

## Relatório Wiki

Em **Administração → Gestão de Times**, use **Gerar relatório**, escolha o projeto e a página Wiki. O plugin cria ou atualiza a página com o resumo dos times e uma tabela de integrantes, papéis e projetos vinculados.

## Testes

Na raiz do Redmine:

```bash
bundle exec rails test plugins/redmine_team_manager/test RAILS_ENV=test
```

## Desinstalação

```bash
bundle exec rake redmine:plugins:migrate NAME=redmine_team_manager VERSION=0 RAILS_ENV=production
```

Depois, remova `plugins/redmine_team_manager` e reinicie o Redmine. Os grupos técnicos nativos são mantidos para preservar atribuições históricas.

## Licença e autor

Licenciado sob GNU GPL versão 2 ou posterior (`GPL-2.0-or-later`). Consulte [LICENSE](LICENSE).

Autor: Roger Gama.
