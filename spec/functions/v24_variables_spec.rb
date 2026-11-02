require 'spec_helper'

describe 'dovecotng::v24_variables' do
  it { is_expected.to run.with_params(nil).and_return(nil) }
  it { is_expected.to run.with_params("email = '%u'").and_return("email = '%{user}'") }
  it { is_expected.to run.with_params("'%n' AND '%d'").and_return("'%{user|username}' AND '%{user|domain}'") }
  it { is_expected.to run.with_params('%h/Maildir').and_return('%{home}/Maildir') }
  it { is_expected.to run.with_params('%Lu %Ud').and_return('%{user|lower} %{user|domain|upper}') }
  it { is_expected.to run.with_params("LIKE '100%%'").and_return("LIKE '100%%'") }
  it { is_expected.to run.with_params("'%{user|username}'").and_return("'%{user|username}'") }
end
