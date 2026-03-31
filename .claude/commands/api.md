# Skill: Docker API Endpoints

Use this skill when adding or modifying endpoints in `Docker::Swarm::Api`.

## Adding a New Endpoint
1.  **Register Endpoint**: Add the method, path (with placeholders if needed), and params to `Docker::Swarm::Api::Application::ENDPOINTS`.
    ```ruby
    # Example:
    containers: {
      stats: { method: :get, path: 'containers/%<id>s/stats' }
    }
    ```
2.  **Add API Method**: In the corresponding class (e.g., `Api::Container`), call `request`.
    ```ruby
    def self.stats(id)
      request(action: ENDPOINTS[:containers][:stats], arguments: { id: id })
    end
    ```

## Path Placeholders
- Use `%<id>s` for dynamic values.
- Ensure all placeholders in the path are passed in `arguments: { ... }`.
