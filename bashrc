#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

export NVIDIA_API_KEY="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"

export EDITOR=micro
export VISUAL=micro

# Amp CLI
export PATH="/home/pratik/.amp/bin:$PATH"
