local home = os.getenv("HOME")

local command = string.format([[
podman run --rm -it \
  --name debian-workspace \
  --security-opt label=disable \
  --volume "%s":"%s" \
  --workdir "%s" \
  docker.io/library/debian:testing \
  bash
]], home, home, home)

os.execute(command)
