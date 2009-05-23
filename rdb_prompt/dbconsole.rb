#!/usr/bin/env ruby

require 'optparse'
require 'yaml'
require 'erb'

class AbstractConsole
  attr_accessor :db_config, :options
  def initialize(db_config, options)
    @db_config = db_config
    @options = options

    abort 'No database name found' if db_config['database'].nil?
    abort 'Database name is empty' if db_config['database'] == ''
    # Todo: deal with whitespace through quoting / escaping quotes
    abort 'Database name has whitespace. Not supported' if db_config['database'] =~ /\s/
    abort 'Bad executable' unless @options[:executable].nil? || @options[:executable] =~ /[a-z]/i
  end

  # Returns @options[:executable] if not empty
  # Otherwise find executable based on commands from PATH
  # adding .exe on the win32 platform
  def find_cmd(*commands)
    return @options[:executable] if @options[:executable]
    dirs_on_path = ENV['PATH'].to_s.split(File::PATH_SEPARATOR)
    commands += commands.map{|cmd| "#{cmd}.exe"} if RUBY_PLATFORM =~ /win32/
    commands.detect do |cmd|
      dirs_on_path.detect do |path|
        File.executable? File.join(path, cmd)
      end
    end || abort("Couldn't find database client: #{commands.join(', ')}. Check your $PATH and try again.")
  end
end

class SqliteConsole < AbstractConsole
  # The default executable is sqlite
  # sqlite support is very basic : no options are passed on
  # except for the database field
  def run
    arg = db_config['database']
    command = "#{find_cmd('sqlite')} #{arg}"
    $stderr.puts "Exec'ing command '#{command}'" if options[:verbose]
    exec find_cmd('sqlite'), arg
  end
end

class Sqlite3Console < AbstractConsole
  # The default executable is sqlite3
  # sqlite3 support is very basic : -header option and
  # modes html, list, line, column (---mode option / @option[:mode])
  def run
    args = []
    args << "-#{@options[:mode]}" if @options[:mode]
    args << "-header" if @options[:header]
    args << db_config['database']
    command = "#{find_cmd('sqlite3')} #{args.join(' ')}"
    $stderr.puts "Exec'ing command '#{command}'" if options[:verbose]
    exec find_cmd('sqlite3'), *args
  end
end

class PostgresqlConsole < AbstractConsole
  # The default executable is psql
  # Environment variables for user/hos/port are set according to the database config.
  # Password is passed in environment variable PGPASSWORD with option -p / @options[:password]
  def run
    ENV['PGUSER']     = @db_config['username'] if @db_config["username"]
    ENV['PGHOST']     = @db_config['host'] if @db_config["host"]
    ENV['PGPORT']     = @db_config['port'].to_s if @db_config["port"]
    ENV['PGPASSWORD'] = @db_config['password'].to_s if @db_config["password"] && @options[:password]

    command = "#{find_cmd('psql')} #{options[:executable]} #{db_config['database']}"
    $stderr.puts "Exec'ing command '#{command}'" if options[:verbose]
    exec find_cmd('psql'), @db_config['database']
  end
end

class MysqlConsole < AbstractConsole

  DATABASE_YAML_TO_MYCNF_MAP = {
      'host'      => 'host',
      'port'      => 'port',
      'socket'    => 'socket',
      'username'  => 'user',
      'encoding'  => 'default-character-set'}

  # Username / password and other connection settings are piped in to 
  # the mysql command (and read by mysql through the --default-config-file
  # switch) -- depending on operating system support

  def run
    if options[:mycnf_only]
      puts get_my_cnf
      return
    end

    if piping_to_dev_fd_supported?
      run_with_pipe
    else 
      run_with_mysql_options
    end
  end

