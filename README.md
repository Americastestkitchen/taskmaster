Taskmaster expects that you have a `.taskmaster.yaml` file in your project root. Thus far what's required is just for JIRA:

    jira:
     domain: <https domain>
     username: <jira username>
     password: <jira password>

You can then do stuff like this:

    issue = Taskmaster::JIRA.find('A-123')
    issue.comment('I approve')
    issue.transition!('approved') # case-insensitive match on transition names for the project's workflow

Or maybe this if we wanted to move stuff in bulk:

    Taskmaster::JIRA.transition_all_by_status('In QA', 'qa approved', project='BC')
