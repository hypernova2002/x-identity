# Purges a deleted project once its restore period has passed. Does nothing if it was restored.
class ProjectPurgeJob < ApplicationJob
  queue_as :maintenance
  limits_concurrency to: 1, key: ->(arguments) { arguments[:project_id] }

  # @param project_id [Integer]
  def perform(project_id:)
    project = Project.due_for_purge.find_by(id: project_id)
    Projects::Purge.new(project).call if project
  end
end
