require  File.dirname(__FILE__) + '/spec_helper'

describe RGoodies::RdbPrompt::Sqlite3Prompt do
  it 'should inherit from AbstractPrompt' do
    RGoodies::RdbPrompt::Sqlite3Prompt.ancestors[1].should == RGoodies::RdbPrompt::AbstractPrompt
  end

  it 'should invoke exec with sqlite3 and database' do
    sqlite3_prompt = RGoodies::RdbPrompt::Sqlite3Prompt.new({'database'=>'testdb'}, {})
    sqlite3_prompt.should_receive(:exec).with('sqlite3 testdb')
    sqlite3_prompt.run
  end

  it 'should invoke exec with given executable and database' do
    sqlite3_prompt = RGoodies::RdbPrompt::Sqlite3Prompt.new({'database'=>'testdb'}, {:executable => 'testexecutable'})
    sqlite3_prompt.should_receive(:exec).with('testexecutable testdb')
    sqlite3_prompt.run
  end
end

describe RGoodies::RdbPrompt::MysqlPrompt, 'assembling my.cnf' do
  it 'should inherit from MysqlPrompt' do
    RGoodies::RdbPrompt::MysqlPrompt.ancestors[1].should == RGoodies::RdbPrompt::AbstractPrompt
  end

  it 'should assemble my.cnf from config' do
    mysql_prompt = RGoodies::RdbPrompt::MysqlPrompt.new({'database'=>'testdb'}, {})
    mysql_prompt.get_my_cnf.should == "[client]\ndatabase=testdb"

    mysql_prompt = RGoodies::RdbPrompt::MysqlPrompt.new({'a'=>'1',
                                                        'b'=>'2',
                                                        'c'=>'3',
                                                        'd'=>'4',
                                                        'database'=>'required'}, {})
    mysql_prompt.get_my_cnf.should == "[client]\na=1\nb=2\nc=3\nd=4\ndatabase=required"
  end

  # The keys are sorted really just to facilitate testing
  it 'should assemble my.cnf from config by sorting the keys' do
    mysql_prompt = RGoodies::RdbPrompt::MysqlPrompt.new({'database'=>'testdb'}, {})
    mysql_prompt.get_my_cnf.should == "[client]\ndatabase=testdb"

    mysql_prompt = RGoodies::RdbPrompt::MysqlPrompt.new({'a'=>'1',
                                                        'd'=>'4',
                                                        'c'=>'3',
                                                        'b'=>'2',
                                                        'database'=>'required'}, {})
    mysql_prompt.get_my_cnf.should == "[client]\na=1\nb=2\nc=3\nd=4\ndatabase=required"
  end

  it 'should not copy adpater to my.cnf' do
    mysql_prompt = RGoodies::RdbPrompt::MysqlPrompt.new({'adapter' => 'mysql', 'database'=>'testdb'}, {})
    mysql_prompt.get_my_cnf.should == "[client]\ndatabase=testdb"
  end

  it 'should rename username to user in my.cnf' do
    mysql_prompt = RGoodies::RdbPrompt::MysqlPrompt.new({'username' => 'test_un', 'database'=>'testdb'}, {})
    mysql_prompt.get_my_cnf.should == "[client]\ndatabase=testdb\nuser=test_un"
  end

  it 'should not copy ignore values to my.cnf' do 
    mysql_prompt = RGoodies::RdbPrompt::MysqlPrompt.new({'a'=>'1',
                                                        'b'=>'2',
                                                        'c'=>'3',
                                                        'd'=>'4',
                                                        'database'=>'required'}, {:ignore => 'b'})
    mysql_prompt.get_my_cnf.should == "[client]\na=1\nc=3\nd=4\ndatabase=required"

    mysql_prompt = RGoodies::RdbPrompt::MysqlPrompt.new({'a'=>'alphabet',
                                                        'longer'=>'2',
                                                        'x'=>'yz',
                                                        'd'=>'4',
                                                        'database'=>'required'}, {:ignore => 'd,longer'})
    mysql_prompt.get_my_cnf.should == "[client]\na=alphabet\ndatabase=required\nx=yz"
  end
