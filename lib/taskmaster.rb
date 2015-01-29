require 'git'

module Taskmaster
  def self.repo
    @repo || Git.open('.')
  end

  def self.current_branch
    repo.lib.branch_current
  end
end

require "taskmaster/config"
require "taskmaster/ducktape"
require "taskmaster/heroku"
require "taskmaster/jira"
require "taskmaster/version"
