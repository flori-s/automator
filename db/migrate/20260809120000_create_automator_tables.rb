# frozen_string_literal: true

class CreateAutomatorTables < ActiveRecord::Migration[6.0]
  def change
    create_table :automator_flows do |t|
      t.string :name, null: false
      t.string :key, null: false
      t.boolean :enabled, null: false, default: true
      t.boolean :dry_run, null: false, default: false
      t.text :description
      t.string :tenant
      t.timestamps
    end
    add_index :automator_flows, :key, unique: true
    add_index :automator_flows, :tenant
    add_index :automator_flows, :enabled

    create_table :automator_triggers do |t|
      t.references :flow, null: false, foreign_key: { to_table: :automator_flows }
      t.string :event, null: false
      t.string :record_type
      t.text :change_filter
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :automator_triggers, :event

    create_table :automator_conditions do |t|
      t.references :flow, null: false, foreign_key: { to_table: :automator_flows }
      t.string :kind, null: false, default: "structured" # structured | custom
      t.text :config
      t.string :predicate_key
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :automator_cancel_conditions do |t|
      t.references :flow, null: false, foreign_key: { to_table: :automator_flows }
      t.string :kind, null: false, default: "structured"
      t.text :config
      t.string :predicate_key
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :automator_actions do |t|
      t.references :flow, null: false, foreign_key: { to_table: :automator_flows }
      t.string :kind, null: false, default: "builtin" # builtin | callback
      t.string :builtin_name
      t.string :handler_key
      t.text :options
      t.integer :delay_seconds, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :automator_jobs do |t|
      t.references :flow, null: false, foreign_key: { to_table: :automator_flows }
      t.references :action, null: false, foreign_key: { to_table: :automator_actions }
      t.string :status, null: false, default: "pending"
      t.datetime :run_at, null: false
      t.text :payload
      t.integer :attempts, null: false, default: 0
      t.text :error
      t.string :idempotency_key
      t.string :tenant
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end
    add_index :automator_jobs, :status
    add_index :automator_jobs, :run_at
    add_index :automator_jobs, :idempotency_key, unique: true
    add_index :automator_jobs, :tenant

    create_table :automator_executions do |t|
      t.references :flow, foreign_key: { to_table: :automator_flows }
      t.references :job, foreign_key: { to_table: :automator_jobs }
      t.string :event
      t.string :outcome, null: false
      t.text :detail
      t.string :tenant
      t.timestamps
    end
    add_index :automator_executions, :outcome
    add_index :automator_executions, :created_at
  end
end
