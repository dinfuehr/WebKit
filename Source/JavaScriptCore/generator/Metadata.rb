require_relative 'Fits'

class Metadata
    @@emitter_local = nil

    def initialize(fields, initializers)
        @fields = fields
        @initializers = initializers
    end

    def empty?
        @fields.nil?
    end

    def length
        empty? ? 0 : @fields.length
    end

    def struct(op)
        return if empty?

        def convertFields(fields)
            fields.map do |field, type|
                if type.kind_of? Hash
                    "union {\n#{convertFields(type)}\n};"
                else
                    "#{type.to_s} #{field.to_s};"
                end
            end.join("\n")
        end

        fields = convertFields(@fields)

        inits = nil
        if @initializers && (not @initializers.empty?)
            inits = ": " + @initializers.map do |metadata, arg|
                "#{metadata}(__op.#{arg})"
            end.join(", ")
        end

        <<-EOF
        struct Metadata {
            Metadata(const #{op.capitalized_name}&#{" __op" if inits})
            #{inits}
            { }

            #{fields}
        };
        EOF
    end

    def accessor
        return if empty?

        <<-EOF
        Metadata& metadata(CodeBlock* codeBlock) const
        {
            return codeBlock->metadata<Metadata>(opcodeID, #{Metadata.field_name});
        }

        Metadata& metadata(ExecState* exec) const
        {
            return metadata(exec->codeBlock());
        }
        EOF
    end

    def field
        return if empty?

        "unsigned #{Metadata.field_name};"
    end

    def load_from_stream(index, size)
        return if empty?

        "#{Metadata.field_name}(#{Fits::convert(size, "stream[#{index}]", :unsigned)})"
    end

    def create_emitter_local
        return if empty?

        <<-EOF
        auto #{emitter_local.name} = __generator->addMetadataFor(opcodeID);
        EOF
    end

    def emitter_local
        unless @@emitter_local
            @@emitter_local = Argument.new("__metadataID", :unsigned, -1)
        end

        return @@emitter_local
    end

    def self.field_name
        "metadataID"
    end
end
