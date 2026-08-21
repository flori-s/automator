# frozen_string_literal: true

class AddOncePerAndSubjectToAutomator < ActiveRecord::Migration[6.0]
  def change
    add_column :automator_flows, :once_per, :string
    add_column :automator_flows, :once_per_group, :string
    add_column :automator_flows, :subject_association, :string
    add_index :automator_flows, :once_per_group

    add_column :automator_jobs, :dedupe_key, :string
    add_index :automator_jobs, :dedupe_key
  end
end
