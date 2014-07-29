require 'httparty'
require 'taskmaster/jira/issue'
require 'pry'

module Taskmaster
  module JIRA
    DOMAIN = Taskmaster::Config.jira.domain
    CREDENTIALS = {
      username: Taskmaster::Config.jira.username,
      password: Taskmaster::Config.jira.password
    }

    def self.find(key)
      response = request(:get, "issue/#{key}")
      if response.has_key?('errorMessages')
        nil
      else
        Issue.new(response)
      end
    end

    def self.extract_issue_key(str, *projects)
      key = /(#{projects.join('|')})-\d+/i.match(str).to_s
      if key.empty?
        nil
      else
        key.upcase
      end
    end

    def self.search(jql)
      response = request(:get, 'search', query: {jql: jql})
      response['issues'].map{|issue| Issue.new(issue)}
    end

    def self.find_by_status(status, project = nil)
      query = "status = '#{status}'"
      if !project.nil?
        query += " AND project = #{project}"
      end
      search(query) 
    end

    def self.transition_all_by_status(current_status, target_status, project = nil)
      errors = []
      find_by_status(current_status, project).each do |issue|
        if issue.transition!(target_status).nil?
          errors << issue.key
        end
      end
      errors
    end

    def self.request(verb, url, options = {})
      options.merge!(basic_auth: CREDENTIALS)
      response = HTTParty.send(verb, DOMAIN + url, options)

      # When we POST the transition change, there is no response body (probably)
      # Thus, when we make this request, this method should return "true" on a successful
      # POST, for proper error handling
      if verb == :post and response.code >= 200 and response.code <= 209
        return true
      elsif verb == :get and !response.body.nil? and response.code >= 200 and response.code <= 209
        return JSON.parse(response.body)
      end
    end
  end
end
