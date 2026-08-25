# ~/.bashrc - Shell configuration

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# History
HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000

# Append to history, don't overwrite
shopt -s histappend

# Check window size after each command
shopt -s checkwinsize

# Enable color support
alias diff='diff --color=auto'
alias grep='grep --color=auto'
alias ip='ip -color=auto'

# Aliases
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'

# Helix alias
alias hx='helix'

# Dev environment
alias dev='~/git/dotfiles/bin/dev'

# PATH
export PATH="$HOME/bin:$HOME/git/dotfiles/bin:$PATH"
