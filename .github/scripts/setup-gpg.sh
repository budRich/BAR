#!/bin/bash
set -e

# Create GPG home directory with proper permissions
mkdir -p ~/.gnupg
chmod 700 ~/.gnupg

# Configure GPG for non-interactive use
cat > ~/.gnupg/gpg.conf <<EOF
use-agent
pinentry-mode loopback
no-tty
batch
yes
EOF

# Configure GPG Agent to allow loopback (prevents ioctl errors)
echo "allow-loopback-pinentry" > ~/.gnupg/gpg-agent.conf
gpg-connect-agent reloadagent /bye

# Import the private key
echo "$GPG_PRIVATE_KEY" | gpg --batch --import

# Trust the key ultimately
echo -e "5\ny\n" | gpg --command-fd 0 --expert --edit-key "$GPG_KEY_ID" trust quit || true
