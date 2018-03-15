[hub]: https://hub.docker.com/r/spritsail/docker-publish

# [spritsail/docker-publish][hub]
[![](https://images.microbadger.com/badges/image/spritsail/docker-publish.svg)](https://microbadger.com/images/spritsail/docker-publish) [![](https://images.microbadger.com/badges/version/spritsail/docker-publish.svg)][hub] [![Docker Stars](https://img.shields.io/docker/stars/spritsail/docker-publish.svg)][hub] [![Docker Pulls](https://img.shields.io/docker/pulls/spritsail/docker-publish.svg)][hub] [![Build Status](https://drone.spritsail.io/api/badges/spritsail/docker-publish/status.svg)](https://drone.spritsail.io/spritsail/docker-publish)

## Supported tags and respective `Dockerfile` links

`latest` - [(Dockerfile)](https://github.com/spritsail/drone-docker-publish/blob/master/Dockerfile)

## Configuration

```yaml
pipeline:
  ..

  publish:
    image: spritsail/docker-publish
    volumes: [ '/var/run/docker.sock:/var/run/docker.sock' ]
    secrets: [ docker_username, docker_password ]
    from: local-built-image
    repo: spritsail/docker-publish
    tags:
      - latest
```

### Tagging

This plugin has multiple flexible methods for tagging images:

```yaml
  tags:
    - raw-tag
    - %auto: 1.5.123
    - %file: .tag_file
    - %fileauto: .version_file
    - %auto: %prefix: beta % 1.2.34
    - %file: %prefix: testing % .tag_file
    - %fileauto: %prefix: beta % .version_file
```

- `rawtag` is a single, literal tag
- `%file` reads a  tag out of a file
- `%auto` enumerates every major version: e.g. `1.2.34` also produces `1.2` and `1`
- `%fileauto` is a combination of `%file` and `%auto`

Additionally, any of the above can be combined with the extra `%prefix: <pre>%` argument
to prepend the fixed prefix to all tags that the rule produces.

#### For example:

` %fileauto: %prefix: beta% .version_file`, with `.version_file` having `2.8.243`

produces the following

```
beta-2
beta-2.8
beta-2.8.243
```
