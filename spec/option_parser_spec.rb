require 'tempfile'
require 'db_prompt' # what we're testing


describe RGoodies::DbPrompt::CommandLineInterface, 'Experimental OptionParser Extensions' do

  before(:each) do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
  end

  it 'should work without any options' do
    @command_line_interface.parse_command_line_args([])
    @command_line_interface.argv.should == []
    @command_line_interface.options.should == {}
  end

  it 'should translate -x option' do
    @command_line_interface.parse_command_line_args %w(-x test_ex)
    @command_line_interface.argv.should == []
    @command_line_interface.options.should == {:executable => 'test_ex'}
  end

  it 'should translate --executable option' do
    @command_line_interface.parse_command_line_args %w(--executable test_ex)
    @command_line_interface.argv.should == []
    @command_line_interface.options.should == {:executable => 'test_ex'}
  end

  it 'should require an argument for the -x option' do
    lambda {@command_line_interface.parse_command_line_args %w(-x)}.should raise_error(OptionParser::MissingArgument)
  end

  it 'should require an argument for the --executable option' do
    lambda {@command_line_interface.parse_command_line_args %w(--executable)}.should raise_error(OptionParser::MissingArgument)
  end

  it 'should pass extra options for -x' do
    @command_line_interface.parse_command_line_args %w(-x test_ex extra arg)
    @command_line_interface.argv.should == ['extra',  'arg']
    @command_line_interface.options.should == {:executable => 'test_ex'}
  end
  
  it 'should accept --mycnf option' do
    @command_line_interface.parse_command_line_args %w(--mycnf)
    @command_line_interface.argv.should == []
    @command_line_interface.options.should == {:mycnf_only => true}
  end

  it 'should accept -i option' do
    @command_line_interface.parse_command_line_args %w(-i a,b,c)
    @command_line_interface.argv.should == []
    @command_line_interface.options.should == {:ignore => 'a,b,c'}

    @command_line_interface.parse_command_line_args %w(--ignore a,b,c,d)
    @command_line_interface.argv.should == []
    @command_line_interface.options.should == {:ignore => 'a,b,c,d'}
  end

  it 'should require an argument for the -i option' do
    lambda { @command_line_interface.parse_command_line_args %w(-i)}.should raise_error(OptionParser::MissingArgument)
  end

  it 'should accept -v option' do
    @command_line_interface.parse_command_line_args %w(-v)
    @command_line_interface.argv.should == []
    @command_line_interface.options.should == {:verbose => true}
  end

  it 'should accept --verbose option' do
    @command_line_interface.parse_command_line_args %w(--verbose)
    @command_line_interface.argv.should == []
    @command_line_interface.options.should == {:verbose => true}
  end
 
  it 'should accept --no-verbose option' do
    @command_line_interface.parse_command_line_args %w(--no-verbose)
    @command_line_interface.argv.should == []
    @command_line_interface.options.should == {:verbose => false}
  end

  it 'should accept --version option' do
    @command_line_interface.should_receive(:exit).once
    @command_line_interface.should_receive(:puts).once

    @command_line_interface.parse_command_line_args %w(--version)
    @command_line_interface.argv.should == []
    @command_line_interface.options.should == {}
  end

  it 'should accept --help option' do
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
describe RGoodies::DbPrompt::CommandLineInterface, 'reading the database.yml file' do

  before(:each) do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
  end

 GOOD_DATABASE_YAML = <<END_GOOD_DATABASE_YAML
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
END_GOOD_DATABASE_YAML

  it 'should read yaml file' do
    @command_line_interface.parse_command_line_args []
    IO.should_receive(:read).with('config/database.yml').and_return(GOOD_DATABASE_YAML)
    mysql_prompt_mock = mock('mysqlprompt')
    mysql_prompt_mock.should_receive(:run)
    expected_init_args = {"username"=>"dev_user", "adapter"=>"mysql", "host"=>"localhost", "password"=>"dev_password", "database"=>"dev_db"}, {}
    RGoodies::DbPrompt::MysqlPrompt.should_receive(:new).with(*expected_init_args).and_return(mysql_prompt_mock)
    @command_line_interface.perform
  end

  it 'should raise when there is no yaml file' do
    f = Tempfile.new('testing.####')
    path = f.path
    f.delete # is there an easier way to create a file-path for a file that doesn't exist?
    @command_line_interface.parse_command_line_args ['no_envo', path]
    lambda { @command_line_interface.perform }.should raise_error(Errno::ENOENT)
  end

  it 'should raise when the yaml file is missing the environment' do
    IO.should_receive(:read).with('config/database.yml').and_return(GOOD_DATABASE_YAML)
    @command_line_interface.parse_command_line_args ['no_envo']
    lambda { @command_line_interface.perform }.should raise_error(RuntimeError)
  end

  it 'should look up environment in yaml file' do
    @command_line_interface.parse_command_line_args %w{ other }
    IO.should_receive(:read).with('config/database.yml').and_return(GOOD_DATABASE_YAML)
    mysql_prompt_mock = mock('mysqlprompt')
    mysql_prompt_mock.should_receive(:run)
    expected_init_args = {"username"=>"other_user", "adapter"=>"mysql", "host"=>"localhost", "database"=>"other_db", "password"=>"other_password"}, {}
    RGoodies::DbPrompt::MysqlPrompt.should_receive(:new).with(*expected_init_args).and_return(mysql_prompt_mock)
    @command_line_interface.perform
  end

  it 'should pass on ignore option' do
    @command_line_interface.parse_command_line_args %w{ -i a,b,c other }
    IO.should_receive(:read).with('config/database.yml').and_return(GOOD_DATABASE_YAML)
    mysql_prompt_mock = mock('mysqlprompt')
    mysql_prompt_mock.should_receive(:run)
    expected_init_args = {"username"=>"other_user", "adapter"=>"mysql", "host"=>"localhost", "database"=>"other_db", "password"=>"other_password"}, {:ignore=>"a,b,c"}
    RGoodies::DbPrompt::MysqlPrompt.should_receive(:new).with(*expected_init_args).and_return(mysql_prompt_mock)
    @command_line_interface.perform
  end

  it 'should pass on executable option' do
    @command_line_interface.parse_command_line_args %w{ -x abc other }
    IO.should_receive(:read).with('config/database.yml').and_return(GOOD_DATABASE_YAML)
    mysql_prompt_mock = mock('mysqlprompt')
    mysql_prompt_mock.should_receive(:run)
    expected_init_args = {"username"=>"other_user", "adapter"=>"mysql", "host"=>"localhost", "database"=>"other_db", "password"=>"other_password"}, {:executable=>"abc"}
    RGoodies::DbPrompt::MysqlPrompt.should_receive(:new).with(*expected_init_args).and_return(mysql_prompt_mock)
    @command_line_interface.perform
  end
end
