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

          %x[heroku config:set #{config.join(' ')} -a #{@app_name}]
        end
      end

      def deploy(standard_master = false)
        if standard_master
          branch = Taskmaster::Heroku.current_branch
          check(branch != 'master', "Deploying non-master branch #{branch}")
        end

        check(needs_migration?, "#{@app_name} needs a migration")

        Taskmaster::Heroku.prepare_deploy

        if /#{Taskmaster::Config.heroku.production_pattern}/.match(apps.first)
          Taskmaster::JIRA.transition_all_by_status('Ready To Merge', 'Merged To Master', project=Taskmaster::Config.jira.project_key)
        end
      end

      def destroy!(credentials = nil)
        credentials ||= Taskmaster::Heroku.credentials
        response = HTTParty.delete("https://api.heroku.com/apps/#{@app_name}", basic_auth: credentials)
        response.code == 200
      end

      def self.needs_migration?
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
