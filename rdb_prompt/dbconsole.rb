#!/usr/bin/env ruby

require 'optparse'
require 'yaml'
require 'erb'

class AbstractPrompt
  attr_accessor :db_config, :options
  def initialize(db_config, options)
    @db_config = db_config
    @options = options

    raise 'No database name found' if db_config['database'].nil?
    raise 'Database name is empty' if db_config['database'] == ''
    raise 'Database name has whitespace' if db_config['database'] =~ /\s/
  end
end

class Sqlite3Prompt < AbstractPrompt
  # sqlite3 support is very basic : no options are passed on
  # except for the database field
  # The default executable is sqlite3
  def run
    options[:executable] ||= 'sqlite3' # default
    command = "#{options[:executable]} #{db_config['database']}"
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
    command = "#{options[:executable]} #{db_config['database']}"
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
    db_config.delete('adapter')
    # 2. Rename username to user
    if db_config['user'].nil? &&
       !db_config['username'].nil? &&
       (db_config['user'] = db_config['username'])
      db_config.delete 'username'
    end

    # 3. Remove fields from options[:ignore]
    connection_opt = db_config.keys.sort
    unless options[:ignore].nil?
      $stderr.puts "Ignore flags: '#{options[:ignore]}'" if options[:verbose]
      connection_opt -= options[:ignore].split(/,/)
    end
    
    # 4. make body of my.cnf
    my_cnf = connection_opt.collect do |key|
      "#{key}=#{db_config[key]}"
    end
    
    # 5. Add client "header"
    my_cnf = "[client]\n#{my_cnf.join("\n")}"
  end

  def piping_to_dev_fd_supported?
    begin
      reader, writer = IO.pipe
      begin
        test_string = Time.new.to_s
        writer.write test_string
        writer.close
        read_back = IO.read("/dev/fd/#{reader.fileno.to_s}") 
        if test_string == read_back
          return true
        end
        $stderr.puts "Wrote >>#{ test_string }<<, but read back >>#{ read_back }<<. Piping to /dev/fd/## is not supported" if options[:verbose]
        return false
      ensure
        reader.close
      end
    rescue Exception => e
      $stderr.puts "Pipe test failed with #{e}" if options[:verbose]
      return false # more closing needed?
    end
  end
  private :piping_to_dev_fd_supported?

  def run
    options[:executable] ||= 'mysql' # default
    my_cnf = self.get_my_cnf
    if options[:mycnf_only]
      puts my_cnf
      return
    end
    $stderr.puts "Using my.cnf\n--- BEGIN my.cnf ----\n#{my_cnf}\n--- END my.cnf ---" if options[:verbose]
    # Now set up a pipe, and hook it up to the executable (mysql)

    if piping_to_dev_fd_supported?
      reader, writer = IO.pipe
      writer.write(my_cnf)
      unless reader.fileno.is_a?(Fixnum)
        writer.close
        reader.close
        raise "Bad fileno >>#{ reader.fileno }<<" 
      end
      # my_cnf to be read in via --defaults-file
      command = "#{options[:executable]} --defaults-file=/dev/fd/#{reader.fileno.to_s}"
      writer.close # reader to be closed by 'command' / the executable
      $stderr.puts "Exec'ing command '#{command}'" if options[:verbose]
      exec command
    else 
      # todo
    end
  end
end

class CommandLineInterface < OptionParser
  attr_accessor :options, :argv
  def initialize
    super
    @options = {}
    self.banner = "Usage: #{$0} [options] [environment] [database.yml]"
    separator ""
    separator "Specific options:"
    def_option "-x", "--executable EXECUTABLE", String, "executable to use. Defaults are sqlite3, psql, mysql" do |executable|
      @options[:executable] = executable.to_s
    end

    def_option "--mycnf", "Just output my.cnf file (mysql adapter only)" do
      @options[:mycnf_only] = true
    end

    def_option "-i", "--ignore FLAGS", "flags in database.yml to ignore, comma-separated (mysql adapter only)" do |ignore|
      @options[:ignore] = ignore
    end

    def_option "-v", "--[no-]verbose", "Run verbosely" do |verbose|
      @options[:verbose] = verbose.first
    end

    def_tail_option "-h", "--help", "Show this help message" do
      puts self
      exit
    end
  end

  def parse_command_line_args(argv)
    @argv = parse!(argv) # parse will populate options and remove the parsed options from argv
    @environment = @argv[0] || 'development'
    @yaml_filename = @argv[1] || 'config/database.yml'
  end

  def perform
    $stderr.puts "Using yaml file '#{@yaml_filename}'" if options[:verbose]
    yaml = YAML::load(ERB.new(IO.read(@yaml_filename)).result)
    
    $stderr.puts "Using environment '#{@environment}'" if options[:verbose]
    raise "Could not find configuration for >>#{@environment}<< in file #{@yaml_filename}." if !yaml || yaml[@environment].nil?
    
    db_config = yaml[@environment]
    adapter = db_config['adapter']
    
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
    adapter_prompt = adapter_prompt_class.new(db_config, options)
    adapter_prompt.run
  end
end

cli = CommandLineInterface.new
cli.parse_command_line_args(ARGV)
cli.perform
