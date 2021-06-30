#!/bin/sh
set -e

url="https://raw.githubusercontent.com/webuni/shell-task-runner/master/runner"
[ -f ./.runner ] && [ .runner -nt "$0" ] || wget -q "$url" -O- > .runner || curl -fso .runner "$url"
#. ./.runner

trap '_run "$@"; exit "$?"' EXIT

__source="${__source:-$(cat $0)}"
__import="$__import"
__import_prefix="$__import_prefix"

__fn()(command -v "$1" | grep -q "$1" && exit 0 || exit 1)

__fn _header || _header()(
    name="$(basename "$(cd "$(dirname "$0")"; pwd -P)")"
    printf "%s\\nUsage %s [command] [command_options]\\n\\n" "$(_ansi --underline "Application $(_ansi --bold --yellow "$name")")" "$0"
)

__fn _print || _print()(
    printf '%s' "$@"
)

__fn _println || _println()(
    printf '%s\n' "$@"
)

__fn _doc_comment || _doc_comment()(
    re_text='[^\r]*' re_comment='(^|\r)[\t ]*(#|:)+ ?' re_func="(^|\r)[^#\r\"']*$1[\t ]*\([\t ]*\)[^\{\(]*[\{\(][^\r]*\s*"
    code="$(_print "${2:-$__source}" | tr -d '\r' | tr '\n' '\r')"
    for pattern in "($re_comment$re_text)+$re_func" "$re_func($re_comment$re_text)+"; do
        comment="$(_print "$code" | awk 'match($0, /'"$pattern"'/) { t = substr($0, RSTART, RLENGTH);
            gsub(/'"$re_func"'/, "", t); gsub(/'"$re_comment"'/, "\r", t); print t}' | tr '\r' '\n')"
        if [ -n "$comment" ]; then
            _print "$comment"
            break
        fi
    done
)

__fn _doc_title || _doc_title()(
    title="$(_doc_comment "$1" | sed -n '/./{p;q;}')"
    if [ -z "$title" ]; then
        title="$(_print "${2:-$__source}" | grep -E '^[\t ]*'"$1"'[\t ]*\([\t ]*\)[\t \{\(]*#' | awk '{gsub(/^[^#]+#+[\t ]*/, ""); print}')"
    fi

    _print "$title"
)

__fn _doc_tags || _doc_tags()(
    tags="$(_doc_comment "$1" | grep -E '^ *@' | sed 's/^ *//')"
    if [ -n "$3" ]; then only_delimited='-s'; fi
    if [ -n "$2" ]; then
        tags="$(_print "$tags" | grep -E "^@?$2" | cut -d' ' $only_delimited -f2-)"
    fi

    if [ -n "$3" ] && [ -z "$tags" ]; then
        tags="$3"
    fi

    _print "$tags"
)

__fn _commands || _commands() (
    prefix="${1:-task_}" suffix='\s*\(\s*\)' pattern="${prefix}[a-z0-9_]+"
    _print "${2:-$__source}" | grep -Eio "^[^#\r\"']*$pattern$suffix" | grep -Eio "$pattern" | sort | awk '{gsub(/'"$prefix"'/, ""); print}'
)

__fn _commands_list || _commands_list()(
    list='' command_prefix="${1:-task_}" commands="$(_commands "$command_prefix" "$2")" prevprefix=''
    length="$(_print "$commands" | awk '{gsub("__", ":"); print length}' | sort -nr | head -1)"
    length=$(( length + 2 ))

    prefixes="$(_print "$commands" | grep -Eio '^[a-z0-9]+__' | uniq | awk '{print substr($0, 0, length - 2)}' | xargs | sed 's/ /|/g')"
    commands="$( printf '%s\n%s' "$(_print "$commands" | grep -Ev "^($prefixes)")" "$(_print "$commands" | grep -E "^($prefixes)")" | grep -v "^$")"
    commands="$(_print "$commands" | awk 'BEGIN{pp=""}{p="";;c=$0;gsub(/__/, ":", c); if(match($0, /^('"$prefixes"')($|_)/)){
        p=substr($0, RSTART, RLENGTH);sub(/_/, "", p);if(p!=pp){print p}};pp=p}{printf("%s|%s\n",c,$0)}')"
    _ansi --yellow --nl "Available commands:"
    echo "$commands" | while IFS='' read command; do
        name="${command#*|}"
        if [ "$command" = "$name" ]; then
          _ansi --yellow --nl " ${command#\#}"
        else
          printf ' %s%s\n' "$(_ansi --green --format " %-${length}s" "${command%|*}")" "$(_doc_title "$command_prefix${name}")"
        fi
    done
)

