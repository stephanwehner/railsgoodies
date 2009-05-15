require 'tempfile'
require 'db_prompt' # what we're testing

# Contents
# --------
#
# describe RGoodies::DbPrompt::CommandLineInterface, 'Experimental OptionParser Extensions' 
# describe RGoodies::DbPrompt::CommandLineInterface, 'reading the database.yml file' 
# describe RGoodies::DbPrompt::CommandLineInterface, 'passing on options' 
# describe RGoodies::DbPrompt::CommandLineInterface, 'selecting the AbstractPrompt to invoke' 
# describe RGoodies::DbPrompt::AbstractPrompt 
# describe RGoodies::DbPrompt::Sqlite3Prompt 
# describe RGoodies::DbPrompt::PostgresqlPrompt 
# describe RGoodies::DbPrompt::MysqlPrompt, 'assembling my.cnf'
#


describe RGoodies::DbPrompt::CommandLineInterface, 'Experimental OptionParser Extensions' do
  it 'should work without any options' do
    command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    command_line_interface.parse_command_line_args([])
    command_line_interface.argv.should == []
    command_line_interface.options.should == {}
  end

  it 'should translate -x option' do
    command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    command_line_interface.parse_command_line_args %w(-x test_ex)
    command_line_interface.argv.should == []
    command_line_interface.options.should == {:executable => 'test_ex'}
  end

  it 'should translate --executable option' do
    command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    command_line_interface.parse_command_line_args %w(--executable test_ex)
    command_line_interface.argv.should == []
    command_line_interface.options.should == {:executable => 'test_ex'}
  end

  it 'should require an argument for the -x option' do
    command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    lambda {command_line_interface.parse_command_line_args %w(-x)}.should raise_error(OptionParser::MissingArgument)
  end

  it 'should require an argument for the --executable option' do
    command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    lambda {command_line_interface.parse_command_line_args %w(--executable)}.should raise_error(OptionParser::MissingArgument)
  end

  it 'should pass extra options for -x' do
    command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    command_line_interface.parse_command_line_args %w(-x test_ex extra arg)
    command_line_interface.argv.should == ['extra',  'arg']
    command_line_interface.options.should == {:executable => 'test_ex'}
  end
  
  it 'should accept --mycnf option' do
    command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    command_line_interface.parse_command_line_args %w(--mycnf)
    command_line_interface.argv.should == []
    command_line_interface.options.should == {:mycnf_only => true}
  end

  it 'should accept -i option' do
    command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    command_line_interface.parse_command_line_args %w(-i a,b,c)
    command_line_interface.argv.should == []
    command_line_interface.options.should == {:ignore => 'a,b,c'}

    command_line_interface.parse_command_line_args %w(--ignore a,b,c,d)
    command_line_interface.argv.should == []
    command_line_interface.options.should == {:ignore => 'a,b,c,d'}
  end

  it 'should require an argument for the -i option' do
    command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    lambda { command_line_interface.parse_command_line_args %w(-i)}.should raise_error(OptionParser::MissingArgument)
  end

  it 'should accept -v option' do
    command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    command_line_interface.parse_command_line_args %w(-v)
    command_line_interface.argv.should == []
    command_line_interface.options.should == {:verbose => true}
  end

  it 'should accept --verbose option' do
    command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    command_line_interface.parse_command_line_args %w(--verbose)
    command_line_interface.argv.should == []
    command_line_interface.options.should == {:verbose => true}
  end
 
  it 'should accept --no-verbose option' do
    command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    command_line_interface.parse_command_line_args %w(--no-verbose)
    command_line_interface.argv.should == []
    command_line_interface.options.should == {:verbose => false}
  end

  it 'should accept --version option' do
    command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    command_line_interface.should_receive(:exit).once
    command_line_interface.should_receive(:puts).once

    command_line_interface.parse_command_line_args %w(--version)
    command_line_interface.argv.should == []
    command_line_interface.options.should == {}
  end

  it 'should accept --help option' do
    command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    command_line_interface.should_receive(:exit).once
    command_line_interface.should_receive(:puts).once

    command_line_interface.parse_command_line_args %w(--help)
    command_line_interface.argv.should == []
    command_line_interface.options.should == {}
  end
