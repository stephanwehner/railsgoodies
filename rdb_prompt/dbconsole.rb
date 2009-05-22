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
    # Todo: deal with whitespace through quoting / escaping quotes
    raise 'Database name has whitespace' if db_config['database'] =~ /\s/
    raise 'Executable empty' if @options[:executable] =~ /\A\s\Z/
  end

  # @options[:executable] if given
  # otherwise find executable based on commands from PATH
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

class SqlitePrompt < AbstractPrompt
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

class Sqlite3Prompt < AbstractPrompt
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

class PostgresqlPrompt < AbstractPrompt
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

class MysqlPrompt < AbstractPrompt
  # mysql support is more elaborate
  # Username / password and other connection settings are piped in to 
  # the mysql command (and read by mysql through the --default-config-file
  # switch)
  # Options set in the database.yml file can be prevented from being
  # passed on to mysql with the --ignore option
  # The default executable is mysql


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

  def run_with_mysql_options
    args = {
      'host'      => '--host',
      'port'      => '--port',
      'socket'    => '--socket',
      'username'  => '--user',
      'encoding'  => '--default-character-set'
    }.map { |opt, arg| "#{arg}=#{@db_config[opt]}" if @db_config[opt] }.compact
  
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
  def run_with_pipe
    my_cnf = get_my_cnf
    $stderr.puts "Using my.cnf\n--- BEGIN my.cnf ----\n#{my_cnf}\n--- END my.cnf ---" if options[:verbose]
    reader, writer = IO.pipe
    writer.write(my_cnf)
    unless reader.fileno.is_a?(Fixnum)
      writer.close
      reader.close
      raise "Bad fileno >>#{ reader.fileno }<<" 
    end
    # my_cnf to be read in via --defaults-file
    writer.close # reader to be closed by 'command' / the executable
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
    separator "Specific options:"
    def_option "-x", "--executable EXECUTABLE", String, "executable to use. Defaults are sqlite3, psql, mysql" do |executable|
      @options[:executable] = executable.to_s
    end

    def_option "--mycnf", "Just output my.cnf file (mysql adapter only)" do
      @options[:mycnf_only] = true
    end

    def_option "--mode [MODE]", ['html', 'list', 'line', 'column'],
    "Automatically put the sqlite3 database in the specified mode (html, list, l
ine, column)." do |mode|
      @options[:mode] = mode
  end

    def_option "-i", "--ignore FLAGS", "Names of flags in database.yml to ignore, comma-separated (mysql adapter only)" do |ignore|
      @options[:ignore] = ignore
    end

    def_option "-v", "--[no-]verbose", "Run verbosely" do |verbose|
      @options[:verbose] = verbose
    end

    def_option "-h", "--[no-]header", "sqlite3 : turn headers on or off"  do |h|
      @options[:header] = h
    end

    def_option("-p", "--include-password", "Automatically provide the password from database.yml") do |v|
      @options[:password] = true
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
    yaml = YAML::load(ERB.new(IO.read(@yaml_filename)).result)
    
    $stderr.puts "Using environment '#{@environment}'" if options[:verbose]
    raise "Could not find configuration for >>#{@environment}<< in file #{@yaml_filename}." if !yaml || yaml[@environment].nil?
    
    db_config = yaml[@environment]
    adapter = db_config['adapter']
    
    $stderr.puts "Adapter is '#{adapter}'" if options[:verbose]
    # Convert adapter into a class
    adapter_prompt_class = case adapter
      when 'sqlite': SqlitePrompt
      when 'sqlite3': Sqlite3Prompt
      when 'postgresql': PostgresqlPrompt
      when 'mysql': MysqlPrompt
      else
        raise  "Unknown command-line client for database #{db_config['database']}. Submit a Rails patch to add support for the #{adapter} adapter!"
    end

    # Instantiate and run
    adapter_prompt = adapter_prompt_class.new(db_config, options)
    adapter_prompt.run
  end
end

cli = CommandLineInterface.new
cli.parse_command_line_args(ARGV)
cli.perform
