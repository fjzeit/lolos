# Roadmap

## Current State

LOLOS is fully operational with all 27 automated tests passing.

### Implemented
- Full BIOS (17 entry points, z80pack I/O)
- Full BDOS (functions 0-37, 40)
- Full CCP (DIR, ERA, REN, TYPE, SAVE, USER, transient loading)
- Sequential and random file I/O
- Multi-extent file support (>16K files)
- Automated test suite

### Verified Compatible
- BBC BASIC 5.x
- MBASIC 5.29
- Colossal Cave Adventure

## Future Work

### Compatibility Testing
- [ ] WordStar or similar editor
- [ ] Turbo Pascal or other compilers
- [ ] Report and fix compatibility issues

### Known Limitations
- Warm boot uses memory copy instead of disk reload
- Test duration ~7 minutes due to cpmsim timeout handling (cpmsim doesn't exit when stdin closes)

### Known Issues
- DIR shows corrupted filenames after running BIGFILE (multi-extent file I/O) in same session. Disk is correct; workaround is warm boot. See [tmp/bigfile-issue.md](../tmp/bigfile-issue.md).
