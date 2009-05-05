#!/usr/bin/env ruby

require 'optparse'
require 'yaml'
require 'erb'

module RailsGoodies
  module DbPrompt

    VERSION = '0.1'

    def pipe_into_exec(message, command_pipe_named, fd_name)
      reader, writer = IO.pipe
      writer.write(message)
      raise "Bad fileno >>#{ reader.fileno }<<" unless reader.fileno.is_a?(Fixnum)
      command = command_pipe_named.gsub(/#{fd_name}/, "/dev/fd/#{reader.fileno.to_s}")
      writer.close # reader to be closed by 'command'
      exec command
    end
    module_function :pipe_into_exec
    private :pipe_into_exec

    class AbstractPrompt
      attr_accessor :config, :options, :argv
      def initialize(config, options, argv)
        @config = config
        @options = options
        @argv = argv
      end
    end

    class SQLITE3Prompt < AbstractPrompt
      def run
        options[:executable] ||= 'sqlite3' # default
        exec "#{options[:executable]} #{config['database']}"
      end
    end

    class POSTGRESQLPrompt < AbstractPrompt
      def run
        options[:executable] ||= 'psql' # default
        exec "#{options[:executable]} #{config['database']}"
      end
    end

    class MYSQLPrompt < AbstractPrompt
      def run
        options[:executable] ||= 'mysql' # default
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
        RailsGoodies::DbPrompt::pipe_into_exec client_config, "#{options[:executable]} --defaults-file=:fd", ':fd'
      end
    end

    def perform(options, argv)
      argv = [] if argv.nil?
      environment = argv[0] || 'development'
      config_file = argv[1] || 'config/database.yml'
      
      yaml = YAML::load(ERB.new(IO.read(config_file)).result)
      
      raise "Could not find configuration for >>#{environment}<< in file #{config_file}." if !yaml || yaml[environment].nil?
      
      config = yaml[environment]
      adapter = config['adapter']
      
      adapter_prompt_class = nil
      begin
        adapter_prompt_class = Object.module_eval("#{ adapter.upcase}Prompt")
      rescue NameError => e
        raise "Adapter >>#{ adapter }<< not supported."
      end
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


    opts.on("-x", "--executable EXECUTABLE", String, "(mysql) executable to use") do |mysql|
      options[:executable] = mysql.to_s
    end

    opts.on("--mycnf", "Output my.cnf file") do |mycnf|
      options[:mycnf] = mycnf
    end
    opts.on("-i", "--ignore FLAGS", "mysql flags in database.yml to ignore, comma-separated") do |ignore|
      options[:ignore] = ignore
    end

    opts.on_tail("--version", "dp_prompt version") do |ignore|
      puts <<ENDV
dp_prompt version #{RailsGoodies::DbPrompt::VERSION}
Copyright (C) 2009 Stephan Wehner
This is free software; see the source for copying conditions.  There is NO
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
  RailsGoodies::DbPrompt::perform(options, ARGV)
end
