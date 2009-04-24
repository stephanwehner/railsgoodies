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
  database: test_db
  username: test_user
  password: test_password
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
    assert_equal "mysql -h 'localhost' -u 'test_user'",  produce_command_line
  end
end

