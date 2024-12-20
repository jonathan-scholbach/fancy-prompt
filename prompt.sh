#################################
#            ICONS              #
#################################

declare -A __ICONS=( \
  ["separator"]="" \
  ["local_branch"]="" \
  ["remote_branch"]="" \
  ["merged_branch"]="" \
  ["stashed"]="󰏢" \
)


#################################
#            COLORS             #
#################################

declare -A __THEME=(\
  ["default"]="-1"\
  ["fg"]="253"\
  ["bglighter"]="238"\
  ["bglight"]="237"\
  ["bg"]="236"\
  ["bgdark"]="235"\
  ["bgdarker"]="234"\
  ["violet"]="69"\
  ["selection"]="239"\
  ["subtle"]="238"\
  ["cyan"]="74"\
  ["green"]="28"\
  ["sky"]="38"\
  ["orange"]="215"\
  ["pink"]="169"\
  ["mauve"]="99"\
  ["red"]="203"\
  ["yellow"]="226"\
  ["lightgray"]="252"\
  ["white"]="255"\
)

__bg() {
  # background color from 256 code, -1 gives default
  local color_code=$1
  if [ "-1" = "${color_code}" ]
  then
    echo "\\[\\e[49m\\]"
  else
    echo "\\[\\e[48;5;${color_code}m\\]"
  fi
}

__fg() {
  # foreground color from 256 code, -1 gives default
  local color_code=$1
  if [ "-1" = "${color_code}" ]
  then
    echo "\\[\\e[39m\\]"
  else
    echo "\\[\\e[38;5;${color_code}m\\]"
  fi
}

__colorized_separator() {
  local left_color="$1"
  local right_color="$2"
  echo "$(__fg $left_color)$(__bg $right_color)${__ICONS[separator]}"
}

#################################
#             USER              #
#################################

user_text="\u@\h"


#################################
#             PATH             #
#################################

path_text="\w"


#################################
#          GIT BRANCH           #
#################################

__branch_name() {
  git rev-parse --abbrev-ref HEAD 2> /dev/null
}

__remote_branch_name() {
  is_only_local_branch=$(git branch -r 2> /dev/null | grep -c "$param_branch_name")

  if [ 0 -eq "$is_only_local_branch" ]; then echo "";fi
  local branch_name

  branch_name=$(git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2> /dev/null | cut -d"/" -f1)
  branch_name=${branch_name:-origin}
  echo "$branch_name"
}

__branch_is_local_only() {
  local param_branch_name="$1"
  local is_only_local_branch

  is_only_local_branch=$(git branch -r 2> /dev/null | grep -c "$param_branch_name")

  if [ 0 -eq "$is_only_local_branch" ]; then return 0; fi
  return 1
}

__branch_is_merged() {
  local branch
  local merged=""

  branch=$(__branch_name)

  merged=$(git branch -r --merged master 2> /dev/null | grep "$branch" 2> /dev/null)
  if [ "" != "$merged" ]; then return 0; fi

  merged=$(git branch -r --merged develop 2> /dev/null | grep "$branch" 2> /dev/null)
  if [ "" != "$merged" ]; then return 0; fi

  merged=$(git branch -r --merged main 2> /dev/null | grep "$branch" 2> /dev/null)
  if [ "" != "$merged" ]; then return 0; else return 1; fi
}

__branch_icon() {
  local param_branch_name="$1"

  if $(__branch_is_local_only)
  then
      echo "${__ICONS[local_branch]}"
      return
  fi

  if $(__branch_is_merged)
  then
      echo "${__ICONS[merged_branch]}"
      return
  fi

  echo "${__ICONS[remote_branch]}"
}

__branch_text() {
  local branch_text=""
  if [ "" != "$(__branch_name)" ]; then branch_text="$(__branch_icon) $(__branch_name)"; fi
  echo "${branch_text}"
}


#################################
#         GIT STATUS            #
#################################

__staged() {
  git diff --name-only --cached 2> /dev/null
}

__untracked() {
  git ls-files --others --exclude-standard 2> /dev/null
}

__changed() {
  git ls-files -m 2> /dev/null
}

