# Manejo de Errores

La gema `docker-swarm` proporciona una jerarquia de excepciones clara para manejar fallos de comunicacion, errores de validacion de Docker y problemas de negocio.

## Jerarquia de Excepciones

Todas las excepciones heredan de `DockerSwarm::Error` y estan organizadas jerarquicamente:

- `DockerSwarm::Error` (Clase base)
  - `DockerSwarm::Error::BadRequest` (400) - Payload malformado o parametros invalidos.
  - `DockerSwarm::Error::Unauthorized` (401) - Credenciales invalidas (TLS).
  - `DockerSwarm::Error::Forbidden` (403) - Permisos insuficientes.
  - `DockerSwarm::Error::NotFound` (404) - Recurso no existe.
  - `DockerSwarm::Error::NotAcceptable` (406) - Formato de respuesta no aceptable.
  - `DockerSwarm::Error::RequestTimeout` (408) - Daemon tardo demasiado.
  - `DockerSwarm::Error::Conflict` (409) - Nombre duplicado o recurso en uso.
  - `DockerSwarm::Error::UnprocessableEntity` (422) - Payload semanticamente invalido.
  - `DockerSwarm::Error::TooManyRequests` (429) - Rate limiting.
  - `DockerSwarm::Error::InternalServerError` (500) - Error interno de Docker.
  - `DockerSwarm::Error::BadGateway` (502) - Proxy entre cliente y daemon fallo.
  - `DockerSwarm::Error::ServiceUnavailable` (503) - Daemon reiniciando.
  - `DockerSwarm::Error::GatewayTimeout` (504) - Timeout en proxy intermedio.
  - `DockerSwarm::Error::Communication` - Errores de socket o conexion.

> **Nota:** Tambien puedes acceder a los errores con aliases directos: `DockerSwarm::Conflict`, `DockerSwarm::NotFound`, etc. o via modulo: `DockerSwarm::Errors::Conflict`.

## Ejemplo de Uso

Es recomendable capturar excepciones especificas para manejar el flujo de la aplicacion:

```ruby
begin
  DockerSwarm::Network.create(Name: "my-net")
rescue DockerSwarm::Error::Conflict => e
  puts "La red ya existe, continuando..."
rescue DockerSwarm::Error::Communication => e
  puts "Error conectando con Docker: #{e.message}"
rescue DockerSwarm::Error => e
  puts "Ocurrió un error inesperado: #{e.class} - #{e.message}"
end
```

## Detalles en Logs

Antes de lanzar una excepcion de negocio (4xx/5xx), el `ErrorHandler` de la gema registra un evento `business_error` en el log con el siguiente formato:

`component=docker_swarm.middleware.error_handler event=business_error status=409 message="network with name X already exists" method=post path=/networks/create`

Esto permite diagnosticar problemas rapidamente sin necesidad de inspeccionar el backtrace de la aplicacion.

## Causas Originales

La gema utiliza el mecanismo de `cause` de Ruby para mantener la trazabilidad. Si un error de `Excon` es envuelto por la gema, puedes acceder al error original:

```ruby
rescue DockerSwarm::Error::Communication => e
  puts e.cause.class # Ej: Excon::Error::Timeout
end
```

---

Ver tambien: [Modelos (ORM)](models.md) para el manejo graceful de 404 en `find` y `destroy` | [Testing](testing.md) para mockear errores en tus tests.
