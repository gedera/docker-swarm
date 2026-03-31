# Cliente de API (Bajo Nivel)

Si necesitas acceder a una funcionalidad de la API de Docker que no esté cubierta por el ORM, puedes usar el cliente de bajo nivel.

## 📡 `Api.request`

Este es el punto de entrada principal para todas las peticiones. La gema utiliza `Excon` con un stack de middlewares optimizado para Docker.

```ruby
response = DockerSwarm::Api.request(
  action: { method: :get, path: "containers/json" },
  query_params: { all: true }
)
```

### Parámetros de `request`

| Parámetro | Tipo | Descripción |
| :--- | :--- | :--- |
| `action` | `Hash` | Contiene `:method` y `:path` (soporta placeholders como `%<id>s`). |
| `arguments` | `Hash` | Valores para interpolar en el `path` (ej. `{ id: "123" }`). |
| `query_params` | `Hash` | Parámetros de la URL. |
| `payload` | `Object` | El cuerpo de la petición. Se serializa según el `Content-Type`. |

---

## 🧬 Encodings Soportados

El `RequestEncoder` detecta automáticamente el formato necesario basándose en el header `Content-Type`:

1.  **JSON (Default)**: Serializa el payload a JSON.
2.  **URL Encoded**: Si el header incluye `application/x-www-form-urlencoded`.
3.  **Multipart**: Si el header incluye `multipart/form-data`.

---

## 🕒 Gestión de Timeouts y Reintentos

Las peticiones utilizan los valores globales de `DockerSwarm.configuration`, pero pueden ser sobrescritos por llamada:

```ruby
DockerSwarm::Api.request(
  action: { method: :get, path: "_ping" },
  read_timeout: 5,
  retries: 0
)
```

---

## 🔄 Middleware Stack

La comunicación con Docker utiliza los siguientes middlewares:

1.  **`Idempotent` & `Instrumentor`**: Gestión nativa de Excon para reintentos y logs.
2.  **`RequestEncoder`**: Serialización inteligente del cuerpo.
3.  **`ResponseJSONParser`**: Parsea JSON y aplica `Deep Indifferent Access`.
4.  **`ErrorHandler`**: Registro de `business_error` y mapeo a excepciones `DockerSwarm::Error`.

---

## 🛠 Peticiones Personalizadas

Puedes saltar la capa de `Api` y hablar directamente con el cliente de conexión:

```ruby
DockerSwarm.request(
  method: :get,
  path: "info"
)
```
