# Skill: Error Handling in Gem

Use this skill when handling errors in the `docker-swarm` gem.

## Standard Exceptions
- `Docker::Swarm::Errors::NotFound` (404)
- `Docker::Swarm::Errors::Conflict` (409)
- `Docker::Swarm::Errors::Communication` (Socket issues)

## Guidelines
- Never let raw `Excon::Error` bubble up; catch them in the `Connection` class and wrap them.
- Ensure the `ErrorHandler` middleware translates all 4xx and 5xx status codes correctly.
- Use the `error_message` helper to extract Docker's specific error message from the JSON body.
