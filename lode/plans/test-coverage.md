# BDOS Test Coverage Enhancement Plan

## Overview

Comprehensive test coverage for all 38 BDOS functions (F0-F40, excluding F0/warm boot and F38-39/unused). Functions grouped by logical relationship.

### Implementation Progress
| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Console Character I/O (F1, F2) | ✅ Complete |
| 2 | Console String I/O (F9, F10, F11) | ✅ Complete |
| 3 | Direct Console I/O (F6) | ✅ Complete |
| 4 | Auxiliary & List (F3, F4, F5) | ✅ Complete |
| 5 | IOBYTE Enhancement (F7, F8) | ✅ Complete |
| 6 | Version Enhancement (F12) | ✅ Complete |
| 7 | Disk System (F13, F14, F24, F25, F31, F37) | ✅ Complete |
| 8 | File Open/Close (F15, F16) | ✅ Complete |
| 9 | Directory Search Enhancement (F17, F18) | ✅ Complete |
| 10 | File Delete (F19) | ✅ Complete |
| 11 | Sequential I/O (F20, F21) | ✅ Complete |
| 12 | File Create (F22) | ✅ Complete |
| 13 | File Rename (F23) | ✅ Complete |
| 14 | DMA Address (F26) | ✅ Complete |
| 15 | Allocation & R/O (F27, F28, F29) | ✅ Complete |
| 16 | File Attributes Enhancement (F30) | ✅ Complete |
| 17 | User Number Enhancement (F32) | ✅ Complete |
| 18 | Random Access Enhancement (F33-F40) | ✅ Complete |

### Current Coverage Summary
- **Console I/O (F1-F11):** 11/11 tested ✅ All console functions covered
- **Disk/File (F12-F40):** 27/27 tested ✅ All disk/file functions covered
- **All BDOS functions have dedicated tests**

### Test Program Pattern
All tests follow the standard structure in `tests/programs/`:
- ORG 0100H, BDOS equates, test counter variables
- Numbered test cases (T1, T2...) with OK/NG reporting
- Summary: "N of M tests PASS/FAIL"

---

## Phase 1: Console Character I/O (F1, F2)
**File:** `tests/programs/tconch.asm` ✅

### Functions
| Fn | Name | Description |
|----|------|-------------|
| F1 | C_READ | Console input with echo |
| F2 | C_WRITE | Console output |

### Implemented Tests
1. **T1:** F2 output printable character ✅
2. **T2:** F2 output CR/LF sequence ✅
3. **T3:** F2 output TAB ✅
4. **T4:** F1 input with echo (reads 'A') ✅
5. **T5:** F1 input with echo (reads 'B') ✅

### Implementation Notes
- Input injection via `program_input` parameter in test harness
- F1 ^S/^P control character handling deferred (hard to verify automatically)

---

## Phase 2: Console String I/O (F9, F10, F11)
**File:** `tests/programs/tconstr.asm` ✅

### Functions
| Fn | Name | Description |
|----|------|-------------|
| F9 | C_WRITESTR | Print $-terminated string |
| F10 | C_READSTR | Buffered line input with editing |
| F11 | C_STAT | Console status (char ready?) |

### Implemented Tests
1. **T1:** F9 print simple string ✅
2. **T2:** F9 print empty string ✅
3. **T3:** F9 string with embedded CR/LF ✅
4. **T4:** F10 basic line input (with input injection) ✅
5. **T5:** F10 empty line input ✅
6. **T6:** F11 console status ✅

### Implementation Notes
- **Critical:** F11 must be called AFTER F10 reads input. F11's ^S check consumes a character from stdin, which would break subsequent F10 reads.
- F10 buffer overflow and line editing tests deferred (require more complex harness coordination)

---

## Phase 3: Direct Console I/O (F6)
**File:** `tests/programs/trawio.asm` ✅

### Functions
| Fn | Name | Description |
|----|------|-------------|
| F6 | C_RAWIO | Direct console I/O (4 modes) |

### Implemented Tests
1. **T1:** E=char - output "RAW" via F6 ✅
2. **T2:** E=CR/LF - output control characters ✅
3. **T3:** E=FDH - blocking input (reads 'X') ✅
4. **T4:** E=FFH - non-blocking input (reads 'Y') ✅
5. **T5:** E=FEH - status query ✅
6. **T6:** E=FFH - non-blocking when no input (returns 0) ✅

