# phoenixd-docker
A Dockerized version of phoenixd by ACINQ.

## NOTE: This repository is now deprecated, as ACINQ are now publishing their own official image. For more info see below:

- https://github.com/ACINQ/phoenixd/pull/180
- https://hub.docker.com/r/acinq/phoenixd

Note that when migrating you'll need to ensure the volume is pointing properly to `/phoenixd/.phoenix` instead of `/phoenixd` as was common with this image. You'll also need to move `seed.dat` as necessary to use your existing seed.

An example Docker Compose with the official image:

```yaml
services:
  phoenixd:
    image: acinq/phoenixd:latest
    container_name: phoenixd
    restart: unless-stopped
    volumes:
      - phoenixd-data:/phoenix/.phoenix
```

An example (EDIT TO FIT YOUR OWN SETUP BEFORE BLINDLY USING THIS COMMAND) for moving the seed.dat file is:

```bash
sudo cp /var/lib/docker/volumes/apps_phoenixd-data/_data/.phoenix/seed.dat /var/lib/docker/volumes/apps_phoenixd-data/_data/seed.dat
```
