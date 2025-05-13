#!/usr/bin/env zsh


run_benchmarks() {
  local window_size=$1
  echo "\n\n=== window_size: $window_size ==="
  export WINDOW_SIZE=$window_size

  git checkout feature/failure-success-counting
  bundle exec ruby bench/redis_bench.rb
  git checkout feature/failure-success-counting-hash-based-buckets
  bundle exec ruby bench/redis_bench.rb
  git checkout feature/failure-success-counting-hash-based-buckets-min-30s-granularity
  bundle exec ruby bench/redis_bench.rb
}

#run_benchmarks 300
#run_benchmarks 600
#run_benchmarks 900
#run_benchmarks 1200
#run_benchmarks 1500
#run_benchmarks 1800
#run_benchmarks 2100
#run_benchmarks 2400
#run_benchmarks 2700
#run_benchmarks 3000
#run_benchmarks 3300
#run_benchmarks 3600
run_benchmarks 3900
run_benchmarks 4200
run_benchmarks 4500
run_benchmarks 4800
run_benchmarks 5100
run_benchmarks 5400
run_benchmarks 5700
run_benchmarks 6000
run_benchmarks 6300
run_benchmarks 6600
run_benchmarks 6900
run_benchmarks 7100
run_benchmarks 7400
run_benchmarks 7700
run_benchmarks 8000
run_benchmarks 8300
run_benchmarks 8600
run_benchmarks 8900
run_benchmarks 9100
run_benchmarks 9400
run_benchmarks 9700
run_benchmarks 10000
