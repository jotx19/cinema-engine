export const curlInstall =
  "curl -fsSL https://raw.githubusercontent.com/jotx19/cinema-engine/main/install.sh | bash"

export const brewInstall =
  "brew tap jotx19/cinema-engine https://github.com/jotx19/cinema-engine.git && brew install cinema-engine"

export const sourceInstall =
  "git clone https://github.com/jotx19/cinema-engine.git && cd cinema-engine && ./install.sh"

export const startCommands = `cinema-engine
cinema-engine start
cinema-engine dev`

export const moreCommands = `cinema-engine setup
cinema-engine list-devices
cinema-engine start --output "AirPods Pro" --preset theatre
cinema-engine start --no-hrtf
cinema-engine start --plain
cinema-engine set bass 70
cinema-engine set width 80
cinema-engine set dialogue 60
cinema-engine set room 40
cinema-engine set preset night
cinema-engine status
cinema-engine stop`
