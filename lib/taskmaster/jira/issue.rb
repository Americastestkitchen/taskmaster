module Taskmaster
  module JIRA
    class Issue
      attr_accessor :id, :title
      def initialize(data)
        @id = data['key']
        @title = data['fields']['summary']
      end

      def comment(text)
        Taskmaster::JIRA.request(:post, "issue/#{@id}/comment", body: {body: text}.to_json, headers: {'Content-Type' => 'application/json'})
      end

      def transition!(transition_name)
        transitions = Taskmaster::JIRA.request(:get, "issue/#{@id}/transitions?expand=transition.fields")
        target_transition = transitions['transitions'].detect{|t| t['name'] =~ /#{Regexp.quote(transition_name)}/i}
        if target_transition.nil?
          return false
        end
        Taskmaster::JIRA.request(:post, "issue/#{@id}/transitions", body: {transition: {id: target_transition['id']}}.to_json, headers: {'Content-Type' => 'application/json'})
      end
    end
  end
end