### Implementation Notes
- Input injection: "XY" for blocking and non-blocking reads
- F6 bypasses ^S/^P handling (raw mode)

---

## Phase 4: Auxiliary & List Devices (F3, F4, F5)
**File:** `tests/programs/tauxlst.asm` ✅

### Functions
| Fn | Name | Description |
|----|------|-------------|
| F3 | A_READ | Auxiliary/reader input |
| F4 | A_WRITE | Auxiliary/punch output |
| F5 | L_WRITE | List/printer output |

### Implemented Tests
1. **T1:** F4 punch output ("PU") ✅
2. **T2:** F5 list output ("LST") ✅
3. **T3:** F5 list CR/LF ✅
4. **T4:** F3 reader input ✅
5. **T5:** F3 returns 7-bit value ✅

### Implementation Notes
- Legacy devices rarely used in modern contexts
- In cpmsim, reader returns EOF (1AH) or 0 when no data
- Tests verify functions work without crashing

---

## Phase 5: IOBYTE Enhancement (F7, F8)
**File:** `tests/programs/tiobyte.asm` ✅ Enhanced

### Functions
| Fn | Name | Description |
|----|------|-------------|
| F7 | A_STATIN | Get IOBYTE |
| F8 | A_STATOUT | Set IOBYTE |

### Implemented Tests (8 total)
1. **T1:** F7 Get IOBYTE ✅
2. **T2:** F8 Set IOBYTE 55H ✅
3. **T3:** F8 Set IOBYTE AAH ✅
4. **T4:** F28 Write protect disk ✅
5. **T5:** Reset clears R/O status ✅
6. **T6:** Boundary value 00H ✅
7. **T7:** Boundary value FFH ✅
8. **T8:** Persistence across BDOS calls ✅

---

## Phase 6: Version Enhancement (F12)
**File:** `tests/programs/tversion.asm` ✅ Enhanced

### Functions
| Fn | Name | Description |
|----|------|-------------|
| F12 | S_BDOSVER | Return CP/M version |

### Implemented Tests (4 total)
1. **T1:** HL=0022H ✅
2. **T2:** A=L=22H ✅
3. **T3:** B=H=00H ✅
4. **T4:** Idempotence (3 calls, same result) ✅

---

## Phase 7: Disk System (F13, F14, F24, F25, F31, F37)
**File:** `tests/programs/tdisk.asm` ✅ Enhanced

### Functions
| Fn | Name | Description |
|----|------|-------------|
| F13 | DRV_ALLRESET | Reset all drives |
| F14 | DRV_SET | Select drive |
| F24 | DRV_LOGINVEC | Get logged-in drives bitmap |
| F25 | DRV_GET | Get current drive |
| F31 | DRV_DPB | Get Disk Parameter Block address |
| F37 | DRV_RESET | Reset specific drives |

### Implemented Tests (17 total)
1. **T1:** F25 Get Current Disk (=0) ✅
2. **T2:** F24 Login Vector bit 0 set ✅
3. **T3:** F13 Reset clears login vector ✅
4. **T4:** F13 Reset keeps disk 0 ✅
5. **T5:** F14 Select sets login bit ✅
6. **T6:** F27 Get ALV address (non-zero) ✅
7. **T7:** F31 Get DPB, verify SPT=26 ✅
8. **T8:** F29 R/O vector = 0 ✅
9. **T9:** F37 Reset drive clears login ✅
10. **T10:** F14 Invalid drive (16) ignored ✅
11. **T11:** F37 Multi-drive bitmask (0003H) ✅
12. **T12:** F31 DPB BSH=3 ✅
13. **T13:** F31 DPB BLM=7 ✅
14. **T14:** F31 DPB EXM=0 ✅
15. **T15:** F31 DPB DSM=242 ✅
16. **T16:** F31 DPB DRM=63 ✅
17. **T17:** F31 DPB OFF=2 ✅

---

## Phase 8: File Open/Close (F15, F16)
**File:** `tests/programs/topen.asm` ✅

### Functions
| Fn | Name | Description |
|----|------|-------------|
| F15 | F_OPEN | Open existing file |
| F16 | F_CLOSE | Close file |

