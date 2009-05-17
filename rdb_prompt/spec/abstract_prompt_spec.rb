require  File.dirname(__FILE__) + '/spec_helper'

describe RailsGoodies::RdbPrompt::AbstractPrompt do
  it 'should have an initializer that saves the two args' do
    test_config = {'database' => 'tdb', :a => 1, :b => 2}
    test_options = {:opt_1 => 1, :opt_2 => 2}
    abstract_prompt = RailsGoodies::RdbPrompt::AbstractPrompt.new(test_config, test_options)
    abstract_prompt.config.should == test_config
    abstract_prompt.options.should == test_options
  end

  # Some checking on the value of database entry in the first hash is performed for an AbstractPrompt:
  it 'should raise error when database is missing' do
    lambda {
      abstract_prompt = RailsGoodies::RdbPrompt::AbstractPrompt.new({}, {})
    }.should raise_error(RuntimeError, 'No database name found')
  end

  it 'should raise error when database is the empty string' do
    lambda {
      abstract_prompt = RailsGoodies::RdbPrompt::AbstractPrompt.new({'database' => ''}, {})
    }.should raise_error(RuntimeError, 'Database name is empty')
  end

  it 'should raise error when database has whitespace' do
    lambda {
      abstract_prompt = RailsGoodies::RdbPrompt::AbstractPrompt.new({'database' => ' '}, {})
    }.should raise_error(RuntimeError, 'Database name has whitespace')

    lambda {
      abstract_prompt = RailsGoodies::RdbPrompt::AbstractPrompt.new({'database' => " \n"}, {})
    }.should raise_error(RuntimeError, 'Database name has whitespace')
  end

end

