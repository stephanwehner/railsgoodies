require 'db_prompt' # what we're testing


describe RGoodies::DbPrompt::CommandLineInterface do
  it 'should work without any options' do
    cli = RGoodies::DbPrompt::CommandLineInterface.new
    result = cli.parse([])
    result.should == []
    cli.options.should == {}
  end

  it 'should require argument for the -x option' do
    cli = RGoodies::DbPrompt::CommandLineInterface.new
    lambda {cli.parse %w(-x)}.should raise_error(OptionParser::MissingArgument)
  end

  it 'should translate -x option' do
    cli = RGoodies::DbPrompt::CommandLineInterface.new
    result = cli.parse %w(-x test_ex)
    result.should == []
    cli.options.should == {:executable => 'test_ex'}
  end

  it 'should translate --executable option' do
    cli = RGoodies::DbPrompt::CommandLineInterface.new
    result = cli.parse %w(--executable test_ex)
    result.should == []
    cli.options.should == {:executable => 'test_ex'}
  end

  it 'should pass extra options for -x' do
    cli = RGoodies::DbPrompt::CommandLineInterface.new
    result = cli.parse %w(-x test_ex extra arg)
    result.should == ['extra',  'arg']
    cli.options.should == {:executable => 'test_ex'}
  end
end
  
=begin
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
=end
