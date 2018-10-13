# Bytecode format

+--------------+
|    header    |
+==============+
| instruction0 |
+--------------+
| instruction1 |
+--------------+
|     ...      |
+--------------+
| instructionN |
+--------------+

## Header

+--------------+
|num_parameters|
+--------------+
| has_metadata |
+--------------+
|  count_op1   |
+--------------+
|     ...      |
+--------------+
|  count_opN   |
+--------------+
|   liveness   |
+--------------+
| global_info  |
+--------------+
| constants    |
+--------------+

* `has_metada` is a BitMap that indicates which opcodes need side table entries
* `count_opI` is a varible length unsigned number that indicates how many entries are necessary for opcode I.

Given that we currently have < 256 opcodes, the BitMap should fit in 4 bytes.
Of all opcodes, ~40 will currently ever need metadata, so that if the bytecode for any CodeBlock uses all of this opcodes, it would an extra 40~160b, depending on how many instances of each opcode appear in the bytecode.

## Instruction

Instructions have variable length, and have the form

+-----------+------+-----+------+------------+
| opcode_id | arg0 | ... | argN | metadataID |
+-----------+------+-----+------+------------+

where N <= 0 and metadataID is optional

### Narrow Instructions

By the default, we try to encode every instruction in a narrow setting, where every segment has 1-byte. However, we will fall back to a "Wide Instruction" whenever any of the arguments overflows, i.e.:

* opcode_id: we currently have 167 opcodes, so this won't be a problem for now but, hypothetically, any opcodes beyond id 256 will have to be encoded as a wide instruction.
* arg: the type of the operand should never be ambiguous, therefore we support:
  + up to 256 of each of the following: local registers, constants and arguments
  + up to 8-byte types: we'll attempt to fit integers and unsigned integers in 8 bytes, otherwise fallback to a wide instruction.
* up to 256 metadata entries per opcode, i.e. if an opcode has metadata, only 256 instances of the same opcode will fit into the same CodeBlock.

### Wide Instructions

Wide instructions have 4-byte segments, but otherwise indistinguishable from narrow instructions.

We reserve the first opcode to a trampoline that will evaluate the next instruction as a "Wide Instruction", where each segment of the instruction has 4 bytes. This opcode will also be responsible to guaranteeing 4-byte alignment on ARM.

## API

A class/struct will be generated for each opcode. The struct wil be responsible for:
* Encoding, e.g. dumping the instruction into a binary format, and choosing between narrow or wide encoding
* Providing access to each of the instruction's arguments and metadata
* Potentially allow dumping the instruction, simplifying the work done by the BytecodeDumper

Here's what the API may look like for each of this operations, for e.g. the `op_get_argument` (this opcode should be a good example, since it has multiple argument types and metadata). Here is its current declaration (syntax may still change)

```ruby
op :get_argument,
  args: {
    dst: :Register,
    index: :unsigned,
  },
  metadata: {
    profile: :ValueProfile,
  }
```

### Encoding

```cpp
static void OpGetArgument::create(BytecodeGenerator& generator RegisterID* register, unsigned index);
```


### Field Access

```cpp
RegisterID OpGetArgument::dst();
unsigned OpGetArgument::index();
```

### Metadata Acess
```cpp
ValueProfile* OpGetArgument::profile(ExecState&);
```

### BytecodeDumper

```cpp
void OpGetArguments::dump(BytecodeDumper&);
```

### Decoding

Decoding should be done by the base instruction/reader class.

```cpp
Instruction::Unknown* Instruction::read(UnlinkedInstructionStream::Reader&);
```

## "Linking"

Linking, in its current form, should no longer be necessary. Instead, it will consist of creating the side table for the bytecode metadata and ensuring that the jump table with the offset for each opcode has been initialized.

### Side table

A callee-saved register pointing to the current CodeBlock's can be kept at all times to speed up metadata accesses that are necessary specially for profiling.

### Jump table

A mapping from opcode IDs to opcode addresses is already generated in InitBytecodes.asm and loaded by LLIntData.

## Portability

Due to different alignment requirements, the bytecode should not portable across different platforms.
Does enabling the JIT affect the bytecode? Possibly not, since it may only affect the metadata and not the bytecode itself, but TBC.

## Performance

Removing the linking step means that the interpreter will no longer be direct-threaded. Disabling COMPUTED_GOTO in CLoop (in order to disable direct threading) shows a 1% regression on PLT.

However, CLoop's fallback implementation is a switch statement, which affects branch prediction.

Alternatively, hacking JSC to skip replacing opcodes with their addresses during linking and modifying the dispatch macro in CLoop to fetch opcodes addresses shows a ~1% progression over CLoop with COMPUTED_GOTO enabled.

### get_by_id

`get_by_id` is the instruction that will require the most change, since we currently rewrite the bytecode stream to select from multiple implementations that share the same size. We can default to trying the most performance critical version of `get_by_id` first and fallback to loading the metadata field that specifies which version of the opcode should we execute.

# Current issues

Forward jumps will always generate wide opcodes: UINT_MAX is used as invalidLocation, which means that the address won't fit into a 1-byte operand. We might need to compact it later.
