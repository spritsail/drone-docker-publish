[hub]: https://hub.docker.com/r/spritsail/docker-publish
[git]: https://github.com/spritsail/drone-docker-publish
[drone]: https://drone.spritsail.io/spritsail/docker-publish
[mbdg]: https://microbadger.com/images/spritsail/docker-publish

# [Spritsail/docker-publish][hub]
[![Layers](https://images.microbadger.com/badges/image/spritsail/docker-publish.svg)][mbdg]
[![Latest Version](https://images.microbadger.com/badges/version/spritsail/docker-publish.svg)][hub]
[![Git Commit](https://images.microbadger.com/badges/commit/spritsail/docker-publish.svg)][git]
[![Docker Stars](https://img.shields.io/docker/stars/spritsail/docker-publish.svg)][hub]
[![Docker Pulls](https://img.shields.io/docker/pulls/spritsail/docker-publish.svg)][hub]
[![Build Status](https://drone.spritsail.io/api/badges/spritsail/drone-docker-publish/status.svg)][drone]

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
    registry: registry.foobar.io
    tags:
      - latest
```

Docker login credentials can be supplied as either separate arguments, or together in a HTTP basic-auth style colon-delimited string:

`$DOCKER_USERNAME` or `$PLUGIN_USERNAME` to specify the usename, and similar for `_PASSWORD`
`$DOCKER_LOGIN` or `$PLUGIN_LOGIN` to specify `username:password`

### Tagging

This plugin provides functionality to filter and mutate versions through multiple filters, much like a unix pipe.

Examples:
```yaml
  tags:
    - latest
    - beta
    - 1.5.123
    - 1.5.123 | %auto
    - %file .tag_file
    - %file .version_file | auto
    - 1.2.34 | %prefix beta | auto
    - %file .tag_file | %prefix testing
    - %file .version_file | %prefix beta | %auto
    - %label org.label-schema.version
    - %label io.spritsail.version.busybox | %auto
```

#### Commands / Filters

Every filter starts with a percent symbol, without it the command is treated as a literal tag.  
Usage arguments are `<required>` `<optional=default>`

Currently available commands are as follows:

- `%prefix` adds a prefix to all tags ~ _**usage:** `%prefix <prefix> [separator=-]`_
- `%suffix` adds a suffix to all tags ~ _**usage:** `%suffix <suffix> [separator=-]`_
- `%rempre` removes a prefix from all tags ~ _**usage:** `%rempre <prefix> [separator=-]`_
- `%remsuf` remove a suffix from all tags ~ _**usage:** `%remsuf <suffix> [separator=-]`_
- `%auto`   generates automatic semver-like versions. optionally takes a minimum length value ~ _**usage:** `%auto [limit]`_
- `%label`  takes a label from a docker image ~ _**usage:** `%label <label-name> [image name=$SRC_REPO]`_
- `%file`   takes a value from a file ~ _**usage:** `%file <file-name>`_

Most commands will take a regex compatible with `sed` POSIX extended regex, including `%rempre` and `%remsuf`.

This small library of filters is enough for our use but suggestions/PRs are welcome for anything you could want.

##### For example:

- `%file .version_file | %prefix beta | %auto`, with `.version_file` having `2.8.243`  
_**or**_
- `%label org.label-schema.version | %prefix: beta | %auto` with `org.label-schema.version` having `2.8.243`

produces the following set of tags

```
beta-2.8.243
beta-2.8
beta-2
beta
```

##### Auto

Usage `| %auto [prefix]` where prefix is a positive integer defining the minimum number of parts of the version to keep:

e.g. `%auto 2` with `1.2.3.4.5` as input would produce
```
1.2.3.4.5
1.2.3.4
1.2.3
1.2
```

where the shortest value `1.2` has two parts

#### Usage

This container doubles up as a CLI tool, as well as a drone plugin. It can be run as follows to test specific tag output before you push.

For example, a simple usage of `%auto` and `%prefix`

```bash
docker run -ti --rm spritsail/docker-test \
  --tags '1.2.3.4-extra | %prefix pre | %auto 2'
```
produces
```
Running in --tags test mode
pre-1.2
pre-1.2.3
pre-1.2.3.4
pre-1.2.3.4-extra
```

More complex filters such as `%label` may require Docker daemon access and additional arguments through the environment. You should deal with these accordingly, for example:

```bash
docker run -ti --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e SRC_REPO=user/image-name \
  spritsail/docker-test \
  ..
```
