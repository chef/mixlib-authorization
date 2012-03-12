require File.expand_path('../settings', __FILE__)
Sequel.migration do
  up do
    # There is no apparent varbinary support in Sequel.  This
    # means a couple of manual workarounds. 
    #
    run("ALTER TABLE nodes ADD COLUMN last_audit_id VARBINARY(16) DEFAULT NULL")

    # audit_id should be varbinary - for now we'll declare it as a
    # placeholder of varchar so that we can create the primary key. 
    create_table(:node_audit) do 
      String(:audit_id, :primary_key => true, :fixed => false, :size => 16) 
      String(:node_id, :index => true, :fixed => true, :size => 32)
      String(:status, :fixed => false, :size => 16)
      DateTime(:start_time, :null => false)
      DateTime(:end_time, :null => true)
      text(:event_data, :null => true)
      foreign_key([:node_id], :nodes, :name => :node_id_fk)
    end

    # Manually change the column data type. 
    run("ALTER TABLE node_audit MODIFY audit_id VARBINARY(16) NOT NULL") 

    # Same drill: audit_id is declared here as a placeholder so we can
    # include it as part of the primary key; we'll change the type
    # afterwards. 
    create_table(:node_audit_detail) do
      String(:audit_id, :fixed => false, :size => 16)
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
    end

    run("ALTER TABLE node_audit_detail MODIFY audit_id VARBINARY(16) NOT NULL"); 

    # We couldn't add FK before column data types matched.
    alter_table(:node_audit_detail) do 
      add_foreign_key([:audit_id], :node_audit, :name => :audit_id_fk);
    end
  end

  # because of hte foreign keys we need to deconstruct our tables in a
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
