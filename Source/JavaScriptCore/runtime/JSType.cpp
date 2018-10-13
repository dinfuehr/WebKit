/*
 *  Copyright (C) 2006-2018 Apple Inc. All rights reserved.
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Library General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Library General Public License for more details.
 *
 *  You should have received a copy of the GNU Library General Public License
 *  along with this library; see the file COPYING.LIB.  If not, write to
 *  the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 *  Boston, MA 02110-1301, USA.
 */

#include "config.h"
#include "JSType.h"

#include <wtf/PrintStream.h>

namespace WTF {

class PrintStream;

#define CASE(__type) \
    case JSC::__type: \
        out.print(#__type); \
        return;

void printInternal(PrintStream& out, JSC::JSType type)
{
    switch (type) {
    CASE(CellType)
    CASE(StringType)
    CASE(SymbolType)
    CASE(BigIntType)
    CASE(CustomGetterSetterType)
    CASE(APIValueWrapperType)
    CASE(ProgramExecutableType)
    CASE(ModuleProgramExecutableType)
    CASE(EvalExecutableType)
    CASE(FunctionExecutableType)
    CASE(UnlinkedFunctionExecutableType)
    CASE(UnlinkedProgramCodeBlockType)
    CASE(UnlinkedModuleProgramCodeBlockType)
    CASE(UnlinkedEvalCodeBlockType)
    CASE(UnlinkedFunctionCodeBlockType)
    CASE(CodeBlockType)
    CASE(JSFixedArrayType)
    CASE(JSImmutableButterflyType)
    CASE(JSSourceCodeType)
    CASE(JSScriptFetcherType)
    CASE(JSScriptFetchParametersType)
    CASE(ObjectType)
    CASE(FinalObjectType)
    CASE(JSCalleeType)
    CASE(JSFunctionType)
    CASE(InternalFunctionType)
    CASE(NumberObjectType)
    CASE(ErrorInstanceType)
    CASE(PureForwardingProxyType)
    CASE(ImpureProxyType)
    CASE(DirectArgumentsType)
    CASE(ScopedArgumentsType)
    CASE(ClonedArgumentsType)
    CASE(ArrayType)
    CASE(DerivedArrayType)
    CASE(ArrayBufferType)
    CASE(Int8ArrayType)
    CASE(Uint8ArrayType)
    CASE(Uint8ClampedArrayType)
    CASE(Int16ArrayType)
    CASE(Uint16ArrayType)
    CASE(Int32ArrayType)
    CASE(Uint32ArrayType)
    CASE(Float32ArrayType)
    CASE(Float64ArrayType)
    CASE(DataViewType)
    CASE(GetterSetterType)
    CASE(GlobalObjectType)
    CASE(GlobalLexicalEnvironmentType)
    CASE(LexicalEnvironmentType)
    CASE(ModuleEnvironmentType)
    CASE(StrictEvalActivationType)
    CASE(WithScopeType)
    CASE(RegExpObjectType)
    CASE(ProxyObjectType)
    CASE(JSMapType)
    CASE(JSSetType)
    CASE(JSWeakMapType)
    CASE(JSWeakSetType)
    CASE(WebAssemblyToJSCalleeType)
    CASE(MaxJSType)
    }
}

#undef CASE

} // namespace WTF
