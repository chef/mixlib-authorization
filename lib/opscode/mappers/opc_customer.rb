require 'opscode/mappers/base'
require 'opscode/models/opc_customer'

module Opscode
  module Mappers
    class OpcCustomer < Base

      attr_reader :join_table

      def initialize(*args)
        super
        @table = @connection[:opc_customers]
        @join_table = @connection[:opc_users]
      end

      def validate!(customer)
        # Calling valid? will reset the error list :( so it has to be done first.
        customer.valid?
        unless customer.errors.empty?
          self.class.invalid_object!(customer.errors.full_messages.join(", "))
        end
        true
      end

      def create(customer)
        customer.update_timestamps!
        validate!(customer)
        row_data = customer.for_db
        execute_sql(:update, :opc_customer) do
          table.insert(row_data)
        end
        customer.persisted!
        customer
      end

      def update(customer)
        customer.update_timestamps!
        validate!(customer)
        row_data = customer.for_db
        execute_sql(:update, :opc_customer) do
          table.filter(:id => customer.id).update(row_data)
        end
      rescue Sequel::DatabaseError => e
        log_exception("OPC Customer update failed", e)
        self.class.query_failed!(e.message)
      end

      def list
        finder = @table.select(:name)
        execute_sql(:list, :opc_customer) { finder.all }.map {|row| row[:name]}
      end

      def find_by_query(&block)
        finder = block ? block.call(table) : table
        if data = execute_sql(:read, :opc_customer) { finder.first }
          inflate_model(data)
        else
          nil
        end
      end

      def find_by_name(name)
        find_by_query { |table| table.filter(:name => name) }
      end

      def find_by_domain(domain)
        find_by_query { |table| table.filter(:domain => domain) }
      end

      def find_all_by_user(username)
        execute_sql(:by_user, :opc_customer) do
          table.join(:opc_users, :customer_id => :id).join(:users, :id => :user_id).filter(:users__username => username).select_all(:opc_customers).map do |row_data|
            inflate_model(row_data)
          end
        end
      end

      def inflate_model(row_data)
        customer = Models::OpcCustomer.load(row_data)
        customer.persisted!
        customer
      end

    end
  end
end

