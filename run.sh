#!/bin/sh
# vitest --watch: tests/link.test.js is a symbolic link to store/a.test.js. The link is replaced
# by one to store/b.test.js (made beside it and renamed over it). Is the test file run again, so
# that the results show the new target? The control is a plain edit of another test file.
# The line it prints also says whether the watcher under vitest reported the replaced link
# (vitest.config.js logs its events) and whether vitest ran the linked file again.
# Usage: npm install && sh run.sh [same|other]
#   same   the old and the new target have the same modification time
#   other  they have different modification times
cd "$(dirname "$0")" || exit 1
mode=${1:-other}
touch -d '2026-01-01 00:00:00' store/a.test.js
if [ "$mode" = same ]; then touch -d '2026-01-01 00:00:00' store/b.test.js; else touch -d '2026-02-02 00:00:00' store/b.test.js; fi
cat store/a.test.js store/b.test.js > /dev/null      # both targets have been read, as files in use have
has() { if grep -q "$1" watch.log 2>/dev/null; then echo yes; else echo no; fi; }
wait_for() { i=0; until [ "$(has "$1")" = yes ] || [ $i -ge "$2" ]; do sleep 1; i=$((i+1)); done; has "$1"; }
plain() { printf "import { test } from 'vitest';\ntest('%s', () => {});\n" "$1" > tests/plain.test.js; }
plain PLAIN1; ln -sfn ../store/a.test.js tests/link.test.js
./node_modules/.bin/vitest --watch --dir tests --reporter=verbose > watch.log 2>&1 &
pid=$!
first=$(wait_for TARGET_A 90)
sleep 3
plain PLAIN2                                  # control: a plain edit
edit=$(wait_for PLAIN2 30)
sleep 2
before=$(wc -l < watch.log)
ln -s ../store/b.test.js tests/.link.tmp && mv -T tests/.link.tmp tests/link.test.js   # the link now points at b.test.js
retarget=$(wait_for TARGET_B 20)
since() { tail -n +$((before+1)) watch.log; }
if since | grep -q 'WATCH .*tests/link\.test\.js'; then event=yes; else event=no; fi
if since | grep -q 'link\.test\.js.*TARGET_'; then rerun=yes; else rerun=no; fi
plain PLAIN3                                  # a later edit of another test file
later=$(wait_for PLAIN3 30)
sleep 2
after=$(has TARGET_B)
kill $pid 2>/dev/null
if ./node_modules/.bin/vitest run --dir tests --reporter=verbose 2>&1 | grep -q TARGET_B; then fresh=yes; else fresh=no; fi
rm -f tests/link.test.js; plain PLAIN1
echo "RESULT target_times=$mode first_build=$first plain_edit_followed=$edit new_target_shown=$retarget later_edit_followed=$later new_target_after_later_edit=$after fresh_build=$fresh watcher_event=$event linked_file_run_again=$rerun"
