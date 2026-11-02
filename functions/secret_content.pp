# Render an EPP template that contains credentials as file content.
#
# When any parameter is a Deferred, the template is rendered on the agent
# with inline_epp, so the resolved secret never enters the catalog. The
# template can only use built-in functions, as Puppet language functions of
# this module are not available on the agent.
#
# Otherwise it is rendered during compilation and returned as Sensitive,
# which keeps the content out of reports and PuppetDB.
function dovecotng::secret_content(String[1] $template, Hash $params) >> Variant[Sensitive[String], Deferred] {
  if $params.any |$key, $value| { $value =~ Deferred } {
    Deferred('inline_epp', [file(find_template($template)), $params])
  } else {
    Sensitive(epp($template, $params))
  }
}
