if RUBY_PLATFORM =~ /java/ && ENV['NODB'].nil? && $0 !~ /rake/ && !["development", "test"].include?(Rails.env)
  require 'active_record_jdbc_mysql_master_slave'
end
