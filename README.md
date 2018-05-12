# Match
- Line Matcher for text data, like grep but more opinionated.

### Usage
- match vars.conf TEMPLATE < INPUT_FILE

### File formats
- vars.conf (example)
```ini
ANY = \S+
NUM = \d+
```
- template.conf (example, any text that will match with INPUT_FILE)
```
The quick brown fox jumps over the lazy dog NUM times
The quick brown ANY jumps over the lazy dog NUM times
```
- INPUT_FILE (any text that will match with TEMPLATE)
```
The quick brown fox jumps over the lazy dog 100 times
The quick brown fox jumps over the lazy dog X times
The quick brown cow jumps over the lazy dog 100 times
The quick brown cow jumps over the lazy dog 100
```

### Output for above example
```
% ./match examples/vars.conf examples/template.conf < examples/input.txt
[Line: 2] Unrecognized token. Expected: NUM: /^\d+/
The quick brown fox jumps over the lazy dog X times
                                            ^
[Line: 4] Incomplete line. Expected: times
The quick brown cow jumps over the lazy dog 100
                                                ^^^
Total: 5 lines, Processed 4 lines in 0.118 ms, found  2  issue(s)
```

### License
- MIT

### Note
- Release binary on OSX is dynamic, and static on linux

### Limitations
- VARS(Regex) and plain texts cannot overrlap (only one will be chosen)
  - abc(TEXT) and abc*(VARS)

- No backtracking, when there is two route a->B->c, and a->Z->y
    - if B is chosen and c does not match, program will not attempt to backtrack to c->Z->y

- Using unsafe semantics, it may segfault or harm your computer. Use at your own risk.
