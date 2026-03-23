# conf.d/z.fish (fisher管理) より先に読み込ませて
# set -U でリテラル ~ が fish_variables に書き込まれるのを防ぐ
set -gx Z_DATA $HOME/.local/share/z/data
set -gx Z_DATA_DIR $HOME/.local/share/z
set -gx Z_EXCLUDE "^$HOME\$"
