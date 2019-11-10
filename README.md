dotinstall - manage dotfiles
----------------------------

`dotinstall` is another little script made for install or uninstall dotfiles by
creating symbolic link. You need to provide a boostrap script for it.

## How to use

```
dotinstall bootstrap
```

The script can use git to retrieve a repository :

```
dotinstall https://git.example.com/user/repo.git
```

You can uninstall the dotfiles by adding the `uninstall` keyword before the
bootstrap file :

```
dotinstall uninstall bootstrap
```

## Boostrap file syntax

`bootstrap` is a simple bash script sourced by `dotinstall`. The `bootstrap`
file contains instructions and can call functions and use variables from
dotinstall:

### functions

#### bin_check

This function check if binary file is avaible in the `PATH`.

 - **input** : list of executable separated by spaces"
 - **return** : no value, but exit the entire script if a executable is not
     found with exit code 128

```
bin_check "ls mv git"
```

#### conf_process_dirs

Process a directory that contains others directories an symblink them to the
destination folder :

 - **input** :
     - `$1` : source directory
     - `$2` : destination directory
 - **return** : no value, exit the funtion if there is an error on path

```
conf_process_dirs "${repository}/config" "${HOME}/.config"
```

#### conf_process_files

Process a directory than contains files and symblink them to the destination
folder :

 - **input** :
     - `$1` : source directory
     - `$2` : destination directory
 - **return** : no value, exit the funtion if there is an error on path

```
conf_process_dirs "${repository}/zshrc" "${HOME}"
```

#### bin_install

Symblink an executable file to the `~/.local/bin` folder.

 - **input** : 
     - `$1` : source file
 - **return** : no value, exit the function if the source file not exist or is
     not executable.

```
bin_install "bin/check_mails.sh
```

#### service_install

Install a systemd service as user, can be useful for timers for example :

 - **input** : 
     - `$1` : source file
     - `$2` : 1 if service must be activated
 - **return** : no value, but exit the function if source file is not found or
     the service can't be activated

```
service_install "services/myservice.service" 1
```

### Avaible variables

 - `$repository` : the root folder of the repository
 - `OVERWRITE_DIRECTORY` : if `1`, the script will erase a directory and replace
     it with a symblink if needed. For example if `~/.vim/` exist, but your
     boostrap file need to create a symblink from `~/.config/dotrepo/conf/vim`
     to `~/.vim`, it will be erased fist. If 0, an error message will be
     displayed.
 - `OVERWRITE_FILE` : do the same with file

## Licence

This softeware is licenced under the GNU-GPL 3 licence, you can found a copy of
the licence [here](https://www.gnu.org/licenses/gpl-3.0.en.html).