private

  def get_my_cnf
    my_cnf = %w( [client] )
    map = DATABASE_YAML_TO_MYCNF_MAP.dup
    map['password'] = 'password'
    # sort to allow testing
    map.each do |yaml_name, mycnf_name|
      my_cnf << "#{mycnf_name}=#{@db_config[yaml_name]}" if @db_config[yaml_name]
    end
    my_cnf.join("\n")
  end

  def piping_to_dev_fd_supported?
    reader,writer = nil,nil # just so we always close
    begin
      reader, writer = IO.pipe
      test_string = Time.new.to_s
      writer.write test_string
      writer.close
      return false unless reader.fileno.is_a?(Fixnum)
      read_back = IO.read("/dev/fd/#{reader.fileno.to_s}") 
      if test_string == read_back
        return true
      end
      $stderr.puts "Wrote >>#{ test_string }<<, but read back >>#{ read_back }<<. Piping to /dev/fd/## is not supported" if options[:verbose]
    rescue Exception => e
      $stderr.puts "Pipe test failed with #{e}" if options[:verbose]
    ensure
      reader.close rescue nil
      writer.close rescue nil
    end
    false
  end

  def run_with_mysql_options
    # todo: add quotes / escaping in case of whitespace
    args = DATABASE_YAML_TO_MYCNF_MAP.map { |yaml_name, mycnf_name|
      "--#{mycnf_name}=#{@db_config[yaml_name]}" if @db_config[yaml_name]
    }.compact
  
    if @db_config['password'] && @options[:password]
      args << "--password=#{@db_config['password']}"
    elsif @db_config['password'] && !@db_config['password'].to_s.empty?
      args << "-p"
    end
  
    args << @db_config['database']
    $stderr.puts "Exec'ing command '#{find_cmd('mysql', 'mysql5')} #{ args.join ' ' }'" if options[:verbose]
  
    exec find_cmd('mysql', 'mysql5'), *args
  end
  
  # Set up a pipe, and hook it up to the executable (mysql)
  # See http://dev.mysql.com/doc/refman/5.0/en/password-security-user.html
  def run_with_pipe
    my_cnf = get_my_cnf
    $stderr.puts "Using my.cnf\n--- BEGIN my.cnf ----\n#{my_cnf}\n--- END my.cnf ---" if options[:verbose]
    reader, writer = IO.pipe
    writer.write(my_cnf)
    writer.close # reader to be closed by 'command' / the executable
    unless reader.fileno.is_a?(Fixnum)
      reader.close
      abort "Bad fileno >>#{ reader.fileno }<<. Cannot pipe."  # unlikely, since checked in method piping_to_dev_fd_supported?
    end
    # my_cnf to be read in via --defaults-file
    command= [ find_cmd('mysql', 'mysql5'), "--defaults-file=/dev/fd/#{reader.fileno.to_s}"]
    $stderr.puts "Exec'ing command '#{ command.join ' ' }'" if options[:verbose]
    exec find_cmd('mysql', 'mysql5'), "--defaults-file=/dev/fd/#{reader.fileno.to_s}"
  end
end

class CommandLineInterface < OptionParser
  attr_accessor :options, :argv
  def initialize
    super
    @options = {}
    self.banner = "Usage: #{$0} [options] [environment] [database.yml]"
    separator ""
    separator "Default environment is development"
    separator "Default database.yml file is config/database.yml"
    separator ""
    separator "Specific options:"

    def_option "-x", "--executable EXECUTABLE", String, "executable to use. Defaults are sqlite, sqlite3, psql, mysql" do |executable|
      @options[:executable] = executable.to_s
    end

    def_option "--mycnf", "mysql only: Just output my.cnf file" do
      @options[:mycnf_only] = true
    end

    def_option "--mode [MODE]", ['html', 'list', 'line', 'column'],
    "sqlite3 only: put the database in the specified mode (html, list, line, column)" do |mode|
      @options[:mode] = mode
    end

    def_option "-h", "--[no-]header", "sqlite3 only: Turn headers on or off"  do |h|
      @options[:header] = h
    end

    def_option("-p", "--include-password", "mysql/postgresql only: Automatically provide the password from database.yml") do |v|
      @options[:password] = true
    end

    def_option "-v", "--[no-]verbose", "Run verbosely" do |verbose|
      @options[:verbose] = verbose
    end

    def_tail_option "--help", "Show this help message" do
      puts self
      exit
    end
  end

  def parse_command_line_args(argv)
    @argv = parse!(argv) # parse will populate options and remove the parsed options from argv
    @environment = @argv[0] || ENV['RAILS_ENV'] || 'development'
    @yaml_filename = @argv[1] || 'config/database.yml'
  end

  def perform
    $stderr.puts "Using yaml file '#{@yaml_filename}'" if options[:verbose]
    abort "Cannot read file #{@yaml_filename}" unless File.readable? @yaml_filename
    yaml = nil
    begin
      yaml = YAML::load(ERB.new(IO.read(@yaml_filename)).result)
    rescue Exception => e
      abort "Error #{e} while reading #{@yaml_filename}"
    end
    
    $stderr.puts "Using environment '#{@environment}'" if options[:verbose]
    abort "Could not find configuration for >>#{@environment}<< in file #{@yaml_filename}." unless yaml && yaml.is_a?(Hash) && yaml[@environment]
    
    db_config = yaml[@environment]
    adapter = db_config['adapter']
    
    $stderr.puts "Found adapter >>#{ adapter }<<" if options[:verbose]
    # Convert adapter into a class
    adapter_console_class = case adapter
      when 'sqlite': SqliteConsole
      when 'sqlite3': Sqlite3Console
      when 'postgresql': PostgresqlConsole
      when 'mysql': MysqlConsole
      else
        abort  "Unknown command-line client for database #{db_config['database']}. Submit a Rails patch to add support for the #{adapter} adapter!"
    end

    # Instantiate and run
    adapter_console = adapter_console_class.new(db_config, options)
    adapter_console.run
  end
end

cli = CommandLineInterface.new
cli.parse_command_line_args(ARGV)
cli.perform
