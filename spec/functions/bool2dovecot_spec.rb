require 'spec_helper'

describe 'dovecotng::bool2dovecot' do
  it { is_expected.to run.with_params(true).and_return('yes') }
  it { is_expected.to run.with_params(false).and_return('no') }
  it { is_expected.to run.with_params(nil).and_return('no') }
  it { is_expected.to run.with_params('TRUE').and_return('yes') }
  it { is_expected.to run.with_params('false').and_return('no') }
  it { is_expected.to run.with_params('mail').and_return('mail') }
  it { is_expected.to run.with_params(42).and_return('42') }
end
