require 'excon'
require 'json'

begin
  puts "Probando conexión con /var/run/docker.sock..."
  conn = Excon.new("unix:///", socket: "/var/run/docker.sock")
  res = conn.request(method: :get, path: "/_ping")
  puts "Status: #{res.status}"
  puts "Body: #{res.body}"
  
  res = conn.request(method: :get, path: "/info")
  info = JSON.parse(res.body)
  puts "Docker ID: #{info['ID']}"
  puts "Conexión exitosa!"
rescue => e
  puts "Error: #{e.class} - #{e.message}"
  puts e.backtrace.first(5)
end