__fn _shell_escape || _shell_escape()(
    _print "$1" | sed -e 's/\(["\& '"'"']\)/\\\1/g'
)

__fn _quote || _quote()(
    _print "$1" | sed "s/'/'\\\\''/g;1s/^/'/;\$s/\$/'/"
)

__fn _printf_escape || _printf_escape()(
    _print "$1" | sed 's/%/%%/g'
)

__fn _ansifilter || _ansifilter()(
    _print "$1" | awk '{gsub(/\x1B\[[0-9;]+[mGKFH]/, "");}1'
)

__fn _stty || _stty()(
    sleep 0.1 # Fix tty delay for docker run -t ...
    stty "$@" 2>/dev/null
)

__fn _color || _color()(
    case "$1" in
        black) echo 0;;
        red) echo 1;;
        green) echo 2;;
        yellow) echo 3;;
        blue) echo 4;;
        magenta|purple) echo 5;;
        cyan) echo 6;;
        white) echo 7;;
    esac
)

__fn _ansi || _ansi()(
    text='' start='' stop="" newline='' format="%s"
    while [ -n "$1" ]; do
        case "$1" in
            --nl|--new-line) newline="\\n";;
            --bold) start="$start\\033[1m" stop="\\033[22m$stop";;
            --italic) start="$start\\033[3m" stop="\\033[23m$stop";;
            --format=*) format="${1#*=}";;
            -f|--format) shift; format="$1";;
            --underline) start="$start\\033[4m" stop="\\033[24m$stop";;
            --inverse) start="$start\\033[7m";;
            --reset) start="$start\\033[0m";;
            --bg-bright-*) start="$start\\033[10$(_color "${1##*-}")m" stop="\\033[49m$stop";;
            --bg-*-intense) start="$start\\033[10$(_color "$(echo "$1" | cut -d- -f4)")m" stop="\\033[49m$stop";;
            --bg-*) start="$start\\033[4$(_color "${1##*-}")m" stop="\\033[49m$stop";;
            --bright-gray) start="$start\\033[37m" stop="\\033[39m$stop";;
            --bright-*) start="$start\\033[9$(_color "${1##*-}")m" stop="\\033[39m$stop";;
            --gray) start="$start\\033[90m" stop="\\033[39m$stop";;
            --*-intense) start="$start\\033[9$(_color "$(echo "$1" | cut -d- -f3)")m" stop="\\033[39m$stop";;
            --black|--red|--green|--yellow|--blue|--magenta|--purple|--cyan|--white) start="$start\\033[3$(_color "${1##*-}")m" stop="\\033[39m$stop";;
            *) text="$text $(_quote "$1")";;
        esac
        shift
    done

    eval set -- "$text"
    printf "${start}${format}${stop}${newline}" "$@"
)

__fn _indent || _indent()(
    sed "s/^/${1:-  }/"
)

