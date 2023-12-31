# SQL Clusterizer

This project is a Proof-of-Cocept that has the goal to demonstrate that SQL can be used to do really basic clusterization workloads, even if it's barely useful for more complex real-world scenarios, such as this approach that picks the most distant point within cartesian distance and later picks the closest reference point.

As this approach may technically count as some very primitive sort of machine learning, this implies that pretty much every SQL database in production is able to do machine learning.

## How well it scales

It takes about a dozen seconds to cluster 64 records with 4 features each (it's tinier than most toy datasets).

Prefer using a library within your programming language instead.

## See also

- [SQL Linear Regressor PoC](https://git.adlerneves.com/adler/sql-linear-regressor-poc)
