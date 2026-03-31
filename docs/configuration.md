# Guía de Configuración

La gema `docker-swarm` está diseñada para funcionar con defaults razonables, pero permite una configuración flexible adaptada a los estándares de producción de Wispro.

## ⚙️ Configuración Global

Utiliza `DockerSwarm.configure` para ajustar los parámetros principales:

```ruby
require 'docker_swarm'

DockerSwarm.configure do |config|
  # Ruta al socket de Docker (default: unix:///var/run/docker.sock)
  config.socket_path = "unix:///var/run/docker.sock"

  # Logger personalizado (default: Logger.new($stdout))
  config.logger = Logger.new($stdout)
  config.log_level = Logger::INFO

  # Timeouts y Reintentos
  config.read_timeout = 60
  config.max_retries = 3
end
```

### Opciones Disponibles

| Opción | Tipo | Default | Descripción |
| :--- | :--- | :--- | :--- |
| `socket_path` | `String` | `unix:///var/run/docker.sock` | Dirección del socket de Docker. Soporta `http://` y `https://`. |
| `logger` | `Logger` | `Logger.new($stdout)` | Objeto logger para trazabilidad de peticiones y errores. |
| `log_level` | `Integer` | `Logger::INFO` | Nivel de verbosidad. En `DEBUG` muestra detalles internos de Excon. |
| `read_timeout` | `Integer` | `60` | Segundos a esperar por una respuesta del daemon. |
| `write_timeout` | `Integer` | `60` | Segundos a esperar para enviar datos al daemon. |
| `connect_timeout` | `Integer` | `10` | Segundos a esperar para abrir la conexión. |
| `max_retries` | `Integer` | `3` | Número máximo de reintentos para errores de red/timeout. |

---

## 🏗️ Uso en Wispro / Rails

Lo ideal es configurar la gema en un initializer (`config/initializers/docker_swarm.rb`):

```ruby
DockerSwarm.configure do |config|
  config.socket_path = ENV.fetch("DOCKER_URL", "unix:///var/run/docker.sock")
  config.logger = Rails.logger
  config.log_level = Rails.logger.level
  config.read_timeout = 30
end
```

## 🔍 Observabilidad

La gema genera logs estructurados en formato Key-Value (KV) para facilitar el parseo por herramientas de monitorización. Estos logs incluyen automáticamente:

- `component`: Identificador del componente (ej. `docker_swarm.connection`).
- `event`: Acción realizada (`request_started`, `request_success`, `business_error`, `request_failure`).
- `source`: Origen de la traza (siempre `http`).
- `duration_ms`: Tiempo total de la petición calculado con reloj monotónico.
- `status`: Código de estado HTTP de la respuesta.

### Seguridad y Enmascaramiento

La gema protege automáticamente la información sensible. Cualquier llave en los payloads que contenga `password`, `token`, `api_key`, `auth` o `secret` será reemplazada por `[FILTERED]` en los logs.

---

## 🚦 Ejemplos por Plataforma

- **macOS**: `unix:///var/run/docker.sock`
- **Linux**: `unix:///var/run/docker.sock`
- **Remote Docker (TCP)**: `http://1.2.3.4:2375` (asegúrate de que el puerto esté abierto en el daemon)
