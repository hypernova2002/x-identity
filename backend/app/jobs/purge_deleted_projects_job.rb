# Hourly safety net: queues a purge for every deleted project past its restore period, in case a
# scheduled purge was lost.
class PurgeDeletedProjectsJob < ApplicationJob
  queue_as :maintenance

  def perform
    Project.due_for_purge.find_each { |project| ProjectPurgeJob.perform_later(project_id: project.id) }
  end
end
