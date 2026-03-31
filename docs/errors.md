# Manejo de Errores

La gema `docker-swarm` traduce los errores de la API de Docker y de red a excepciones de Ruby claras y manejables.

## 🏛️ Jerarquía de Excepciones

Todas las excepciones heredan de `DockerSwarm::Errors::Error`.

-   **`Error`**: Clase base para todos los errores de la gema.
-   **`Communication`**: Errores de red o de socket (e.g., el socket no existe o no hay permisos).
-   **`NotFound`**: El recurso solicitado (nodo, servicio, etc.) no existe (HTTP 404).
-   **`Conflict`**: El recurso ya existe o hay un conflicto de versiones (HTTP 409).
-   **`Unauthorized`**: Problemas de permisos con la API de Docker (HTTP 401).
-   **`Server`**: Error interno de la API de Docker (HTTP 500).

---

## 🛠 Cómo capturar errores

Se recomienda capturar excepciones específicas para mejorar la experiencia de usuario o la lógica de negocio:

```ruby
begin
  service = DockerSwarm::Service.find("123")
  service.destroy
rescue DockerSwarm::Errors::NotFound
  puts "El servicio ya no existe."
rescue DockerSwarm::Errors::Communication => e
  puts "No se pudo conectar con Docker: #{e.message}"
rescue DockerSwarm::Errors::Error => e
  puts "Ocurrió un error inesperado: #{e.message}"
end
```

---

## 🔄 Mapeo Automático

El middleware `ErrorHandler` se encarga de convertir los códigos de estado HTTP de Docker en excepciones de Ruby:

| Código HTTP | Excepción |
| :--- | :--- |
| 401 | `DockerSwarm::Errors::Unauthorized` |
| 404 | `DockerSwarm::Errors::NotFound` |
| 409 | `DockerSwarm::Errors::Conflict` |
| 500 | `DockerSwarm::Errors::Server` |
| Otros 4xx/5xx | `DockerSwarm::Errors::Error` |

---

## 🔍 Detalles del Error

Cuando Docker devuelve un error, la gema intenta extraer el mensaje descriptivo del JSON de respuesta para incluirlo en el mensaje de la excepción:

```ruby
begin
  DockerSwarm::Service.create(Spec: { Name: "nombre_invalido!" })
rescue DockerSwarm::Errors::Error => e
  puts e.message # Muestra el mensaje específico de Docker
end
```
