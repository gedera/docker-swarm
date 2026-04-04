# Catálogo de Errores

Referencia completa de excepciones de DockerSwarm. Todas heredan de `DockerSwarm::Error`.

## Jerarquía

```
DockerSwarm::Error (base)
├── BadRequest (400)
├── Unauthorized (401)
├── Forbidden (403)
├── NotFound (404)
├── NotAcceptable (406)
├── RequestTimeout (408)
├── Conflict (409)
├── UnprocessableEntity (422)
├── TooManyRequests (429)
├── InternalServerError (500)
├── BadGateway (502)
├── ServiceUnavailable (503)
├── GatewayTimeout (504)
└── Communication (socket/red)
```

## Acceso

Cada excepción tiene 3 formas de acceso equivalentes:

```ruby
DockerSwarm::NotFound              # alias directo (recomendado)
DockerSwarm::Error::NotFound       # acceso via clase Error
DockerSwarm::Errors::NotFound      # módulo Errors (const_missing dinámico)
```

## Catálogo completo

### BadRequest (400)

**Causa:** Payload malformado o parámetros inválidos.
**Reproducción:** Enviar JSON con campos incorrectos (ej: `Replicas: "abc"` en vez de integer).
**Resolución:** Validar payload contra la documentación de Docker API. Verificar tipos de datos.

### Unauthorized (401)

**Causa:** Credenciales inválidas o ausentes para Docker daemon con TLS.
**Reproducción:** Conectar a daemon protegido sin certificados.
**Resolución:** Configurar TLS client certificates en Excon o en la URL de conexión.

### Forbidden (403)

**Causa:** Permisos insuficientes para la operación.
**Reproducción:** Intentar operación de swarm en un nodo worker.
**Resolución:** Verificar que el nodo es manager y que el usuario tiene permisos sobre el socket.

### NotFound (404)

**Causa:** Recurso no existe o fue eliminado.
**Reproducción:** `Service.find("id_inexistente")`.
**Resolución:** `Base.find` retorna `nil` automáticamente. `Deletable#destroy` también es graceful (retorna `nil` en 404). No requiere rescue manual en estos casos.

### NotAcceptable (406)

**Causa:** El servidor no puede producir una respuesta aceptable.
**Reproducción:** Raro en Docker API.
**Resolución:** Verificar headers Accept del request.

### RequestTimeout (408)

**Causa:** Docker daemon tardó demasiado en responder.
**Reproducción:** Operación en un cluster sobrecargado.
**Resolución:** Incrementar `read_timeout` en configuración. Verificar estado del cluster.

### Conflict (409)

**Causa:** Nombre duplicado, recurso en uso, o versión desactualizada.
**Reproducción:** `Service.create(Name: "nombre_existente")` o update con `Version.Index` stale.
**Resolución:** Para nombres: verificar existencia antes de crear. Para versiones: hacer `reload` y reintentar el update.

### UnprocessableEntity (422)

**Causa:** Payload semánticamente inválido.
**Reproducción:** Crear servicio con imagen inexistente y restricciones de scheduling imposibles.
**Resolución:** Verificar que la imagen existe y que las constraints del servicio son alcanzables.

### TooManyRequests (429)

**Causa:** Rate limiting del Docker daemon o registry.
**Reproducción:** Burst de requests al API.
**Resolución:** Implementar backoff. Los retries de Excon cubren errores de socket/timeout pero no 429.

### InternalServerError (500)

**Causa:** Error interno del Docker daemon.
**Reproducción:** Bug en Docker, operación sobre estado inconsistente, o update sin `version` query param.
**Resolución:** Verificar logs del Docker daemon (`journalctl -u docker`). Si es por version faltante, usar el modelo (Updatable lo maneja).

### BadGateway (502)

**Causa:** Proxy o load balancer entre cliente y daemon devuelve error.
**Reproducción:** Docker daemon detrás de reverse proxy caído.
**Resolución:** Verificar infraestructura de red y proxy.

### ServiceUnavailable (503)

**Causa:** Docker daemon reiniciando o en mantenimiento.
**Reproducción:** Request durante restart del servicio Docker.
**Resolución:** Reintentar después de esperar. `max_retries` cubre errores de socket pero no 503.

### GatewayTimeout (504)

**Causa:** Proxy entre cliente y daemon timeout.
**Reproducción:** Operación larga detrás de proxy con timeout corto.
**Resolución:** Incrementar timeout del proxy. Verificar que `read_timeout` de la gema es menor que el del proxy.

### Communication

**Causa:** Error de socket o red — daemon caído, socket inexistente, permisos insuficientes.
**Reproducción:** `DockerSwarm::System.up` con daemon apagado.
**Resolución:** Verificar que Docker está corriendo (`systemctl status docker`), que el socket existe y que el usuario tiene permisos de lectura.

## Manejo recomendado

```ruby
begin
  DockerSwarm::Service.create(Name: "web", TaskTemplate: { ... })
rescue DockerSwarm::Conflict => e
  # Nombre duplicado — buscar existente
  existing = DockerSwarm::Service.all(name: ["web"]).first
rescue DockerSwarm::Communication => e
  # Docker caído
  logger.error("Docker unreachable: #{e.message}")
rescue DockerSwarm::Error => e
  # Cualquier otro error de Docker
  logger.error("Docker error: #{e.class} #{e.message}")
end
```

## Logging automático

El middleware ErrorHandler loguea automáticamente antes de raise:

```
component=docker_swarm.middleware.error_handler event=business_error source=http status=409 message="name conflicts" method=post path=/services/create
```

Formato KV con masking de datos sensibles via LogHelper.

## Causa original (Excon wrapping)

Excon puede envolver excepciones del middleware en `Excon::Error::Socket`. Connection detecta esto y re-raise la excepción original:

```ruby
# Connection#request internamente:
actual_error = e.cause&.class&.name&.include?("DockerSwarm::Error") ? e.cause : e
```

La excepción original mantiene la causa via `Exception#cause` de Ruby para trazabilidad completa.
