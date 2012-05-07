require File.expand_path('../settings', __FILE__)

Sequel.migration do
  change do

    create_table(:opc_customers) do
      primary_key :id
      String(:name, :null => false, :unique => true)
      String(:display_name, :null => false)
      String(:domain, :null => false, :unique => true)
      String(:contact, :null => false, :text => true)
      Fixnum(:priority)

      DateTime(:created_at, :null => false)
      DateTime(:updated_at, :null => false)
    end

    create_table(:opc_users) do
      String(:user_id, :null => false, :fixed => true, :size => 32)
      foreign_key([:user_id], :users, :on_delete => :cascade)
      foreign_key(:customer_id, :opc_customers, :on_delete => :cascade)
      unique([:user_id, :customer_id])
    end
  end
end
