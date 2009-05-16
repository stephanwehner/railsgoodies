require  File.dirname(__FILE__) + '/spec_helper'

describe RGoodies::DbPrompt do
  it 'should have a VERSION' do
    RGoodies::DbPrompt::VERSION.should be_an_instance_of(String)
  end
end