__fn _align || _align()(
    for text in "$@"; do true; done
    rawtext="$(_ansifilter "$text")"
    width=$(( $(_stty size | cut -d' ' -f2) + ${#text} - ${#rawtext} ))
    left_span=$(( (width + ${#text}) / 2 ))
    right_span=$(( width - left_span ))
    case "$1" in
        --right) printf "%${width}s\\n" "$text";;
        --center) printf "%${left_span}s%${right_span}s\\n" "$text";;
        *) printf "%s" "$text";;
    esac
)

__fn _box || _box()(
    text=""; options=""; newline=""; padding=1; margin=0
    while [ -n "$1" ]; do
        case "$1" in
            --p=*|--padding=*) padding="${1#*=}";;
            -p|--padding) shift; padding="$1";;
            --m=*|--margin=*) margin="${1#*=}";;
            -m|--margin) shift; margin="$1";;
            --nl|--new-line) newline=1;;
            --*) options="$options $1";;
            *) text="$text$1";;
        esac
        shift
    done

    mspace=$([ "$margin" -gt 0 ] && printf "   %.0s" $(seq 1 "$margin") || echo "")
    pspace=$([ "$padding" -gt 0 ] && printf "   %.0s" $(seq 1 "$padding") || echo "")
    width=$(( $(_stty size | cut -d' ' -f2) - 2 * ${#mspace} ))
    textwidth=$(( width - 2 * ${#pspace} ))

    for _ in $(seq 1 "$margin"); do echo ""; done
    for _ in $(seq 1 "$padding"); do echo "$mspace$(_ansi $options --nl --format="%${width}s")"; done

    esc="$(printf '\033')"
    printf "$(_printf_escape "$text\\n ")" | while IFS= read -r part; do
        length=0; line=''; state=0
        _println "$part" | sed 's/\(.\)/\1\n/g' | {
            LANG=C; LC_ALL=C
            while IFS= read -r char; do
                line="$line$char"
                if [ "$esc" = "$char" ]; then state=1; fi
                if [ "$state" -eq 0 ]; then
                    if [ "${#char}" -ge 4 ]; then step=2; else step=1; fi
                    length=$(( length + step ));
                fi
                if [ "$state" -eq 1 ] && [ "m" = "$char" ]; then state=0; fi
                if [ "$length" -eq "$textwidth" ]; then
                    _println "$mspace$(_ansi $options --format="$pspace%s%$(( textwidth - length ))s$pspace" "$line")"
                    length=0; line='';
                fi
            done
            if [ "$length" -gt 0 ]; then
                _println "$mspace$(_ansi $options --format="$pspace%s%$(( textwidth - length + 1 ))s$pspace" "$line")"
            fi
            length=0; line=''
        }
    done

    for _ in $(seq 1 "$padding"); do _println "$mspace$(_ansi $options --nl --format="%${width}s")"; done
    for _ in $(seq 1 "$margin"); do echo ""; done
    if [ -n "$newline" ]; then echo ""; fi
)

__fn _log || _log()(
    color="gray"
    case $1 in
        --error) color="red"; shift;;
        --warning) color="yellow"; shift;;
        --success) color="green"; shift;;
        --info) color="cyan"; shift;;
        --*) shift;;
    esac

    printf "[%s] %s\\n" "$(_ansi "--${color}" "$(date -Iseconds)")" "$@"
)

__fn _docker_run || _docker_run()(
    if [ -t 0 ]; then tty="-t"; fi
    if [ -d '/tmp/.X11-unix' ]; then x11="-v /tmp/.X11-unix:/tmp/.X11-unix"; fi
    docker run --rm -i $tty -e DISPLAY="$DISPLAY" $x11 -v "$(pwd):$(pwd)" -w "$(pwd)" "$@"
)

__fn _docker_compose || _docker_compose()(
    docker-compose "$@"
)

__fn _docker_compose_run || _docker_compose_run()(
    service="" services="$(_docker_compose config --services)"
    for arg in "$@"; do
        if echo "$services" | grep -qwe "$arg"; then service="$arg"; break; fi
    done

    if [ -t 1 ]; then DTTY=""; else DTTY="-T"; fi
    if _docker_compose ps --filter "status=running" --services | grep -qe "$service"; then
        _docker_compose exec $DTTY --user "$(id -u):$(id -g)" "$@"
    else
        _docker_compose run --rm $DTTY "$@"
    fi
)

__fn _decorator_docker_run || _decorator_docker_run() (
    if __fn docker; then
        image="${image:-$(_doc_tags "$1" image)}"
        if [ "$(_print "$image" | cut -c1)" = '$' ]; then image="$(eval _print "$image")"; fi
        if [ -n "$image" ]; then
            command="$1" shift
            _docker_run "$image" "$0" "$command" "$@";
        else
            "$@"
        fi
    else
        "$@"
    fi
)

