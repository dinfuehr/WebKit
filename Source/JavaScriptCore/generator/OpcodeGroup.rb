require_relative 'Opcode'

class OpcodeGroup
    attr_reader :name
    attr_reader :opcodes
    attr_reader :config

    def initialize(section, desc, opcodes, config)
        @section = section
        @name = name
        @opcodes = opcodes
        @config = config
    end
end
