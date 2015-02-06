require 'taskmaster/heroku/app'

module Taskmaster
  module Heroku
    def self.app_name
      # Heroku apps are limited to 30 char.
      @app_name ||= Taskmaster.current_branch.downcase[0...27].gsub(/[^\w\d-]/, "") + '-qa'
    end

    def self.credentials
      Bundler.with_clean_env do
        {
          email: `heroku auth:whoami`,
          password: `heroku auth:token`
        }
      end
    end

    def self.prepare_deploy
      @deploy_prepared ||= false
      if !@deploy_prepared
        puts '= Precompiling assets...'

        # Remove all other asset manifest files before running the precompile,
        # but only if there are any, in order to ensure that the asset manifest updates
        if !Dir.glob('public/assets/manifest-*').empty?
          Bundler.with_clean_env do
            `rm public/assets/manifest-*`
          end
        end

        Bundler.with_clean_env do
          %x[
            foreman run bundle exec rake RAILS_ENV=production RAILS_GROUPS=assets assets:precompile
            mv public/assets/manifest-*.json public/assets/manifest-1.json
          ]
        end
        Taskmaster.repo.add('public/assets/manifest-1.json')
        Taskmaster.repo.commit('Assets Manifest updated. [ci skip]')
      end
      @deploy_prepared = true
    end

    def self.deploy(*app_names, standard_master: false)
      # Do this check in the main deploy because it will be the same for all apps
      if standard_master
        App.check(Taskmaster.current_branch != 'master', "Deploying non-master branch #{Taskmaster.current_branch}")
      end

      # Initialize the apps so that more checks can be made
      apps = app_names.map{|app| App.new(app)}

      # Check if any of the apps need a migration
      # Doing these checks before Threads rear their ugly heads makes our lives easier
      apps.each{|app| App.check(app.needs_migration?, "#{app.app_name} needs a migration")}

      # Check if this is a prod deployment
      is_prod_deploy = apps.any? { |app| app.is_prod? }

      # If it is, get a list of tickets that are going to be deployed for confirmation
      if is_prod_deploy
        tickets = []
          Taskmaster::Config.jira.project_keys.each { |project| 
            tickets << Taskmaster::JIRA.find_by_status('Merged To Master', project).map{|issue| 
              issue.key + " : " + issue.title
            }
          }
          tickets.flatten!
          if tickets.empty?
            App.check(true, "No tickets found in Merged to Master")
          else
            puts "\nThe following tickets are about to be deployed: "
            puts '* ' + tickets.join("\n* ")
            App.check(true, "The above tickets will be deployed")
          end
      end

      if Taskmaster::Config::deploy.needs_prepare
          Taskmaster::Heroku.prepare_deploy
      end

      apps.map do |app|
        Thread.new {
          app.deploy()
        }
      end.each{ |t| t.join }

      errors = []
      if is_prod_deploy
        Taskmaster::Config.jira.project_keys.each { |key|
          errors << Taskmaster::JIRA.transition_all_by_status('Merged To Master', 'Deployed', key)
        }
        errors.flatten!
        if errors.empty?
          puts "\nCongratulations! All #{Taskmaster::Config.jira.project_keys.join("/")} tickets in Merged To Master have been moved to Deployed in JIRA!"
          puts "\n Make sure to move any tickets from other projects manually, if there are any!"
        else
          puts "\nWARNING! Not all tickets in Merged To Master were successfully moved to Deployed!"
          puts "\nMake sure to manually move the following tickets: "
          puts '* ' + errors.join("\n* ")
        end
      end

      if block_given?
        yield
      end
    end
  end
end
