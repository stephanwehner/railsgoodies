require 'db_prompt' # what we're testing


describe RGoodies::DbPrompt::CommandLineInterface do

  before(:each) do
    @command_line_interface = RGoodies::DbPrompt::CommandLineInterface.new
  end

  it 'should work without any options' do
    result = @command_line_interface.parse([])
    result.should == []
    @command_line_interface.options.should == {}
  end

  it 'should translate -x option' do
    result = @command_line_interface.parse %w(-x test_ex)
    result.should == []
    @command_line_interface.options.should == {:executable => 'test_ex'}
  end

  it 'should translate --executable option' do
    result = @command_line_interface.parse %w(--executable test_ex)
    result.should == []
    @command_line_interface.options.should == {:executable => 'test_ex'}
  end

  it 'should require an argument for the -x option' do
    lambda {@command_line_interface.parse %w(-x)}.should raise_error(OptionParser::MissingArgument)
  end

  it 'should require an argument for the --executable option' do
    lambda {@command_line_interface.parse %w(--executable)}.should raise_error(OptionParser::MissingArgument)
  end

  it 'should pass extra options for -x' do
    result = @command_line_interface.parse %w(-x test_ex extra arg)
    result.should == ['extra',  'arg']
    @command_line_interface.options.should == {:executable => 'test_ex'}
  end
  
  it 'should accept --mycnf option' do
    result = @command_line_interface.parse %w(--mycnf)
    result.should == []
    @command_line_interface.options.should == {:mycnf_only => true}
  end

  it 'should accept -i option' do
    result = @command_line_interface.parse %w(-i a,b,c)
    result.should == []
    @command_line_interface.options.should == {:ignore => 'a,b,c'}

    result = @command_line_interface.parse %w(--ignore a,b,c,d)
    result.should == []
    @command_line_interface.options.should == {:ignore => 'a,b,c,d'}
  end

  it 'should require an argument for the -i option' do
    lambda { @command_line_interface.parse %w(-i)}.should raise_error(OptionParser::MissingArgument)
  end

  it 'should accept -v option' do
    result = @command_line_interface.parse %w(-v)
    result.should == []
    @command_line_interface.options.should == {:verbose => true}
  end

  it 'should accept --verbose option' do
    result = @command_line_interface.parse %w(--verbose)
    result.should == []
    @command_line_interface.options.should == {:verbose => true}
  end
 
  it 'should accept --no-verbose option' do
    result = @command_line_interface.parse %w(--no-verbose)
    result.should == []
    @command_line_interface.options.should == {:verbose => false}
  end

  it 'should accept --version option' do
    @command_line_interface.should_receive(:exit).once
    @command_line_interface.should_receive(:puts).once
    result = @command_line_interface.parse %w(--version)
    result.should == []
    @command_line_interface.options.should == {}
  end

  it 'should accept --help option' do
    @command_line_interface.should_receive(:exit).once
    @command_line_interface.should_receive(:puts).once
    result = @command_line_interface.parse %w(--help)
    result.should == []
    @command_line_interface.options.should == {}
  end
end