__fn _decorator_docker_compose_run || _decorator_docker_compose_run() (
    if __fn docker-compose; then
        service="${service:-$(_doc_tags "$1" service)}"
        if [ "$(_print "$service" | cut -c1)" = '$' ]; then service="$(eval _print "$service")"; fi
        if [ -n "$service" ]; then
            command="$1" shift
            # TODO Fix prefix from import (remove prefix)
            _docker_compose_run "$service" "$0" "$command" "$@";
        else
            _decorator_docker_run "$@"
        fi
    else
        _decorator_docker_run "$@"
    fi
)

__fn _load_dotenv || _load_dotenv() {
    DOTENV_SHELL_LOADER_SAVED_OPTS=$(set +o)
    set -a
    [ -f "${1:-.env}" ] && source "$(_path "${1:-.env}")"
    set +a
    eval "$DOTENV_SHELL_LOADER_SAVED_OPTS"
    unset DOTENV_SHELL_LOADER_SAVED_OPTS
}

__fn _dotenv || _dotenv()(
    config=""
    target="$(_path "${1:-.env}")"
    source="$(_path "${2:-.env.dist}")"

    touch "$source" "$target"
    while read -r line; do
        if [ "$(_print "$line" | head -c1)" = '#' ]; then
            help=$(_print "$line" | cut -c2- | xargs)
            config="$config$line\\n"
            continue
        fi

        if test "${line#*=}" = "$line"; then
            config="$config$line\\n"
            continue
        fi

        key="$(_print "$line" | cut -d= -f1)"
        value="$(_print "$line" | cut -d= -f2-)"
        default="$(eval _print "$value" 2>/dev/null)" || default="$value"
        value="$default"
        if [ "$1" = '-f' ] || [ "$1" = '--force' ] || ! grep "^${key}=" "$target" > /dev/null; then
            [ -n "$help" ] && _ansi --white --nl "  $help"
            printf "%s (%s): $(test -t 1 && printf "\\n")" "$(_ansi --cyan "  $key")" "$(_ansi --yellow "$default")"
            if [ -t 1 ] && read -r value </dev/tty && [ "$value" = "" ]; then
                value="$default"
            fi
            value="$(_shell_escape "$value")"
        else
            value="$(grep "^${key}=" "$target" | cut -d= -f2-)"
        fi
        config="$config$key=$value\\n"
        help=""
    done < "$source"
    # shellcheck disable=SC2059
    printf "$(_printf_escape "$config")" > "$target"
)

__fn _import || _import(){
    [ ! -r "$1" ] && return 1
    local old__import="$__import";
    local old__import_prefix="$__import_prefix"
    __import=1
    __import_prefix="${__import_prefix}${2}"
    local code="$(sed -E "s/task_([a-zA-Z0-9_]+)/task_${__import_prefix}\1/g" < "$1")"
    __source="$__source $code"
    eval _print "$code"
    __import="$old__import"
    __import_prefix="$old__import_prefix"
}

__fn _pass || _pass()(
    _ansi --green --nl " ✔ ${1}"
)

__fn _fail || _fail()(
    _ansi --red --nl " ✘ ${1}"
    return "${2:-1}"
)

__fn _diff || _diff()(
    expected="$1"; actual="$2"
    [ "$#" -lt 2 ] && [ -t 1 ] && actual=-

    if [ - = "$expected" ]; then expected="$(cat)"; fi
    if [ - = "$actual" ]; then actual="$(cat)"; fi

    if [ "$actual" != "$expected" ]; then
        expected_file="$(mktemp)" actual_file="$(mktemp)"
        _println "$expected" > "$expected_file"
        _println "$actual" > "$actual_file"
        diff -du "$expected_file" "$actual_file" | sed '1,3d'
        rm "$expected_file" "$actual_file"

        return 1
    fi
)

__fn _path || _path() (
  echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
)

