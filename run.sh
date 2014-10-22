set -e;

init_wercker_environment_variables() {
    if [ -z "$WERCKER_CATALYZE_DEPLOY_APP_NAME" ]; then
        if [ ! -z "$WERCKER_CATALYZE_DEPLOY_CATALYZE_APP_NAME" ]; then
            export WERCKER_CATALYZE_DEPLOY_APP_NAME="$WERCKER_CATALYZE_DEPLOY_CATALYZE_APP_NAME";
        else
            fail "Missing or empty option catalyze_app_name. $error_suffix";
        fi
    fi

    if [ -z "$WERCKER_CATALYZE_DEPLOY_USER" ]; then
        if [ ! -z "$CATALYZE_USER" ]; then
            export WERCKER_CATALYZE_DEPLOY_USER="$CATALYZE_USER";
        else
            export WERCKER_CATALYZE_DEPLOY_USER="catalyze-deploy@wercker.com";
        fi
    fi

    if [ -z "$WERCKER_CATALYZE_DEPLOY_SOURCE_DIR" ]; then
        export WERCKER_CATALYZE_DEPLOY_SOURCE_DIR="$WERCKER_ROOT";
        debug "option source_dir not set. Will deploy directory $WERCKER_CATALYZE_DEPLOY_SOURCE_DIR";
    else
        warn "Use of source_dir is deprecated. Please make sure that you fix your Catalyze deploy version on a major version."
        debug "option source_dir found. Will deploy directory $WERCKER_CATALYZE_DEPLOY_SOURCE_DIR";
    fi
}

init_ssh() {
    local catalyze_public_key="git.catalyze.io ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDllJujC1yCiklA/vmTZqBePNoIiP49dMX3w6YtKwGLCzF+dV4LNId9p8kDQ8qu1b5k8IINpQZSgPuTzzO2aUP0VpIQsPgDMCDCF2SZT2ZbE3RLiwHeg6eQPYJrvqh2YVMH8wpZlA8JNxn8GrcyKsHTZnfoZxIaBxOrawJ8z0FlGaHy8Zroj/kvO2mWVyMZsCc1VfQYHrC02l9KmC8+sigOQ1Q1kTkG1bTlgcX+oexbTwY60TT5NjJnx3pYBZQWwkQqy5trbMbBReNMP+9mjstFffE8Kk5Glkkfpw8Z5fKn+oaCRBDCd3L8gGYPMci2hYnUSrtBlgR5JMqWhlR4QMRt";

    mkdir -p $HOME/.ssh;
    touch $HOME/.ssh/known_hosts;
    chmod 600 $HOME/.ssh/known_hosts;
    echo $catalyze_public_key >> $HOME/.ssh/known_hosts;
}

init_git() {
    local username="$1";
    local email="$2";

    if ! type git &> /dev/null; then
        debug "git not found; installing it"

        sudo apt-get update;
        sudo apt-get install git-core;
    else
        debug "git is already installed; skipping installation"
    fi

    git config --global user.name "$username";
    git config --global user.email "$email";
}

init_gitssh() {
    local gitssh_path="$1";
    local ssh_key_path="$2";

    echo "ssh -e none -i \"$ssh_key_path\" \$@" > $gitssh_path;
    chmod 0700 $gitssh_path;
    export GIT_SSH="$gitssh_path";
}

use_wercker_ssh_key() {
    local ssh_key_path="$1";
    local wercker_ssh_key_name="$2";

    debug "will use specified key in key-name option: ${wercker_ssh_key_name}_PRIVATE";

    local private_key=$(eval echo "\$${wercker_ssh_key_name}_PRIVATE");

    if [ ! -n "$private_key" ]; then
        fail 'Missing key error. The key-name is specified, but no key with this name could be found. Make sure you generated a key, and exported it as an environment variable.';
    fi

    debug "writing key file to $ssh_key_path";
    echo -e "$private_key" > $ssh_key_path;
    chmod 0600 "$ssh_key_path";
}

push_code() {
    local app_name="$1";

    debug "starting catalyze deployment with git push";
    git push -f git@git.catalyze.io:$app_name.git HEAD:master;
    local exit_code_push=$?;

    debug "git pushed exited with $exit_code_push";
    return $exit_code_push;
}

use_new_git_repository() {
    local working_directory="$1"

    local current_working_directory=$(pwd)

    # If there is a git repository, remove it because
    # we want to create a new git repository to push
    # to catalyze.
    if [ -d "$working_directory/.git" ]; then
        debug "found git repository in $working_directory"
        warn "Removing git repository from $working_directory"
        rm -rf "$working_directory/.git"

        #submodules found are flattened
        if [ -f "$working_directory/.gitmodules" ]; then
            debug "found possible git submodule(s) usage"
            while IFS= read -r -d '' file
            do
                rm -f "$file" && warn "Removed submodule $file"
            done < <(find "$working_directory" -type f -name ".git" -print0)
        fi
    fi

    # Create git repository and add all files.
    # This repository will get pushed to catalyze.
    git init
    git add .
    git commit -m 'wercker deploy'
}

# === Main flow starts here ===
ssh_key_path="$(mktemp -d)/id_rsa";
gitssh_path="$(mktemp)";
error_suffix='Please add this option to the wercker.yml or add a catalyze (custom) deployment target on the website which will set these options for you.';
exit_code_push=0;
exit_code_run=0;

# Initialize some values
init_wercker_environment_variables;
init_ssh;
init_git "$WERCKER_CATALYZE_DEPLOY_USER" "$WERCKER_CATALYZE_DEPLOY_USER";
init_gitssh "$gitssh_path" "$ssh_key_path";

cd $WERCKER_CATALYZE_DEPLOY_SOURCE_DIR || fail "could not change directory to source_dir \"$WERCKER_CATALYZE_DEPLOY_SOURCE_DIR\""

# Check if the user supplied a wercker key-name
if [ -n "$WERCKER_CATALYZE_DEPLOY_KEY_NAME" ]; then
    use_wercker_ssh_key "$ssh_key_path" "$WERCKER_CATALYZE_DEPLOY_KEY_NAME";
fi

# Then configure new git repository
use_new_git_repository "$WERCKER_CATALYZE_DEPLOY_SOURCE_DIR";

# Try to push the code
set +e;
push_code "$WERCKER_CATALYZE_DEPLOY_APP_NAME";
exit_code_push=$?
set -e;


if [ $exit_code_push -eq 0 ]; then
    success 'deployment to catalyze finished successfully';
else
    fail 'git push to catalyze failed';
fi