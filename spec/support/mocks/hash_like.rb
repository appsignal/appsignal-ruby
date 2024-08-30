class HashLike < Hash
  def initialize(value)
    super
    @value = value
  end

  def to_h
    @value
  end
end
