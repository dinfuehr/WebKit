require 'stringio'

require_relative 'Opcode'
require_relative 'OpcodeGroup'

class Section
  attr_reader :name
  attr_reader :config
  attr_reader :opcodes

  def initialize(name, config)
    @name = name
    @config = config
    @opcodes = []
    @opcode_groups = []
  end

  def add_opcode(name, config)
      @opcodes << create_opcode(name, config)
  end

  def create_opcode(name, config)
      Opcode.new(self, name, config[:args], config[:metadata], config[:metadata_initializers])
  end

  def add_opcode_group(name, opcodes, config)
      opcodes = opcodes.map { |opcode| create_opcode(opcode, config) }
      @opcode_groups << OpcodeGroup.new(self, name, opcodes, config)
      @opcodes += opcodes
  end

  def sort!
      @opcodes = @opcodes.sort { |a, b| a.metadata.empty? ? b.metadata.empty? ? 0 : 1 : -1 }
      @opcodes.each(&:create_id!)
  end

  def header_helpers(num_opcodes)
      out = StringIO.new
      if config[:emit_in_h_file]
          out.write("#define FOR_EACH_#{config[:macro_name_component]}_ID(macro) \\\n")
          opcodes.each { |opcode| out.write("macro(#{opcode.name}, #{opcode.length}) \\\n") }
          out << "\n"

          out.write("#define NUMBER_OF_#{config[:macro_name_component]}_IDS #{opcodes.length}\n")
      end

      if config[:emit_in_structs_file]
          out.write("#define FOR_EACH_#{config[:macro_name_component]}_METADATA_SIZE(macro) \\\n")
          i = 0
          while true
              if opcodes[i].metadata.empty?
                  out << "\n"
                  out << "#define NUMBER_OF_#{config[:macro_name_component]}_WITH_METADATA #{i}\n"
                  break
              end

              out.write("macro(sizeof(#{opcodes[i].capitalized_name}::Metadata))\\\n")
              i += 1
          end
          out << "\n"
      end

      if config[:emit_opcode_id_string_values_in_h_file]
          out << "\n"
          opcodes.each { |opcode|
              out.write("#define #{opcode.name}_value_string \"#{opcode.id}\"\n")
          }
          opcodes.each { |opcode|
              out.write("#define #{opcode.name}_wide_value_string \"#{num_opcodes + opcode.id}\"\n")
          }
      end
      out.string
  end
end
