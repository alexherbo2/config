decl str toolsclient
decl -hidden int find_current_line 0
decl -hidden str find_pattern

define-command -params ..1 find %{
    eval -save-regs '/' %{
        eval -save-regs '' -draft %{
            %sh{
                if [ -n "$1" ]; then
                    printf %s\\n "set-register / %arg{1}"
                else
                    printf %s\\n "set-register / %val{selection}"
                fi
            }
            try %{ delete-buffer *find* }
            eval -buffer * %{
                # create find buffer after we start iterating so as not to include it
                eval -draft %{ edit -scratch *find* }
                try %{
                    exec '%s<ret>'
                    eval -save-regs '/c' -itersel %{
                        # expand selection beginning and end to yank full lines
                        exec -draft -save-regs '' '<a-L><a-;><a-H>y'
                        # reduce to first character from selection to know the context
                        exec '<a-;>;'
                        set-register c "%val{bufname}:%val{cursor_line}:%val{cursor_column}:"
                        # paste context followed by the selection
                        # also align the selection in case it spans multiple lines
                        exec -buffer *find* 'geo<esc>"cp<a-p><a-s><a-;>&'
                    }
                }
            }
            exec -buffer *find* d
        }
        eval -try-client %opt{toolsclient} %{
            buffer *find*
            set buffer find_pattern "%reg{/}"
            set buffer filetype find
            set buffer find_current_line 0
        }
    }
}

hook -group find-highlight global WinSetOption filetype=find %{
    add-highlighter group find
    add-highlighter -group find dynregex '%opt{find_pattern}' 0:black,yellow
    add-highlighter -group find regex "^([^\n]*?):(\d+):(\d+)?" 1:cyan 2:green 3:green
    add-highlighter -group find line '%opt{find_current_line}' default+b
    # ensure whitespace is always after
    # kinda hacky
    try %{
        remove-highlighter show_whitespaces
        add-highlighter show_whitespaces
    }
}

hook global WinSetOption filetype=find %{
    hook buffer -group find-hooks NormalKey <ret> find-jump
}

hook -group find-highlight global WinSetOption filetype=(?!find).* %{
    remove-highlighter find
}

hook global WinSetOption filetype=(?!find).* %{
    remove-hooks buffer find-hooks
}

decl str jumpclient

def -hidden find-jump %{
    eval -collapse-jumps %{
        try %{
            exec -save-regs '' 'xs^([^\n]*?):(\d+):(\d+)<ret>'
            set buffer find_current_line %val{cursor_line}
            eval -try-client %opt{jumpclient} "edit -existing %reg{1} %reg{2} %reg{3}"
            try %{ focus %opt{jumpclient} }
        }
    }
}

def find-next -docstring 'Jump to the next find match' %{
    eval -collapse-jumps -try-client %opt{jumpclient} %{
        buffer '*find*'
        exec "%opt{find_current_line}ggl/^[^:]+:\d+:<ret>"
        find-jump
    }
    try %{ eval -client %opt{toolsclient} %{ exec %opt{find_current_line}g } }
}

def find-prev -docstring 'Jump to the previous find match' %{
    eval -collapse-jumps -try-client %opt{jumpclient} %{
        buffer '*find*'
        exec "%opt{find_current_line}g<a-/>^[^:]+:\d+:<ret>"
        find-jump
    }
    try %{ eval -client %opt{toolsclient} %{ exec %opt{find_current_line}g } }
}
