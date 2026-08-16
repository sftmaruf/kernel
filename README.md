# Kernel

A minimal operating system kernel being written from scratch in [Zig](https://ziglang.org/).

This is a **learning project** exploring how operating systems work by building one piece at a time. It currently implements a userspace simulation of process management and scheduling, and is being incrementally expanded toward a real kernel.

> **Status:** Preemptive time-quantum simulation. The scheduler, process lifecycle, per-process CPU accounting, and context save/restore run as a regular host executable today; booting, interrupts, and hardware interaction are not yet implemented.

## Features

- **Process model** with lifecycle states: `new`, `ready`, `running`, `blocked`, `terminated`
- **Process creation** with automatic `pid` assignment and a `cpu_burst` budget (`src/kernel.zig:create_process`)
- **Process lookup** by `pid` (`src/kernel.zig:find_process`)
- **Hardware CPU abstraction** — the kernel owns a `CPU` that executes instructions by advancing its program counter and can save/restore its full context (`src/hardware/cpu.zig`)
- **Preemptive round-robin scheduler** — cycles through ready processes and preempts the running one once it exhausts its fixed time quantum (default 5), returning it to the ready queue with its context saved (`src/kernel.zig:scheduleProcess`, `src/kernel.zig:tryPreempt`)
- **Per-process CPU accounting** — each instruction executed decrements `remaining_time` and increments `quantum_used`; a process is terminated when its burst is exhausted (`src/kernel.zig:runProcess`)
- **Context save/restore** — the CPU registers (`pc`, `sp`, `r0`-`r3`) are saved into a process's context on yield, preemption, or termination, and restored when it is scheduled (`src/cpu_context.zig`)
- **Voluntary yield** — a running process can return to the ready queue early (`src/kernel.zig:yield`)
- **Process termination** (`src/kernel.zig:terminateProcess`)
- **Inspectable logging** that can be toggled at compile time (`src/helper/config.zig`)

## Requirements

- [Zig](https://ziglang.org/download/) **0.16.0** (or newer, per `minimum_zig_version` in `build.zig.zon`)
- [Valgrind](https://valgrind.org/) (only for `zig build run-valgrind`)

## Building and running

```sh
zig build run
```

This compiles and executes the demo in `src/main.zig`, which:

1. Creates three processes with varying CPU bursts (`shell` 3 instructions, `worker` 100, `shell` 4)
2. Simulates 107 CPU ticks, each calling `tick()` (schedule when idle, run one instruction, preempt after the quantum)
3. Terminates each process as its burst is exhausted
4. Prints the final state of every process

Example output (run with inspection logging enabled, abbreviated):

```
Creating a process
Process created with id: 1

Creating a process
Process created with id: 2

Creating a process
Process created with id: 3


Instructed to schedule process
PID: [1] scheduled. Restoring PC: 100. Transitioned [ready] to [running]
Instructed to run the current process
PID: [1] executed instruction. Next PC: 101, Remaining time: 2
Instructed to run the current process
PID: [1] executed instruction. Next PC: 102, Remaining time: 1
Instructed to run the current process
PID: [1] executed instruction. Next PC: 103, Remaining time: 0
PID: [1] has terminated

Instructed to schedule process
PID: [2] scheduled. Restoring PC: 200. Transitioned [ready] to [running]
Instructed to run the current process
PID: [2] executed instruction. Next PC: 201, Remaining time: 99
Instructed to run the current process
PID: [2] executed instruction. Next PC: 202, Remaining time: 98
Instructed to run the current process
PID: [2] executed instruction. Next PC: 203, Remaining time: 97
Instructed to run the current process
PID: [2] executed instruction. Next PC: 204, Remaining time: 96
Instructed to run the current process
PID: [2] executed instruction. Next PC: 205, Remaining time: 95
PID: [2] preempted. Saved PC: 205

Instructed to schedule process
PID: [3] scheduled. Restoring PC: 300. Transitioned [ready] to [running]
Instructed to run the current process
PID: [3] executed instruction. Next PC: 301, Remaining time: 3
...
Processes and their current status:
PID 1: shell [terminated] | PC: 103
PID 2: worker [terminated] | PC: 300
PID 3: shell [terminated] | PC: 304
```

### Other commands

| Command              | Description                              |
| -------------------- | ---------------------------------------- |
| `zig build`          | Build the executable into `zig-out/bin/` |
| `zig build test`      | Run the tests                           |
| `zig build run`      | Build and run the demo                   |
| `zig build run-valgrind` | Run the executable under valgrind's leak checker (requires valgrind) |

## Project structure

```
src/
├── main.zig            # Demo entry point that exercises the kernel
├── root.zig            # Library root (tests, public API surface)
├── kernel.zig          # The Kernel: process table, scheduler, lifecycle ops
├── process.zig         # Process struct and ProcessState enum
├── cpu_context.zig     # CpuContext: the CPU state saved per process
├── hardware/
│   └── cpu.zig         # CPU abstraction: instruction execution, context save/restore
└── helper/
    ├── config.zig      # Compile-time feature toggles (e.g. inspection logging)
    └── logger.zig      # Conditional logging helpers
build.zig               # Build configuration (executable, tests, run step)
build.zig.zon           # Package metadata and Zig version requirement
```

## How it works

### Process lifecycle

Every process moves through a set of states defined in `src/process.zig`:

```
        ┌──────────────────────────────────────────┐
        │                                          │
        ▼                                          │
      new ──► ready ──► running ──► terminated
                   ▲        │
                   └────────┘
             (yield / preempt)
```

- `create_process(name)` creates a process in the `ready` state, assigns it the next `pid`, and seeds its context (each process starts its program counter at `pid * 100`).
- `scheduleProcess()` picks the next `ready` process (round-robin), restores its saved context into the CPU, resets its quantum, and transitions it to `running`.
- `runProcess()` advances the CPU by one instruction (incrementing its program counter) and updates the process's `remaining_time`/`quantum_used`.
- `yield()` saves the current context back into the process and moves it from `running` to `ready`, signaling it no longer needs the CPU.
- `terminateProcess()` saves the current context, marks the process as `terminated`, and releases the CPU.

### The round-robin scheduler

`Kernel` keeps a `next_process_index` cursor into the process table. Each call to `scheduleProcess()`:

1. Returns the currently running process if one exists.
2. Otherwise scans forward from the cursor, wrapping around to the beginning when it reaches the end.
3. Restores the first process it finds in the `ready` state into the CPU, transitions it to `running`, and returns it.
4. Returns `null` if no runnable process exists (every process is `blocked`/`terminated`, or the table is empty).

### Preemption

`Kernel` also holds a shared `CPU` and a fixed `quantum` (default 5). After each `tick()`, `tryPreempt()` checks whether the running process has used up its quantum:

1. If `quantum_used < quantum`, the process keeps the CPU for the next tick.
2. Otherwise, its context is saved back into the process, it returns to `ready`, and the CPU is released so the next `tick()` can schedule a new process.

This makes scheduling **preemptive**: no process can monopolize the CPU beyond its time quantum, even if it never yields.

### Logging

Log output is gated behind `enable_inscpection` in `src/helper/config.zig`. Set it to `false` to silence the kernel's diagnostic prints.

## Roadmap

Ideas for where this is headed next:

- **Real process spawning** backed by threads/processes
- **Interrupt handling and a timer driver** (to replace the simulated tick)
- **Memory management** (physical allocator, virtual address spaces)
- **Context switching** between user-space processes on a real CPU
- **Booting on real hardware** (multiboot/limine, serial console)

## Notes

- This is an intentionally small, readable codebase built to learn — not a production kernel.
- Real kernels drive preemptive scheduling from a hardware timer interrupt; this prototype simulates the timer with a loop of `tick()` calls to keep the logic easy to follow.
