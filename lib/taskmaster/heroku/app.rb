require 'httparty'

module Taskmaster
  module Heroku
    class App
      attr_reader :current_branch, :app_name

      def initialize(app_name)
        @app_name = app_name
      end

      def create
        Bundler.with_clean_env do
          %x[heroku apps:create #{@app_name} --remote #{@app_name}]

          addons = Taskmaster::Config.heroku.addons

          addons.each do |addon|
            %x[heroku addons:add #{addon} -a #{@app_name}]
          end
        end
      end

      def copy_config(source_app)
        Bundler.with_clean_env do
          config = `heroku config -a #{source_app}`.split("\n")
          config.shift

          config = config.map do |config_line|
            (config_var, config_value) = config_line.split(/:\s+/)
            "#{config_var}='#{config_value}'"
          end

          # Set up the hosts so that the links will work
          config << "QA_HOST=" + @app_name + ".herokuapp.com"

          %x[heroku config:set #{config.join(' ')} -a #{@app_name}]
        end
      end

      def deploy(standard_master = false)
        if standard_master
          branch = Taskmaster::Heroku.current_branch
          self.class.check(branch != 'master', "Deploying non-master branch #{branch}")
        end

        self.class.check(needs_migration?, "#{@app_name} needs a migration")
        is_prod = /#{Taskmaster::Config.heroku.production_pattern}/.match(@app_name)

        if is_prod
          tickets = []
          Taskmaster::Config.jira.project_keys.each { |project| 
            tickets = Taskmaster::JIRA.find_by_status('Merged To Master', project).map(&:key)
          }
          tickets.flatten!
          if tickets.empty?
            self.class.check(true, "No tickets found in Merged to Master")
          else
            puts "\nThe following tickets are about to be deployed: "
            puts "#{'* ' + tickets.join('\n* ')}"
            sefl.class.check(true, "The above tickets will be deployed")
          end
        end


        if Taskmaster::Config::deploy.needs_prepare
          Taskmaster::Heroku.prepare_deploy
        end

        puts "= Deploying #{@app_name} (#{Taskmaster::Heroku.current_branch})..."
        puts `git push #{@app_name} #{Taskmaster::Heroku.current_branch}:master -f`

        errors = []
        if is_prod
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
            failed_tickets = '* ' + errors.join("\n* ")
            puts "#{failed_tickets}"
          end
        end
      end

      def destroy!(credentials = nil)
        credentials ||= Taskmaster::Heroku.credentials
        response = HTTParty.delete("https://api.heroku.com/apps/#{@app_name}", basic_auth: credentials)
        response.code == 200
      end

      def needs_migration?
        files = `git diff #{@app_name}/master..#{Taskmaster::Heroku.current_branch} --name-only`
        Taskmaster::Config.git.migration_dirs.any?{|dirname| files =~ /#{Regexp.quote(dirname)}/}
      end

      private

      def self.check(condition, message)
        if condition
          print "#{message}, continue? (y/n) "
          if $stdin.gets.downcase.strip != 'y'
            puts "Aborted!"
            exit
          end
        end
      end
    end
  end
end
