require 'spec_helper'

RSpec.describe Straight do

  it 'has logger attribute' do
    @logger = Straight.logger
    expect(@logger).to be_instance_of Logger
    expect(@logger.instance_variable_get(:@logdev).filename).to eq '/dev/null'
    expect(Straight.logger.object_id).to eq @logger.object_id
    Straight.logger = 123
    expect(Straight.logger).to eq 123
  end
end
