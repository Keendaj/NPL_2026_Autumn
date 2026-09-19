#!/usr/bin/env bash
cd "$(dirname "$0")" || exit 2
F=example.txt

pass=0
fail=0

run() {
    mine=$(perl grep.pl "$@" < "$F" 2>err.log); mine_rc=$?
    ref=$(grep "$@" < "$F" 2>/dev/null);        ref_rc=$?
    if [ "$mine" = "$ref" ] && [ "$mine_rc" = "$ref_rc" ]; then
        echo "OK    $*"
        pass=$((pass + 1))
    else
        echo "FAIL  $*  (codes: my $mine_rc, grep $ref_rc)"
        diff <(echo "$ref") <(echo "$mine") | cut -c1-90 | head -n 6 | sed 's/^/      /'
        [ -s err.log ] && echo "      stderr: $(head -n 1 err.log)"
        fail=$((fail + 1))
    fi
    rm -f err.log
}

run manor $F
run zzz $F
run Extremely $F
run -i Extremely $F

run -n manor $F
run -c she $F
run -c zzz $F
run -l manor $F
run -n -m 2 and $F
run -m 0 manor $F

run -c -v the $F
run -c he $F
run -c -w he $F
run -n -w she $F
run -c -i -v -w THE $F

run -n '^Extended' $F
run -n 'still\.$' $F
run -c 'age\.' $F
run -c -F 'age\.' $F
run -c '[0-9]' $F
run -c 'e.t' $F

run -c manor $F $F
run -h -c manor $F $F
run -l manor $F $F
run -n Extremely $F $F

run -n Extremely
run -c -w she

echo
echo "Correct: $pass, failed: $fail"
[ "$fail" -eq 0 ]
