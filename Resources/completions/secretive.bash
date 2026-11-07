_secretive() {
    local cur prev words cword
    _init_completion || return
    
    if [[ $cword -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "key cert agent env version" -- "$cur") )
        return
    fi
    
    case ${words[1]} in
        key)
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=( $(compgen -W "list show create delete rename" -- "$cur") )
            fi
            ;;
        cert)
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=( $(compgen -W "list import delete" -- "$cur") )
            fi
            ;;
        agent)
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=( $(compgen -W "status" -- "$cur") )
            fi
            ;;
    esac
}
complete -F _secretive secretive
