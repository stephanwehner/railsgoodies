require 'tempfile'
require 'db_prompt' # what we're testing


describe RGoodies::DbPrompt::CommandLineInterface, 'Experimental OptionParser Extensions' do

  it 'should work without any options' do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    @command_line_interface.parse_command_line_args([])
    @command_line_interface.argv.should == []
    @command_line_interface.options.should == {}
  end

  it 'should translate -x option' do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    @command_line_interface.parse_command_line_args %w(-x test_ex)
    @command_line_interface.argv.should == []
    @command_line_interface.options.should == {:executable => 'test_ex'}
  end

  it 'should translate --executable option' do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    @command_line_interface.parse_command_line_args %w(--executable test_ex)
    @command_line_interface.argv.should == []
    @command_line_interface.options.should == {:executable => 'test_ex'}
  end

  it 'should require an argument for the -x option' do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    lambda {@command_line_interface.parse_command_line_args %w(-x)}.should raise_error(OptionParser::MissingArgument)
  end

  it 'should require an argument for the --executable option' do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    lambda {@command_line_interface.parse_command_line_args %w(--executable)}.should raise_error(OptionParser::MissingArgument)
  end

  it 'should pass extra options for -x' do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    @command_line_interface.parse_command_line_args %w(-x test_ex extra arg)
    @command_line_interface.argv.should == ['extra',  'arg']
    @command_line_interface.options.should == {:executable => 'test_ex'}
  end
  
  it 'should accept --mycnf option' do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    @command_line_interface.parse_command_line_args %w(--mycnf)
    @command_line_interface.argv.should == []
    @command_line_interface.options.should == {:mycnf_only => true}
  end

  it 'should accept -i option' do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    @command_line_interface.parse_command_line_args %w(-i a,b,c)
    @command_line_interface.argv.should == []
    @command_line_interface.options.should == {:ignore => 'a,b,c'}

    @command_line_interface.parse_command_line_args %w(--ignore a,b,c,d)
    @command_line_interface.argv.should == []
    @command_line_interface.options.should == {:ignore => 'a,b,c,d'}
  end

  it 'should require an argument for the -i option' do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    lambda { @command_line_interface.parse_command_line_args %w(-i)}.should raise_error(OptionParser::MissingArgument)
  end

  it 'should accept -v option' do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    @command_line_interface.parse_command_line_args %w(-v)
    @command_line_interface.argv.should == []
    @command_line_interface.options.should == {:verbose => true}
  end

  it 'should accept --verbose option' do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    @command_line_interface.parse_command_line_args %w(--verbose)
    @command_line_interface.argv.should == []
    @command_line_interface.options.should == {:verbose => true}
  end
 
  it 'should accept --no-verbose option' do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    @command_line_interface.parse_command_line_args %w(--no-verbose)
    @command_line_interface.argv.should == []
    @command_line_interface.options.should == {:verbose => false}
  end

  it 'should accept --version option' do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    @command_line_interface.should_receive(:exit).once
    @command_line_interface.should_receive(:puts).once

    @command_line_interface.parse_command_line_args %w(--version)
    @command_line_interface.argv.should == []
    @command_line_interface.options.should == {}
  end

  it 'should accept --help option' do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    @command_line_interface.should_receive(:exit).once
    @command_line_interface.should_receive(:puts).once

    @command_line_interface.parse_command_line_args %w(--help)
    @command_line_interface.argv.should == []
    @command_line_interface.options.should == {}
  end
end

#
# Now for the perform method
#
TEST_DATABASE_YAML = <<END_TEST_DATABASE_YAML
development: 
  adapter: mysql
  username: dev_user
  database: dev_db
  password: dev_password
  host: localhost
other: 
  adapter: mysql
  username: other_user
  password: other_password
  database: other_db
  host: localhost
test_unknown_adapter:
  adapter: no_such_adapter
  username: dev_user_2
  database: dev_db_2
  password: dev_password_2
  host: localhost_2
test_mysql_env: 
  adapter: mysql
  username: dev_user_2
  database: dev_db_2
  password: dev_password_2
  host: localhost_2
test_postgres_env:
  adapter: postgresql
  database: ps_test
  pool: 5
  timeout: 5000
test_sqlite3_env:
  adapter: sqlite3
  database: test.sqlite3
  pool: 5
  timeout: 5000
