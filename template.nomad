job "[[ .job ]]" {
  region      = "[[ or .region "global" ]]"
  datacenters = [
    [[ range $index, $value := .datacenters ]]
    [[ if ne $index 0 ]], [[ end ]]"[[ $value ]]"
    [[ end ]]
  ]

  ##########
  # Placement Options
  ##########

  [[ if .placement ]]
    [[ if eq .placement.type "all" ]]
      type = "system"
    [[ else if eq .placement.type "batch" ]]
      type = "batch"
    [[ else ]]
      type = "service"
      [[ if eq .placement.type "unique" ]]
        constraint {
          operator  = "distinct_hosts"
          value     = "true"
        }
      [[ end ]]
    [[ end ]]

    [[ if and (and (and .placement .placement.type) (eq .placement.type "batch")) .placement.crontab ]]
      periodic {
        cron = "[[ .placement.crontab ]]"
      }
    [[ end ]]

    [[ if .placement.os_type ]]
      constraint {
        attribute = "${attr.kernel.name}"
        value = "[[ .placement.os_type ]]"
      }
    [[ end ]]

    [[ if .placement.os ]]
      constraint {
        attribute = "${attr.os.name}"
        value = "[[ .placement.os ]]"
      }
    [[ end ]]

    [[ if .placement.os_version ]]
      constraint {
        attribute = "${attr.os.version}"
        value = "[[ .placement.os_version ]]"
      }
    [[ end ]]
  [[ else ]]
    type = "service"
  [[ end ]]


  ##########
  # Deployment Options
  ##########

  [[ if .placement ]]
    [[ if eq .placement.type "service" ]]
      update {
        max_parallel = [[ if .deployment ]][[ or .deployment.max_parallel 1 ]][[ else ]]1[[ end ]]

        health_check = "task_states"
        healthy_deadline = [[ if .deployment ]]"[[ or .deployment.healthy_deadline "3m" ]]"[[ else ]]"3m"[[ end ]]
        min_healthy_time = "10s"
        progress_deadline = "10m"

        canary = [[ if .deployment ]][[ or .deployment.canaries 1 ]][[ else ]]1[[ end ]]
        auto_promote = true
        auto_revert = [[ if .deployment ]][[ if .deployment.no_revert_on_failure ]]false[[ else ]]true[[ end ]][[ else ]]true[[ end ]]
      }
    [[ end ]]
  [[ else ]]
    update {
      max_parallel = [[ if .deployment ]][[ or .deployment.max_parallel 1 ]][[ else ]]1[[ end ]]

      health_check = "task_states"
      healthy_deadline = [[ if .deployment ]]"[[ or .deployment.healthy_deadline "3m" ]]"[[ else ]]"3m"[[ end ]]
      min_healthy_time = "10s"
      progress_deadline = "10m"

      canary = [[ if .deployment ]][[ or .deployment.canaries 1 ]][[ else ]]1[[ end ]]
      auto_promote = true
      auto_revert = [[ if .deployment ]][[ if .deployment.no_revert_on_failure ]]false[[ else ]]true[[ end ]][[ else ]]true[[ end ]]
    }
  [[ end ]]


  group "[[ .job ]]" {
    count = [[ if .deployment ]][[ or .deployment.initial_count 1 ]][[ else ]]1[[ end ]]

    restart {
      attempts = [[ if .deployment ]][[ or .deployment.attempts 2 ]][[ else ]]2[[ end ]]
      interval = "30m"
      delay = "15s"
      mode = "fail"
    }

    ##########
    # Volumes
    ##########

    [[ range $taskName, $task := .tasks ]]
        [[ if .volumes ]]
          [[ range $index, $config := .volumes.host ]]
            volume "[[ $taskName ]]-[[ .volume ]]" {
              type      = "host"
              source    = "[[ .volume ]]"
              read_only = false
            }
        [[ end ]]
      [[ end ]]
    [[ end ]]

    ##########
    # Tasks
    ##########

    [[ range $taskName, $task := .tasks ]]
      task "[[ $taskName ]]" {
        driver = "docker"

        config {
          dns_servers = [ "169.254.1.1" ]
          image = "[[ .image ]]:[[ or .version "latest" ]]"
          [[ if .command ]]command = "[[ .command ]]"[[ end ]]
          [[ if .allow_docker_sock ]]userns_mode = "host"[[ end ]]
          [[ if .args ]]
            args = [
              [[ range $index, $arg := .args ]]
                [[ if ne $index 0 ]],[[ end ]] "[[ $arg ]]"
              [[ end ]]
            ]
          [[ end ]]

          # Docker Ports
          port_map = {
            [[ range $name, $port := .ports ]]
              [[ $name ]] = [[ .inner ]]
            [[ end ]]
          }

          [[ if .capacities ]]
            cap_add = [
              [[ range $index, $cap := .capacities ]]
                [[ if ne $index 0 ]],[[ end ]] "[[ $cap ]]"
              [[ end ]]
            ]
          [[ end ]]

          volumes = [
            [[ if .volumes ]]
              [[ range $index, $config := .volumes.share ]]
                [[ if ne $index 0 ]],[[ end ]] "/fileshare/[[ .fileshare ]]:[[ .mountpoint ]]"
                [[ if $task.volumes.raw ]],[[ end ]]
              [[ end ]]
              [[ range $index, $config := .volumes.raw ]]
                [[ if ne $index 0 ]],[[ end ]] "[[ .from ]]:[[ .mountpoint ]]"
              [[ end ]]
              [[ if and .allow_docker_sock (or .volumes.raw .volumes.share) ]],[[ end ]]
            [[ end ]]
            [[ if .allow_docker_sock ]]
              "/var/run/docker.sock:/var/run/docker.sock"
            [[ end ]]
          ]

          [[ if .volumes ]]
            mounts = [
              [[ range $index, $target := .volumes.tmpfs ]]
                  [[ if ne $index 0]],[[ end ]]
                  {
                      type = "tmpfs"
                      target = "[[ $target ]]"
                      readonly = false
                  }
              [[ end ]]
            ]
          [[ end ]]
        }

        [[ if .volumes ]]
          [[ range $index, $config := .volumes.host ]]
            volume_mount {
              volume = "[[ $taskName ]]-[[ .volume ]]"
              destination = "[[ .mountpoint ]]"
              read_only = [[ if .read_only ]]true[[ else ]]false[[ end ]]
            }
          [[ end ]]
        [[ end ]]

        [[ if .volumes ]]
          [[ range $index, $config := .volumes.artifact ]]
            artifact {
              source = "[[ .source ]]"
              destination = "[[ .destination ]]"
            }
          [[ end ]]
        [[ end ]]

        resources {
          cpu = [[ if .resources ]][[ or .resources.cpu 100 ]][[ else ]]100[[ end ]]
          memory = [[ if .resources ]][[ or .resources.memory 256 ]][[ else ]]256[[ end ]]

          # External Port Mapping
          network {
            [[ if .host_network ]]mode = "host"[[ end ]]
            [[ range $name, $port := .ports ]]
              port "[[ $name ]]" {
                [[ if .outer ]]
                  static = [[ .outer ]]
                [[ end ]]
              }
            [[ end ]]
          }
        }

        [[ if .vault ]]
          [[ if .vault.policies ]]
            vault {
              policies = [
                [[ range $index, $value := .vault.policies ]]
                  [[ if ne $index 0 ]], [[ end ]]"[[ $value ]]"
                [[ end ]]
              ]
              change_mode   = "signal"
              change_signal = "SIGHUP"
            }
          [[ end ]]

          # Secrets
          [[ if .vault.env ]]
            template {
              data = <<EOF
                [[ range $vaultKey, $vaultSecrets := .vault.env ]]
                  {{- with secret "kv/data/[[ $vaultKey ]]" -}}
                    [[ range $envKey, $secretKey := $vaultSecrets ]]
                      [[ $envKey ]]={{ .Data.data.[[ $secretKey ]] }}
                    [[ end ]]
                  {{ end }}
                [[ end ]]
              EOF
              destination = "local/secrets.env"
              env         = true
            }
          [[ end ]]

          [[ if .vault.files ]]
            [[ range $vaultKey, $vaultFiles := .vault.files ]]
              [[ range $fileName, $fileInfo := $vaultFiles ]]
                template {
                  data = <<EOF
                    {{- with secret "kv/data/[[ $vaultKey ]]" -}}
                      [[ $fileInfo.contents ]]
                    {{ end }}
                  EOF
                  destination = "local/[[ $fileName ]]"
                  env         = [[ if $fileInfo.env ]]true[[ else ]]false[[ end ]]
                }
              [[ end ]]
            [[ end ]]
          [[ end ]]
        [[ end ]]

        # Environment Variables
        [[ if .env ]]
          env {
            [[ range $envKey, $value := .env ]]
              [[ $envKey ]] = "[[ $value ]]"
            [[ end ]]
          }
        [[ end ]]

        [[ if .files ]]
          [[ range $file, $template := .files ]]
            template {
              destination = "[[ $file ]]"
              env = [[ if .env ]]true[[ else ]]false[[ end ]]
              data = <<EOF
[[ .data ]]
EOF
            }
          [[ end ]]
        [[ end ]]

        # Consul Service Registration
        [[ range $portName, $port := .ports ]]
          service {
            name = "[[ if eq $.job $taskName ]][[ $taskName ]][[ else ]][[ $.job ]]-[[ $taskName ]][[ end ]][[ if not (eq $taskName $portName) ]]-[[ $portName ]][[ end ]]"
            port = "[[ $portName ]]"
            canary_tags = [
              "traefik.enable=false"
            ]
            tags = [
              "scheme=[[ or .scheme "http" ]]"
	      [[ range $index, $tag := .tags ]]
                ,"[[ $tag ]]"
              [[ end ]]
              [[ if .lb ]]
                ,"traefik.enable=true",
                "traefik.http.routers.[[ $.job ]]-[[ $taskName ]]-[[ $portName ]].rule=Host(`[[ .lb.domain ]]`)"
                [[ if .scheme ]][[ if eq .scheme "https" ]]
                  ,"traefik.http.services.[[ $.job ]]-[[ $taskName ]]-[[ $portName ]].loadbalancer.server.scheme=https"
                [[ end ]][[ end ]]
                [[ if .lb.https_only ]]
                  ,"traefik.http.routers.[[ $.job ]]-[[ $taskName ]]-[[ $portName ]].middlewares=redirect-scheme@file"
                [[ else ]]
                  [[ if .lb.middleware ]],"traefik.http.routers.[[ $.job ]]-[[ $taskName ]]-[[ $portName ]].middlewares=[[ range $index, $middleware := .lb.middleware ]][[ if ne $index 0 ]],[[ end ]][[ $middleware ]][[ end ]]"[[ end ]]
                [[ end ]]
                [[ if .lb.cert ]],
		  [[ if .lb.middleware ]]"traefik.http.routers.[[ $.job ]]-[[ $taskName ]]-[[ $portName ]]-tls.middlewares=[[ range $index, $middleware := .lb.middleware ]][[ if ne $index 0 ]],[[ end ]][[ $middleware ]][[ end ]]",[[ end ]]
                  "traefik.http.routers.[[ $.job ]]-[[ $taskName ]]-[[ $portName ]]-tls.rule=Host(`[[ .lb.domain ]]`)",
                  "traefik.http.routers.[[ $.job ]]-[[ $taskName ]]-[[ $portName ]]-tls.tls=true",
                  "traefik.http.routers.[[ $.job ]]-[[ $taskName ]]-[[ $portName ]]-tls.tls.certresolver=[[ replace .lb.cert "." "-" ]]",
                  "traefik.http.routers.[[ $.job ]]-[[ $taskName ]]-[[ $portName ]]-tls.tls.domains[0].main=*.[[ .lb.cert ]]",
                  "traefik.http.routers.[[ $.job ]]-[[ $taskName ]]-[[ $portName ]]-tls.tls.domains[0].sans=[[ .lb.cert ]]"
                  [[ if .lb.sticky ]],
                  "traefik.http.services.[[ $.job ]]-[[ $taskName ]]-[[ $portName ]].loadBalancer.sticky=true",
                  "traefik.http.services.[[ $.job ]]-[[ $taskName ]]-[[ $portName ]].loadBalancer.sticky.cookie.name=[[ $.job ]]-[[ $taskName ]]-[[ $portName ]]",
                  "traefik.http.services.[[ $.job ]]-[[ $taskName ]]-[[ $portName ]].loadBalancer.sticky.cookie.secure=false",
                  "traefik.http.services.[[ $.job ]]-[[ $taskName ]]-[[ $portName ]].loadBalancer.sticky.cookie.httpOnly=true"
                  [[ end ]]
                [[ end ]]
              [[ end ]]
            ]
          }
        [[ end ]]
      }
    [[ end ]]
  }
}
