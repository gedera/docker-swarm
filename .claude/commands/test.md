# Skill: Testing Docker Swarm

Use this skill when writing RSpec tests for the gem.

## Test Standards
- **Mock Connection**: Always mock the `Docker::Swarm.connection` to avoid actual socket calls.
- **Mock Response**: Use `double` or `allow_any_instance_of` to simulate Excon responses.
- **Errors**: Verify that error scenarios raise `Docker::Swarm::Errors::*`.

## Example
```ruby
describe Docker::Swarm::Models::Service do
  it "fetches all services" do
    allow(Docker::Swarm::Api::Application).to receive(:request).and_return([{ "ID" => "123" }])
    services = described_class.all
    expect(services.first.ID).to eq("123")
  end
end
```
