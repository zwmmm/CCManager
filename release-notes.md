### Bug Fixes

- Load the user's configured shell environment before running Usage Statistics refreshes so `npx` can be found from shell-managed Node.js setups, with a bash fallback when zsh is unavailable
