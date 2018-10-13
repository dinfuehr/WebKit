class Type
    def initialize(name)
        @name = name
    end

    def *
        Type.new "#{@name}*"
    end

    def to_s
        @name.to_s
    end
end
