require 'test/unit'
require 'tempfile'
require 'rubygems'
require 'mocha'

require 'my_sql'

class MySqlTest < Test::Unit::TestCase

  include RailsGoodies::MySql

  GOOD_DATABASE_YML = <<-END
development: 
  adapter: mysql
  database: dev_db
  username: dev_user
  password: dev_password
  host: localhost
other: 
  adapter: mysql
  database: other_db
  username: other_user
  password: other_password
  host: localhost
  END

  def test_no_config_file
    f = Tempfile.new('testing')
    path = f.path
    assert f.delete # is there an easier way to create a file-path for a file that doesn't exist?
    assert_raises Errno::ENOENT do
      produce_command_line( ['dev', path] )
    end
  end
  
  def test_no_args
    IO.expects(:read).returns(GOOD_DATABASE_YML)
    expected = <<-END
{ printf '[client]\nuser=%s\\nhost=%s\\ndatabase=%s\\npassword=%s' dev_user localhost dev_db dev_password |\n3<&0 <&4 4<&- /usr/local/mysql/bin/mysql --defaults-file=/dev/fd/3 \n} 4<&0
    END
    assert_equal expected.strip,  produce_command_line.strip
  end

  def test_empty_password
    # Sometimes one doesn't want to setup  a password.
    # The password should appear at the end in the 
    # "defaults-file" -- Otherwise other options would be shifted up...
    IO.expects(:read).returns(GOOD_DATABASE_YML.sub(/password: dev_password/,'password:'))
    expected = <<-END
{ printf '[client]\nuser=%s\\nhost=%s\\ndatabase=%s\\npassword=%s' dev_user localhost dev_db  |\n3<&0 <&4 4<&- /usr/local/mysql/bin/mysql --defaults-file=/dev/fd/3 \n} 4<&0
    END
    assert_equal expected.strip,  produce_command_line.strip
  end

  def test_other_database
    # Sometimes one doesn't want to setup  a password.
    # The password should appear at the end in the 
    # "defaults-file" -- Otherwise other options would be shifted up...
    IO.expects(:read).returns(GOOD_DATABASE_YML)
    expected = <<-END
{ printf '[client]\nuser=%s\\nhost=%s\\ndatabase=%s\\npassword=%s' other_user localhost other_db other_password |\n3<&0 <&4 4<&- /usr/local/mysql/bin/mysql --defaults-file=/dev/fd/3 \n} 4<&0
    END
    assert_equal expected.strip,  produce_command_line(['other']).strip
  end
end
