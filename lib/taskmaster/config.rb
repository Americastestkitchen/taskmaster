require 'yaml'
require 'hashie'

module Taskmaster
  Config = Hashie::Mash.new(YAML.load(File.open('.taskmaster.yaml')))
end