end

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
    command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    IO.should_receive(:read).with('config/database.yml').and_return('a')
    command_line_interface.parse_command_line_args ['test_unknown_adapter']
    lambda { command_line_interface.perform }.should raise_error(RuntimeError, /Could not find configuration for >>test_unknown_adapter<</)
  end

  it 'should read yaml file' do
    command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    command_line_interface.parse_command_line_args []
    IO.should_receive(:read).with('config/database.yml').and_return(TEST_DATABASE_YAML)
    prompt_mock = mock('mysqlprompt')
    prompt_mock.should_receive(:run)
    RGoodies::DbPrompt::MysqlPrompt.should_receive(:new).and_return(prompt_mock)
    command_line_interface.perform
  end

  it 'should raise when there is no yaml file' do
    command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    f = Tempfile.new('testing.####')
    path = f.path
    f.delete # is there an easier way to create a file-path for a file that doesn't exist?
    command_line_interface.parse_command_line_args ['no_envo', path]
    lambda { command_line_interface.perform }.should raise_error(Errno::ENOENT)
  end

  it 'should raise when the yaml file is missing the environment' do
    command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    IO.should_receive(:read).with('config/database.yml').and_return(TEST_DATABASE_YAML)
    command_line_interface.parse_command_line_args ['no_envo']
    lambda { command_line_interface.perform }.should raise_error(RuntimeError, 'Could not find configuration for >>no_envo<< in file config/database.yml.')
  end

  it 'should look up environment in yaml file' do
    command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    command_line_interface.parse_command_line_args %w{ other }
    IO.should_receive(:read).with('config/database.yml').and_return(TEST_DATABASE_YAML)
    mysql_prompt_mock = mock('mysqlprompt')
    mysql_prompt_mock.should_receive(:run)
    expected_init_args = {"username"=>"other_user", "adapter"=>"mysql", "host"=>"localhost", "database"=>"other_db", "password"=>"other_password"}, {}
    RGoodies::DbPrompt::MysqlPrompt.should_receive(:new).with(*expected_init_args).and_return(mysql_prompt_mock)
    command_line_interface.perform
  end
end

describe RGoodies::DbPrompt::CommandLineInterface, 'passing on options' do
  it 'should pass on ignore option' do
    command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    command_line_interface.parse_command_line_args %w{ -i a,b,c other }
    IO.should_receive(:read).with('config/database.yml').and_return(TEST_DATABASE_YAML)
    mysql_prompt_mock = mock('mysqlprompt')
    mysql_prompt_mock.should_receive(:run)
    expected_init_args = {"username"=>"other_user", "adapter"=>"mysql", "host"=>"localhost", "database"=>"other_db", "password"=>"other_password"}, {:ignore=>"a,b,c"}
    RGoodies::DbPrompt::MysqlPrompt.should_receive(:new).with(*expected_init_args).and_return(mysql_prompt_mock)
    command_line_interface.perform
  end

  it 'should pass on executable option' do
    command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    command_line_interface.parse_command_line_args %w{ -x abc other }
    IO.should_receive(:read).with('config/database.yml').and_return(TEST_DATABASE_YAML)
    mysql_prompt_mock = mock('mysqlprompt')
    mysql_prompt_mock.should_receive(:run)
    expected_init_args = {"username"=>"other_user", "adapter"=>"mysql", "host"=>"localhost", "database"=>"other_db", "password"=>"other_password"}, {:executable=>"abc"}
    RGoodies::DbPrompt::MysqlPrompt.should_receive(:new).with(*expected_init_args).and_return(mysql_prompt_mock)
    command_line_interface.perform
  end

  it 'should raise when the environment has no known adapter' do
    command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    IO.should_receive(:read).with('config/database.yml').and_return(TEST_DATABASE_YAML)
    command_line_interface.parse_command_line_args ['test_unknown_adapter']
    lambda { command_line_interface.perform }.should raise_error(RuntimeError, 'Adapter >>no_such_adapter<< not supported.')
  end
