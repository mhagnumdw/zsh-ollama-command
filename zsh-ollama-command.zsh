# default shortcut as Ctrl-o
(( ! ${+ZSH_OLLAMA_COMMANDS_HOTKEY} )) && typeset -g ZSH_OLLAMA_COMMANDS_HOTKEY='^o'
# default ollama model as llama3
# (( ! ${+ZSH_OLLAMA_MODEL} )) && typeset -g ZSH_OLLAMA_MODEL='llama3'
(( ! ${+ZSH_OLLAMA_MODEL} )) && typeset -g ZSH_OLLAMA_MODEL='llama3.1:8b-instruct-q4_K_M'
# default response number as 5
(( ! ${+ZSH_OLLAMA_COMMANDS} )) && typeset -g ZSH_OLLAMA_COMMANDS='5'
# default ollama server host
(( ! ${+ZSH_OLLAMA_URL} )) && typeset -g ZSH_OLLAMA_URL='http://localhost:11434'

validate_required() {
  # check required tools are installed
  if (( ! $+commands[fzf] )) then
      echo "🚨: zsh-ollama-command failed as fzf NOT found!"
      echo "Please install it with 'brew install fzf'"
      return 1;
  fi
  if (( ! $+commands[curl] )) then
      echo "🚨: zsh-ollama-command failed as curl NOT found!"
      echo "Please install it with 'brew install curl'"
      return 1;
  fi
  if ! curl -s "${ZSH_OLLAMA_URL}/api/tags" | grep -q $ZSH_OLLAMA_MODEL; then
    echo "🚨: zsh-ollama-command failed as model ${ZSH_OLLAMA_MODEL} server NOT found!"
    echo "Please start it with 'ollama pull ${ZSH_OLLAMA_MODEL}' or adjust ZSH_OLLAMA_MODEL"
    return 1;
  fi
}

check_status() {
  tput cuu 1 # cleanup waiting message
  if [ $? -ne 0 ]; then
    echo "༼ つ ◕_◕ ༽つ Sorry! Please try again..."
    exit 1
  fi
}

fzf_ollama_commands() {
  setopt extendedglob
  validate_required
  if [ $? -eq 1 ]; then
    return 1
  fi

  ZSH_OLLAMA_COMMANDS_USER_QUERY=$BUFFER

  zle end-of-line
  zle reset-prompt

  print
  print -u1 "👻 Please wait..."

  ZSH_OLLAMA_COMMANDS_MESSAGE_CONTENT="You are an expert agent that replies with only Linux Zsh terminal commands for a expert user to copy-pasting. Reply with one command per line, without any additional text or explanation or newlines. Provide up to $ZSH_OLLAMA_COMMANDS relevant commands, each on a new line, in plain text. Answer: $ZSH_OLLAMA_COMMANDS_USER_QUERY"

  ZSH_OLLAMA_COMMANDS_REQUEST_BODY='{
    "model": "'$ZSH_OLLAMA_MODEL'",
    "messages": [
      {
        "role": "user",
        "content":  "'$ZSH_OLLAMA_COMMANDS_MESSAGE_CONTENT'"
      }
    ],
    "stream": false
  }'

  ZSH_OLLAMA_COMMANDS_RESPONSE=$(curl --silent "${ZSH_OLLAMA_URL}/api/chat" \
    -H "Content-Type: application/json" \
    -d "$ZSH_OLLAMA_COMMANDS_REQUEST_BODY")
  local ret=$?

  # collect suggestion commands from response content
  ZSH_OLLAMA_COMMANDS_SUGGESTION=$(echo -E "$ZSH_OLLAMA_COMMANDS_RESPONSE" | tr -d '\n\r' | tr -d '\0' | jq -r '.message.content')
  check_status

  ZSH_OLLAMA_COMMANDS_SELECTED=$(echo $ZSH_OLLAMA_COMMANDS_SUGGESTION | \
    grep -v '^[[:space:]]*$' | \
    # grep -v '^[[:space:]]*```' | \
    # sed 's/^`//; s/`$//' | \
    fzf --ansi --height=~10 --cycle)
  check_status

  if [[ -n "${ZSH_OLLAMA_COMMANDS_SELECTED}" ]]; then
    BUFFER="$ZSH_OLLAMA_COMMANDS_SELECTED # $BUFFER"
  fi

  zle end-of-line
  zle reset-prompt
  return $ret
}

autoload fzf_ollama_commands
zle -N fzf_ollama_commands

bindkey $ZSH_OLLAMA_COMMANDS_HOTKEY fzf_ollama_commands
