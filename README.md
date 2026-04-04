# Docker Swarm Gem

[![Gem Version](https://badge.fury.io/rb/docker-swarm.svg)](https://badge.fury.io/rb/docker-swarm)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

`docker-swarm` es un ORM ligero y cliente API robusto para interactuar con Docker Swarm desde Ruby. Diseñado para sentirse familiar a los desarrolladores de Rails, utiliza `ActiveModel` para ofrecer una interfaz limpia y potente con estándares de observabilidad de Wispro.

## Instalacion

Agrega la gema a tu `Gemfile`:

```ruby
gem 'docker-swarm', '~> 0.5'
```

Y ejecuta:

```bash
bundle install
```

## Quick Start

```ruby
require 'docker_swarm'

# Configurar (opcional, usa defaults razonables)
DockerSwarm.configure do |config|
  config.socket_path = "unix:///var/run/docker.sock"
  config.log_level   = Logger::INFO
  config.max_retries = 3
end

# Verificar conectividad
DockerSwarm::System.up  # => "OK"

# Listar servicios
services = DockerSwarm::Service.all
services.each { |s| puts "#{s.ID}: #{s.Spec[:Name]}" }
```

## Uso

### Crear un servicio

```ruby
service = DockerSwarm::Service.create(
  Name: "my-webapp",
  TaskTemplate: {
    ContainerSpec: { Image: "nginx:latest" }
  }
)
puts service.ID
```

### Actualizar (maneja Version.Index automaticamente)

```ruby
service = DockerSwarm::Service.find("svc-id")
service.update(Mode: { Replicated: { Replicas: 3 } })
```

### Eliminar

```ruby
service.destroy  # graceful: retorna nil si ya no existe
```

### Logs

```ruby
puts service.logs(stdout: 1, stderr: 1)
```

### Filtros

```ruby
DockerSwarm::Service.all(label: ["env=production"])
DockerSwarm::Node.all(role: ["manager"])
DockerSwarm::Container.all(status: ["running"])
```

### Sistema y Cluster

```ruby
DockerSwarm::System.info     # informacion del daemon
DockerSwarm::System.version  # version de Docker
DockerSwarm::System.df       # uso de disco
DockerSwarm::Swarm.show      # informacion del cluster
```

### Manejo de errores

```ruby
begin
  DockerSwarm::Service.create(Name: "web", TaskTemplate: { ... })
rescue DockerSwarm::Conflict => e
  puts "Nombre duplicado"
rescue DockerSwarm::Communication => e
  puts "Docker inalcanzable: #{e.message}"
end
```

## Configuracion

```ruby
DockerSwarm.configure do |config|
  config.socket_path     = "unix:///var/run/docker.sock"  # o http://host:port
  config.logger          = Logger.new($stdout)
  config.log_level       = Logger::INFO
  config.read_timeout    = 60    # segundos
  config.write_timeout   = 60
  config.connect_timeout = 10
  config.max_retries     = 3
end
```

Ver [Guia de Configuracion](docs/configuration.md) para opciones avanzadas, Rails integration y observabilidad.

## Documentacion

- [Modelos (ORM)](docs/models.md) — Todos los modelos, concerns y ciclo de vida
- [Configuracion](docs/configuration.md) — Opciones, observabilidad y seguridad
- [Manejo de Errores](docs/errors.md) — Jerarquia de excepciones y uso
- [Cliente API](docs/api.md) — Acceso de bajo nivel y middlewares
- [Testing](docs/testing.md) — Estrategias de mocking para tus tests

## Contribuir

Las contribuciones son bienvenidas. Por favor, lee `CLAUDE.md` para las guias de desarrollo.

```bash
bundle exec rspec       # tests
bundle exec rubocop -a  # linting
```

## Licencia

Este proyecto esta bajo la licencia MIT.
