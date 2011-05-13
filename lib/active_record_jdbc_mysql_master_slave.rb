module ActiveRecord
  module ConnectionAdapters
    class JdbcAdapter

      MYSQL_MASTER_SLAVE = true

      class << self

        def master_only
          Thread.current[:master_only]
        end

        def master_only=(mo)
          Thread.current[:master_only] = mo
        end

        def with_master(mo=true, &block)
          saved = self.master_only
          begin
            self.master_only = mo
            block.call
          ensure
            self.master_only = saved
          end
        end

        def with_master_or_slave(&block)
          with_master(false, &block)
        end

      end
    end
    
    module JdbcAdapterMysqlMasterSlaveMethods

      # When included, interject our _execute method around the original
      def self.included(mod)
        mod.class_eval do  
          alias_method :_execute_without_master_slave, :_execute
          alias_method :_execute, :_execute_with_master_slave
        end
      end

      # if we're in auto-commit mode and about to execute a select statement, 
      # then set the connection in read-only mode for the duration of
      # the query... which will permit the query to be load-balanced
      # amongst the slaves by the mysql connector/j ReplicationDriver
      def _execute_with_master_slave(sql, name=nil)
        # The old version would patch the initialize, but that posed an issue
        # in Rails 2.3 where the adapter would be initialized before the plugins
        # loaded, so instead we do this step on first use.
        if @_master_slave_in_use.nil?
          # Only do the instrumentation if the adapter mentioned mysql
          @_master_slave_in_use = config[:adapter] =~ /mysql/
        end
        return _execute_without_master_slave(sql, name) unless @_master_slave_in_use

        # Need to set the read_only option on the raw connection
        # to tell the underlying driver whether the request can
        # go to slaves.
        cro = raw_connection.connection.read_only
        begin
          raw_connection.connection.read_only = 
            !JdbcAdapter.master_only &&
            raw_connection.connection.auto_commit &&
            JdbcConnection::select?(sql)

          self._execute_without_master_slave(sql, name)
           
        ensure
          raw_connection.connection.read_only = cro
        end
      end
    end
    
    class JdbcAdapter      
      include JdbcAdapterMysqlMasterSlaveMethods
    end
  end
end
