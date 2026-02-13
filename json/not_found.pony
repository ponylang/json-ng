primitive NotFound is Stringable
  """Sentinel value indicating a JSON path did not lead to a value."""

  fun string(): String iso^ => "NotFound".clone()
