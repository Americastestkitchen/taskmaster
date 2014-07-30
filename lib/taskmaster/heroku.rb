require 'taskmaster/heroku/app'

module Taskmaster
  module Heroku
    def self.current_branch
      @current_branch ||= `git symbolic-ref HEAD --short`.chomp
    end

    def self.app_name
      # Heroku apps are limited to 30 char.
      @app_name ||= current_branch.downcase[0...27] + '-qa'
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
        Bundler.with_clean_env do
          %x[
            foreman run bundle exec rake RAILS_ENV=production RAILS_GROUPS=assets assets:precompile
            mv public/assets/manifest-*.json public/assets/manifest-1.json
            git commit public/assets/manifest-1.json -m 'Assets Manifest updated. [ci skip]'
          ]
        end
      end
      @deploy_prepared = true
    end

    def self.deploy(*app_names, standard_master=false)
      app_names.map do |remote|
        Thread.new {
          app = App.new(remote)
          app.deploy(standard_master)
        }
      end.each{ |t| t.join }
    end
  end
end
