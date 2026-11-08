# secretive fish completions

complete -c secretive -f

# Top level commands
set -l cmds key cert agent env version

complete -c secretive -n "not __fish_seen_subcommand_from $cmds" -a key -d 'Manage Secure Enclave keys'
complete -c secretive -n "not __fish_seen_subcommand_from $cmds" -a cert -d 'Manage OpenSSH certificates'
complete -c secretive -n "not __fish_seen_subcommand_from $cmds" -a agent -d 'Manage SecretAgent'
complete -c secretive -n "not __fish_seen_subcommand_from $cmds" -a env -d 'Print shell environment configuration'
complete -c secretive -n "not __fish_seen_subcommand_from $cmds" -a version -d 'Print version information'
complete -c secretive -n "not __fish_seen_subcommand_from $cmds" -s h -l help -d 'Print help'
complete -c secretive -n "not __fish_seen_subcommand_from $cmds" -l json -d 'Format output as JSON'

# Key subcommands
complete -c secretive -n "__fish_seen_subcommand_from key; and not __fish_seen_subcommand_from list show create delete rename" -a list -d 'List all available keys'
complete -c secretive -n "__fish_seen_subcommand_from key; and not __fish_seen_subcommand_from list show create delete rename" -a show -d 'Show details, public key, or fingerprint'
complete -c secretive -n "__fish_seen_subcommand_from key; and not __fish_seen_subcommand_from list show create delete rename" -a create -d 'Create a new key'
complete -c secretive -n "__fish_seen_subcommand_from key; and not __fish_seen_subcommand_from list show create delete rename" -a delete -d 'Permanently delete a key'
complete -c secretive -n "__fish_seen_subcommand_from key; and not __fish_seen_subcommand_from list show create delete rename" -a rename -d 'Rename an existing key'

# Cert subcommands
complete -c secretive -n "__fish_seen_subcommand_from cert; and not __fish_seen_subcommand_from list import delete" -a list -d 'List imported certificates'
complete -c secretive -n "__fish_seen_subcommand_from cert; and not __fish_seen_subcommand_from list import delete" -a import -d 'Import a certificate from a file'
complete -c secretive -n "__fish_seen_subcommand_from cert; and not __fish_seen_subcommand_from list import delete" -a delete -d 'Delete an imported certificate'

# Agent subcommands
complete -c secretive -n "__fish_seen_subcommand_from agent; and not __fish_seen_subcommand_from status" -a status -d 'Show whether SecretAgent is running'

# File completions for cert import
complete -c secretive -n "__fish_seen_subcommand_from import" -F
