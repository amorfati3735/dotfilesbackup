#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# Secrets loaded from ~/.env_secrets (not backed up)
[ -f ~/.env_secrets ] && source ~/.env_secrets

export EDITOR=micro
export VISUAL=micro

# Amp CLI
export PATH="/home/pratik/.amp/bin:$PATH"
