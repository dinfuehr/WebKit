require 'optparse'

$config = {
    bytecodesFilename: {
        short: "-b",
        long: "--bytecodes_h FILE",
        desc: "generate bytecodes macro .h FILE",
    },
    bytecodeStructsFilename: {
        short: "-s",
        long: "--bytecode_structs_h FILE",
        desc: "generate bytecode structs .h FILE",
    },
    initAsmFilename: {
        short: "-a",
        long: "--init_bytecodes_asm FILE",
        desc: "generate ASM bytecodes init FILE",
    },
    bytecodeIndicesFilename: {
        short: "-i",
        long: "--bytecode_indices_h FILE",
        desc: "generate indices of bytecode structs .h FILE",
    },
};

module Options
    def self.optparser(options)
        OptionParser.new do |opts|
            opts.banner = "usage: #{opts.program_name} [options] <bytecode-list-file>"
            $config.map do |key, option|
                opts.on(option[:short], option[:long], option[:desc]) do |v|
                    options[key] = v
                end
            end
        end
    end

    def self.check(argv, options)
        missing = $config.keys.select{ |param| options[param].nil? }
        unless missing.empty?
            raise OptionParser::MissingArgument.new(missing.join(', '))
        end
        unless argv.length == 1
            raise OptionParser::MissingArgument.new("<bytecode-list-file>")
        end
    end

    def self.parse(argv)
        options = {}
        parser = optparser(options)

        begin
            parser.parse!(argv)
            check(argv, options)
        rescue OptionParser::MissingArgument, OptionParser::InvalidOption
            puts $!.to_s
            puts parser
            exit 1
        end

        options[:bytecodeList] = argv[0]
        options
    end
end
