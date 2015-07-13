#!/bin/bash

function myconvert {
  tmpfile=$(mktemp)
  pod2markdown "$1" |
    sed -re 's%(\[CPrAN[^]]*]\()https://metacpan\.org/pod/%\1%g' > "$tmpfile";
  file "$tmpfile" | egrep -q "(ASCII|ISO-8859)";
  if [ $? -eq 0 ]; then
    # echo "Converting \"$1\" to UTF-8";
    iconv -f ISO-8859-14 -t UTF-8 "$tmpfile" -o "doc/$(
      basename "$1" | sed -re 's/(pm|pl)$/md/'
    )";
  else
    # echo "Skipping \"$1\"";
    mv "$tmpfile" "doc/$(basename "$1" | sed -re 's/(pm|pl)$/md/')";
  fi
}

find CPrAN/ -name "*pm" | while read line; do myconvert "$line"; done
myconvert "CPrAN.pm"
myconvert "cpran.pl"
find CPrAN/ -name "*md" | while read line; do
  mv "$line" "$(echo "$line" | sed -re 's/(.*)/\L\1/')";
done

mv "doc/CPrAN.md" "doc/module.md"
