# Performance Benchmarks

When introducing performance optimizations, we want to ensure that we are not
regressing performance. To do this, we have a set of benchmarks that we can run
to compare the performance of different versions of the code.

## Stoplight::DataStore::Memory#with_deduplicated_notification

This benchmark measures the performance of the `with_deduplicated_notification` method
in the `Stoplight::DataStore::Memory` class. This method is responsible for deduplicating
notifications that are sent to the data store. 

```
"=== Measuring High Contention Scenario ==="
       user     system      total        real
original               0.746578   0.647021   1.393599 ( 36.679392)
yield outside sync     0.203208   0.277723   0.480931 (  2.767637)
yield outside sync 2   0.236568   0.247015   0.483583 (  2.667852)
concurrent map         0.209853   0.229989   0.439842 (  2.658348)
concurrent map 2       0.243073   0.268041   0.511114 (  2.637344)

"=== Measuring Low Contention Scenario ==="
       user     system      total        real
original               0.843443   0.715945   1.559388 ( 38.109842)
yield outside sync     0.210029   0.200885   0.410914 (  2.395854)
yield outside sync 2   0.238965   0.196362   0.435327 (  2.457544)
concurrent map         0.215277   0.208665   0.423942 (  2.491836)
concurrent map 2       0.212998   0.229852   0.442850 (  2.560563)
```

The benchmark shows that yielding block outside the mutex synchronization block yields significant 
performance benefits. It also shows that using `Concurrent::Map` is yields marginal performance benefits
and is not worth the complexity.

## Stoplight::DataStore::Redis#record_failure

This benchmark measures the performance of the `record_failure` method in the `Stoplight::DataStore::Redis` class.
The old implementation used Redis transaction to perform four operations as a single unit. The new implementation
moves this logic to LUA script which yields ~38% performance improvement. 

```
ruby 3.3.4 (2024-07-09 revision be1089c8ec) [arm64-darwin23]
Warming up --------------------------------------
       not optimized     1.292k i/100ms
           optimized     2.214k i/100ms
Calculating -------------------------------------
       not optimized     16.963k (± 8.7%) i/s   (58.95 μs/i) -    167.960k in  10.033443s
           optimized     23.439k (± 4.7%) i/s   (42.66 μs/i) -    234.684k in  10.036023s

Comparison:
           optimized:    23439.3 i/s
       not optimized:    16963.3 i/s - 1.38x  slower
```
