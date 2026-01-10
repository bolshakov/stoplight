class NullLightFactory
  def with(**) = raise NotImplementedError
  def build_with(**) = raise NotImplementedError

  def build = raise NotImplementedError
end
