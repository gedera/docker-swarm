# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - 2026-03-31

### Added
- **Observability Standards:** Implemented structured KV logging (`component`, `event`, `source`, `duration_ms`) following Wispro standards.
- **Precise Timing:** Integrated `monotonic clock` for accurate request duration measurements.
- **Security:** Added automatic masking of sensitive keys (`password`, `token`, `api_key`, `auth`, `secret`) in logs.
- **Flexible Connection:** Added support for both Unix sockets (`unix://`) and HTTP/TCP connections via `socket_path` configuration.
- **Network Update:** Implemented `Network.update` functionality and endpoint.
- **Enhanced Configuration:** Added `log_level` to the configuration block, allowing runtime adjustments of logging verbosity.
- **Error Handling:** Added `TooManyRequests` (429) error mapping.
- **Integration Tests:** Expanded coverage to include `Service`, `Node`, `Task`, `Swarm`, `System`, `Image`, and `Container`.

### Changed
- **Architectural Refactor:** Moved model files to `lib/docker_swarm/models/` for better organization.
- **ORM Normalization:** Standardized `Base.all` to handle wrapped API responses (e.g., `Volumes`) using `root_key`.
- **API Consistency:** Standardized `logs` methods to instance-level with default parameters (`stdout: 1, stderr: 1`).
- **Swarm/System Unification:** Updated `Swarm` and `System` to inherit from `Base`, enabling dynamic attributes and consistent ORM behavior.
- **Exception Hierarchy:** Refactored error classes to be nested under `DockerSwarm::Error` (e.g., `DockerSwarm::Error::Conflict`) while maintaining root-level aliases.

### Fixed
- **Excon Error Wrapping:** Fixed issue where `Excon` would wrap business exceptions in `Excon::Error::Socket`, ensuring the original cause is raised.
- **Volume All Bug:** Fixed `Volume.all` failing due to Docker's unique response structure.
- **Typo Correction:** Fixed `Gateway_Timeout` to `GatewayTimeout` class name.
- **Gem Entry Point:** Added `lib/docker-swarm.rb` to ensure correct automatic loading by Bundler/Rails.
- **Validation Issues:** Relaxed `Service` validations to allow flexible resource creation during tests.

---

## [0.1.0] - Early 2026
- Initial release with basic ORM for Services, Networks, and Volumes.