END_TEST_DATABASE_YAML
describe RGoodies::DbPrompt::CommandLineInterface, 'reading the database.yml file' do

  it 'should raise when yaml is invalid' do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    IO.should_receive(:read).with('config/database.yml').and_return('a')
    @command_line_interface.parse_command_line_args ['test_unknown_adapter']
    lambda { @command_line_interface.perform }.should raise_error(RuntimeError, /Could not find configuration for >>test_unknown_adapter<</)
  end

  it 'should read yaml file' do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    @command_line_interface.parse_command_line_args []
    IO.should_receive(:read).with('config/database.yml').and_return(TEST_DATABASE_YAML)
    prompt_mock = mock('mysqlprompt')
    prompt_mock.should_receive(:run)
    RGoodies::DbPrompt::MysqlPrompt.should_receive(:new).and_return(prompt_mock)
    @command_line_interface.perform
  end

  it 'should raise when there is no yaml file' do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    f = Tempfile.new('testing.####')
    path = f.path
    f.delete # is there an easier way to create a file-path for a file that doesn't exist?
    @command_line_interface.parse_command_line_args ['no_envo', path]
    lambda { @command_line_interface.perform }.should raise_error(Errno::ENOENT)
  end

  it 'should raise when the yaml file is missing the environment' do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    IO.should_receive(:read).with('config/database.yml').and_return(TEST_DATABASE_YAML)
    @command_line_interface.parse_command_line_args ['no_envo']
    lambda { @command_line_interface.perform }.should raise_error(RuntimeError, 'Could not find configuration for >>no_envo<< in file config/database.yml.')
  end

  it 'should look up environment in yaml file' do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    @command_line_interface.parse_command_line_args %w{ other }
    IO.should_receive(:read).with('config/database.yml').and_return(TEST_DATABASE_YAML)
    mysql_prompt_mock = mock('mysqlprompt')
    mysql_prompt_mock.should_receive(:run)
    expected_init_args = {"username"=>"other_user", "adapter"=>"mysql", "host"=>"localhost", "database"=>"other_db", "password"=>"other_password"}, {}
    RGoodies::DbPrompt::MysqlPrompt.should_receive(:new).with(*expected_init_args).and_return(mysql_prompt_mock)
    @command_line_interface.perform
  end
end

describe RGoodies::DbPrompt::CommandLineInterface, 'passing on options' do

  it 'should pass on ignore option' do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    @command_line_interface.parse_command_line_args %w{ -i a,b,c other }
    IO.should_receive(:read).with('config/database.yml').and_return(TEST_DATABASE_YAML)
    mysql_prompt_mock = mock('mysqlprompt')
    mysql_prompt_mock.should_receive(:run)
    expected_init_args = {"username"=>"other_user", "adapter"=>"mysql", "host"=>"localhost", "database"=>"other_db", "password"=>"other_password"}, {:ignore=>"a,b,c"}
    RGoodies::DbPrompt::MysqlPrompt.should_receive(:new).with(*expected_init_args).and_return(mysql_prompt_mock)
    @command_line_interface.perform
  end

  it 'should pass on executable option' do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    @command_line_interface.parse_command_line_args %w{ -x abc other }
    IO.should_receive(:read).with('config/database.yml').and_return(TEST_DATABASE_YAML)
    mysql_prompt_mock = mock('mysqlprompt')
    mysql_prompt_mock.should_receive(:run)
    expected_init_args = {"username"=>"other_user", "adapter"=>"mysql", "host"=>"localhost", "database"=>"other_db", "password"=>"other_password"}, {:executable=>"abc"}
    RGoodies::DbPrompt::MysqlPrompt.should_receive(:new).with(*expected_init_args).and_return(mysql_prompt_mock)
    @command_line_interface.perform
  end

  it 'should raise when the environment has no known adapter' do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    IO.should_receive(:read).with('config/database.yml').and_return(TEST_DATABASE_YAML)
    @command_line_interface.parse_command_line_args ['test_unknown_adapter']
    lambda { @command_line_interface.perform }.should raise_error(RuntimeError, 'Adapter >>no_such_adapter<< not supported.')
  end

end

describe RGoodies::DbPrompt::CommandLineInterface, 'selecting the AbstractPrompt to invoke' do

  it 'should use PostgresqlPrompt' do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    @command_line_interface.parse_command_line_args %w{ test_postgres_env }
    IO.should_receive(:read).with('config/database.yml').and_return(TEST_DATABASE_YAML)
    prompt_mock = mock('postgresql prompt')
    prompt_mock.should_receive(:run)
    expected_init_args = {"adapter"=>"postgresql", "timeout"=>5000, "database"=>"ps_test", "pool"=>5}, {}
    RGoodies::DbPrompt::PostgresqlPrompt.should_receive(:new).with(*expected_init_args).and_return(prompt_mock)
    @command_line_interface.perform
  end

  it 'should use MysqlPrompt' do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    @command_line_interface.parse_command_line_args %w{ test_mysql_env }
    IO.should_receive(:read).with('config/database.yml').and_return(TEST_DATABASE_YAML)
    prompt_mock = mock('postgresql prompt')
    prompt_mock.should_receive(:run)
    expected_init_args = {"username"=>"dev_user_2", "adapter"=>"mysql", "host"=>"localhost_2", "password"=>"dev_password_2", "database"=>"dev_db_2"}, {}
    RGoodies::DbPrompt::MysqlPrompt.should_receive(:new).with(*expected_init_args).and_return(prompt_mock)
    @command_line_interface.perform
  end

  it 'should use Sqlite3Prompt' do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    @command_line_interface.parse_command_line_args %w{ test_sqlite3_env }
    IO.should_receive(:read).with('config/database.yml').and_return(TEST_DATABASE_YAML)
    prompt_mock = mock('postgresql prompt')
    prompt_mock.should_receive(:run)
    expected_init_args = {"adapter"=>"sqlite3", "timeout"=>5000, "database"=>"test.sqlite3", "pool"=>5}, {}
    RGoodies::DbPrompt::Sqlite3Prompt.should_receive(:new).with(*expected_init_args).and_return(prompt_mock)
    @command_line_interface.perform
  end
end