end

describe RGoodies::DbPrompt::CommandLineInterface, 'selecting the AbstractPrompt to invoke' do
  it 'should use PostgresqlPrompt' do
    command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    command_line_interface.parse_command_line_args %w{ test_postgres_env }
    IO.should_receive(:read).with('config/database.yml').and_return(TEST_DATABASE_YAML)
    prompt_mock = mock('postgresql prompt')
    prompt_mock.should_receive(:run)
    expected_init_args = {"adapter"=>"postgresql", "timeout"=>5000, "database"=>"ps_test", "pool"=>5}, {}
    RGoodies::DbPrompt::PostgresqlPrompt.should_receive(:new).with(*expected_init_args).and_return(prompt_mock)
    command_line_interface.perform
  end

  it 'should use MysqlPrompt' do
    command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    command_line_interface.parse_command_line_args %w{ test_mysql_env }
    IO.should_receive(:read).with('config/database.yml').and_return(TEST_DATABASE_YAML)
    prompt_mock = mock('postgresql prompt')
    prompt_mock.should_receive(:run)
    expected_init_args = {"username"=>"dev_user_2", "adapter"=>"mysql", "host"=>"localhost_2", "password"=>"dev_password_2", "database"=>"dev_db_2"}, {}
    RGoodies::DbPrompt::MysqlPrompt.should_receive(:new).with(*expected_init_args).and_return(prompt_mock)
    command_line_interface.perform
  end

  it 'should use Sqlite3Prompt' do
    command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
    command_line_interface.parse_command_line_args %w{ test_sqlite3_env }
    IO.should_receive(:read).with('config/database.yml').and_return(TEST_DATABASE_YAML)
    prompt_mock = mock('postgresql prompt')
    prompt_mock.should_receive(:run)
    expected_init_args = {"adapter"=>"sqlite3", "timeout"=>5000, "database"=>"test.sqlite3", "pool"=>5}, {}
    RGoodies::DbPrompt::Sqlite3Prompt.should_receive(:new).with(*expected_init_args).and_return(prompt_mock)
    command_line_interface.perform
  end
end

describe RGoodies::DbPrompt::AbstractPrompt do
  it 'should raise error when database is empty' do
    lambda {
      abstract_prompt = RGoodies::DbPrompt::AbstractPrompt.new({}, {})
    }.should raise_error(RuntimeError, 'No database name found')
  end

  it 'should raise error when database is the empty string' do
    lambda {
      abstract_prompt = RGoodies::DbPrompt::AbstractPrompt.new({'database' => ''}, {})
    }.should raise_error(RuntimeError, 'Database name is empty')
  end

  it 'should raise error when database has whitespace' do
    lambda {
      abstract_prompt = RGoodies::DbPrompt::AbstractPrompt.new({'database' => ' '}, {})
    }.should raise_error(RuntimeError, 'Database name has whitespace')

    lambda {
      abstract_prompt = RGoodies::DbPrompt::AbstractPrompt.new({'database' => " \n"}, {})
    }.should raise_error(RuntimeError, 'Database name has whitespace')
  end
end

describe RGoodies::DbPrompt::Sqlite3Prompt do
  it 'should inherit from AbstractPrompt' do
    RGoodies::DbPrompt::Sqlite3Prompt.ancestors[1].should == RGoodies::DbPrompt::AbstractPrompt
  end

  it 'should invoke exec with sqlite3 and database' do
    sqlite3_prompt = RGoodies::DbPrompt::Sqlite3Prompt.new({'database'=>'testdb'}, {})
    sqlite3_prompt.should_receive(:exec).with('sqlite3 testdb')
    sqlite3_prompt.run
  end

  it 'should invoke exec with given executable and database' do
    sqlite3_prompt = RGoodies::DbPrompt::Sqlite3Prompt.new({'database'=>'testdb'}, {:executable => 'testexecutable'})
    sqlite3_prompt.should_receive(:exec).with('testexecutable testdb')
    sqlite3_prompt.run
  end
