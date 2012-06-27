require File.expand_path('../settings', __FILE__)

Sequel.migration do

  change do

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

# CREATE INDEX node_audit_node_id_index ON node_run USING btree (node_id);


  end
end
