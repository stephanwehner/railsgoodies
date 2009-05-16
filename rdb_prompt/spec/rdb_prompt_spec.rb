require  File.dirname(__FILE__) + '/spec_helper'

describe RGoodies::RdbPrompt do
  it 'should have a VERSION' do
    RGoodies::RdbPrompt::VERSION.should be_an_instance_of(String)
  end
end
