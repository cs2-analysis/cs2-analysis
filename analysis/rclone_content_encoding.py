#!/usr/bin/env python3
import sys
import json

def main():
    if len(sys.argv) != 2:
        print("Usage: rclone_metadata_mapper.py <content-encoding>")
        sys.exit(1)
        
    o = { "Metadata": {"content-encoding": sys.argv[1]}}
    json.dump(o, sys.stdout, indent="\t")

if __name__ == "__main__":
    main()