__stashed() {
  local msg="$(git stash list 2> /dev/null)"
  if [[ "" != "${msg}" ]]; then echo "${__ICONS[stashed]}"; else echo ""; fi
}

__unpushed() {
    local branch_name=$(__branch_name)
    local remote_name=$(__remote_branch_name)
    git log --pretty=oneline "${remote_name}"/"${branch_name}"..HEAD 2> /dev/null
}

__needs_pull() {
  # In order for this to give more accurate information, git fetch needs to be
  # run It does not make sense to run git fetch here, as it would slow down
  # every new prompt
  local local_only=$(__branch_is_local_only)
  if [ "0" != "${local_only}" ]
  then
    echo "0"
    return 0
  fi
  local branch_name=$(__branch_name)
  if [ "" != "${branch_name}" ]
  then
    if [ $(git rev-parse HEAD) = $(git rev-parse @{u}) ]; then echo "0"; else echo "0"; fi
  else
		echo "0"
  fi
}

#################################
#             VENV              #
#################################

__venv() {
  if [ "${VIRTUAL_ENV}" ]
  then
    echo $(basename "${VIRTUAL_ENV}")
  else
    echo ""
  fi
}

#################################
#            BLOCKS             #
#################################

__block() {
  local prev_bg="$1"
  local bg="$2"
  local fg="$3"
  local text="$4"

  local color_separator="$(__colorized_separator $prev_bg $bg)"
  local foreground="$(__fg $fg)"
  local color_text="${foreground}${text}"
  if [ "" = "${text}" ]
  then
    echo ${color_text}
  else
    echo " ${color_separator} ${color_text}"
  fi
}

__split_string_at_semicolon() {
  echo ${split[@]}
}

__chain() {
  local blocks=("$@")

  local block
  local chain=""

  local default_background="$(__bg "${__THEME[default]}")"
  local default_fontcolor=$(__fg "${__THEME[default]}")

  local prev_background
  for raw_block in "${blocks[@]}";
  do
    local block_array
    IFS=';' block_array=($raw_block)
    local background="${block_array[0]}"
    local font_color="${block_array[1]}"
    local text="${block_array[2]}"

    # first container starts with clean edge
    if [ -z "$prev_background" ]; then prev_background=$background; fi
    if [ "" != "${text}" ]  # skip empty blocks
    then
      block=$(__block "${prev_background}" "${background}" "${font_color}" "${text}")
      chain+="${block}"
      prev_background="${background}"
    fi
  done

  # append tail separator
  chain+=" $(__colorized_separator "${prev_background}" "${__THEME[default]}")"

  # reset background and font color
  chain+="${default_background}${default_fontcolor} "

  echo "${chain}"
}


prompt() {
  # blocks in "background;font-color;text" format
  local user="${__THEME[mauve]};${__THEME[white]};${user_text}"
  local path="${__THEME[violet]};${__THEME[white]};${path_text}"

  local branch="$(__branch_text)"
  local branch_color="${__THEME[subtle]};${__THEME[white]}"
  if [ "0" != "$(__needs_pull)" ]; then branch_color="${__THEME[red]};${__THEME[white]}"; fi
  if [ "" != "$(__unpushed)" ]; then branch_color="${__THEME[green]};${__THEME[white]}"; fi
  if [ "" != "$(__staged)" ]; then branch_color="${__THEME[yellow]};${__THEME[bgdark]}"; fi
  if [ "" != "$(__changed)" ]; then branch_color="${__THEME[orange]};${__THEME[white]}"; fi
  if [ "" != "$(__untracked)" ]; then branch_color="${__THEME[pink]};${__THEME[bgdark]}"; fi
  branch="${branch_color};${branch}"

  local stash="${__THEME[sky]};${__THEME[white]};$(__stashed)"

  local venv=$(__venv)
  if [ "" != __venv ]
  then
    venv="${__THEME[lightgray]};${__THEME[bgdark]};${venv}"
  fi

  declare -a chain=( ${user} ${path} "${stash}" "${branch}" "${venv}" )

  PS1=$(__chain "${chain[@]}")
}

PROMPT_COMMAND="prompt"
