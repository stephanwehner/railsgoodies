#!/usr/bin/env ruby

require 'optparse'
require 'yaml'
require 'erb'
require 'open3'

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
#
# Implementation
# At http://dev.mysql.com/doc/refman/5.0/en/password-security-user.html
# a comment points out this shell snippet
#
#   { printf '[client]\npassword=%s\n' xxxx |
#   3<&0 <&4 4<&- mysql --defaults-file=/dev/fd/3 -u myuser
#   } 4<&0
#
# in order to switch to a mysql prompt without revealing the password
# within the argument list of processes.
#
# In Ruby it turns out less cryptic.

module RailsGoodies
  module MySql

    def exec_with_fd(to_pipe, fd_assignment)
      pipe_os, pipe_is = IO.pipe
      pipe_is.puts(to_pipe)
      fd_key = fd_assignment.keys.first
      command_string = fd_assignment[fd_key]
      raise "Bad fileno >>#{ pipe_os.fileno }<<" unless pipe_os.fileno.is_a?(Fixnum)
      command = command_string.gsub(/:#{fd_key}/, pipe_os.fileno.to_s)
      child_pid = fork do
        pipe_is.close
        exec command
      end
  
      pipe_is.close
      Process.wait
      exit
    end

    def perform(argv = [], options = {})
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
      
      client_config = connection_opt.collect do |key|
        "#{key}=#{config[key]}"
      end
      client_config = "[client]\n#{client_config.join("\n")}"
      if options[:mycnf]
         puts client_config
         return
      end
      exec_with_fd client_config, :fd => "#{options[:executable]} --defaults-file=/dev/fd/:fd"
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

    opts.on("--mycnf", "Output my.cnf file") do |mycnf|
      options[:mycnf] = mycnf
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
  perform(ARGV, options)
end
