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

      def destroy(customer)
        unless customer.id
          return self.class.invalid_object!("Cannot delete customer #{customer.inspect} without a valid ID")
        end
        execute_sql(:destroy, :opc_customer) do
          join_table.filter(:customer_id => customer.id).delete
          table.filter(:id => customer.id).delete
        end
      end

      def list(load=false)
        finder = @table
        finder = finder.select(:name) unless load
        execute_sql(:list, :opc_customer) { finder.all }.map {|row| load ? inflate_model(row) : row[:name]}
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

      def find_all_by_user(user, check_domain=true, &block)
        username = user.respond_to?(:username) ? user.username : user
        customers = execute_sql(:by_user, :opc_customer) do
          table.join(:opc_users, :customer_id => :id).join(:users, :id => :user_id).filter(:users__username => username).select_all(:opc_customers).map do |row_data|
            customer = inflate_model(row_data)
            block ? block.call(customer) : customer
          end
        end
        if user.respond_to?(:email) && check_domain
          domain_customer = find_by_domain(user.email.split('@').last)
          customers.insert(0, block ? block.call(domain_customer) : domain_customer) if domain_customer && !customers.include?(domain_customer)
        end
        customers
      end

      def add_user(customer, user)
        execute_sql(:add_user, :opc_customer) do
          join_table.insert(:customer_id => customer.id, :user_id => user.id)
        end
      end

      def remove_user(customer, user)
        execute_sql(:remove_user, :opc_customer) do
          join_table.filter(:customer_id => customer.id, :user_id => user.id).delete
        end
      end

      def has_user?(customer, user)
        finder = join_table.filter(:customer_id => customer.id)
        if user.id == user.username # The User objects in AccountManagement don't expose the UUID
          finder = finder.join(:users, :id => :user_id).filter(:users__username => user.username)
        else
          finder = finder.filter(:user_id => user.id)
        end
        execute_sql(:has_user?, :opc_customer) do
          !!finder.select(1).first
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

