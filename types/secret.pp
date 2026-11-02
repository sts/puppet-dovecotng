# A credential: a plain String, a Sensitive String, or a Deferred function
# call that is resolved on the agent, so the secret is never part of the
# compiled catalog. A Deferred call may return a String or a Sensitive.
type Dovecotng::Secret = Variant[String, Sensitive[String], Deferred]
