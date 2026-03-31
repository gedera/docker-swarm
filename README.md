# Docker Swarm Gem

[![Gem Version](https://badge.fury.io/rb/docker-swarm.svg)](https://badge.fury.io/rb/docker-swarm)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

`docker-swarm` es un ORM ligero y cliente API robusto para interactuar con Docker Swarm desde Ruby. Diseñado para sentirse familiar a los desarrolladores de Rails, utiliza `ActiveModel` para ofrecer una interfaz limpia y potente.

## 🚀 Inicio Rápido

```ruby
require 'docker_swarm'

# Configurar (opcional, usa defaults)
DockerSwarm.configure do |config|
  config.socket_path = "unix:///var/run/docker.sock"
end

# Listar servicios
services = DockerSwarm::Service.all
services.each { |s| puts "#{s.ID}: #{s.Spec['Name']}" }

# Crear un nuevo servicio
service = DockerSwarm::Service.create(
  Spec: {
    Name: "my-webapp",
    TaskTemplate: {
      ContainerSpec: { Image: "nginx:latest" }
    }
  }
)

# Obtener logs
puts service.logs
```

## 📖 Documentación Completa

Para profundizar en el uso de la gema, consulta las siguientes guías:

1.  **[Guía de Configuración](docs/configuration.md)**: Cómo configurar el socket, logger y opciones globales.
2.  **[Uso del ORM (Modelos)](docs/models.md)**: Todo sobre el ciclo de vida de los recursos (`Service`, `Node`, `Task`, etc.).
3.  **[Cliente de API (Bajo Nivel)](docs/api.md)**: Cómo realizar peticiones personalizadas directamente a la API de Docker.
4.  **[Manejo de Errores](docs/errors.md)**: Jerarquía de excepciones y mapeo de errores de Docker.
5.  **[Pruebas y Mocking](docs/testing.md)**: Guía para testear tu aplicación sin depender de un socket de Docker real.

## 🛠 Características Clave

- **Mapeo PascalCase**: Mantiene la fidelidad con los atributos de Docker (e.g., `s.ID`, `s.Spec`) evitando transformaciones costosas.
- **ActiveModel Ready**: Soporta validaciones, serialización JSON y comportamientos estándar de modelos Ruby.
- **Surgical Updates**: Actualizaciones precisas enviando solo el índice de versión y el payload necesario.
- **Excon Stack**: Basado en `Excon` con middlewares para encoding de peticiones, parseo de respuestas y gestión de errores.

## 🤝 Contribuir

Las contribuciones son bienvenidas. Por favor, lee `CLAUDE.md` para las guías de desarrollo y asegúrate de que todos los tests pasen antes de enviar un PR.

```bash
bundle exec rspec
```

## 📄 Licencia

Este proyecto está bajo la licencia MIT.
