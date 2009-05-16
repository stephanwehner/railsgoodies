require  File.dirname(__FILE__) + '/spec_helper'

describe RGoodies::DbPrompt::PostgresqlPrompt do
  it 'should inherit from AbstractPrompt' do
    RGoodies::DbPrompt::PostgresqlPrompt.ancestors[1].should == RGoodies::DbPrompt::AbstractPrompt
  end

  it 'should invoke exec with psql and database' do
    postgresql_prompt = RGoodies::DbPrompt::PostgresqlPrompt.new({'database'=>'testdb'}, {})
    postgresql_prompt.should_receive(:exec).with('psql testdb')
    postgresql_prompt.run
  end

  it 'should invoke exec with given executable and database' do
    postgresql_prompt = RGoodies::DbPrompt::PostgresqlPrompt.new({'database'=>'testdb'}, {:executable => 'testexecutable'})
    postgresql_prompt.should_receive(:exec).with('testexecutable testdb')
    postgresql_prompt.run
  end
end

