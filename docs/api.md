# Cliente de API (Bajo Nivel)

Si necesitas acceder a una funcionalidad de la API de Docker que no esté cubierta por el ORM, puedes usar el cliente de bajo nivel.

## 📡 `Api.request`

Este es el punto de entrada principal para todas las peticiones. La gema utiliza `Excon` internamente para una comunicación eficiente.

```ruby
response = DockerSwarm::Api.request(
  action: { method: :get, path: "containers/json" },
  query_params: { all: true },
  payload: nil
)
```

### Parámetros de `request`

| Parámetro | Tipo | Descripción |
| :--- | :--- | :--- |
| `action` | `Hash` | Contiene `:method` (e.g., `:get`, `:post`) y `:path` (con placeholders como `%<id>s`). |
| `arguments` | `Hash` | Valores para rellenar los placeholders en el `path`. |
| `query_params` | `Hash` | Parámetros que se añadirán a la URL (e.g., `?all=true`). |
| `payload` | `Hash/String` | El cuerpo de la petición (automáticamente convertido a JSON). |

---

## 🏗️ Endpoints Registrados

La gema define una estructura de endpoints en `DockerSwarm::Api::ENDPOINTS`. Puedes usar estos endpoints registrados de forma manual:

```ruby
# Ejemplo: Obtener versión del sistema
DockerSwarm::System.version

# Ejemplo: Listar tareas de un nodo
DockerSwarm::Api.request(
  action: DockerSwarm::Api::ENDPOINTS[:tasks][:index],
  query_params: { filters: { node: ["node-id"] }.to_json }
)
```

---

## 🔄 Middleware Stack

La comunicación con Docker pasa por una serie de middlewares que facilitan el trabajo:

1.  **`RequestEncoder`**: Asegura que el cuerpo de la petición sea un JSON válido.
2.  **`ResponseParser`**: Parsea automáticamente el JSON de respuesta.
3.  **`ErrorHandler`**: Intercepta códigos de error HTTP (4xx, 5xx) y los traduce a excepciones de Ruby.

---

## 🛠 Peticiones Personalizadas

Si el endpoint que necesitas no está registrado en `ENDPOINTS`, puedes usar el método `request` de `DockerSwarm` directamente:

```ruby
DockerSwarm.request(
  method: :get,
  path: "custom/docker/endpoint",
  query: { param: "value" }
)
```
