# Kernel

A minimal operating system kernel being written from scratch in [Zig](https://ziglang.org/).

This is a **learning project** exploring how operating systems work by building one piece at a time. It currently implements a round-robin process scheduler that boots and runs bare-metal in QEMU.

> **Status:** The scheduler, process lifecycle, and per-process CPU accounting run as a bare-metal kernel in QEMU. Booting via Multiboot, VGA text-mode output, and serial port output are implemented. Interrupts, memory management, and real context switching are not yet implemented.

## Features

- **Bare-metal boot** via Multiboot 1 header, runs directly in QEMU without an OS
- **VGA text-mode output** for on-screen display (`src/vga.zig`)
- **Serial port output** for terminal visibility (`src/vga.zig`)
- **Process model** with lifecycle states: `new`, `ready`, `running`, `blocked`, `terminated`
- **Process creation** with automatic `pid` assignment and an `execution_time` budget (`src/kernel.zig:create_process`)
- **Process lookup** by `pid` (`src/kernel.zig:find_process`)
- **Round-robin scheduler** that cycles through ready processes and hands the CPU to the next runnable one (`src/kernel.zig:schedule_process`)
- **Fixed 1-tick time slices** — `tick()` schedules when idle, runs the process for one tick, then rotates to the next (`src/kernel.zig:tick`)
- **Per-process CPU accounting** — each tick decrements `remaining_time` and increments `cpu_time`; a process is terminated when its budget is exhausted (`src/kernel.zig:run_process`)
- **Voluntary yield** — a running process can return to the ready queue early (`src/kernel.zig:yield`)
- **Process termination** (`src/kernel.zig:terminate_process`)
- **Saved CPU context** (`instruction_pointer`, `stack_pointer`, registers) per process, groundwork for future context switching (`src/cpu_context.zig`)

## Requirements

- [Zig](https://ziglang.org/download/) **0.16.0** (or newer, per `minimum_zig_version` in `build.zig.zon`)
- [QEMU](https://www.qemu.org/) (`qemu-system-i386`)

## Building and running

```sh
zig build run-qemu
```

This compiles the kernel for x86 freestanding, boots it in QEMU, and outputs to your terminal via the serial port. Press `Ctrl+C` to exit.

The kernel:

1. Creates three processes with varying execution budgets (`shell` 3 ticks, `worker` 2, `shell` 4)
2. Simulates 10 CPU ticks, each calling `tick()` (schedule when idle, run for one tick, rotate)
3. Terminates each process as its budget is exhausted
4. Prints the final state of every process

Example output:

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

...

Processes and their current status:
PID 1: shell [terminated]
PID 2: worker [terminated]
PID 3: shell [terminated]
```

## Project structure

```
src/
├── vga.zig              # VGA text-mode driver and serial port output
├── kernel.zig           # The Kernel: process table, scheduler, lifecycle ops
├── process.zig          # Process struct and ProcessState enum
├── cpu_context.zig      # CPU context struct (registers, instruction/stack pointers)
└── boot/
    ├── main.zig         # Multiboot header, stack, entry point, kmain
    └── linker.ld        # Linker script for i386 Multiboot
build.zig                # Build configuration (QEMU target, run step)
build.zig.zon            # Package metadata and Zig version requirement
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
4. Returns if no runnable process exists (every process is `blocked`/`terminated`, or the table is empty).

## Roadmap

Ideas for where this is headed next:

- **Time-slicing**: preempt the running process after a fixed quantum instead of relying on cooperative yield
- **Real process spawning** backed by threads/processes
- **Interrupt handling and a timer driver**
- **Memory management** (physical allocator, virtual address spaces)
- **Context switching** between user-space processes

## Notes

- This is an intentionally small, readable codebase built to learn — not a production kernel.
- Real kernels use timer-driven preemptive scheduling; this prototype uses a cooperative model first to keep the logic easy to follow.
