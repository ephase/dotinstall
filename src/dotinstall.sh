#!/usr/bin/env bash

# Personnal Dotfiles install script

BIN_DIRECTORY="${HOME}/.local/bin/"
LIB_DIRECTORY="${HOME}/.local/lib/"
SYD_DIRECTORY="${HOME}/.config/systemd/user"
DOTREPO="${HOME}/.config/dotrepo/"


# DEFAULT VALUES
OVERWRITE_DIRECTORY=0
OVERWRITE_FILE=0

repository=""
install=1

usage ()
{
    printf "\nUSAGE\n"
    printf "\n"
    printf "%s <bootstrap_file>\n" "$0"
    printf "boostrap_file : file contain variables\n"
}

die ()
{
    # Exit script
    # $1 : error message before quit
    # $2 : exit code - default 99
    # $3 : 1 if print usage 

    [ -z $2 ] && $2=99
    printf "\e[31mFATAL : %s\e[0m\n" "$1"
    [ $3 == 1 ] && usage
    exit $2
}

error ()
{
    # print error message in red
    # $@ : message

    printf "\e[31m%s\e[0m\n" "$*"
}

private:get_bootstrap_path ()
{
    # this function return the absolute path of the bootstrap file
    # $* : path of bootstrap file

    # If the path begin with /, this is an absolute part
    if [[ "$*" =~ ^/[[:graph:]]*$ ]]
    then
        repository="$(dirname $*)"
        return
    fi

    local relative_path="$*"
    local current_path="$(pwd)"
    while [[ $relative_path =~ ^../[[:graph:]]*$ ]]
    do
            printf "We found ..\n"
            relative_path="${relative_path##../}"
            current_path="${current_path%/*}"
    done
    repository="$(dirname "${current_path}/${relative_path}")"
}

private:remove_symblink()
{
    # Remove a symblink
    # $* source

    printf "  -> Remove symblink %s : " "$symblink"
    if [ -L "$*" ]
    then
        local ret;
        ret=$(rm "$*" 2>&1)
        [ $? -ne 0 ] && { error "can't remove : $ret"; return; }
    elif [ ! -f "$*" ]
    then
        error "$* not exist"
        return
    else
        error "$* is not a symblink"
    fi
    printf "\e[32mdone\e[0m\n"
}

private:create_symblink ()
{
    # Create a symblink
    # $1: source
    # $2: destination

    local source="$1"
    local dest="$2"
    
    printf "  -> Create a symblink from %s : " "$source"

    # If dest is a symbolic link, delete it.
    if [ -L "$dest" ]
    then
        rm -rf "$dest"
    # If source is a directory
    elif [ -d "$source" ]
    then
        if [ -d "$dest" ]
        then
            if [ $OVERWRITE_DIRECTORY -ne 0 ]
            then
                error "can't overwrite destination"
                return
            else
                rm -rf $dest
            fi
        elif [ -e $dest ]
        then
            error "destination exist but is not a directory"
            return
        fi

    # If source is a file
    elif [ -f "$source" ]
    then
        if [ -f "$dest" ]
        then
            if [ $OVERWRITE_FILE -ne 0 ]
            then
                error "can't overwrite destination"
                return
            else
                rm -rf "$dest"
            fi
        elif [ -e "$dest" ]
        then
            error "$dest exist but is not a file"
            return
        fi

    fi
    ln -s "$source" "$dest"
    printf "\e[32mdone\e[0m\n"
}

private:clone_repository ()
{
    # Clone a git repository and test if it has a bootstrap file
    # $* url
    # return : local directory

    local ret
    ret=$(git clone -q "$1" "${2}" 2>&1)
    [[ $? -ne 0 ]] && die "Can't clone_repository : $ret" 20 0
}

