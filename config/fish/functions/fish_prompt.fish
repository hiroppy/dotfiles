function fish_prompt
    set last_status $status

    if [ $status -eq 0 ]
        set_color 69DC85
        echo -n '(๑˃̵ᴗ˂̵)و'
        set_color normal
    else
        set_color FF0087
        echo -n '｡◕ˇ_ˇ◕｡'
        set_color normal
    end

    echo -n ' '

    set_color $fish_color_cwd
    printf '%s' (prompt_pwd)
    set_color normal

    printf '%s ' (__fish_git_prompt)

    set_color 69DC85
    echo -n ' ᐅ '
    set_color normal
end