end

describe RGoodies::RdbPrompt::MysqlPrompt, 'invoking run' do
  it 'should output my.cnf with mycnf_only option' do
    mysql_prompt = RGoodies::RdbPrompt::MysqlPrompt.new({'database' => 'required', 'a'=>'1','b'=>'2'},{:mycnf_only => true})
    mysql_prompt.should_receive(:get_my_cnf).and_return('test my cnf')
    mysql_prompt.should_receive(:puts).with('test my cnf')
    mysql_prompt.run
  end

  it 'should write my.cnf to the pipe-writer' do
    mysql_prompt = RGoodies::RdbPrompt::MysqlPrompt.new({'database' => 'required', 'a'=>'1','b'=>'2'},{})
    reader = mock('IO.pipe reader', :fileno => 5)
    writer = mock('IO.pipe writer')
    writer.should_receive(:write).with("test my cnf")
    writer.should_receive(:close)
    IO.should_receive(:pipe).and_return( [reader,writer] )
    mysql_prompt.should_receive(:get_my_cnf).and_return('test my cnf')
    mysql_prompt.should_receive(:exec)
    mysql_prompt.run
  end

  it 'should raise if the pipe-readers fileno is not a Fixnum' do
    ['', nil, Object.new, Fixnum].each do |bad_fileno|
      mysql_prompt = RGoodies::RdbPrompt::MysqlPrompt.new({'database' => 'required', 'a'=>'1','b'=>'2'},{})
      reader = mock('IO.pipe reader', :fileno => bad_fileno)
      writer = mock('IO.pipe writer')
      writer.should_receive(:write).with("test my cnf")
      writer.should_receive(:close)
      reader.should_receive(:close)
      IO.should_receive(:pipe).and_return( [reader,writer] )
      mysql_prompt.should_receive(:get_my_cnf).and_return('test my cnf')
      mysql_prompt.should_not_receive(:exec)
      lambda {mysql_prompt.run}.should raise_error(RuntimeError, "Bad fileno >>#{bad_fileno.to_s}<<")
    end
  end

  it 'should pass the pipe-readers fileno as /dev/fd/## to the command' do
    mysql_prompt = RGoodies::RdbPrompt::MysqlPrompt.new({'database' => 'required', 'a'=>'1','b'=>'2'},{})
    mock_fileno = mock('IO.pipe reader fileno')
    mock_fileno.should_receive(:is_a?).with(Fixnum).and_return(true)
    mock_fileno.should_receive(:to_s).and_return('thats_the_way')
    reader = mock('IO.pipe reader', :fileno => mock_fileno)
    writer = mock('IO.pipe writer')
    writer.should_receive(:write).with("test my cnf")
    writer.should_receive(:close)
    IO.should_receive(:pipe).and_return( [reader,writer] )
    mysql_prompt.should_receive(:get_my_cnf).and_return('test my cnf')
    mysql_prompt.should_receive(:exec).with("mysql --defaults-file=/dev/fd/thats_the_way")
    mysql_prompt.run
  end

  it 'should invoke exec with given executable' do
    mysql_prompt = RGoodies::RdbPrompt::MysqlPrompt.new({'database' => 'required', 'a'=>'1','b'=>'2'},{:executable => 'testexec'})
    reader = mock('IO.pipe reader', :fileno => 3)
    writer = mock('IO.pipe writer')
    writer.should_receive(:write).with("test my cnf")
    writer.should_receive(:close)
    IO.should_receive(:pipe).and_return( [reader,writer] )
    mysql_prompt.should_receive(:get_my_cnf).and_return('test my cnf')
    mysql_prompt.should_receive(:exec).with("testexec --defaults-file=/dev/fd/3")
    mysql_prompt.run
  end
end
