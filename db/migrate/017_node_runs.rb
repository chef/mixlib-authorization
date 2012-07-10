require File.expand_path('../settings', __FILE__)

Sequel.migration do

  up do

    alter_table(:nodes) do 
      drop_column :last_audit_id
      add_column(:last_run_id, String, :size => 32)
    end

    drop_table(:node_audit_detail)

    drop_table(:node_audit)

    create_table(:node_run) do
      String(:run_id, :primary_key => true, :fixed => true, :size => 32)
      String(:node_id, :fixed => true, :size => 32, :index => true)
      String(:status, :size => 16)
      DateTime(:start_time, :null => false) # FIXME: without time zone?
      DateTime(:end_time) # FIXME: without time zone?
      text(:event_data)
      text(:run_list, :default => "", :null => false)
      Fixnum(:updated_res_count, :default => 0, :null => false)
      Fixnum(:total_res_count, :default => 0, :null => false)
      foreign_key([:node_id], :nodes, :key => [:id], :name => :node_id_fk, :on_delete => :cascade, :on_update => :restrict)
    end

    create_table(:node_run_detail) do
      String(:run_id, :fixed => true, :size => 32)
      Fixnum(:seq, :null => false)
      Fixnum(:duration, :null => false)
      String(:res_id, :size => 255, :null => false)
      String(:res_type, :size => 255, :null => false)
      String(:res_name, :size => 255, :null => false)
      String(:res_result, :size => 16)
      text(:res_initial_state)
      text(:res_final_state)
      text(:delta)
      text(:cookbook_name, :default => "", :null => false)
      String(:cookbook_ver, :size=>32, :default => "", :null => false)
      primary_key [:run_id, :seq]
      foreign_key([:run_id], :node_run, :name => :node_run_run_id_fk, :on_delete => :cascade, :on_update => :restrict)
    end

  down do
    drop_table(:node_run_detail)

    drop_table(:node_run)

    create_table(:node_audit) do 
      column :audit_id, bin_column_type, :null => false
      String(:node_id, :index => true, :fixed => true, :size => 32)
      String(:status, :fixed => false, :size => 16)
      DateTime(:start_time, :null => false)
      DateTime(:end_time, :null => true)
      text(:event_data, :null => true)
      primary_key([:audit_id])
      foreign_key([:node_id], :nodes, :name => :node_id_fk)
    end

    create_table(:node_audit_detail) do
      column :audit_id, bin_column_type, :null => false
      int(:seq, :null => false)
      int(:duration, :null => false)
      String(:res_id, :fixed => false,  :null => false, :size => 255)
      String(:res_type, :fixed => false, :null => false, :size => 16)
      String(:res_name, :fixed => false,  :null => false, :size => 255)
      String(:res_result, :fixed => false, :null => true, :size => 16)
      text(:res_initial_state, :null => true)
      text(:res_final_state, :null => true)
      text(:delta, :null => true)
      primary_key([:audit_id, :seq])
      foreign_key([:audit_id], :node_audit, :name => :audit_id_fk); 
    end

    bin_column_type = defined?(Sequel::Postgres) ? "bytea" : "varbinary(16)"

    alter_table(:nodes) do 
      add_column :last_audit_id, bin_column_type
      drop_column :last_run_id
    end
  end

  end
end
