require  File.dirname(__FILE__) + '/spec_helper'

describe RailsGoodies::RdbPrompt do
  it 'should have a VERSION' do
    RailsGoodies::RdbPrompt::VERSION.should be_an_instance_of(String)
  end
end
