#!/usr/bin/env ruby

require 'yaml'
require 'erb'

# Usage
# -----
#
# my_sql environment config-file
#
# Goal
# ----
#
# Developer has a shell open. The current directory is the root of a Rails application.
# The Rails application uses a mysql database.
#
# Instead of opening script/console they want to connect to the mysql directly.
# But they don't want to look up the username and password, host, port etc. from
# the config/database.yml
#
# Instead they would simply type for example,
#
#   my_sql => opens mysql prompt with development database
#
#   my_sql test=> opens mysql prompt with test database
#
# Result:
#
# They are now in a mysql prompt.

module RailsGoodies
  module MySql
    def produce_command_line(argv)
      environment = argv[0] || 'development'
      config_file = argv[1] || 'config/database.yml'
      config = nil
      
      begin
        config = YAML::load(ERB.new(IO.read(config_file)).result)
      rescue Exception => e
        raise "Could not parse config file >>#{config_file}<<. Exception >>#{e}<<"
      end
      
      raise "Could not find configuration for >>#{environment}<< in file #{config_file}." if config[environment].nil?
      
      config_env = config[environment]
      adapter = config_env['adapter']
      raise "Adapter >>#{adapter}<< not supported. Sorry." unless adapter == 'mysql'
      
      %{mysql -h '#{adapter['host']}' -u #{adapter['username']} -p... }
    end
  end
end

if  __FILE__ == $0
  include RailsGoodies::MySql
  exec produce_command_line(ARGV)
end