__fn _run || _run()(
    if [ "$__import" ]; then return; fi
    prefix="${COMMAND_PREFIX:-task_}"
    _ansi --reset
    name="$(_print "$1" | sed 's/:/__/g')"
    if [ -z "$name" ] || [ "$name" = '-h' ] || [ "$name" = '--help' ]; then
        _header
        printf "%s\\n  %-25s%s\\n\\n" "$(_ansi --cyan "Options:")" "$(_ansi --green "-h, --help")" "Print this message and exit"
        _commands_list "$prefix"
        return
    elif __fn "$prefix$name"; then
        command="$prefix$name"
    elif LC_ALL=C command -V "$name" 2>/dev/null | head -1 | grep -qe 'function'; then
        command="$name"
    else
        ! commands="$(_commands)" commands="$(_print "$commands" | grep -e "^$(_print "$name" | sed -e 's/__/.*__/g')")"
        if [ -n "$commands" ] && [ "$(_println "$commands" | wc -l)" = 1 ]; then command="$prefix$commands"; fi
    fi

    if [ -z "$command" ] && __fn _command; then
      command="$(_command "$1" "$name" "$prefix")"
    fi

    if [ -z "$command" ]; then
        _header
        _box --bg-red --white --nl "Command $(_ansi --bold "$1") doesn't exist." >&2 && _commands_list "$prefix" >&1 && exit 1
    fi

    shift; set -- "$command" "$@"
    if __fn _decorator && _println "$(_doc_tags "$command")" | grep -qvE '^@no[_-]?decorat(e|or)'; then
        set -- _decorator "$@"
    fi
    "$@"
)

if [ -r ./.env ]; then
    . ./.env
fi

IMAGE_NAMESPACE="${IMAGE_NAMESPACE:-minidocks}"
GIT_NAMESPACE="${GIT_NAMESPACE:-minidocks}"
HUB_NAMESPACE="${HUB_NAMESPACE:-minidocks}"
HUB_URL=https://hub.docker.com/v2
HUB_API_URL=https://hub.docker.com/api/build/v1

to_json(){
    printf '{"%s"}' "$(echo "$1" | sed -E 's/\\/\\\\/g; s/"/\\"/g; s/=/": "/g; s/&/", "/g; s/"(true|false)"/\1/g')"
}

json_escape()(
    printf "%s" "$1" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g'
)

http_code(){
    printf "%s" "$1" | head -n1 | cut -d" " -f2
}

http_body(){
    printf "%s" "$1" | sed '1,/^$/d'
}

assert_http_code(){
    if [ "$(http_code "$1")" != "$2" ]; then
        printf "\033[30;41m%s\033[0m\n" "$1" >&2
        exit 1
    fi
}

query()(
    json="$1"
    shift
    printf '%s' "$json" | _docker_run minidocks/curl jq "$@"
)

do_request(){
    _docker_run minidocks/curl \
        curl --retry 5 --retry-delay 3 -H "Content-Type: application/json" -H "Accept: application/json" -i -s "$@" \
    | tr -d '\r' | tr '\n' '\r' | sed -e 's/.\+\(HTTP\/1.\+\)/-\1-/' | tr '\r' '\n'
}

run_git(){
    _docker_run -e FILE_NETRC_PATH="/home/user/.netrc" -e FILE_NETRC_CONTENT="machine github.com login token password $GITHUB_TOKEN" minidocks/git git "$@"
}

github(){
    do_request -H "Authorization: token $GITHUB_TOKEN" -X "$1" --data "$3" "https://api.github.com$2"
}

hub(){
    if [ -z "$REGISTRY_TOKEN" ] || [ $(( $(date +"%s") - REGISTRY_TOKEN_TIME )) -gt 300 ]; then
        response="$(do_request -X "POST" --data "{\"username\": \"$(json_escape "$DOCKER_LOGIN")\", \"password\": \"$(json_escape "$DOCKER_PASSWORD")\"}" "$HUB_URL/users/login/")"
        assert_http_code "$response" "200"
        REGISTRY_TOKEN="$(query "$(http_body "$response")" -r '.token')"
        REGISTRY_TOKEN_TIME="$(date +"%s")"
    fi

    do_request -H "Authorization: JWT $REGISTRY_TOKEN" -X "$1" --data "$3" "${4:-$HUB_URL}$2"
}

hub_api()(
    hub "$1" "$2" "$3" "$HUB_API_URL"
)

lsdir()(
    if [ -d "." ]; then
      find "." -mindepth 1 -maxdepth 1 -type d -not -path '*/\.*' -printf '%f\n' | sort
    fi
)

froms()(
    for namespace in $IMAGE_NAMESPACE; do
        printf "%s" "$1" | grep "FROM $namespace/" | cut -d/ -f2 | cut -d' ' -f1 | uniq
    done
)

