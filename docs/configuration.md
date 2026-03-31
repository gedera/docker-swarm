# Guía de Configuración

La gema `docker-swarm` está diseñada para funcionar con defaults razonables, pero permite una configuración flexible tanto en aplicaciones Ruby puras como en entornos Rails.

## ⚙️ Configuración Global

Utiliza `DockerSwarm.configure` para ajustar los parámetros principales:

```ruby
require 'docker_swarm'

DockerSwarm.configure do |config|
  # Ruta al socket de Docker (default: unix:///var/run/docker.sock)
  config.socket_path = "unix:///var/run/docker.sock"

  # Logger personalizado (default: Logger.new($stdout) o Rails.logger si existe)
  config.logger = MyCustomLogger.new
end
```

### Opciones Disponibles

| Opción | Tipo | Default | Descripción |
| :--- | :--- | :--- | :--- |
| `socket_path` | `String` | `unix:///var/run/docker.sock` | Dirección del socket de Docker. Soporta `http://` si Docker está expuesto vía TCP. |
| `logger` | `Logger` | `Rails.logger` o `Logger.new` | Objeto logger para trazabilidad de peticiones y errores. |

---

## 🏗️ Uso en Rails

En una aplicación Rails, lo ideal es crear un inicializador:

```ruby
# config/initializers/docker_swarm.rb
DockerSwarm.configure do |config|
  config.socket_path = ENV.fetch("DOCKER_URL", "unix:///var/run/docker.sock")
  config.logger = Rails.logger
end
```

### Entornos de Desarrollo
Si usas Docker Desktop en macOS o Windows, la ruta del socket suele ser diferente:

- **macOS**: `unix:///var/run/docker.sock`
- **Linux**: `unix:///var/run/docker.sock`
- **TCP (Remoto)**: `http://1.2.3.4:2375`

---

## 🔍 Inspección de la Configuración

Puedes acceder a la configuración actual en cualquier momento:

```ruby
puts DockerSwarm.configuration.socket_path
```
