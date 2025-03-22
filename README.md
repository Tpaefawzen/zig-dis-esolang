# zig-dis-esolang
Implementation of the esoteric prorgramming language [Dis].

Generalized base, generalized digit, generalized bits of data.

## About [Dis]
A programming language that works on base-3 10-digit computer of
accumulator A, program counter C, and data pointer D, and 59049
cells of base-3 10-digit memory with shared data and shared code,
and a byte-unit of input and output functions.

### Machine instructions
Every instruction shall take no operands; the program must do something
with accumulator A, data pointer D, and content of memory at address
number contained in register D.

Instruction 33 is halt command; the computer stops.
Instruction 42 is data-loader; `D := mem[D]`.
Instruction 62 is right-rotate operator; `A, mem[D] := rotate(mem[D])`.
The content of memory specified at register D gets 

[Dis]: https://www.esolangs.org/wiki/Dis
