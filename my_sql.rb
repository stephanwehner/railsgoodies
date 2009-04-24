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
    def produce_command_line(argv = [])
      argv = [] if argv.nil?
      environment = argv[0] || 'development'
      config_file = argv[1] || 'config/database.yml'
      
      yaml = YAML::load(ERB.new(IO.read(config_file)).result)
      
      raise "Could not find configuration for >>#{environment}<< in file #{config_file}." if !yaml || yaml[environment].nil?
      
      config = yaml[environment]
      adapter = config['adapter']
      raise "Adapter >>#{adapter}<< not supported. Sorry." unless adapter == 'mysql'
      
      config.delete('adapter')
      # Rename username to user
      if config['user'].nil? && (config['user'] = config['username'])
        config.delete 'username'
      end
      connection_opt = config.keys
      if config.keys.include? 'password'
        connection_opt.delete_if { |opt|  opt=='password'}
        connection_opt << 'password'
      end
      
      connection_values = connection_opt.collect { |key| config[key]}
      connection_opt.map! { |key| "#{ key }=%s"}

      # After http://dev.mysql.com/doc/refman/5.0/en/password-security-user.html
      return <<-END_BASH
      { printf '[client]\n#{connection_opt.join('\n')}' #{connection_values.join(' ')} |
3<&0 <&4 4<&- /usr/local/mysql/bin/mysql --defaults-file=/dev/fd/3 
} 4<&0
       END_BASH
    end
  end
end

if  __FILE__ == $0
  include RailsGoodies::MySql
  puts produce_command_line(ARGV)
  exec produce_command_line(ARGV)
end
