#!/bin/sh -e
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

if [ -z "$INPUT_STACK_FILE_NAME" ]; then
  INPUT_STACK_FILE_NAME=docker-compose.yaml
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
eval "$(ssh-agent)"
ssh-add "$HOME/.ssh/id_rsa"

echo -e "${color_yellow}> Add known hosts${color_reset}"
printf '%s %s\n' "$SSH_HOST" "$INPUT_SSH_PUBLIC_HOST_KEY" > /etc/ssh/ssh_known_hosts

# Do some magic
echo -e "${color_yellow}> Creating destination folder${color_reset}"
execute_ssh "mkdir -p $INPUT_DEPLOY_PATH || true"

echo -e "${color_yellow}> Transfer files to destination folder${color_reset}"
rsync -rzhp --delete --rsync-path="sudo rsync" -e="$SSH_COMMAND" --info=progress2 ./ "$INPUT_DOCKER_HOST":"$INPUT_DEPLOY_PATH"

if [ -n "$INPUT_PRE_DEPLOY_COMMAND" ] ; then
  echo -e "${color_yellow}> Running pre-deploy command${color_reset}"
  execute_ssh "cd $INPUT_DEPLOY_PATH && $INPUT_PRE_DEPLOY_COMMAND" 2>&1
fi

if [ -n "$INPUT_PULL_IMAGES" ] && [ $INPUT_PULL_IMAGES = 'true' ] && [ $INPUT_DEPLOYMENT_MODE = 'docker-compose' ] ; then
  echo -e "${color_yellow}> Pulling images${color_reset}"
  execute_ssh "cd $INPUT_DEPLOY_PATH && docker-compose -f ./$INPUT_DOCKER_COMPOSE_FILE pull" 2>&1
fi

if [ -n "$INPUT_BUILD_IMAGES" ] && [ $INPUT_BUILD_IMAGES = 'true' ] && [ $INPUT_DEPLOYMENT_MODE = 'docker-compose' ] ; then
  echo -e "${color_yellow}> Building images${color_reset}"
  execute_ssh "cd $INPUT_DEPLOY_PATH && docker-compose -f ./$INPUT_DOCKER_COMPOSE_FILE build --no-cache" 2>&1
fi

echo -e "${color_yellow}> Deploy${color_reset}"
#execute_ssh "cd $INPUT_DEPLOY_PATH && docker-compose -f ./$INPUT_DOCKER_COMPOSE_FILE $INPUT_ARGS --force-recreate --remove-orphans" 2>&1

case $INPUT_DEPLOYMENT_MODE in
  docker-swarm)
    if [ -n "$INPUT_DOTENV" ] ; then
      execute_ssh "cd $INPUT_DEPLOY_PATH && env $(sed "s/\\\`/\\\\\`/g" < "$INPUT_DOTENV" | sed 's/"/\\"/g' | xargs) docker stack deploy $INPUT_ARGS --compose-file $INPUT_STACK_FILE_NAME" 2>&1
    else
      execute_ssh "cd $INPUT_DEPLOY_PATH && docker stack deploy $INPUT_ARGS --compose-file $INPUT_STACK_FILE_NAME" 2>&1
    fi
  ;;

  *)
    execute_ssh "cd $INPUT_DEPLOY_PATH && docker-compose -f ./$INPUT_STACK_FILE_NAME $INPUT_ARGS --force-recreate --remove-orphans" 2>&1
  ;;
esac


