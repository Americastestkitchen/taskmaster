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

      def deploy()
        puts "= Deploying #{@app_name} (#{Taskmaster::Heroku.current_branch})..."
        puts `git push #{@app_name} #{Taskmaster::Heroku.current_branch}:master -f`
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

      def is_prod?
        /#{Taskmaster::Config.heroku.production_pattern}/.match(@app_name)
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
