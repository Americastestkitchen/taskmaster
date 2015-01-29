require 'httparty'

module Taskmaster
  module Ducktape
    DOMAIN = Taskmaster::Config.ducktape.domain
    SLUG = Taskmaster::Config.ducktape.slug

    def self.endpoint
      "#{DOMAIN}repos/#{SLUG}/releases"
    end

    def self.tag_release
      sha = Taskmaster.repo.revparse('HEAD')
      response = HTTParty.post(endpoint, body: {sha: sha}.to_json, headers: {'Content-Type' => 'application/json', 'Accept' => 'application/json'})
      release = JSON.parse(response.body)
      release_name = release['Name']
      Taskmaster.repo.add_tag(release_name.downcase.gsub(/ /, '-'))
      Taskmaster.repo.push('origin', 'master', tags: true)
    end
  end
end