end

describe RGoodies::DbPrompt::PostgresqlPrompt do
  it 'should inherit from AbstractPrompt' do
    RGoodies::DbPrompt::PostgresqlPrompt.ancestors[1].should == RGoodies::DbPrompt::AbstractPrompt
  end

  it 'should invoke exec with psql and database' do
    postgresql_prompt = RGoodies::DbPrompt::PostgresqlPrompt.new({'database'=>'testdb'}, {})
    postgresql_prompt.should_receive(:exec).with('psql testdb')
    postgresql_prompt.run
  end

  it 'should invoke exec with given executable and database' do
    postgresql_prompt = RGoodies::DbPrompt::PostgresqlPrompt.new({'database'=>'testdb'}, {:executable => 'testexecutable'})
    postgresql_prompt.should_receive(:exec).with('testexecutable testdb')
    postgresql_prompt.run
  end
end

describe RGoodies::DbPrompt::MysqlPrompt, 'assembling my.cnf' do
  it 'should inherit from MysqlPrompt' do
    RGoodies::DbPrompt::MysqlPrompt.ancestors[1].should == RGoodies::DbPrompt::AbstractPrompt
  end

  it 'should assemble my.cnf from config' do
    mysql_prompt = RGoodies::DbPrompt::MysqlPrompt.new({'database'=>'testdb'}, {})
    mysql_prompt.get_my_cnf.should == "[client]\ndatabase=testdb"

    mysql_prompt = RGoodies::DbPrompt::MysqlPrompt.new({'a'=>'1',
                                                        'b'=>'2',
                                                        'c'=>'3',
                                                        'd'=>'4',
                                                        'database'=>'required'}, {})
    mysql_prompt.get_my_cnf.should == "[client]\na=1\nb=2\nc=3\nd=4\ndatabase=required"
  end

  # The keys are sorted really just to facilitate testing
  it 'should assemble my.cnf from config by sorting the keys' do
    mysql_prompt = RGoodies::DbPrompt::MysqlPrompt.new({'database'=>'testdb'}, {})
    mysql_prompt.get_my_cnf.should == "[client]\ndatabase=testdb"

    mysql_prompt = RGoodies::DbPrompt::MysqlPrompt.new({'a'=>'1',
                                                        'd'=>'4',
                                                        'c'=>'3',
                                                        'b'=>'2',
                                                        'database'=>'required'}, {})
    mysql_prompt.get_my_cnf.should == "[client]\na=1\nb=2\nc=3\nd=4\ndatabase=required"
  end

  it 'should not copy adpater to my.cnf' do
    mysql_prompt = RGoodies::DbPrompt::MysqlPrompt.new({'adapter' => 'mysql', 'database'=>'testdb'}, {})
    mysql_prompt.get_my_cnf.should == "[client]\ndatabase=testdb"
  end

  it 'should rename username to user in my.cnf' do
    mysql_prompt = RGoodies::DbPrompt::MysqlPrompt.new({'username' => 'test_un', 'database'=>'testdb'}, {})
    mysql_prompt.get_my_cnf.should == "[client]\ndatabase=testdb\nuser=test_un"
  end

  it 'should not copy ignore values to my.cnf' do 
    mysql_prompt = RGoodies::DbPrompt::MysqlPrompt.new({'a'=>'1',
                                                        'b'=>'2',
                                                        'c'=>'3',
                                                        'd'=>'4',
                                                        'database'=>'required'}, {:ignore => 'b'})
    mysql_prompt.get_my_cnf.should == "[client]\na=1\nc=3\nd=4\ndatabase=required"

    mysql_prompt = RGoodies::DbPrompt::MysqlPrompt.new({'a'=>'alphabet',
                                                        'longer'=>'2',
                                                        'x'=>'yz',
                                                        'd'=>'4',
                                                        'database'=>'required'}, {:ignore => 'd,longer'})
    mysql_prompt.get_my_cnf.should == "[client]\na=alphabet\ndatabase=required\nx=yz"
  end
