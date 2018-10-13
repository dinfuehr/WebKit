module Fits
    def self.convert(size, name, type)
        "Fits<#{type.to_s}, #{size}>::convert(#{name})"
    end

    def self.check(size, name, type)
        "Fits<#{type.to_s}, #{size}>::check(#{name})"
    end

    def self.write(size, name, type)
        "__generator->write(#{convert(size, name, type)});"
    end
end