process_dirs () {

    # Process a directory than contains subdir, create symblink from each subdir
    # to the destination.
    #
    # $1: source directory
    # $2: destination directory

    local dest="${repository}/$1"
    printf "\nProcess directory %s\n" "$1"

    [ ! -d "$dest" ] && { error "  -> source is not a directory"; return; }
    [ ! -d "$dest" ] && { error "  -> destination is not a directory"; return; }

    while read d
    do
        if [ $install -eq 1 ]
        then
            private:create_symblink "$d" "${2}/$(basename "$d")"
        else
            local symblink="${2}/$(basename ${d})"
            private:remove_symblink "$symblink"
        fi

    done < <(ls -d -1 "${dest}"/*/)
}

process_files () {

    # Process a directory than contains config files, create symblink from each
    # files to the destination.
    # $1: source directory
    # $2: destination directory
    
    local dest="${repository}/$1"
    printf "Process files from directory %s:\n" "$1"
    
    [ ! -d "$dest" ] && { error "  -> source is not a directory"; return; }
    [ ! -d "$dest" ] && { error "  -> destination is not a directory"; return; }

    while read d
    do
        if [ $install -eq 1 ]
        then
            private:create_symblink "$d" "$2/$(basename "$d")"
        else
            local symblink="${2}/$(basename ${d})"
            private:remove_symblink "$symblink"
        fi

    done < <(ls -1 "$dest")
}


install_service ()
{
    # Install an user service with systemd and activate it
    # $1 file
    # $2 1 to Activate the service

    local source="${repository}/$1"
    local ret
    [ ! -f "$source" ] && { error "$1 not found"; return; }
    local basename=$(basename "$source") 
    if [ $install -eq 1 ]
    then
        printf "\nInstall service %s :\n" "$source"
        private:create_symblink "$source" "${SYD_DIRECTORY}/${basename}"

        # activate service
        if [ $2 ]
        then
            printf "  -> Activate $basename : "
            ret=$(systemctl --user enable ${basename} 2>&1)
            [[ $? -ne 0 || ! $(systemctl --user is-enabled $basename) ]] && { error "$ret"; return; }
            printf "\e[32mdone\e[0m\n"
        fi
    else
        printf "\nUninstall service %s :\n" "$source"
        #Deactivate service
        if [ $1 ]
        then
            printf "    -> Deactivate $basename : "
            ret=$(systemctl --user disable ${basename} 2>&1)
            [[ $? -ne 0 ]] && { error "$ret"; return; }
            printf "\e[32mdone\e[0m\n"
        fi
    fi

}

check_bin ()
{
    # Check if an executable exist
    # $1 executables separated with spaces

    printf "Checking required programs :\n"
    for p in $1
    do
        printf "  -> %s:" "$p"
        command -v $p >/dev/null 2>&1 || die "not found" 128
        printf " \e[32mfound\e[0m\n"
    done
}

install_bin ()
{
    # Install a binary / script file as executable
    # Via a symbolic link
    # $1 : path to script

    local source="${repository}/${1}"
    local dest="${BIN_DIRECTORY}/$(basename $1)"
    
    printf "\nProcess executable :\n"
    [ ! -f "$source" ] && { error "$source is not a file"; return; }
    [ ! -x "$source" ] && { error "$source not executable "; return; }
    
    if [ $install -eq 1 ]
    then
        private:create_symblink "$source" "$dest"
    else
        private:remove_symblink "$dest"
    fi
}

## create bin directory
[ ! -d $BIN_DIRECTORY ] && mkdir -p $BIN_DIRECTORY || printf "bin exist\n"

# Test parameters : we need to know if it's a git repo or a file
[[ $1 == "uninstall" || $1 == "-u" ]] && { install=0; printf "Activate uninstall mode\n"; shift; }
echo $install
[ "$*" = "" ] && die "You must specify a bootstrap file" 10 1

if [[ $* =~ ^https://.*\.git$ || $* =~ ^ssh://.*\.git$ ]]
then
    bin_check "git"
    
    # Check
    localdir="${DOTREPO}/$(basename $* .git)"
    [ -d "$localdir" ] && die "destination folder for git repository already exist" 21 0
    
    private:clone_repository "$*" "$localdir"
    if [ -f "${localdir}/bootstrap" ]
    then
        $0 "${localdir}/bootstrap"
        exit $?
    else
        die "Can't find a \`boostrap\` file in ${repo}" 22 0
    fi
else
    [ ! -f "$*" ] && die "$* does not exist" 10 1
    private:get_bootstrap_path "$*"

    # Include bootstrap
    source $*
fi
exit 0
