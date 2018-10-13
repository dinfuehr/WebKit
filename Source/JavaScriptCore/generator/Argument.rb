require_relative 'Fits'

class Argument
    attr_reader :name
    attr_reader :index

    def initialize(name, type, index)
        @optional = name[-1] == "?"
        @name = @optional ? name[0...-1] : name
        @type = type
        @index = index
    end

    def field
        "#{@type.to_s} #{@name};"
    end

    def create_param
        "#{@type.to_s} #{@name}"
    end

    def fits_check(size)
        Fits::check size, @name, @type
    end

    def fits_write(size)
        Fits::write size, @name, @type
    end

    def assert_fits(size)
        "ASSERT((#{fits_check size}));"
    end

    def load_from_stream(index, size)
        "#{@name}(#{Fits::convert(size, "stream[#{index}]", @type)})"
    end

    def setter
        <<-EOF
        template<typename Functor>
        void set#{capitalized_name}(#{@type.to_s} value, Functor func)
        {
            if (isWide())
                set#{capitalized_name}<OpcodeSize::Wide>(value, func);
            else
                set#{capitalized_name}<OpcodeSize::Narrow>(value, func);
        }

        template <OpcodeSize size, typename Functor>
        void set#{capitalized_name}(#{@type.to_s} value, Functor func)
        {
            if (!#{Fits::check "size", "value", @type})
                value = func();
            auto* stream = reinterpret_cast<typename TypeBySize<size>::type*>(reinterpret_cast<uint8_t*>(this) + #{@index} * size + PaddingBySize<size>::value);
            *stream = #{Fits::convert "size", "value", @type};
        }
        EOF
    end

    def capitalized_name
        @capitalized_name ||= @name.to_s.split('_').map do |word|
            letters = word.split('')
            letters.first.upcase!
            letters.join
        end.join
    end
end
