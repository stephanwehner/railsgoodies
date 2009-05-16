require  File.dirname(__FILE__) + '/spec_helper'

describe RailsGoodies::RdbPrompt::AbstractPrompt do
  it 'should raise error when database is empty' do
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

