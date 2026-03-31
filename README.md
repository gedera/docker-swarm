# Docker Swarm Gem

[![Gem Version](https://badge.fury.io/rb/docker-swarm.svg)](https://badge.fury.io/rb/docker-swarm)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

`docker-swarm` es un ORM ligero y cliente API robusto para interactuar con Docker Swarm desde Ruby. Diseñado para sentirse familiar a los desarrolladores de Rails, utiliza `ActiveModel` para ofrecer una interfaz limpia y potente con estándares de observabilidad de Wispro.

## 🚀 Inicio Rápido

```ruby
require 'docker_swarm'

# Configurar (opcional, usa defaults)
DockerSwarm.configure do |config|
  config.socket_path = "unix:///var/run/docker.sock"
  config.log_level = Logger::INFO
  config.read_timeout = 30
  config.max_retries = 3
end

# Listar servicios (con soporte para Indifferent Access en arrays)
services = DockerSwarm::Service.all
services.each { |s| puts "#{s.ID}: #{s.Spec[:Name]}" }

# Crear un nuevo servicio
service = DockerSwarm::Service.create(
  Name: "my-webapp",
  Spec: {
    TaskTemplate: {
      ContainerSpec: { Image: "nginx:latest" }
    }
  }
)

# Obtener logs (stdout y stderr habilitados por defecto)
puts service.logs
```

## 🛠 Características Clave

- **Observabilidad Wispro**: Logging estructurado (KV) con `component`, `event`, `source` y `duration_ms` usando reloj monotónico.
- **Seguridad**: Enmascaramiento automático de secretos (`password`, `token`, etc.) en los logs.
- **Deep Indifferent Access**: Acceso a atributos mediante símbolos o strings, incluso en resultados de listados (`.all`).
- **Resiliencia**: Gestión inteligente de timeouts (`read`, `write`, `connect`) y reintentos automáticos para errores de red.
- **Mapeo PascalCase**: Mantiene la fidelidad con los atributos de Docker (e.g., `s.ID`, `s.Spec`) evitando transformaciones costosas.
- **ActiveModel Ready**: Soporta validaciones, serialización JSON y comportamientos estándar de modelos Ruby.

## 🤝 Contribuir

Las contribuciones son bienvenidas. Por favor, lee `CLAUDE.md` para las guías de desarrollo y asegúrate de que todos los tests pasen antes de enviar un PR.

```bash
bundle exec rspec
```

## 📄 Licencia

Este proyecto está bajo la licencia MIT.
