# Define the base directory based on the current user
BASE_DIR="$HOME"

# Define file paths, content, ownership, and permissions
declare -A files=(
  ["$BASE_DIR/.config/code-server/config.yaml"]='
bind-addr: 0.0.0.0:443
auth: none
cert: true
'
  ["$BASE_DIR/.local/share/code-server/User/settings.json"]='
{
    "security.workspace.trust.enabled": false,
    "workbench.panel.defaultLocation": "bottom",
    "workbench.colorTheme": "Default Dark Modern",
    "workbench.startupEditor": "none",
    "telemetry.enableTelemetry": false,
    "update.mode": "none"
}
'
  ["$BASE_DIR/.local/share/code-server/workspace.code-workspace"]='
{
    "folders": [
        {
            "path": "'"$BASE_DIR"'"
        }
    ],
    "settings": {
        "security.workspace.trust.untrustedFiles": "open",
        "security.workspace.trust.enabled": true
    }
}
'
  ["$BASE_DIR/.local/share/code-server/coder.json"]='
{
    "query": {
        "folder": "'"$BASE_DIR"'"
    },
    "lastVisited": {
        "url": "'"$BASE_DIR"'/.local/share/code-server/User/workspace.code-workspace",
        "workspace": true
    }
}
'
)

# Set ownership and permissions
OWNER="$USER:$USER"
PERMISSIONS="0640"

# Create directories and write files
for path in "${!files[@]}"; do
  # Create directory if it doesn't exist
  mkdir -p "$(dirname "$path")"

  # Write content to the file
  echo "${files[$path]}" > "$path"

  # Set ownership and permissions
  chown "$OWNER" "$path"
  chmod "$PERMISSIONS" "$path"

  echo "File $path created and configured."
done

echo "All files have been successfully created and configured."

curl -fsSL https://code-server.dev/install.sh | sh

sudo systemctl enable --now code-server@$USER

sudo setcap cap_net_bind_service=+ep /usr/lib/code-server/lib/node

sudo systemctl restart code-server@$USER
sudo systemctl status code-server@$USER