### Implemented Tests (8 total)
1. **T1:** F15 Open existing file (HELLO.COM) ✅
2. **T2:** F15 Open non-existent file (expect FFH) ✅
3. **T3:** F16 Close file after open ✅
4. **T4:** F15 Verify RC > 0 after open ✅
5. **T5:** F15 Open with wildcard in extension (HELLO.???) ✅
6. **T6:** F16 Close without prior open (no crash) ✅
7. **T7:** F15 Verify EX=0 after open ✅
8. **T8:** F15 Verify allocation map (D0 non-zero) ✅

### Implementation Notes
- Tests use HELLO.COM which must exist on disk
- Verifies FCB fields (RC, EX, D0) are properly populated by BDOS

---

## Phase 9: Directory Search Enhancement (F17, F18)
**File:** `tests/programs/tsearch.asm` ✅ Enhanced

### Functions
| Fn | Name | Description |
|----|------|-------------|
| F17 | F_SFIRST | Search for first match |
| F18 | F_SNEXT | Search for next match |

### Implemented Tests (9 total)
1. **T1:** F17 Search exact file (SRCH1.TST) ✅
2. **T2:** F17 Search non-existent file ✅
3. **T3:** F17/18 Wildcard *.TST (finds 3+) ✅
4. **T4:** F17/18 Wildcard SRCH?.TST ✅
5. **T5:** Directory code 0-3 validation ✅
6. **T6:** Verify DMA entry has valid user/filename ✅
7. **T7:** Wildcard SR?H1.TST (? in middle) ✅
8. **T8:** Search *.* (all files, finds 3+) ✅
9. **T9:** Verify full filename match in DMA ✅

### Implementation Notes
- Creates SRCH1/2/3.TST test files during setup
- Cleans up test files after tests
- Verifies DMA buffer contents match expected directory format

---

## Phase 10: File Delete (F19)
**File:** `tests/programs/tdelete.asm` ✅

### Functions
| Fn | Name | Description |
|----|------|-------------|
| F19 | F_DELETE | Delete file(s) |

### Implemented Tests (8 total)
1. **T1:** F19 Delete existing file (DEL1.TST) ✅
2. **T2:** F19 Delete non-existent (no crash) ✅
3. **T3:** Verify DEL1.TST gone via search ✅
4. **T4:** DEL2, DEL3 still exist ✅
5. **T5:** Delete wildcard DEL?.TST ✅
6. **T6:** Verify DEL2 gone after wildcard ✅
7. **T7:** Verify DEL3 gone after wildcard ✅
8. **T8:** Delete already-deleted (no crash) ✅

### Implementation Notes
- Creates DEL1/2/3.TST test files during setup
- Tests single file, wildcard, and verification via search
- Note: Non-existent file delete behavior is implementation-defined

---

## Phase 11: Sequential I/O (F20, F21)
**File:** `tests/programs/tseqio.asm` ✅

### Functions
| Fn | Name | Description |
|----|------|-------------|
| F20 | F_READ | Read sequential record |
| F21 | F_WRITE | Write sequential record |

### Implemented Tests (8 total)
1. **T1:** F21 Write single record ✅
2. **T2:** F20 Read single record back ✅
3. **T3:** Verify data matches (00-7F pattern) ✅
4. **T4:** CR increment (3 writes, verify 0→1→2→3) ✅
5. **T5:** Read past EOF (expect A=1) ✅
6. **T6:** Extent transition on write (129 records) ✅
7. **T7:** Extent transition on read (129 records) ✅
8. **T8:** Verify DMA buffer contents after read ✅

### Implementation Notes
- More focused than existing fileio.asm/bigfile.asm
- Tests CR increment explicitly
- Tests extent transitions (record 129 forces new extent)
- Uses SEQIO.TST as temporary test file (cleaned up after)

---

## Phase 12: File Create (F22)
**File:** `tests/programs/tmake.asm` ✅

### Functions
| Fn | Name | Description |
|----|------|-------------|
| F22 | F_MAKE | Create new file |

### Implemented Tests (8 total)
1. **T1:** F22 Create new file (expect 0-3) ✅
2. **T2:** Verify file exists via search ✅
3. **T3:** Create existing file (no crash) ✅
4. **T4:** Verify EX=0, CR=0 after create ✅
5. **T5:** Create, close, reopen (persistence) ✅
6. **T6:** Create multiple files in sequence ✅
7. **T7:** Verify RC=0 (empty file) ✅
8. **T8:** Create + verify exists ✅

