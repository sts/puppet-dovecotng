require 'spec_helper'

describe 'dovecotng::mail_plugins' do
  it { is_expected.to run.with_params(nil, '2.4').and_return(nil) }
  it { is_expected.to run.with_params('$mail_plugins sieve', '2.3', '  ').and_return('  mail_plugins = $mail_plugins sieve') }
  it { is_expected.to run.with_params('$mail_plugins sieve quota', '2.4', '  ').and_return("  mail_plugins {\n    sieve = yes\n    quota = yes\n  }") }
  it { is_expected.to run.with_params('quota', '2.4').and_return('mail_plugins = quota') }
  it { is_expected.to run.with_params('$mail_plugins', '2.4').and_return(nil) }
end
