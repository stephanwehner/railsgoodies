require 'test/unit'
require 'rubygems'
require 'mocha'

require 'db_prompt' # what we're testing

class OptionParsingTest < Test::Unit::TestCase


  def test_no_options
    cli = RGoodies::DbPrompt::CommandLineInterface.new
    result = cli.parse []
    assert_equal [], result
    assert_equal ({}), cli.options
  end

  def test_exec_option
    cli = RGoodies::DbPrompt::CommandLineInterface.new
    assert_raises OptionParser::MissingArgument do
      cli.parse %w(-x)
    end
    cli = RGoodies::DbPrompt::CommandLineInterface.new
    result = cli.parse %w(-x test_ex)
    assert_equal [], result
    assert_equal ({:executable => 'test_ex'}), cli.options
    cli = RGoodies::DbPrompt::CommandLineInterface.new
    result = cli.parse %w(--executable test_ex)
    assert_equal [], result
    assert_equal ({:executable => 'test_ex'}), cli.options

    cli = RGoodies::DbPrompt::CommandLineInterface.new
    result = cli.parse %w(-x test_ex extra arg)
    assert_equal ['extra',  'arg'], result
    assert_equal ({:executable => 'test_ex'}), cli.options
  end
  
  def test_mycnf_only_option
    cli = RGoodies::DbPrompt::CommandLineInterface.new
    result = cli.parse %w(--mycnf)
    assert_equal [], result
    assert_equal ({:mycnf_only => true}), cli.options
  end

  def test_ignore_option
    cli = RGoodies::DbPrompt::CommandLineInterface.new
    assert_raises OptionParser::MissingArgument do
      cli.parse %w(-i)
    end
    cli = RGoodies::DbPrompt::CommandLineInterface.new
    result = cli.parse %w(-i a,b,c)
    assert_equal [], result
    assert_equal ({:ignore => 'a,b,c'}), cli.options
    result = cli.parse %w(--ignore a,b,c,d)
    assert_equal [], result
    assert_equal ({:ignore => 'a,b,c,d'}), cli.options
  end

  def test_verbose_option
    cli = RGoodies::DbPrompt::CommandLineInterface.new
    result = cli.parse %w(-v)
    assert_equal [], result
    assert_equal ({:verbose => true}), cli.options
    result = cli.parse %w(--verbose)
    assert_equal [], result
    assert_equal ({:verbose => true}), cli.options
    result = cli.parse %w(--no-verbose)
    assert_equal [], result
    assert_equal ({:verbose => false}), cli.options
  end
end
