/*
 * Copyright (C) 2018 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#include "config.h"
#include "MetadataTable.h"

#include "CodeBlock.h"
#include "OpcodeInlines.h"

namespace JSC {

MetadataTable::MetadataTable(CodeBlock* codeBlock)
    : m_codeBlock(codeBlock)
{
    UnlinkedCodeBlock* unlinkedCodeBlock = codeBlock->unlinkedCodeBlock();
    for (unsigned i = 0; i < NUMBER_OF_BYTECODE_WITH_METADATA; i++) {
        auto opcodeID = static_cast<OpcodeID>(i);
        auto count = unlinkedCodeBlock->numberOfMetadataEntries(opcodeID);
        if (count) {
            size_t size = metadataSize(opcodeID) * count;
            void* buffer = malloc(size);
            memset(buffer, 0, size);
            m_data[opcodeID] = reinterpret_cast<Instruction::Metadata*>(buffer);
        } else
            m_data[opcodeID] = nullptr;
    }
}

size_t MetadataTable::sizeInBytes()
{
    return m_codeBlock->unlinkedCodeBlock()->metadataSizeInBytes();
}

struct DeallocTable {
    template<typename Op>
    static void withOpcodeType(void* table, size_t size)
    {
        auto* entries = reinterpret_cast<typename Op::Metadata*>(table);
        for (unsigned i = 0; i < size; i++)
            entries[i].~Metadata();
    }
};

MetadataTable::~MetadataTable()
{
    for (unsigned i = 0; i < NUMBER_OF_BYTECODE_WITH_METADATA; i++) {
        auto opcodeID = static_cast<OpcodeID>(i);
        auto* table = m_data[opcodeID];
        if (table) {
            size_t size = m_codeBlock->unlinkedCodeBlock()->numberOfMetadataEntries(opcodeID);
            getOpcodeType<DeallocTable>(opcodeID, table, size);
            free(table);
        }
    }
}

} // namespace JSC
