require 'httparty'
require 'taskmaster/jira/issue'

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
        if !issue.transition!(target_status)
          errors << issue.key
      end
      errors
    end

    def self.request(verb, url, options = {})
      options.merge!(basic_auth: CREDENTIALS)
      response = HTTParty.send(verb, DOMAIN + url, options)
      if !response.body.nil?
        JSON.parse(response.body)
      elsif verb == :post and response.code >= 200 and response.code <= 204
        # This case covers successful post requests that do not have a response body
        # This is the case for successful issue transitions (and other issues that we
        # haven't bothered to implement)
        # TODO: Maybe pass the entire response object back to the calling method and
        #       have each method decide what to return?
        true
      end
    end
  end
end
