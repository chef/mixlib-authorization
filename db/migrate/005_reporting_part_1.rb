require File.expand_path('../settings', __FILE__)
Sequel.migration do
  up do
    bin_column_type = defined?(Sequel::Postgres) ? "bytea" : "varbinary(16)"

    alter_table :nodes do 
      add_column :last_audit_id, bin_column_type
    end

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

  end

  # because of the foreign keys we need to deconstruct our tables in a
  # specific order. 
  #
  down do
    alter_table(:nodes) do 
      drop_column :last_audit_id;
    end

    drop_table(:node_audit_detail)

    drop_table(:node_audit)

  end
end
# Sequel.migration do
#  change do
#  end
# end
