require 'singleton'
require 'amqp_client'

# Patch Chef AMQP Client to add easier transactions.
class Chef::IndexQueue::AmqpClient
  def transaction
    transaction_start
    yield
  rescue Exception
    transaction_rollback
    raise
  else
    transaction_commit
  end


  def transaction_start
    amqp_client.tx_select
  end

  def transaction_rollback
    amqp_client.tx_rollback
  end

  def transaction_commit
    amqp_client.tx_commit
  end

end
