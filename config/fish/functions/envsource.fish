function envsource
  for line in (cat $argv | grep -v '^#' | grep -v '^\s*$')
    set item (string split -m 1 '=' $line)
    set key (string replace 'export ' '' $item[1])
    set -gx $key $item[2]
  end
end
