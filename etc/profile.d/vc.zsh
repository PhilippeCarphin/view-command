__vc_log(){
    echo "${funcstack[2]}: $*" >&2
}
whence(){
    local cmd=$1
    local file
    if ! info=($(builtin whence -v ${cmd})) ; then
        if ! file=$(_vc_find_path_sourceable_file ${cmd}) ; then
            echo "${funcstack[1]}: No sourceable file found in PATH" >&2
            return 1
        fi
        echo "custom_whence: ${cmd} is a sourceable file: ${file} in PATH"
    else
        echo "${info[*]}"
    fi
}

apologize(){
    echo "The file ${file} doesn't exist.  This is possibly because it was"
    echo "sourced with a path relative to PWD.  On behalf of ZSH, I apologize"
    echo "for this inconvenience"
}

vc(){
    local cmd=$1
    local info=
    if ! info=($(builtin whence -v ${cmd})) ; then
        echo "${funcstack[1]}: ${info[*]}" >&2
        local file
        if ! file=$(_vc_find_path_sourceable_file ${cmd}) ; then
            echo "${funcstack[1]}: No sourceable file found in PATH" >&2
            return 1
        fi
        vim ${file}
        return 0
    fi

    echo "${funcstack[1]}: ${info[*]}" >&2
    case "${info[*]}" in
        ${cmd}\ is\ a\ shell\ function\ from\ *)
            local file=${info[-1]}
            if ! [[ -f ${file} ]] ; then
                apologize
                return 1
            fi
            local lineno="$(\grep -n "^\s*\(function\)\?\s*${cmd}\s*()" ${file} | cut -d ':' -f 1)"
            if [[ -n "${lineno}" ]] ; then
                vim ${file} +${lineno}
            else
                vim ${file}
            fi
            return 0
            ;;
        ${cmd}\ is\ an\ autoload\ shell\ function)
            if ! file=$(find_autoload_shell_function ${cmd}) ; then
                __vc_log "Failed to locate autoloaded shell function"
                return 1
            fi
            echo "${funcstack[1]}(): file='${file}'"
            vim ${file}
            return 0
            ;;
        ${cmd}\ is\ a\ shell\ builtin)
            return 1
            ;;
        ${cmd}\ is\ an\ alias\ *)
            return 0
            ;;
        ${cmd}\ is\ *)
            if (( ${#info[@]} != 3 )) ; then
                __vc_log "unexpected output from whence : '${info}'"
                return 1
            fi
            local file=${info[-1]}
            vim ${file}
            return 0
            ;;
        *)
            __vc_log "unexpected output from whence : '${info}'"
            return 1
            ;;
    esac

}

find_autoload_shell_function(){
    local func=$1
    local old_ifs="${IFS}"
    local IFS=$'\n'
    local f
    # fpath is a builtin array representing the search path for autoload functions
    for f in "${fpath[@]}" ; do
        if ! [[ -d ${f} ]] ; then
            continue
        fi
        if ! res=($(find $f -maxdepth 1 -name ${func} -o -name ${func}.zsh)) ; then
            __vc_log "error in find command"
            return 1
        fi
        case ${#res[@]} in
            0) continue ;;
            1) echo ${res[1]} ; return ;;
            *)
                __vc_log "multiple matches in ${f}: ${res[*]}" >&2
                echo ${res[1]}
                return
                ;;
        esac
    done
    return 1
}

_vc(){
    local cur=${words[-1]}
    _vc_add_autoloads
    _vc_add_functions
    _vc_add_path_everything
}

compdef _vc vc

_vc_add_autoloads(){
    for f in "${fpath[@]}" ; do
        if ! [[ -d ${f} ]] ; then
            continue
        fi
        if ! res=($(find $f -maxdepth 1 -name ${func} -o -name ${func}.zsh)) ; then
            return 1
        fi
        for r in "${res[@]}" ; do
            if [[ "${r}" = ${cur}* ]] ; then
                compadd ${r}
            fi
        done
    done
}

_vc_find_path_sourceable_file(){
    local filename=$1
    local OIFS=${IFS}
    IFS=:
    local path_array=(${=PATH})
    IFS=${OIFS}
    local results=()
    for p in "${path_array[@]}" ; do
        # NULLGLOB Thing: Adding (N) makes it so that if the glob matches
        # nothing it's OK
        for f in ${p}/*(N) ; do
            if ! [[ ${f} == ${p}/${filename} ]] ; then
                continue
            fi
            if [[ -d ${f} ]] ; then
                continue
            fi
            if [[ -x ${f} ]] ; then
                continue
            fi
            local file_result="$(file -L ${f})"
            if ! ( [[ "${file_result}" == *ASCII* ]] || [[ "${file_result}" == *UTF-8* ]] ) ; then
                continue
            fi
            echo "$f"
            return 0
        done
    done
    return 1
}


#
# The ZSH completion system is so cryptic that after trying to figure out how
# to tell it that argument one of my command should complete with command names
# I just gave up and wrote this. And it wouldn't take into account the
# non-executable files that I could source.
#
_vc_add_path_everything(){
    local OIFS=${IFS}
    IFS=:
    local path_array=(${=PATH})
    IFS=${OIFS}
    local results=()
    for p in "${path_array[@]}" ; do
        for f in ${p}/* ; do
            if ! [[ ${f} == ${p}/${cur}* ]] ; then
                continue
            fi
            if [[ -d ${f} ]] ; then
                continue
            fi
            if [[ -x ${f} ]] ; then
                results+=(${f##*/})
                continue
            fi
            if [[ "$(file -L ${f})" == *ASCII* ]] ; then
                results+=(${f##*/})
                continue
            fi
        done
    done
    compadd -a results
}

_vc_add_functions(){
    local results=($( declare -f 2>&1 | grep -v $'^\t\\|}' | tr -d '(){ ' | grep "^${cur}" ))
    compadd -a results
}




