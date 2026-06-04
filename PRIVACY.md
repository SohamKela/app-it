# Privacy

App It is local-first developer tooling. It runs inside the AI coding
environment you already invoked and works on the local project directory you ask
it to package.

App It itself does not operate a cloud service, collect analytics, phone home, or
transmit project contents to an App It server. Its normal work is limited to
reading local project files, adding local launcher files, generating local icons,
and starting or stopping local dev-server processes during verification.

The host assistant and coding environment may process prompts, file context, and
tool output under their own privacy terms. Those systems are outside App It's
control, so review their policies when deciding what project data to share with
an assistant.

Do not ask App It to handle secrets. If logs or reports are committed or shared,
review them first and remove private `.env` values, tokens, customer data, or
proprietary source excerpts.
