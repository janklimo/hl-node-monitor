# HL Node Monitor

A minimal Ruby script to run the unjail command if your validator is jailed.

### Installation

1. Clone the repo, the examples below use `/home/ubuntu/hl-scripts/hl-node-monitor` as working directory
1. Set up environment variables (secrets).
1. Set up `systemd` service to run the script at a predefined interval

### Secrets

In the working directory, create a new file `.env`:

```
VALIDATOR=<validator address>
KEY=<signer wallet private key>
```

### `systemd` service

This sets up the script to run 10x per minute.

```
[Unit]
Description=HL Node Monitor Script
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/hl-scripts/hl-node-monitor
ExecStart=/bin/bash -c 'while true; do /home/ubuntu/.asdf/shims/ruby run.rb; sleep 6; done'
Restart=always

[Install]
WantedBy=multi-user.target
```

Note: I'm using `asdf` to manage ruby version. Change the command above
if you're using something else.

Save as `/etc/systemd/system/hl-node-monitor.service`.

Reload and restart service:

```
sudo systemctl daemon-reload
sudo systemctl restart hl-node-monitor
sudo systemctl status hl-node-monitor
```

### Logging

The script logs to the `./logs` folder for debugging purposes.
