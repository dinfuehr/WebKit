class AssertionError < RuntimeError
    def initialize(msg)
        super
    end
end

def assert(msg, &block)
    raise AssertionError, msg unless yield
end
