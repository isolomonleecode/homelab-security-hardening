# Monitoring & Logging (Pi4 Recommended)

To avoid impacting Unraid OS stability, deploy log collection on the Pi4 (Ubuntu) running Pi-hole/Vaultwarden. Promtail will tail container logs and ship to a remote Loki (Grafana Cloud or local Loki on the Pi4).

## Why Pi4
- Offloads CPU/IO from Unraid
- Avoids container restarts or plugin dependencies on Unraid
- Decouples monitoring from the environment being monitored

## Option A: Grafana Cloud (simplest)
1. Create a free Grafana Cloud account and Loki stack.
2. Copy your Loki endpoint, username, and API key.
3. On the Pi4:
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# Promtail container
docker run -d --name promtail \
  -v /var/log:/var/log:ro \
  -v /var/lib/docker/containers:/var/lib/docker/containers:ro \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd)/configs/logging/promtail-pi4-config.yml:/etc/promtail/config.yml:ro \
  -p 9080:9080 \
  grafana/promtail:2.9.6 \
  -config.file=/etc/promtail/config.yml
```
4. Edit `configs/logging/promtail-pi4-config.yml` with your Grafana Cloud details.
5. Verify logs in Grafana Explore (label `container`).

## Option B: Local Loki on Pi4
```bash
docker network create observability || true

# Loki
docker run -d --name loki --network observability -p 3100:3100 \
  -v loki-data:/loki \
  grafana/loki:2.9.6 -config.file=/etc/loki/local-config.yaml

# Promtail (update client URL to http://loki:3100)
# See config at configs/logging/promtail-pi4-config.yml
```

## Option C: Send Promtail (Pi4) to Loki on Grafana Host
When Grafana runs on a separate machine and Loki is containerized on that host:

1. Start Loki on the Grafana host (Docker):
```
docker network create observability || true
docker rm -f loki || true
docker run -d --name loki --network observability -p 3100:3100 \
  -v loki-data:/loki \
  grafana/loki:2.9.6 -config.file=/etc/loki/local-config.yaml
```
2. If Grafana runs in Docker, connect both Grafana and Loki to a common network:
```
docker network connect saml-lab_saml-net loki
# In Grafana data source, use URL: http://loki:3100
```
3. On the Pi4, configure Promtail to push to the Grafana host's IP (if DNS not available):
```
clients:
  - url: http://192.168.0.52:3100/loki/api/v1/push
```
4. Verify:
```
curl http://localhost:9080/ready         # Promtail
curl http://192.168.0.52:3100/ready      # Loki from Pi4
```

## Minimal Alerts to Start
- Excessive 4xx/5xx from reverse proxy (if logs available)
- Container restart spikes
- SSH auth failures on Pi4

## Deliverables
- `configs/logging/promtail-pi4-config.yml` populated
- Screenshots or saved queries in `findings/` for portfolio

## Safety Notes
- Do not run this on Unraid to keep production stable
- Promtail is read-only; no changes to containers
 - If Pi DNS cannot resolve `grafana.homelab.local`, use the Grafana host IP in Promtail config, or add an A record in Pi-hole and revert to hostname later

