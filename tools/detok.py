#!/usr/bin/env python3
"""List a tokenised BBC BASIC program (the disc's front ends).   detok.py FILE"""
import sys

TOK = ["AND", "DIV", "EOR", "MOD", "OR", "ERROR", "LINE", "OFF", "STEP", "SPC", "TAB(", "ELSE", "THEN", "<line>", "OPENIN",
       "PTR", "PAGE", "TIME", "LOMEM", "HIMEM", "ABS", "ACS", "ADVAL", "ASC", "ASN", "ATN", "BGET", "COS", "COUNT", "DEG",
       "ERL", "ERR", "EVAL", "EXP", "EXT", "FALSE", "FN", "GET", "INKEY", "INSTR(", "INT", "LEN", "LN", "LOG", "NOT",
       "OPENUP", "OPENOUT", "PI", "POINT(", "POS", "RAD", "RND", "SGN", "SIN", "SQR", "TAN", "TO", "TRUE", "USR", "VAL",
       "VPOS", "CHR$", "GET$", "INKEY$", "LEFT$(", "MID$(", "RIGHT$(", "STR$", "STRING$(", "EOF", "AUTO", "DELETE",
       "LOAD", "LIST", "NEW", "OLD", "RENUMBER", "SAVE", "EDIT", "PTR", "PAGE", "TIME", "LOMEM", "HIMEM", "SOUND", "BPUT",
       "CALL", "CHAIN", "CLEAR", "CLOSE", "CLG", "CLS", "DATA", "DEF", "DIM", "DRAW", "END", "ENDPROC", "ENVELOPE", "FOR",
       "GOSUB", "GOTO", "GCOL", "IF", "INPUT", "LET", "LOCAL", "MODE", "MOVE", "NEXT", "ON", "VDU", "PLOT", "PRINT",
       "PROC", "READ", "REM", "REPEAT", "REPORT", "RESTORE", "RETURN", "RUN", "STOP", "COLOUR", "TRACE", "UNTIL", "WIDTH",
       "OSCLI"]


def lineno(b):
    return (((b[0] << 2) & 0xc0) ^ b[1]) | ((((b[0] << 4) & 0xc0) ^ b[2]) << 8)


def lines(path):
    """(line number, text) of each line; inside quotes nothing is a token, and bytes of 128 up (the teletext control
    codes of MODE 7 text) or under 32 are written \\xNN."""
    b = open(path, "rb").read()
    i = 0
    while i + 3 < len(b) and b[i] == 0x0d:
        ln = b[i + 1] << 8 | b[i + 2]
        if ln == 0xffff:
            break
        n = b[i + 3]
        t, s, j, quoted = b[i + 4:i + n], "", 0, False
        while j < len(t):
            c = t[j]
            if quoted:
                if c == 0x22:
                    quoted = False
                    s += '"'
                elif c >= 128 or c < 32:
                    s += "\\x%02x" % c
                else:
                    s += chr(c)
                j += 1
                continue
            if c == 0x22:
                quoted = True
                s += '"'
            elif c == 0x8d:
                s += str(lineno(t[j + 1:j + 4]))
                j += 3
            else:
                s += TOK[c - 0x80] if c >= 0x80 else chr(c)
            j += 1
        yield ln, s
        i += n


def main(path):
    for ln, text in lines(path):
        print(ln, text)


if __name__ == "__main__":
    main(sys.argv[1])
