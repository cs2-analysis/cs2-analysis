#!/usr/bin/env python3
import argparse
import idapro

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("input", help="Input file to open")
    args = parser.parse_args()

    idapro.enable_console_messages(True)

    print(f"Analyzing file {args.input}")
    idapro.open_database(args.input, True)

    print("Closing database")
    idapro.close_database()

if __name__ == "__main__":
    main()
