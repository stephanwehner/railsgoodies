#!/usr/bin/env ruby

require 'optparse'
require 'yaml'
require 'erb'

module RGoodies
  module DbPrompt

    VERSION = '0.1'

    class AbstractPrompt
      attr_accessor :config, :options, :argv
      def initialize(config, options, argv)
        @config = config
        @options = options
        @argv = argv
      end
    end

    class Sqlite3Prompt < AbstractPrompt
      # sqlite3 support is very basic : no options are passed on
      # except for the database field
      # The default executable is sqlite3
      def run
        options[:executable] ||= 'sqlite3' # default
        command = "#{options[:executable]} #{config['database']}"
        $stderr.puts "Exec'ing command '#{command}'" if options[:verbose]
        exec command
      end
    end

    class PostgresqlPrompt < AbstractPrompt
      # postgres support is very basic : no options are passed on
      # except for the database field (not even username, host)
      # The default executable is psql
      def run
        options[:executable] ||= 'psql' # default
        command = "#{options[:executable]} #{config['database']}"
        $stderr.puts "Exec'ing command '#{command}'" if options[:verbose]
        exec command
      end
    end

    class MysqlPrompt < AbstractPrompt
      # mysql support is more elaborate
      # Username / password and other connection settings are piped in to 
      # the mysql command (and read by mysql through the --default-config-file
      # switch)
      # Options set in the database.yml file can be prevented from being
      # passed on to mysql with the --ignore option
      # The default executable is mysql

      def get_my_cnf
        # Assemble my_cnf which are supposed to be contents of 
        # a my.cnf with the connection options found in the database.yml
        # file
        
        # 1. Don't want to pass on 'adapter'.
        config.delete('adapter')
        # 2. Rename username to user
        if config['user'].nil? && (config['user'] = config['username'])
          config.delete 'username'
        end
  
        # 3. Remove fields from options[:ignore]
        connection_opt = config.keys.sort
        unless options[:ignore].nil?
          $stderr.puts "Ignore flags: '#{options[:ignore]}'" if options[:verbose]
          connection_opt -= options[:ignore].split(/,/)
        end
        
        # 4. make body of my.cnf
        my_cnf = connection_opt.collect do |key|
          "#{key}=#{config[key]}"
        end
        
        # 5. Add client "header"
        my_cnf = "[client]\n#{my_cnf.join("\n")}"
      end


      def run
        options[:executable] ||= 'mysql' # default
        my_cnf = self.get_my_cnf
        if options[:mycnf_only]
          puts my_cnf
          return
        end
        $stderr.puts "Using my.cnf\n--- BEGIN my.cnf ----\n#{my_cnf}\n--- END my.cnf ---" if options[:verbose]
        # Now set up a pipe, and hook it up to the executable (mysql)
        reader, writer = IO.pipe
        writer.write(my_cnf)
        raise "Bad fileno >>#{ reader.fileno }<<" unless reader.fileno.is_a?(Fixnum)
        # my_cnf to be read in via --defaults-file
        command = "#{options[:executable]} --defaults-file=/dev/fd/#{reader.fileno.to_s}"
        writer.close # reader to be closed by 'command' / the executable
        $stderr.puts "Exec'ing command '#{command}'" if options[:verbose]
        exec command
      end
    end

    def perform(options, argv)
      argv = [] if argv.nil?
      environment = argv[0] || 'development'
      $stderr.puts "Using environment '#{environment}'" if options[:verbose]
      yaml_file = argv[1] || 'config/database.yml'
      $stderr.puts "Reading yaml file '#{yaml_file}'" if options[:verbose]
      
      yaml = YAML::load(ERB.new(IO.read(yaml_file)).result)
      
      raise "Could not find configuration for >>#{environment}<< in file #{yaml_file}." if !yaml || yaml[environment].nil?
      
      config = yaml[environment]
      adapter = config['adapter']
      
      $stderr.puts "Adapter is '#{adapter}'" if options[:verbose]
      # Convert adapter into a class
      adapter_prompt_class = case adapter
        when 'sqlite3': Sqlite3Prompt
        when 'postgresql': PostgresqlPrompt
        when 'mysql': MysqlPrompt
        else
          raise "Adapter >>#{ adapter }<< not supported."
      end

      # Instantiate and run
      adapter_prompt = adapter_prompt_class.new(config, options, argv)
      adapter_prompt.run
    end
    module_function :perform
  end
end

if  __FILE__ == $0
  # Default options:
  options = {}
  option_parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options] [environment] [database.yml]\n"

    opts.separator ""
    opts.separator "Specific options:"

    opts.on("-x", "--executable EXECUTABLE", String, "executable to use. Defaults are sqlite3, psql, mysql") do |executable|
      options[:executable] = executable.to_s
    end

    opts.on("--mycnf", "Just output my.cnf file (mysql adapter only)") do |mycnf|
      options[:mycnf_only] = mycnf
    end

    opts.on("-i", "--ignore FLAGS", "flags in database.yml to ignore, comma-separated (mysql adapter only)") do |ignore|
      options[:ignore] = ignore
    end

    opts.on("-v", "Verbose output") do
      options[:verbose] = true
    end

    opts.on_tail("--version", "dp_prompt version") do |ignore|
      puts <<ENDV
dp_prompt version #{RGoodies::DbPrompt::VERSION}
Copyright (C) 2009 Stephan Wehner
This is free software; see the LICENSE file for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
ENDV
      exit
    end
    opts.on_tail("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end
  option_parser.parse! ARGV
  RGoodies::DbPrompt::perform(options, ARGV)
end
