# Skill: Swarm ORM Models

Use this skill when creating or extending ORM models in `Docker::Swarm::Models`.

## Adding a New Resource
1.  **Create File**: Inherit from `Base`.
    ```ruby
    module Docker::Swarm::Models
      class Config < Base
        include Concerns::Creatable
        include Concerns::Deletable
      end
    end
    ```
2.  **Custom Mapping**: Use `assign_attributes` to normalize IDs if necessary.
3.  **CRUD Actions**:
    - `.create(Spec: { ... })`
    - `#update(Spec: { ... })`
    - `.find(id)`
    - `#destroy`

## Dynamic Attributes
- Models automatically map PascalCase keys (e.g. `Spec`) to Ruby accessors.
- Use `persisted?` to check if a resource has an ID.
- Use `payload_for_docker` to build the Hash for API calls.