### Implementation Notes
- Tests FCB field initialization (EX, CR, RC)
- Tests file persistence after close/reopen
- Duplicate file creation is implementation-defined (test just verifies no crash)
- Creates MAKE1-7.TST test files (cleaned up after)

---

## Phase 13: File Rename (F23)
**File:** `tests/programs/trename.asm` ✅

### Functions
| Fn | Name | Description |
|----|------|-------------|
| F23 | F_RENAME | Rename file(s) |

### Implemented Tests (8 total)
1. **T1:** F23 Rename existing file ✅
2. **T2:** Verify new name exists ✅
3. **T3:** Rename non-existent (no crash) ✅
4. **T4:** Rename to same name ✅
5. **T5:** Rename one file, others intact ✅
6. **T6:** Rename back and forth ✅
7. **T7:** Change extension ✅
8. **T8:** Open renamed file ✅

### Implementation Notes
- FCB format: bytes 1-11 = old name, bytes 17-27 = new name
- Fixed BDOS bug: F23 was copying in wrong direction (from dir to FCB instead of FCB to dir)
- Creates REN1-6.TST test files (cleaned up after)

---

## Phase 14: DMA Address (F26)
**File:** `tests/programs/tdma.asm` ✅

### Functions
| Fn | Name | Description |
|----|------|-------------|
| F26 | F_DMAOFF | Set DMA transfer address |

### Implemented Tests (5 total)
1. **T1:** Set DMA to default 0080H ✅
2. **T2:** Set DMA to custom address, verify read uses it ✅
3. **T3:** Set DMA to custom address, verify search uses it ✅
4. **T4:** DMA at page boundary (256-byte aligned) ✅
5. **T5:** DMA persistence across multiple operations ✅

### Implementation Notes
- Tests verify DMA actually directs data to specified address
- T2 writes pattern to file, reads with DMA pointing to different buffer
- T3 verifies F17 search places directory entry at DMA address
- T4 uses page-aligned buffer (ORG alignment trick)
- T5 confirms DMA setting persists across multiple file reads

---

## Phase 15: Allocation & R/O (F27, F28, F29)
**File:** `tests/programs/talloc.asm` ✅

### Functions
| Fn | Name | Description |
|----|------|-------------|
| F27 | DRV_ALLOCVEC | Get allocation vector address |
| F28 | DRV_SETRO | Set drive read-only |
| F29 | DRV_ROVEC | Get R/O vector bitmap |

### Implemented Tests (6 total)
1. **T1:** F27 returns valid ALV address ✅
2. **T2:** ALV has bits set (files exist) ✅
3. **T3:** File create + write works ✅
4. **T4:** F28 sets R/O, F29 reflects it ✅
5. **T5:** Write to R/O drive returns error ✅
6. **T6:** F13 reset clears R/O status ✅

### Implementation Notes
- Creates ALLOC.TST as test file
- Tests R/O vector maintenance (setting, clearing, persistence)
- BDOS enforces R/O: F21/F34 return error 1 when drive is R/O

---

## Phase 16: File Attributes Enhancement (F30)
**File:** `tests/programs/tattrib.asm` ✅ Enhanced

### Functions
| Fn | Name | Description |
|----|------|-------------|
| F30 | F_ATTRIB | Set file attributes |

### Implemented Tests (7 total)
1. **T1:** Set R/O attribute (T1 bit 7) ✅
2. **T2:** Set SYS attribute (T2 bit 7) ✅
3. **T3:** Clear attributes ✅
4. **T4:** F30 on non-existent file returns FFH ✅
5. **T5:** Set Archive attribute (T3 bit 7) ✅
6. **T6:** Attribute persistence after close/reopen ✅
7. **T7:** R/O attribute preserved after file recreate ✅

### Implementation Notes
- All three attribute bits tested: R/O (T1), SYS (T2), Archive (T3)
- Persistence test verifies attributes survive open/close cycle
- T7 verifies R/O attribute persists through file deletion and recreation
- Note: CP/M 2.2 does NOT enforce file-level R/O (only drive-level via F28)

---

