#!/bin/sh
GITHUB_ENDPOINT="${GITHUB_OWNER}/${GITHUB_REPOSITORY}"
#for organizations
#GITHUB_ENDPOINT=organization_name
registration_url="https://api.github.com/repos/${GITHUB_ENDPOINT}/actions/runners/registration-token"
#for organizations
#https://api.github.com/orgs/${GITHUB_ENDPOINT}/actions/runners/registration-token
echo "Requesting registration URL at '${registration_url}'"

payload=$(curl -sX POST -H "Authorization: token ${GITHUB_PAT}" ${registration_url})
export RUNNER_TOKEN=$(echo $payload | jq .token --raw-output)
mkdir $HOME/.ssh
touch $HOME/.ssh/agent-environment
touch $HOME/.ssh/known_hosts
sudo cp /data/secrets/id_rsa /home/github/.ssh/id_rsa
sudo chown -R github:github /home/github/.ssh/id_rsa
cat > .bashrc <<'SH'
SSH_ENV="$HOME/.ssh/agent-environment"

function start_agent {
    echo "Initialising new SSH agent..."
    /usr/bin/ssh-agent | sed 's/^echo/#echo/' > "${SSH_ENV}"
    echo succeeded
    chmod 600 "${SSH_ENV}"
    . "${SSH_ENV}" > /dev/null
    /usr/bin/ssh-add /home/github/.ssh/id_rsa;
}

# Source SSH settings, if applicable

if [ -f "${SSH_ENV}" ]; then
    . "${SSH_ENV}" > /dev/null
    #ps ${SSH_AGENT_PID} doesn't work under cywgin
    ps -ef | grep ${SSH_AGENT_PID} | grep ssh-agent$ > /dev/null || {
        start_agent;
    }
else
    start_agent;
fi
SH
ssh-keyscan -H github.com >> $HOME/.ssh/known_hosts

./config.sh \
    --name $(hostname) \
    --labels x64,linux \
    --token ${RUNNER_TOKEN} \
    --url https://github.com/${GITHUB_ENDPOINT} \
    --work ${RUNNER_WORKDIR} \
    --unattended \
    --replace

remove() {
    ./config.sh remove --unattended --token "${RUNNER_TOKEN}"
}

trap 'remove; exit 130' INT
trap 'remove; exit 143' TERM

./run.sh "$*" &

wait $!