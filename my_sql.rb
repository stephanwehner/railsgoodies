#!/usr/bin/env ruby

require 'optparse'
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
    def produce_command_line(argv = [], options = {})
      options[:executable] ||= 'mysql' # default
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

      connection_opt = config.keys.sort
      unless options[:ignore].nil?
        connection_opt -= options[:ignore].split(/,/)
      end
      
      connection_values = connection_opt.collect { |key| "'#{config[key]}'"}
      connection_opt.map! { |key| "#{ key }=%s"}

      # After http://dev.mysql.com/doc/refman/5.0/en/password-security-user.html
      command_line = <<-END_BASH
      { printf '[client]\n#{connection_opt.join('\n')}' #{connection_values.join(' ')} |
3<&0 <&4 4<&- #{options[:executable]} --defaults-file=/dev/fd/3 
} 4<&0
       END_BASH
       $stderr.puts command_line if options[:verbose]
       command_line
    end
  end
end

if  __FILE__ == $0
  include RailsGoodies::MySql
  # Default options:
  options = {}
  option_parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options] [environment] [database.yml]"

    opts.separator ""
    opts.separator "Specific options:"


    opts.on("-x", "--executable EXECUTABLE", String, "(mysql) executable to use") do |mysql|
      options[:executable] = mysql.to_s
    end

    opts.on("-v", "--verbose", "Verbosity") do |verbose|
      options[:verbose] = verbose
    end

    opts.on("-i", "--ignore FLAGS", "mysql flags in database.yml to ignore, comma-separated") do |ignore|
      options[:ignore] = ignore
    end

    opts.on_tail("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end
  option_parser.parse! ARGV
  exec produce_command_line(ARGV, options)
end