end

describe RGoodies::DbPrompt::MysqlPrompt, 'invoking run' do
  it 'should output my.cnf with mycnf_only option' do
    mysql_prompt = RGoodies::DbPrompt::MysqlPrompt.new({'database' => 'required', 'a'=>'1','b'=>'2'},{:mycnf_only => true})
    mysql_prompt.should_receive(:get_my_cnf).and_return('test my cnf')
    mysql_prompt.should_receive(:puts).with('test my cnf')
    mysql_prompt.run
  end

  it 'should write my.cnf to the pipe-writer' do
    mysql_prompt = RGoodies::DbPrompt::MysqlPrompt.new({'database' => 'required', 'a'=>'1','b'=>'2'},{})
    reader = mock('IO.pipe reader', :fileno => 5)
    writer = mock('IO.pipe writer')
    writer.should_receive(:write).with("test my cnf")
    writer.should_receive(:close)
    IO.should_receive(:pipe).and_return( [reader,writer] )
    mysql_prompt.should_receive(:get_my_cnf).and_return('test my cnf')
    mysql_prompt.should_receive(:exec)
    mysql_prompt.run
  end

  it 'should raise if the pipe-readers fileno is not a Fixnum' do
    ['', nil, Object.new, Fixnum].each do |bad_fileno|
      mysql_prompt = RGoodies::DbPrompt::MysqlPrompt.new({'database' => 'required', 'a'=>'1','b'=>'2'},{})
      reader = mock('IO.pipe reader', :fileno => bad_fileno)
      writer = mock('IO.pipe writer')
      writer.should_receive(:write).with("test my cnf")
      writer.should_receive(:close)
      reader.should_receive(:close)
      IO.should_receive(:pipe).and_return( [reader,writer] )
      mysql_prompt.should_receive(:get_my_cnf).and_return('test my cnf')
      mysql_prompt.should_not_receive(:exec)
      lambda {mysql_prompt.run}.should raise_error(RuntimeError, "Bad fileno >>#{bad_fileno.to_s}<<")
    end
  end

  it 'should pass the pipe-readers fileno as /dev/fd/## to the command' do
    mysql_prompt = RGoodies::DbPrompt::MysqlPrompt.new({'database' => 'required', 'a'=>'1','b'=>'2'},{})
    mock_fileno = mock('IO.pipe reader fileno')
    mock_fileno.should_receive(:is_a?).with(Fixnum).and_return(true)
    mock_fileno.should_receive(:to_s).and_return('thats_the_way')
    reader = mock('IO.pipe reader', :fileno => mock_fileno)
    writer = mock('IO.pipe writer')
    writer.should_receive(:write).with("test my cnf")
    writer.should_receive(:close)
    IO.should_receive(:pipe).and_return( [reader,writer] )
    mysql_prompt.should_receive(:get_my_cnf).and_return('test my cnf')
    mysql_prompt.should_receive(:exec).with("mysql --defaults-file=/dev/fd/thats_the_way")
    mysql_prompt.run
  end

  it 'should invoke exec with given executable' do
    mysql_prompt = RGoodies::DbPrompt::MysqlPrompt.new({'database' => 'required', 'a'=>'1','b'=>'2'},{:executable => 'testexec'})
    reader = mock('IO.pipe reader', :fileno => 3)
    writer = mock('IO.pipe writer')
    writer.should_receive(:write).with("test my cnf")
    writer.should_receive(:close)
    IO.should_receive(:pipe).and_return( [reader,writer] )
    mysql_prompt.should_receive(:get_my_cnf).and_return('test my cnf')
    mysql_prompt.should_receive(:exec).with("testexec --defaults-file=/dev/fd/3")
    mysql_prompt.run
  end
end
