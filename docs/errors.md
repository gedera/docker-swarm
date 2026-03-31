# Manejo de Errores

La gema `docker-swarm` proporciona una jerarquía de excepciones clara para manejar fallos de comunicación, errores de validación de Docker y problemas de negocio.

## 🏛️ Jerarquía de Excepciones

Todas las excepciones heredan de `DockerSwarm::Error` y están organizadas jerárquicamente:

- `DockerSwarm::Error` (Clase base)
  - `DockerSwarm::Error::BadRequest` (400)
  - `DockerSwarm::Error::Unauthorized` (401)
  - `DockerSwarm::Error::Forbidden` (403)
  - `DockerSwarm::Error::NotFound` (404)
  - `DockerSwarm::Error::Conflict` (409) - Ej: Nombre de red duplicado.
  - `DockerSwarm::Error::UnprocessableEntity` (422)
  - `DockerSwarm::Error::TooManyRequests` (429) - Rate limiting.
  - `DockerSwarm::Error::InternalServerError` (500)
  - `DockerSwarm::Error::ServiceUnavailable` (503)
  - `DockerSwarm::Error::GatewayTimeout` (504)
  - `DockerSwarm::Error::Communication` - Errores de socket o conexión.

> **Nota:** Para mantener la compatibilidad, también puedes acceder a los errores mediante `DockerSwarm::Conflict` o `DockerSwarm::Errors::Conflict`.

## 🛠️ Ejemplo de Uso

Es recomendable capturar excepciones específicas para manejar el flujo de la aplicación:

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

## 🔍 Detalles en Logs

Antes de lanzar una excepción de negocio (4xx/5xx), el `ErrorHandler` de la gema registra un evento `business_error` en el log con el siguiente formato:

`component=docker_swarm.middleware.error_handler event=business_error status=409 message="network with name X already exists" method=post path=/networks/create`

Esto permite diagnosticar problemas rápidamente sin necesidad de inspeccionar el backtrace de la aplicación.

## 🔗 Causas Originales

La gema utiliza el mecanismo de `cause` de Ruby para mantener la trazabilidad. Si un error de `Excon` es envuelto por la gema, puedes acceder al error original:

```ruby
rescue DockerSwarm::Error::Communication => e
  puts e.cause.class # Ej: Excon::Error::Timeout
end
```
