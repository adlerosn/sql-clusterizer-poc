#!/usr/bin/env python3
# -*- encoding: utf-8 -*-

import sqlite3
import sys
from pathlib import Path

import pandas

DBPATH = Path('db.sqlite3')


def main():
    if len(sys.argv) < 2:
        sys.argv.append(DBPATH)
    for file in sys.argv[2:]:
        if not Path(file).is_file():
            raise FileNotFoundError(file)
    with sqlite3.connect(Path(sys.argv[1])) as conn:
        for file in sys.argv[2:]:
            conn.execute(f'drop table if exists {Path(file).stem};').close()
            pd = pandas.read_csv(Path(file))
            pd.to_sql(Path(file).stem, conn)


if __name__ == '__main__':
    main()