deps()(
    dir="${1:-$(pwd)}"
    basename="$(basename "$dir")"
    froms=""

    if [ -d "$dir" ]; then
        for file in $(find "$dir" -name "Dockerfile"); do
            froms="$(froms "$(cat "$file")") $froms"
        done
    fi

    froms="$(echo "$froms" | sed -e 's/ /\n/g' | grep -v "$basename" | cut -d: -f1 | sort | uniq | xargs)"
    for from in $froms; do
        froms="$(deps "$from") $froms"
    done

    echo "$froms" | xargs
)

versions()(
    if [ -f "$1/build.sh" ]; then
        "$1/build.sh" --versions
    elif [ -d "$1" ]; then
        find "$1"/* -maxdepth 0 \( -type d -o -type l \) | sort | cut -d/ -f2
    fi
)

build()(
    package="" version="" source_dir="" opts=""
    while [ -n "$1" ]; do
        case "$1" in
            --force) opts="$opts --no-cache";;
            --no-clear) no_clear="1";;
            --dir*) source_dir="$2"; shift;;
            -*) opts="$opts $1";;
            *) if [ -z "$package" ]; then package="$1"; else version="$1"; fi;;
        esac
        shift
    done

    if [ -f "$source_dir/build.sh" ]; then
        source_dir="$source_dir"
    elif [ -f "$package/build.sh" ]; then
        source_dir="$package"
    elif [ -z "$source_dir" ]; then
        source_dir="${package}/${version}"
    else
        source_dir="${source_dir}/${version}"
    fi

    if [ ! -f "$source_dir/Dockerfile" ]; then
        printf 'Skip "%s". Unable to find file "%s/Dockerfile"' "$source_dir" >&2
        return
    fi

    froms="$(froms "$(cat "$source_dir/Dockerfile")")"
    for from in $froms; do
        tag="$(echo "$from" | cut -d: -f2 -s)"
        task_build "$(echo "$from" | cut -d: -f1)" "${tag:-latest}"
    done

    target_dir="/tmp/${package}-${version}"
    if [ -f "$source_dir/build.sh" ]; then
        for namespace in $IMAGE_NAMESPACE; do
            printf "Build %s/%s:%s - %s" "$namespace" "$package" "$version" "$source_dir"
            namespace="$namespace" docker_opts="$(echo "$opts" | xargs)" "$source_dir/build.sh" "$version"
            echo "Result build $?"
        done
        printf "\n"
    elif [ ! -d "$target_dir" ] || [ "$no_clear" != 1 ]; then
        rm -rf "$target_dir"
        cp -rfL "$source_dir" "$target_dir"
        for namespace in $IMAGE_NAMESPACE; do
            printf "Build %s/%s:%s - %s" "$namespace" "$package" "$version" "$source_dir"
            docker buildx build $opts -t "$namespace/$package:$version" "$target_dir"
        done
        if [ "$no_clear" != 1 ]; then rm -rf "$target_dir"; fi
        printf "\n"
    else
        printf "Image %s/%s:%s exists" "$IMAGE_NAMESPACE" "$package" "$version"
    fi
)

task_build()(
    package="" version="" dir="" opts=""
    while [ -n "$1" ]; do
        case "$1" in
            --dir*) dir="$2"; shift;;
            --force) opts="${opts} --no-cache";;
            -*) opts="${opts} $1";;
            *) if [ -z "$package" ]; then package="$1"; else version="$1"; fi;;
        esac
        shift
    done

    if [ "${package#*/}" != "$package" ]; then
        version="$(printf '%s' "$package" | cut -d/ -f2)"
        package="$(printf '%s' "$package" | cut -d/ -f1)"
    fi

    if [ ! -d "${dir:-$package}" ]; then
        run_git clone "https://github.com/$GIT_NAMESPACE/$package"
    fi

    versions="$(versions "${dir:-$package}")"
    if [ -n "$version" ] && echo "$versions" | grep -qx "$version"; then
        build "$package" "$version" --dir "$dir" $opts
        echo "Result $?"
    else
        for version in $versions; do
            build "$package" "$version" --dir "$dir" $opts
        done
    fi
)
