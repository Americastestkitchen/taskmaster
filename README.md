Taskmaster expects that you have a `.taskmaster.yaml` file in your project root. Thus far what's required is just for JIRA:

    jira:
     domain: <https domain>
     username: <jira username>
     password: <jira password>
     project_keys: <array of project shorthands applicable to the project (EV, RTB, CS, MG, NPS, ETC, BRB, BBQ)

You can then do stuff like this:

    issue = Taskmaster::JIRA.find('A-123')
    issue.comment('I approve')
    issue.transition!('approved') # case-insensitive match on transition names for the project's workflow

Or maybe this if we wanted to move stuff in bulk:

    Taskmaster::JIRA.transition_all_by_status('In QA', 'qa approved', project='BC')

HOOKS:

We now also keep git hooks in Taskmaster!

Git hooks live on the client side, so after checking them out, you will have to create a symbolic link in your project's .git/hooks directory

For example, if we have ~/cio and ~/taskmaster, we would run:

`ln -s ~/taskmaster/hooks/* ~/cio/.git/hooks/`

Make sure to replace those example paths with your actual paths!

The current hooks have the following functionality:

commit-msg: 
- Automatically prepends the ticket associated with your branch, if there is one, to your commit messages (Note: this will only work in projects with .taskmaster.yaml files)
