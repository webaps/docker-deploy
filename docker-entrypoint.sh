#!/bin/sh
set -eu

color_yellow='\033[33;1m'
color_reset='\033[0m'

if [ -z "$INPUT_DOCKER_HOST" ]; then
    echo "Input docker_host is required!"
    exit 1
fi

if [ -z "$INPUT_SSH_PRIVATE_KEY" ]; then
    echo "Input ssh_private_key is required!"
    exit 1
fi

if [ -z "$INPUT_SSH_PUBLIC_HOST_KEY" ]; then
    echo "Input ssh_public_host_key is required!"
    exit 1
fi

if [ -z "$INPUT_ARGS" ]; then
    echo "Input args is required!"
    exit 1
fi

if [ -z "$INPUT_DEPLOY_PATH" ]; then
    echo "Input deploy_path is required!"
    exit 1
fi

SSH_COMMAND="ssh -q -t -i $HOME/.ssh/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

execute_ssh(){
  echo "$INPUT_DOCKER_HOST: $@"
  $SSH_COMMAND "$INPUT_DOCKER_HOST" "$@"
}


# Setup SSH key
SSH_HOST=${INPUT_DOCKER_HOST#*@}

echo -e "${color_yellow}> Registering SSH keys${color_reset}"

mkdir -p "$HOME/.ssh"
printf '%s\n' "$INPUT_SSH_PRIVATE_KEY" > "$HOME/.ssh/id_rsa"
chmod 600 "$HOME/.ssh/id_rsa"
eval $(ssh-agent)
ssh-add "$HOME/.ssh/id_rsa"

echo -e "${color_yellow}> Add known hosts${color_reset}"
printf '%s %s\n' "$SSH_HOST" "$INPUT_SSH_PUBLIC_HOST_KEY" > /etc/ssh/ssh_known_hosts

# Do some magic
echo -e "${color_yellow}> Creating destination folder${color_reset}"
execute_ssh "mkdir -p $INPUT_DEPLOY_PATH || true"

echo -e "${color_yellow}> Transfer files to destination folder${color_reset}"
rsync -rzh --delete --rsync-path="sudo rsync" -e="$SSH_COMMAND" --info=progress2 ./ "$INPUT_DOCKER_HOST":"$INPUT_DEPLOY_PATH"

if ! [ -z "$INPUT_PRE_DEPLOY_COMMAND" ] ; then
  echo -e "${color_yellow}> Running pre-deploy command${color_reset}"
  execute_ssh "cd $INPUT_DEPLOY_PATH | $INPUT_PRE_DEPLOY_COMMAND" 2>&1
fi

if ! [ -z "$INPUT_PULL_IMAGES" ] && [ $INPUT_PULL_IMAGES = 'true' ] ; then
  echo -e "${color_yellow}> Pulling images${color_reset}"
  execute_ssh "cd $INPUT_DEPLOY_PATH | docker-compose -f $INPUT_DOCKER_COMPOSE_FILE pull" 2>&1
fi

echo -e "${color_yellow}> Deploy${color_reset}"
execute_ssh "cd $INPUT_DEPLOY_PATH | docker-compose -f $INPUT_DOCKER_COMPOSE_FILE $INPUT_ARGS" 2>&1




