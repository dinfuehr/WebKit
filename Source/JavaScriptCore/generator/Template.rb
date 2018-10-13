require_relative 'Type'

class Template < Type
  def [](*types)
    Type.new "#{@name}<#{types.map(&:to_s).join ","}>"
  end
end
