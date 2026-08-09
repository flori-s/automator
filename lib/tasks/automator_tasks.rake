# frozen_string_literal: true

namespace :automator do
  desc "Sweep due Automator jobs (schedule every minute)"
  task sweep: :environment do
    results = Automator.sweep
    puts "Automator sweep processed #{Array(results).size} job(s)"
  end

  desc "Requeue failed webhook/automation jobs"
  task retry_webhooks: :environment do
    count = 0
    Automator::Tenancy.each do |_tenant|
      Automator::Job.failed.find_each do |job|
        job.requeue!(run_at: Time.current)
        count += 1
      end
    end
    puts "Requeued #{count} failed job(s)"
  end

  desc "Seed flows from config/automations.yml"
  task seed: :environment do
    path = Rails.root.join("config/automations.yml")
    abort "Missing #{path}" unless File.exist?(path)

    Automator::Tenancy.each do |tenant|
      flows = Automator.seed_from_yaml(path)
      puts "Seeded #{flows.size} flow(s)#{tenant ? " for #{tenant}" : ""}"
    end
  end
end
