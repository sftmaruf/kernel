# Kernel

A minimal operating system kernel being written from scratch in [Zig](https://ziglang.org/).

This is a **learning project** exploring how operating systems work by building one piece at a time. It currently implements a userspace simulation of process management and scheduling, and is being incrementally expanded toward a real kernel.

> **Status:** Early prototype. The scheduler and process lifecycle run as a regular host executable today; booting, interrupts, and hardware interaction are not yet implemented.

## Features

- **Process model** with lifecycle states: `new`, `ready`, `running`, `blocked`, `terminated`
- **Process creation** with automatic `pid` assignment (`src/kernel.zig:create_process`)
- **Process lookup** by `pid` (`src/kernel.zig:find_process`)
- **Round-robin scheduler** that cycles through ready processes and hands the CPU to the next runnable one (`src/kernel.zig:schedule_process`)
- **Preemption-less yielding** — a running process can voluntarily return to the ready queue (`src/kernel.zig:yield`)
- **Process termination** (`src/kernel.zig:terminate_process`)
- **Inspectable logging** that can be toggled at compile time (`src/helper/config.zig`)

## Requirements

- [Zig](https://ziglang.org/download/) **0.15.1** (or newer, per `minimum_zig_version` in `build.zig.zon`)

## Building and running

```sh
zig build run
```

This compiles and executes the demo in `src/main.zig`, which:

1. Creates three processes (`shell`, `worker`, `shell`)
2. Schedules the first runnable process
3. Yields the running process back to the ready queue
4. Schedules the next process (round-robin advances the cursor)
5. Prints the final state of every process

Example output:

```
Creating a process
Process created with id: 1
Creating a process
Process created with id: 2
Creating a process
Process created with id: 3
Running PID: 1
Running PID: 2
PID 1: shell [ready]
PID 2: worker [running]
PID 3: shell [ready]
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
