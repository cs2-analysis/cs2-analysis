#!/usr/bin/env python3
import argparse
import idapro
import idaapi
from idaapi import ida_ida, ida_expr, ida_idaapi
from os import path

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("input", help="Input file to open")
    args = parser.parse_args()

    idapro.enable_console_messages(True)

    print(f"Analyzing file {args.input}")
    idapro.open_database(args.input, True)
    idaapi.auto_wait()

    print("Generating BinExport")
    binexportPath = path.splitext(args.input)[0] + ".BinExport"
    ida_expr.eval_idc_expr(None, ida_idaapi.BADADDR, f'BinExportBinary("{binexportPath}")')

    print("Closing database")
    ida_ida.inf_set_compress_idb(False)
    idapro.close_database()

if __name__ == "__main__":
    main()
