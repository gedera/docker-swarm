# Uso del ORM (Modelos)

La gema `docker-swarm` proporciona una capa de abstraccion sobre la API de Docker Swarm, permitiendote interactuar con los recursos del cluster como si fueran objetos Ruby estandar.

## Conceptos Base

Todos los modelos heredan de `DockerSwarm::Base` y están integrados con `ActiveModel`.

### Mapeo PascalCase y Deep Indifferent Access
Para mantener la fidelidad con la API de Docker, los modelos utilizan `PascalCase`. La gema aplica automáticamente `with_indifferent_access` a todos los atributos (Hashes y Arrays), permitiendo el acceso mediante símbolos o strings:

```ruby
service = DockerSwarm::Service.find("123")
puts service.ID           # Acceso directo al ID de Docker
puts service.Spec[:Name]  # Símbolo (indifferent access)
puts service.Spec['Name'] # String (indifferent access)
```

### Accesores Dinámicos
Si Docker añade nuevos campos a la respuesta JSON, la gema los expondrá automáticamente mediante `method_missing` sin necesidad de actualizar el código.

---

## Ciclo de Vida de los Recursos

### Listado y Búsqueda
- **`.all(filters = {})`**: Lista todos los recursos.
- **`.find(id)`**: Busca un recurso específico por ID. Retorna `nil` si no existe.
- **`.where(filters)`**: Alias para `.all` con filtrado nativo de Docker.

La gema maneja automáticamente respuestas especiales (como la de `Volume`) para que siempre recibas un array de objetos.

### Creación (`Concerns::Creatable`)
```ruby
# Los modelos validan automáticamente la presencia de campos clave como Name
service = DockerSwarm::Service.create(Name: "web", Spec: { ... })
if service.persisted?
  puts "Servicio creado con ID: #{service.ID}"
else
  puts "Errores: #{service.errors.full_messages}"
end
```

### Actualización (`Concerns::Updatable`)
La gema gestiona automáticamente el índice de versión de Docker (`Index`) para realizar actualizaciones atómicas.

```ruby
network = DockerSwarm::Network.find("my-net")
network.update(Labels: { env: "prod" })
```

---

## Guia de Modelos Especificos

| Modelo | Concerns Incluidos | Métodos Adicionales |
| :--- | :--- | :--- |
| `Service` | `Creatable`, `Updatable`, `Deletable` | `#logs` |
| `Node` | `Updatable`, `Deletable` | - |
| `Task` | - | `#logs` |
| `Container` | `Deletable` | `#start`, `#stop`, `#logs` |
| `Network` | `Creatable`, `Updatable`, `Deletable` | - |
| `Volume` | `Creatable`, `Deletable` | - |
| `Config` | `Creatable`, `Deletable` | - |
| `Secret` | `Creatable`, `Deletable` | - |
| `Image` | `Creatable`, `Deletable` | - |
| `Swarm` | - | `.show` |
| `System` | - | `.info`, `.version`, `.up`, `.df` |

### Obtencion de Logs
El método `#logs` ha sido estandarizado a nivel de instancia en `Service`, `Task` y `Container`. Por defecto, solicita tanto `stdout` como `stderr`.

```ruby
service = DockerSwarm::Service.find("abc")
puts service.logs(stdout: 1, stderr: 0) # Solo salida estándar
```

### Swarm y System
`Swarm` y `System` heredan de `Base`, permitiendo acceder a sus atributos de forma dinamica:

```ruby
info = DockerSwarm::System.info
puts info["Swarm"]["LocalNodeState"] # => "active"

swarm = DockerSwarm::Swarm.show
puts swarm["ID"]
```

---

Ver tambien: [Configuracion](configuration.md) para opciones de conexion y timeouts | [Manejo de Errores](errors.md) para excepciones en operaciones CRUD | [Testing](testing.md) para mockear modelos en tus tests.
