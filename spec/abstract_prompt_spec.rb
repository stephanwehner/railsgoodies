require  File.dirname(__FILE__) + '/spec_helper'

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

