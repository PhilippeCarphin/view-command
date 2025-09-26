#!/usr/bin/env bash
#
# Open commands in $PATH or the file containing the definition of a shell
# function.
#
_vc_usage(){
    cat <<-EOF
	usage: vc [-s] CMD

	Open file where CMD is defined.  CMD can be
	- A shell function: vc will open the file where the function is defined
	  at the first line of the function
	- An executable script in PATH: vc will open the file
	- A non-executable file in PATH if the shell option 'sourcepath' is active.
	I don't know what vc means, I named it that because of the stack overflow
	question that inspired me to make this tool.

	If '-s' is specified, then if CMD is a shell function, the file containing
	this function will be sourced when the editor returns.
	EOF
}

vc(){
    if [[ "$1" == "--help" ]] ; then
        _vc_usage
        return 0
    fi
    local source_func_file=false
    if [[ "$1" == "-s" ]] ; then
        source_func_file=true
        shift
    fi
    local cmd="${1}"
    local alias_str
    if [[ -n ${VC_EXPAND_ALIASES} ]] ; then
        if alias_str=$(alias ${cmd} 2>/dev/null) ; then
            # output of alias is "alias <name>='<alias-definition>"
            local alias_def=${alias_str#*=}
            local alias_name=${alias_str%%=*}
            local alias_def_words=($( eval echo ${alias_def} ) )
            local alias_cmd=${alias_def_words[0]}
            cmd=${alias_def_words[0]}
            echo "${FUNCNAME[0]}: Expanded '${alias_str}', now looking for '${cmd}'" >&2
        fi
    fi

    echo "${FUNCNAME[0]}: Looking for shell function '${cmd}'" >&2
    _vc_open-shell-function "${cmd}" ; case $? in
        0) return 0 ;; # We're back from opening the shell function
        1) ;; # cmd is not a shell function, try other things
        2) return 1 ;; # ${cmd} is a shell function but its file doesn't exist
    esac

    echo "${FUNCNAME[0]}: Looking for executable '${cmd}' in PATH" >&2
    local file
    if file=$(command which ${cmd} 2>/dev/null) ; then
        echo "${FUNCNAME[0]}: ... '${cmd}' is '${file}' from PATH" >&2
        local file_result="$(file -L ${file})"
        local file_result_first_line="${file_result%%$'\n'*}"
        # Result is of the form '<name>: <information>'
        # and we need to remove name because it could contain the word 'text'
        # and less likely but still possible: ASCII or UTF-8.
        local file_result_without_filename="${file_result_first_line#*:}"
        local open_file=y
        case "${file_result_without_filename}" in
            *ASCII*|*UTF-8*|*text*) ;;
            *) read -p "${FUNCNAME[0]}: File '${file}' is not ASCII or UTF-8 text, still open? [y/n] > " open_file ;;
        esac
        if [[ "${open_file}" == y ]] ; then
            command vim ${file}
        fi
        return
    else
        echo "${FUNCNAME[0]}: ... '${cmd}' is not an executable in PATH" >&2
    fi

    if shopt -q sourcepath ; then
        echo "${FUNCNAME[0]}: Looking for sourceable file in PATH" >&2
        file="$(find -L $(echo $PATH | tr ':' ' ') -name "${cmd}" ! -perm -100 -type f -print -quit)"
        if [[ -n "${file}" ]] ; then
            echo "${FUNCNAME[0]}: ... '${cmd}' is non-executable file '${file}' from PATH" >&2
            command vim ${file}
            return
        else
            echo "${FUNCNAME[0]}: ... '${cmd}' is not a sourceable file in PATH" >&2
        fi
    fi
}

# Sourceable here means
# - not executable `compgen -c` will pick up executables from PATH anyway
#   and it reduces the number of candidates to run the `file` command on.
# - ASCII text Note: running `file` is the most time consuming step so
#   it should be done only on the candidates that have passed all of the
#   other checks.
_vc_add_path_sourceable(){
    local IFS=:
    local p
    for p in ${PATH} ; do {
        local IFS=$'\n'
        p=${p:-$PWD}
        for f in ${p}/* ; do
            # Eliminate filenames that don't match
            if ! [[ ${f} == ${p}/${cur}* ]] ; then
                continue
            fi
            # Eliminate executables (already found by compgen -c)
            if [[ -x ${f} ]] ; then
                continue
            fi
            # Eliminate files that are not ASCII or UTF8
            case "$(file -L "${f}")" in
                *ASCII*|*UTF-8*) ;;
                *) continue ;;
            esac
            COMPREPLY+=(${f##*/})
        done
    } done
}

_vc(){
    local cur=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=($(compgen -c -- "${cur}" | sort | uniq))
    if shopt -q sourcepath ; then
        _vc_add_path_sourceable
    fi
}

_vc_open-shell-function(){
    local -r shell_function="${1}"

    #
    # The extdebug setting causes `declare -F ${shell_function}` to print
    # '<function> <lineno> <file>'.  Since this function runs in a subshell
    # turning it on here does not affect the outer environment
    #
    local reset_extdebug="$(shopt -p extdebug)"
    shopt -s extdebug

    local info=$(declare -F ${shell_function})
    if [[ -z "${info}" ]] ; then
        echo "vc: ... '${shell_function}' is not a shell function" >&2
        ${reset_extdebug}
        return 1
    fi

    local lineno
    if ! lineno=$(echo ${info} | cut -d ' ' -f 2) ; then
         echo "vc: Error getting line number from info '${info}' on '${shell_function}'" >&2
         ${reset_extdebug}
         return 1
    fi

    local file
    if ! file=$(echo ${info} | cut -d ' ' -f 3) ; then
        echo "vc: Error getting filename from info '${info}' on '${shell_function}'" >&2
        ${reset_extdebug}
        return 1
    fi
    if [[ "${file}" != /* ]] ; then
        echo "vc: INFO: file '${file}' is a relative path.  This will only work if run from the directory where the original source command was run" >&2
    fi

    if ! [[ -e "${file}" ]] ; then
        echo "vc: ERROR: '${cmd}' is a shell function from '${file}' which does not exist" >&2
        return 2
    fi

    echo "vc: Opening '${file}' at line ${lineno}"
    command vim ${file} +${lineno}
    ${reset_extdebug}
}

whence(){

    local follow_link
    if [[ $1 == -r ]] ; then
        follow_link=true
        shift
    fi
    local -r cmd=$1

    if alias ${cmd} 2>/dev/null ; then
        return
    fi

    local reset_extdebug=$(shopt -p extdebug)
    shopt -s extdebug

    local func file info link realpath
    # Shell function
    if info=$(declare -F ${cmd}) ; then
        if [[ -n ${follow_link} ]] ; then
            if ! file=$(echo ${info} | cut -d ' ' -f 3) ; then
                echo "Could not extract file from declare -F output" >&2
            fi
            realpath=" ~ $(realpath ${file})"
        fi
        echo "${info}${realpath}"
        return
    fi

    # File from PATH
    if file=$(command which ${cmd} 2>/dev/null) ; then
        : good
    elif file="$(find -L $(echo $PATH | tr ':' ' ') -mindepth 1 -maxdepth 1 -name "${cmd}" ! -perm -100 -type f)" ; then
        : good
    else
        return 1
    fi

    if [[ -n ${follow_link} ]] ; then
        realpath=" ~ $(realpath ${file})"
    fi
    echo "${file}${realpath}"
    ${reset_extdebug}
}

complete -F _vc vc whence
