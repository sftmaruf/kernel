# Kernel

A minimal operating system kernel being written from scratch in [Zig](https://ziglang.org/).

This is a **learning project** exploring how operating systems work by building one piece at a time. It currently implements a userspace simulation of process management and scheduling, and is being incrementally expanded toward a real kernel.

> **Status:** Tick-based simulation. The scheduler, process lifecycle, and per-process CPU accounting run as a regular host executable today; booting, interrupts, and hardware interaction are not yet implemented.

## Features

- **Process model** with lifecycle states: `new`, `ready`, `running`, `blocked`, `terminated`
- **Process creation** with automatic `pid` assignment and an `execution_time` budget (`src/kernel.zig:create_process`)
- **Process lookup** by `pid` (`src/kernel.zig:find_process`)
- **Round-robin scheduler** that cycles through ready processes and hands the CPU to the next runnable one (`src/kernel.zig:schedule_process`)
- **Fixed 1-tick time slices** — `tick()` schedules when idle, runs the process for one tick, then rotates to the next (`src/kernel.zig:tick`)
- **Per-process CPU accounting** — each tick decrements `remaining_time` and increments `cpu_time`; a process is terminated when its budget is exhausted (`src/kernel.zig:run_process`)
- **Voluntary yield** — a running process can return to the ready queue early (`src/kernel.zig:yield`)
- **Process termination** (`src/kernel.zig:terminate_process`)
- **Saved CPU context** (`instruction_pointer`, `stack_pointer`, registers) per process, groundwork for future context switching (`src/cpu_context.zig`)
- **Inspectable logging** that can be toggled at compile time (`src/helper/config.zig`)

## Requirements

- [Zig](https://ziglang.org/download/) **0.15.1** (or newer, per `minimum_zig_version` in `build.zig.zon`)

## Building and running

```sh
zig build run
```

This compiles and executes the demo in `src/main.zig`, which:

1. Creates three processes with varying execution budgets (`shell` 3 ticks, `worker` 2, `shell` 4)
2. Simulates 10 CPU ticks, each calling `tick()` (schedule when idle, run for one tick, rotate)
3. Terminates each process as its budget is exhausted
4. Prints the final state of every process

Example output (run with inspection logging enabled):

```
Creating a process
Process created with id: 1

Creating a process
Process created with id: 2

Creating a process
Process created with id: 3


Instructed to schedule process
PID: [1] scheduled. Transitioned [ready] to [running]
Instructed to run the current process
PID: [1] is executed from 1 tick, Remaining time: 2

Instructed to schedule process
PID: [2] scheduled. Transitioned [ready] to [running]
Instructed to run the current process
PID: [2] is executed from 1 tick, Remaining time: 1

Instructed to schedule process
PID: [3] scheduled. Transitioned [ready] to [running]
Instructed to run the current process
PID: [3] is executed from 1 tick, Remaining time: 3

Instructed to schedule process
PID: [1] scheduled. Transitioned [ready] to [running]
Instructed to run the current process
PID: [1] is executed from 1 tick, Remaining time: 1

Instructed to schedule process
PID: [2] scheduled. Transitioned [ready] to [running]
Instructed to run the current process
PID: [2] is executed from 1 tick, Remaining time: 0
PID: [2] has terminated

Instructed to schedule process
PID: [3] scheduled. Transitioned [ready] to [running]
Instructed to run the current process
PID: [3] is executed from 1 tick, Remaining time: 2

Instructed to schedule process
PID: [1] scheduled. Transitioned [ready] to [running]
Instructed to run the current process
PID: [1] is executed from 1 tick, Remaining time: 0
PID: [1] has terminated

Instructed to schedule process
PID: [3] scheduled. Transitioned [ready] to [running]
Instructed to run the current process
PID: [3] is executed from 1 tick, Remaining time: 1

Instructed to schedule process
PID: [3] scheduled. Transitioned [ready] to [running]
Instructed to run the current process
PID: [3] is executed from 1 tick, Remaining time: 0
PID: [3] has terminated

Instructed to schedule process
No runnable processInstructed to run the current process

Processes and their current status:
PID 1: shell [terminated]
PID 2: worker [terminated]
PID 3: shell [terminated]
```

### Other commands

| Command              | Description                              |
| -------------------- | ---------------------------------------- |
| `zig build`          | Build the executable into `zig-out/bin/` |
| `zig build test`      | Run the tests                           |
| `zig build run`      | Build and run the demo                   |

## Project structure

```
src/
├── main.zig            # Demo entry point that exercises the kernel
├── root.zig            # Library root (tests, public API surface)
├── kernel.zig          # The Kernel: process table, scheduler, lifecycle ops
├── process.zig         # Process struct and ProcessState enum
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
                    (yield)
```

- `create_process(name)` creates a process in the `ready` state and assigns it the next `pid`.
- `schedule_process()` picks the next `ready` process (round-robin) and transitions it to `running`.
- `yield()` moves the current process from `running` back to `ready`, signaling it no longer needs the CPU.
- `terminate_process()` marks the current process as `terminated` and releases the CPU.

### The round-robin scheduler

`Kernel` keeps a `next_process_index` cursor into the process table. Each call to `schedule_process()`:

1. Returns the currently running process if one exists.
2. Otherwise scans forward from the cursor, wrapping around to the beginning when it reaches the end.
3. Transitions the first process it finds in the `ready` state to `running` and returns it.
4. Returns `null` if no runnable process exists (every process is `blocked`/`terminated`, or the table is empty).

### Logging

Log output is gated behind `enable_inscpection` in `src/helper/config.zig`. Set it to `false` to silence the kernel's diagnostic prints.

## Roadmap

Ideas for where this is headed next:

- **Time-slicing**: preempt the running process after a fixed quantum instead of relying on cooperative yield (see the note in `src/main.zig`)
- **Real process spawning** backed by threads/processes
- **Interrupt handling and a timer driver**
- **Memory management** (physical allocator, virtual address spaces)
- **Context switching** between user-space processes
- **Booting on real hardware** (multiboot/limine, serial console)

## Notes

- This is an intentionally small, readable codebase built to learn — not a production kernel.
- Real kernels use timer-driven preemptive scheduling; this prototype uses a cooperative model first to keep the logic easy to follow.
