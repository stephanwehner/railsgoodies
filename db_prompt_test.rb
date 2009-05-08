require 'test/unit'
require 'tempfile'
require 'rubygems'
require 'mocha'
require 'mocha_ext'

require 'db_prompt'

class DbPromptTest < Test::Unit::TestCase

  include RGoodies::DbPrompt

  GOOD_DATABASE_YML = <<-END
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
  END

  def test_no_config_file
    f = Tempfile.new('testing')
    path = f.path
    assert f.delete # is there an easier way to create a file-path for a file that doesn't exist?
    assert_raises Errno::ENOENT do
      perform({} , ['no_envo', path])
    end
  end
  
  def test_no_args
    IO.expects(:read).returns(GOOD_DATABASE_YML)
    stub_exec
    result = perform({}, [])
    assert_match /mysql \-\-defaults\-file=\/dev\/fd\/\d+/, result
  end

  def test_empty_password
    # Sometimes one doesn't want to setup  a password.
    # Using quotes to handle
    IO.expects(:read).returns(GOOD_DATABASE_YML.sub(/password: dev_password/,'password:'))
    expected = <<-END
{ ruby my_sql.rb  --mycnf development config/database.yml |
3<&0 <&4 4<&- mysql --defaults-file=/dev/fd/3 
} 4<&0
    END
    assert_equal expected.strip,  produce_command_line.strip
  end

  def test_other_database
    IO.expects(:read).returns(GOOD_DATABASE_YML)
    expected = <<-END
{ ruby my_sql.rb  --mycnf other config/database.yml |
3<&0 <&4 4<&- mysql --defaults-file=/dev/fd/3 
} 4<&0
    END
    assert_equal expected.strip,  produce_command_line(['other']).strip
  end

  def test_executable
    IO.expects(:read).returns(GOOD_DATABASE_YML)
    expected = <<-END
{ ruby my_sql.rb  --mycnf other config/database.yml |
3<&0 <&4 4<&- test_ex --defaults-file=/dev/fd/3 
} 4<&0
    END
    assert_equal expected.strip,  produce_command_line(['other'], {:executable=>'test_ex'}).strip
  end

  def test_ignore
    yaml = GOOD_DATABASE_YML.dup
    yaml << "  encoding: utf8\n"
    yaml << '  other_opt: other_setting'
    IO.expects(:read).returns(yaml).at_least(3)
    expected = <<-END
{ ruby my_sql.rb  --mycnf other config/database.yml |
3<&0 <&4 4<&- mysql --defaults-file=/dev/fd/3 
} 4<&0
    END
    assert_equal expected.strip,  produce_command_line(['other']).strip
    expected = <<-END
{ ruby my_sql.rb --ignore encoding --mycnf other config/database.yml |
3<&0 <&4 4<&- mysql --defaults-file=/dev/fd/3 
} 4<&0
    END
    assert_equal expected.strip,  produce_command_line(['other'], {:ignore=>'encoding'}).strip
    expected = <<-END
{ ruby my_sql.rb --ignore encoding,other_opt --mycnf other config/database.yml |
3<&0 <&4 4<&- mysql --defaults-file=/dev/fd/3 
} 4<&0
    END
    assert_equal expected.strip,  produce_command_line(['other'], {:ignore=>'encoding,other_opt'}).strip
  end

  def test_mycnf
    yaml = GOOD_DATABASE_YML.dup
    yaml << "  encoding: utf8"
    IO.expects(:read).returns(yaml).at_least(2)
    expected = <<-END
[client]
database=other_db
encoding=utf8
host=localhost
password=other_password
user=other_user
    END
    assert_equal expected.strip,  produce_command_line(['other'], {:mycnf=>true}).strip
    expected = <<-END
[client]
database=other_db
host=localhost
password=other_password
user=other_user
    END
    assert_equal expected.strip,  produce_command_line(['other'], {:ignore=>'encoding', :mycnf=>true}).strip
  end

  def stub_exec
    exec_stub = lambda do |one, two|
      two
    end
    RGoodies::DbPrompt::MysqlPrompt.any_instance.stubs(:exec).returns(exec_stub)
  end

  class Stdin
    attr_accessor :puts_collector
    attr_accessor :closed
    def initialize
      @puts_collector = []
      @closed = false
    end
    def puts(s)
      raise 'closed' if @closed
      @puts_collector << s
    end
    def close
      @closed = true
    end
  end

  class Stdout
    def entries
      ['testing']
    end
  end
end