## Phase 17: User Number Enhancement (F32)
**File:** `tests/programs/tuser.asm` ✅ Enhanced

### Functions
| Fn | Name | Description |
|----|------|-------------|
| F32 | F_USERNUM | Get/set user number |

### Implemented Tests (7 total)
1. **T1:** Initial user = 0 after reset ✅
2. **T2:** Set user 5, get 5 ✅
3. **T3:** Set user 15 (max), get 15 ✅
4. **T4:** User masked to 0-15 (set 0x3F, get 0x0F) ✅
5. **T5:** Reset clears user to 0 ✅
6. **T6:** E=FFH idempotent (get without changing) ✅
7. **T7:** User isolation (file in user 0 not visible from user 1) ✅

### Implementation Notes
- Boundary values (0, 15) covered by T1, T3
- Invalid user number masking covered by T4
- User isolation verifies file namespace separation between users
- E=FFH tested 3 times in sequence to confirm no side effects

---

## Phase 18: Random Access Enhancement (F33, F34, F35, F36, F40)
**File:** `tests/programs/trandom.asm` ✅ Enhanced

### Functions
| Fn | Name | Description |
|----|------|-------------|
| F33 | F_READRAND | Random read |
| F34 | F_WRITERAND | Random write |
| F35 | F_SIZE | Compute file size |
| F36 | F_RANDREC | Set random record from sequential position |
| F40 | F_WRITEZF | Random write with zero fill |

### Implemented Tests (13 total)
1. **T1:** F35 File size = 10 ✅
2. **T2:** F33 Read random rec 5 ✅
3. **T3:** F34 Write random rec 15 ✅
4. **T4:** Read back rec 15 ✅
5. **T5:** F36 Set random from seq ✅
6. **T6:** Read unallocated block fails ✅
7. **T7:** Write/read record 127 (ext 0 boundary) ✅
8. **T8:** Write/read record 128 (ext 1 boundary) ✅
9. **T9:** F35 on empty file (size=0) ✅
10. **T10:** F40 write/read with gap verification ✅
11. **T11:** R2 overflow error (code 6) ✅
12. **T12:** Write/read record 255 (extent 1 boundary) ✅
13. **T13:** Write/read record 256 (extent 2 boundary) ✅

### Implementation Notes
- Extent boundary tests: T7/T8 (127/128), T12/T13 (255/256)
- F40 implemented same as F34 (zero fill optional per CP/M 2.2 spec)
- T10 tests F40 gap handling (lenient - accepts non-zero-fill implementations)
- R2 overflow correctly returns error code 6
- F35 on multi-extent file covered by existing file (16+ records after T3)

---

## Execution Order Recommendation

1. **Start with new console tests** (Phases 1-4) - isolated, no file system side effects
2. **Enhance existing disk tests** (Phases 5-7) - build on working foundation
3. **New file operation tests** (Phases 8-14) - core functionality gaps
4. **Enhance remaining tests** (Phases 15-18) - edge cases and completeness

## Files to Create
- `tests/programs/tconch.asm` (Phase 1) ✅
- `tests/programs/tconstr.asm` (Phase 2) ✅
- `tests/programs/trawio.asm` (Phase 3) ✅
- `tests/programs/tauxlst.asm` (Phase 4) ✅
- `tests/programs/topen.asm` (Phase 8) ✅
- `tests/programs/tdelete.asm` (Phase 10) ✅
- `tests/programs/tseqio.asm` (Phase 11) ✅
- `tests/programs/tmake.asm` (Phase 12) ✅
- `tests/programs/trename.asm` (Phase 13) ✅
- `tests/programs/tdma.asm` (Phase 14) ✅
- `tests/programs/talloc.asm` (Phase 15) ✅

## Files to Enhance
- `tests/programs/tiobyte.asm` (Phases 5, 15) ✅
- `tests/programs/tversion.asm` (Phase 6) ✅
- `tests/programs/tdisk.asm` (Phase 7) ✅
- `tests/programs/tsearch.asm` (Phase 9) ✅
- `tests/programs/tattrib.asm` (Phase 16) ✅
- `tests/programs/tuser.asm` (Phase 17) ✅
- `tests/programs/trandom.asm` (Phase 18) ✅

## Test Harness Updates
- `tests/run_tests.py` - add new test entries for each new .asm file
