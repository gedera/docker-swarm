# Uso del ORM (Modelos)

La gema `docker-swarm` proporciona una capa de abstracción sobre la API de Docker Swarm, permitiéndote interactuar con los recursos del cluster como si fueran objetos Ruby estándar.

## 🏛️ Conceptos Base

Todos los modelos heredan de `DockerSwarm::Base` y están integrados con `ActiveModel`.

### Mapeo PascalCase
Para mantener la fidelidad con la API de Docker y facilitar el mapeo de atributos, los modelos utilizan `PascalCase` para sus atributos y métodos de acceso:

```ruby
service = DockerSwarm::Service.find("123")
puts service.ID           # Acceso directo al ID de Docker
puts service.Spec['Name'] # Acceso a los atributos del Spec
puts service.Version      # Acceso al índice de versión
```

### Accesores Dinámicos
Si Docker añade nuevos campos a la respuesta JSON, la gema los expondrá automáticamente mediante `method_missing` sin necesidad de actualizar el código.

---

## 🔄 Ciclo de Vida de los Recursos

### Listado y Búsqueda
- **`.all(filters = {})`**: Lista todos los recursos. Soporta filtros nativos de Docker.
- **`.find(id)`**: Busca un recurso específico por ID. Retorna `nil` si no existe.
- **`.where(filters)`**: Alias para `.all` con filtrado.

```ruby
# Listar servicios con nombre específico
services = DockerSwarm::Service.all(name: "my-service")

# Buscar un nodo
node = DockerSwarm::Node.find("node-id")
```

### Creación (`Concerns::Creatable`)
Los modelos que incluyen este concern pueden ser creados mediante `.create` o `#save`.

```ruby
# Método de clase
service = DockerSwarm::Service.create(Spec: { Name: "web" })

# Método de instancia
service = DockerSwarm::Service.new(Spec: { Name: "web" })
service.save # Retorna true/false y asigna el ID tras la creación
```

### Actualización (`Concerns::Updatable`)
Permite actualizar recursos existentes. La gema gestiona automáticamente el índice de versión de Docker para evitar conflictos de escritura.

```ruby
service = DockerSwarm::Service.find("123")
service.update(Spec: { Name: "new-name" })
```

### Eliminación (`Concerns::Deletable`)
Permite destruir recursos de forma segura.

```ruby
# Por instancia
service.destroy

# Por ID
DockerSwarm::Service.destroy("123")
```

---

## 📦 Guía de Modelos Específicos

| Modelo | Concerns Incluidos | Métodos Adicionales |
| :--- | :--- | :--- |
| `Service` | `Creatable`, `Updatable`, `Deletable` | `#logs` |
| `Node` | `Updatable`, `Deletable` | - |
| `Task` | - | `#logs` |
| `Container` | `Deletable` | `#start`, `#stop`, `#logs` |
| `Network` | `Creatable`, `Deletable` | - |
| `Volume` | `Creatable`, `Deletable` | - |
| `Config` | `Creatable`, `Deletable` | - |
| `Secret` | `Creatable`, `Deletable` | - |
| `Image` | `Creatable`, `Deletable` | - |

### Ejemplo: Logs de un Servicio
```ruby
service = DockerSwarm::Service.find("abc")
puts service.logs # Obtiene logs de todas las tareas del servicio
```

### Ejemplo: Control de Contenedores
```ruby
container = DockerSwarm::Container.find("xyz")
container.stop
container.start
```
